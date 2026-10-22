# Better-NiDA

[![Latest Release](https://img.shields.io/github/v/release/airiharuki/Better-NiDA?style=for-the-badge&color=121A6B&label=Release)](https://github.com/airiharuki/Better-NiDA/releases/latest)
[![Platform Support](https://img.shields.io/badge/Platform-Windows%20%7C%20macOS%20%7C%20Linux-2563EB?style=for-the-badge)](#khmer-nida-layout---for-macos--linux)
[![Shift Reduction](https://img.shields.io/badge/Shift%20Load-%E2%88%9297.5%25%20(0.5%25%20Share)-16A34A?style=for-the-badge)](#current-work-the-midpoint-hybrid-engine)
[![AltGr Reduction](https://img.shields.io/badge/AltGr%20Load-%E2%88%9286.1%25-0D9488?style=for-the-badge)](#current-work-the-midpoint-hybrid-engine)
[![NiDA Parity](https://img.shields.io/badge/NiDA%20Parity-144%2F144%20Verified-7C3AED?style=for-the-badge)](#reverse-engineering-results)
[![License: MIT](https://img.shields.io/github/license/airiharuki/Better-NiDA?style=for-the-badge&color=475569)](LICENSE)

An improved, modern, and ergonomic evolution of the standard **Khmer NiDA**
keyboard layout—delivering **zero-lag speed**, **−97.5% `Shift` utilization**,
and **100% muscle-memory compatibility**.

### Quick Downloads (`v0.4.0`)

[![Windows Standalone Installer](https://img.shields.io/badge/Windows-BetterNiDA--Midpoint--Windows.exe-0078D6?style=flat-square&logo=windows)](https://github.com/airiharuki/Better-NiDA/releases/download/v0.4.0/BetterNiDA-Midpoint-Windows.exe)
[![Keyman Package](https://img.shields.io/badge/Keyman-better__nida__midpoint.kmp-F59E0B?style=flat-square)](https://github.com/airiharuki/Better-NiDA/releases/download/v0.4.0/better_nida_midpoint.kmp)
[![Get Keyman Engine](https://img.shields.io/badge/Keyman-Download%20Keyman%20(Free)-D97706?style=flat-square)](https://keyman.com/downloads/)
[![macOS Installer](https://img.shields.io/badge/macOS-install--nida--macos.command-111827?style=flat-square&logo=apple)](https://github.com/airiharuki/Better-NiDA/releases/download/v0.4.0/install-nida-macos.command)
[![Linux Installer](https://img.shields.io/badge/Linux-install--nida.sh-FCC624?style=flat-square&logo=linux&logoColor=black)](https://github.com/airiharuki/Better-NiDA/releases/download/v0.4.0/install-nida.sh)
[![Printable Layout Guide (PDF)](https://img.shields.io/badge/Layout%20Guide-Printable%20PDF-EC4899?style=flat-square&logo=adobeacrobatreader)](docs/better_nida_layout_guide.pdf)

> 💡 **Testing with Keyman:** First download and install the free [Keyman Desktop Engine](https://keyman.com/downloads/) (available for Windows, macOS, and Linux). Once Keyman is running, double-click [`better_nida_midpoint.kmp`](https://github.com/airiharuki/Better-NiDA/releases/download/v0.4.0/better_nida_midpoint.kmp) to install the full Better-NiDA keyboard with 1-click! Alternatively on Windows, you can test immediately with zero installations using [`BetterNiDA-Midpoint-Windows.exe`](https://github.com/airiharuki/Better-NiDA/releases/download/v0.4.0/BetterNiDA-Midpoint-Windows.exe).

---

## Keyboard Layout Guide

![Better-NiDA Standard Khmer Unicode Keyboard Layout Guide](https://raw.githubusercontent.com/airiharuki/Better-NiDA/refs/heads/main/docs/better_nida_layout_guide.png)

> **1-to-1 Reference Sheet:** Styled after the classic 2005 NiDA Standard Khmer Unicode Keyboard chart (`ក្ដារចុចយូនីកូដខ្មែរ`). Available as a [high-resolution PNG](docs/better_nida_layout_guide.png) and a [vector PDF](docs/better_nida_layout_guide.pdf).

---

## Background

The Khmer NiDA keyboard layout (National Information Communications Technology
Development Authority) is the national standard for typing the Khmer script on
modern computing platforms. In Windows it ships as the system driver
`kbdkni.dll` (KLID `00010453`).

Better-NiDA starts by fully reverse-engineering that driver down to its raw
tables - virtual keys, modifier numbering, character maps and multi-character
ligatures - as the reference specification any redesign must build on.

### Design Philosophy: Where Three Lineages Meet

**Better-NiDA** aims to unite the strengths of Cambodia's key typing innovations with original research:

- **The Standardization of Khmer NiDA**: Rooted in the national standard taught across Cambodia and embedded in everyday operating systems. Better-NiDA respects existing muscle memory—every stock key and familiar Shift chord remains fully functional and additive.
- **The Ergonomic Ease of Khmerism (ក្ដារចុចខ្មែរនិយម)**: Inspired by Khmerism’s focus on fluid, fatigue-free typing—minimizing heavy Shift contortions and prioritizing finger comfort so typists can write long texts without strain.
- **The Smart Sequencing of Khmer Angkor**: Drawing from the intelligent rule-based sequencing and contextual handling pioneered by the Khmer Angkor layout (Keyman / SIL) to resolve clusters cleanly into canonical Unicode.
- **Better-NiDA's Original Research**: Introducing original ergonomic mechanisms, notably the **universal slash series switch (`/`)**—an original invention allowing typists to toggle consonant series and register shifters effortlessly as a trailing key without chording Shift—alongside additive double-tap vowel upgrades and zero-displacement layer mapping.

> **The Better-NiDA Aim:** The nationwide muscle-memory of **NiDA**, the ergonomic typing ease of **Khmerism**, and the intelligent sequencing of **Khmer Angkor**, powered by **Better-NiDA's original research**.

---

## Platform Requirements

### The reverse-engineering toolchain is Windows-only

This is a hard limit, not a missing feature. The analysis works by loading
Microsoft's own keyboard driver and asking Windows to interpret it:

| | |
| :-- | :-- |
| Reads | `C:\Windows\System32\kbdkni.dll`, a Windows PE driver |
| Loads it with | `kernel32!LoadLibrary` + its `KbdLayerDescriptor` export |
| Oracle | `user32!ToUnicodeEx`, `MapVirtualKeyEx`, `LoadKeyboardLayout` |

Neither the file nor the APIs exist on macOS or Linux, so **these scripts
cannot run there, and cannot be ported** - there is no `kbdkni.dll` to read off
a Mac. Any attempt to reproduce the decompilation elsewhere would be reverse
engineering from the committed JSON, which is a weaker claim.

Concretely, Windows-only:

| Script | Why |
| :-- | :-- |
| `dump_kbd_tables.ps1` | `LoadLibrary`s the driver DLL and calls into it |
| `dump_layout.ps1` | `ToUnicodeEx` behavioural probe |
| `dump_layout_control.ps1` | `ToUnicodeEx` with Control held |
| `export_nida_spec.ps1` | `MapVirtualKeyEx` for scan codes |
| `build_platform_layouts.ps1` | `MapVirtualKeyEx` for scan codes |

Runs anywhere PowerShell does (Windows, macOS, Linux) - pure data, no Win32:

| Script | Note |
| :-- | :-- |
| `verify_tables.ps1` | compares the committed CSVs |
| `verify_control.ps1` | compares the committed CSVs |
| `verify_platform_layouts.ps1` | validates the committed layout files |
| `build_unicode_names.ps1` | needs network access to the UCD |
| `render_docs.ps1` | renders markdown from the spec |

`verify_all.ps1` appears portable but is not: it drives the Windows-only
scripts above, so it only completes on Windows. Run the individual portable
scripts directly if you are elsewhere.

### You do not need any of this to use the layouts

macOS and Linux users never need to run the toolchain. The verified spec is
committed as **`nida_layout.json`**, and the generated layouts are committed
alongside it. Clone, install, type. See [`macos/`](macos/) and
[`linux/`](linux/).

If you *do* want to regenerate the platform files on a Mac or Linux box, the
only blocker is one Win32 call: `build_platform_layouts.ps1` uses
`MapVirtualKeyEx` to derive scan codes from virtual keys, and that mapping
could be replaced with a static table to make the generator portable. Open an
issue if you are interested - it is a small change, just not one made by
necessity.

---

## Reverse Engineering Results

The layout is recovered by decoding the DLL's own data structures and then
cross-checking the result against Windows itself:

| Method | Tooling |
| :-- | :-- |
| Structural: walk `KbdLayerDescriptor()` tables in `kbdkni.dll` | `scripts/dump_kbd_tables.ps1` |
| Behavioural: probe `ToUnicodeEx()` per key and modifier state | `scripts/dump_layout.ps1` |
| Behavioural: same probe with Control held | `scripts/dump_layout_control.ps1` |
| Cross-check: both paths must agree exactly | `scripts/verify_tables.ps1` |
| Cross-check: secondary tables vs Control behaviour | `scripts/verify_control.ps1` |

**Result: 144 of 144 comparisons agree, zero mismatches**, plus 4 of 4 on the
Control probe.

### Key findings

- The NiDA driver defines **49 keys across 4 modifier states** (Normal, Shift,
  Control, AltGr). It overrides no Control characters.
- **Five keys emit two code points at once** - the Khmer *srak*/*srah* marks:
  `Shift+A` (ាំ), `Shift+V` (េះ), `Shift+;` (ោះ), `,` (ុំ) and `Shift+,` (ុះ).
- `J` is the **coeng subscript generator** (ជើង, `U+17D2`), and the **spacebar
  emits a zero-width space** (`U+200B`); `Shift+Space` is a real space.
- The driver has **no `Shift+AltGr` state**, so the Khmer symbol block
  `U+19E0..U+19FF` that the legacy `kbdkhmr.dll` layout exposes is unreachable
  in NiDA.
- Each key is defined in exactly one table: the main map and the fallback
  tables have **zero overlapping virtual keys**.
- Multi-character output is keyed by `(virtual key, modifier number)`, not as a
  chord string - getting this wrong reverses the two code points.

Full details, including the exact binary layout of every table, are in
**[REVERSE_ENGINEERING_NIDA.md](REVERSE_ENGINEERING_NIDA.md)**.

---

## Khmer NiDA Layout - for macOS & Linux

The same layouts, generated from the verified spec above and shipped for both
platforms. Two variants, since the two Windows layouts genuinely differ:

| | Coeng `្` | Zero-width space | Modifier states |
| :-- | :-- | :-- | :-- |
| **Khmer NiDA** | `J` | `Space` | 4 |
| **Khmer NiDA Legacy** | `Space` | `/` | 5 (incl. Shift+AltGr) |

| Platform | Files | Ligatures | Install |
| :-- | :-- | :-- | :-- |
| macOS | [`macos/`](macos/) | **full** - macOS emits multi-character output | [`macos/install.sh`](macos/install.sh) or a double-clickable `.pkg` |
| Linux | [`linux/`](linux/) | partial - XKB emits one character per level | [`linux/install.sh`](linux/install.sh) |

**macOS is the better-supported target.** A macOS keylayout can emit several
characters from one key press, so all five ligatures work. XKB maps each key to
exactly one character per level, so those five keys emit only their first code
point on Linux; the affected lines are marked `LIGATURE truncated`. Everything
else - including the coeng and the zero-width space - is faithful on both.

On Linux, [`linux/m17n/`](linux/m17n/) provides a ligature-capable input
method for anyone who needs those.

> **Testing status.** Both platforms were generated and structurally validated
> on Windows (the analysis host). They have **not** been loaded on macOS or
> Linux. Each platform ships a test script - `linux/verify.sh` and the
> checklist in `macos/README.md` - and the honest position is that these are
> untested on real hardware. Please open an issue if something misbehaves —
> and check **[CHANGELOG.md](CHANGELOG.md)** first, since the most likely
> problems are already documented limitations rather than defects.

### Help us test them

This is the most useful thing you can contribute right now. If you have a Mac
or a Linux box:

1. Install the layout ([`macos/`](macos/) or [`linux/`](linux/))
2. Work through the checklist in that directory's README
3. Open a **Testing Report** issue - even "it works" is worth recording

The automated checks catch a malformed file. They cannot tell you whether your
desktop will list the layout at all, which is exactly the bug we would most
likely have shipped.

---

## Current Work: The "Midpoint" Hybrid Engine

With stock NiDA faithfully decoded and ported to macOS and Linux, active development is focused on **improving typing speed, eliminating clunkiness, and reducing `Shift` utilization to near zero without breaking typists' muscle memory**.

Measured on a **565.4 million character Khmer corpus** (scored via shortest-path search in `scripts/score_midpoint.ps1` over a 374,918-character typeable sample):

| Metric | Stock NiDA | Better-NiDA Midpoint | Improvement |
| :-- | --: | --: | :-- |
| **Typeable characters** | 374,918 | 374,918 | **100% repertoire parity** |
| **Keystrokes needing `Shift`** | 89,999 | 2,217 | **−97.5%** |
| **`Shift` share of keystrokes** | **24.3%** | **0.5%** | **−23.8 percentage points** |
| **Keystrokes needing `AltGr`** | 2,984 | 414 | **−86.1%** |
| **Total presses (`keys + modifiers`)** | 463,536 | 458,109 | **−5,427 presses** |
| **KSPC (Keystrokes Per Character)** | **1.236** | **1.222** | **−1.2% (faster)** |

**Better-NiDA "Midpoint"** (`scripts/midpoint_engine.ps1` $\rightarrow$ `midpoint_layout.json`) uses a two-tier architecture generated from a single source of truth:

- **Static Layer (Zero-Lag, Universal — macOS `.keylayout`, Linux XKB `linux/nida_midpoint`)**:
  - Moves high-frequency word-final marks (Nikahit `ំ` `U+17C6` and Reahmuk `ះ` `U+17C7`) off `Shift` onto unshifted `]` and `\`, saving 1 full keystroke on nearly every word while relocating `ឪ` (`U+17AA`), `ឮ` (`U+17AE`), and `ឳ` (`U+17B3`) to `AltGr+]`, `AltGr+\`, and `AltGr+U`.
  - Places the 13 second-series consonants on the vacant `Shift+AltGr` (`Shift+Option`) layer, displacing nothing.
  - Makes `Shift+J` emit Coeng `្` (`U+17D2`) as a rollover-safe modifier, eliminating accidental `ញ` during rapid subscript typing.

- **Sequence / Contextual Layer (Zero-Lag Inline — Windows Keyman `windows/better_nida_midpoint.kmn`, Linux `linux/m17n/nida-midpoint.mim`)**:
  - **Universal Series Flip (`/`)**: An original Better-NiDA research invention—typing a base consonant followed by trailing `/` switches its series (`k/` $\rightarrow$ `គ`, `t/` $\rightarrow$ `ទ`, `b/` $\rightarrow$ `ព`, `c/` $\rightarrow$ `ជ`, `g/` $\rightarrow$ `អ`) or appends the appropriate series shifter (`m/` $\rightarrow$ `ម៉`, `s/` $\rightarrow$ `ស៊`) without holding `Shift`.
  - **Rollover-Safe Coeng & `Shift`-Free `ញ` / `្ញ`**: `jj` emits standalone `ញ` (`U+1789`), `jj/` emits `ញ៉` (`U+1789 U+17C9`), and `j/` emits subscript `្ញ` (`U+17D2 U+1789`) in 2 unshifted keys instead of 3 presses.
  - **Additive Double-Tap & Vowel/Space Upgrades**: Double-tapping or pairing vowels/signs upgrades them without `Shift` (`ii` $\rightarrow$ `ី`, `uu` $\rightarrow$ `ូ`, `ee` $\rightarrow$ `ែ`, `aa` $\rightarrow$ `ាំ`, `ea` $\rightarrow$ `ោ`, `ei` $\rightarrow$ `ើ`, `ua`/`u/` $\rightarrow$ `ួ`, `ai`/`i/` $\rightarrow$ `ៃ`, `  ` or ` /` $\rightarrow$ `U+0020` real space, `6/` $\rightarrow$ `៍`, `7/` $\rightarrow$ `័`, `\\` $\rightarrow$ `ៈ`, `;/` $\rightarrow$ `៖`).
  - Preserves **100% of unshifted `A–Z`** and **100% of stock `Shift` chords** (except `Shift+J`) for total backwards compatibility.

Layout correctness and modifier load are verified and measured using **`scripts/verify_midpoint.ps1`** and **`scripts/score_midpoint.ps1`**.

---

## Project Roadmap

The complete development strategy is detailed in **[ROADMAP.md](ROADMAP.md)**.

| Stage | Focus | Core Deliverables | Status |
| :-- | :-- | :-- | :-- |
| **1. Measure** | Validate on 565M corpus | `scripts/score_midpoint.ps1` + `scripts/analyze_corpus.py`: `Shift` share reduced from **24.3% to 0.5%** (−97.5%), KSPC improved from **1.236 to 1.222**. | **Done** |
| **2. Linux** | Reference target | `linux/m17n/nida-midpoint.mim` (full sequence + static rules) and `linux/nida_midpoint` (XKB `EIGHT_LEVEL` static subset). | **Generated & Structurally Verified** |
| **3. Windows** | Keyman target | `windows/better_nida_midpoint.kmn` using zero-lag inline contextual replacements (`U+1780 + [K_SLASH] > U+1782`). Stock `kbdkni.dll` untouched. | **Generated & Structurally Verified** |
| **4. macOS** | Static subset | `macos/Khmer Better-NiDA.keylayout` (5-`<keyMap>` bundle with `Shift+Option` second-series consonants and zero dead-key lag). | **Generated & Structurally Verified** |
| **5. Verify** | Real hardware | Hardware testing on macOS, Linux, and Keyman Desktop with Cambodian typists. | **In Progress** |

Midpoint makes typing **less effortful, not shorter** — it trades raw keystroke count for fewer `Shift` presses. What it does *not* solve, and what comes after it:

- **Coeng ligatures** — `្` + subscript is a contiguous 2-character substring, so it ligates directly. NiDA ships only 5 ligatures, worth 0.9% of keystrokes.
- **Coverage parity** — 45 Khmer-script characters reachable in legacy Khmer are not in NiDA, including the consonants `ឝ` and `ឞ`.
- **Auto-ZWSP** — 16.4% of keystrokes produce a `U+200B` the reader never sees. No layout can do this; it needs an IME.

For deep dives into layout limits, modifier capacity, and design trade-offs, consult **[ROADMAP.md](ROADMAP.md)**.

---

## Artifacts

| File | Contents |
| :-- | :-- |
| [docs/better_nida_layout_guide.png](docs/better_nida_layout_guide.png) / [.pdf](docs/better_nida_layout_guide.pdf) | 1-to-1 visual keyboard reference chart (300-DPI PNG & vector PDF) |
| [REVERSE_ENGINEERING_NIDA.md](REVERSE_ENGINEERING_NIDA.md) | Full technical specification and findings |
| [ROADMAP.md](ROADMAP.md) | In-depth development plan, empirical baseline, and architecture trade-offs |
| [nida_layout.json](nida_layout.json) | Machine-readable NiDA spec: 49 keys, all states, ligatures, official Unicode names |
| [midpoint_layout.json](midpoint_layout.json) | Machine-readable Better-NiDA Midpoint spec: 49 keys, 5 modifier levels, 51 sequence rules |
| [windows/better_nida_midpoint.kmn](windows/better_nida_midpoint.kmn) | Keyman keyboard source for Windows/cross-platform with zero-lag contextual rules |
| [linux/m17n/nida-midpoint.mim](linux/m17n/nida-midpoint.mim) | Linux m17n input method implementing full Midpoint sequence and static layers |
| [linux/nida_midpoint](linux/nida_midpoint) | Linux XKB `EIGHT_LEVEL` symbols for the Midpoint static subset |
| [macos/Khmer Better-NiDA.keylayout](macos/Khmer%20Better-NiDA.keylayout) | macOS 5-level `.keylayout` bundle for the Midpoint static subset |
| [tables_kbdkni.json](tables_kbdkni.json) / [.csv](tables_kbdkni.csv) | Every table decoded directly from `kbdkni.dll` |
| [tables_kbdkhmr.json](tables_kbdkhmr.json) / [.csv](tables_kbdkhmr.csv) | Same for the legacy Khmer layout |
| [tables_kbdus.json](tables_kbdus.json) / [.csv](tables_kbdus.csv) | Same for US, used as the structural control |
| [kni_layout.csv](kni_layout.csv) | Behavioural probe of NiDA (`ToUnicodeEx`) |
| [khmr_layout.csv](khmr_layout.csv) | Behavioural probe of legacy Khmer |
| [kni_control.csv](kni_control.csv) | Behavioural probe of NiDA with Control held |
| [us_control.csv](us_control.csv) | Same probe for US, used to test a table-role claim |

Character names come from the official Unicode Character Database
(`scripts/data/unicode_names.json`), so no name in the spec is hand-typed.

---

## Repository Structure

```
Better-NiDA/
├── docs/
│   ├── better_nida_layout_guide.png  # 300-DPI 1-to-1 visual keyboard guide
│   └── better_nida_layout_guide.pdf  # Printable vector PDF keyboard guide
├── REVERSE_ENGINEERING_NIDA.md   # Full technical specification
├── ROADMAP.md                    # Plan for improving on NiDA
├── CHANGELOG.md                  # Release history
├── nida_layout.json              # Authoritative NiDA layout spec
├── midpoint_layout.json          # Authoritative Better-NiDA Midpoint spec
├── tables_kbd*.json / .csv       # Tables decoded from the driver DLLs
├── kni_layout.csv                # Behavioural probe: NiDA
├── khmr_layout.csv               # Behavioural probe: legacy Khmer
├── windows/                      # Keyman (.kmn/.kps) source for Better-NiDA Midpoint
├── macos/                        # macOS .keylayout layouts + installer
├── linux/                        # XKB layouts + installer + m17n input methods
├── scripts/
│   ├── dump_kbd_tables.ps1       # Decode the DLL's KbdLayerDescriptor tables
│   ├── dump_layout.ps1           # Probe layout behaviour via ToUnicodeEx
│   ├── dump_layout_control.ps1   # Probe again with Control held
│   ├── verify_tables.ps1         # Assert the two paths agree (CI-friendly)
│   ├── verify_control.ps1        # Check secondary tables vs Control behaviour
│   ├── build_platform_layouts.ps1 # Generate the macOS, Linux, m17n, and Keyman files
│   ├── build_installers.ps1      # Compile and bundle release installers into dist/
│   ├── verify_platform_layouts.ps1 # Validate all generated platform files
│   ├── verify_all.ps1            # Rebuild and verify everything, one command
│   ├── build_unicode_names.ps1   # Refresh official Unicode character names
│   ├── export_nida_spec.ps1      # Build nida_layout.json
│   ├── export_midpoint_spec.ps1  # Build midpoint_layout.json
│   ├── render_docs.ps1           # Render markdown tables from the spec
│   ├── analyze_corpus.py         # Stream 565M-char corpus into frequency & coeng tables
│   ├── score_midpoint.ps1        # Shortest-path KSPC & modifier scorer against corpus
│   ├── midpoint_engine.ps1       # Single source of truth for the Midpoint hybrid engine
│   ├── verify_midpoint.ps1       # Test suite for Midpoint static & sequence rules
│   └── data/                     # Curated UCD names & corpus coeng pair frequencies
├── .gitignore
└── README.md
```

---

## Reproducing

One command rebuilds and re-verifies everything from scratch:

```powershell
.\scripts\verify_all.ps1
```

It runs nine generation stages followed by four checks, and exits non-zero if
any stage or check fails:

```
1-3  decode driver tables (kbdkni, kbdkhmr, kbdus)
4-6  probe layout behaviour, with and without Control
7    refresh official Unicode character names
8    rebuild nida_layout.json
9    generate the macOS .keylayout and Linux XKB files

CHECK  NiDA tables vs ToUnicodeEx            144/144, 0 mismatches
CHECK  legacy Khmer tables vs ToUnicodeEx    144/144, 0 mismatches
CHECK  secondary tables vs Control             4/4
CHECK  macOS + Linux layout files            structural
```

To verify the committed artifacts without regenerating them (for CI):

```powershell
.\scripts\verify_all.ps1 -SkipRegenerate
```

The generated artifacts are byte-identical to the committed ones, so the
pipeline is deterministic: any diff after a clean run means something changed.

Individually:

```powershell
# 1. decode the driver tables
.\scripts\dump_kbd_tables.ps1 -Dll kbdkni.dll
.\scripts\dump_kbd_tables.ps1 -Dll kbdkhmr.dll
.\scripts\dump_kbd_tables.ps1 -Dll kbdus.dll

# 2. probe the layouts behaviourally
.\scripts\dump_layout.ps1
.\scripts\dump_layout_control.ps1

# 3. prove the decode is correct (non-zero exit on any mismatch)
.\scripts\verify_tables.ps1 -TablesCsv tables_kbdkni.csv -ProbeCsv kni_layout.csv
.\scripts\verify_control.ps1

# 4. rebuild the specification and the platform layouts
.\scripts\build_unicode_names.ps1
.\scripts\export_nida_spec.ps1
.\scripts\build_platform_layouts.ps1

# 5. validate the generated platform files
.\scripts\verify_platform_layouts.ps1
```

The regenerated artifacts are byte-identical to the committed ones, so the
outputs are reproducible and any diff after a run means something changed.

> **Generated files.** `nida_layout.json`, `tables_kbd*.json`, `macos/*.keylayout`
> and `linux/nida*` are all produced by the scripts above. Hand edits work
> today but are overwritten on the next run - change the generator instead.
> The platform layouts you *install* (`~/.xkb/symbols/nida`,
> `~/Library/Keyboard Layouts/...`) are yours to edit freely.

Requires Windows (the tools load the driver DLLs and call Windows keyboard APIs)
and Windows PowerShell 5.1 or later.

---

## Contributing & Community

Contributions are warmly welcomed! Please read:
- **[CONTRIBUTING.md](CONTRIBUTING.md)**: Development workflow, Conventional Commits specification, and PR guidelines.
- **[CODE_OF_CONDUCT.md](CODE_OF_CONDUCT.md)**: Community standards and Contributor Covenant pledge.

### Start with the CHANGELOG

**[CHANGELOG.md](CHANGELOG.md) is the fastest way to see what has already been
tried, shipped, or rejected** — and it is the first place to look before opening
an issue or adding something. Two minutes reading it usually saves duplicating
work that was already considered.

It records the reasoning behind decisions, not just the diffs, which matters
here because most proposals to this layout have a trap attached. Several rules in
the Midpoint variant were dropped because they broke something subtle, and the
CHANGELOG says which and why. It is also the place where "nothing yet" under
*Unreleased* means an idea genuinely has not been tried.

| If you want to... | Do this |
| :-- | :-- |
| Report something broken | Search the CHANGELOG first — it may be a known limitation. If it is not, use the issue templates below. |
| Propose a new key or character | Read [ROADMAP.md](ROADMAP.md) §5.1 on modifier capacity first — there are 98 unused slots already identified, so your idea may fit without displacing anyone. |
| Contribute a fix or feature | Check the CHANGELOG for prior art, then follow [CONTRIBUTING.md](CONTRIBUTING.md). |
| Report test results | The **Testing Report** template — "it works" is worth recording. |

**Issue templates:** [Bug report](.github/ISSUE_TEMPLATE/bug_report.md) ·
[Feature request](.github/ISSUE_TEMPLATE/feature_request.md) ·
[Testing report](.github/ISSUE_TEMPLATE/testing_report.md) ·
[Layout proposal](.github/ISSUE_TEMPLATE/layout_proposal.md)

---

## Versioning

This project follows [Semantic Versioning 2.0.0](https://semver.org/) and
[Conventional Commits](https://www.conventionalcommits.org/). Full release
history — including what was considered and rejected — is in
**[CHANGELOG.md](CHANGELOG.md)**, formatted per
[Keep a Changelog](https://keepachangelog.com/).

---

## License

MIT License. See [LICENSE](LICENSE).

