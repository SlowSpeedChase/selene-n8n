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
        INSERT INTO raw_notes (title, content, content_hash, created_at, test_run, source_type)
        VALUES ('Test Note', '$content', 'hash-${TEST_RUN_ID}-$(date +%s%N)', datetime('now'), '${TEST_RUN_ID}', 'test');
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
echo -n "Test $((TOTAL + 1)): Single note embedding... "
TOTAL=$((TOTAL + 1))

curl -s -X POST "$WEBHOOK_URL" \
    -H "Content-Type: application/json" \
    -d "{\"note_id\": $NOTE_1, \"test_run\": \"${TEST_RUN_ID}\", \"use_test_db\": true}" > /dev/null

# Wait for async processing
sleep 3

# Verify in database
EMBED_COUNT=$(sqlite3 "$DB_PATH" "SELECT COUNT(*) FROM note_embeddings WHERE raw_note_id = $NOTE_1 AND test_run = '${TEST_RUN_ID}';")

if [ "$EMBED_COUNT" = "1" ]; then
    echo -e "${GREEN}PASS${NC}"
    PASSED=$((PASSED + 1))
else
    echo -e "${RED}FAIL${NC}"
    echo "  Expected 1 embedding, got: $EMBED_COUNT"
    FAILED=$((FAILED + 1))
fi

# ============================================
# Test 2: Batch embedding (multiple notes)
# ============================================
echo -n "Test $((TOTAL + 1)): Batch embedding (2 notes)... "
TOTAL=$((TOTAL + 1))

curl -s -X POST "$WEBHOOK_URL" \
    -H "Content-Type: application/json" \
    -d "{\"note_ids\": [$NOTE_2, $NOTE_3], \"test_run\": \"${TEST_RUN_ID}\", \"use_test_db\": true}" > /dev/null

sleep 8

# Verify both notes got embeddings
BATCH_COUNT=$(sqlite3 "$DB_PATH" "SELECT COUNT(*) FROM note_embeddings WHERE raw_note_id IN ($NOTE_2, $NOTE_3) AND test_run = '${TEST_RUN_ID}';")

if [ "$BATCH_COUNT" = "2" ]; then
    echo -e "${GREEN}PASS${NC}"
    PASSED=$((PASSED + 1))
else
    echo -e "${RED}FAIL${NC}"
    echo "  Expected 2 embeddings, got: $BATCH_COUNT"
    FAILED=$((FAILED + 1))
fi

# ============================================
# Test 3: Idempotency - skip existing embedding
# ============================================
echo -n "Test $((TOTAL + 1)): Skip existing embedding (idempotent)... "
TOTAL=$((TOTAL + 1))

# Get current count for NOTE_1
BEFORE_COUNT=$(sqlite3 "$DB_PATH" "SELECT COUNT(*) FROM note_embeddings WHERE raw_note_id = $NOTE_1;")

curl -s -X POST "$WEBHOOK_URL" \
    -H "Content-Type: application/json" \
    -d "{\"note_id\": $NOTE_1, \"test_run\": \"${TEST_RUN_ID}\", \"use_test_db\": true}" > /dev/null

sleep 3

# Should still be same count (not duplicated)
AFTER_COUNT=$(sqlite3 "$DB_PATH" "SELECT COUNT(*) FROM note_embeddings WHERE raw_note_id = $NOTE_1;")

if [ "$BEFORE_COUNT" = "$AFTER_COUNT" ] && [ "$AFTER_COUNT" = "1" ]; then
    echo -e "${GREEN}PASS${NC}"
    PASSED=$((PASSED + 1))
else
    echo -e "${RED}FAIL${NC}"
    echo "  Before: $BEFORE_COUNT, After: $AFTER_COUNT (expected both 1)"
    FAILED=$((FAILED + 1))
fi

# ============================================
# Test 4: Note not found
# ============================================
echo -n "Test $((TOTAL + 1)): Note not found (graceful)... "
TOTAL=$((TOTAL + 1))

# This should not crash and should not create an embedding
curl -s -X POST "$WEBHOOK_URL" \
    -H "Content-Type: application/json" \
    -d "{\"note_id\": 999999, \"test_run\": \"${TEST_RUN_ID}\", \"use_test_db\": true}" > /dev/null

sleep 2

# Verify no embedding created for non-existent note
NOT_FOUND_COUNT=$(sqlite3 "$DB_PATH" "SELECT COUNT(*) FROM note_embeddings WHERE raw_note_id = 999999;")

if [ "$NOT_FOUND_COUNT" = "0" ]; then
    echo -e "${GREEN}PASS${NC}"
    PASSED=$((PASSED + 1))
else
    echo -e "${RED}FAIL${NC}"
    echo "  Expected 0 embeddings for missing note, got: $NOT_FOUND_COUNT"
    FAILED=$((FAILED + 1))
fi

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
