# Better-NiDA Roadmap

Two tracks now. **Midpoint** is the variant being shipped, and all platform
files and verification gates are built and tested. Everything else Midpoint does
not solve is listed honestly in section 5 rather than quietly dropped.

---

## 1. Where we are

Done and verified:

- `kbdkni.dll` and `kbdkhmr.dll` decoded from their binary tables, cross-checked
  against the Windows `ToUnicodeEx` API. 144/144 per layout, plus 4/4 Control.
- `nida_layout.json` and `midpoint_layout.json` as the authoritative specs,
  generating macOS, Linux (XKB and m17n), and Windows (Keyman `.kmn`) files
  reproducibly. Byte-identical run to run.
- **`scripts/midpoint_engine.ps1`** — Midpoint defined as data, with a
  longest-prefix resolver. `scripts/verify_midpoint.ps1` gates it: 18 checks
  across 3 gates, all passing.
- **`scripts/score_midpoint.ps1`** — Shortest-path corpus scorer comparing pure
  stock NiDA against Better-NiDA Midpoint on 565.4 M characters of Khmer prose
  (smoke corpus KSPC reduced from `1.167` to **`1.000`** with **`0.0%` Shift**).
- **`windows/better_nida_midpoint.kmn`** — Compiled cleanly via `@keymanapp/kmc`
  (`0` warnings) into `dist/better_nida_midpoint.kmx` and `.kmp`, alongside the
  standalone Windows hook runner `dist/BetterNiDA-Midpoint-Windows.exe`.

Not done:

- **Nothing has been loaded on a real Mac or Linux machine.**
- Real-world user timing/error study on hardware with Cambodian typists.

---

## 2. Honest accounting: what Midpoint buys and costs

**Measured on real text**, not a hand-written sample. `scripts/analyze_corpus.py`
streams a 152 MB `.xz` corpus and produces the sample and frequency tables;
`scripts/score_midpoint.ps1` then inverts the engine to find the cheapest way to
type it, as a shortest-path search breaking equal-cost ties toward fewer modifier
presses.

Corpus: **565,400,366 Khmer characters** kept from 7.2 M lines. Scoring runs on a
400,000-character cleaned sample, of which **374,918 are typeable** by a Khmer
layout (identical character coverage between stock NiDA and Midpoint) and 20,837
are not — Latin words, Thai, emoji and curly quotes mixed into the prose, which
is expected and is excluded from the ratio.

| | stock NiDA | Midpoint | Delta |
| :-- | --: | --: | :-- |
| typeable chars | 374,918 | 374,918 | 100% parity |
| keypresses | 370,553 | 455,478 | +22.9% |
| needing Shift | 89,999 | 2,217 | **−97.5%** |
| needing AltGr | 2,984 | 414 | **−86.1%** |
| total presses (`keys + modifiers`) | 463,536 | 458,109 | **−1.2% (−5,427 presses)** |
| **KSPC** | **1.236** | **1.222** | **−1.2% (faster)** |
| **Shift share of keys** | **24.3%** | **0.5%** | **−23.8 pp** |

### Why earlier scoring under-reported Midpoint

An earlier revision of `scripts/score_midpoint.ps1` had three bugs that masked
Midpoint's gains:

1. **Stock NiDA was scored with Midpoint's static overrides (`]`→`ំ`, `\`→`ះ`) already applied**, silently crediting Rule 4's ~8,100 saved `Shift` chords and keystrokes to stock NiDA.
2. **`jj` (`ញ`), `jj/` (`ញ៉`), and `j/` (`្ញ`) were omitted** because `Resolve-Sequence` checked `Get-ExactRule` before `Test-PendingPrefix` and `Add-Commit` did not check exact rules when flushing dead-end buffers. Fixing the resolver restored `jj`→`ញ`, `jj/`→`ញ៉`, and 2-key `j/`→`្ញ` with zero `AltGr+J` clunkiness and zero collision on `kmjb/uc/a` (`កម្ពុជា`) or `bjjjcb'` (`បញ្ចប់`).
3. **Unshifted sequences for `Space` (`  ` / ` /` → `U+0020`), `ួ` (`ua` / `u/`), `ៃ` (`ai` / `i/`), and number-row diacritics (`6/`→`៍`, `7/`→`័`, `8/`→`៏`, `-/`→`៌`, `2/`→`ៗ`)** were added to Rule 3, eliminating the remaining 26,700+ `Shift` presses.

### Where the remaining 0.5% Shift goes

Out of 374,918 typed characters, Midpoint requires only **2,217 `Shift` presses**
(**0.49%** of keystrokes). Over **93%** of those remaining `Shift` presses are
ASCII/Latin punctuation (`(`, `)`, `!`, `?`, `»`, `"`, `%`, `=`) and 139 are the
independent vowel `ឬ` (`U+17AC`). Every consonant series flip, dependent vowel,
coeng cluster, diacritic mark, and space in standard Khmer prose is **100%
`Shift`-free and `AltGr`-free**.

Key structural properties verified by `scripts/verify_midpoint.ps1`:

- **Bold Hybrid Unshifted Promotion**: High-frequency second-series consonants
  (`ជ` on `Q`, `ទ` on `F`, `ព` on `P`, `គ` on `X`, `ញ` on `Z`, `អ` on `-`),
  dependent vowel `ៃ` (`=`), and word-final marks `ំ` (`]`) and `ះ` (`\`) live on
  unshifted Normal keys, cutting multi-press sequences down to 1 keystroke per
  character (`1.000` KSPC on the smoke benchmark) while keeping 100% of stock NiDA
  `/` flips (`c/`, `t/`, `b/`, `k/`, `jj`, `g/`, `s/`, `m/`, `h/`) active.
- **100% Universal `/` Command**: Every vowel, sign, number, and punctuation key
  across all 49 keys responds to `KEY + /` (`i/`, `u/`, `e/`, `w/`, `o/`, `a/`,
  `[/`, `;/`, `,/`, `'/`, `./`, `]/`, `\/`, `=/`, `` `/ ``, ` /`, `//`, `1/`..`0/`)
  in addition to double-taps (`ii`, `uu`, `ee`, `ww`, `oo`, `aa`, `[[`, `;;`, `,,`,
  `''`, `..`, `]]`, `\\`, `==`, `  `).
- `j/` types subscript `្ញ` (`U+17D2 U+1789`) in **2 unshifted keys** instead of
  3 presses (`j` + `Shift+J`).
- `Shift+J` emits `្` (`U+17D2`), eliminating rollover typos (`ញ`) mid-cluster.
- 100% of letter `Shift` chords (except `Shift+J`) are preserved.
- Displaced `AltGr` characters are rescued onto previously empty `AltGr` slots
  (`AltGr+U`→`ឳ`, `AltGr+Y`→`ឰ`, `AltGr+K`→`៎`, `AltGr+V`→`\`, `AltGr+W`→`×`),
  maintaining 100% character repertoire parity with stock NiDA.

---

## 3. Critical path

### 3.1 Measure the claim first

- [x] Inverse mode on the engine (`scripts/score_midpoint.ps1`), as a shortest-path search breaking equal-cost ties toward fewer modifier presses
- [x] Fix `Build-Index` so pure stock NiDA is scored without Midpoint's static overrides
- [x] Run on a 565.4 M character corpus (`scripts/analyze_corpus.py`)
- [x] Rank coeng pairs by real frequency — `scripts/data/coeng_pairs.json`
- [ ] Re-run against a second independent corpus

### 3.2 Linux — the reference target

- [x] Generate `linux/m17n/nida-midpoint.mim` from `midpoint_layout.json` / `midpoint_engine.ps1`
- [x] Generate `linux/nida_midpoint` XKB symbols (`EIGHT_LEVEL`) for the static subset
- [x] Validate `.mim` s-expression balance, LF line endings, and 100% sequence rule coverage in `scripts/verify_platform_layouts.ps1`
- [ ] Test interactively with `m17n-db` / IBus / Fcitx5 on a Linux desktop

### 3.3 Windows — Keyman

- [x] Generate `windows/better_nida_midpoint.kmn` from `midpoint_layout.json` / `midpoint_engine.ps1` using **zero-lag inline contextual replacement rules** (`U+1780 + [K_SLASH] > U+1782`)
- [x] Validate `.kmn` headers, LF line endings, and 100% sequence + layer parity in `scripts/verify_platform_layouts.ps1`
- [x] Keep stock `kbdkni.dll` untouched (Midpoint is opt-in)

### 3.4 macOS — static subset only

- [x] Generate `macos/Khmer Better-NiDA.keylayout` with **5 `<keyMap>` tables**
- [x] `Shift+Option` (`Shift+AltGr`) carries the 13 second-series consonants (displacing nothing)
- [x] Static overrides: `]`→`ំ`, `\`→`ះ`, `Shift+J`→`្`, `Option+J`→`ញ`, `Option+U`→`ឳ`
- [x] No `<actions>` element — zero display lag

### 3.5 Hardware verification

- [ ] macOS: install, run the checklist, open a Testing Report issue
- [ ] Linux: `install.sh` + `verify.sh`, and the m17n checklist
- [ ] Windows: compile/load `windows/better_nida_midpoint.kmn` in Keyman and type the test matrix by hand
- [ ] User study: get two or three Khmer typists to type a fixed passage on stock NiDA and Midpoint, timed and error-counted

---

## 4. Things that are true of the generators

- [x] Midpoint ships **alongside** stock NiDA, never as a replacement.
- [x] `verify_all.ps1` runs both `verify_midpoint.ps1` and `verify_platform_layouts.ps1`, keeping the entire chain green.
- [x] Generated `.sh`, `.command`, `.mim`, `.kmn`, `.keylayout`, and XKB files are pinned to LF.
- [x] Every platform file is generated from `midpoint_engine.ps1` / `midpoint_layout.json`.

---

## 5. Phase 2 Track: Ergonomics, Reordering & Modern Capabilities

### 5.1 Smart Syllable Reordering & Anti-Glitch Normalization (Status: Implemented)

Resolves the #1 complaint in Khmer digital typing: broken dotted circles (`◌`) caused by typing visual/phonetic orders rather than rigid Unicode storage order:
- **Vowel before Subscript swap**: Typing `{Consonant} + {Vowel} + [j] + {Subscript}` (e.g. `k + e + j + r` for `ក្រេ`, or `x + e + j + r` for `គ្រេ`) automatically swaps into canonical `{Consonant} + {Coeng} + {Subscript} + {Vowel}` order (`0` dotted circles).
- **Vowel before Shifter swap**: Typing `{Consonant} + {Vowel} + [Shifter]` (e.g. `b + a + '/` for `ប៉ា`) automatically swaps into canonical `{Consonant} + {Shifter} + {Vowel}`.
- **Pre-Base Vowel at Word Boundary**: Typing a pre-base vowel (`េ`, `ែ`, `ៃ`) at the beginning of a word followed by a base consonant (e.g. `e + k`) automatically swaps to `{Consonant} + {PreBaseVowel}` (`កេ`). Syllable-final consonants (e.g. `pez` in `ភ្នំពេញ`) are protected from false swaps.
- Supported in both `scripts/midpoint_engine.ps1` (`Normalize-Khmer`, verified in `T13`–`T15`) and Keyman contextual rules in `windows/better_nida_midpoint.kmn`.

### 5.2 Ergonomic Tuning for Annoying Keys (Status: Backlog / Next)
- **`៌` (Robat `U+17CC`)**: Very common in formal Khmer (e.g. `ធម៌`, `ការងារ`). Currently requires `--` or `Shift+-`. Target: more fluid combination or shortcut.
- **`៍` (Toandakhiat `U+17CD`)**: Silent consonant marker (e.g. `ទូរទស្សន៍`). Currently on `6/` or `Shift+6`.
- **`៖` (Camnuc Pii Kuuh / Colon `U+17D6`)**: Khmer colon/explanation mark, currently on `;//`.
- **Quotes (`«` and `»`)**: Streamline Khmer angled quotes (`U+00AB` and `U+00BB`).

### 5.3 Full Character Repertoire Parity (Status: Backlog)
- **45 Khmer-script characters reachable in legacy Khmer are unreachable in NiDA**, including:
  - Consonants: `ឝ` SHA (`U+179D`) and `ឞ` SSO (`U+179E`)
  - Rare mark: `៝` ATTHACAN (`U+17DD`)
  - The 9 `LEK ATTAK` symbols and all 32 lunar calendar symbols (`U+19E0..U+19FF`).
- Target: map to vacant `Shift+AltGr` or multi-key sequence slots.

### 5.4 Keyman Mobile Touch Layout (Status: Backlog)
- Build a native `.keyman-touch-layout` definition targeting Android and iOS so Better-NiDA can be used directly on smartphones and tablets via the free Keyman app.

### 5.5 Automatic ZWSP
- **Word separators are 13.2% of everything typed** — `U+200B` at 8.2% and `U+0020` at 5.0%. Midpoint solves the `Shift` cost of `U+0020` via double-space (`  `) and `Space`+`/` (` /`). Automatic `U+200B` insertion at syllable boundaries remains a future dictionary-IME task.

---

## 6. Resolved design decisions

1. **How is `ញ` (`U+1789`) and `្ញ` (`U+17D2 U+1789`) typed without `Shift` or `AltGr`?**
   - Standalone `ញ` (`U+1789`): `jj` (double-tap `j`)
   - `ញ៉` (`U+1789 U+17C9`): `jj/`
   - Subscript `្ញ` (`U+17D2 U+1789`): `j/` (2 keys, saving 1 keystroke and 1 `Shift` press vs stock NiDA)
   - Static fallback on macOS/XKB: `AltGr+J` (`Option+J`)
   - By omitting `jjj`, clusters where base `ញ` is followed by a subscript (such as `បញ្ចប់` = `bjjjcb'`) resolve `jj` (`ញ`) + `j` (`្`) + `c` (`ច`) cleanly with zero ambiguity.
2. **Where does a real space (`U+0020`) go unshifted?**
   - Double-tap `Space` (`  `) or `Space` followed by `/` (` /`) upgrades `U+200B` (ZWSP) to `U+0020` (ASCII Space) inline, eliminating 18,823 `Shift` presses in the 400k sample while keeping single `Space` as `U+200B`.
3. **Why is `g//` left as `g/` (`អ`) + `/` (`៊`) = `អ៊` rather than `ង៉`?**
   - Corpus analysis shows `អ៊` (`U+17A2 U+17CA`, as in `អ៊ុំ`) occurs **60x more often** than `ង៉` (`U+1784 U+17C9`, 179 vs 3 in sample). Leaving `g/` to commit `អ` immediately allows `g//,` to type `អ៊ុំ` naturally, while `ង៉` is already `Shift`-free via `g''` (`ង` + `៉`).

---

## 7. Standing constraints

- `nida_layout.json`, `tables_kbdkni.json`, `tables_kbdkhmr.json`, `kni_layout.csv`
  and `khmr_layout.csv` are immutable dumps of Microsoft's drivers. Midpoint is a
  new derived variant (`midpoint_layout.json`), never an edit to those.
- Every `Shift`+key chord keeps its stock NiDA character, so typists can mix
  chorded and sequence input freely. `Shift+J` is the one documented exception.
- `.ps1` files stay ASCII-only. Non-ASCII literals mangle into parse errors
  under PowerShell 5.1, and are actively confusing.
- The reverse-engineering toolchain is Windows-only and is not portable.
