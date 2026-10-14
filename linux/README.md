# Khmer NiDA for Linux

Two keyboard layouts, generated from the reverse-engineered Windows driver
(`kbdkni.dll`):

| File | Layout | Source |
| :-- | :-- | :-- |
| `nida` | Khmer NiDA | `kbdkni.dll` (KLID `00010453`) |
| `nida_legacy` | Khmer NiDA Legacy | `kbdkhmr.dll` (KLID `00000453`) |

They differ on about eight keys - most visibly, NiDA puts the coeng
subscript on `J` and the zero-width space on the spacebar, while the legacy
layout swaps those around. See
[REVERSE_ENGINEERING_NIDA.md](../REVERSE_ENGINEERING_NIDA.md) for the full
comparison.

---

## Install

```sh
cd linux
./install.sh              # both layouts, activate "nida"
./install.sh nida_legacy  # activate the legacy layout instead
```

No root, no system packages beyond `x11-xkb-utils`. Everything lands in
`~/.xkb`, and running it twice is safe.

To remove:

```sh
./install.sh --remove
```

### If your desktop has a settings app

GNOME, KDE, Xfce and Cinnamon all list XKB layouts. After installing, look
under **Keyboard -> Layouts -> Add -> Others** for "Khmer NiDA".

---

## Test it before you keep it

```sh
./verify.sh          # inspect whichever layout is active
./verify.sh nida     # inspect nida without activating it
```

It prints the active keymap and a short checklist of keys worth confirming
by hand:

| Key | Unshifted | Shift | AltGr (Right Alt) |
| :-- | :-- | :-- | :-- |
| `J` | `U+17D2` coeng | `U+1789` nyo | |
| `Space` | `U+200B` ZWSP | `U+0020` real space | `U+00A0` NBSP |
| `1` | `U+17E1` | `U+0021` | `U+200C` ZWNJ |
| `-` | `U+17A5` | `U+17CC` | `U+00D7` |
| `` ` `` | `U+00AB` | `U+00BB` | `U+200D` ZWJ |

---

## Known limitation: ligatures

**XKB cannot do this.** A key produces exactly one character per level, so
the Windows driver's multi-character ligatures cannot be expressed. Those five
keys emit only their **first** code point:

| Key | Windows emits | XKB emits |
| :-- | :-- | :-- |
| `Shift+A` | `U+17B6 U+17C6` ាំ | `U+17B6` ា |
| `Shift+V` | `U+17C1 U+17C7` េះ | `U+17C1` េ |
| `Shift+;` | `U+17C4 U+17C7` ោះ | `U+17C4` ោ |
| `,` | `U+17BB U+17C6` ុំ | `U+17BB` ុ |
| `Shift+,` | `U+17BB U+17C7` ុះ | `U+17BB` ុ |

Every affected line in the generated file is marked `LIGATURE truncated`, so
you can find them with `grep LIGATURE ~/.xkb/symbols/nida`.

For those, use [`m17n/`](m17n/) instead - see below.

The rest of the layout, including the coeng and the zero-width space, is a
faithful match.

---

## Optional: ligatures via m17n

`m17n/` holds an input method that emits the full ligature sequences. It needs
`m17n-lib`, so it is not the default path.

```sh
mkdir -p ~/.m17n
cp m17n/nida-nida.mim m17n/nida-nida.mim-cs ~/.m17n/
m17n-db < ~/.m17n/nida-nida.mim > ~/.m17n/nida-nida.mimdb   # must be silent
```

Then select it in your desktop's input-method menu, or set:

```sh
export XMODIFIERS=@im=nida
export GTK_IM_MODULE=m17n
export QT_IM_MODULE=m17n
```

`m17n-db` printing nothing means the definition parsed. Anything it prints
is an error worth reading.

---

## Editing it yourself

The layouts are plain text, and edits survive reinstalls of everything else
on your system.

```sh
nano ~/.xkb/symbols/nida     # edit
setxkbmap -layout nida        # re-apply, no log out needed
```

A key line looks like this:

```
    key <AC07>	{ U17D2, U1789, NoSymbol, U200D };
```

That is `J`: unshifted, shifted, control, AltGr. `NoSymbol` means the level
intentionally produces nothing. Code points are written `U` followed by four
hex digits.

To change how many levels a key accepts, edit `key.type` near the top of the
file (`FOUR_LEVEL` here, `EIGHT_LEVEL` for the legacy layout).

### Regenerating from source

The files are generated - do not hand-edit them and expect the change to
survive. Edit the generator instead:

```sh
# from the repository root, on Windows
pwsh ./scripts/build_platform_layouts.ps1
pwsh ./scripts/verify_platform_layouts.ps1
```

---

## Testing status

These files were **generated on Windows** and checked structurally there
(XML/symbol syntax, key names validated against `xkeyboard-config`, and every
base symbol compared against `nida_layout.json`). They have **not** been
loaded on a Linux machine. Run `./verify.sh` and the checklist above on real
hardware before relying on them.