#!/bin/bash
# Builds CuteTimer.app into ~/Applications and installs the `cutetimer` command.
set -euo pipefail
cd "$(dirname "$0")"
APP="$HOME/Applications/CuteTimer.app"
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources"
swiftc -O -swift-version 5 -parse-as-library -target arm64-apple-macosx13.0 \
  CuteTimer.swift -o "$APP/Contents/MacOS/CuteTimer"
cat > "$APP/Contents/Info.plist" <<'PLIST'
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0"><dict>
  <key>CFBundleName</key><string>CuteTimer</string>
  <key>CFBundleIdentifier</key><string>com.hermes.cutetimer</string>
  <key>CFBundleExecutable</key><string>CuteTimer</string>
  <key>CFBundlePackageType</key><string>APPL</string>
  <key>CFBundleShortVersionString</key><string>1.0</string>
  <key>LSMinimumSystemVersion</key><string>13.0</string>
  <key>LSUIElement</key><true/>
  <key>NSHighResolutionCapable</key><true/>
</dict></plist>
PLIST
codesign --force --sign - "$APP" >/dev/null 2>&1 || true
echo "Built $APP"
