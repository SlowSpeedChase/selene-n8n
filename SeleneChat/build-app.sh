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

# Generate a simple app icon using SF Symbols-inspired design
echo "🎨 Creating app icon..."
ICON_DIR="$APP_DIR/Contents/Resources/AppIcon.appiconset"
mkdir -p "$ICON_DIR"

# Check if ImageMagick is available to create icons
if command -v convert &> /dev/null; then
    # Create simple gradient icons at different sizes
    for size in 16 32 128 256 512; do
        convert -size ${size}x${size} \
            xc:"#5E5CE6" \
            -gravity center \
            -pointsize $((size/2)) \
            -fill white \
            -annotate +0+0 "S" \
            "$ICON_DIR/icon_${size}x${size}.png"

        # Create @2x versions
        size2x=$((size*2))
        convert -size ${size2x}x${size2x} \
            xc:"#5E5CE6" \
            -gravity center \
            -pointsize $((size2x/2)) \
            -fill white \
            -annotate +0+0 "S" \
            "$ICON_DIR/icon_${size}x${size}@2x.png"
    done

    cp "Sources/Resources/Assets.xcassets/AppIcon.appiconset/Contents.json" "$ICON_DIR/"

    # Create the .icns file from the 512x512 icon
    mkdir -p "$APP_DIR/Contents/Resources/AppIcon.iconset"
    for size in 16 32 128 256 512; do
        cp "$ICON_DIR/icon_${size}x${size}.png" "$APP_DIR/Contents/Resources/AppIcon.iconset/icon_${size}x${size}.png"
        cp "$ICON_DIR/icon_${size}x${size}@2x.png" "$APP_DIR/Contents/Resources/AppIcon.iconset/icon_${size}x${size}@2x.png"
    done

    iconutil -c icns "$APP_DIR/Contents/Resources/AppIcon.iconset"
    rm -rf "$APP_DIR/Contents/Resources/AppIcon.iconset"

    echo "✅ App icon created"
else
    echo "⚠️  ImageMagick not found - skipping icon generation"
    echo "   Install with: brew install imagemagick"
fi

# Make executable
chmod +x "$APP_DIR/Contents/MacOS/SeleneChat"

echo "✅ SeleneChat.app built successfully!"
echo "📍 Location: $APP_DIR"
echo ""
echo "To run: open $APP_DIR"
echo "To install: cp -R $APP_DIR /Applications/"
