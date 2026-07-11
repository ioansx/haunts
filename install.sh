#!/bin/sh
# Build ismux and install it to /Applications, replacing any running copy.
set -e
cd "$(dirname "$0")"

./make-app.sh

pkill -f 'ismux.app/Contents/MacOS/ismux' 2>/dev/null || true
rm -rf /Applications/ismux.app
cp -R ismux.app /Applications/ismux.app
open /Applications/ismux.app

echo "Installed /Applications/ismux.app and launched it."
echo "Note: first run from the new location re-prompts the Ghostty automation"
echo "permission, and Launch at Login should be re-toggled from the menu bar."
