# Khmer NiDA for macOS

Two keyboard layouts, generated from the reverse-engineered Windows driver
(`kbdkni.dll`):

| File | Layout | Source |
| :-- | :-- | :-- |
| `Khmer NiDA.keylayout` | Khmer NiDA | `kbdkni.dll` (KLID `00010453`) |
| `Khmer NiDA Legacy.keylayout` | Khmer NiDA Legacy | `kbdkhmr.dll` (KLID `00000453`) |

They differ on about eight keys - most visibly, NiDA puts the coeng
subscript on `J` and the zero-width space on the spacebar, while the legacy
layout swaps those around. See
[REVERSE_ENGINEERING_NIDA.md](../REVERSE_ENGINEERING_NIDA.md) for the full
comparison.

**macOS is the better of the two platforms for this layout**: unlike XKB, a
macOS keylayout can emit several characters from one key press, so all five
ligatures work here exactly as they do on Windows.

---

## Install

### The easy way - double-click

Build the installer once, on any Mac:

```sh
./make-pkg.sh
```

That produces `dist/Khmer-NiDA-Layouts-1.0.0.pkg`. Double-click it and follow
the prompts. It installs system-wide, so it will ask for your password.

### The no-installer way

```sh
./install.sh
```

Copies both layouts into `~/Library/Keyboard Layouts`. No password needed -
this only affects your own account.

Then enable them:

**System Settings -> Keyboard -> Text Input -> Edit... -> `+` -> Others...**

Pick "Khmer NiDA" or "Khmer NiDA Legacy". If they do not appear straight
away, log out and back in: macOS caches the keyboard layout list and the
installer only nudges it.

### From the shell

```sh
defaults write com.apple.HIToolbox AppleEnabledInputSources -array-add '<dict>
  <key>InputSourceKind</key><string>Keyboard Layout</string>
  <key>KeyboardLayout Name</key><string>Khmer NiDA</string>
</dict>'
killall SystemUIServer
```

### Remove

```sh
sudo rm '/Library/Keyboard Layouts/Khmer NiDA.keylayout' \
        '/Library/Keyboard Layouts/Khmer NiDA Legacy.keylayout'
# or, for a user-level install:
rm ~/Library/Keyboard\ Layouts/Khmer*.keylayout
killall SystemUIServer
```

Also remove it from **System Settings -> Keyboard -> Text Input** so it is not
listed as missing.

---

## Check it

| Key | Unshifted | Shift | Option (AltGr) |
| :-- | :-- | :-- | :-- |
| `J` | `U+17D2` coeng | `U+1789` nyo | |
| `Space` | `U+200B` ZWSP | `U+0020` real space | `U+00A0` NBSP |
| `1` | `U+17E1` | `U+0021` | `U+200C` ZWNJ |
| `-` | `U+17A5` | `U+17CC` | `U+00D7` |
| `` ` `` | `U+00AB` | `U+00BB` | `U+200D` ZWJ |

And the ligatures, which should all be single key presses:

| Key | Result |
| :-- | :-- |
| `Shift+A` | `U+17B6 U+17C6` ាំ |
| `Shift+V` | `U+17C1 U+17C7` េះ |
| `Shift+;` | `U+17C4 U+17C7` ោះ |
| `,` | `U+17BB U+17C6` ុំ |
| `Shift+,` | `U+17BB U+17C7` ុះ |

Type them into a Unicode-aware editor (TextEdit, VS Code) - if a character
appears missing, the app may not handle Khmer shaping rather than the layout
being wrong.

---

## Editing it yourself

The layouts are plain XML. Open one in any text editor:

```sh
open -e 'Khmer NiDA.keylayout'     # opens in TextEdit
```

A key line looks like this:

```xml
<key code="24" output="៤"/>
```

`code` is the Apple virtual key code, `output` is what gets typed. Change
either, copy the file back into `~/Library/Keyboard Layouts`, and log out and
back in - macOS caches compiled layouts aggressively.

### Regenerating from source

The files are generated, so hand edits are overwritten by a regeneration.
Edit the generator instead:

```sh
# from the repository root, on Windows
pwsh ./scripts/build_platform_layouts.ps1
pwsh ./scripts/verify_platform_layouts.ps1
```

### If you add a longer ligature

The `keyboard` element carries `maxout="3"`, the longest string one key press
may emit. It is generous for the two-character ligatures here, but if you add a
four-character sequence, raise it to match or macOS will silently truncate.

---

## Testing status

These files were **generated on Windows** and checked structurally there
(XML well-formedness, no duplicate key codes, a non-empty base layer, and all
five ligatures compared byte-for-byte against `nida_layout.json`). They have
**not** been loaded on a macOS machine. Check the table above on real hardware
before relying on them, and please open an issue if anything is off.