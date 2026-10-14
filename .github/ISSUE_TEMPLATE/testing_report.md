---
name: Testing Report
about: Report what actually happened when you installed the layout on macOS or Linux, or confirm it works
title: 'test: '
labels: ['needs triage']
assignees: ''
---

## Why this template exists

The macOS and Linux layouts were generated and checked **on Windows**, which is
the only machine involved in the analysis. Everything we verify automatically is
structural: XML well-formedness, no duplicate key codes, ligatures compared
byte-for-byte against the spec, XKB syntax, and the XKB key names validated
against `xkeyboard-config`.

That catches a broken file. It does **not** prove macOS or Linux will accept
it.

We have never loaded either layout on a real Mac or Linux machine. So this is
the most useful thing anyone can contribute - and "it works" is a genuinely
valuable report, not a wasted one.

## Platform and layout

- [ ] macOS
- [ ] Linux
- Layout: [Khmer NiDA / Khmer NiDA Legacy]

## Install method used
- [ ] `macos/install.sh` (per-user)
- [ ] `macos/make-pkg.sh` then the `.pkg`
- [ ] `linux/install.sh`
- [ ] Desktop settings GUI instead
- [ ] Something else: 

## Did the layout appear in the input-method menu?

- [ ] Yes, immediately
- [ ] Yes, after signing out and back in
- [ ] No

If no, that is a real bug and the most valuable thing you can report. Please
say what you searched for in the menu.

## Checklist

Please confirm as many as you can. A screenshot of typed output is ideal.

| Key | Expected | Works? |
| :-- | :-- | :-- |
| `J` | `U+17D2` coeng | |
| `Shift+J` | `U+1789` nyo | |
| `Space` | `U+200B` zero-width space | |
| `Shift+Space` | `U+0020` real space | |
| `AltGr+Space` | `U+00A0` NBSP | |
| `AltGr+1` | `U+200C` ZWNJ | |
| `A` | `U+17B6` | |
| `-` | `U+17A5` | |

### Ligatures

macOS reproduces all five; Linux cannot (XKB allows one character per level)
and `linux/m17n/` is the opt-in alternative.

| Key | Expected | macOS | Linux |
| :-- | :-- | :-- | :-- |
| `Shift+A` | `U+17B6 U+17C6` ាំ | | |
| `Shift+V` | `U+17C1 U+17C7` េះ | | |
| `Shift+;` | `U+17C4 U+17C7` ោះ | | |
| `,` | `U+17BB U+17C6` ុំ | | |
| `Shift+,` | `U+17BB U+17C7` ុះ | | |

## Environment
- OS and version: [e.g., Ubuntu 24.04 / macOS 15.1]
- Desktop environment: [e.g., GNOME 47 / Plasma 6 / not applicable]
- Keyboard: [e.g., ANSI 104-key]
- Layout source: [release version / `main` branch / installed from a zip]

## Anything else
Paste any output that looked wrong, and any error message. If something broke,
say whether it broke the whole desktop input or only this layout.