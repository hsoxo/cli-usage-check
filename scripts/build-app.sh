#!/bin/bash
# Build AI Usage Check menubar app and wrap the SPM executable in a .app bundle.
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT"

CONFIG="${CONFIG:-release}"
ARCH="${ARCH:-native}"
APP_NAME="AI Usage Check"
APP_DIR="$ROOT/build/${APP_NAME}.app"
EXECUTABLE_NAME="AIUsageCheck"

case "$ARCH" in
    native)
        echo "[1/4] swift build (-c $CONFIG)"
        swift build -c "$CONFIG"
        BIN_PATH="$ROOT/.build/$CONFIG/$EXECUTABLE_NAME"
        ;;
    arm64|x86_64)
        echo "[1/4] swift build (-c $CONFIG --arch $ARCH)"
        swift build -c "$CONFIG" --arch "$ARCH"
        BIN_PATH="$ROOT/.build/${ARCH}-apple-macosx/$CONFIG/$EXECUTABLE_NAME"
        ;;
    universal)
        echo "[1/4] swift build (-c $CONFIG --arch arm64 + --arch x86_64)"
        swift build -c "$CONFIG" --arch arm64
        swift build -c "$CONFIG" --arch x86_64

        UNIVERSAL_DIR="$ROOT/.build/universal/$CONFIG"
        BIN_PATH="$UNIVERSAL_DIR/$EXECUTABLE_NAME"
        mkdir -p "$UNIVERSAL_DIR"
        rm -f "$BIN_PATH"
        lipo -create \
            "$ROOT/.build/arm64-apple-macosx/$CONFIG/$EXECUTABLE_NAME" \
            "$ROOT/.build/x86_64-apple-macosx/$CONFIG/$EXECUTABLE_NAME" \
            -output "$BIN_PATH"
        ;;
    *)
        echo "Unsupported ARCH=$ARCH (expected native, arm64, x86_64, or universal)" >&2
        exit 1
        ;;
esac

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
