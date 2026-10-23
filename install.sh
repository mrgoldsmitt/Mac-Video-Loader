#!/bin/bash
set -e

DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$DIR"

echo "==> [1/3] Stelle sicher, dass die App gebaut ist..."
if [ ! -d "Mac Video Loader.app" ]; then
    ./bundle_app.sh
fi

TARGET_DIR="/Applications"
TARGET_APP="$TARGET_DIR/Mac Video Loader.app"

echo "==> [2/3] Installiere Mac Video Loader in $TARGET_DIR..."

# Beende laufende Instanz falls vorhanden
pkill -f "Mac Video Loader.app/Contents/MacOS/MacVideoLoader" 2>/dev/null || true
pkill -f "YTDownloader.app/Contents/MacOS/YTDownloader" 2>/dev/null || true

# Entferne vorherige Version falls vorhanden
if [ -d "$TARGET_APP" ]; then
    rm -rf "$TARGET_APP"
fi

# Kopiere neue Version
cp -R "Mac Video Loader.app" "$TARGET_DIR/"

# Entferne Quarantäne-Attribute (Gatekeeper) und signiere ad-hoc
xattr -cr "$TARGET_APP" 2>/dev/null || true
codesign --force --deep --sign - "$TARGET_APP" 2>/dev/null || true

# Aktualisiere LaunchServices-Datenbank (damit Spotlight & Launchpad die App sofort finden)
/System/Library/Frameworks/CoreServices.framework/Frameworks/LaunchServices.framework/Support/lsregister -f "$TARGET_APP" 2>/dev/null || true

echo "==> [3/3] Erfolgreich installiert!"
echo "--------------------------------------------------------"
echo "  Die App befindet sich nun im Programme-Ordner:"
echo "  /Applications/Mac Video Loader.app"
echo ""
echo "  Du kannst sie direkt über Spotlight (Cmd+Leertaste),"
echo "  das Launchpad oder mit folgendem Befehl starten:"
echo "  open \"/Applications/Mac Video Loader.app\""
echo "--------------------------------------------------------"
