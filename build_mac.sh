#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")"

echo "=== Snake: build Snake.app and Snake.dmg ==="

if ! xcrun --find swiftc >/dev/null 2>&1; then
    echo "Swift compiler not found. Run this once, then start the script again:"
    echo "    xcode-select --install"
    exit 1
fi

ARCH="$(uname -m)"
SDK="$(xcrun --sdk macosx --show-sdk-path)"
echo "Swift: $(xcrun swiftc --version 2>&1 | head -1)"
echo "SDK:   $SDK"

APP="build/Snake.app"
rm -rf build Snake.dmg
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources"

echo "Compiling..."
xcrun swiftc -O -parse-as-library -swift-version 5 \
    -target "$ARCH-apple-macos15.0" -sdk "$SDK" \
    Sources/*.swift -o "$APP/Contents/MacOS/Snake"

cp Info.plist "$APP/Contents/Info.plist"
cp snake.icns "$APP/Contents/Resources/snake.icns"

echo "Signing (ad-hoc)..."
xattr -cr "$APP"
codesign --force --deep --sign - "$APP"

echo "Creating DMG..."
mkdir -p build/dmg
cp -R "$APP" build/dmg/
ln -s /Applications build/dmg/Applications
hdiutil create -volname "Snake" -srcfolder build/dmg -ov -format UDZO Snake.dmg >/dev/null

echo
echo "Done!"
echo "  App: $(pwd)/$APP"
echo "  DMG: $(pwd)/Snake.dmg"
open -R Snake.dmg
