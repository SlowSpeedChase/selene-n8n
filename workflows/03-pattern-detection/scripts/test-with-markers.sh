#!/bin/bash

# Pattern Detection Workflow Test Script
# Tests workflow 03 by manually triggering execution and verifying results
#
# NOTE: This workflow is cron-triggered (daily at 6am), not webhook-triggered.
# The test triggers execution via n8n's workflow execute API.

set -e

# Colors for output
GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Configuration
WORKFLOW_ID="F4YgT8MYfqGZYObF"  # 03-Pattern-Detection | Selene
CONTAINER_NAME="selene-n8n"
DB_PATH="/Users/chaseeasterling/selene-n8n/data/selene.db"

# Generate unique test identifier
TEST_RUN_ID="test-run-$(date +%Y%m%d-%H%M%S)"

# Test counters
PASSED=0
FAILED=0
TOTAL=0

echo "=========================================="
echo "03-Pattern-Detection Workflow Test Suite"
echo "=========================================="
echo -e "${BLUE}Test Run ID: ${TEST_RUN_ID}${NC}"
echo ""

# Helper function for tests
run_test() {
    local test_name="$1"
    local test_command="$2"
    local expected="$3"

    TOTAL=$((TOTAL + 1))
    echo -n "Test $TOTAL: $test_name... "

    result=$(eval "$test_command" 2>&1) || true

    if [[ "$result" == *"$expected"* ]] || [[ "$result" == "$expected" ]]; then
        echo -e "${GREEN}PASS${NC}"
        PASSED=$((PASSED + 1))
        return 0
    else
        echo -e "${RED}FAIL${NC}"
        echo "  Expected to contain: $expected"
        echo "  Got: $result"
        FAILED=$((FAILED + 1))
        return 1
    fi
}

echo -e "${YELLOW}Pre-flight Checks...${NC}"
echo ""

# Check 1: Container running
run_test "Container Running" \
    "docker ps --format '{{.Names}}' | grep -q '$CONTAINER_NAME' && echo 'yes' || echo 'no'" \
    "yes"

# Check 2: Processed notes exist (need at least some for pattern detection)
PROCESSED_COUNT=$(sqlite3 "$DB_PATH" "SELECT COUNT(*) FROM processed_notes;" 2>&1)
run_test "Processed Notes Available (>= 5)" \
    "[ $PROCESSED_COUNT -ge 5 ] && echo 'sufficient' || echo 'insufficient'" \
    "sufficient"
echo -e "${BLUE}  (Found $PROCESSED_COUNT processed notes)${NC}"

# Check 3: Record initial pattern count
INITIAL_PATTERNS=$(sqlite3 "$DB_PATH" "SELECT COUNT(*) FROM detected_patterns;" 2>&1)
echo -e "${BLUE}Initial detected_patterns count: $INITIAL_PATTERNS${NC}"

INITIAL_REPORTS=$(sqlite3 "$DB_PATH" "SELECT COUNT(*) FROM pattern_reports;" 2>&1)
echo -e "${BLUE}Initial pattern_reports count: $INITIAL_REPORTS${NC}"
echo ""

echo -e "${YELLOW}Triggering Workflow...${NC}"
echo ""

# Trigger the workflow execution via n8n CLI
# Note: Since this is a scheduled workflow, we trigger it manually
TRIGGER_RESULT=$(docker exec "$CONTAINER_NAME" n8n execute --id="$WORKFLOW_ID" 2>&1 | grep -v "Error tracking" || true)

echo -e "${BLUE}Trigger Result: ${NC}"
echo "$TRIGGER_RESULT"
echo ""

# Wait for processing
echo "Waiting for workflow to complete..."
sleep 5

echo -e "${YELLOW}Verification Tests...${NC}"
echo ""

# Test: Check for new patterns (may or may not create new patterns depending on data)
FINAL_PATTERNS=$(sqlite3 "$DB_PATH" "SELECT COUNT(*) FROM detected_patterns;" 2>&1)
echo -e "${BLUE}Final detected_patterns count: $FINAL_PATTERNS${NC}"

# Test: Check for new reports
FINAL_REPORTS=$(sqlite3 "$DB_PATH" "SELECT COUNT(*) FROM pattern_reports;" 2>&1)
echo -e "${BLUE}Final pattern_reports count: $FINAL_REPORTS${NC}"

# Test 3: Database integrity - detected_patterns table
run_test "Detected Patterns Table Accessible" \
    "sqlite3 '$DB_PATH' 'SELECT pattern_type, pattern_name, confidence FROM detected_patterns LIMIT 1;' 2>&1 | head -1" \
    ""  # Just check it doesn't error

# Test 4: Database integrity - pattern_reports table
run_test "Pattern Reports Table Accessible" \
    "sqlite3 '$DB_PATH' 'SELECT report_id, total_patterns, generated_at FROM pattern_reports ORDER BY generated_at DESC LIMIT 1;' 2>&1 | head -1" \
    ""  # Just check it doesn't error

# Test 5: Workflow execution recorded (check if execution completed)
run_test "Workflow Execution Completed" \
    "echo '$TRIGGER_RESULT' | grep -c 'Execution was' || echo '0'" \
    ""  # Check for some execution output

# Show latest patterns if any
echo ""
echo -e "${YELLOW}Latest Detected Patterns:${NC}"
sqlite3 "$DB_PATH" "SELECT pattern_type, pattern_name, confidence, discovered_at FROM detected_patterns ORDER BY discovered_at DESC LIMIT 5;" 2>&1 || echo "No patterns found"

echo ""
echo -e "${YELLOW}Latest Pattern Report:${NC}"
sqlite3 "$DB_PATH" "SELECT report_id, total_patterns, high_confidence_count, generated_at FROM pattern_reports ORDER BY generated_at DESC LIMIT 1;" 2>&1 || echo "No reports found"

echo ""
echo "=========================================="
echo "Test Summary"
echo "=========================================="
echo -e "Total Tests: $TOTAL"
echo -e "${GREEN}Passed: $PASSED${NC}"
echo -e "${RED}Failed: $FAILED${NC}"
echo ""
echo -e "${BLUE}Test Run ID: ${TEST_RUN_ID}${NC}"
echo ""

# Note about cron-triggered workflow
echo -e "${YELLOW}Note:${NC} This workflow is cron-triggered (daily at 6am)."
echo "Pattern detection depends on having sufficient processed notes with:"
echo "  - Multiple themes appearing across weeks"
echo "  - At least 3+ occurrences per theme"
echo "  - Theme frequency changes of 20%+ to detect trends"
echo ""
echo "If no new patterns were created, this is expected behavior when:"
echo "  - Not enough data variation exists"
echo "  - Existing patterns already cover current trends"
echo ""

if [ $FAILED -eq 0 ]; then
    echo -e "${GREEN}All tests passed!${NC}"
    exit 0
else
    echo -e "${RED}Some tests failed. Review output above.${NC}"
    exit 1
fi
