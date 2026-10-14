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
| Cross-check: both paths must agree exactly | `scripts/verify_tables.ps1` |

**Result: 144 of 144 comparisons agree, zero mismatches.**

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
- Multi-character output is keyed by `(virtual key, modifier number)`, not as a
  chord string - getting this wrong reverses the two code points.

Full details, including the exact binary layout of every table, are in
**[REVERSE_ENGINEERING_NIDA.md](REVERSE_ENGINEERING_NIDA.md)**.

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
├── scripts/
│   ├── dump_kbd_tables.ps1       # Decode the DLL's KbdLayerDescriptor tables
│   ├── dump_layout.ps1           # Probe layout behaviour via ToUnicodeEx
│   ├── verify_tables.ps1         # Assert the two paths agree (CI-friendly)
│   ├── build_unicode_names.ps1   # Refresh official Unicode character names
│   ├── export_nida_spec.ps1      # Build nida_layout.json
│   ├── render_docs.ps1           # Render markdown tables from the spec
│   └── data/unicode_names.json   # Curated UCD names for the layouts' characters
├── .gitignore
└── README.md
```

---

## Reproducing

```powershell
# 1. decode the driver tables
.\scripts\dump_kbd_tables.ps1 -Dll kbdkni.dll
.\scripts\dump_kbd_tables.ps1 -Dll kbdkhmr.dll
.\scripts\dump_kbd_tables.ps1 -Dll kbdus.dll

# 2. probe the layouts behaviourally
.\scripts\dump_layout.ps1

# 3. prove the decode is correct (non-zero exit on any mismatch)
.\scripts\verify_tables.ps1 -TablesCsv tables_kbdkni.csv -ProbeCsv kni_layout.csv

# 4. rebuild the specification
.\scripts\build_unicode_names.ps1
.\scripts\export_nida_spec.ps1
```

Requires Windows (the tools load the driver DLLs and call Windows keyboard APIs)
and Windows PowerShell 5.1 or later.

---

## Versioning

This project follows [Semantic Versioning](https://semver.org/) and
[Conventional Commits](https://www.conventionalcommits.org/).

## License

MIT License. See [LICENSE](LICENSE).
