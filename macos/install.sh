#!/usr/bin/env bash
# Install the Khmer NiDA keyboard layouts for macOS (current user, no sudo).
#
#   ./install.sh        copy both layouts to ~/Library/Keyboard Layouts
#   ./make-pkg.sh       build a double-clickable .pkg instead (needs a Mac)
#
# The layouts are plain XML. Edit them with any text editor and re-copy.

set -euo pipefail

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
DEST="$HOME/Library/Keyboard Layouts"

say() { printf '\033[32m==>\033[0m %s\n' "$1"; }
die() { printf '\033[31merror:\033[0m %s\n' "$1" >&2; exit 1; }

[ "$(uname -s)" = "Darwin" ] || die "this installer is macOS only"

mkdir -p "$DEST"
found=0
for f in "$HERE"/*.keylayout; do
    [ -e "$f" ] || continue
    name="$(basename "$f")"
    cp "$f" "$DEST/$name"
    say "copied $name to ~/Library/Keyboard Layouts"
    found=1
done
[ "$found" -eq 1 ] || die "no .keylayout files found next to this script"

# macOS caches the keyboard layout list; nudge it to rescan. Needs no
# privileges in most cases, so failure here is not fatal - we tell the user to
# log out and back in instead.
killall -HUP SystemUIServer 2>/dev/null || true

cat <<'EOF'

macOS caches its keyboard layout list, so if the layouts do not appear
straight away, log out and back in (or restart).

Then enable them:

  System Settings -> Keyboard -> Text Input -> Edit ->
    " + " (add) -> Others... -> pick "Khmer NiDA" or "Khmer NiDA Legacy"

To do it from the shell instead:

  defaults write com.apple.HIToolbox AppleEnabledInputSources -array-add '<dict>
    <key>InputSourceKind</key><string>Keyboard Layout</string>
    <key>KeyboardLayout Name</key><string>Khmer NiDA</string>
  </dict>'
  killall SystemUIServer

Undo:

  rm ~/Library/Keyboard\ Layouts/Khmer*.keylayout
  killall SystemUIServer

EDITING

  The layouts are plain XML. Open one in any text editor, change the
  characters, copy it back over, then log out and back in.

LIGATURES

  Unlike XKB, macOS layouts CAN emit several characters from one key press,
  so all five ligatures work here:
      Shift+A  -> U+17B6 U+17C6
      Shift+V  -> U+17C1 U+17C7
      Shift+;  -> U+17C4 U+17C7
      ,        -> U+17BB U+17C6
      Shift+,  -> U+17BB U+17C7

  If you ever make an output longer than 3 characters, raise the keyboard
  element's maxout="3" attribute to match.
EOF
