#!/bin/bash
#
# Build SeleneChat Release App Bundle
#
# This script builds SeleneChat in release mode and creates a proper macOS app bundle.
#

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(dirname "$SCRIPT_DIR")"
SELENECHAT_DIR="$PROJECT_DIR/SeleneChat"
BUILD_DIR="$PROJECT_DIR/build"
APP_NAME="SeleneChat"
APP_BUNDLE="$BUILD_DIR/$APP_NAME.app"

# Colors
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

echo "========================================"
echo "  SeleneChat Release Build"
echo "========================================"
echo ""

# Clean previous build
if [ -d "$BUILD_DIR" ]; then
    echo -e "${YELLOW}Cleaning previous build...${NC}"
    rm -rf "$BUILD_DIR"
fi

mkdir -p "$BUILD_DIR"

# Build in release mode
echo "Building in release mode..."
cd "$SELENECHAT_DIR"
swift build -c release

# Get the built executable path
EXECUTABLE_PATH="$SELENECHAT_DIR/.build/release/SeleneChat"

if [ ! -f "$EXECUTABLE_PATH" ]; then
    echo "ERROR: Executable not found at $EXECUTABLE_PATH"
    exit 1
fi

echo -e "${GREEN}Build successful${NC}"
echo ""

# Create app bundle structure
echo "Creating app bundle..."
mkdir -p "$APP_BUNDLE/Contents/MacOS"
mkdir -p "$APP_BUNDLE/Contents/Resources"

# Copy executable
cp "$EXECUTABLE_PATH" "$APP_BUNDLE/Contents/MacOS/$APP_NAME"

# Create Info.plist
cat > "$APP_BUNDLE/Contents/Info.plist" << 'EOF'
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>CFBundleDevelopmentRegion</key>
    <string>en</string>
    <key>CFBundleExecutable</key>
    <string>SeleneChat</string>
    <key>CFBundleIdentifier</key>
    <string>com.selene.chat</string>
    <key>CFBundleInfoDictionaryVersion</key>
    <string>6.0</string>
    <key>CFBundleName</key>
    <string>SeleneChat</string>
    <key>CFBundlePackageType</key>
    <string>APPL</string>
    <key>CFBundleShortVersionString</key>
    <string>1.0.0</string>
    <key>CFBundleVersion</key>
    <string>1</string>
    <key>LSMinimumSystemVersion</key>
    <string>14.0</string>
    <key>NSHighResolutionCapable</key>
    <true/>
    <key>NSPrincipalClass</key>
    <string>NSApplication</string>
    <key>LSApplicationCategoryType</key>
    <string>public.app-category.productivity</string>
    <key>NSAppTransportSecurity</key>
    <dict>
        <key>NSAllowsLocalNetworking</key>
        <true/>
        <key>NSAllowsArbitraryLoads</key>
        <true/>
    </dict>
</dict>
</plist>
EOF

# Create PkgInfo
echo -n "APPL????" > "$APP_BUNDLE/Contents/PkgInfo"

echo -e "${GREEN}App bundle created at:${NC}"
echo "  $APP_BUNDLE"
echo ""

# Show bundle info
echo "Bundle contents:"
ls -la "$APP_BUNDLE/Contents/"
ls -la "$APP_BUNDLE/Contents/MacOS/"
echo ""

# Get file size
SIZE=$(du -sh "$APP_BUNDLE" | cut -f1)
echo "Bundle size: $SIZE"
echo ""

echo "========================================"
echo -e "  ${GREEN}Build complete!${NC}"
echo "========================================"
echo ""
echo "To install:"
echo "  cp -r $APP_BUNDLE /Applications/"
echo ""
echo "To run:"
echo "  open $APP_BUNDLE"
echo ""
