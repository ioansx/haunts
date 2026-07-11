#!/bin/sh
# Build Haunts and install it to /Applications, replacing any running copy.
set -e
cd "$(dirname "$0")"

./make-app.sh

pkill -f 'Haunts.app/Contents/MacOS/haunts' 2>/dev/null || true
rm -rf /Applications/Haunts.app
cp -R Haunts.app /Applications/Haunts.app
open /Applications/Haunts.app

echo "Installed /Applications/Haunts.app and launched it."
