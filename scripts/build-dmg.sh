#!/bin/bash
# Package the already-built .app into a compressed DMG with an Applications shortcut.
# Usage: bash scripts/build-dmg.sh <version>
set -euo pipefail

VERSION="${1:?usage: build-dmg.sh <version>}"
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT"

APP="$ROOT/build/AI Usage Check.app"
if [[ ! -d "$APP" ]]; then
    echo "App not found at $APP — run scripts/build-app.sh first" >&2
    exit 1
fi

STAGING="$ROOT/build/dmg-staging"
DMG="$ROOT/build/AI-Usage-Check-$VERSION.dmg"

echo "[1/3] Staging $STAGING"
rm -rf "$STAGING"
mkdir -p "$STAGING"
cp -R "$APP" "$STAGING/"
ln -s /Applications "$STAGING/Applications"

echo "[2/3] Removing any prior $DMG"
rm -f "$DMG"

echo "[3/3] hdiutil create"
hdiutil create \
    -volname "AI Usage Check" \
    -srcfolder "$STAGING" \
    -ov -format UDZO \
    "$DMG"

rm -rf "$STAGING"
echo ""
echo "DMG: $DMG"
