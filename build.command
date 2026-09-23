#!/bin/zsh
set -e

APP_NAME="SpotDL Downloader"
ROOT="$(cd "$(dirname "$0")" && pwd)"
BUILD="$ROOT/build"
APP="$BUILD/$APP_NAME.app"

echo "🔨 Building $APP_NAME..."

rm -rf "$BUILD"
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources"

swiftc "$ROOT/SpotDLDownloader.swift" \
    -o "$APP/Contents/MacOS/SpotDLDownloader" \
    -framework SwiftUI \
    -framework AppKit \
    -parse-as-library \
    -target "$(uname -m)-apple-macos13.0"

cat > "$APP/Contents/Info.plist" <<PLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>CFBundleDisplayName</key>
    <string>SpotDL Downloader</string>
    <key>CFBundleExecutable</key>
    <string>SpotDLDownloader</string>
    <key>CFBundleIdentifier</key>
    <string>com.local.spotdldownloader</string>
    <key>CFBundleName</key>
    <string>SpotDL Downloader</string>
    <key>CFBundlePackageType</key>
    <string>APPL</string>
    <key>LSMinimumSystemVersion</key>
    <string>13.0</string>
    <key>NSHighResolutionCapable</key>
    <true/>
</dict>
</plist>
PLIST

chmod +x "$APP/Contents/MacOS/SpotDLDownloader"

echo
echo "✅ Built:"
echo "   $APP"
echo
echo "🚀 Opening app..."
open "$APP"
