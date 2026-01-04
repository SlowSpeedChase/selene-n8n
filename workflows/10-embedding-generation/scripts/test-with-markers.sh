#!/bin/bash

# Embedding Generation Workflow Test Script
# Tests embedding creation, idempotency, and error handling

set -e

# Colors for output
GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Configuration
WEBHOOK_URL="http://localhost:5678/webhook/api/embed"
DB_PATH="${SELENE_DB_PATH:-data/selene.db}"

# Generate unique test run ID
TEST_RUN_ID="test-run-$(date +%Y%m%d-%H%M%S)"

# Test counters
PASSED=0
FAILED=0
TOTAL=0

# Store created test note IDs for cleanup
TEST_NOTE_IDS=()

echo "=========================================="
echo "Selene Embedding Workflow Test Suite"
echo "=========================================="
echo -e "${BLUE}Test Run ID: ${TEST_RUN_ID}${NC}"
echo -e "${BLUE}Database: ${DB_PATH}${NC}"
echo ""

# Cleanup function
cleanup() {
    echo ""
    echo -e "${YELLOW}Cleaning up test data...${NC}"

    # Delete test embeddings
    sqlite3 "$DB_PATH" "DELETE FROM note_embeddings WHERE test_run = '${TEST_RUN_ID}';" 2>/dev/null || true

    # Delete test notes
    for id in "${TEST_NOTE_IDS[@]}"; do
        sqlite3 "$DB_PATH" "DELETE FROM raw_notes WHERE id = $id AND test_run = '${TEST_RUN_ID}';" 2>/dev/null || true
    done

    echo -e "${GREEN}Cleanup complete${NC}"
}

# Set trap for cleanup on exit
trap cleanup EXIT

# Helper function to create a test note
create_test_note() {
    local content="$1"
    local note_id

    note_id=$(sqlite3 "$DB_PATH" "
        INSERT INTO raw_notes (content, content_hash, test_run, source_type)
        VALUES ('$content', 'hash-${TEST_RUN_ID}-$(date +%s%N)', '${TEST_RUN_ID}', 'test');
        SELECT last_insert_rowid();
    ")

    TEST_NOTE_IDS+=("$note_id")
    echo "$note_id"
}

# Run a test
run_test() {
    local test_name="$1"
    local payload="$2"
    local check_func="$3"

    TOTAL=$((TOTAL + 1))
    echo -n "Test $TOTAL: $test_name... "

    # Send webhook request
    response=$(curl -s -X POST "$WEBHOOK_URL" \
        -H "Content-Type: application/json" \
        -d "$payload" 2>&1)

    # Run verification function
    if $check_func "$response"; then
        echo -e "${GREEN}PASS${NC}"
        PASSED=$((PASSED + 1))
        return 0
    else
        echo -e "${RED}FAIL${NC}"
        echo "  Response: $response"
        FAILED=$((FAILED + 1))
        return 1
    fi
}

# ============================================
# Setup: Create test notes
# ============================================
echo -e "${BLUE}Setting up test data...${NC}"

# Create notes for testing
NOTE_1=$(create_test_note "This is a test note about machine learning and artificial intelligence concepts.")
NOTE_2=$(create_test_note "Another test note discussing software development best practices.")
NOTE_3=$(create_test_note "A third note about productivity and time management strategies.")

echo "Created test notes: $NOTE_1, $NOTE_2, $NOTE_3"
echo ""

# ============================================
# Test 1: Single note embedding
# ============================================
check_single_embed() {
    local response="$1"
    # Check response indicates success and 1 embedded
    echo "$response" | jq -e '.success == true and .summary.embedded == 1' > /dev/null 2>&1
}

run_test "Single note embedding" \
    "{\"note_id\": $NOTE_1, \"test_run\": \"${TEST_RUN_ID}\"}" \
    check_single_embed

# ============================================
# Test 2: Batch embedding (multiple notes)
# ============================================
check_batch_embed() {
    local response="$1"
    # Check response indicates 2 new embeddings
    echo "$response" | jq -e '.success == true and .summary.embedded == 2' > /dev/null 2>&1
}

run_test "Batch embedding (2 notes)" \
    "{\"note_ids\": [$NOTE_2, $NOTE_3], \"test_run\": \"${TEST_RUN_ID}\"}" \
    check_batch_embed

# ============================================
# Test 3: Idempotency - skip existing embedding
# ============================================
check_skip_existing() {
    local response="$1"
    # Should skip (already embedded in Test 1)
    echo "$response" | jq -e '.success == true and .summary.skipped == 1 and .summary.embedded == 0' > /dev/null 2>&1
}

run_test "Skip existing embedding (idempotent)" \
    "{\"note_id\": $NOTE_1, \"test_run\": \"${TEST_RUN_ID}\"}" \
    check_skip_existing

# ============================================
# Test 4: Note not found
# ============================================
check_not_found() {
    local response="$1"
    # Should report not_found
    echo "$response" | jq -e '.success == true and .summary.not_found == 1' > /dev/null 2>&1
}

run_test "Note not found (graceful)" \
    "{\"note_id\": 999999, \"test_run\": \"${TEST_RUN_ID}\"}" \
    check_not_found

# ============================================
# Test 5: Verify embedding dimensions
# ============================================
echo -n "Test $((TOTAL + 1)): Verify embedding dimensions (768)... "
TOTAL=$((TOTAL + 1))

# Query the stored embedding and check dimensions
DIMENSIONS=$(sqlite3 "$DB_PATH" "
    SELECT json_array_length(embedding)
    FROM note_embeddings
    WHERE raw_note_id = $NOTE_1 AND test_run = '${TEST_RUN_ID}'
    LIMIT 1;
")

if [ "$DIMENSIONS" = "768" ]; then
    echo -e "${GREEN}PASS${NC}"
    PASSED=$((PASSED + 1))
else
    echo -e "${RED}FAIL${NC}"
    echo "  Expected: 768 dimensions"
    echo "  Got: $DIMENSIONS"
    FAILED=$((FAILED + 1))
fi

# ============================================
# Summary
# ============================================
echo ""
echo "=========================================="
echo "Test Results"
echo "=========================================="
echo -e "Passed: ${GREEN}$PASSED${NC}"
echo -e "Failed: ${RED}$FAILED${NC}"
echo "Total:  $TOTAL"
echo ""

if [ $FAILED -eq 0 ]; then
    echo -e "${GREEN}All tests passed!${NC}"
    exit 0
else
    echo -e "${RED}Some tests failed${NC}"
    exit 1
fi
