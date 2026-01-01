#!/bin/bash
# sync-things-status.sh
# Batch sync task statuses from Things 3 to Selene database
#
# Usage: ./sync-things-status.sh [--dry-run]
#
# Queries all tasks with things_task_id in task_links table,
# checks their status in Things 3, and updates the database.

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
DB_PATH="${SELENE_DB_PATH:-$PROJECT_ROOT/data/selene.db}"
LOG_DIR="$PROJECT_ROOT/logs"
LOG_FILE="$LOG_DIR/things-sync.log"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
NC='\033[0m' # No Color

# Parse arguments
DRY_RUN=false
if [ "${1:-}" = "--dry-run" ]; then
    DRY_RUN=true
    echo -e "${YELLOW}[DRY RUN]${NC} No database changes will be made"
fi

# Ensure log directory exists
mkdir -p "$LOG_DIR"

log() {
    local level="$1"
    local message="$2"
    local timestamp=$(date '+%Y-%m-%d %H:%M:%S')
    echo "[$timestamp] [$level] $message" >> "$LOG_FILE"

    case "$level" in
        INFO)  echo -e "${GREEN}[INFO]${NC} $message" ;;
        WARN)  echo -e "${YELLOW}[WARN]${NC} $message" ;;
        ERROR) echo -e "${RED}[ERROR]${NC} $message" ;;
    esac
}

# Check database exists
if [ ! -f "$DB_PATH" ]; then
    log "ERROR" "Database not found: $DB_PATH"
    exit 1
fi

# Check if task_links table exists
if ! sqlite3 "$DB_PATH" ".schema task_links" > /dev/null 2>&1; then
    log "ERROR" "task_links table not found in database"
    exit 1
fi

log "INFO" "Starting Things status sync..."

# Get all tasks with things_task_id
TASK_IDS=$(sqlite3 "$DB_PATH" "SELECT things_task_id FROM task_links WHERE things_task_id IS NOT NULL AND things_task_id != '';")

if [ -z "$TASK_IDS" ]; then
    log "INFO" "No tasks with Things IDs found"
    exit 0
fi

TOTAL=0
UPDATED=0
COMPLETED=0
NOT_FOUND=0
ERRORS=0

while IFS= read -r things_id; do
    [ -z "$things_id" ] && continue

    TOTAL=$((TOTAL + 1))

    # Get status from Things
    STATUS_JSON=$("$SCRIPT_DIR/check-task-status.sh" "$things_id" 2>/dev/null || echo '{"error": "Script failed"}')

    # Check for error
    if echo "$STATUS_JSON" | grep -q '"error"'; then
        ERROR_MSG=$(echo "$STATUS_JSON" | grep -o '"error": "[^"]*"' | cut -d'"' -f4)
        if echo "$ERROR_MSG" | grep -q "not found"; then
            NOT_FOUND=$((NOT_FOUND + 1))
            log "WARN" "Task not found in Things: $things_id"
        else
            ERRORS=$((ERRORS + 1))
            log "ERROR" "Failed to get status for $things_id: $ERROR_MSG"
        fi
        continue
    fi

    # Extract status from JSON
    THINGS_STATUS=$(echo "$STATUS_JSON" | grep -o '"status": "[^"]*"' | cut -d'"' -f4)
    COMPLETION_DATE=$(echo "$STATUS_JSON" | grep -o '"completion_date": [^,}]*' | cut -d':' -f2 | tr -d ' "')

    if [ "$THINGS_STATUS" = "completed" ]; then
        COMPLETED=$((COMPLETED + 1))

        if [ "$DRY_RUN" = false ]; then
            # Update database with completion status
            sqlite3 "$DB_PATH" "UPDATE task_links SET
                things_status = 'completed',
                things_completed_at = '${COMPLETION_DATE}',
                updated_at = datetime('now')
                WHERE things_task_id = '$things_id';"
            UPDATED=$((UPDATED + 1))
        fi

        log "INFO" "Task completed: $things_id (${COMPLETION_DATE:-unknown date})"
    fi

done <<< "$TASK_IDS"

log "INFO" "Sync complete: $TOTAL tasks checked, $COMPLETED completed, $UPDATED updated, $NOT_FOUND not found, $ERRORS errors"

# Summary
echo ""
echo "=== Sync Summary ==="
echo "Total tasks checked: $TOTAL"
echo "Completed in Things: $COMPLETED"
echo "Database updated:    $UPDATED"
echo "Not found in Things: $NOT_FOUND"
echo "Errors:              $ERRORS"

if [ "$DRY_RUN" = true ]; then
    echo ""
    echo -e "${YELLOW}This was a dry run. Run without --dry-run to update the database.${NC}"
fi
