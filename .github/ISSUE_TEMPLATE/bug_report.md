---
name: Bug Report
about: Report a problem with layout tables, decoded characters, scripts, or platform behavior
title: 'fix: '
labels: ['bug', 'needs triage']
assignees: ''
---

## Description
A clear and concise description of what the issue is.

## Affected Component
- [ ] Table decode (`scripts/dump_kbd_tables.ps1` / `verify_tables.ps1`)
- [ ] Specification data (`nida_layout.json` / `tables_kbdkni.json`)
- [ ] Documentation (`REVERSE_ENGINEERING_NIDA.md` / `README.md`)
- [ ] Platform implementation (Windows / macOS / Linux / Firmware)
- [ ] Other (please describe below)

## Expected Behavior vs Actual Behavior
- **Expected**: e.g., Key `X` with modifier `Shift` should emit character `Y` (`U+XXXX`)
- **Actual**: e.g., Key `X` emits character `Z` (`U+YYYY`) or does not match native behavior

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

## Environment & OS
- OS: [e.g., Windows 11 23H2 / macOS Sonoma / Linux Ubuntu 24.04]
- Driver Version / DLL: [e.g., Windows native kbdkni.dll 10.0.22621]
- PowerShell / Runtime: [e.g., PowerShell 5.1 / 7.4]

## Additional Context
Add any other context, screenshots, or logs here.
