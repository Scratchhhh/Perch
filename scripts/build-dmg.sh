#!/usr/bin/env bash
set -euo pipefail

cd "$(dirname "$0")/.."

BUILD_DIR="build"
DERIVED="$BUILD_DIR/DerivedData"
PRODUCTS="$PWD/$BUILD_DIR/Release"
DMG="$BUILD_DIR/Perch.dmg"

rm -rf "$PRODUCTS" "$DMG"
mkdir -p "$PRODUCTS"

echo "==> Building Release"
xcodebuild -scheme Perch -configuration Release -destination 'platform=macOS' \
    -derivedDataPath "$DERIVED" \
    CONFIGURATION_BUILD_DIR="$PRODUCTS" \
    build

APP="$PRODUCTS/Perch.app"
if [ ! -d "$APP" ]; then
    echo "error: build did not produce $APP" >&2
    exit 1
fi

echo "==> Packaging DMG"
STAGING="$(mktemp -d)"
cp -R "$APP" "$STAGING/"
ln -s /Applications "$STAGING/Applications"
hdiutil create -volname "Perch" -srcfolder "$STAGING" -ov -format UDZO "$DMG" >/dev/null
rm -rf "$STAGING"

echo "==> Done: $DMG"
echo "    To distribute, sign with a Developer ID and notarize (see README)."
