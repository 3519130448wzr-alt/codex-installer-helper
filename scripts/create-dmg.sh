#!/bin/bash
set -euo pipefail

PROJECT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
BUILD_DIR="$PROJECT_DIR/build"
VERSION="${VERSION:-0.1.0}"
SIGNING_IDENTITY="${SIGNING_IDENTITY:--}"
APP_PATH="$BUILD_DIR/Codex 安装助手.app"
DMG_PATH="$BUILD_DIR/Codex-Installer-Helper-$VERSION-macOS.dmg"
STAGING_DIR="$BUILD_DIR/dmg-stage"

"$PROJECT_DIR/scripts/build-app.sh"
rm -rf "$STAGING_DIR"
mkdir -p "$STAGING_DIR"
ditto "$APP_PATH" "$STAGING_DIR/Codex 安装助手.app"
ln -s /Applications "$STAGING_DIR/Applications"
rm -f "$DMG_PATH" "$DMG_PATH.sha256"
hdiutil create \
    -volname "Codex 安装助手" \
    -srcfolder "$STAGING_DIR" \
    -ov \
    -format UDZO \
    "$DMG_PATH"
rm -rf "$STAGING_DIR"

if [ "$SIGNING_IDENTITY" != "-" ]; then
    codesign --force --timestamp --sign "$SIGNING_IDENTITY" "$DMG_PATH"
    codesign --verify --verbose=2 "$DMG_PATH"
fi
hdiutil verify "$DMG_PATH"
shasum -a 256 "$DMG_PATH" > "$DMG_PATH.sha256"
echo "DMG: $DMG_PATH"
