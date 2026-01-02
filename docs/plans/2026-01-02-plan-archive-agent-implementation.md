# Plan Archive Agent Implementation Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** Automated git post-commit hook that archives completed/superseded design documents and cleans stale references.

**Architecture:** Post-commit hook triggers `archive-stale-plans.sh` which parses INDEX.md for status, moves qualifying files to `_archived/`, updates INDEX.md, cleans references, and auto-commits.

**Tech Stack:** Bash, git, sed, grep

**Design Doc:** `docs/plans/2026-01-02-plan-archive-agent-design.md`

---

## Task 1: Create Archive Directory

**Files:**
- Create: `docs/plans/_archived/.gitkeep`

**Step 1: Create the directory structure**

```bash
mkdir -p docs/plans/_archived
touch docs/plans/_archived/.gitkeep
```

**Step 2: Verify directory exists**

Run: `ls -la docs/plans/_archived/`
Expected: Shows `.gitkeep` file

**Step 3: Commit**

```bash
git add docs/plans/_archived/.gitkeep
git commit -m "chore: create _archived directory for stale plans"
```

---

## Task 2: Create Archive Script - Core Structure

**Files:**
- Create: `scripts/archive-stale-plans.sh`

**Step 1: Create script with header and helpers**

```bash
#!/bin/bash
# archive-stale-plans.sh - Archive completed/superseded design documents
# Called by post-commit hook

set -e

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

# Configuration
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"
PLANS_DIR="$PROJECT_ROOT/docs/plans"
ARCHIVE_DIR="$PLANS_DIR/_archived"
INDEX_FILE="$PLANS_DIR/INDEX.md"
DRY_RUN="${ARCHIVE_DRY_RUN:-0}"
STALE_DAYS=14

# Track what we archived
ARCHIVED_FILES=()
UPDATED_REFS=()

log_info() { echo -e "${GREEN}[archive]${NC} $1"; }
log_warn() { echo -e "${YELLOW}[archive]${NC} $1"; }
log_error() { echo -e "${RED}[archive]${NC} $1" >&2; }

# Check if we should skip
should_skip() {
    # Skip if no plans directory
    if [ ! -d "$PLANS_DIR" ]; then
        return 0
    fi

    # Skip if no INDEX.md
    if [ ! -f "$INDEX_FILE" ]; then
        return 0
    fi

    # Skip in worktrees
    if [ -f "$(git rev-parse --git-dir)/commondir" ]; then
        return 0
    fi

    return 1
}

# Main entry point (implemented in later tasks)
main() {
    if should_skip; then
        exit 0
    fi

    log_info "Checking for stale plans..."
    # Implementation continues in next tasks
}

main "$@"
```

**Step 2: Make executable and test structure**

Run: `chmod +x scripts/archive-stale-plans.sh && ./scripts/archive-stale-plans.sh`
Expected: "Checking for stale plans..." message

**Step 3: Commit**

```bash
git add scripts/archive-stale-plans.sh
git commit -m "feat: add archive-stale-plans.sh core structure"
```

---

## Task 3: Add INDEX.md Parsing

**Files:**
- Modify: `scripts/archive-stale-plans.sh`

**Step 1: Add function to extract completed/superseded files from INDEX.md**

Add before `main()`:

```bash
# Parse INDEX.md for files with given status
# Usage: get_files_by_status "Completed" or "Superseded"
get_files_by_status() {
    local status="$1"
    local in_section=0
    local files=()

    while IFS= read -r line; do
        # Check if we're entering the target section
        if echo "$line" | grep -qi "^## $status"; then
            in_section=1
            continue
        fi

        # Check if we're leaving the section (new ## header)
        if [ $in_section -eq 1 ] && echo "$line" | grep -q "^## "; then
            break
        fi

        # Extract filename from table row (| date | filename.md | ... |)
        if [ $in_section -eq 1 ]; then
            local filename
            filename=$(echo "$line" | grep -oE '[0-9]{4}-[0-9]{2}-[0-9]{2}-[a-zA-Z0-9_-]+\.md' | head -1)
            if [ -n "$filename" ] && [ -f "$PLANS_DIR/$filename" ]; then
                files+=("$filename")
            fi
        fi
    done < "$INDEX_FILE"

    printf '%s\n' "${files[@]}"
}

# Check if file has KEEP marker
has_keep_marker() {
    local file="$1"
    grep -q '<!-- KEEP:' "$PLANS_DIR/$file" 2>/dev/null
}
```

**Step 2: Add function to get uncategorized files**

Add after `has_keep_marker()`:

```bash
# Get files from Uncategorized section that are stale
get_stale_uncategorized() {
    local files=()
    local cutoff_date
    cutoff_date=$(date -v-${STALE_DAYS}d +%Y-%m-%d 2>/dev/null || date -d "-${STALE_DAYS} days" +%Y-%m-%d)

    while IFS= read -r line; do
        local filename
        filename=$(echo "$line" | grep -oE '[0-9]{4}-[0-9]{2}-[0-9]{2}-[a-zA-Z0-9_-]+\.md' | head -1)

        if [ -n "$filename" ] && [ -f "$PLANS_DIR/$filename" ]; then
            # Check last modification date
            local last_modified
            last_modified=$(git log -1 --format=%cs -- "$PLANS_DIR/$filename" 2>/dev/null)

            if [ -n "$last_modified" ] && [[ "$last_modified" < "$cutoff_date" ]]; then
                files+=("$filename")
            fi
        fi
    done < <(sed -n '/^## Uncategorized/,/^## /p' "$INDEX_FILE" | head -n -1)

    printf '%s\n' "${files[@]}"
}
```

**Step 3: Test parsing**

Run: `./scripts/archive-stale-plans.sh`
Expected: No errors (parsing functions exist but not yet called)

**Step 4: Commit**

```bash
git add scripts/archive-stale-plans.sh
git commit -m "feat: add INDEX.md parsing for completed/superseded/uncategorized"
```

---

## Task 4: Add Archive Function

**Files:**
- Modify: `scripts/archive-stale-plans.sh`

**Step 1: Add archive_file function**

Add before `main()`:

```bash
# Archive a single file
archive_file() {
    local filename="$1"
    local reason="$2"
    local source="$PLANS_DIR/$filename"
    local dest="$ARCHIVE_DIR/$filename"

    # Check KEEP marker
    if has_keep_marker "$filename"; then
        log_warn "Skipping $filename (has KEEP marker)"
        return 0
    fi

    if [ "$DRY_RUN" -eq 1 ]; then
        log_info "[DRY RUN] Would archive: $filename ($reason)"
        return 0
    fi

    # Move file
    git mv "$source" "$dest"
    ARCHIVED_FILES+=("$filename:$reason")
    log_info "Archived: $filename ($reason)"
}
```

**Step 2: Update main() to collect and archive files**

Replace the `main()` function:

```bash
main() {
    if should_skip; then
        exit 0
    fi

    # Ensure archive directory exists
    mkdir -p "$ARCHIVE_DIR"

    log_info "Checking for stale plans..."

    # Collect files to archive
    local to_archive=()

    # Get completed files
    while IFS= read -r file; do
        [ -n "$file" ] && to_archive+=("$file:completed")
    done < <(get_files_by_status "Completed")

    # Get superseded files
    while IFS= read -r file; do
        [ -n "$file" ] && to_archive+=("$file:superseded")
    done < <(get_files_by_status "Superseded")

    # Get stale uncategorized files
    while IFS= read -r file; do
        [ -n "$file" ] && to_archive+=("$file:stale-uncategorized")
    done < <(get_stale_uncategorized)

    # Nothing to archive
    if [ ${#to_archive[@]} -eq 0 ]; then
        log_info "No stale plans to archive"
        exit 0
    fi

    log_info "Found ${#to_archive[@]} files to archive"

    # Archive each file
    for entry in "${to_archive[@]}"; do
        local file="${entry%%:*}"
        local reason="${entry##*:}"
        archive_file "$file" "$reason"
    done

    # Continue to update INDEX and commit (next tasks)
    if [ ${#ARCHIVED_FILES[@]} -gt 0 ]; then
        update_index
        clean_references
        commit_changes
    fi
}
```

**Step 3: Add placeholder functions**

Add before `main()`:

```bash
# Placeholder - implemented in next task
update_index() {
    log_info "Updating INDEX.md..."
}

# Placeholder - implemented in next task
clean_references() {
    log_info "Cleaning stale references..."
}

# Placeholder - implemented in next task
commit_changes() {
    log_info "Committing changes..."
}
```

**Step 4: Test with dry run**

Run: `ARCHIVE_DRY_RUN=1 ./scripts/archive-stale-plans.sh`
Expected: Shows "[DRY RUN] Would archive:" for completed/superseded files

**Step 5: Commit**

```bash
git add scripts/archive-stale-plans.sh
git commit -m "feat: add archive_file function with dry-run support"
```

---

## Task 5: Add INDEX.md Update Function

**Files:**
- Modify: `scripts/archive-stale-plans.sh`

**Step 1: Replace update_index placeholder**

```bash
# Update INDEX.md - remove archived entries, add to Archived section
update_index() {
    log_info "Updating INDEX.md..."

    local today
    today=$(date +%Y-%m-%d)
    local temp_file
    temp_file=$(mktemp)

    # Remove archived files from their original sections
    local index_content
    index_content=$(cat "$INDEX_FILE")

    for entry in "${ARCHIVED_FILES[@]}"; do
        local file="${entry%%:*}"
        # Remove line containing this filename
        index_content=$(echo "$index_content" | grep -v "$file")
    done

    # Check if Archived section exists
    if echo "$index_content" | grep -q "^<details>"; then
        # Update existing Archived section
        # Insert new entries before </details>
        local new_entries=""
        for entry in "${ARCHIVED_FILES[@]}"; do
            local file="${entry%%:*}"
            local date_prefix
            date_prefix=$(echo "$file" | grep -oE '^[0-9]{4}-[0-9]{2}-[0-9]{2}' || echo "unknown")
            local name
            name=$(echo "$file" | sed 's/^[0-9-]*-//')
            new_entries+="| $date_prefix | $name | $today |"$'\n'
        done

        index_content=$(echo "$index_content" | sed "s|</details>|$new_entries</details>|")
    else
        # Add new Archived section at end
        local archived_section
        archived_section=$'\n---\n\n<details>\n<summary>Archived</summary>\n\n| Date | Document | Archived |\n|------|----------|----------|\n'

        for entry in "${ARCHIVED_FILES[@]}"; do
            local file="${entry%%:*}"
            local date_prefix
            date_prefix=$(echo "$file" | grep -oE '^[0-9]{4}-[0-9]{2}-[0-9]{2}' || echo "unknown")
            local name
            name=$(echo "$file" | sed 's/^[0-9-]*-//')
            archived_section+="| $date_prefix | $name | $today |"$'\n'
        done

        archived_section+=$'\n</details>\n'
        index_content+="$archived_section"
    fi

    # Update summary count
    local count=${#ARCHIVED_FILES[@]}
    index_content=$(echo "$index_content" | sed -E "s/<summary>Archived \([0-9]+ documents\)<\/summary>/<summary>Archived ($count documents)<\/summary>/")

    echo "$index_content" > "$INDEX_FILE"
}
```

**Step 2: Test with dry run (no actual changes)**

Run: `ARCHIVE_DRY_RUN=1 ./scripts/archive-stale-plans.sh`
Expected: Shows files that would be archived, but INDEX.md unchanged

**Step 3: Commit**

```bash
git add scripts/archive-stale-plans.sh
git commit -m "feat: add update_index function to maintain INDEX.md"
```

---

## Task 6: Add Reference Cleaning

**Files:**
- Modify: `scripts/archive-stale-plans.sh`

**Step 1: Replace clean_references placeholder**

```bash
# Clean stale references from context files
clean_references() {
    log_info "Cleaning stale references..."

    local context_files=(
        "$PROJECT_ROOT/CLAUDE.md"
        "$PROJECT_ROOT/.claude/PROJECT-STATUS.md"
        "$PROJECT_ROOT/.claude/GITOPS.md"
    )

    for ctx_file in "${context_files[@]}"; do
        [ ! -f "$ctx_file" ] && continue

        local modified=0
        local content
        content=$(cat "$ctx_file")

        for entry in "${ARCHIVED_FILES[@]}"; do
            local file="${entry%%:*}"

            # Check if file is referenced
            if echo "$content" | grep -q "$file"; then
                # Remove lines in navigation tables that reference this file
                # Pattern: | ... | `@docs/plans/filename.md` | ... |
                content=$(echo "$content" | grep -v "@docs/plans/$file")

                # Also handle non-@ references
                content=$(echo "$content" | grep -v "docs/plans/$file")

                modified=1
                UPDATED_REFS+=("$ctx_file:$file")
                log_info "Removed reference to $file from $(basename "$ctx_file")"
            fi
        done

        if [ $modified -eq 1 ]; then
            echo "$content" > "$ctx_file"
        fi
    done
}
```

**Step 2: Test parsing (dry run)**

Run: `ARCHIVE_DRY_RUN=1 ./scripts/archive-stale-plans.sh`
Expected: No errors

**Step 3: Commit**

```bash
git add scripts/archive-stale-plans.sh
git commit -m "feat: add clean_references to update context files"
```

---

## Task 7: Add Commit Function

**Files:**
- Modify: `scripts/archive-stale-plans.sh`

**Step 1: Replace commit_changes placeholder**

```bash
# Commit all changes
commit_changes() {
    if [ "$DRY_RUN" -eq 1 ]; then
        log_info "[DRY RUN] Would commit changes"
        return 0
    fi

    # Stage all changes
    git add "$ARCHIVE_DIR"
    git add "$INDEX_FILE"

    for ctx_file in "$PROJECT_ROOT/CLAUDE.md" "$PROJECT_ROOT/.claude/PROJECT-STATUS.md" "$PROJECT_ROOT/.claude/GITOPS.md"; do
        [ -f "$ctx_file" ] && git add "$ctx_file"
    done

    # Build commit message
    local msg="chore: archive stale design documents"$'\n\n'
    msg+="Archived ${#ARCHIVED_FILES[@]} documents to docs/plans/_archived/:"$'\n'

    for entry in "${ARCHIVED_FILES[@]}"; do
        local file="${entry%%:*}"
        local reason="${entry##*:}"
        msg+="- $file ($reason)"$'\n'
    done

    if [ ${#UPDATED_REFS[@]} -gt 0 ]; then
        msg+=$'\n'"Updated references in:"$'\n'
        for ref in "${UPDATED_REFS[@]}"; do
            local ctx="${ref%%:*}"
            msg+="- $(basename "$ctx")"$'\n'
        done
    fi

    git commit -m "$msg"
    log_info "Committed archive changes"
}
```

**Step 2: Verify complete script**

Run: `ARCHIVE_DRY_RUN=1 ./scripts/archive-stale-plans.sh`
Expected: Full dry-run output showing what would be archived

**Step 3: Commit**

```bash
git add scripts/archive-stale-plans.sh
git commit -m "feat: add commit_changes for auto-commit after archival"
```

---

## Task 8: Create Post-Commit Hook

**Files:**
- Create: `scripts/hooks/post-commit`

**Step 1: Create the hook**

```bash
#!/bin/bash
# Post-commit hook: Archive stale design documents
# Installed by scripts/setup-hooks.sh

# Skip if this is an archive commit (prevent recursion)
if git log -1 --format=%s | grep -q "^chore: archive stale"; then
    exit 0
fi

# Skip merge commits
if git rev-parse -q --verify MERGE_HEAD >/dev/null 2>&1; then
    exit 0
fi

# Run archival (failures are non-blocking)
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
"$SCRIPT_DIR/../../scripts/archive-stale-plans.sh" || true
```

**Step 2: Make executable**

Run: `chmod +x scripts/hooks/post-commit`

**Step 3: Commit**

```bash
git add scripts/hooks/post-commit
git commit -m "feat: add post-commit hook for plan archival"
```

---

## Task 9: Update Setup Script

**Files:**
- Modify: `scripts/setup-hooks.sh`

**Step 1: Add post-commit symlink**

Add before the final echo statements:

```bash
# Create symlink for post-commit hook
if [ -f "$PROJECT_ROOT/.git/hooks/post-commit" ] && [ ! -L "$PROJECT_ROOT/.git/hooks/post-commit" ]; then
    echo "Backing up existing post-commit hook..."
    mv "$PROJECT_ROOT/.git/hooks/post-commit" "$PROJECT_ROOT/.git/hooks/post-commit.backup"
fi

ln -sf "../../scripts/hooks/post-commit" "$PROJECT_ROOT/.git/hooks/post-commit"

echo "✓ Post-commit hook installed (plan archival)"
```

**Step 2: Update final message**

Update the echo at the end to include post-commit:

```bash
echo ""
echo "Hooks are now active. They will run on every commit to:"
echo "  - Warn about documentation in wrong locations"
echo "  - Block recreation of consolidated files"
echo "  - Remind to update docs/plans/INDEX.md for new design docs"
echo "  - Archive completed/superseded plans automatically"
```

**Step 3: Run setup to install hook**

Run: `./scripts/setup-hooks.sh`
Expected: Shows both hooks installed

**Step 4: Verify symlink**

Run: `ls -la .git/hooks/post-commit`
Expected: Symlink to `../../scripts/hooks/post-commit`

**Step 5: Commit**

```bash
git add scripts/setup-hooks.sh
git commit -m "feat: update setup-hooks.sh to install post-commit hook"
```

---

## Task 10: End-to-End Test

**Step 1: Run dry-run to see what would be archived**

Run: `ARCHIVE_DRY_RUN=1 ./scripts/archive-stale-plans.sh`
Expected: List of completed/superseded files that would be archived

**Step 2: Run actual archival manually first**

Run: `./scripts/archive-stale-plans.sh`
Expected: Files moved to `_archived/`, INDEX.md updated, auto-commit created

**Step 3: Verify archived files**

Run: `ls docs/plans/_archived/`
Expected: Shows archived `.md` files

**Step 4: Verify INDEX.md has Archived section**

Run: `grep -A5 "<details>" docs/plans/INDEX.md`
Expected: Shows `<summary>Archived</summary>` with entries

**Step 5: Test hook triggers on commit**

```bash
echo "# Test" >> docs/plans/INDEX.md
git add docs/plans/INDEX.md
git commit -m "test: verify post-commit hook runs"
```
Expected: Hook runs silently (no files to archive since we just archived)

**Step 6: Commit test cleanup**

```bash
git revert HEAD --no-edit  # Revert test commit
```

---

## Task 11: Update Documentation

**Files:**
- Modify: `scripts/CLAUDE.md` (add section for archive script)

**Step 1: Add documentation for archive-stale-plans.sh**

Add new section:

```markdown
## archive-stale-plans.sh

### Purpose
Automatically archive completed/superseded design documents to prevent context rot.

### Usage
```bash
# Dry run - see what would be archived
ARCHIVE_DRY_RUN=1 ./scripts/archive-stale-plans.sh

# Manual run (normally triggered by post-commit hook)
./scripts/archive-stale-plans.sh
```

### Behavior
- Parses `docs/plans/INDEX.md` for Completed/Superseded status
- Checks uncategorized files for staleness (14+ days unmodified)
- Moves files to `docs/plans/_archived/`
- Updates INDEX.md with Archived section
- Cleans references in CLAUDE.md, PROJECT-STATUS.md
- Auto-commits all changes

### Override
Add `<!-- KEEP: reason -->` to any plan file to prevent archival.
```

**Step 2: Commit**

```bash
git add scripts/CLAUDE.md
git commit -m "docs: add archive-stale-plans.sh documentation"
```

---

## Task 12: Final Verification & Merge Prep

**Step 1: Run full test suite (if any)**

Run: `./scripts/setup-hooks.sh` (reinstall to verify)
Expected: Both hooks installed successfully

**Step 2: Verify git status is clean**

Run: `git status`
Expected: Nothing to commit, working tree clean

**Step 3: Check archived files are correct**

Run: `ls docs/plans/_archived/ | wc -l`
Expected: Count matches completed + superseded from INDEX.md

**Step 4: Review commits**

Run: `git log --oneline main..HEAD`
Expected: ~12 clean commits following the implementation

**Step 5: Ready for merge**

Branch is ready to merge to main via PR or direct merge.

---

## Summary

| Task | Description | Commits |
|------|-------------|---------|
| 1 | Create _archived directory | 1 |
| 2 | Archive script core structure | 1 |
| 3 | INDEX.md parsing | 1 |
| 4 | Archive function | 1 |
| 5 | INDEX.md update function | 1 |
| 6 | Reference cleaning | 1 |
| 7 | Commit function | 1 |
| 8 | Post-commit hook | 1 |
| 9 | Setup script update | 1 |
| 10 | End-to-end test | 0 |
| 11 | Documentation | 1 |
| 12 | Final verification | 0 |

**Total: ~10 commits**
