#!/bin/sh
# Build ismux.app. Signs with the "ismux-dev" Keychain certificate when it
# exists (stable identity → macOS Automation permission survives rebuilds),
# otherwise falls back to ad-hoc signing.
set -e
cd "$(dirname "$0")"

swift build -c release

APP=ismux.app
rm -rf "$APP"
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources"
cp .build/release/ismux "$APP/Contents/MacOS/ismux"
cp assets/ismux.icns "$APP/Contents/Resources/ismux.icns"

cat > "$APP/Contents/Info.plist" <<'EOF'
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>CFBundleIdentifier</key>
    <string>dev.ioan.ismux</string>
    <key>CFBundleName</key>
    <string>ismux</string>
    <key>CFBundleExecutable</key>
    <string>ismux</string>
    <key>CFBundleIconFile</key>
    <string>ismux</string>
    <key>CFBundlePackageType</key>
    <string>APPL</string>
    <key>CFBundleShortVersionString</key>
    <string>0.1.0</string>
    <key>LSMinimumSystemVersion</key>
    <string>13.0</string>
    <key>LSUIElement</key>
    <true/>
    <key>NSAppleEventsUsageDescription</key>
    <string>ismux controls Ghostty windows to switch workspaces.</string>
</dict>
</plist>
EOF

if security find-identity -v -p codesigning 2>/dev/null | grep -q '"ismux-dev"'; then
    codesign --force --sign ismux-dev "$APP"
    echo "Signed with ismux-dev certificate."
else
    codesign --force --sign - "$APP"
    echo "Ad-hoc signed (create an 'ismux-dev' certificate in Keychain Access for a stable identity)."
fi
echo "Built $APP — launch with: open $APP"
