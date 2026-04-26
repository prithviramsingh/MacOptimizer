#!/bin/bash
set -e

cd "$(dirname "$0")"

echo "Cleaning..."
swift package clean 2>&1

echo "Building..."
swift build 2>&1

BINARY=".build/debug/MacOptimizer"
APP_DIR=".build/MacOptimizer.app/Contents/MacOS"
APP_BUNDLE=".build/MacOptimizer.app"

mkdir -p "$APP_DIR"

cp "$BINARY" "$APP_DIR/MacOptimizer"

cat > "$APP_BUNDLE/Contents/Info.plist" <<EOF
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>CFBundleExecutable</key>
    <string>MacOptimizer</string>
    <key>CFBundleIdentifier</key>
    <string>com.macoptimizer.app</string>
    <key>CFBundleName</key>
    <string>Mac Optimizer</string>
    <key>CFBundlePackageType</key>
    <string>APPL</string>
    <key>CFBundleShortVersionString</key>
    <string>1.0</string>
    <key>CFBundleVersion</key>
    <string>1</string>
    <key>LSMinimumSystemVersion</key>
    <string>13.0</string>
    <key>NSHighResolutionCapable</key>
    <true/>
    <key>NSPrincipalClass</key>
    <string>NSApplication</string>
    <key>NSSupportsAutomaticTermination</key>
    <false/>
</dict>
</plist>
EOF

codesign --force --sign - "$APP_BUNDLE"

echo "Launching Mac Optimizer..."
open "$APP_BUNDLE"
