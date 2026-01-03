#!/bin/bash
# Shared SeleneChat auto-build logic for git hooks
# Called by: post-merge, post-rewrite

set -e

# Arguments
OLD_REF="${1:-ORIG_HEAD}"
NEW_REF="${2:-HEAD}"

# Check if SeleneChat files changed
if ! git diff --name-only "$OLD_REF" "$NEW_REF" 2>/dev/null | grep -q "^SeleneChat/"; then
    exit 0
fi

echo "SeleneChat files changed - triggering auto-build..."

# Get repo root and set paths
REPO_ROOT="$(git rev-parse --show-toplevel)"
LOG_FILE="$HOME/.selenechat-build.log"
APP_SOURCE="$REPO_ROOT/SeleneChat/.build/release/SeleneChat.app"

# Resolve symlink - Swift PM uses a symlink for .build/release
if [ -L "$REPO_ROOT/SeleneChat/.build/release" ]; then
    APP_SOURCE="$(readlink "$REPO_ROOT/SeleneChat/.build/release")/SeleneChat.app"
fi
APP_DEST="/Applications/SeleneChat.app"

# Build SeleneChat
cd "$REPO_ROOT/SeleneChat"

if ./build-app.sh > "$LOG_FILE" 2>&1; then
    # Success: install to Applications
    rm -rf "$APP_DEST"
    cp -R "$APP_SOURCE" "$APP_DEST"
    osascript -e 'display notification "Build complete" with title "SeleneChat Updated ✓"'
    echo "SeleneChat installed to $APP_DEST"
else
    # Failure: keep old app, notify with error
    osascript -e 'display notification "Check ~/.selenechat-build.log" with title "SeleneChat Build Failed ✗"'
    echo "Build failed - see $LOG_FILE for details"
    exit 1
fi
