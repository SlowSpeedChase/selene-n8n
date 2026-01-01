#!/bin/bash

# Generate user-stories.md from feedback_notes table
# Run manually or via workflow after processing
#
# Usage:
#   ./scripts/generate-backlog.sh
#
# Environment variables:
#   SELENE_DB_PATH - Path to the database (optional, defaults to production)

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"
DB_PATH="${SELENE_DB_PATH:-$PROJECT_ROOT/data/selene.db}"
OUTPUT_PATH="$PROJECT_ROOT/docs/backlog/user-stories.md"

# Verify database exists
if [ ! -f "$DB_PATH" ]; then
    echo "Error: Database not found at $DB_PATH"
    exit 1
fi

# Verify feedback_notes table exists
if ! sqlite3 "$DB_PATH" "SELECT 1 FROM feedback_notes LIMIT 1;" >/dev/null 2>&1; then
    echo "Error: feedback_notes table does not exist in $DB_PATH"
    exit 1
fi

# Generate backlog content
generate_backlog() {
    local timestamp=$(date -u +"%Y-%m-%d %H:%M UTC")

    cat << EOF
# Selene Backlog

Last updated: $timestamp

*This file is auto-generated from #selene-feedback notes. Do not edit manually.*

---

## How to Add Feedback

Capture a note in Drafts with the \`#selene-feedback\` tag:

\`\`\`
The task suggestion felt wrong - it gave me a high-energy
task when I said I was tired #selene-feedback
\`\`\`

The note will be processed into a user story and added here automatically.

---

EOF

    # Get distinct themes for open stories
    local themes
    if ! themes=$(sqlite3 "$DB_PATH" "SELECT DISTINCT theme FROM feedback_notes WHERE status = 'open' AND test_run IS NULL AND theme IS NOT NULL ORDER BY theme" 2>&1); then
        echo "Error: Failed to query themes: $themes" >&2
        exit 1
    fi

    if [ -z "$themes" ]; then
        cat << EOF
## Open Stories

*No feedback captured yet. Start using Selene and log your thoughts!*

EOF
    else
        echo "$themes" | while IFS= read -r theme; do
            # Skip empty themes
            [ -z "$theme" ] && continue

            # Validate theme only contains expected characters (alphanumeric, hyphen)
            if [[ ! "$theme" =~ ^[a-z0-9-]+$ ]]; then
                echo "Warning: Skipping invalid theme: $theme" >&2
                continue
            fi

            # Escape single quotes in theme for SQL safety
            local escaped_theme="${theme//\'/\'\'}"
            local count=$(sqlite3 "$DB_PATH" "SELECT COUNT(*) FROM feedback_notes WHERE theme = '$escaped_theme' AND status = 'open' AND test_run IS NULL")

            # Convert theme slug to title case (e.g., "ui-design" -> "UI Design")
            local display_theme=$(echo "$theme" | sed 's/-/ /g' | awk '{for(i=1;i<=NF;i++) $i=toupper(substr($i,1,1)) substr($i,2)}1')

            echo "## $display_theme ($count stories)"
            echo ""

            # Query stories for this theme, sorted by priority and mention count
            sqlite3 -separator '|' "$DB_PATH" "
                SELECT id, user_story, priority, mention_count, date(created_at)
                FROM feedback_notes
                WHERE theme = '$escaped_theme' AND status = 'open' AND test_run IS NULL
                ORDER BY priority DESC, mention_count DESC
            " | while IFS='|' read -r id story priority mentions created; do
                # Skip if no story
                [ -z "$story" ] && continue

                # Generate priority stars (with numeric validation)
                local stars=""
                if [[ "$priority" =~ ^[0-9]+$ ]] && [ "$priority" -ge 1 ] && [ "$priority" -le 5 ]; then
                    for ((i=1; i<=priority; i++)); do stars+="*"; done
                else
                    stars="*"  # Default to 1 star if invalid
                fi

                # Truncate story for heading (first 60 chars)
                local heading="${story:0:60}"
                if [ ${#story} -gt 60 ]; then
                    heading="${heading}..."
                fi

                echo "### $stars $heading"
                echo ""
                echo "$story"
                echo ""
                echo "- **Priority:** $priority"
                echo "- **Mentions:** $mentions"
                echo "- **Created:** $created"
                echo "- **ID:** feedback-$id"
                echo ""
            done
        done
    fi

    echo "---"
    echo ""
    echo "## Completed"
    echo ""

    local completed_count=$(sqlite3 "$DB_PATH" "SELECT COUNT(*) FROM feedback_notes WHERE status = 'implemented' AND test_run IS NULL")

    if [ "$completed_count" -eq 0 ]; then
        echo "*Stories move here after implementation.*"
        echo ""
    else
        # Show recent completed stories (limit 10)
        sqlite3 -separator '|' "$DB_PATH" "
            SELECT user_story, implemented_pr, date(implemented_at)
            FROM feedback_notes
            WHERE status = 'implemented' AND test_run IS NULL
            ORDER BY implemented_at DESC
            LIMIT 10
        " | while IFS='|' read -r story pr impl_date; do
            # Skip if no story
            [ -z "$story" ] && continue

            # Truncate story for heading
            local heading="${story:0:50}"
            if [ ${#story} -gt 50 ]; then
                heading="${heading}..."
            fi

            echo "### [$impl_date] $heading"
            echo ""
            echo "$story"
            echo ""
            if [ -n "$pr" ]; then
                echo "- **Implemented in:** $pr"
            fi
            echo ""
        done

        if [ "$completed_count" -gt 10 ]; then
            echo "*...and $((completed_count - 10)) more completed stories.*"
            echo ""
        fi
    fi
}

# Ensure output directory exists
mkdir -p "$(dirname "$OUTPUT_PATH")"

# Generate and write
echo "Generating backlog from $DB_PATH..."
generate_backlog > "$OUTPUT_PATH"
echo "Backlog written to $OUTPUT_PATH"
echo "  - Open stories: $(sqlite3 "$DB_PATH" "SELECT COUNT(*) FROM feedback_notes WHERE status = 'open' AND test_run IS NULL")"
echo "  - Completed: $(sqlite3 "$DB_PATH" "SELECT COUNT(*) FROM feedback_notes WHERE status = 'implemented' AND test_run IS NULL")"

exit 0
