# SeleneChat Auto-Builder Design

**Created:** 2026-01-02
**Status:** Approved
**Phase:** Infrastructure

---

## Problem

Building and installing SeleneChat requires manual steps:
1. Navigate to SeleneChat directory
2. Run `./build-app.sh`
3. Copy to Applications folder
4. Open the app

This friction means running stale builds or avoiding updates.

---

## Solution

A git post-merge hook that automatically builds and installs SeleneChat to `/Applications` whenever SeleneChat files change, with macOS notifications for feedback.

---

## Trigger Flow

```
git merge (closure ritual)
    │
    ▼
post-merge hook fires
    │
    ▼
Check: did SeleneChat/* change?
    │
    ├─ No  → exit silently
    │
    └─ Yes → build + install + notify
```

---

## Implementation

### File Structure

```
scripts/
├── hooks/
│   └── post-merge          # The hook script (version controlled)
└── setup-hooks.sh          # One-time setup (creates symlink)
```

### Hook Logic (`scripts/hooks/post-merge`)

```bash
#!/bin/bash

# Exit if no SeleneChat files changed
if ! git diff-tree -r --name-only ORIG_HEAD HEAD | grep -q "^SeleneChat/"; then
    exit 0
fi

# Build and install
LOG_FILE="$HOME/.selenechat-build.log"
cd "$(git rev-parse --show-toplevel)/SeleneChat"

if ./build-app.sh > "$LOG_FILE" 2>&1; then
    # Success: install to Applications
    rm -rf /Applications/SeleneChat.app
    cp -R .build/release/SeleneChat.app /Applications/
    osascript -e 'display notification "Build complete" with title "SeleneChat Updated"'
else
    # Failure: keep old app, notify with error
    osascript -e 'display notification "Check ~/.selenechat-build.log" with title "SeleneChat Build Failed"'
    exit 1
fi
```

### Setup Script (`scripts/setup-hooks.sh`)

```bash
#!/bin/bash

REPO_ROOT="$(git rev-parse --show-toplevel)"
HOOK_SOURCE="$REPO_ROOT/scripts/hooks/post-merge"
HOOK_TARGET="$REPO_ROOT/.git/hooks/post-merge"

if [ -L "$HOOK_TARGET" ] || [ -f "$HOOK_TARGET" ]; then
    echo "Hook already exists at $HOOK_TARGET"
    echo "Remove it first if you want to reinstall"
    exit 1
fi

ln -s "$HOOK_SOURCE" "$HOOK_TARGET"
echo "Hook installed: $HOOK_TARGET -> $HOOK_SOURCE"
```

---

## Behavior

### Change Detection

Uses `git diff-tree` to check if any files under `SeleneChat/` changed:
- Docs-only merges: no build
- Workflow changes: no build
- Script changes: no build
- SeleneChat code changes: build

### Build Process

1. Runs existing `./build-app.sh` (already creates proper .app bundle)
2. Captures all output to `~/.selenechat-build.log`
3. On success: replaces `/Applications/SeleneChat.app`
4. On failure: keeps existing app untouched

### Notifications

- **Success:** "SeleneChat Updated" with "Build complete"
- **Failure:** "SeleneChat Build Failed" with "Check ~/.selenechat-build.log"

Uses built-in `osascript` - no dependencies.

### Log File

- Location: `~/.selenechat-build.log`
- Overwrites on each build (not append)
- Contains full build output for debugging

---

## Integration with GitOps

Fires automatically during the closure ritual:

```bash
git checkout main
git pull origin main
git merge phase-X.Y/feature-name  # <-- hook fires here
git push origin main
```

Only triggers in main repo (worktrees have separate .git directories).

---

## What's NOT Included (YAGNI)

- Version badge in app About menu
- Build history/archive
- Scheduled/nightly builds
- Worktree triggers
- GitHub Actions integration
- Slack/webhook notifications

---

## Setup Instructions

One-time setup after cloning:

```bash
./scripts/setup-hooks.sh
```

---

## Success Criteria

- [ ] Merging SeleneChat changes triggers automatic build
- [ ] App appears in `/Applications/SeleneChat.app`
- [ ] macOS notification shows on success
- [ ] macOS notification shows on failure
- [ ] Failed builds don't break existing app
- [ ] Non-SeleneChat merges don't trigger builds
