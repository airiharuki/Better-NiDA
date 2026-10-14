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

## Artifacts

| File | Contents |
| :-- | :-- |
| [REVERSE_ENGINEERING_NIDA.md](REVERSE_ENGINEERING_NIDA.md) | Full technical specification and findings |
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
[Conventional Commits](https://www.conventionalcommits.org/).

---

## License

MIT License. See [LICENSE](LICENSE).

