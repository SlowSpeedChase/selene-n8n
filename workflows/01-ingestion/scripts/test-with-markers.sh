#!/bin/bash

# Ingestion Workflow Test Script with Test Markers
# Tests all functionality and marks test data for easy cleanup

set -e

# Colors for output
GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Configuration
WEBHOOK_URL="http://localhost:5678/webhook/api/drafts"
DB_PATH="data/selene.db"

# Generate unique test run ID
TEST_RUN_ID="test-run-$(date +%Y%m%d-%H%M%S)"

# Test counters
PASSED=0
FAILED=0
TOTAL=0

echo "=========================================="
echo "Selene Ingestion Workflow Test Suite"
echo "=========================================="
echo -e "${BLUE}Test Run ID: ${TEST_RUN_ID}${NC}"
echo ""

# Helper function to run a test
run_test() {
    local test_name="$1"
    local payload="$2"
    local verification_query="$3"
    local expected_result="$4"

    TOTAL=$((TOTAL + 1))
    echo -n "Test $TOTAL: $test_name... "

    # Send webhook request with test_run marker
    response=$(curl -s -X POST "$WEBHOOK_URL" \
        -H "Content-Type: application/json" \
        -d "$payload" 2>&1)

    # Wait for processing
    sleep 2

    # Verify in database if query provided
    if [ -n "$verification_query" ]; then
        db_result=$(sqlite3 "$DB_PATH" "$verification_query" 2>&1 || echo "QUERY_ERROR")

        if [ "$db_result" = "$expected_result" ]; then
            echo -e "${GREEN}PASS${NC}"
            PASSED=$((PASSED + 1))
            return 0
        else
            echo -e "${RED}FAIL${NC}"
            echo "  Expected: $expected_result"
            echo "  Got: $db_result"
            FAILED=$((FAILED + 1))
            return 1
        fi
    else
        # Just check webhook response
        if echo "$response" | grep -q "Workflow was started"; then
            echo -e "${GREEN}PASS${NC}"
            PASSED=$((PASSED + 1))
            return 0
        else
            echo -e "${RED}FAIL${NC}"
            echo "  Response: $response"
            FAILED=$((FAILED + 1))
            return 1
        fi
    fi
}

echo -e "${YELLOW}Running Tests...${NC}"
echo ""

# Test 1: Basic Note Ingestion
run_test "Basic Note Ingestion" \
    '{
        "title": "Test Note 1",
        "content": "This is a basic test note to verify ingestion works.",
        "created_at": "2025-10-29T22:00:00Z",
        "source_type": "drafts",
        "test_run": "'"$TEST_RUN_ID"'"
    }' \
    "SELECT COUNT(*) FROM raw_notes WHERE title='Test Note 1' AND test_run='$TEST_RUN_ID';" \
    "1"

# Test 2: Note with Tags
run_test "Note with Tags" \
    '{
        "title": "Tagged Note",
        "content": "This note has #productivity and #testing tags in it.",
        "created_at": "2025-10-29T22:05:00Z",
        "test_run": "'"$TEST_RUN_ID"'"
    }' \
    "SELECT tags FROM raw_notes WHERE title='Tagged Note' AND test_run='$TEST_RUN_ID';" \
    '["productivity","testing"]'

# Test 3: Duplicate Detection
run_test "Duplicate Detection" \
    '{
        "title": "Test Note 1",
        "content": "This is a basic test note to verify ingestion works.",
        "created_at": "2025-10-29T22:00:00Z",
        "source_type": "drafts",
        "test_run": "'"$TEST_RUN_ID"'"
    }' \
    "SELECT COUNT(*) FROM raw_notes WHERE title='Test Note 1' AND test_run='$TEST_RUN_ID';" \
    "1"

# Test 4: Long Content
run_test "Long Content" \
    '{
        "title": "Long Form Note",
        "content": "This is a much longer note with multiple paragraphs.\\n\\nIt contains several sentences and spans multiple lines.\\n\\nWe want to test that word count, character count, and content hash all work correctly with longer content.\\n\\n#longform #testing #content",
        "created_at": "2025-10-29T22:10:00Z",
        "test_run": "'"$TEST_RUN_ID"'"
    }' \
    "SELECT word_count FROM raw_notes WHERE title='Long Form Note' AND test_run='$TEST_RUN_ID';" \
    "38"

# Test 5: Minimal Required Fields
run_test "Minimal Required Fields" \
    '{
        "content": "Minimal note with no title or timestamp",
        "test_run": "'"$TEST_RUN_ID"'"
    }' \
    "SELECT title FROM raw_notes WHERE content='Minimal note with no title or timestamp' AND test_run='$TEST_RUN_ID';" \
    "Untitled Note"

# Test 6: Empty Content Error
run_test "Empty Content Error" \
    '{
        "title": "Empty Note",
        "content": "",
        "test_run": "'"$TEST_RUN_ID"'"
    }' \
    "SELECT COUNT(*) FROM raw_notes WHERE title='Empty Note' AND test_run='$TEST_RUN_ID';" \
    "0"

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
echo "To view test data:"
echo "  sqlite3 $DB_PATH \"SELECT * FROM raw_notes WHERE test_run='$TEST_RUN_ID';\""
echo ""
echo "To clean up test data:"
echo "  ./workflows/01-ingestion/cleanup-tests.sh $TEST_RUN_ID"
echo "  OR to clean ALL test data:"
echo "  ./workflows/01-ingestion/cleanup-tests.sh --all"
echo ""

if [ $FAILED -eq 0 ]; then
    exit 0
else
    exit 1
fi
