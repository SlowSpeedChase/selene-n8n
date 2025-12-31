#!/bin/bash

# Task Extraction Workflow Test Script with Classification Testing
# Tests all three classification paths (actionable, needs_planning, archive_only)
# Marks test data for easy cleanup

set -e

# Colors for output
GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

# Navigate to project root (relative to scripts directory)
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"

# Detect if we're in a worktree or main project
# Worktrees are in .worktrees/ directory
if [[ "$SCRIPT_DIR" == *".worktrees"* ]]; then
    # Extract main project path from worktree path
    PROJECT_ROOT="${SCRIPT_DIR%%/.worktrees/*}"
    echo "Running from worktree, using main project database at: $PROJECT_ROOT"
else
    PROJECT_ROOT="$SCRIPT_DIR/../../.."
fi

cd "$PROJECT_ROOT"

# Configuration
WEBHOOK_URL="http://localhost:5678/webhook/task-extraction"
DB_PATH="$PROJECT_ROOT/data/selene.db"
THINGS_WRAPPER_URL="http://localhost:3456/create-task"

# Generate unique test run ID
TEST_RUN="test-run-$(date +%Y%m%d-%H%M%S)"

# Test counters
PASSED=0
FAILED=0
SKIPPED=0
TOTAL=0

# Flags
N8N_AVAILABLE=false
THINGS_AVAILABLE=false
OLLAMA_AVAILABLE=false

echo "=========================================="
echo "Task Extraction Classification Test Suite"
echo "=========================================="
echo -e "${BLUE}Test Run ID: ${TEST_RUN}${NC}"
echo ""

# ============================================================================
# Dependency Checks
# ============================================================================

echo -e "${YELLOW}Checking dependencies...${NC}"

# Check if n8n is running
if curl -s --max-time 3 "http://localhost:5678/healthz" > /dev/null 2>&1; then
    echo -e "  n8n: ${GREEN}Available${NC}"
    N8N_AVAILABLE=true
else
    echo -e "  n8n: ${RED}Not available${NC} (workflow tests will be skipped)"
fi

# Check if Ollama is running
if curl -s --max-time 3 "http://localhost:11434/api/tags" > /dev/null 2>&1; then
    echo -e "  Ollama: ${GREEN}Available${NC}"
    OLLAMA_AVAILABLE=true
else
    echo -e "  Ollama: ${RED}Not available${NC} (classification tests may fail)"
fi

# Check if Things wrapper is running
if curl -s --max-time 3 "$THINGS_WRAPPER_URL" > /dev/null 2>&1; then
    echo -e "  Things Wrapper: ${GREEN}Available${NC}"
    THINGS_AVAILABLE=true
else
    echo -e "  Things Wrapper: ${YELLOW}Not available${NC} (task creation will use mock IDs)"
fi

# Check if database exists
if [ -f "$DB_PATH" ]; then
    echo -e "  Database: ${GREEN}Available${NC}"
else
    echo -e "  Database: ${RED}Not found at $DB_PATH${NC}"
    echo "Please ensure the database exists and run migrations first."
    exit 1
fi

# Check if classification column exists
CLASSIFICATION_EXISTS=$(sqlite3 "$DB_PATH" "SELECT COUNT(*) FROM pragma_table_info('processed_notes') WHERE name='classification';" 2>/dev/null || echo "0")
if [ "$CLASSIFICATION_EXISTS" = "1" ]; then
    echo -e "  Migration 008: ${GREEN}Applied${NC}"
else
    echo -e "  Migration 008: ${RED}Not applied${NC}"
    echo ""
    echo "Please run the migration first:"
    echo "  sqlite3 $DB_PATH < database/migrations/008_classification_fields.sql"
    exit 1
fi

echo ""

# ============================================================================
# Helper Functions
# ============================================================================

# Create a test note in the database and return its ID
create_test_note() {
    local content="$1"
    local title="$2"

    # Generate unique hash
    local hash="hash-${TEST_RUN}-${RANDOM}"

    # Insert raw note
    sqlite3 "$DB_PATH" "INSERT INTO raw_notes (title, content, content_hash, test_run, created_at) VALUES ('$title', '$content', '$hash', '$TEST_RUN', datetime('now'));"
    local raw_id=$(sqlite3 "$DB_PATH" "SELECT id FROM raw_notes WHERE test_run = '$TEST_RUN' ORDER BY id DESC LIMIT 1;")

    # Insert processed note with default classification
    # Note: processed_notes doesn't have test_run column, we track via raw_notes
    sqlite3 "$DB_PATH" "INSERT INTO processed_notes (raw_note_id, concepts, primary_theme) VALUES ($raw_id, '[\"test-concept\"]', 'test-theme');"

    echo "$raw_id"
}

# Run a classification test
run_classification_test() {
    local test_name="$1"
    local content="$2"
    local title="$3"
    local expected_classification="$4"
    local check_discussion_thread="$5"  # "yes" or "no"
    local check_task_metadata="$6"      # "yes" or "no"

    TOTAL=$((TOTAL + 1))
    echo ""
    echo -e "${CYAN}=== Test $TOTAL: $test_name ===${NC}"
    echo -e "Content: \"$content\""
    echo -e "Expected: $expected_classification"

    if [ "$N8N_AVAILABLE" != "true" ]; then
        echo -e "${YELLOW}SKIP${NC} (n8n not available)"
        SKIPPED=$((SKIPPED + 1))
        return 0
    fi

    # Create test note
    local note_id=$(create_test_note "$content" "$title")
    echo "Created test note ID: $note_id"

    # Trigger workflow
    echo "Triggering workflow..."
    local response=$(curl -s -X POST "$WEBHOOK_URL" \
        -H "Content-Type: application/json" \
        -d "{\"raw_note_id\": $note_id, \"test_run\": \"$TEST_RUN\"}" 2>&1)

    # Wait for processing (Ollama can take 5-15 seconds)
    echo "Waiting for classification (15 seconds)..."
    sleep 15

    # Check classification result
    local classification=$(sqlite3 "$DB_PATH" "SELECT classification FROM processed_notes WHERE raw_note_id = $note_id;" 2>/dev/null || echo "")
    echo "Actual classification: $classification"

    local test_passed=true

    # Verify classification
    if [ "$classification" = "$expected_classification" ]; then
        echo -e "Classification: ${GREEN}PASS${NC}"
    else
        echo -e "Classification: ${RED}FAIL${NC} (expected: $expected_classification, got: $classification)"
        test_passed=false
    fi

    # Check for discussion thread (for needs_planning)
    if [ "$check_discussion_thread" = "yes" ]; then
        local thread_count=$(sqlite3 "$DB_PATH" "SELECT COUNT(*) FROM discussion_threads WHERE raw_note_id = $note_id AND test_run = '$TEST_RUN';" 2>/dev/null || echo "0")
        if [ "$thread_count" -ge "1" ]; then
            echo -e "Discussion thread created: ${GREEN}YES${NC}"
        else
            echo -e "Discussion thread created: ${RED}NO${NC} (expected: 1+)"
            test_passed=false
        fi

        # Check planning_status
        local planning_status=$(sqlite3 "$DB_PATH" "SELECT planning_status FROM processed_notes WHERE raw_note_id = $note_id;" 2>/dev/null || echo "")
        if [ "$planning_status" = "pending_review" ]; then
            echo -e "Planning status: ${GREEN}pending_review${NC}"
        else
            echo -e "Planning status: ${RED}$planning_status${NC} (expected: pending_review)"
            test_passed=false
        fi
    fi

    # Check for task metadata (for actionable)
    if [ "$check_task_metadata" = "yes" ]; then
        local task_count=$(sqlite3 "$DB_PATH" "SELECT COUNT(*) FROM task_metadata WHERE raw_note_id = $note_id AND test_run = '$TEST_RUN';" 2>/dev/null || echo "0")
        if [ "$task_count" -ge "1" ]; then
            echo -e "Task metadata created: ${GREEN}YES${NC} ($task_count tasks)"
        else
            # This might be expected if Things wrapper is not running
            if [ "$THINGS_AVAILABLE" = "true" ]; then
                echo -e "Task metadata created: ${RED}NO${NC} (expected: 1+)"
                test_passed=false
            else
                echo -e "Task metadata created: ${YELLOW}NO${NC} (Things wrapper not available)"
            fi
        fi
    fi

    # Check for NO discussion thread (for archive_only)
    if [ "$expected_classification" = "archive_only" ]; then
        local thread_count=$(sqlite3 "$DB_PATH" "SELECT COUNT(*) FROM discussion_threads WHERE raw_note_id = $note_id AND test_run = '$TEST_RUN';" 2>/dev/null || echo "0")
        if [ "$thread_count" = "0" ]; then
            echo -e "No discussion thread (correct): ${GREEN}YES${NC}"
        else
            echo -e "Unexpected discussion thread: ${RED}FOUND${NC}"
            test_passed=false
        fi
    fi

    # Record result
    if [ "$test_passed" = true ]; then
        echo -e "${GREEN}TEST PASSED${NC}"
        PASSED=$((PASSED + 1))
    else
        echo -e "${RED}TEST FAILED${NC}"
        FAILED=$((FAILED + 1))
    fi
}

# ============================================================================
# Test Cases
# ============================================================================

echo -e "${YELLOW}Running Classification Tests...${NC}"

# Test 1: Actionable Note
run_classification_test \
    "Actionable Note Classification" \
    "I need to call the dentist tomorrow to schedule an appointment" \
    "Quick task test" \
    "actionable" \
    "no" \
    "yes"

# Test 2: Needs Planning Note
run_classification_test \
    "Needs Planning Note Classification" \
    "I want to completely redesign my personal website. Should have a portfolio, blog, maybe newsletter signup, need to figure out hosting and design..." \
    "Project idea test" \
    "needs_planning" \
    "yes" \
    "no"

# Test 3: Archive Only Note
run_classification_test \
    "Archive Only Note Classification" \
    "Thinking about how my energy levels fluctuate throughout the day. Mornings are usually better for deep work." \
    "Reflection test" \
    "archive_only" \
    "no" \
    "no"

# ============================================================================
# Summary
# ============================================================================

echo ""
echo "=========================================="
echo "Test Summary"
echo "=========================================="
echo -e "Total Tests: $TOTAL"
echo -e "${GREEN}Passed: $PASSED${NC}"
echo -e "${RED}Failed: $FAILED${NC}"
echo -e "${YELLOW}Skipped: $SKIPPED${NC}"
echo ""
echo -e "${BLUE}Test Run ID: ${TEST_RUN}${NC}"
echo ""

# Show test data summary
echo -e "${CYAN}Test Data Created:${NC}"
NOTES_COUNT=$(sqlite3 "$DB_PATH" "SELECT COUNT(*) FROM raw_notes WHERE test_run = '$TEST_RUN';" 2>/dev/null || echo "0")
# processed_notes doesn't have test_run - join via raw_notes
PROCESSED_COUNT=$(sqlite3 "$DB_PATH" "SELECT COUNT(*) FROM processed_notes pn JOIN raw_notes rn ON pn.raw_note_id = rn.id WHERE rn.test_run = '$TEST_RUN';" 2>/dev/null || echo "0")
THREADS_COUNT=$(sqlite3 "$DB_PATH" "SELECT COUNT(*) FROM discussion_threads WHERE test_run = '$TEST_RUN';" 2>/dev/null || echo "0")
TASKS_COUNT=$(sqlite3 "$DB_PATH" "SELECT COUNT(*) FROM task_metadata WHERE test_run = '$TEST_RUN';" 2>/dev/null || echo "0")

echo "  Raw notes: $NOTES_COUNT"
echo "  Processed notes: $PROCESSED_COUNT"
echo "  Discussion threads: $THREADS_COUNT"
echo "  Task metadata records: $TASKS_COUNT"
echo ""

# Show classification breakdown
echo -e "${CYAN}Classifications:${NC}"
sqlite3 "$DB_PATH" "SELECT pn.classification, COUNT(*) as count FROM processed_notes pn JOIN raw_notes rn ON pn.raw_note_id = rn.id WHERE rn.test_run = '$TEST_RUN' GROUP BY pn.classification;" 2>/dev/null | while read line; do
    echo "  $line"
done

echo ""
echo "To view test data:"
echo "  sqlite3 $DB_PATH \"SELECT rn.id, rn.title, pn.classification, pn.planning_status FROM raw_notes rn JOIN processed_notes pn ON rn.id = pn.raw_note_id WHERE rn.test_run='$TEST_RUN';\""
echo ""
echo "To view discussion threads:"
echo "  sqlite3 $DB_PATH \"SELECT * FROM discussion_threads WHERE test_run='$TEST_RUN';\""
echo ""
echo "To clean up test data:"
echo "  ./scripts/cleanup-tests.sh $TEST_RUN"
echo ""

# ============================================================================
# Cleanup Option
# ============================================================================

if [ -t 0 ]; then  # Only prompt if running interactively
    read -p "Cleanup test data now? (y/n) " -n 1 -r
    echo ""
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        echo "Cleaning up test data..."

        # Delete in correct order (foreign key constraints)
        sqlite3 "$DB_PATH" "DELETE FROM task_metadata WHERE test_run = '$TEST_RUN';" 2>/dev/null || true
        sqlite3 "$DB_PATH" "DELETE FROM discussion_threads WHERE test_run = '$TEST_RUN';" 2>/dev/null || true
        # processed_notes needs to be deleted via join
        sqlite3 "$DB_PATH" "DELETE FROM processed_notes WHERE raw_note_id IN (SELECT id FROM raw_notes WHERE test_run = '$TEST_RUN');" 2>/dev/null || true
        sqlite3 "$DB_PATH" "DELETE FROM raw_notes WHERE test_run = '$TEST_RUN';" 2>/dev/null || true

        echo -e "${GREEN}Cleanup complete.${NC}"
    else
        echo "Test data preserved. Run cleanup later with:"
        echo "  ./scripts/cleanup-tests.sh $TEST_RUN"
    fi
fi

# Exit with appropriate code
if [ $FAILED -eq 0 ]; then
    exit 0
else
    exit 1
fi
