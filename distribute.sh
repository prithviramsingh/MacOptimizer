#!/bin/bash
# ─────────────────────────────────────────────────────────────────
# Mac Optimizer — Developer ID distribution script
#
# Prerequisites:
#   1. Developer ID Application certificate installed in Keychain
#      (Xcode → Settings → Accounts → Manage Certificates → + → Developer ID Application)
#   2. An app-specific password from https://appleid.apple.com
#      (Sign In & Security → App-Specific Passwords → Generate)
#
# Usage:
#   ./distribute.sh
#
# Environment variables (override defaults):
#   APPLE_ID          Your Apple ID email
#   TEAM_ID           Your 10-char Apple Team ID
#   APP_PASSWORD      App-specific password for notarytool
# ─────────────────────────────────────────────────────────────────
set -euo pipefail
cd "$(dirname "$0")"

# ── Config ────────────────────────────────────────────────────────
BUNDLE_ID="com.prithvibondili.macoptimizer"
APP_NAME="MacOptimizer"
# Fallback version, but usually you want this to match your tag
VERSION="${VERSION:-1.0.4}"
TEAM_ID="${TEAM_ID:-5YCN5GF5G9}"
APPLE_ID="${APPLE_ID:-}"
APP_PASSWORD="${APP_PASSWORD:-}"

BUILD_DIR=".build/distribution"
APP_BUNDLE="$BUILD_DIR/$APP_NAME.app"
DMG_PATH="$BUILD_DIR/$APP_NAME-$VERSION.dmg"
ZIP_PATH="$BUILD_DIR/$APP_NAME.zip"
ENTITLEMENTS="MacOptimizer.entitlements"

# ── Helpers ───────────────────────────────────────────────────────
require_env() {
    if [[ -z "${!1}" ]]; then
        echo "Error: $1 is not set. Export it before running:"
        echo "  export $1=<value>"
        exit 1
    fi
}

step() { echo; echo "▶ $*"; }

# ── Check prerequisites ───────────────────────────────────────────
step "Checking prerequisites..."

CERT=$(security find-identity -v -p codesigning 2>/dev/null | grep "Developer ID Application" | head -1 | sed 's/.*"\(.*\)".*/\1/')
if [[ -z "$CERT" ]]; then
    echo "✗ No 'Developer ID Application' certificate found in Keychain."
    echo ""
    echo "  Create one in Xcode → Settings → Accounts → Manage Certificates"
    echo "  → + → Developer ID Application → Done"
    echo ""
    echo "  Then re-run this script."
    exit 1
fi
echo "✓ Certificate: $CERT"

require_env APPLE_ID
require_env APP_PASSWORD

# ── Build Release ─────────────────────────────────────────────────
step "Building Release binary..."
swift build -c release 2>&1
BINARY=".build/release/$APP_NAME"
echo "✓ Built: $BINARY"

# ── Assemble .app bundle ──────────────────────────────────────────
step "Assembling .app bundle..."
rm -rf "$APP_BUNDLE"
mkdir -p "$APP_BUNDLE/Contents/MacOS"
mkdir -p "$APP_BUNDLE/Contents/Resources"

cp "$BINARY" "$APP_BUNDLE/Contents/MacOS/$APP_NAME"

cat > "$APP_BUNDLE/Contents/Info.plist" <<PLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>CFBundleExecutable</key>
    <string>$APP_NAME</string>
    <key>CFBundleIdentifier</key>
    <string>$BUNDLE_ID</string>
    <key>CFBundleName</key>
    <string>Mac Optimizer</string>
    <key>CFBundleDisplayName</key>
    <string>Mac Optimizer</string>
    <key>CFBundlePackageType</key>
    <string>APPL</string>
    <key>CFBundleShortVersionString</key>
    <string>$VERSION</string>
    <key>CFBundleVersion</key>
    <string>1</string>
    <key>LSMinimumSystemVersion</key>
    <string>13.0</string>
    <key>NSHighResolutionCapable</key>
    <true/>
    <key>NSPrincipalClass</key>
    <string>NSApplication</string>
    <key>NSHumanReadableCopyright</key>
    <string>Copyright © 2026. All rights reserved.</string>
    <key>NSSupportsAutomaticTermination</key>
    <false/>
</dict>
</plist>
PLIST

echo "✓ Bundle assembled at $APP_BUNDLE"

# ── Sign with Developer ID ────────────────────────────────────────
step "Signing with Developer ID..."
codesign \
    --force \
    --deep \
    --options runtime \
    --entitlements "$ENTITLEMENTS" \
    --sign "$CERT" \
    --timestamp \
    "$APP_BUNDLE"

codesign --verify --deep --strict "$APP_BUNDLE" && echo "✓ Signature verified"

# ── Notarize ──────────────────────────────────────────────────────
step "Zipping for notarization..."
rm -f "$ZIP_PATH"
ditto -c -k --keepParent "$APP_BUNDLE" "$ZIP_PATH"
echo "✓ $ZIP_PATH"

step "Submitting to Apple notarization service (this takes 1-3 minutes)..."
NOTARY_OUTPUT=$(xcrun notarytool submit "$ZIP_PATH" \
    --apple-id "$APPLE_ID" \
    --team-id "$TEAM_ID" \
    --password "$APP_PASSWORD" \
    --wait 2>&1)

echo "$NOTARY_OUTPUT"

if ! echo "$NOTARY_OUTPUT" | grep -q "status: Accepted"; then
    SUBMISSION_ID=$(echo "$NOTARY_OUTPUT" | grep "id:" | head -1 | awk '{print $2}')
    echo "✗ Notarization failed."
    [[ -n "$SUBMISSION_ID" ]] && echo "  Fetch log: xcrun notarytool log $SUBMISSION_ID --apple-id \"$APPLE_ID\" --team-id \"$TEAM_ID\" --password \"$APP_PASSWORD\""
    exit 1
fi
echo "✓ Notarization accepted"

step "Stapling notarization ticket..."
xcrun stapler staple "$APP_BUNDLE"
echo "✓ Stapled"

# ── Create .dmg ───────────────────────────────────────────────────
step "Creating .dmg..."
rm -f "$DMG_PATH"

# Temp staging folder for a clean DMG layout
TMP_DMG_DIR="$BUILD_DIR/dmg_staging"
rm -rf "$TMP_DMG_DIR"
mkdir -p "$TMP_DMG_DIR"
cp -R "$APP_BUNDLE" "$TMP_DMG_DIR/"
ln -s /Applications "$TMP_DMG_DIR/Applications"   # drag-to-install shortcut

hdiutil create \
    -volname "Mac Optimizer" \
    -srcfolder "$TMP_DMG_DIR" \
    -ov \
    -format UDZO \
    -imagekey zlib-level=9 \
    "$DMG_PATH"

rm -rf "$TMP_DMG_DIR"

# Sign the DMG too
codesign --force --sign "$CERT" --timestamp "$DMG_PATH"
echo "✓ Signed DMG: $DMG_PATH"

# ── Done ──────────────────────────────────────────────────────────
echo
echo "════════════════════════════════════════════════════════"
echo "  ✓ Distribution build complete"
echo "  📦 $DMG_PATH"
echo "════════════════════════════════════════════════════════"
echo
echo "Next steps to distribute:"
echo "  1. Test the DMG: open \"$DMG_PATH\""
echo "  2. Verify notarization: spctl -a -t open --context context:primary-signature -v \"$APP_BUNDLE\""
echo "  3. Upload the .dmg to your website, GitHub Releases, or Gumroad"
echo
