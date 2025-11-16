#!/bin/bash

# Build script for SeleneChat.app
set -e

echo "🔨 Building SeleneChat..."

# Build in release mode
swift build -c release

# Create app bundle structure
APP_NAME="SeleneChat.app"
BUILD_DIR=".build/release"
APP_DIR="$BUILD_DIR/$APP_NAME"

echo "📦 Creating app bundle..."
rm -rf "$APP_DIR"
mkdir -p "$APP_DIR/Contents/MacOS"
mkdir -p "$APP_DIR/Contents/Resources"

# Copy executable
echo "📋 Copying executable..."
cp "$BUILD_DIR/SeleneChat" "$APP_DIR/Contents/MacOS/SeleneChat"

# Copy Info.plist
echo "📋 Copying Info.plist..."
cp "Info.plist" "$APP_DIR/Contents/Info.plist"

# Copy Assets (if they exist)
if [ -d "Sources/Resources/Assets.xcassets" ]; then
    echo "📋 Copying assets..."
    cp -R "Sources/Resources/Assets.xcassets" "$APP_DIR/Contents/Resources/"
fi

# Copy app icon from Assets.xcassets
echo "🎨 Creating app icon..."
ICON_SOURCE="Sources/Resources/Assets.xcassets/AppIcon.appiconset"

if [ -d "$ICON_SOURCE" ]; then
    # Create .iconset directory for iconutil
    ICONSET_DIR="$APP_DIR/Contents/Resources/AppIcon.iconset"
    mkdir -p "$ICONSET_DIR"

    # Copy all icon files to iconset directory
    cp "$ICON_SOURCE/icon_16x16.png" "$ICONSET_DIR/icon_16x16.png"
    cp "$ICON_SOURCE/icon_16x16@2x.png" "$ICONSET_DIR/icon_16x16@2x.png"
    cp "$ICON_SOURCE/icon_32x32.png" "$ICONSET_DIR/icon_32x32.png"
    cp "$ICON_SOURCE/icon_32x32@2x.png" "$ICONSET_DIR/icon_32x32@2x.png"
    cp "$ICON_SOURCE/icon_128x128.png" "$ICONSET_DIR/icon_128x128.png"
    cp "$ICON_SOURCE/icon_128x128@2x.png" "$ICONSET_DIR/icon_128x128@2x.png"
    cp "$ICON_SOURCE/icon_256x256.png" "$ICONSET_DIR/icon_256x256.png"
    cp "$ICON_SOURCE/icon_256x256@2x.png" "$ICONSET_DIR/icon_256x256@2x.png"
    cp "$ICON_SOURCE/icon_512x512.png" "$ICONSET_DIR/icon_512x512.png"
    cp "$ICON_SOURCE/icon_512x512@2x.png" "$ICONSET_DIR/icon_512x512@2x.png"

    # Create .icns file from iconset
    iconutil -c icns "$ICONSET_DIR" -o "$APP_DIR/Contents/Resources/AppIcon.icns"
    rm -rf "$ICONSET_DIR"

    echo "✅ App icon created from Assets.xcassets"
else
    echo "⚠️  App icon assets not found at $ICON_SOURCE"
fi

# Make executable
chmod +x "$APP_DIR/Contents/MacOS/SeleneChat"

echo "✅ SeleneChat.app built successfully!"
echo "📍 Location: $APP_DIR"
echo ""
echo "To run: open $APP_DIR"
echo "To install: cp -R $APP_DIR /Applications/"
