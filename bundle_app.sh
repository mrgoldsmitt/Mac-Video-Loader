#!/bin/bash
set -e

DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$DIR"

echo "==> Baue Mac Video Loader (Release)..."
swift build -c release

APP_NAME="Mac Video Loader.app"
CONTENTS_DIR="$APP_NAME/Contents"
MACOS_DIR="$CONTENTS_DIR/MacOS"
RESOURCES_DIR="$CONTENTS_DIR/Resources"

echo "==> Erstelle macOS App-Bundle ($APP_NAME)..."
rm -rf "$APP_NAME"
mkdir -p "$MACOS_DIR"
mkdir -p "$RESOURCES_DIR"

cp ".build/release/MacVideoLoader" "$MACOS_DIR/MacVideoLoader"
chmod +x "$MACOS_DIR/MacVideoLoader"

echo "==> Erstelle Retina App-Icons..."
python3 create_icon.py

cat << 'EOF' > "$CONTENTS_DIR/Info.plist"
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>CFBundleDevelopmentRegion</key>
    <string>de</string>
    <key>CFBundleExecutable</key>
    <string>MacVideoLoader</string>
    <key>CFBundleIdentifier</key>
    <string>com.macvideoloader</string>
    <key>CFBundleInfoDictionaryVersion</key>
    <string>6.0</string>
    <key>CFBundleName</key>
    <string>Mac Video Loader</string>
    <key>CFBundleDisplayName</key>
    <string>Mac Video Loader</string>
    <key>CFBundleIconFile</key>
    <string>AppIcon</string>
    <key>CFBundlePackageType</key>
    <string>APPL</string>
    <key>CFBundleShortVersionString</key>
    <string>0.6.0</string>
    <key>CFBundleVersion</key>
    <string>8</string>
    <key>CFBundleDocumentTypes</key>
    <array>
        <dict>
            <key>CFBundleTypeName</key>
            <string>Mac Video Loader Download-Liste</string>
            <key>CFBundleTypeExtensions</key>
            <array>
                <string>mvl</string>
            </array>
            <key>CFBundleTypeRole</key>
            <string>Editor</string>
            <key>LSHandlerRank</key>
            <string>Owner</string>
        </dict>
    </array>
    <key>LSMinimumSystemVersion</key>
    <string>13.0</string>
    <key>NSHighResolutionCapable</key>
    <true/>
    <key>NSPrincipalClass</key>
    <string>NSApplication</string>
    <key>NSRequiresAquaSystemAppearance</key>
    <false/>
</dict>
</plist>
EOF

echo "==> Signiere App (Ad-hoc Signierung für lokalen Mac)..."
codesign --force --deep --sign - "$APP_NAME"

echo "==> Fertig! Die App befindet sich unter: $DIR/$APP_NAME"
