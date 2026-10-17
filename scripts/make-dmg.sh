#!/bin/bash
# Crea build/PoxiDrop-<versión>.dmg con la app y un acceso a Aplicaciones para arrastrarla.
set -euo pipefail
cd "$(dirname "$0")/.."

VERSION=$(/usr/libexec/PlistBuddy -c "Print CFBundleShortVersionString" build/PoxiDrop.app/Contents/Info.plist)
STAGE=build/dmg
OUT="build/PoxiDrop-$VERSION.dmg"

rm -rf "$STAGE" "$OUT"
mkdir -p "$STAGE"
cp -R build/PoxiDrop.app "$STAGE/"
ln -s /Applications "$STAGE/Aplicaciones"
hdiutil create -volname "PoxiDrop $VERSION" -srcfolder "$STAGE" -fs HFS+ -format UDZO -ov "$OUT" >/dev/null
rm -rf "$STAGE"
echo "Listo: $OUT ($(du -h "$OUT" | cut -f1))"
