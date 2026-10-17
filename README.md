# Better-NiDA

An improved, modern, and ergonomic evolution of the standard **Khmer NiDA**
keyboard layout.

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
> untested on real hardware. Please open an issue if something misbehaves.

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

With stock NiDA faithfully decoded and ported to macOS and Linux, active development is focused on **improving the typing experience without breaking typists' muscle memory**. 

Our analysis revealed two critical structural facts:
1. **16.4% of all typed characters in Khmer are invisible Zero-Width Spaces (`U+200B`)**, representing a massive keystroke overhead that no pure layout can remove.
2. **Stock NiDA has 98 completely empty modifier slots** across Control (49/49 free) and Shift+AltGr (49/49 free), meaning extensions do not need to displace existing characters.

To address these inefficiencies, we are prototyping **Better-NiDA "Midpoint"** (`scripts/midpoint_engine.ps1`), a hybrid architecture split into two tiers:

- **Static Layer (Zero-Lag, Universal)**:
  - Moves high-frequency word-final marks (Nikahit `ំ` and Reahmuk `ះ`) off Shift onto unshifted `]` and `\`, moving rare independent vowels down to AltGr.
  - Places second-series consonants on the vacant `Shift+AltGr` layer (displacing nothing).
  - Makes `Shift+J` emit Coeng `្` as a rollover-safe modifier, eliminating accidental `ញ` during rapid subscript typing.
  - Runs natively on all platforms including macOS `.keylayout` with zero display latency.

- **Sequence Layer (Input Method / IME-Buffered)**:
  - **Universal Series Flip (`/`)**: An original Better-NiDA innovation—typing a base consonant followed by trailing `/` switches its series or appends appropriate register shifters (e.g. muusikatoan/traysap) without holding Shift.
  - **Additive Double-Tap Upgrades**: Typing a vowel twice upgrades it to its long or composite counterpart (e.g., `ii` $\rightarrow$ `ី`, `uu` $\rightarrow$ `ូ`, `aa` $\rightarrow$ `ាំ`).
  - Preserves 100% of stock Shift chords for total backwards compatibility.

Layout efficiency and modifier load are verified and measured using **`scripts/score_layout.ps1`** and **`scripts/verify_midpoint.ps1`**.

---

## Project Roadmap

The complete development strategy is detailed in **[ROADMAP.md](ROADMAP.md)**. The path is now driven by shipping the **Midpoint** variant:

| Stage | Focus | Core Deliverables |
| :-- | :-- | :-- |
| **1. Measure** | Validate the claim | Inverse mode on `midpoint_engine.ps1`: text → cheapest keystrokes, with the real `Shift` rate. Gates everything after it. |
| **2. Linux** | Reference target | `nida-midpoint.mim` with full sequence rules (m17n resolves longest-prefix natively), plus an XKB static-subset fallback. Validate with `m17n-db`. |
| **3. Windows** | Keyman target | `better_nida_midpoint.kmn`, generated from the engine. Opt-in; stock `kbdkni.dll` untouched. |
| **4. macOS** | Static subset only | A 5-`<keyMap>` `.keylayout`. Second-series consonants move to the unused `Shift+AltGr` level. No `<actions>`, so zero display lag. |
| **5. Verify** | Real hardware | macOS, Linux and Keyman installs, then the same passage typed by Khmer typists on stock NiDA vs Midpoint. |

Midpoint makes typing **less effortful, not shorter** — it trades raw keystroke count for fewer `Shift` presses. What it does *not* solve, and what comes after it:

- **Coeng ligatures** — `្` + subscript is a contiguous 2-character substring, so it ligates directly. NiDA ships only 5 ligatures, worth 0.9% of keystrokes.
- **Coverage parity** — 45 Khmer-script characters reachable in legacy Khmer are not in NiDA, including the consonants `ឝ` and `ឞ`.
- **Auto-ZWSP** — 16.4% of keystrokes produce a `U+200B` the reader never sees. No layout can do this; it needs an IME.

For deep dives into layout limits, modifier capacity, and design trade-offs, consult **[ROADMAP.md](ROADMAP.md)**.

---

## Artifacts

| File | Contents |
| :-- | :-- |
| [REVERSE_ENGINEERING_NIDA.md](REVERSE_ENGINEERING_NIDA.md) | Full technical specification and findings |
| [ROADMAP.md](ROADMAP.md) | In-depth development plan, empirical baseline, and architecture trade-offs |
| [nida_layout.json](nida_layout.json) | Machine-readable NiDA spec: 49 keys, all states, ligatures, official Unicode names |
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
├── REVERSE_ENGINEERING_NIDA.md   # Full technical specification
├── ROADMAP.md                    # Plan for improving on NiDA
├── CHANGELOG.md                  # Release history
├── nida_layout.json              # Authoritative NiDA layout spec
├── tables_kbd*.json / .csv       # Tables decoded from the driver DLLs
├── kni_layout.csv                # Behavioural probe: NiDA
├── khmr_layout.csv               # Behavioural probe: legacy Khmer
├── macos/                        # macOS .keylayout layouts + installer
├── linux/                        # XKB layouts + installer + optional m17n
├── scripts/
│   ├── dump_kbd_tables.ps1       # Decode the DLL's KbdLayerDescriptor tables
│   ├── dump_layout.ps1           # Probe layout behaviour via ToUnicodeEx
│   ├── dump_layout_control.ps1   # Probe again with Control held
│   ├── verify_tables.ps1         # Assert the two paths agree (CI-friendly)
│   ├── verify_control.ps1        # Check secondary tables vs Control behaviour
│   ├── build_platform_layouts.ps1 # Generate the macOS + Linux layouts
│   ├── verify_platform_layouts.ps1 # Validate the generated platform files
│   ├── verify_all.ps1            # Rebuild and verify everything, one command
│   ├── build_unicode_names.ps1   # Refresh official Unicode character names
│   ├── export_nida_spec.ps1      # Build nida_layout.json
│   ├── render_docs.ps1           # Render markdown tables from the spec
│   ├── score_layout.ps1          # Measure stroke count and modifier load against corpus
│   ├── midpoint_engine.ps1       # Single source of truth for the Midpoint hybrid engine
│   ├── verify_midpoint.ps1       # Test suite for Midpoint static & sequence rules
│   └── data/unicode_names.json   # Curated UCD names for the layouts' characters
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

---

## Versioning

This project follows [Semantic Versioning 2.0.0](https://semver.org/) and
[Conventional Commits](https://www.conventionalcommits.org/). Release history
is in **[CHANGELOG.md](CHANGELOG.md)**, formatted per
[Keep a Changelog](https://keepachangelog.com/).

---

## License

MIT License. See [LICENSE](LICENSE).

