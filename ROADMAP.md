# Better-NiDA Roadmap

How to go about fixing the Khmer NiDA layout: what can be fixed, what cannot,
what order to do it in, and what each step needs.

---

## 1. First, the scoping: what a keyboard layout can and cannot fix

This determines what the project is worth doing at all, so it comes first.

A keyboard layout maps key + modifier to code points. That is *all* it does.
It can control **which characters are reachable and how much effort each
takes**. It cannot control anything downstream of the keypress.

| Problem | Fixable by a layout? |
| :-- | :-- |
| A character cannot be typed at all | **Yes** — add a key or a level |
| Typing a common character needs Shift + a reach across the keyboard | **Yes** — move it |
| The layout produces two code points, the Linux XKB stack drops the second | **Yes** — different platform target |
| Khmer text renders with wrong coeng stacking or broken shaping | **No** — needs shaping in the text engine |
| An app mishandles `U+200B`, shows it as a box, or breaks on `U+17D2` | **No** — needs an input method or an app fix |
| Word boundaries are wrong because nothing auto-inserts `U+200B` | **No** — needs an IME |

The last four are real problems people attribute to "the keyboard layout". They
are not layout problems, and no amount of remapping fixes them. If Better-NiDA
is going to address them, the deliverable is an **input method**, not a layout —
a much larger project, and a legitimate one, but a different one.

**Decision to make early:** is Better-NiDA a better *layout*, or a better
*typing engine*? Doing both doubles the work and the maintenance. The layout
scope is achievable and verifiable now; the engine scope needs a rendering and
IME architecture nobody has designed here yet.

---

## 2. Where we are

Done, and verified on Windows:

- `kbdkni.dll` and `kbdkhmr.dll` decoded from their binary tables, and
  cross-checked against the Windows `ToUnicodeEx` API (144/144 per layout, plus
  4/4 on a Control probe).
- An authoritative spec, `nida_layout.json`, from which macOS `.keylayout` and
  Linux XKB files are generated.
- A reproducible pipeline: `scripts/verify_all.ps1` regenerates and re-checks
  everything, and the artifacts are byte-identical run to run.

Not done:

- **Nothing has been loaded on a real Mac or Linux machine.**
- The reverse-engineering toolchain is Windows-only and not portable.
- `linux/m17n/` has never been run through `m17n-db`.

---

## 3. Phase 1 — Make it verifiable (do this first, before changing anything)

Nothing else is worth building on top of an unverified base.

- [ ] **Test on macOS.** Install `install-nida-macos.command`, run the checklist,
      open a Testing Report issue.
- [ ] **Test on Linux.** Same via `linux/install.sh` and `linux/verify.sh`.
- [ ] **Validate the m17n input method** with `m17n-db`, which must print
      nothing.
- [ ] **Find two or three Khmer typists** who will test-drive candidates. Not
      optional for Phase 3, and worth recruiting now.

Exit criterion: one confirmed-working install on each OS, and a name against
each open bug.

---

## 4. Phase 2 — Close the objective gaps

These need no research and no debate: characters are simply missing. Anyone
who hits them is typing around a real hole.

### 2.1 The fifth modifier level

NiDA's main table declares **4 modifier states**; legacy Khmer declares **5**.
The missing level is `Shift+AltGr`, and it is where legacy Khmer keeps the
entire `U+19E0..U+19FF` symbol block. **45 Khmer-block characters reachable in
legacy Khmer are unreachable in NiDA**, including two real consonants:

- `ឝ` SHA (U+179D) and `ឞ` SSO (U+179E) — **consonants NiDA cannot type**
- `៝` ATTHACAN (U+17DD)
- the 9 `LEK ATTAK` symbols (U+17F0..17F9)
- the 32 symbols U+19E0..19FF (PATHAMASAT, KOET and ROC families, TUTEYASAT)

The generator already emits 5-level layouts for the legacy variant, so this is
a data change, not a code change.

- [ ] Decide the exact key assignments for the new level
- [ ] Add the level to the NiDA variant in the generator
- [ ] Place `ឝ` and `ឞ` somewhere reachable — this needs a decision, since it
      means displacing something
- [ ] Re-run the chain, confirm the layout files grow the expected characters

### 2.2 Unblock authoring (architecture gap)

Right now the pipeline is one-directional:

```
kbdkni.dll  ->  nida_layout.json  ->  macos + Linux layouts
```

The spec is a *dump* of Microsoft's driver. Better-NiDA wants to *author* a
layout and emit platforms from it, which means the middle needs to become an
input rather than a by-product.

- [ ] Define a small, readable layout source format (YAML or JSON) that a human
      can edit
- [ ] Have the generator accept either a driver dump or an authored file
- [ ] Keep the existing pipeline able to reproduce the NiDA dump, so the
      authored NiDA is provably identical to the driver's

### 2.3 Linux ligature parity

On Linux, XKB gives one character per key per level, so the five ligatures
(`Shift+A`, `Shift+V`, `Shift+;`, `,`, `Shift+,`) emit only their first code
point. macOS has no such limit.

- [ ] Validate `linux/m17n/` properly
- [ ] Consider QMK/ZMK as a Linux path that can do multi-character output
- [ ] Document the limitation prominently — it is already in `linux/README.md`

---

## 5. Phase 3 — Ergonomics

Everything here requires evidence. None of it should be done on intuition.

### 5.1 Get frequency data

There is no input to this phase without it. Candidate sources:

- Khmer Wikipedia dumps (`km.wikipedia.org`) — large, free, real prose
- SEAlang Project — Khmer word lists and dictionaries
- Khmer subtitle corpora, if available

Then build the analyser:

- [ ] A script that takes a corpus and produces a character frequency table
- [ ] A script that scores a candidate layout: keystrokes per character, share
      of keystrokes needing Shift, finger-travel distance, home-row coverage,
      same-finger bigram rate

### 5.2 Candidate changes to evaluate

Listed as hypotheses, not recommendations. Each is a trade-off, not a fix.

| Hypothesis | Trade-off |
| :-- | :-- |
| Flatten the consonant pairs so `ក` and `គ` need no Shift | Abandons NiDA's two-layer model entirely |
| Move the most frequent vowels to the home row | Displaces consonants or symbols |
| Move the real space off `Shift+Space` | Cambridges an intentional choice; Khmer word separation relies on `U+200B` |
| Make Caps Lock do something useful | It currently cannot — Caps maps to the base layer, since Shift is already load-bearing |

That last row is worth pausing on: because `Shift` carries the o-series
consonants, **Caps Lock is structurally useless on NiDA**. That is not a bug in
our implementation, it is a consequence of the design.

### 5.3 Evaluate properly

- [ ] Generate 2-3 candidate layouts from the source format
- [ ] Score each against the corpus metrics
- [ ] Have the typists type a fixed passage on each, timed and error-counted
- [ ] Publish the results, including the ones that lose

---

## 6. Phase 4 — Beyond the keyboard

Only if Phase 3 shows the layout is not the bottleneck.

- [ ] Auto-insert `U+200B` at syllable boundaries — impossible in a layout,
      needs an IME
- [ ] Hangul-style syllable composition? Khmer is not composed that way, but a
      syllable-cluster buffer would help
- [ ] QMK/ZMK firmware with the layout baked in
- [ ] Windows port, so a `.keylayout`-equivalent ships to NiDA users

---

## 7. Open questions

Things worth deciding before the work starts:

1. **Layout or engine?** See section 1. This is the biggest fork.
2. **Who are the typists?** Phase 3 is worthless without Cambodian users, and
   that is a relationship, not a task.
3. **Is compatibility sacred?** A Better-NiDA that reassigns NiDA keys will
   annoy existing users. A separate layout name, shipped alongside NiDA,
   avoids forcing a choice.
4. **Who maintains it?** The reverse-engineering is done, but the generated
   layouts need regenerating whenever Windows ships a new `kbdkni.dll`.