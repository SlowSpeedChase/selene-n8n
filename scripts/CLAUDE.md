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

- **test-ingest.sh** - Test note ingestion workflow
- **cleanup-tests.sh** - Remove test data from database
- **import-workflows.sh** - Import n8n workflows
- **cleanup-production-database.sh** - Production data maintenance
- **run-doc-agent.sh** - Execute documentation agent
- **test-with-markers.sh** (in workflow dirs) - Workflow-specific testing

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
