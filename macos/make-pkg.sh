#!/usr/bin/env bash
# Build a double-clickable installer package for the Khmer NiDA layouts.
#
# Run this ONCE on a Mac; it produces dist/Khmer-NiDA-Layouts.pkg which you can
# then hand to anyone - they double-click it and the layouts are installed
# system-wide, no Terminal required.
#
#   ./make-pkg.sh
#
# Requires macOS and the Xcode command line tools (for pkgbuild).

set -euo pipefail

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
DIST="$HERE/dist"
BUILD="$HERE/.pkgbuild"
VERSION="1.0.0"

say() { printf '\033[32m==>\033[0m %s\n' "$1"; }
die() { printf '\033[31merror:\033[0m %s\n' "$1" >&2; exit 1; }

[ "$(uname -s)" = "Darwin" ] || die "pkgbuild only exists on macOS - run this on a Mac"
command -v pkgbuild >/dev/null 2>&1 || die "pkgbuild not found. Install the Xcode command line tools: xcode-select --install"

shopt -s nullglob
layouts=("$HERE"/*.keylayout)
[ ${#layouts[@]} -gt 0 ] || die "no .keylayout files found next to this script"

rm -rf "$BUILD" "$DIST"
mkdir -p "$BUILD/Library/Keyboard Layouts" "$DIST"

for f in "${layouts[@]}"; do
    cp "$f" "$BUILD/Library/Keyboard Layouts/"
done
say "staged ${#layouts[@]} layout(s)"

# A postinstall that refreshes the layout cache, so the user does not have to
# log out before System Settings shows them.
cat > "$BUILD/postinstall" <<'EOF'
#!/bin/sh
killall -HUP SystemUIServer 2>/dev/null || true
exit 0
EOF
chmod +x "$BUILD/postinstall"

PKG="$DIST/Khmer-NiDA-Layouts-$VERSION.pkg"
pkgbuild --root "$BUILD" \
         --scripts "$BUILD" \
         --identifier "com.github.airiharuki.betternida.keylayout" \
         --version "$VERSION" \
         --install-location "/" \
         "$PKG"

say "built $PKG"
printf '\nDouble-click it, or install from the command line:\n  sudo installer -pkg "%s" -target /\n' "$PKG"
