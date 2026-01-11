#!/bin/bash
#
# SeleneChat Client Update Script
#
# This script checks for and installs updates from the Selene server.
# It's designed to be run manually or via launchd on the client (laptop).
#
# Configuration:
#   Set SERVER_ADDRESS to your Mac mini's IP address
#
# Usage:
#   ./update-selenechat.sh              # Check and update if needed
#   ./update-selenechat.sh --check      # Only check, don't update
#   ./update-selenechat.sh --force      # Force reinstall
#

set -e

# Configuration
SERVER_ADDRESS="${SELENE_SERVER_ADDRESS:-192.168.1.100}"  # Set this to your Mac mini's IP
SERVER_PORT="${SELENE_SERVER_PORT:-5678}"
APP_NAME="SeleneChat"
APP_PATH="/Applications/$APP_NAME.app"
TEMP_DIR="/tmp/selenechat-update"

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

log_info() {
    echo -e "${GREEN}[INFO]${NC} $1"
}

log_warn() {
    echo -e "${YELLOW}[WARN]${NC} $1"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

log_step() {
    echo -e "${BLUE}[STEP]${NC} $1"
}

# Parse arguments
CHECK_ONLY=false
FORCE_UPDATE=false

while [[ $# -gt 0 ]]; do
    case $1 in
        --check)
            CHECK_ONLY=true
            shift
            ;;
        --force)
            FORCE_UPDATE=true
            shift
            ;;
        *)
            echo "Unknown option: $1"
            echo "Usage: $0 [--check|--force]"
            exit 1
            ;;
    esac
done

# Get currently installed version
get_installed_version() {
    if [ -f "$APP_PATH/Contents/Info.plist" ]; then
        /usr/libexec/PlistBuddy -c "Print :CFBundleShortVersionString" "$APP_PATH/Contents/Info.plist" 2>/dev/null || echo "0.0.0"
    else
        echo "not_installed"
    fi
}

# Get server version
get_server_version() {
    local response
    response=$(curl -s --connect-timeout 5 "http://${SERVER_ADDRESS}:${SERVER_PORT}/api/app/version" 2>/dev/null)

    if [ $? -ne 0 ] || [ -z "$response" ]; then
        echo "unreachable"
        return
    fi

    # Parse JSON response (simple grep for version)
    echo "$response" | grep -o '"version":"[^"]*"' | cut -d'"' -f4
}

# Get server build date
get_server_build_date() {
    local response
    response=$(curl -s --connect-timeout 5 "http://${SERVER_ADDRESS}:${SERVER_PORT}/api/app/version" 2>/dev/null)

    if [ $? -ne 0 ] || [ -z "$response" ]; then
        echo "unknown"
        return
    fi

    echo "$response" | grep -o '"buildDate":"[^"]*"' | cut -d'"' -f4
}

# Compare versions (returns 0 if v1 > v2)
version_gt() {
    local v1=$1
    local v2=$2

    # Handle special cases
    if [ "$v1" = "not_installed" ]; then
        return 0  # Not installed, need to install
    fi
    if [ "$v2" = "unreachable" ]; then
        return 1  # Can't compare
    fi

    # Simple string comparison for now (works for semver like 1.0.0, 1.0.1, etc.)
    [ "$v1" != "$v2" ] && [ "$(printf '%s\n%s' "$v1" "$v2" | sort -V | tail -n1)" = "$v2" ]
}

# Download and install update
install_update() {
    log_step "Creating temp directory..."
    rm -rf "$TEMP_DIR"
    mkdir -p "$TEMP_DIR"

    log_step "Downloading update from server..."
    curl -# -o "$TEMP_DIR/SeleneChat.zip" "http://${SERVER_ADDRESS}:${SERVER_PORT}/api/app/download"

    if [ ! -f "$TEMP_DIR/SeleneChat.zip" ]; then
        log_error "Download failed"
        return 1
    fi

    log_step "Extracting app bundle..."
    cd "$TEMP_DIR"
    unzip -q SeleneChat.zip

    if [ ! -d "$TEMP_DIR/$APP_NAME.app" ]; then
        log_error "Extraction failed - app bundle not found"
        return 1
    fi

    log_step "Closing running app (if any)..."
    osascript -e "quit app \"$APP_NAME\"" 2>/dev/null || true
    sleep 1

    log_step "Installing to /Applications..."
    rm -rf "$APP_PATH"
    mv "$TEMP_DIR/$APP_NAME.app" /Applications/

    log_step "Setting permissions..."
    chmod -R 755 "$APP_PATH"

    # Remove quarantine attribute (since we trust our own server)
    xattr -dr com.apple.quarantine "$APP_PATH" 2>/dev/null || true

    log_step "Cleaning up..."
    rm -rf "$TEMP_DIR"

    log_info "Update installed successfully!"
    return 0
}

# Main
main() {
    echo "========================================"
    echo "  SeleneChat Update Checker"
    echo "========================================"
    echo ""
    echo "Server: ${SERVER_ADDRESS}:${SERVER_PORT}"
    echo ""

    # Get versions
    log_step "Checking installed version..."
    INSTALLED_VERSION=$(get_installed_version)
    echo "  Installed: $INSTALLED_VERSION"

    log_step "Checking server version..."
    SERVER_VERSION=$(get_server_version)
    SERVER_BUILD_DATE=$(get_server_build_date)

    if [ "$SERVER_VERSION" = "unreachable" ]; then
        log_error "Cannot reach server at ${SERVER_ADDRESS}:${SERVER_PORT}"
        echo ""
        echo "Make sure:"
        echo "  1. Your Mac mini is running and connected"
        echo "  2. The Selene server is running (npm run start)"
        echo "  3. You're on the same network"
        echo "  4. The server address is correct"
        exit 1
    fi

    echo "  Server: $SERVER_VERSION (built: $SERVER_BUILD_DATE)"
    echo ""

    # Determine if update needed
    NEED_UPDATE=false

    if [ "$FORCE_UPDATE" = true ]; then
        log_info "Forcing update..."
        NEED_UPDATE=true
    elif [ "$INSTALLED_VERSION" = "not_installed" ]; then
        log_info "App not installed, will install..."
        NEED_UPDATE=true
    elif version_gt "$INSTALLED_VERSION" "$SERVER_VERSION"; then
        log_info "Update available: $INSTALLED_VERSION -> $SERVER_VERSION"
        NEED_UPDATE=true
    else
        log_info "Already up to date!"
    fi

    if [ "$CHECK_ONLY" = true ]; then
        if [ "$NEED_UPDATE" = true ]; then
            echo ""
            echo "Update available. Run without --check to install."
        fi
        exit 0
    fi

    if [ "$NEED_UPDATE" = true ]; then
        echo ""
        install_update

        echo ""
        echo "========================================"
        echo -e "  ${GREEN}Update complete!${NC}"
        echo "========================================"
        echo ""
        echo "To launch: open /Applications/$APP_NAME.app"
    fi
}

main
