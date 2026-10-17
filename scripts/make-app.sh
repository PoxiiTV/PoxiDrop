#!/bin/bash
# Compila PoxiDrop en modo release y monta build/PoxiDrop.app (app de barra de menús) firmada ad-hoc.
set -euo pipefail
cd "$(dirname "$0")/.."

VERSION=0.1.0
APP=build/PoxiDrop.app

swift build -c release --arch arm64
BIN="$(swift build -c release --arch arm64 --show-bin-path)/PoxiDrop"

rm -rf "$APP" build/icon.iconset
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources"
cp "$BIN" "$APP/Contents/MacOS/PoxiDrop"

swiftc -target arm64-apple-macosx14.0 scripts/make-icon.swift -o build/make-icon
build/make-icon build/icon-1024.png
mkdir build/icon.iconset
for s in 16 32 128 256 512; do
    sips -z $s $s build/icon-1024.png --out "build/icon.iconset/icon_${s}x${s}.png" >/dev/null
    sips -z $((s*2)) $((s*2)) build/icon-1024.png --out "build/icon.iconset/icon_${s}x${s}@2x.png" >/dev/null
done
iconutil -c icns build/icon.iconset -o "$APP/Contents/Resources/PoxiDrop.icns"

cat > "$APP/Contents/Info.plist" <<PLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>CFBundleName</key><string>PoxiDrop</string>
    <key>CFBundleDisplayName</key><string>PoxiDrop</string>
    <key>CFBundleIdentifier</key><string>dev.alexiis.poxidrop</string>
    <key>CFBundleExecutable</key><string>PoxiDrop</string>
    <key>CFBundleIconFile</key><string>PoxiDrop</string>
    <key>CFBundlePackageType</key><string>APPL</string>
    <key>CFBundleDevelopmentRegion</key><string>es</string>
    <key>CFBundleLocalizations</key><array><string>es</string></array>
    <key>CFBundleShortVersionString</key><string>$VERSION</string>
    <key>CFBundleVersion</key><string>1</string>
    <key>LSMinimumSystemVersion</key><string>14.0</string>
    <key>LSUIElement</key><true/>
    <key>NSHighResolutionCapable</key><true/>
    <key>NSHumanReadableCopyright</key><string>Software libre (GPL-3.0). Hecho por Alexis Juárez.</string>
</dict>
</plist>
PLIST

codesign --force --deep --sign - "$APP"
echo "Listo: $APP"
