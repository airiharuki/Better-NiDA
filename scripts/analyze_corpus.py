#!/usr/bin/env python3
"""Turn a compressed Khmer text corpus into the measurements the roadmap needs.

Reads an .xz (or plain) UTF-8 text file, streams it, and emits:

  1. a cleaned sample suitable for score_midpoint.ps1
  2. a character frequency table
  3. coeng + following-character pair frequencies, which is the ranking that
     ROADMAP.md section 5.1 needs before any ligature is chosen
  4. composition stats: how much of the text is ZWSP, real space, and other
     structural overhead

Why streaming: the corpus is ~150 MB compressed and expands to far more, so it
is never held in memory in full.

Why Python: it has lzma in the standard library and counts text quickly. This is
the only part of the project that needs it. Decoding the driver tables and
generating the layouts remain pure PowerShell and Windows-only.

Console safety: this box's console is cp1252 and cannot encode Khmer, so every
printed diagnostic is ASCII. Khmer goes into files.
"""

import argparse
import collections
import io
import json
import lzma
import os
import re
import sys

COENG = 0x17D2
ZWSP = 0x200B
KHMER_LO = 0x1780
KHMER_HI = 0x17FF

TAG = re.compile(r"<[^>]{0,200}>")


def open_text(path):
    if path.endswith(".xz"):
        return lzma.open(path, "rt", encoding="utf-8", errors="replace")
    return io.open(path, "r", encoding="utf-8", errors="replace")


def khmer_ratio(s):
    if not s:
        return 0.0
    k = sum(1 for ch in s if KHMER_LO <= ord(ch) <= KHMER_HI)
    letters = sum(1 for ch in s if ch.isalpha())
    return (k / letters) if letters else 0.0


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("corpus")
    ap.add_argument("--outdir", required=True)
    ap.add_argument("--sample-chars", type=int, default=400_000)
    ap.add_argument("--min-khmer-ratio", type=float, default=0.80)
    args = ap.parse_args()

    os.makedirs(args.outdir, exist_ok=True)

    freq = collections.Counter()
    coeng_pairs = collections.Counter()
    other = collections.Counter()

    lines_kept = 0
    lines_total = 0
    sample_len = 0
    total_chars = 0

    sample_path = os.path.join(args.outdir, "corpus_sample.txt")
    sample_fh = io.open(sample_path, "w", encoding="utf-8", newline="\n")

    with open_text(args.corpus) as fh:
        for line in fh:
            lines_total += 1
            line = line.strip()
            if not line:
                continue
            # Drop markup, then require the line to still be mostly Khmer so
            # headers and Latin-only lines do not pollute the frequencies.
            line = TAG.sub(" ", line)
            if khmer_ratio(line) < args.min_khmer_ratio:
                continue

            lines_kept += 1
            total_chars += len(line)
            freq.update(line)

            for i, ch in enumerate(line):
                o = ord(ch)
                if KHMER_LO <= o <= KHMER_HI:
                    if o == COENG and i + 1 < len(line):
                        coeng_pairs[line[i:i + 2]] += 1
                elif ch in (" ", "\t"):
                    other["space"] += 1
                elif o == ZWSP:
                    other["zwsp"] += 1
                elif ch.isdigit() or (ch.isascii() and ch.isalpha()):
                    other["ascii_alnum"] += 1
                else:
                    other["punctuation_other"] += 1

            if sample_len < args.sample_chars:
                take = min(len(line), args.sample_chars - sample_len)
                sample_fh.write(line[:take])
                sample_fh.write("\n")
                sample_len += take + 1

    sample_fh.close()

    # --- outputs -------------------------------------------------------------

    freq_path = os.path.join(args.outdir, "corpus_freq.json")
    with io.open(freq_path, "w", encoding="utf-8") as fh:
        json.dump({("U+%04X" % ord(c)): n for c, n in freq.most_common()},
                  fh, ensure_ascii=False, indent=1)

    pairs_path = os.path.join(args.outdir, "coeng_pairs.json")
    with io.open(pairs_path, "w", encoding="utf-8") as fh:
        json.dump({("U+%04X+U+%04X" % (ord(p[0]), ord(p[1]))): n
                   for p, n in coeng_pairs.most_common()},
                  fh, ensure_ascii=False, indent=1)

    print(f"lines read        : {lines_total:,}")
    print(f"lines kept        : {lines_kept:,}")
    print(f"chars kept        : {total_chars:,}")
    print(f"sample written    : {sample_len:,} chars -> {sample_path}")
    print()
    print("=== composition ===")
    non_khmer = sum(v for k, v in other.items())
    khmer_total = sum(n for c, n in freq.items() if KHMER_LO <= ord(c) <= KHMER_HI)
    whole = khmer_total + non_khmer
    print(f"  Khmer block chars : {khmer_total:>14,}")
    for k, v in other.most_common():
        print(f"  {k:<18}: {v:>14,}  ({100.0*v/whole:5.2f}% of all chars)")
    print()
    print(f"  ZWSP share of ALL chars     : {100.0*other['zwsp']/whole:5.2f}%")
    print(f"  ZWSP share of Khmer chars  : {100.0*other['zwsp']/khmer_total:5.2f}%")
    print()
    print("=== top 25 characters ===")
    for c, n in freq.most_common(25):
        share = 100.0 * n / whole
        print(f"  U+{ord(c):04X}  {n:>12,}  {share:5.2f}%")
    print()
    print("=== top 25 coeng + following char ===")
    total_coeng = sum(coeng_pairs.values())
    print(f"  total coengs followed by a char: {total_coeng:,}")
    cum = 0
    for i, (p, n) in enumerate(coeng_pairs.most_common(25)):
        cum += n
        share = 100.0 * n / total_coeng
        cumshare = 100.0 * cum / total_coeng
        print(f"  U+{ord(p[0]):04X}+U+{ord(p[1]):04X}  {n:>10,}  {share:5.2f}%  cum {cumshare:5.1f}%")
    print()
    print(f"wrote {freq_path}")
    print(f"wrote {pairs_path}")


if __name__ == "__main__":
    sys.exit(main())