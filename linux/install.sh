#!/usr/bin/env bash
# Install the Khmer NiDA XKB layouts for the current user (no root needed).
#
# Everything is plain text under ~/.xkb, so you can edit the files afterwards
# and re-apply without reinstalling. Nothing outside your home directory is
# touched, and running it twice is safe.
#
#   ./install.sh              install both layouts and activate "nida"
#   ./install.sh nida         install and activate Khmer NiDA
#   ./install.sh nida_legacy  install and activate Khmer NiDA Legacy
#   ./install.sh --test       compile-check only, change nothing
#   ./install.sh --remove     remove both layouts

set -euo pipefail

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
XKB="$HOME/.xkb"
SYMBOLS="$XKB/symbols"
RULES="$XKB/rules"
LAYOUTS=(nida nida_legacy)

have() { command -v "$1" >/dev/null 2>&1; }

die() { printf '\033[31merror:\033[0m %s\n' "$1" >&2; exit 1; }
say() { printf '\033[32m==>\033[0m %s\n' "$1"; }
warn() { printf '\033[33mwarn:\033[0m %s\n' "$1" >&2; }

# --- remove -----------------------------------------------------------------
if [ "${1-}" = "--remove" ]; then
    for l in "${LAYOUTS[@]}"; do rm -f "$SYMBOLS/$l"; done
    if [ -f "$RULES/evdev.lst.nida" ]; then
        # strip our marker block back out of evdev.lst
        sed -i '/# >>> Better-NiDA/,/# <<< Better-NiDA/d' "$RULES/evdev.lst" 2>/dev/null || true
        rm -f "$RULES/evdev.lst.nida"
    fi
    say "removed. pick another layout with: setxkbmap -layout us"
    exit 0
fi

have setxkbmap || die "setxkbmap not found. Install xorg-x11-xkb-utils (Debian/Ubuntu) or xorg-x11-xkb-utils (Fedora)."

# --- copy symbols -----------------------------------------------------------
mkdir -p "$SYMBOLS" "$RULES"
for l in "${LAYOUTS[@]}"; do
    [ -f "$HERE/$l" ] || die "missing $HERE/$l"
    cp "$HERE/$l" "$SYMBOLS/$l"
    say "installed symbols: ~/.xkb/symbols/$l"
done

# --- register in the rules file --------------------------------------------
# evdev.lst is the classic registration format; libxkbcomp still reads it and
# it needs no root. Anything between the markers is ours.
mkdir -p "$RULES"
touch "$RULES/evdev.lst"
if ! grep -q '# >>> Better-NiDA' "$RULES/evdev.lst" 2>/dev/null; then
    cat >> "$RULES/evdev.lst" <<'EOF'

# >>> Better-NiDA
! model          layout     variant
  *             nida
  *             nida_legacy
# <<< Better-NiDA
EOF
    say "registered both layouts in ~/.xkb/rules/evdev.lst"
fi

# --- validate ---------------------------------------------------------------
if have xkbcomp; then
    for l in "${LAYOUTS[@]}"; do
        if xkbcomp -w0 -I"$XKB" -I/usr/share/X11/xkb \
                   ":nida${l#nida}" "$SYMBOLS/$l" >/dev/null 2>/tmp/nida_xkb_err; then
            say "xkbcomp: $l compiles"
        else
            warn "xkbcomp could not fully compile $l on its own (expected: it has no keymap header)."
            warn "see /tmp/nida_xkb_err"
        fi
    done
else
    warn "xkbcomp not installed; skipping compile check"
fi

if [ "${1-}" = "--test" ]; then
    say "test mode: nothing was activated"
    printf '\nTo try a layout for the current session only:\n  setxkbmap -layout nida\n'
    exit 0
fi

# --- activate ---------------------------------------------------------------
TARGET="${1:-nida}"
case "$TARGET" in
    nida|nida_legacy) ;;
    *) die "unknown layout '$TARGET' (use nida or nida_legacy)" ;;
esac

setxkbmap -layout "$TARGET" || die "setxkbmap failed"
say "activated: $TARGET"

cat <<'EOF'

Your session is set up. To keep it across logins, copy the command
setxkbmap printed above into your session startup file, for example:

  echo 'setxkbmap -layout nida' >> ~/.xprofile

For a desktop menu entry instead, GNOME Settings / KDE System Settings ->
Keyboard -> Layouts -> Add -> Other -> search for "nida".

To change layout later:
  setxkbmap -layout nida_legacy

To edit the layout by hand (it is just text):
  nano ~/.xkb/symbols/nida
then re-apply with:  setxkbmap -layout nida

LIGATURE NOTE
  XKB gives each key one character per level, so the Windows driver's
  multi-character ligatures (Shift+A, Shift+V, Shift+;, comma) cannot be
  produced by this file - they emit only the first character. The lines
  concerned are marked "LIGATURE truncated". For those, see m17n/ .
EOF
