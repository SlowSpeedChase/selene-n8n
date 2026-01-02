# Scripts and Utilities Context

## Purpose

Bash automation scripts for testing, cleanup, workflow management, and database operations. Simplifies common development tasks and ensures consistent test data handling.

## Tech Stack

- Bash 4.0+ (shell scripting)
- SQLite CLI (database operations)
- curl (HTTP requests for testing)
- jq (JSON parsing, optional)
- Docker CLI (container management)

## Key Files

- **manage-workflow.sh** - n8n workflow management (export, import, update)
- **test-ingest.sh** - Test note ingestion workflow
- **cleanup-tests.sh** - Remove test data from database
- **import-workflows.sh** - Import n8n workflows
- **cleanup-production-database.sh** - Production data maintenance
- **run-doc-agent.sh** - Execute documentation agent
- **test-with-markers.sh** (in workflow dirs) - Workflow-specific testing
- **archive-stale-plans.sh** - Archive completed/superseded design documents

## Common Patterns

### Script Header Template
```bash
#!/bin/bash
# Script Purpose: Brief description
# Usage: ./script-name.sh [args]

set -e  # Exit on error
set -u  # Exit on undefined variable

# Color output for readability
RED='\033[0,31m'
GREEN='\033[0,32m'
YELLOW='\033[0,33m'
NC='\033[0m'  # No Color

# Helper functions
log_info() {
    echo -e "${GREEN}[INFO]${NC} $1"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

log_warn() {
    echo -e "${YELLOW}[WARN]${NC} $1"
}
```

### Test Data Markers
```bash
# Generate unique test run ID
TEST_RUN="test-run-$(date +%Y%m%d-%H%M%S)"

# Use in webhook payload
curl -X POST http://localhost:5678/webhook/ingest-note \
    -H "Content-Type: application/json" \
    -d "{
        \"content\": \"Test note\",
        \"test_run\": \"${TEST_RUN}\"
    }"

# Cleanup after test
sqlite3 data/selene.db "DELETE FROM raw_notes WHERE test_run = '${TEST_RUN}';"
```

### Database Operations
```bash
# Safe database access
DB_PATH="./data/selene.db"

if [ ! -f "$DB_PATH" ]; then
    log_error "Database not found: $DB_PATH"
    exit 1
fi

# Read-only query
sqlite3 "$DB_PATH" "SELECT COUNT(*) FROM raw_notes WHERE test_run IS NULL;"

# Write operation (use with caution)
sqlite3 "$DB_PATH" "DELETE FROM raw_notes WHERE test_run = '${TEST_RUN}';"
```

## test-ingest.sh

### Purpose
Test the 01-ingestion workflow with various payloads.

### Usage
```bash
./scripts/test-ingest.sh
```

### Pattern
```bash
#!/bin/bash
set -e

WEBHOOK_URL="http://localhost:5678/webhook/ingest-note"
TEST_RUN="test-run-$(date +%Y%m%d-%H%M%S)"

# Test 1: Normal note
curl -X POST "$WEBHOOK_URL" \
    -H "Content-Type: application/json" \
    -d "{
        \"content\": \"This is a test note\",
        \"uuid\": \"test-uuid-001\",
        \"test_run\": \"$TEST_RUN\"
    }"

# Test 2: Duplicate detection
curl -X POST "$WEBHOOK_URL" \
    -H "Content-Type: application/json" \
    -d "{
        \"content\": \"This is a test note\",
        \"uuid\": \"test-uuid-002\",
        \"test_run\": \"$TEST_RUN\"
    }"

# Verify results
COUNT=$(sqlite3 data/selene.db "SELECT COUNT(*) FROM raw_notes WHERE test_run = '$TEST_RUN';")
echo "Created $COUNT notes (expected: 1 due to deduplication)"

# Cleanup
read -p "Cleanup test data? (y/n) " -n 1 -r
if [[ $REPLY =~ ^[Yy]$ ]]; then
    ./scripts/cleanup-tests.sh "$TEST_RUN"
fi
```

## cleanup-tests.sh

### Purpose
Remove test data from database by test_run marker.

### Usage
```bash
# List all test runs
./scripts/cleanup-tests.sh --list

# Clean specific test run
./scripts/cleanup-tests.sh test-run-20251124-120000

# Clean all test data
./scripts/cleanup-tests.sh --all
```

### Pattern
```bash
#!/bin/bash
set -e

DB_PATH="./data/selene.db"

list_test_runs() {
    sqlite3 "$DB_PATH" "
        SELECT DISTINCT test_run, COUNT(*) as count
        FROM raw_notes
        WHERE test_run IS NOT NULL
        GROUP BY test_run
        ORDER BY test_run DESC;
    "
}

cleanup_test_run() {
    local test_run=$1

    echo "Cleaning test run: $test_run"

    # Clean from all tables
    sqlite3 "$DB_PATH" "DELETE FROM raw_notes WHERE test_run = '$test_run';"
    sqlite3 "$DB_PATH" "DELETE FROM processed_notes WHERE test_run = '$test_run';"
    sqlite3 "$DB_PATH" "DELETE FROM sentiment_history WHERE test_run = '$test_run';"
    # ... other tables

    echo "Cleanup complete"
}

case "${1:---list}" in
    --list)
        list_test_runs
        ;;
    --all)
        read -p "Delete ALL test data? (y/n) " -n 1 -r
        if [[ $REPLY =~ ^[Yy]$ ]]; then
            sqlite3 "$DB_PATH" "DELETE FROM raw_notes WHERE test_run IS NOT NULL;"
            # ... other tables
        fi
        ;;
    *)
        cleanup_test_run "$1"
        ;;
esac
```

## import-workflows.sh

### Purpose
Import all n8n workflows from JSON files.

### Usage
```bash
./scripts/import-workflows.sh
```

### Pattern
```bash
#!/bin/bash
set -e

WORKFLOW_DIR="./workflows"
N8N_URL="http://localhost:5678"

for workflow_json in "$WORKFLOW_DIR"/*/workflow.json; do
    workflow_name=$(basename $(dirname "$workflow_json"))

    echo "Importing $workflow_name..."

    # Note: n8n API import would go here
    # This is placeholder - actual implementation depends on n8n API

    echo "✓ $workflow_name imported"
done
```

## manage-workflow.sh

### Purpose
Comprehensive n8n workflow management via CLI - list, export, import, and update workflows.

**CRITICAL: This is the PRIMARY tool for workflow modifications. Always use this instead of manual n8n UI edits.**

### Usage

```bash
# List all workflows
./scripts/manage-workflow.sh list

# Show workflow details
./scripts/manage-workflow.sh show <workflow-id>

# Export workflow to JSON
./scripts/manage-workflow.sh export <workflow-id> [output-file]

# Import workflow from JSON
./scripts/manage-workflow.sh import <input-file> [--separate]

# Update existing workflow (creates backup first)
./scripts/manage-workflow.sh update <workflow-id> <input-file>

# Backup credentials
./scripts/manage-workflow.sh backup-creds [output-file]

# New lifecycle commands
./scripts/manage-workflow.sh status              # Show sync state and orphans
./scripts/manage-workflow.sh init                # Initialize mapping from n8n
./scripts/manage-workflow.sh sync [name]         # Sync git -> n8n
./scripts/manage-workflow.sh cleanup [--force]   # Remove orphaned workflows
```

### Common Workflows

#### Modifying an Existing Workflow

```bash
# 1. List workflows to find ID
./scripts/manage-workflow.sh list

# 2. Export current version (creates timestamped backup)
./scripts/manage-workflow.sh export 1

# 3. Edit the workflow JSON using Read/Edit tools
# (Make changes to workflows/01-ingestion/workflow.json)

# 4. Update the workflow (auto-backup + import)
./scripts/manage-workflow.sh update 1 /workflows/01-ingestion/workflow.json

# 5. Test the workflow
./workflows/01-ingestion/scripts/test-with-markers.sh

# 6. Update documentation
# Edit workflows/01-ingestion/docs/STATUS.md
```

#### Creating a New Workflow

```bash
# 1. Create workflow JSON file
# (Use Read/Write tools to create workflows/XX-name/workflow.json)

# 2. Import into n8n
./scripts/manage-workflow.sh import /workflows/XX-name/workflow.json

# 3. Test the workflow
./workflows/XX-name/scripts/test-with-markers.sh
```

#### Emergency Backup

```bash
# Backup all credentials (sensitive!)
./scripts/manage-workflow.sh backup-creds

# Export specific workflow
./scripts/manage-workflow.sh export 1 /workflows/backup-critical.json
```

### Features

- **Automatic Backups**: `update` command creates timestamped backups before importing
- **Interactive Mode**: Run `export` or `show` without ID to select interactively
- **Container Checks**: Verifies n8n container is running before operations
- **Color-Coded Output**: Info (green), warnings (yellow), errors (red), steps (blue)
- **Safe Operations**: Validates inputs and provides clear error messages

### Integration with Workflow Development

**ALWAYS follow this pattern when modifying workflows:**

1. **Export** current version (backup)
2. **Edit** JSON file using Read/Edit tools
3. **Import** updated version
4. **Test** with test-with-markers.sh
5. **Document** changes in STATUS.md
6. **Commit** to git

### Pattern

```bash
#!/bin/bash
set -e

CONTAINER_NAME="selene-n8n"

# Check container is running
check_container() {
    if ! docker ps --format '{{.Names}}' | grep -q "^${CONTAINER_NAME}$"; then
        echo "ERROR: Container not running"
        exit 1
    fi
}

# List workflows
list_workflows() {
    docker exec "$CONTAINER_NAME" n8n list:workflow
}

# Export workflow
export_workflow() {
    local workflow_id="$1"
    local output_file="${2:-/workflows/backup-${workflow_id}-$(date +%Y%m%d-%H%M%S).json}"

    docker exec "$CONTAINER_NAME" n8n export:workflow --id="$workflow_id" --output="$output_file"
    echo "Exported to: $output_file"
}

# Import workflow
import_workflow() {
    local input_file="$1"
    local separate="${2:-false}"

    if [ "$separate" = "--separate" ]; then
        docker exec "$CONTAINER_NAME" n8n import:workflow --input="$input_file" --separate
    else
        docker exec "$CONTAINER_NAME" n8n import:workflow --input="$input_file"
    fi
}

# Update workflow (backup + import)
update_workflow() {
    local workflow_id="$1"
    local input_file="$2"

    # Backup first
    export_workflow "$workflow_id"

    # Import updated version
    import_workflow "$input_file" "--separate"
}
```

### Error Handling

```bash
# Container not running
if ! docker ps | grep -q selene-n8n; then
    echo "ERROR: n8n container not running"
    echo "Start with: docker-compose up -d"
    exit 1
fi

# Invalid workflow ID
if ! docker exec selene-n8n n8n show:workflow --id="$ID" 2>/dev/null; then
    echo "ERROR: Workflow $ID not found"
    exit 1
fi

# File not found
if [ ! -f "$INPUT_FILE" ]; then
    echo "ERROR: File not found: $INPUT_FILE"
    exit 1
fi
```

### Workflow Lifecycle Management

The script now includes git-first workflow lifecycle management:

**Source of Truth:** `workflows/XX-name/workflow.json` files in git

**ID Mapping:** `.workflow-ids.json` (gitignored) maps logical names to n8n IDs

**Daily Workflow:**
```bash
# 1. Edit workflow JSON in git
# 2. Push to n8n
./scripts/manage-workflow.sh sync 07-task-extraction

# 3. Test
./workflows/07-task-extraction/scripts/test-with-markers.sh

# 4. Commit
git add workflows/07-task-extraction/workflow.json
git commit -m "feat(07): description"
```

**First-Time Setup:**
```bash
./scripts/manage-workflow.sh init     # Create mapping from current n8n state
./scripts/manage-workflow.sh status   # Review
./scripts/manage-workflow.sh cleanup  # Remove old versions
```

## test-with-markers.sh (Workflow-Specific)

### Purpose
Test individual workflows with unique markers for cleanup.

### Location
Each workflow directory: `workflows/XX-name/scripts/test-with-markers.sh`

### Pattern
```bash
#!/bin/bash
set -e

# Navigate to workflow directory
cd "$(dirname "$0")/.."

TEST_RUN="test-run-$(date +%Y%m%d-%H%M%S)"
DB_PATH="../../data/selene.db"

echo "Testing workflow with marker: $TEST_RUN"

# Workflow-specific test cases
test_case_1() {
    echo "Test 1: Normal processing"
    # Insert test data or trigger webhook
}

test_case_2() {
    echo "Test 2: Edge case"
    # Test edge case scenario
}

# Run all tests
test_case_1
test_case_2

# Report results
PASS_COUNT=$(sqlite3 "$DB_PATH" "SELECT COUNT(*) FROM ... WHERE test_run = '$TEST_RUN';")
echo "Tests complete: $PASS_COUNT passed"

# Cleanup prompt
read -p "Cleanup test data? (y/n) " -n 1 -r
if [[ $REPLY =~ ^[Yy]$ ]]; then
    ../../scripts/cleanup-tests.sh "$TEST_RUN"
fi
```

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

## Common Utility Functions

### Check Docker Running
```bash
check_docker() {
    if ! docker ps > /dev/null 2>&1; then
        log_error "Docker is not running"
        exit 1
    fi
}
```

### Check n8n Ready
```bash
check_n8n() {
    if ! curl -s http://localhost:5678 > /dev/null; then
        log_error "n8n is not running or not accessible"
        exit 1
    fi
}
```

### Database Backup
```bash
backup_database() {
    local backup_path="data/selene-backup-$(date +%Y%m%d-%H%M%S).db"
    sqlite3 data/selene.db ".backup $backup_path"
    log_info "Database backed up to: $backup_path"
}
```

## Do NOT

- **NEVER modify production data without backup** - Always backup first
- **NEVER skip error handling** - Use `set -e` and validate inputs
- **NEVER hardcode paths** - Use relative paths or variables
- **NEVER commit test data** - Always use test_run markers
- **NEVER use rm -rf without confirmation** - Prompt user first
- **NEVER skip logging** - Use colored output for readability

## Error Handling

### Input Validation
```bash
if [ $# -eq 0 ]; then
    echo "Usage: $0 <test-run-id>"
    exit 1
fi

if [ ! -f "$DB_PATH" ]; then
    log_error "Database not found: $DB_PATH"
    exit 1
fi
```

### Cleanup on Error
```bash
cleanup_on_error() {
    log_error "Script failed, cleaning up..."
    # Cleanup code here
}

trap cleanup_on_error ERR
```

## Testing Best Practices

### Idempotent Scripts
```bash
# Script can be run multiple times safely
if ! test_data_exists; then
    create_test_data
fi
```

### Verbose Output
```bash
# Optional verbose mode
VERBOSE=${VERBOSE:-false}

if [ "$VERBOSE" = true ]; then
    set -x  # Print commands before execution
fi
```

## Related Context

@workflows/01-ingestion/scripts/test-with-markers.sh
@database/schema.sql
@README.md
