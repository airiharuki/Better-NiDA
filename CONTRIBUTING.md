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

The project uses PowerShell and Win32 interop scripts to decode and cross-verify layout tables directly against Windows keyboard binaries.

### Prerequisites
- Windows 10/11 with PowerShell 5.1+ or PowerShell 7+
- Git

### Verifying Layout Consistency
Before submitting a pull request that alters table data or decoding scripts, run the validation suite to ensure 100% parity with native drivers:

```powershell
# Cross-check decoded tables against Win32 ToUnicodeEx API
powershell -ExecutionPolicy Bypass -File scripts/verify_tables.ps1

# Regenerate complete nida_layout.json spec
powershell -ExecutionPolicy Bypass -File scripts/export_nida_spec.ps1
```

All checks should pass with **0 mismatches**.

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

1. **`MAJOR`**: Incompatible layout changes (e.g., breaking key repositioning, major remapping of primary characters).
2. **`MINOR`**: Backwards-compatible functionality (e.g., new secondary layers, extra ligature definitions, new platform export formats).
3. **`PATCH`**: Backwards-compatible bug fixes and documentation improvements (e.g., table corrections, typo fixes, script improvements).

Git tags follow the format: `v<MAJOR>.<MINOR>.<PATCH>` (e.g., `v0.1.0`, `v0.2.0`).

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
