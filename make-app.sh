#!/bin/sh
# Build Haunts.app. Signs with the "haunts-dev" Keychain certificate when it
# exists (stable identity → macOS Automation permission survives rebuilds),
# otherwise falls back to ad-hoc signing.
set -e
cd "$(dirname "$0")"

swift build -c release

APP=Haunts.app
rm -rf "$APP"
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources"
cp .build/release/haunts "$APP/Contents/MacOS/haunts"
cp assets/haunts.icns "$APP/Contents/Resources/haunts.icns"

cat > "$APP/Contents/Info.plist" <<'EOF'
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>CFBundleIdentifier</key>
    <string>dev.ioan.haunts</string>
    <key>CFBundleName</key>
    <string>Haunts</string>
    <key>CFBundleExecutable</key>
    <string>haunts</string>
    <key>CFBundleIconFile</key>
    <string>haunts</string>
    <key>CFBundlePackageType</key>
    <string>APPL</string>
    <key>CFBundleShortVersionString</key>
    <string>0.1.0</string>
    <key>LSMinimumSystemVersion</key>
    <string>13.0</string>
    <key>LSUIElement</key>
    <true/>
    <key>NSAppleEventsUsageDescription</key>
    <string>Haunts controls Ghostty windows to switch workspaces.</string>
</dict>
</plist>
EOF

if security find-identity -v -p codesigning 2>/dev/null | grep -q '"haunts-dev"'; then
    codesign --force --sign haunts-dev "$APP"
    echo "Signed with haunts-dev certificate."
else
    codesign --force --sign - "$APP"
    echo "Ad-hoc signed (create a 'haunts-dev' certificate in Keychain Access for a stable identity)."
fi
echo "Built $APP — launch with: open $APP"
