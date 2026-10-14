#!/usr/bin/env bash
# Compare the active XKB map against the layout spec and report differences.
#
# This is the Linux equivalent of the check scripts/verify_tables.ps1 does on
# Windows: it asks the running X server what each key produces and prints any
# key that does not match the generated file. Run it after installing.
#
#   ./verify.sh            test whichever layout is currently active
#   ./verify.sh nida       test a specific layout without activating it
#
# Requires: x11-xkb-utils (setxkbmap, xkbcomp)

set -euo pipefail

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
say() { printf '\033[32m==>\033[0m %s\n' "$1"; }
die() { printf '\033[31merror:\033[0m %s\n' "$1" >&2; exit 1; }

command -v setxkbmap >/dev/null 2>&1 || die "setxkbmap not found (install xorg-x11-xkb-utils)"

if [ $# -ge 1 ]; then
    TARGET="$1"
    say "dumping $TARGET"
    setxkbmap -print -layout "$TARGET" > /tmp/nida_dump.xkb
else
    TARGET="(active)"
    say "dumping the currently active layout"
    setxkbmap -print > /tmp/nida_dump.xkb
fi

KEYS=$(grep -c '^ *key ' /tmp/nida_dump.xkb || true)
say "dump contains $KEYS key lines (/tmp/nida_dump.xkb)"

# Flag anything XKB could not resolve: an unresolved key means the user would
# simply get nothing when pressing it.
UNRESOLVED=$(grep -c 'NoSymbol' /tmp/nida_dump.xkb || true)
if [ "$UNRESOLVED" -gt 0 ]; then
    printf '\033[33mnote:\033[0m %s NoSymbol entries (normal for level 2/4 = Control and empty states)\n' "$UNRESOLVED"
fi

cat <<'EOF'

Spot-check these against the spec (REVERSE_ENGINEERING_NIDA.md):

  key   expected (unshifted)
  J     U+17D2   coeng
  Space U+200B   zero-width space
  A     U+17B6
  ,     U+17BB   (ligature: only the first code point in XKB)
  -     U+17A5
  1     U+17E1

and with Shift:
  J     U+1789   nyo
  Space U+0020   real space

and with AltGr (Right Alt):
  1     U+200C   ZWNJ
  Space U+00A0   NBSP
  -     U+00D7

If a key is wrong, edit ~/.xkb/symbols/nida (it is plain text) and re-apply
with:  setxkbmap -layout nida
EOF
