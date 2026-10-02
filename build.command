#!/bin/zsh

set -e

APP_NAME="Podly"
ROOT="$(cd "$(dirname "$0")" && pwd)"
BUILD="$ROOT/build"
APP="$BUILD/$APP_NAME.app"

echo "🔨 Building $APP_NAME..."

rm -rf "$BUILD"

mkdir -p \
    "$APP/Contents/MacOS" \
    "$APP/Contents/Resources"

echo "⚙️ Compiling Swift..."

swiftc "$ROOT/podly.swift" \
    -o "$APP/Contents/MacOS/Podly" \
    -framework SwiftUI \
    -framework AppKit \
    -parse-as-library \
    -target "$(uname -m)-apple-macos13.0"

# Copy app icon
if [[ -f "$ROOT/Podly.icns" ]]; then
    echo "🎨 Installing app icon..."
    cp "$ROOT/Podly.icns" \
       "$APP/Contents/Resources/Podly.icns"
else
    echo "⚠️ Warning: Podly.icns not found"
fi

cat > "$APP/Contents/Info.plist" <<PLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN"
"http://www.apple.com/DTDs/PropertyList-1.0.dtd">

<plist version="1.0">
<dict>

    <key>CFBundleDisplayName</key>
    <string>Podly</string>

    <key>CFBundleExecutable</key>
    <string>Podly</string>

    <key>CFBundleIdentifier</key>
    <string>com.local.podly</string>

    <key>CFBundleName</key>
    <string>Podly</string>

    <key>CFBundlePackageType</key>
    <string>APPL</string>

    <key>CFBundleVersion</key>
    <string>1.0</string>

    <key>CFBundleShortVersionString</key>
    <string>1.0</string>

    <key>CFBundleIconFile</key>
    <string>Podly.icns</string>

    <key>LSMinimumSystemVersion</key>
    <string>13.0</string>

    <key>NSHighResolutionCapable</key>
    <true/>

</dict>
</plist>
PLIST

chmod +x "$APP/Contents/MacOS/Podly"

# Refresh Launch Services icon cache
touch "$APP"

echo
echo "✅ Build successful!"
echo "📦 $APP"
echo

open "$APP"
