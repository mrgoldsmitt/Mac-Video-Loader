#!/bin/bash
set -e

DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$DIR"

echo "==> [1/5] Stelle sicher, dass das aktuelle App-Bundle bereitsteht..."
if [ ! -d "Mac Video Loader.app" ]; then
    ./bundle_app.sh
fi

APP_NAME="Mac Video Loader"
APP_BUNDLE="Mac Video Loader.app"
DMG_NAME="Mac-Video-Loader.dmg"
VOL_NAME="Mac Video Loader Installer"
DMG_TEMP="temp_MacVideoLoader.dmg"
STAGING_DIR="dmg_staging"

# Aufräumen
rm -rf "$STAGING_DIR" "$DMG_TEMP" "$DMG_NAME"
mkdir -p "$STAGING_DIR"

echo "==> [2/5] Bereite Staging-Verzeichnis vor..."
cp -R "$APP_BUNDLE" "$STAGING_DIR/"
ln -s /Applications "$STAGING_DIR/Applications"

echo "==> [3/5] Erstelle temporäres beschreibbares Disk-Image..."
hdiutil create -srcfolder "$STAGING_DIR" -volname "$VOL_NAME" -fs HFS+ -fsargs "-c c=64,a=16,e=16" -format UDRW -size 75M "$DMG_TEMP"

echo "==> [4/5] Formatiere Finder-Ansicht (Drag-to-Applications Layout)..."
MOUNT_DIR="/Volumes/$VOL_NAME"

# Falls bereits gemountet, aushängen
if [ -d "$MOUNT_DIR" ]; then
    hdiutil detach "$MOUNT_DIR" -force 2>/dev/null || true
fi

DEVICE=$(hdiutil attach -readwrite -noverify -noautoopen "$DMG_TEMP" | grep -E '^/dev/' | head -n 1 | awk '{print $1}')
sleep 1

# AppleScript zur optischen Gestaltung des DMG-Fensters
osascript << EOF || true
tell application "Finder"
    tell disk "$VOL_NAME"
        open
        set current view of container window to icon view
        set toolbar visible of container window to false
        set statusbar visible of container window to false
        set the bounds of container window to {300, 200, 860, 560}
        
        set theViewOptions to the icon view options of container window
        set icon size of theViewOptions to 104
        set arrangement of theViewOptions to not arranged
        
        -- Positioniere App links und Applications-Ordner rechts
        set position of item "$APP_BUNDLE" of container window to {130, 170}
        set position of item "Applications" of container window to {410, 170}
        
        close
        open
        update without registering applications
        delay 1
    end tell
end tell
EOF

sync
sleep 1
hdiutil detach "$DEVICE" -force 2>/dev/null || true

echo "==> [5/5] Komprimiere zu finalem Read-Only DMG ($DMG_NAME)..."
hdiutil convert "$DMG_TEMP" -format UDZO -imagekey zlib-level=9 -o "$DMG_NAME"

# Bereinigung
rm -rf "$STAGING_DIR" "$DMG_TEMP"

echo "==> Fertig! Das Disk-Image befindet sich unter:"
echo "    $DIR/$DMG_NAME"
