#!/bin/bash
# Builds woutage.app and installs it into /Applications.
set -euo pipefail

APP_NAME="woutage"
ROOT="$(cd "$(dirname "$0")" && pwd)"
BUILD_DIR="$ROOT/build"
APP="$BUILD_DIR/$APP_NAME.app"
DEST="${1:-/Applications}"

rm -rf "$BUILD_DIR"
mkdir -p "$APP/Contents/MacOS"

echo "==> Compiling"
swiftc "$ROOT"/Sources/*.swift "$ROOT"/Sources/Views/*.swift \
    -o "$APP/Contents/MacOS/$APP_NAME" \
    -framework Cocoa -framework SwiftUI -framework IOKit \
    -O

cp "$ROOT/Resources/Info.plist" "$APP/Contents/Info.plist"

echo "==> Signing (ad-hoc)"
codesign --force --sign - "$APP"

echo "==> Installing to $DEST"
osascript -e "tell application \"$APP_NAME\" to quit" 2>/dev/null || true
pkill -f "$DEST/$APP_NAME.app" 2>/dev/null || true
sleep 1
rm -rf "${DEST:?}/$APP_NAME.app"
cp -R "$APP" "$DEST/$APP_NAME.app"

echo "==> Launching"
open "$DEST/$APP_NAME.app"
echo "Done. Look for the bolt icon in your menu bar."
