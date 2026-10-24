# Changelog

All notable changes to Better-NiDA are recorded here.

The format follows [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
versions follow [Semantic Versioning](https://semver.org/spec/v2.0.0.html), and
commit messages follow
[Conventional Commits](https://www.conventionalcommits.org/en/v1.0.0/).

Because the macOS and Linux layouts are *generated from* the specification, a
change that alters what a user types is versioned by its effect on typing, not
by the size of the diff.

---

## [Unreleased]

### Added

- Nothing yet.

---

## [0.5.0] - 2026-10-24

### Added

- **Bold Hybrid Rearrangement (Khmerism speed + NiDA accessibility):**
  - Promoted the 6 high-frequency second-series consonants (`ជ` on `Q`, `ទ` on `F`,
    `ព` on `P`, `គ` on `X`, `ញ` on `Z`, `អ` on `-`), dependent vowel `ៃ` (`=`),
    and word-final marks `ំ` (`]`) and `ះ` (`\`) directly onto unshifted Normal
    keys.
  - Displaced low-frequency aspirated consonants and independent vowels (`ឆ`, `ថ`,
    `ផ`, `ខ`, `ឋ`, `ឥ`, `ឲ`, `ឪ`, `ឮ`) are preserved on `AltGr` (`Option`) and
    via `/` sequences (`q/`, `f/`, `p/`, `x/`, `zz`, `--/`, `=/`, `]]`, `\\/`),
    while displaced `AltGr` characters (`ឰ` on `AltGr+Y`, `ឳ` on `AltGr+U`, `៎`
    on `AltGr+K`, `\` on `AltGr+V`, `×` on `AltGr+W`) are rescued onto previously
    empty `AltGr` slots for 100% character repertoire parity.
- **100% Universal `/` Command (91 sequence rules):**
  - Expanded contextual `/` rules across all 49 keys so every vowel, diacritic,
    punctuation mark, and number key responds to `KEY + /` in addition to
    double-tap `KEY + KEY` (`i/` or `ii` → `ី`, `u/` or `uu` → `ូ`, `e/` or `ee`
    → `ែ`, `w/` or `ww` → `ឺ`, `o/` or `oo` → `ៅ`, `a/` or `aa` → `ាំ`, `[/` or
    `[[` → `ឿ`, `;/` or `;;` → `ោះ`, `,/` or `,,` → `ុះ`, `'/` or `''` → `៉`,
    `./` or `..` → `៕`, `]/` → `ឧ`, `\/` → `ៈ`, `` `/ `` → `»`, `//` → `?`,
    `1/`..`0/` → `!`..`)`).
  - Preserved 100% of stock NiDA `/` series flips (`k/`→`គ`, `t/`→`ទ`, `b/`→`ព`,
    `c/`→`ជ`, `g/`→`អ`, `jj`→`ញ`, `j/`→`្ញ`) alongside the new 1-key Bold Hybrid
    bindings.
- **Smart Syllable Reordering & Anti-Glitch Normalization:**
  - Added intelligent contextual reordering rules in Keyman (`windows/better_nida_midpoint.kmn`)
    and the engine (`scripts/midpoint_engine.ps1`) that automatically swap visual
    mis-types into canonical Unicode order (e.g. vowel before subscript `kejr` → `ក្រេ`,
    vowel before shifter `ba'/` → `ប៉ា`, and word-start pre-base vowel `ek` → `កេ`),
    eliminating broken dotted circles (`◌`) while protecting syllable-final consonants.
- **Visual Layout Guide (`docs/better_nida_layout_guide.png` & `.pdf`):**
  - Added 300-DPI PNG and vector PDF 1-to-1 reference charts styled after the
    classic 2005 NiDA Standard Khmer Unicode Keyboard poster, stamped with V 0.5.0.

---

## [0.4.0] - 2026-10-22

### Added

- **Better-NiDA Midpoint engine, specification, and cross-platform targets:**
  - `scripts/midpoint_engine.ps1`: Single source of truth for the Better-NiDA
    Midpoint layout, combining static layer remapping (Rules 2, 4, 5) and
    prefix-buffered / contextual sequence rules (Rules 1, 2, 3).
  - `scripts/export_midpoint_spec.ps1` and `midpoint_layout.json`: Machine-readable
    Midpoint specification with 49 keys across 5 modifier levels and 51 sequence
    rules.
  - `windows/better_nida_midpoint.kmn` and `windows/better_nida_midpoint.kps`:
    Keyman keyboard source and package descriptor using zero-lag inline
    contextual replacement (`U+1780 + [K_SLASH] > U+1782`), compiled via
    `@keymanapp/kmc` into `better_nida_midpoint.kmp`, `.kmx`, and `.js`.
  - `scripts/build_windows_runner.ps1`: Compiles a zero-dependency standalone
    Windows executable (`BetterNiDA-Midpoint-Windows.exe`) directly from
    `midpoint_layout.json`, featuring a built-in live typing sandbox, Unicode
    codepoint inspector, and a system-wide low-level keyboard hook toggle
    (`Ctrl+Shift+Space`).
  - `linux/m17n/nida-midpoint.mim`: Linux m17n input method implementing the full
    sequence and static rule set.
  - `linux/nida_midpoint` and `macos/Khmer Better-NiDA.keylayout`: Static-subset
    XKB (`EIGHT_LEVEL`) and macOS (5-`<keyMap>`) layouts with `Shift+AltGr`
    (`Shift+Option`) carrying the 13 second-series consonants.
  - `scripts/analyze_corpus.py`, `scripts/score_midpoint.ps1`, and
    `scripts/data/coeng_pairs.json`: 565.4M-character Khmer corpus analysis and
    shortest-path KSPC / modifier load scorer.
  - `scripts/verify_midpoint.ps1`: 16-check verification suite covering the
    keystroke matrix (`T01`–`T11`) and 100% additive backward-compatibility
    guardrails.

### Fixed

- `scripts/midpoint_engine.ps1`: Fixed `Resolve-Sequence` to check
  `Test-PendingPrefix` before `Get-ExactRule` and updated `Add-Commit` to resolve
  longest exact rules left-to-right before falling back to single keys. This
  restores `jj`→`ញ` (`U+1789`), `jj/`→`ញ៉` (`U+1789 U+17C9`), and 2-key `j/`→`្ញ`
  (`U+17D2 U+1789`) without `AltGr+J` clunkiness or cluster collisions.
- `scripts/midpoint_engine.ps1`: Rescued `ឳ` (`U+17B3`, displaced from `AltGr+]`)
  onto `AltGr+U` (unmapped in stock NiDA) for 100% character repertoire parity,
  and added unshifted sequences for `Space` (`  ` / ` /` → `U+0020`), `ួ`
  (`ua` / `u/`), `ៃ` (`ai` / `i/`), and number-row diacritics, cutting `Shift`
  share from 24.3% to 0.5% (−97.5%) and lowering KSPC from 1.236 to 1.222.
- `scripts/score_midpoint.ps1`: Fixed `Build-Index` so stock NiDA is scored
  without Midpoint's static overrides, and added modifier tie-breaking to
  `Measure-Text`.

---

## [0.3.1] - 2026-10-14

### Added

- **Self-contained installers as release assets.** `install-nida.sh` (Linux) and
  `install-nida-macos.command` (macOS, double-clickable) each embed the layout
  data, so installing no longer requires cloning the repository. The payload is
  embedded as a quoted heredoc rather than base64, keeping the layout readable
  inside the installer and editable after install.
- `scripts/build_installers.ps1` builds and validates those installers: `bash -n`
  for syntax, and each embedded payload extracted with the same `sed` the
  installer uses and compared byte-for-byte against the source layout.
- A **Testing Report** issue template, and a `config.yml` contact link pointing
  at it. The layouts have never been loaded on real hardware, so a short report
  from a Mac or Linux box is the most useful contribution available.

### Fixed

- The scripts no longer call `LoadKeyboardLayout` with `KLF_ACTIVATE`, and
  unload the handle afterwards. Repeated runs were accumulating duplicate Khmer
  and English entries in the user's input-method list. Activation was never
  needed: `ToUnicodeEx` and `MapVirtualKeyEx` both take the handle explicitly.

### Changed

- Issue templates, `README.md` and `CONTRIBUTING.md` now describe what the
  project actually does, including the two layout variants and the platform
  constraints that decide whether a layout proposal is feasible.
- The reverse-engineering toolchain is documented as **Windows-only and not
  portable**, with the exact split between the five scripts that call Win32 and
  the five that are portable.

### Notes on the version number

This release adds no new typing behaviour: the layout files themselves shipped
in 0.3.0, and this changes only how they are delivered. It also carries a bug
fix. That reads as a PATCH, hence 0.3.1.

A stricter reading of the MINOR clause ("new backwards-compatible
functionality") would call downloadable installers a new capability and put
this at 0.4.0. The judgement made here is that the *capability* is the layout,
not its packaging. Easy to renumber if you disagree.

---

## [0.3.0] - 2026-10-14

### Added

- **Khmer NiDA keyboard layouts for macOS and Linux**, in both the NiDA and
  legacy Khmer variants, generated from the verified specification rather than
  transcribed by hand.
  - macOS: Apple `.keylayout` bundles with the standard modifier map. A macOS
    keylayout can emit several characters per key press, so **all five ligatures
    are reproduced faithfully**.
  - Linux: XKB `symbols` files, `FOUR_LEVEL` for NiDA and `EIGHT_LEVEL` for the
    legacy layout, covering Normal / Shift / Control / AltGr / Shift+AltGr.
  - `linux/m17n/`, a ligature-capable input method for anyone who needs the
    compound marks on Linux, where XKB cannot express them.
  - Installers: `linux/install.sh` (per-user, no root) and `macos/install.sh`,
    plus `macos/make-pkg.sh` which builds a double-clickable `.pkg`.
  - `scripts/build_platform_layouts.ps1` generates both platforms from one
    script, so the variants cannot drift apart.
  - `scripts/verify_platform_layouts.ps1` validates the output structurally.
- `scripts/verify_all.ps1` rebuilds and re-verifies the whole chain in one
  command, exiting non-zero on any failure. `-SkipRegenerate` verifies the
  committed artifacts for CI.

### Fixed

- Shell scripts and `.keylayout` files are pinned to LF in `.gitattributes`.
  `core.autocrlf=true` would have rewritten the shebangs to `bash\r`, breaking
  every installer for anyone cloning from Windows.
- The XKB symbols files are no longer generated with CRLF endings.
  `StringBuilder.AppendLine()` uses `Environment.NewLine`, and the files have no
  extension so no `.gitattributes` wildcard matched them either.

### Known limitations

- The generated layouts were **produced and structurally checked on Windows**
  (the analysis host) and have **not** been loaded on macOS or Linux. Validation
  covers syntax, structure and data, not OS acceptance.
- On Linux, XKB allows one character per key per level, so the five ligature
  keys emit only their first code point. The affected lines are marked
  `LIGATURE truncated`.

---

## [0.2.1] - 2026-10-14

### Added

- Issue templates for bug reports, feature requests and layout proposals, plus
  a `config.yml` routing general questions to Discussions.
- Labels `needs triage` and `layout design` on the repository. GitHub silently
  drops unknown labels, so the bug and proposal workflows would not have been
  applied without them.

---

## [0.2.0] - 2026-10-14

### Added

- `nida_layout.json` regenerated from the verified table decode rather than by
  the previous, broken exporter, which silently produced an empty spec while
  reporting success.
- `CONTRIBUTING.md` and `CODE_OF_CONDUCT.md`.

### Fixed

- Scan codes are resolved by inverting scan code to virtual key rather than
  asking for virtual key to scan code: F7 through F10 share virtual keys with
  the letters A to D, and the direct query reported the wrong key.
- The modifier documentation no longer describes modifier bits as if they were
  Windows virtual keys. The real mapping is bit to modifier number:
  0→0, 1→1, 2→2, 3/4/5→invalid, 6→AltGr.
- Secondary-table slots are labelled neutrally (`Slot0`, `Slot1`). Only the main
  character table is verified to be indexed by modifier number.

---

## [0.1.0] - 2026-10-14

### Added

- Reverse engineering of the Khmer NiDA layout from `kbdkni.dll`, and of the
  legacy Khmer layout from `kbdkhmr.dll`.
- `REVERSE_ENGINEERING_NIDA.md`: the full binary specification - descriptor
  layout, the four character sub-tables, entry format, reserved values, the
  ligature table, modifier numbering, and the complete character matrix.
- `nida_layout.json`, `tables_kbd*.json`, and behavioural probe CSVs.
- `scripts/` to decode the driver tables and cross-check them against the
  Windows `ToUnicodeEx` API.

### Notes

- The first pass inferred the binary format by hand and got the descriptor
  offsets wrong, reading the ligature fields from `+0x72` and producing an
  invalid pointer. Corrected in 0.3.0-era work by decoding the tables directly.

---

## Verification status

Reported alongside each release because the claims are specific:

| Claim | Basis |
| :-- | :-- |
| Table decode is faithful to Windows | 144/144 `ToUnicodeEx` comparisons per Khmer layout, 0 mismatches |
| Table 0 slot 2 is the Control character | 4/4 with Control held |
| Generated artifacts are reproducible | byte-identical after a clean run of the full chain |
| macOS layouts are well-formed and complete | XML validity, no duplicate key codes, non-empty base layer, 5/5 ligatures |
| Linux symbols are syntactically valid | brace/level sanity, key names validated against `xkeyboard-config` |
| **Layouts work on macOS / Linux** | **Not established — never loaded on either OS** |

The last row is the important one. Everything above it can be checked on a
Windows machine; that one cannot.

[Unreleased]: https://github.com/airiharuki/Better-NiDA/compare/v0.5.0...HEAD
[0.5.0]: https://github.com/airiharuki/Better-NiDA/compare/v0.4.0...v0.5.0
[0.4.0]: https://github.com/airiharuki/Better-NiDA/compare/v0.3.1...v0.4.0
[0.3.1]: https://github.com/airiharuki/Better-NiDA/compare/v0.3.0...v0.3.1
[0.3.0]: https://github.com/airiharuki/Better-NiDA/compare/v0.2.1...v0.3.0
[0.2.1]: https://github.com/airiharuki/Better-NiDA/compare/v0.2.0...v0.2.1
[0.2.0]: https://github.com/airiharuki/Better-NiDA/compare/v0.1.0...v0.2.0
[0.1.0]: https://github.com/airiharuki/Better-NiDA/releases/tag/v0.1.0