#!/bin/bash
set -euo pipefail

PROJECT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
BUILD_DIR="$PROJECT_DIR/build"
APP_NAME="Codex 安装助手.app"
APP_PATH="$BUILD_DIR/$APP_NAME"
CONTENTS="$APP_PATH/Contents"
EXECUTABLE="$CONTENTS/MacOS/CodexInstallerHelper"
VERSION="${VERSION:-0.1.0}"
BUILD_NUMBER="${BUILD_NUMBER:-1}"
SIGNING_IDENTITY="${SIGNING_IDENTITY:--}"
UNIVERSAL="${UNIVERSAL:-1}"

mkdir -p "$BUILD_DIR"
rm -rf "$APP_PATH" "$BUILD_DIR/AppIcon.iconset"
mkdir -p "$CONTENTS/MacOS" "$CONTENTS/Resources"

build_binary() {
    local triple="$1"
    local scratch="$2"
    swift build \
        --package-path "$PROJECT_DIR" \
        --scratch-path "$scratch" \
        --triple "$triple" \
        -c release \
        --product CodexInstallerHelper
    swift build \
        --package-path "$PROJECT_DIR" \
        --scratch-path "$scratch" \
        --triple "$triple" \
        -c release \
        --show-bin-path
}

if [ "$UNIVERSAL" = "1" ]; then
    ARM_BIN_DIR="$(build_binary arm64-apple-macosx13.0 "$BUILD_DIR/.swift-arm64" | tail -n 1)"
    INTEL_BIN_DIR="$(build_binary x86_64-apple-macosx13.0 "$BUILD_DIR/.swift-x86_64" | tail -n 1)"
    lipo -create \
        "$ARM_BIN_DIR/CodexInstallerHelper" \
        "$INTEL_BIN_DIR/CodexInstallerHelper" \
        -output "$EXECUTABLE"
else
    swift build --package-path "$PROJECT_DIR" -c release --product CodexInstallerHelper
    BIN_DIR="$(swift build --package-path "$PROJECT_DIR" -c release --show-bin-path)"
    cp "$BIN_DIR/CodexInstallerHelper" "$EXECUTABLE"
fi
chmod 755 "$EXECUTABLE"

cp "$PROJECT_DIR/Resources/Info.plist" "$CONTENTS/Info.plist"
cp "$PROJECT_DIR/Resources/PrivacyInfo.xcprivacy" "$CONTENTS/Resources/PrivacyInfo.xcprivacy"
plutil -replace CFBundleShortVersionString -string "$VERSION" "$CONTENTS/Info.plist"
plutil -replace CFBundleVersion -string "$BUILD_NUMBER" "$CONTENTS/Info.plist"

ICON_PNG="$BUILD_DIR/AppIcon-1024.png"
swift "$PROJECT_DIR/scripts/generate-icon.swift" "$ICON_PNG"
ICONSET="$BUILD_DIR/AppIcon.iconset"
mkdir -p "$ICONSET"
sips -z 16 16 "$ICON_PNG" --out "$ICONSET/icon_16x16.png" >/dev/null
sips -z 32 32 "$ICON_PNG" --out "$ICONSET/icon_16x16@2x.png" >/dev/null
sips -z 32 32 "$ICON_PNG" --out "$ICONSET/icon_32x32.png" >/dev/null
sips -z 64 64 "$ICON_PNG" --out "$ICONSET/icon_32x32@2x.png" >/dev/null
sips -z 128 128 "$ICON_PNG" --out "$ICONSET/icon_128x128.png" >/dev/null
sips -z 256 256 "$ICON_PNG" --out "$ICONSET/icon_128x128@2x.png" >/dev/null
sips -z 256 256 "$ICON_PNG" --out "$ICONSET/icon_256x256.png" >/dev/null
sips -z 512 512 "$ICON_PNG" --out "$ICONSET/icon_256x256@2x.png" >/dev/null
sips -z 512 512 "$ICON_PNG" --out "$ICONSET/icon_512x512.png" >/dev/null
cp "$ICON_PNG" "$ICONSET/icon_512x512@2x.png"
iconutil -c icns "$ICONSET" -o "$CONTENTS/Resources/AppIcon.icns"

if [ "$SIGNING_IDENTITY" = "-" ]; then
    codesign --force --sign - --identifier top.wanzhuoran.codex-installer-helper "$APP_PATH"
else
    codesign \
        --force \
        --options runtime \
        --timestamp \
        --sign "$SIGNING_IDENTITY" \
        --identifier top.wanzhuoran.codex-installer-helper \
        "$APP_PATH"
fi

plutil -lint "$CONTENTS/Info.plist"
codesign --verify --strict --verbose=2 "$APP_PATH"
test -x "$EXECUTABLE"
test -f "$CONTENTS/Resources/AppIcon.icns"
test -f "$CONTENTS/Resources/PrivacyInfo.xcprivacy"
if [ "$UNIVERSAL" = "1" ]; then
    lipo "$EXECUTABLE" -verify_arch arm64 x86_64
    lipo -info "$EXECUTABLE"
fi

echo "App bundle: $APP_PATH"
