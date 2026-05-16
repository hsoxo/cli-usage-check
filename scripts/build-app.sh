#!/bin/bash
# Build AI Usage Check menubar app and wrap the SPM executable in a .app bundle.
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT"

CONFIG="${CONFIG:-release}"
APP_NAME="AI Usage Check"
APP_DIR="$ROOT/build/${APP_NAME}.app"
EXECUTABLE_NAME="AIUsageCheck"

echo "[1/4] swift build (-c $CONFIG)"
swift build -c "$CONFIG"

BIN_PATH="$ROOT/.build/$CONFIG/$EXECUTABLE_NAME"
if [[ ! -f "$BIN_PATH" ]]; then
    echo "Build failed: $BIN_PATH not found" >&2
    exit 1
fi

echo "[2/4] Cleaning $APP_DIR"
rm -rf "$APP_DIR"
mkdir -p "$APP_DIR/Contents/MacOS" "$APP_DIR/Contents/Resources"

echo "[3/4] Copying binary + Info.plist"
cp "$BIN_PATH" "$APP_DIR/Contents/MacOS/$EXECUTABLE_NAME"
cp "$ROOT/Resources/Info.plist" "$APP_DIR/Contents/Info.plist"
chmod +x "$APP_DIR/Contents/MacOS/$EXECUTABLE_NAME"

echo "[4/4] Codesign (ad-hoc)"
codesign --force --deep --sign - "$APP_DIR" 2>&1 | sed 's/^/  /' || true

echo ""
echo "Built: $APP_DIR"
echo "Launch: open \"$APP_DIR\""
