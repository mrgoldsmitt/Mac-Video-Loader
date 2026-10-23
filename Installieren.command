#!/bin/bash
DIR="$(cd "$(dirname "$0")" && pwd)"
"$DIR/install.sh"
echo ""
read -p "Drücke [Enter] zum Schließen dieses Fensters..."
