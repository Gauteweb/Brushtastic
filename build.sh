#!/usr/bin/env bash
# Bygger Brushtastic.app i ./build (krever bare Command Line Tools).
set -euo pipefail
cd "$(dirname "$0")"

VERSION="1.0"   # vises i menyen og i Finder
BUILD="1"

APP="build/Brushtastic.app"
swift build -c release

rm -rf "$APP"
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources"
cp "$(swift build -c release --show-bin-path)/Brushtastic" "$APP/Contents/MacOS/Brushtastic"

# App-ikon: ikon.svg -> PNG (Quick Look) -> .iconset (sips) -> AppIcon.icns (iconutil)
ICONWORK=".build/icon"
rm -rf "$ICONWORK"
mkdir -p "$ICONWORK/AppIcon.iconset"
# Marg som i Apples ikonmal: selve ikonet er 824 av 1024 px, sentrert (100 px luft rundt).
# Pakker innholdet i ikon.svg inn i en skalert gruppe i stedet for å endre originalfilen.
perl -0pe 's/(<svg\b[^>]*>)/$1\n<g transform="translate(100 100) scale(0.8046875)">/; s/<\/svg>\s*$/<\/g>\n<\/svg>\n/' \
    ikon.svg > "$ICONWORK/ikon.svg"
qlmanage -t -s 1024 -o "$ICONWORK" "$ICONWORK/ikon.svg" >/dev/null 2>&1
SRC="$ICONWORK/ikon.svg.png"
[ -f "$SRC" ] || { echo "Klarte ikke å konvertere ikon.svg" >&2; exit 1; }
for size in 16 32 128 256 512; do
    sips -z $size $size "$SRC" --out "$ICONWORK/AppIcon.iconset/icon_${size}x${size}.png" >/dev/null
    double=$((size * 2))
    sips -z $double $double "$SRC" --out "$ICONWORK/AppIcon.iconset/icon_${size}x${size}@2x.png" >/dev/null
done
iconutil -c icns "$ICONWORK/AppIcon.iconset" -o "$APP/Contents/Resources/AppIcon.icns"

cat > "$APP/Contents/Info.plist" <<PLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>CFBundleName</key><string>Brushtastic</string>
    <key>CFBundleDisplayName</key><string>Brushtastic</string>
    <key>CFBundleIdentifier</key><string>com.brushtastic.app</string>
    <key>CFBundleExecutable</key><string>Brushtastic</string>
    <key>CFBundleIconFile</key><string>AppIcon</string>
    <key>CFBundleDevelopmentRegion</key><string>en</string>
    <key>CFBundleLocalizations</key>
    <array><string>en</string><string>nb</string></array>
    <key>CFBundlePackageType</key><string>APPL</string>
    <key>CFBundleShortVersionString</key><string>${VERSION}</string>
    <key>CFBundleVersion</key><string>${BUILD}</string>
    <key>LSMinimumSystemVersion</key><string>13.0</string>
    <key>LSUIElement</key><true/>
    <key>NSHighResolutionCapable</key><true/>
</dict>
</plist>
PLIST

codesign --force --sign - "$APP" >/dev/null
# Be Finder/Dock oppdatere ikon-cachen for appen.
touch "$APP"
echo "Bygget $APP (versjon $VERSION)"
