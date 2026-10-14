---
name: Bug Report
about: Something is wrong with the layout data, the decoded tables, the scripts, or a generated macOS/Linux layout
title: 'fix: '
labels: ['bug', 'needs triage']
assignees: ''
---

## Which layout

Two variants ship. They are **not** interchangeable - they differ on about
eight keys:

- [ ] **Khmer NiDA** (`kbdkni.dll`, KLID `00010453`) - coeng on `J`, ZWSP on `Space`
- [ ] **Khmer NiDA Legacy** (`kbdkhmr.dll`, KLID `00000453`) - coeng on `Space`, ZWSP on `/`
- [ ] Not layout-specific (scripts, docs, tooling)

## Affected Component
- [ ] **Table decode** (`scripts/dump_kbd_tables.ps1`)
- [ ] **Specification data** (`nida_layout.json`, `tables_kbd*.json`)
- [ ] **macOS layout** (`macos/*.keylayout`)
- [ ] **Linux XKB layout** (`linux/nida`, `linux/nida_legacy`)
- [ ] **Linux m17n input method** (`linux/m17n/`)
- [ ] **Installer** (`macos/install.sh`, `macos/make-pkg.sh`, `linux/install.sh`)
- [ ] **Documentation** (`README.md`, `REVERSE_ENGINEERING_NIDA.md`, `CONTRIBUTING.md`)
- [ ] Other (please describe below)

> If the macOS or Linux layout does not load at all, or does not appear in the
> input-method menu, use this template - that is the class of bug our
> automated checks cannot catch. Please do report it.

## Expected Behavior vs Actual Behavior
- **Expected**: e.g., key `X` with modifier `Shift` emits `Y` (`U+XXXX`)
- **Actual**: e.g., key `X` emits `Z` (`U+YYYY`), emits nothing, or the layout
  fails to load

## Key & Code Point Information (if applicable)
- **Key (US QWERTY)**: e.g., `J`, `Shift+A`, `AltGr+1`
- **Virtual Key (VK)**: e.g., `VK_J (0x4A)`
- **Scan Code (SC)**: e.g., `0x24`
- **Expected Unicode Code Point(s)**: e.g., `U+17D2` (្)
- **Observed Output**: 

## Steps to Reproduce
1. Run `...`
2. Inspect `...`
3. Notice mismatch at `...`

For a macOS or Linux layout bug, please say how you installed it:

```
# Linux
cd linux && ./install.sh nida && ./verify.sh

# macOS
cd macos && ./install.sh
```

## Environment & OS
- OS: [e.g., Windows 11 26H2 / macOS 15.x Sequoia / Ubuntu 24.04 / Fedora 40]
- Desktop / DE: [e.g., GNOME 47 / KDE Plasma 6 / Windows 11]
- If Windows: driver version, e.g. `kbdkni.dll 10.0.26100.2454`
- PowerShell / Runtime: [e.g., PowerShell 5.1 / 7.4]
- Output of `./scripts/verify_all.ps1 -SkipRegenerate`, if you ran it

## Did the automated checks pass?
Paste the last line, e.g. `ALL CHECKS PASSED` or the failing check.

This tells us whether the bug is in the data or in the generated platform
files, which is the first thing we check.

## Additional Context
Add any other context, screenshots, or logs here.
