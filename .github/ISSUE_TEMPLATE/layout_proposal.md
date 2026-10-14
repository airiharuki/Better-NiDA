---
name: Layout Proposal / Ergonomic Improvement
about: Propose an ergonomic modification, key relocation, or alternate typing flow (e.g. skipping space / auto-ZWSP)
title: 'feat(layout): '
labels: ['enhancement', 'layout design']
assignees: ''
---

## Proposal Summary
A concise overview of the proposed layout change or typing mechanism.

## Problem Statement & Motivation
What ergonomic problem, typing fatigue, or friction does this address in standard Khmer NiDA?
*(e.g., frequent modifier chording, excessive finger travel, awkward hand jumps, repetitive spacebar tapping for ZWSP)*

## Proposed Design / Mechanism
Detailed explanation of the new behavior:
- **Keys / Layers Modified**: Which physical keys, layers, or combos are changed?
- **Typing Flow / Mechanics**: How does this improve typing rhythm? (e.g., auto-spacing rules, syllable boundaries, skipping space)
- **Khmer Orthography Compliance**: How does this handle Khmer consonant clusters, subscript Coeng (`្`), and independent vowels?

## Comparison with Standard NiDA
| Key / Context | Standard NiDA Behavior | Proposed Better-NiDA Behavior | Ergonomic Rationale |
| :--- | :--- | :--- | :--- |
| *e.g., Spacebar* | Emits ZWSP `U+200B` | Automated insertion / alternate key | Eliminates manual spacebar press per word |

## Target Platforms
- [ ] Windows (Win32 / MSKLC / IME)
- [ ] macOS (`.keylayout` / Input Method)
- [ ] Linux (XKB / m17n / IBus / Fcitx)
- [ ] Keyboard Firmware (QMK / ZMK / Kanata / KMonad)
- [ ] Web / Mobile

## References & Frequency Data
Include any linguistic references, Khmer n-gram/letter frequency data, or keyboard heatmaps supporting this proposal.
