# Contributing to Better-NiDA

Thank you for your interest in contributing to **Better-NiDA**! We welcome contributions from developers, linguists, typographers, and keyboard enthusiasts to help design a more modern, ergonomic, and seamless typing experience for the Khmer language.

Please take a moment to review this document to ensure a smooth collaboration process.

---

## Code of Conduct

This project is governed by the [Contributor Covenant Code of Conduct](CODE_OF_CONDUCT.md). By participating in this project, you are expected to uphold this code. Please report any unacceptable behavior to [sovannreachmakara@outlook.com](mailto:sovannreachmakara@outlook.com).

---

## How Can I Contribute?

- **Proposing Ergonomic Enhancements**: Share data, letter frequency analyses, or typing dynamics for modern Khmer script.
- **Improving Layout Data**: Refine mappings, add support for missing characters, or expand phonetic mnemonics.
- **Cross-Platform Implementations**: Help compile or port Better-NiDA to macOS (`.keylayout`), Linux (`xkb` / `m17n`), firmware (`QMK`/`ZMK`/`Kanata`), and mobile IMEs.
- **Tooling & Validation**: Enhance test coverage, cross-validation scripts, or automated CI pipelines.
- **Documentation**: Improve guides, tutorials, and reverse-engineering notes.

---

## Development & Verification Workflow

The project decodes the Windows driver tables and cross-checks them against
the Windows `ToUnicodeEx` API, then generates the macOS and Linux layouts from
that verified spec. Everything is driven by PowerShell scripts on Windows.

### Prerequisites

- **Windows** 10/11 with PowerShell 5.1+ or PowerShell 7+, to run the full chain
- Git

The analysis toolchain is **Windows-only and cannot be ported**. It reads
`C:\Windows\System32\kbdkni.dll` via `kernel32!LoadLibrary` and calls its
`KbdLayerDescriptor` export, then uses `user32!ToUnicodeEx` and
`MapVirtualKeyEx` as the oracle. Neither the driver nor those APIs exist on
macOS or Linux.

| Needs Windows | Runs anywhere |
| :-- | :-- |
| `dump_kbd_tables.ps1` | `verify_tables.ps1` |
| `dump_layout.ps1` | `verify_control.ps1` |
| `dump_layout_control.ps1` | `verify_platform_layouts.ps1` |
| `export_nida_spec.ps1` | `build_unicode_names.ps1` (needs network) |
| `build_platform_layouts.ps1` | `render_docs.ps1` |

`verify_all.ps1` drives the Windows-only scripts, so it only completes on
Windows - run the portable ones individually elsewhere.

**If you are on macOS or Linux**, you can still do useful work: the five
right-hand scripts run anywhere, the platform layouts are plain files you can
edit and test, and testing them on real hardware is what we most need. See
*Testing on real hardware* below.

### One command

```powershell
pwsh ./scripts/verify_all.ps1
```

This regenerates **everything** - the decoded tables, both behavioural probes,
the Unicode name table, `nida_layout.json`, and the macOS + Linux layouts - and
then runs four checks. It exits non-zero if any stage or check fails, so it is
safe to run in CI.

```
1-3  decode driver tables (kbdkni, kbdkhmr, kbdus)
4-6  probe layout behaviour, with and without Control
7    refresh official Unicode character names
8    rebuild nida_layout.json
9    generate the macOS .keylayout and Linux XKB files
CHECK  NiDA tables vs ToUnicodeEx        144/144, 0 mismatches
CHECK  legacy Khmer tables vs ToUnicodeEx 144/144, 0 mismatches
CHECK  secondary tables vs Control        4/4
CHECK  macOS + Linux layout files         structural
```

To verify the committed artifacts without regenerating them:

```powershell
pwsh ./scripts/verify_all.ps1 -SkipRegenerate
```

### The generator is the source of truth

`macos/*.keylayout`, `linux/nida` and `linux/nida_legacy` are **generated**
files. Editing them by hand works today but is overwritten on the next run.
Change `scripts/build_platform_layouts.ps1` instead, and re-run the chain.

The same applies to `nida_layout.json` and the `tables_kbd*.json` files.

### What the checks do and do not prove

The four checks are real, and a failure is meaningful. But be precise about
what they cover:

- The three Windows checks compare the decoded tables against the Windows
  `ToUnicodeEx` API. They prove the decode is faithful **to Windows**.
- The platform check validates structure only: XML well-formedness, no
  duplicate key codes, a non-empty base layer, ligatures compared byte-for-byte
  against `nida_layout.json`, XKB brace and level sanity, and every base symbol
  present.

**None of them loads a layout on macOS or Linux.** The analysis host is Windows
(26H2, build 26300.9550) and no Mac or Linux machine has been involved. If you
have one, see below - it is the most useful contribution available.

### Testing on real hardware

| Platform | How to check |
| :-- | :-- |
| Linux | `cd linux && ./install.sh && ./verify.sh` - prints the active keymap and a key checklist |
| macOS | `cd macos && ./install.sh`, then the checklist in `macos/README.md` |

Please report what you find - even "it works" is worth recording, and "it does
not appear in the menu" is exactly the kind of bug structural checks cannot
catch. Use the *Testing Report* issue template.

---

## Commit Guidelines (Conventional Commits)

We enforce the **[Conventional Commits specification](https://www.conventionalcommits.org/en/v1.0.0/)** (v1.0.0). Every commit message must follow this structure:

```
<type>[optional scope]: <description>

[optional body]

[optional footer(s)]
```

### Allowed Types

| Type | Purpose | Example |
| :--- | :--- | :--- |
| `feat` | A new feature or layout capability | `feat(layout): add automatic zero-width space emission rule` |
| `fix` | A bug fix in tables, scripts, or outputs | `fix(decode): correct Slot0 neutral naming for control keys` |
| `docs` | Documentation changes only | `docs: add CONTRIBUTING.md and CODE_OF_CONDUCT.md` |
| `refactor` | Code change that neither fixes a bug nor adds a feature | `refactor(scripts): modularize Win32 pinvoke wrappers` |
| `perf` | Code change that improves performance | `perf(validator): accelerate table comparison loop` |
| `test` | Adding missing tests or correcting existing tests | `test(tables): add cross-validation for numpad states` |
| `chore` | Maintenance tasks, repository configs, dependencies | `chore: update .gitignore and release tooling` |

### Rules
- Use imperative, present tense ("add", not "added" or "adds").
- Do not capitalize the first letter of the subject line.
- Do not place a period at the end of the subject line.
- Provide background reasoning in the commit body if the change is non-trivial.

---

## Versioning Policy (Semantic Versioning)

Better-NiDA adheres strictly to **[Semantic Versioning 2.0.0](https://semver.org/)** (`MAJOR.MINOR.PATCH`):

1. **`MAJOR`**: Incompatible layout changes (e.g., breaking key repositioning, major remapping of primary characters). Also a change that alters any generated artifact - `nida_layout.json`, `macos/*.keylayout`, `linux/nida*` - in a way that changes what a user types.
2. **`MINOR`**: Backwards-compatible functionality (e.g., new secondary layers, extra ligature definitions, a new platform target such as QMK/ZMK firmware).
3. **`PATCH`**: Backwards-compatible bug fixes and documentation improvements (e.g., table corrections, tooling fixes, documentation).

Because the platform layouts are generated from the spec, a change to
`scripts/` that alters the generator's output is a user-visible layout change:
judge it as MAJOR or MINOR, not PATCH, even though the diff may look small.

Git tags follow the format: `v<MAJOR>.<MINOR>.<PATCH>` (e.g., `v0.1.0`, `v0.2.0`).

### Changelog

[CHANGELOG.md](CHANGELOG.md) follows [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
grouped by release with an `[Unreleased]` section at the top.

When cutting a release:

1. Move everything under `[Unreleased]` into a new version heading, and add the
   compare link at the bottom.
2. Tag the commit: `git tag -a vX.Y.Z -m "..."`, then `git push origin vX.Y.Z`.
3. Create the GitHub release with `gh release create`, and attach any build
   artifacts to it.

Because the layouts are generated, judge the bump by what a user types, not by
how large the diff is - see the versioning policy above.

---

## Pull Request Process

1. **Fork & Branch**: Create a feature or fix branch from `main`:
   ```bash
   git checkout -b feat/ergonomic-home-row
   ```
2. **Make Focused Commits**: Keep commits atomic and use Conventional Commit messages.
3. **Run Validation**: Ensure `scripts/verify_tables.ps1` passes cleanly.
4. **Update Documentation**: If modifying mappings or features, update `README.md` or `REVERSE_ENGINEERING_NIDA.md`.
5. **Open a PR**:
   - Provide a clear summary of what was changed and why.
   - Reference any related issues (e.g., `Closes #12`).
   - Confirm that all scripts pass without regressions.

---

## Questions or Ideas?

Feel free to open an issue or discussion on GitHub to share suggestions or discuss keyboard layout ergonomics!
