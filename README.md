# Better-NiDA

An improved, modern, and ergonomic evolution of the standard **Khmer NiDA** keyboard layout.

## Background

The Khmer NiDA keyboard layout (National Information Communications Technology Development Authority) has been the national standard for typing the Khmer script on modern computing platforms. In Windows, it is distributed as the system driver `kbdkni.dll` (KLID `00010453`).

**Better-NiDA** begins by completely reverse-engineering the native Windows NiDA driver down to its raw virtual keys, scan codes, modifier tables, and composite ligatures, serving as the foundational reference specification for modern ergonomics and improvements.

---

## Reverse Engineering Documentation & Data

- 📖 **[Reverse Engineering Specification](REVERSE_ENGINEERING_NIDA.md)**: In-depth technical breakdown of `kbdkni.dll` vs legacy `kbdkhmr.dll`, modifier states, ligatures, and zero-width character behaviors.
- 📋 **[nida_layout.json](nida_layout.json)**: Machine-readable schema mapping all scan codes, virtual keys, characters, Unicode code points, and multi-codepoint ligature definitions.
- 📊 **[kni_layout.csv](kni_layout.csv)**: Full tabular dump extracted directly from `kbdkni.dll`.
- 📊 **[khmr_layout.csv](khmr_layout.csv)**: Comparison tabular dump extracted from `kbdkhmr.dll`.

---

## Key NiDA Architectural Principles

1. **Subscript Generator (Coeng / ជើង)**: Key `J` (`U+17D2`).
2. **Invisible Word Separation**: Spacebar produces Zero-Width Space (`U+200B`).
3. **Visible Space**: `Shift + Space` produces regular ASCII space (`U+0020`).
4. **Native Ligatures**:
   - `Shift + A` $\rightarrow$ `ាំ` (`U+17B6` + `U+17C6`)
   - `Shift + V` $\rightarrow$ `េះ` (`U+17C1` + `U+17C7`)
   - `Shift + ;` $\rightarrow$ `ោះ` (`U+17C4` + `U+17C7`)
   - `,` (Comma) $\rightarrow$ `ុំ` (`U+17BB` + `U+17C6`)
   - `Shift + ,` $\rightarrow$ `ុះ` (`U+17BB` + `U+17C7`)

---

## Repository Structure

```
Better-NiDA/
├── REVERSE_ENGINEERING_NIDA.md  # Detailed technical documentation
├── nida_layout.json             # Complete layout specification (JSON)
├── kni_layout.csv               # Extracted Windows NiDA key mappings (CSV)
├── khmr_layout.csv              # Extracted Windows Legacy Khmer key mappings (CSV)
├── scripts/
│   ├── dump_layout.ps1          # Tool to inspect and dump Win32 keyboard layouts
│   └── export_nida_spec.ps1     # Generator for nida_layout.json
├── .gitignore
└── README.md
```

---

## Versioning & Commits

This project adheres to:
- **[Semantic Versioning 2.0.0](https://semver.org/)** (`MAJOR.MINOR.PATCH`)
- **[Conventional Commits](https://www.conventionalcommits.org/en/v1.0.0/)** (`feat:`, `fix:`, `docs:`, `chore:`, etc.)

---

## License

MIT License. See [LICENSE](LICENSE) for details.
