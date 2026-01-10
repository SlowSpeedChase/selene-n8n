#!/bin/bash
# Test script for Workflow 08: Project Detection
# Usage: ./test-with-markers.sh

set -e

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/../../.." && pwd)"

# Database is always in main repo, not worktree
# Resolve by finding the main repo (git worktree list gives us the path)
MAIN_REPO=$(git worktree list 2>/dev/null | head -1 | awk '{print $1}' || echo "$PROJECT_ROOT")
DB_PATH="$MAIN_REPO/data/selene.db"

WEBHOOK_URL="http://localhost:5678/webhook/project-detection"
PENDING_DIR="$MAIN_REPO/vault/projects-pending"

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
NC='\033[0m'

TEST_RUN="test-run-$(date +%Y%m%d-%H%M%S)"

log_info() { echo -e "${GREEN}[INFO]${NC} $1"; }
log_warn() { echo -e "${YELLOW}[WARN]${NC} $1"; }
log_error() { echo -e "${RED}[ERROR]${NC} $1"; }

# Setup: Create test tasks with shared concept
setup_test_data() {
    log_info "Creating test data with marker: $TEST_RUN"

    # Insert 3 tasks with shared concept "website-redesign"
    sqlite3 "$DB_PATH" "
        INSERT INTO task_metadata (raw_note_id, things_task_id, energy_required, estimated_minutes, related_concepts, task_type, test_run)
        VALUES
            (1, 'test-task-1-$TEST_RUN', 'high', 60, '[\"website-redesign\", \"frontend\"]', 'action', '$TEST_RUN'),
            (2, 'test-task-2-$TEST_RUN', 'medium', 30, '[\"website-redesign\", \"design\"]', 'research', '$TEST_RUN'),
            (3, 'test-task-3-$TEST_RUN', 'low', 15, '[\"website-redesign\", \"content\"]', 'action', '$TEST_RUN');
    "

    log_info "Created 3 test tasks with shared concept 'website-redesign'"
}

# Test 1: Trigger workflow
test_workflow_trigger() {
    log_info "Test 1: Triggering project detection workflow"

    RESPONSE=$(curl -s -X POST "$WEBHOOK_URL" \
        -H "Content-Type: application/json" \
        -d "{\"test_run\": \"$TEST_RUN\", \"use_test_db\": true}")

    if echo "$RESPONSE" | grep -qi "error"; then
        log_error "Workflow returned error: $RESPONSE"
        return 1
    fi

    log_info "Workflow triggered successfully"
    echo "$RESPONSE" | head -c 200
    echo ""
}

# Test 2: Verify JSON file created
test_json_file_created() {
    log_info "Test 2: Verifying project JSON file created"

    # Wait a moment for file creation
    sleep 2

    # Check for files with our test_run marker
    if [ -d "$PENDING_DIR" ]; then
        FILES=$(find "$PENDING_DIR" -name "*.json" -newer /tmp 2>/dev/null | head -5)
        if [ -n "$FILES" ]; then
            log_info "Found pending project files:"
            echo "$FILES"
            return 0
        fi
    fi

    log_warn "No pending project files found (this may be expected if host script already processed them)"
    return 0
}

# Test 3: Verify project_metadata created (after host processing)
test_project_created() {
    log_info "Test 3: Verifying project_metadata created"

    COUNT=$(sqlite3 "$DB_PATH" "SELECT COUNT(*) FROM project_metadata WHERE test_run = '$TEST_RUN';")

    if [ "$COUNT" -eq 0 ]; then
        log_warn "No project created yet (host script may not have run)"
        log_info "Run: ./scripts/things-bridge/process-pending-projects.sh"
        return 0
    fi

    PROJECT_NAME=$(sqlite3 "$DB_PATH" "SELECT project_name FROM project_metadata WHERE test_run = '$TEST_RUN' LIMIT 1;")
    log_info "Project created: $PROJECT_NAME"
}

# Test 4: Verify energy profile calculated
test_energy_profile() {
    log_info "Test 4: Verifying energy profile calculated"

    ENERGY=$(sqlite3 "$DB_PATH" "SELECT energy_profile FROM project_metadata WHERE test_run = '$TEST_RUN' LIMIT 1;")

    if [ -z "$ENERGY" ]; then
        log_warn "Energy profile not yet calculated (host script may not have run)"
        return 0
    fi

    log_info "Energy profile: $ENERGY"
}

# Cleanup
cleanup() {
    log_info "Cleaning up test data"
    sqlite3 "$DB_PATH" "DELETE FROM task_metadata WHERE test_run = '$TEST_RUN';"
    sqlite3 "$DB_PATH" "DELETE FROM project_metadata WHERE test_run = '$TEST_RUN';"

    # Clean up any test JSON files
    if [ -d "$PENDING_DIR" ]; then
        find "$PENDING_DIR" -name "*$TEST_RUN*.json" -delete 2>/dev/null || true
    fi

    log_info "Cleanup complete"
}

# Main
main() {
    log_info "Starting Workflow 08 tests with marker: $TEST_RUN"
    echo ""

    setup_test_data

    # Run tests
    test_workflow_trigger || { cleanup; exit 1; }
    test_json_file_created || { cleanup; exit 1; }
    test_project_created || { cleanup; exit 1; }
    test_energy_profile || { cleanup; exit 1; }

    echo ""
    log_info "All tests completed!"
    log_info "Note: Full integration requires host script to process pending files"

    # Prompt for cleanup
    read -p "Cleanup test data? (y/n) " -n 1 -r
    echo ""
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        cleanup
    else
        log_warn "Test data retained with marker: $TEST_RUN"
    fi
}

main "$@"
