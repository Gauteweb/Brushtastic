#!/usr/bin/env bash
# Builds build/Brushtastic.app (only needs the Xcode Command Line Tools).
# Also used by the Homebrew formula (gauteweb/tap/brushtastic).
set -euo pipefail
cd "$(dirname "$0")"

VERSION="1.0.1"   # shown in the menu and in Finder
BUILD="2"

APP="build/Brushtastic.app"
rm -rf "$APP"
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources"

# Compile with swiftc directly (no SwiftPM), so it also works in Homebrew's sandbox.
swiftc -O -swift-version 5 \
    -framework AppKit -framework Carbon -framework ServiceManagement \
    -o "$APP/Contents/MacOS/Brushtastic" \
    Sources/Brushtastic/*.swift

# App icon: AppIcon.png (made from ikon.svg by make-icon.sh) -> .iconset -> AppIcon.icns
ICONSET="build/AppIcon.iconset"
rm -rf "$ICONSET"
mkdir -p "$ICONSET"
for size in 16 32 128 256 512; do
    sips -z $size $size AppIcon.png --out "$ICONSET/icon_${size}x${size}.png" >/dev/null
    sips -z $((size * 2)) $((size * 2)) AppIcon.png --out "$ICONSET/icon_${size}x${size}@2x.png" >/dev/null
done
iconutil -c icns "$ICONSET" -o "$APP/Contents/Resources/AppIcon.icns"
rm -rf "$ICONSET"

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

codesign --force --sign - "$APP" >/dev/null 2>&1
# Ask Finder/Dock to refresh the icon cache for the app.
touch "$APP"
echo "Built $APP (version $VERSION)"
