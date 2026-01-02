#!/bin/bash
# Setup script: Install git hooks for selene-n8n

set -e
set -u

REPO_ROOT="$(git rev-parse --show-toplevel)"
HOOKS_SOURCE="$REPO_ROOT/scripts/hooks"
HOOKS_TARGET="$(git rev-parse --git-common-dir)/hooks"

echo "Installing git hooks..."

# Install post-merge hook
if [ -f "$HOOKS_SOURCE/post-merge" ]; then
    if [ -L "$HOOKS_TARGET/post-merge" ] || [ -f "$HOOKS_TARGET/post-merge" ]; then
        echo "  post-merge: already exists (skipping)"
    else
        ln -s "$HOOKS_SOURCE/post-merge" "$HOOKS_TARGET/post-merge"
        echo "  post-merge: installed ✓"
    fi
else
    echo "  post-merge: source not found (skipping)"
fi

echo ""
echo "Hook setup complete!"
echo "The post-merge hook will auto-build SeleneChat when its files change."
