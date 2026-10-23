#!/bin/bash
DIR="$(cd "$(dirname "$0")" && pwd)"
"$DIR/uninstall.sh"
echo ""
read -p "Drücke [Enter] zum Schließen dieses Fensters..."
