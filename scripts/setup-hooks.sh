#!/bin/bash
# Setup git hooks for Selene project
# Run this once after cloning the repo

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"

echo "Setting up git hooks..."

# Create symlink for pre-commit hook
if [ -f "$PROJECT_ROOT/.git/hooks/pre-commit" ]; then
    echo "Backing up existing pre-commit hook..."
    mv "$PROJECT_ROOT/.git/hooks/pre-commit" "$PROJECT_ROOT/.git/hooks/pre-commit.backup"
fi

ln -sf "../../scripts/hooks/pre-commit" "$PROJECT_ROOT/.git/hooks/pre-commit"

echo "✓ Pre-commit hook installed"
echo ""
echo "Hooks are now active. They will run on every commit to:"
echo "  - Warn about documentation in wrong locations"
echo "  - Block recreation of consolidated files"
echo "  - Remind to update docs/plans/INDEX.md for new design docs"
