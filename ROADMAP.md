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

Measured with `scripts/score_midpoint.ps1`, which inverts the engine: given text,
it finds the cheapest way to type it, as a shortest-path search rather than
greedy. 213 characters of hand-written Khmer (see the caveat below).

| | stock NiDA | Midpoint | |
| :-- | --: | --: | :-- |
| keypresses | 211 | 245 | **+16.1%** |
| needing Shift | 38 | 4 | **−89.5%** |
| needing AltGr | 5 | 5 | — |
| total presses | 254 | 254 | — |
| **KSPC** | **1.192** | **1.192** | **0.0%** |
| Shift share of keys | 18.0% | 1.6% | — |

**The headline result is that Midpoint is a wash on KSPC.** It removes almost
every mandatory `Shift` press, then spends precisely those keystrokes on extra
keys to do it. Total effort is identical to three decimal places.

That does not make it useless — it relocates the effort from modifier fatigue to
keystroke count, which some typists will prefer and some will not. But it is a
different proposition from the one the research claimed, and the variant should
be described that way rather than as a speedup.

The baseline `Shift` share measures 18.0% here, against the 24.5% the research
spec assumed. Different corpus, different method; the direction agrees but the
figures are not interchangeable.

**Caveat, and it is a large one.** This corpus is hand-written and 213
characters long. It is not frequency-weighted and cannot be trusted as a
representative sample. It is enough to falsify a claim, which is what it was
built for; it is not enough to support one. See 3.1.

Two things Midpoint does that hold regardless of the above, because they are not
about volume:

- `ំ` and `ះ` move to unshifted `]` and `\`. They are the most common word-final
  marks in Khmer, so this removes a `Shift` press almost every word.
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
- [ ] **Re-measure on a real corpus.** The 213-character sample can falsify a
      claim but cannot support one. Everything downstream inherits this caveat.
- [ ] Re-measure after every future rule change, and publish the delta

Because the verdict is "a wash on volume, better on fatigue", the remaining
question is subjective and needs people, not more arithmetic: 3.5.

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
anyway**. Coeng `្` is 8% of characters in the baseline, and `្` + subscript
consonant is a **contiguous two-character substring** — `្រ` inside `ព្រ` — so it
ligates directly with no reordering.

Seven entries covered an entire smoke corpus. This is orthogonal to Midpoint and
should be a separate change, measured separately.

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

### 5.3 Automatic ZWSP

**16.4% of all keystrokes** in the baseline produce a `U+200B` the reader never
perceives as content. It is the single largest win available and **no layout can
deliver it** — it requires an IME. See section 6, question 1.

---

## 6. Open questions

1. **How much is Midpoint actually worth?** Section 2's trade-off is hand-traced
   on three words. 3.1 answers this properly, and it should be answered before
   shipping rather than after.
2. **Caps Lock as Shift.** The research spec proposes mapping Caps Lock to Shift.
   This now looks self-defeating: its purpose is to relieve Shift load, and
   Midpoint's entire point is reducing that load. It also makes Caps Lock
   unusable for anything else. **Recommend deferring it.** Decide before 3.2.
3. **The `g//` rule.** The spec maps `g` `//` to `ង៉`, which contradicts the
   spec's own orthography section stating `អ` only ever takes `៊`. Unresolved and
   currently unimplemented. Either it is a typo or the rule needs restating.
4. **Who are the typists?** 3.5 is worthless without Cambodian users. That is a
   relationship to build, not a task to tick.
5. **Who maintains it?** Reverse-engineering is done. Regeneration whenever
   Windows ships a new `kbdkni.dll` is somebody's ongoing job.

---

## 7. Risks

| Risk | Consequence | Mitigation |
| :-- | :-- | :-- |
| Midpoint does not reduce total effort | It is a lateral move, not an improvement | **Partly realised.** KSPC is a wash; only typists can say if the trade is worth it (3.5) |
| A 213-character hand-written corpus misleads us | Every number here is provisional | 3.1 re-measure on a real corpus before any release |
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