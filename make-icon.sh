#!/usr/bin/env bash
# Regenerates AppIcon.png (1024x1024, with Apple-style margin) from ikon.svg.
# Run this after changing ikon.svg and commit the resulting AppIcon.png.
# (build.sh uses the PNG, so building also works where Quick Look is unavailable,
# e.g. inside Homebrew's build sandbox.)
set -euo pipefail
cd "$(dirname "$0")"

WORK="$(mktemp -d)"
trap 'rm -rf "$WORK"' EXIT

# Apple icon grid: the artwork is 824 of 1024 px, centered (100 px margin).
perl -0pe 's/(<svg\b[^>]*>)/$1\n<g transform="translate(100 100) scale(0.8046875)">/; s/<\/svg>\s*$/<\/g>\n<\/svg>\n/' \
    ikon.svg > "$WORK/ikon.svg"
qlmanage -t -s 1024 -o "$WORK" "$WORK/ikon.svg" >/dev/null 2>&1
[ -f "$WORK/ikon.svg.png" ] || { echo "Could not render ikon.svg" >&2; exit 1; }
cp "$WORK/ikon.svg.png" AppIcon.png
echo "Updated AppIcon.png"
