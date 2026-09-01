#!/bin/bash
set -euo pipefail

PROJECT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
VERSION="${VERSION:-0.1.0}"
DMG_PATH="${DMG_PATH:-$PROJECT_DIR/build/Codex-Installer-Helper-$VERSION-macOS.dmg}"

test -f "$DMG_PATH"
if [ -n "${NOTARY_PROFILE:-}" ]; then
    xcrun notarytool submit "$DMG_PATH" --keychain-profile "$NOTARY_PROFILE" --wait
else
    : "${APPLE_API_PRIVATE_KEY_PATH:?Set APPLE_API_PRIVATE_KEY_PATH or NOTARY_PROFILE}"
    : "${APPLE_API_KEY_ID:?Set APPLE_API_KEY_ID or NOTARY_PROFILE}"
    : "${APPLE_API_ISSUER_ID:?Set APPLE_API_ISSUER_ID or NOTARY_PROFILE}"
    xcrun notarytool submit "$DMG_PATH" \
        --key "$APPLE_API_PRIVATE_KEY_PATH" \
        --key-id "$APPLE_API_KEY_ID" \
        --issuer "$APPLE_API_ISSUER_ID" \
        --wait
fi

xcrun stapler staple "$DMG_PATH"
xcrun stapler validate "$DMG_PATH"
spctl --assess --type open --context context:primary-signature --verbose=2 "$DMG_PATH"
shasum -a 256 "$DMG_PATH" > "$DMG_PATH.sha256"
echo "Notarized: $DMG_PATH"
