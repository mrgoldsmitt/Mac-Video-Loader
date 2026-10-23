#!/bin/bash
set -e

echo "==> Deinstalliere Mac Video Loader..."

# Beende laufende Prozesse
pkill -f "Mac Video Loader.app/Contents/MacOS/MacVideoLoader" 2>/dev/null || true
pkill -f "YTDownloader.app/Contents/MacOS/YTDownloader" 2>/dev/null || true

# Entferne App-Bundles aus /Applications
if [ -d "/Applications/Mac Video Loader.app" ]; then
    rm -rf "/Applications/Mac Video Loader.app"
    echo "  -> /Applications/Mac Video Loader.app gelöscht."
fi

if [ -d "/Applications/YTDownloader.app" ]; then
    rm -rf "/Applications/YTDownloader.app"
    echo "  -> /Applications/YTDownloader.app gelöscht."
fi

# Optional: Einstellungen zurücksetzen
defaults delete com.macvideoloader 2>/dev/null || true

# LaunchServices aktualisieren
/System/Library/Frameworks/CoreServices.framework/Frameworks/LaunchServices.framework/Support/lsregister -u "/Applications/Mac Video Loader.app" 2>/dev/null || true

echo "==> Deinstallation erfolgreich abgeschlossen!"
