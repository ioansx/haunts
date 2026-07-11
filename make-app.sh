#!/bin/sh
# Build ismux.app so macOS attributes the Automation permission to ismux
# itself rather than the terminal it was launched from.
set -e
cd "$(dirname "$0")"

swift build -c release

APP=ismux.app
rm -rf "$APP"
mkdir -p "$APP/Contents/MacOS"
cp .build/release/ismux "$APP/Contents/MacOS/ismux"

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

codesign --force --sign - "$APP"
echo "Built $APP — launch with: open $APP"
