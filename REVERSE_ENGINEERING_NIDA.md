# Reverse Engineering the Khmer NiDA Keyboard Layout

This document is the technical record of how `kbdkni.dll` - the Windows
implementation of the Khmer NiDA layout - was decoded, and of what the layout
actually contains.

Everything below is derived from the DLL's own data structures, then
cross-checked against Windows itself. Nothing is inferred from documentation
that could not be confirmed on this machine.

---

## 1. Target and environment

Recorded precisely, because a reverse-engineering result is only meaningful
alongside the exact build it was taken from.

| Property | Value |
| :-- | :-- |
| Host OS | Windows 11 Enterprise, 26H2, build 26300.9550 |
| Analysis host | Windows only - no macOS or Linux machine was involved |
| Binary | `C:\Windows\System32\kbdkni.dll` |
| Size | 24576 bytes |
| DLL file version | 10.0.26100.2454 (`WinBuild.160101.0800`) |
| Keyboard layout ID | `00010453` |
| Display name | Khmer (NiDA) |
| Authority | NiDA - National Information Communications Technology Development Authority, Cambodia |
| Comparison layout | `kbdkhmr.dll`, KLID `00000453`, "Khmer" (legacy), file version 10.0.26100.8972 |

Note the gap between the OS build and the DLL versions: the keyboard layout
DLLs still carry a `26100` base version while the host runs `26300`. The
keyboard subsystem is versioned independently of the OS release, so a `26100`
DLL on a `26300` host is expected and not a stale-file problem.

### Scope limit

Every finding in this document comes from Windows: the DLL tables were decoded
on Windows and verified against the Windows `ToUnicodeEx` API. The
macOS and Linux layouts built from this spec have **not** been loaded on
macOS or Linux - see the platform sections for what that means in practice.

---

## 2. Method

Two independent paths were used, and they agree exactly:

1. **Structural (primary).** Load the DLL in-process, call its exported
   `KbdLayerDescriptor()`, and walk the returned descriptor into the layout's
   own tables. This reads the layout as data, with no Windows in the loop.
2. **Behavioural (oracle).** Ask Windows what each key produces by calling
   `ToUnicodeEx()` for every scan code in every modifier state. This is
   completely independent of any assumption about the file format.
3. **Control probe.** Repeat the probe with `VK_CONTROL` held, to test the one
   reading the first oracle could not settle: whether slot 2 of the
   special-keys table is the Control character.

```
comparisons made : 144  (NiDA, 48 keys x Normal/Shift/AltGr)
mismatches       : 0

control probe    : 4    (special keys x Control)
mismatches       : 0     -> slot 2 is the Control character, now verified
```

`scripts/verify_tables.ps1` re-runs this comparison and exits non-zero on any
disagreement, so the claim is reproducible rather than asserted.

Both paths run on Windows, and both see the layout as Windows sees it. A
cross-platform check is deliberately *not* claimed: the behavioural oracle is
the Windows API, so it cannot independently predict what macOS or Linux will do
with a layout built from these tables.

The structural decode also produced facts the behavioural probe cannot see
(section 10).

---

## 3. Binary anatomy

### 3.1 Entry point

Every `kbd*.dll` exports `KbdLayerDescriptor`, which returns a pointer to a
descriptor. Offsets below are for 64-bit Windows.

| Offset | Field | Notes |
| :-- | :-- | :-- |
| `+0x00` | `pCharModifiers` | modifier-state numbering (section 3.4) |
| `+0x08` | `pVkToWcharTable` | four character sub-tables (section 3.2) |
| `+0x10` | `pDeadKey` | `NULL` - NiDA defines no dead keys |
| `+0x18` | `pKeyNames` | key-name tables |
| `+0x20` | `pKeyNamesExt` | |
| `+0x28` | `pKeyNamesDead` | `NULL` |
| `+0x30` | `puVKeyToCodes` | virtual-key remap list, 127 entries |
| `+0x38` | `cbVKeyToCodes` | `0x7F` |
| `+0x40` | `pTypedef` | shared keyboard typedef list |
| `+0x48` | key-name string data | points into the name-string area |
| `+0x50` | flags | `0x00010001` (Khmer layouts), `0x00010000` (US) - meaning unconfirmed |
| `+0x54` | `nLgMax` | `2` - max characters in one ligature |
| `+0x55` | `cbLgEntry` | `8` - size of one ligature record |
| `+0x58` | `pLigature` | ligature table (section 3.5) |

> Earlier drafts of this document placed the ligature fields at `+0x72`/`+0x74`
> and read `pLigature` from `+0x50`. Those offsets are wrong on 64-bit: doing so
> yields a nonsensical pointer such as `0x80200010001`. The offsets above are
> the ones confirmed by decoding real data.

### 3.2 Character sub-tables

`pVkToWcharTable` is an array of 16-byte descriptors, terminated by a null
pointer:

| Offset | Type | Field |
| :-- | :-- | :-- |
| `+0x00` | `PVOID` | table pointer |
| `+0x08` | `BYTE` | `cStates` - modifier states stored per key |
| `+0x09` | `BYTE` | `cbEntry` - always `2 * (1 + cStates)` |
| `+0x0A` | `USHORT` | `0` |

For `kbdkni.dll`:

| Index | `cStates` | `cbEntry` | Entries | Role |
| :-- | :-- | :-- | :-- | :-- |
| 0 | 3 | 8 | 4 | special keys (Backspace, Escape, Enter, Ctrl+C) |
| 1 | 4 | 10 | 49 | **main character map** |
| 2 | 2 | 6 | 5 | base characters for keys missing from table 1 |
| 3 | 1 | 4 | 10 | base characters for the keypad digits |

Only table 1 has a slot count equal to the layout's modifier-state count, so it
is the only one whose slots are confirmed to be indexed by modifier number -
and that is the one the `ToUnicodeEx` cross-check validates. The others are
emitted with neutral slot labels (section 7).

Tables 2 and 3 are disjoint from the main table: for all three layouts dumped
(NiDA, legacy Khmer, US) no virtual key appears in both, so each key is defined
exactly once. NiDA's table 2 holds only the 5 keys the main table omits (Tab and
the keypad operators); US, whose main table has just 3 exception entries, holds
47.

`kbdus.dll` uses the identical four-table shape with the same state counts,
which is what confirms the format is a general one rather than something fitted
to Khmer. Its main table holds only **3** entries, because a US layout inherits
the base 104-key mapping from Windows and only stores its exceptions.

### 3.3 Entry format

Each entry is `cbEntry` bytes and holds one virtual key plus one code point per
modifier state:

```
struct KbdCharEntry {          // cbEntry bytes
    USHORT vk;                 // +0x00  virtual key
    USHORT wchar[cStates];     // +0x02  one code point per modifier state
};
```

Two reserved values appear in the `wchar` slots:

| Value | Meaning |
| :-- | :-- |
| `0xF000` | no character is emitted in this state |
| `0xF002` | the character resolves through the ligature table |

`0xF002` in a slot and a matching `(vk, modNumber)` entry in the ligature table
is exactly how a multi-character keystroke is expressed. NiDA uses it five
times, listed in section 5.

### 3.4 Modifier numbering

`pCharModifiers` is `{ PVOID pVkToBit; USHORT wMaxModBits; BYTE aModifiers[]; }`,
where `aModifiers[bit]` gives the **modifier number** for a modifier bit.
NiDA sets `wMaxModBits = 6`:

| Modifier bit | Modifier number | Meaning |
| :-- | :-- | :-- |
| 0 | 0 | Normal |
| 1 | 1 | Shift |
| 2 | 2 | Control |
| 3 | 15 | invalid - never produced |
| 4 | 15 | invalid |
| 5 | 15 | invalid |
| 6 | 3 | AltGr (Ctrl + Alt / Right Alt) |

The character tables then list one code point per *modifier number* in ascending
order. NiDA's main table has four slots: **Normal, Shift, Control, AltGr**.
Control is `0xF000` for every printable key - NiDA overrides no control
characters.

`kbdkhmr.dll` declares `wMaxModBits = 7` with an extra bit 7 -> modifier
number 4, giving it a fifth slot that carries `Shift + AltGr` characters. This
is why the same entry format is 12 bytes there instead of 10.

### 3.5 Ligature table

`pLigature` is an array of `cbLgEntry`-byte records, ended by an all-zero record:

```
struct KbdLigature {           // cbLgEntry bytes
    BYTE  vk;                  // +0x00
    BYTE  reserved;            // +0x01
    USHORT modNumber;          // +0x02
    WCHAR text[nLgMax];        // +0x04  n-th is 0-terminated / zero-padded
};
```

NiDA: `nLgMax = 2`, `cbLgEntry = 8`, five records.

---

## 4. Modifier states in NiDA

| State | Modifier number | Chords |
| :-- | :-- | :-- |
| Normal | 0 | unshifted |
| Shift | 1 | Shift |
| Control | 2 | Ctrl (no override in NiDA) |
| AltGr | 3 | Ctrl+Alt, or Right Alt |
| Shift+AltGr | - | not present in NiDA (present in legacy Khmer) |

---

## 5. Ligatures

Five keys emit two code points in a single keystroke:

| Key | State | Output | Code points |
| :-- | :-- | :-- | :-- |
| `A` (`0x41`) | Shift | ាំ | `U+17B6 U+17C6` |
| `V` (`0x56`) | Shift | េះ | `U+17C1 U+17C7` |
| `;` (`0xBA`) | Shift | ោះ | `U+17C4 U+17C7` |
| `,` (`0xBC`) | Normal | ុំ | `U+17BB U+17C6` |
| `,` (`0xBC`) | Shift | ុះ | `U+17BB U+17C7` |

These are the Khmer *srak* (word-final) marks and the *srah* sequences: typing
`ាំ` needs one keystroke instead of two.

---

## 6. Complete character matrix

All 49 keys of the main table, in physical keyboard order. `Normal`, `Shift`
and `AltGr` are the three states NiDA defines characters for. Invisible
characters are labelled: `<ZWSP>` zero-width space, `<ZWNJ>` zero-width
non-joiner, `<ZWJ>` zero-width joiner, `<NBSP>` non-breaking space.

| Key | VK | SC | Normal | Shift | AltGr |
| :-- | :-- | :-- | :-- | :-- | :-- |
| **1** | `0x31` | `0x02` | ១ U+17E1 | `!` U+0021 | <ZWNJ> U+200C |
| **2** | `0x32` | `0x03` | ២ U+17E2 | ៗ U+17D7 | `@` U+0040 |
| **3** | `0x33` | `0x04` | ៣ U+17E3 | `"` U+0022 | ៑ U+17D1 |
| **4** | `0x34` | `0x05` | ៤ U+17E4 | ៛ U+17DB | `$` U+0024 |
| **5** | `0x35` | `0x06` | ៥ U+17E5 | `%` U+0025 | € U+20AC |
| **6** | `0x36` | `0x07` | ៦ U+17E6 | ៍ U+17CD | ៙ U+17D9 |
| **7** | `0x37` | `0x08` | ៧ U+17E7 | ័ U+17D0 | ៚ U+17DA |
| **8** | `0x38` | `0x09` | ៨ U+17E8 | ៏ U+17CF | `*` U+002A |
| **9** | `0x39` | `0x0A` | ៩ U+17E9 | `(` U+0028 | `{` U+007B |
| **0** | `0x30` | `0x0B` | ០ U+17E0 | `)` U+0029 | `}` U+007D |
| **-** | `0xBD` | `0x0C` | ឥ U+17A5 | ៌ U+17CC | × U+00D7 |
| **=** | `0xBB` | `0x0D` | ឲ U+17B2 | `=` U+003D | ៎ U+17CE |
| **Q** | `0x51` | `0x10` | ឆ U+1786 | ឈ U+1788 |  |
| **W** | `0x57` | `0x11` | ឹ U+17B9 | ឺ U+17BA |  |
| **E** | `0x45` | `0x12` | េ U+17C1 | ែ U+17C2 | ឯ U+17AF |
| **R** | `0x52` | `0x13` | រ U+179A | ឬ U+17AC | ឫ U+17AB |
| **T** | `0x54` | `0x14` | ត U+178F | ទ U+1791 |  |
| **Y** | `0x59` | `0x15` | យ U+1799 | ួ U+17BD |  |
| **U** | `0x55` | `0x16` | ុ U+17BB | ូ U+17BC |  |
| **I** | `0x49` | `0x17` | ិ U+17B7 | ី U+17B8 | ឦ U+17A6 |
| **O** | `0x4F` | `0x18` | ោ U+17C4 | ៅ U+17C5 | ឱ U+17B1 |
| **P** | `0x50` | `0x19` | ផ U+1795 | ភ U+1797 | ឰ U+17B0 |
| **[** | `0xDB` | `0x1A` | ៀ U+17C0 | ឿ U+17BF | ឩ U+17A9 |
| **]** | `0xDD` | `0x1B` | ឪ U+17AA | ឧ U+17A7 | ឳ U+17B3 |
| **A** | `0x41` | `0x1E` | ា U+17B6 | ាំ U+17B6 U+17C6 |  |
| **S** | `0x53` | `0x1F` | ស U+179F | ៃ U+17C3 |  |
| **D** | `0x44` | `0x20` | ដ U+178A | ឌ U+178C |  |
| **F** | `0x46` | `0x21` | ថ U+1790 | ធ U+1792 |  |
| **G** | `0x47` | `0x22` | ង U+1784 | អ U+17A2 |  |
| **H** | `0x48` | `0x23` | ហ U+17A0 | ះ U+17C7 |  |
| **J** | `0x4A` | `0x24` | ្ U+17D2 | ញ U+1789 |  |
| **K** | `0x4B` | `0x25` | ក U+1780 | គ U+1782 |  |
| **L** | `0x4C` | `0x26` | ល U+179B | ឡ U+17A1 |  |
| **;** | `0xBA` | `0x27` | ើ U+17BE | ោះ U+17C4 U+17C7 | ៖ U+17D6 |
| **'** | `0xDE` | `0x28` | ់ U+17CB | ៉ U+17C9 | ៈ U+17C8 |
| **\** | `0xDC` | `0x2B` | ឮ U+17AE | ឭ U+17AD | `\` U+005C |
| **Z** | `0x5A` | `0x2C` | ឋ U+178B | ឍ U+178D |  |
| **X** | `0x58` | `0x2D` | ខ U+1781 | ឃ U+1783 |  |
| **C** | `0x43` | `0x2E` | ច U+1785 | ជ U+1787 |  |
| **V** | `0x56` | `0x2F` | វ U+179C | េះ U+17C1 U+17C7 |  |
| **B** | `0x42` | `0x30` | ប U+1794 | ព U+1796 |  |
| **N** | `0x4E` | `0x31` | ន U+1793 | ណ U+178E |  |
| **M** | `0x4D` | `0x32` | ម U+1798 | ំ U+17C6 |  |
| **,** | `0xBC` | `0x33` | ុំ U+17BB U+17C6 | ុះ U+17BB U+17C7 | `,` U+002C |
| **.** | `0xBE` | `0x34` | ។ U+17D4 | ៕ U+17D5 | `.` U+002E |
| **/** | `0xBF` | `0x35` | ៊ U+17CA | `?` U+003F | `/` U+002F |
| **`** | `0xC0` | `0x29` | « U+00AB | » U+00BB | <ZWJ> U+200D |
| **Space** | `0x20` | `0x39` | <ZWSP> U+200B | ` ` U+0020 | <NBSP> U+00A0 |

The 49th main-table entry has no scan code on a 104-key board: keypad decimal
(`0x6E`) produces `,` and `.`.

---

## 7. Secondary tables

**Special keys** (table 0, three slots). Slot 2 is **verified** to be the
Control character - see section 2:

| Key | Normal | Shift | Control |
| :-- | :-- | :-- | :-- |
| Backspace | `U+0008` | `U+0008` | `U+007F` (Delete) |
| Escape | `U+001B` | `U+001B` | `U+001B` |
| Enter | `U+000D` | `U+000D` | `U+000A` (Line feed) |
| Ctrl+C | `U+0003` | `U+0003` | `U+0003` |

**Base-character fallback** (tables 2 and 3). These carry the *unshifted*
character for keys that are **absent from the main table**, not control
characters:

| Table | Entries | Keys |
| :-- | :-- | :-- |
| 2 | 5 | Tab, keypad `+ - * /` |
| 3 | 10 | keypad `0`-`9` -> matching digits |

For all three layouts dumped (NiDA, legacy Khmer, US) the main table and tables
2/3 are **completely disjoint** - 0 overlapping virtual keys - so each key is
defined exactly once. An earlier draft of this document described table 2 as a
"control-character map"; that was wrong, and the Control probe disproved it:
holding Ctrl on Tab or the keypad operators produces nothing, while table 2's
values equal the plain unshifted character.

Slot labels in the JSON are neutral (`Slot0`, `Slot1`, ...) for these tables,
because their slots are not modifier-indexed in the way the main table's are.

---

## 8. Invisible and formatting characters

Khmer word segmentation depends on characters that render as nothing:

| Character | Input | Purpose |
| :-- | :-- | :-- |
| `U+17D2` coeng ្ | `J` | subscript generator, placed before a consonant (`ក` + `្` + `ខ`) |
| `U+200B` ZWSP | `Space` | separates words with no visible gap |
| `U+0020` space | `Shift + Space` | a real, visible space |
| `U+00A0` NBSP | `AltGr + Space` | non-breaking space |
| `U+200C` ZWNJ | `AltGr + 1` | suppresses coeng joining where wanted |
| `U+200D` ZWJ | `AltGr + `` ` `` | forces joined forms |

---

## 9. NiDA versus the legacy Khmer layout

| Feature | Khmer NiDA (`kbdkni.dll`) | Legacy Khmer (`kbdkhmr.dll`) |
| :-- | :-- | :-- |
| Coeng subscript U+17D2 | key `J` | key `Space` |
| Zero-width space U+200B | key `Space` | key `/` |
| Visible space U+0020 | `Shift + Space` | `Shift + Space` |
| Letter Nyo U+1789 | `Shift + J` | key `J` |
| Srak AM (U+17B6 U+17C6) | `Shift + A` | `Shift + S` |
| Srak OM (U+17BB U+17C6) | key `,` | `Shift + J` |
| Srak UH (U+17BB U+17C7) | `Shift + ,` | `Shift + G` |
| Srah EH (U+17C1 U+17C7) | `Shift + V` | `Shift + V` |
| Srah AOH (U+17C4 U+17C7) | `Shift + ;` | `Shift + [` |
| Modifier states in main table | 4 (Normal / Shift / Control / AltGr) | 5 (+ Shift+AltGr) |
| Shift+AltGr characters | not defined | Khmer symbol set U+19E0..U+19FF |

Structurally the two layouts use the same tables, the same entry format and the
same `nLgMax`/`cbLgEntry`. They differ in how many modifier states the main
table carries, which changes the entry size from 10 to 12 bytes.

---

## 10. Findings that behavioural probing alone would miss

These come from reading the tables, and are the reason the structural decode was
worth doing:

1. **`Space` is the zero-width space and `Shift + Space` the real space.** A
   probe that only sampled printable output tends to hide this.
2. **NiDA defines no Control characters at all.** Every printable key's Control
   slot is `0xF000`, so Windows synthesises `^C`, `^V` and friends. The legacy
   layout is the same.
3. **NiDA has no `Shift + AltGr` state.** Legacy Khmer has a fifth state holding
   `U+19E0..U+19FF`, a block of Khmer symbols that NiDA users cannot reach at
   all.
4. **The ligature mechanism is keyed by `(vk, modifier number)`, not by chord
   string**, and it is the *only* place a keystroke may emit more than one code
   point. A re-implementation that treats ligatures as dead keys will order the
   two code points backwards.
5. **Keypad decimal produces `,` and `.`** - present in the main table, but its
   scan code (`0x53E`) is outside the range a naive `0x01..0x58` scan covers, so
   the behavioural probe misses it entirely.

---

## 11. Not decoded

Stated plainly so the record is honest about its limits:

| Field | Status |
| :-- | :-- |
| descriptor `+0x50` flags | value observed (`0x00010001` for both Khmer layouts, `0x00010000` for US); meaning not established |
| `pVkToBit` mask per key | dumped verbatim in `tables_kbdkni.json` as `vkModifierMasks`, but the bit semantics are not established |
| `puVKeyToCodes` / `cbVKeyToCodes` | dumped; not interpreted |
| `pTypedef` | shared, layout-independent typedef list; not interpreted |
| key-name tables | located; not needed for character mapping |

None of these affect the character mapping, which is fully verified.

### Resolved by the Control probe

The one reading previously listed as unverified is now settled. Table 0's third
slot was inferred to be the Control character; probing `ToUnicodeEx` with
`VK_CONTROL` held confirms it on all 4 keys. The probe also disproved the
earlier "table 2 is a control-character map" claim: holding Control on those
keys emits nothing, and their stored values are the plain unshifted characters.

---

## 12. Reproducing

Everything at once:

```powershell
.\scripts\verify_all.ps1                    # rebuild + verify, from scratch
.\scripts\verify_all.ps1 -SkipRegenerate    # verify committed artifacts only
```

Stage by stage:

```powershell
# structural decode of every layout
.\scripts\dump_kbd_tables.ps1 -Dll kbdkni.dll
.\scripts\dump_kbd_tables.ps1 -Dll kbdkhmr.dll
.\scripts\dump_kbd_tables.ps1 -Dll kbdus.dll

# behavioural probe (the oracle)
.\scripts\dump_layout.ps1

# cross-check the two; exits 1 on any disagreement
.\scripts\verify_tables.ps1 -TablesCsv tables_kbdkni.csv -ProbeCsv kni_layout.csv
.\scripts\verify_tables.ps1 -TablesCsv tables_kbdkhmr.csv -ProbeCsv khmr_layout.csv

# probe Control, then confirm the secondary tables against it
.\scripts\dump_layout_control.ps1
.\scripts\verify_control.ps1

# refresh official Unicode names, then rebuild the spec
.\scripts\build_unicode_names.ps1
.\scripts\export_nida_spec.ps1
```

The regenerated artifacts are byte-identical to the committed ones, so the
pipeline is deterministic: any diff after a clean run means a real change.

---

## 13. Artifacts

| File | Contents |
| :-- | :-- |
| `nida_layout.json` | authoritative NiDA specification: 49 keys, 5 ligatures, all states |
| `tables_kbdkni.json` / `.csv` | every table decoded straight from the DLL |
| `tables_kbdkhmr.json` / `.csv` | same for the legacy layout |
| `tables_kbdus.json` / `.csv` | same for US, used as the structural control |
| `kni_layout.csv` | behavioural probe of NiDA |
| `khmr_layout.csv` | behavioural probe of legacy Khmer |
| `kni_control.csv` | behavioural probe of NiDA with Control held |
| `us_control.csv` | same probe for US, used to test table 2's role |
