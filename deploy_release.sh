#!/bin/bash
set -e

DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$DIR"

# 1. Version ermitteln (entweder als Argument übergeben oder aus bundle_app.sh auslesen)
if [ -n "$1" ]; then
    VERSION="$1"
else
    VERSION=$(grep -A 1 "CFBundleShortVersionString" bundle_app.sh | grep "<string>" | sed -E 's/.*<string>(.*)<\/string>.*/\1/')
fi

if [ -z "$VERSION" ]; then
    echo "Fehler: Konnte Versionsnummer nicht ermitteln."
    exit 1
fi

TAG="v$VERSION"
DMG_FILE="Mac-Video-Loader.dmg"

echo "=========================================================="
echo "  Deploy Pipeline: Mac Video Loader $TAG"
echo "=========================================================="

# 2. Prüfen, ob gh installiert und angemeldet ist
export PATH="/opt/homebrew/bin:$PATH"
if ! command -v gh &> /dev/null; then
    echo "Fehler: GitHub CLI ('gh') ist nicht installiert."
    exit 1
fi

if ! gh auth status &> /dev/null; then
    echo "Fehler: GitHub CLI ist nicht angemeldet. Bitte führe 'gh auth login' aus."
    exit 1
fi

# 3. Frisches App-Bundle und DMG erstellen
echo "==> [1/4] Erstelle App-Bundle und Disk-Image (DMG)..."
./bundle_app.sh
./create_dmg.sh

if [ ! -f "$DMG_FILE" ]; then
    echo "Fehler: $DMG_FILE wurde nicht gefunden!"
    exit 1
fi

# 4. Git-Status prüfen und uncommitted changes committen
echo "==> [2/4] Prüfe Git-Status..."
if [ -n "$(git status --porcelain)" ]; then
    echo "==> Committe offene Änderungen für Release $TAG..."
    git add .
    git commit -m "Release $TAG"
fi

# 5. Git-Tag erstellen und pushen
echo "==> [3/4] Erstelle und synchronisiere Git-Tag $TAG..."
if git rev-parse "$TAG" >/dev/null 2>&1; then
    echo "Tag $TAG existiert lokal bereits."
else
    git tag -a "$TAG" -m "Mac Video Loader $TAG"
    echo "Tag $TAG lokal erstellt."
fi

# Push Branch und Tags
echo "==> Pushe Änderungen und Tags zu GitHub..."
git push origin HEAD --tags

# 6. GitHub Release erstellen oder aktualisieren
echo "==> [4/4] Veröffentliche Release auf GitHub..."
if gh release view "$TAG" >/dev/null 2>&1; then
    echo "GitHub Release $TAG existiert bereits. Aktualisiere $DMG_FILE..."
    gh release upload "$TAG" "$DMG_FILE" --clobber
else
    echo "Erstelle neues GitHub Release $TAG..."
    gh release create "$TAG" "$DMG_FILE" \
        --title "Mac Video Loader $TAG" \
        --generate-notes
fi

echo "=========================================================="
echo "  Release $TAG erfolgreich auf GitHub veröffentlicht!"
echo "  URL: $(gh release view "$TAG" --json url -q .url)"
echo "=========================================================="
