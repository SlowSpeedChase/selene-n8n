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
        # INDEX format: | 2025-11-14 | ollama-integration-design.md | ... |
        # Actual file:  2025-11-14-ollama-integration-design.md
        if [ $in_section -eq 1 ]; then
            # Try to extract date and short filename from table row
            local row_date short_name full_filename
            row_date=$(echo "$line" | grep -oE '\| *[0-9]{4}-[0-9]{2}-[0-9]{2} *\|' | grep -oE '[0-9]{4}-[0-9]{2}-[0-9]{2}' | head -1)
            short_name=$(echo "$line" | grep -oE '[a-zA-Z0-9_-]+\.md' | head -1)

            if [ -n "$row_date" ] && [ -n "$short_name" ]; then
                # Construct full filename with date prefix
                full_filename="${row_date}-${short_name}"
                if [ -f "$PLANS_DIR/$full_filename" ]; then
                    files+=("$full_filename")
                fi
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

# Get files from Uncategorized section that are stale
get_stale_uncategorized() {
    local files=()
    local cutoff_date
    cutoff_date=$(date -v-${STALE_DAYS}d +%Y-%m-%d 2>/dev/null || date -d "-${STALE_DAYS} days" +%Y-%m-%d)

    while IFS= read -r line; do
        # INDEX format: | 2025-11-15 | selenechat-icon-design.md |
        # Actual file:  2025-11-15-selenechat-icon-design.md
        local row_date short_name full_filename
        row_date=$(echo "$line" | grep -oE '\| *[0-9]{4}-[0-9]{2}-[0-9]{2} *\|' | grep -oE '[0-9]{4}-[0-9]{2}-[0-9]{2}' | head -1)
        short_name=$(echo "$line" | grep -oE '[a-zA-Z0-9_-]+\.md' | head -1)

        if [ -n "$row_date" ] && [ -n "$short_name" ]; then
            full_filename="${row_date}-${short_name}"
            if [ -f "$PLANS_DIR/$full_filename" ]; then
                # Check last modification date via git
                local last_modified
                last_modified=$(git log -1 --format=%cs -- "$PLANS_DIR/$full_filename" 2>/dev/null)

                if [ -n "$last_modified" ] && [[ "$last_modified" < "$cutoff_date" ]]; then
                    files+=("$full_filename")
                fi
            fi
        fi
    # Use awk instead of head -n -1 for macOS compatibility
    done < <(sed -n '/^## Uncategorized/,/^## /p' "$INDEX_FILE" | awk 'NR>1 {print prev} {prev=$0}')

    printf '%s\n' "${files[@]}"
}

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
    if ! git mv "$source" "$dest" 2>/dev/null; then
        log_error "Failed to archive: $filename"
        return 1
    fi
    ARCHIVED_FILES+=("$filename:$reason")
    log_info "Archived: $filename ($reason)"
}

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
        # Extract short name (without date prefix) for matching INDEX.md format
        local short_name
        short_name=$(echo "$file" | sed 's/^[0-9-]*-//')
        # Remove line containing this filename
        index_content=$(echo "$index_content" | grep -v "$short_name")
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

# Placeholder - implemented in next task
clean_references() {
    log_info "Cleaning stale references..."
}

# Placeholder - implemented in next task
commit_changes() {
    log_info "Committing changes..."
}

# Main entry point
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
        if ! archive_file "$file" "$reason"; then
            log_error "Aborting: failed to archive $file"
            exit 1
        fi
    done

    # Continue to update INDEX and commit (next tasks)
    if [ ${#ARCHIVED_FILES[@]} -gt 0 ]; then
        update_index
        clean_references
        commit_changes
    fi
}

main "$@"
