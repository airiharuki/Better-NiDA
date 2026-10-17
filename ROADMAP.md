# Better-NiDA Roadmap

Two tracks now. **Midpoint** is the variant being shipped, and it is far enough
along to plan concretely. Everything else Midpoint does not solve is listed
honestly in section 5 rather than quietly dropped.

---

## 1. Where we are

Done and verified:

- `kbdkni.dll` and `kbdkhmr.dll` decoded from their binary tables, cross-checked
  against the Windows `ToUnicodeEx` API. 144/144 per layout, plus 4/4 Control.
- `nida_layout.json` as the authoritative spec, generating macOS and Linux files
  reproducibly. Byte-identical run to run.
- **`scripts/midpoint_engine.ps1`** — Midpoint defined as data, with a
  longest-prefix resolver. `scripts/verify_midpoint.ps1` gates it: 11 checks,
  all passing.

Not done:

- **No platform file has been generated for Midpoint.** The engine exists;
  nothing consumes it yet.
- **Nothing has been loaded on a real Mac or Linux machine.**
- No corpus, so **no ergonomic claim in this project is measured.**
- Keyman is not installed, so the Windows target cannot be functionally tested
  even though this host is Windows.

---

## 2. Honest accounting: what Midpoint buys and costs

**Measured on real text**, not a hand-written sample. `scripts/analyze_corpus.py`
streams a 152 MB `.xz` corpus and produces the sample and frequency tables;
`scripts/score_midpoint.ps1` then inverts the engine to find the cheapest way to
type it, as a shortest-path search rather than greedy.

Corpus: **565,400,366 Khmer characters** kept from 7.2 M lines. Scoring runs on a
400,000-character cleaned sample, of which **374,915 are typeable** by a Khmer
layout and 20,840 are not — Latin words, Thai, emoji and curly quotes mixed into
the prose, which is expected and is excluded from the ratio.

| | stock NiDA | Midpoint | |
| :-- | --: | --: | :-- |
| keypresses | 370,550 | 424,149 | **+14.5%** |
| needing Shift | 83,685 | 28,926 | **−65.4%** |
| needing AltGr | 5,540 | 5,540 | — |
| total presses | 459,775 | 458,615 | −0.3% |
| **KSPC** | **1.226** | **1.223** | **−0.3%** |
| Shift share of keys | **22.6%** | **6.8%** | — |

**The verdict: Midpoint is a dead heat on total effort.** It removes two-thirds
of the mandatory `Shift` presses and spends almost exactly those presses on extra
keys. KSPC is marginally better for Midpoint, by 0.3% — inside the noise of the
sample, and not a reason to ship it.

The baseline `Shift` share measures **22.6%**, against the 24.5% the research spec
assumed. Their estimate was sound; the prediction built on it was not. Midpoint
reaches 6.8%, not the promised 2.5%.

So Midpoint is not a speedup. It is a **relocation of effort**: from modifier
fatigue to keystroke count. Whether that is worth anything is a question for
typists, not arithmetic — see 3.5.

### Where the remaining Shift goes

Of Midpoint's 28,926 remaining `Shift` presses, about **18,800 are the space bar**
alone. Real text uses `U+0020` for roughly 5% of characters, and NiDA requires
`Shift+Space` for it because unshifted Space emits `U+200B`. That is 65% of the
leftover modifier load, and it is a single-character fix nobody has made yet.

This also validates the auto-ZWSP case below with real numbers rather than
estimate: word separators are **13.2%** of everything typed (`U+200B` 8.2%,
`U+0020` 5.0%).

Two things Midpoint does that hold regardless of the volume argument:

- `ំ` and `ះ` move to unshifted `]` and `\`. They are the most common
  word-final marks in Khmer, so this removes a `Shift` press almost every word.
- `Shift+J` can no longer produce a stray `ញ` mid-cluster, which was causing
  rollover typos.
- 100% of unshifted A–Z is preserved, so retraining is near zero. Gated, not
  asserted.

---

## 3. Critical path

### 3.1 Measure the claim first

**Done.** `scripts/score_midpoint.ps1` inverts the engine: given text, it finds
the cheapest way to type it, as a shortest-path search rather than greedy, and
reports keypresses, modifier load, and KSPC for stock NiDA and Midpoint side by
side. Ties in cost break toward fewer modifier presses, which is the axis the two
layouts actually compete on.

The result is in section 2, and it is not the one the research predicted: KSPC is
identical, because the `Shift` presses Midpoint saves are exactly the extra keys
it costs.

- [x] Inverse mode on the engine, as a shortest-path search
- [x] Report keypresses, modifier load, KSPC and Shift share, both layouts
- [x] Correct the claim in section 2 rather than re-running until it looked better
- [x] **Run it on a real corpus.** `scripts/analyze_corpus.py` streams a 152 MB
      `.xz` dump into a sample plus frequency tables. 565,400,366 characters kept.
- [x] Rank coeng pairs by real frequency — `scripts/data/coeng_pairs.json`
- [ ] **Re-run against a second corpus.** One corpus of 565 M characters is
      strong evidence, not proof of representativeness. Everything downstream
      inherits that caveat.
- [ ] Re-measure after every future rule change, and publish the delta

Because the verdict is "a wash on volume, better on fatigue", the remaining
question is subjective and needs people, not more arithmetic: 3.5.

**Python is required only for corpus work.** It has `lzma` in the standard
library. Decoding the driver tables and generating the layouts remain pure
PowerShell and Windows-only.

### 3.2 Linux — the reference target

Linux goes first because m17n resolves longest-prefix sequences natively, so it
implements Midpoint's intended semantics exactly, with no approximation.

- [ ] Generate `linux/m17n/nida-midpoint.mim` from the engine's rule set. The
      sequence rules become `(seq ...)` maps; the static overrides become the
      base map.
- [ ] Generate `linux/nida_midpoint` XKB symbols for the **static subset only**.
      XKB cannot express sequences — one keysym per level — so this file is the
      no-lag fallback, not a reduced version.
- [ ] Validate the `.mim` structurally here, and with `m17n-db` on Linux. Must be
      silent. This has never been done for any file in this project.
- [ ] Verify both files against the engine: every keystroke the engine resolves
      must appear in the generated file, and vice versa.

### 3.3 Windows — Keyman

Keyman rather than AutoHotkey: an actual keyboard rather than a script layered
over stock NiDA, and no runtime for users to install.

- [ ] Generate `windows/better_nida_midpoint.kmn` from the engine.
- [ ] Validate `.kmn` syntax. Keyman is not installed here, so this is careful
      structural checking, not a functional test. Say so plainly in the docs.
- [ ] Keep the guardrail that matters: existing NiDA users keep `kbdkni.dll`
      untouched. Midpoint is opt-in.

### 3.4 macOS — static subset only

Settled by measurement, not preference. **31 of 49 keys (63%) become pending**
under the sequence rules, and `.keylayout` cannot replace an already-emitted
character. Dead-key emulation would mean two-thirds of the keyboard invisible
until the next keystroke. Not shippable.

- [ ] Generate `macos/Khmer Better-NiDA.keylayout` with **5 `<keyMap>` tables**,
      which the generator already supports for the legacy variant.
- [ ] Shift+AltGr carries the 13 second-series consonants. Stock NiDA leaves
      that level empty (0 of 49 keys), so **nothing is displaced**.
- [ ] Static overrides: `]`→`ំ`, `\`→`ះ`, `Shift+J`→`្`.
- [ ] No `<actions>` element. Zero display lag, and no dead-key behaviour to
      misfire in text fields, terminals, or remote sessions.

### 3.5 Hardware verification

Blocked on other people, and it is the single highest-value thing left.

- [ ] macOS: install, run the checklist, open a Testing Report issue.
- [ ] Linux: `install.sh` + `verify.sh`, and the m17n checklist.
- [ ] Windows: load the `.kmn` in Keyman and type the test matrix by hand.
- [ ] **Get two or three Khmer typists** to type a fixed passage on stock NiDA
      and Midpoint, timed and error-counted. Without this, section 2's trade-off
      is unresolved opinion.

---

## 4. Things that must be true of the generators

- [ ] Midpoint ships **alongside** stock NiDA, never as a replacement. Existing
      users' behaviour is unchanged.
- [ ] `verify_all.ps1` gains the Midpoint stage, so the whole chain stays green.
- [ ] Generated `.sh`, `.mim`, and `.keylayout` files stay pinned to LF.
- [ ] Every platform file is generated from the engine. Nothing hand-written, or
      the platforms will drift.

---

## 5. What Midpoint does not solve

Kept deliberately, so these are not lost. None of them is addressed by the
current engine.

### 5.1 Typing length — the coeng ligature case

Midpoint makes typing *less effortful*, not *shorter*. The lever for length is
ligatures, and NiDA ships only 5, contributing **0.9%** of keystrokes in the
measured baseline.

The opportunity is large and cheap, because **31 of 49 keys are pending
anyway**. Coeng `្` is **7.7%** of typed characters, and `្` + subscript
consonant is a **contiguous two-character substring** — `្រ` inside `ព្រ` — so it
ligates directly with no reordering.

Ranked from 41.6 M real coengs (`scripts/data/coeng_pairs.json`):

| Pairs added | Coverage of all coengs |
| :-- | --: |
| 1 (`្រ` alone) | 26.4% |
| 5 | 58.7% |
| 10 | 75.9% |
| 20 | 94.7% |
| 25 | 98.7% |

A single ligature for `្រ` covers more than a quarter of all coengs in Khmer.
Twenty entries reach 94.7%, and there are 98 unused slots to put them in.

At one keystroke saved per occurrence, the top 25 are worth roughly **6.6% of all
keystrokes** — a larger and more certain win than anything Midpoint does, and it
composes with it rather than competing.

- [ ] Take the top 20 pairs and place them on `Shift+AltGr` / `Control`
- [ ] Verify the driver accepts the entries, and whether 2-character entries are
      the only supported length. Only 2-character behaviour is verified today
- [ ] Re-score and publish the delta

#### Modifier capacity: the cost of adding ligatures is lower than expected

The driver declares more modifier states than it uses. Measured occupancy:

| Level | Keys carrying output |
| :-- | :-- |
| Normal | 49 / 49 |
| Shift | 49 / 49 |
| AltGr | 27 / 49 |
| **Control** | **0 / 49** |
| **ShiftAltGr** | **0 / 49** |

That is **98 unused slots**. Ligatures do not have to displace existing
characters — the free levels already hold them. This inverts the usual
assumption that extending a keyboard layout means taking keys away from someone,
and it is the reason this is cheap enough to do.

There is one genuine conflict. `Shift+AltGr` is the level legacy Khmer uses for
the whole `U+19E0..19FF` symbol block, and Midpoint's static subset already uses
it for the 13 second-series consonants. Ligatures and those symbols compete for
the same 49 slots; `Control` is the fallback, but reaching it costs a `Ctrl+Alt`
chord, which is worse ergonomics than either deserves.

Unverified: **the driver has only ever been observed emitting 2-character
ligatures.** A 3-character entry may or may not be accepted, and that needs a
Windows probe. macOS `.keylayout` has no such limit.

### 5.2 Character coverage

**45 Khmer-script characters reachable in legacy Khmer are unreachable in
NiDA**, including two consonants NiDA cannot type at all: `ឝ` SHA (U+179D) and
`ឞ` SSO (U+179E). Plus `៝` ATTHACAN, the 9 `LEK ATTAK` symbols, and all 32 of
`U+19E0..19FF`.

That is 13 characters in the Khmer block `U+1780..17FF` plus 32 in the Khmer
Symbols block `U+19E0..19FF`. 79 characters in total are legacy-only, the rest
being Latin punctuation and currency signs.

Adding characters does not shorten or lighten typing, so this sits behind
Midpoint in priority.

### 5.3 Automatic ZWSP, and the space bar

**Word separators are 13.2% of everything typed** — `U+200B` at 8.2% and
`U+0020` at 5.0%. Automatic `U+200B` insertion at syllable boundaries is the
single largest win available, and **no layout can deliver it**; it needs an IME.

There is also a cheap layout-level half of this that is separate and
actionable: NiDA requires `Shift+Space` for a real space, and that single choice
accounts for **~18,800 of Midpoint's 28,926 remaining `Shift` presses**.

- [ ] Decide where a real space goes unshifted, or accept that space is the price
      of a Shift-free layout. This is a design decision, not just a placement one
- [ ] Then measure again — removing it would drop Midpoint's `Shift` share well
      under 3% and make the variant materially better than it currently is
- [ ] Auto-`U+200B` remains an IME task, not a layout one

---

## 6. Open questions

1. **How much is Midpoint actually worth?** Section 2 answers the arithmetic and
   the answer is: no gain in total effort, two-thirds less `Shift`. Only typists
   can say whether that trade has value. **Do not generate platform files before
   this is answered** — the whole variant rests on it.
2. **Where does a real space go?** It is 65% of Midpoint's remaining `Shift` load
   and a one-character fix. Cheapest remaining win in the project.
3. **Caps Lock as Shift.** The research spec proposes mapping Caps Lock to Shift.
   This now looks self-defeating: its purpose is to relieve Shift load, and
   Midpoint's entire point is reducing that load. It also makes Caps Lock
   unusable for anything else. **Recommend deferring it.** Decide before 3.2.
4. **The `g//` rule.** The spec maps `g` `//` to `ង៉`, which contradicts the
   spec's own orthography section stating `អ` only ever takes `៊`. Unresolved and
   currently unimplemented. Either it is a typo or the rule needs restating.
5. **Who are the typists?** 3.5 is worthless without Cambodian users. That is a
   relationship to build, not a task to tick.
6. **Who maintains it?** Reverse-engineering is done. Regeneration whenever
   Windows ships a new `kbdkni.dll` is somebody's ongoing job.

**Untypeable in real text, and worth noting:** `ឝ` SHA (U+179D) and `ឞ` SSO
(U+179E) both occur in the corpus and neither is reachable in NiDA. The section
5.2 coverage gap is real demand, not a theoretical completeness argument.

---

## 7. Risks

| Risk | Consequence | Mitigation |
| :-- | :-- | :-- |
| Midpoint does not reduce total effort | It is a lateral move, not an improvement | **Realised.** KSPC is a wash on real text; only typists can say if the trade is worth it (3.5) |
| This corpus is not representative of typing | Every number here is one corpus deep | It is 565 M characters of real prose, but re-run against a second corpus before any release |
| Space bar dominates the remaining `Shift` load | Variant looks far worse than it needs to | Section 5.3; one-character fix |
| m17n prefix semantics diverge from the engine | Silent corruption on Linux only | Generate from the engine; cross-check both directions |
| Sequence rules feel slower than Shift | Typists revert to stock | 3.5 typist testing before promotion |
| `Shift+AltGr` for second series is too awkward | macOS variant underperforms | Test it early; it is a one-line change if rejected |
| Nothing is tested on real hardware | Unknown unknowns, as now | 3.5 |

**A known lossy case, recorded so it is not rediscovered as a mystery:** `usLegend`
is not unique in `nida_layout.json`. The numpad period is also labelled `.`, so
49 keys yield 48 legends. A legend-keyed lookup can only return one of them. The
engine keeps the main-area key (U+17D4 / U+17D5) and the numpad key's ASCII comma
and period are unreachable *through the engine* — both remain reachable on the
layout itself via `AltGr+,` and `AltGr+.`.

---

## 8. Standing constraints

- `nida_layout.json`, `tables_kbdkni.json`, `tables_kbdkhmr.json`, `kni_layout.csv`
  and `khmr_layout.csv` are immutable dumps of Microsoft's drivers. Midpoint is a
  new derived variant, never an edit to those.
- Every `Shift`+key chord keeps its stock NiDA character, so typists can mix
  chorded and sequence input freely. `Shift+J` is the one documented exception.
- `.ps1` files stay ASCII-only. Non-ASCII literals mangle into parse errors
  under PowerShell 5.1, and are actively confusing.
- The reverse-engineering toolchain is Windows-only and is not portable.