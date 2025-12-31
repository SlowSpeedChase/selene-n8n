#!/bin/bash

# Obsidian Export Workflow Test Script with Test Markers
# Tests export functionality and marks test data for easy cleanup

set -e

# Colors for output
GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Configuration
WEBHOOK_URL="http://localhost:5678/webhook/obsidian-export"
DB_PATH="data/selene.db"
VAULT_PATH="vault/Selene"

# Generate unique test run ID
TEST_RUN_ID="test-run-$(date +%Y%m%d-%H%M%S)"

# Test counters
PASSED=0
FAILED=0
TOTAL=0

# Navigate to project root
cd "$(dirname "$0")/../../.."

echo "=========================================="
echo "Selene Obsidian Export Workflow Test Suite"
echo "=========================================="
echo -e "${BLUE}Test Run ID: ${TEST_RUN_ID}${NC}"
echo ""

# Helper function to run a test
run_test() {
    local test_name="$1"
    local expected_result="$2"
    local actual_result="$3"

    TOTAL=$((TOTAL + 1))
    echo -n "Test $TOTAL: $test_name... "

    if [ "$actual_result" = "$expected_result" ]; then
        echo -e "${GREEN}PASS${NC}"
        PASSED=$((PASSED + 1))
        return 0
    else
        echo -e "${RED}FAIL${NC}"
        echo "  Expected: $expected_result"
        echo "  Got: $actual_result"
        FAILED=$((FAILED + 1))
        return 1
    fi
}

echo -e "${YELLOW}Phase 1: Prerequisites Check${NC}"
echo ""

# Test 1: Check Docker container is running
DOCKER_STATUS=$(docker ps --format '{{.Names}}' | grep -c "selene-n8n" || echo "0")
run_test "Docker container running" "1" "$DOCKER_STATUS"

# Test 2: Check database exists
if [ -f "$DB_PATH" ]; then
    DB_EXISTS="1"
else
    DB_EXISTS="0"
fi
run_test "Database exists" "1" "$DB_EXISTS"

# Test 3: Check vault directory exists
if [ -d "$VAULT_PATH" ]; then
    VAULT_EXISTS="1"
else
    VAULT_EXISTS="0"
fi
run_test "Vault directory exists" "1" "$VAULT_EXISTS"

# Test 4: Check export Python script exists in container
SCRIPT_EXISTS=$(docker exec selene-n8n test -f /workflows/scripts/obsidian_export.py && echo "1" || echo "0")
run_test "Export script exists in container" "1" "$SCRIPT_EXISTS"

echo ""
echo -e "${YELLOW}Phase 2: Create Test Data${NC}"
echo ""

# Create a test note with all required fields for export
echo "Creating test note in database..."

# First, insert a raw note with test_run marker
sqlite3 "$DB_PATH" "
INSERT INTO raw_notes (
    title,
    content,
    content_hash,
    source_type,
    word_count,
    character_count,
    tags,
    created_at,
    status,
    exported_to_obsidian,
    test_run
) VALUES (
    'Obsidian Export Test Note - ${TEST_RUN_ID}',
    'This is a test note for the Obsidian export workflow. It contains multiple sentences to ensure word count is accurate. TODO: Verify this exports correctly. The note covers topics like testing, automation, and ADHD productivity systems.',
    'test-hash-${TEST_RUN_ID}',
    'drafts',
    35,
    280,
    '[\"testing\", \"automation\", \"export\"]',
    datetime('now'),
    'processed',
    0,
    '${TEST_RUN_ID}'
);
"

# Get the raw note ID
RAW_NOTE_ID=$(sqlite3 "$DB_PATH" "SELECT id FROM raw_notes WHERE test_run = '${TEST_RUN_ID}' LIMIT 1;")
echo "Created raw note with ID: $RAW_NOTE_ID"

# Insert corresponding processed note with sentiment data
sqlite3 "$DB_PATH" "
INSERT INTO processed_notes (
    raw_note_id,
    concepts,
    concept_confidence,
    primary_theme,
    secondary_themes,
    theme_confidence,
    sentiment_analyzed,
    overall_sentiment,
    sentiment_score,
    emotional_tone,
    energy_level,
    sentiment_data,
    processed_at,
    note_created_at
) VALUES (
    ${RAW_NOTE_ID},
    '[\"testing\", \"automation\", \"workflow\"]',
    '{\"testing\": 0.9, \"automation\": 0.85, \"workflow\": 0.8}',
    'technical',
    '[\"productivity\", \"development\"]',
    0.88,
    1,
    'positive',
    0.75,
    'determined',
    'high',
    '{\"markers\": {\"hyperfocus\": true, \"overwhelm\": false}}',
    datetime('now'),
    datetime('now')
);
"

echo "Created processed note for raw note ID: $RAW_NOTE_ID"

# Verify test data was created
TEST_DATA_COUNT=$(sqlite3 "$DB_PATH" "SELECT COUNT(*) FROM raw_notes WHERE test_run = '${TEST_RUN_ID}';")
run_test "Test note created in raw_notes" "1" "$TEST_DATA_COUNT"

PROCESSED_COUNT=$(sqlite3 "$DB_PATH" "
SELECT COUNT(*)
FROM raw_notes rn
JOIN processed_notes pn ON rn.id = pn.raw_note_id
WHERE rn.test_run = '${TEST_RUN_ID}'
  AND pn.sentiment_analyzed = 1;
")
run_test "Processed note with sentiment exists" "1" "$PROCESSED_COUNT"

echo ""
echo -e "${YELLOW}Phase 3: Trigger Export Workflow${NC}"
echo ""

# Test 5: Trigger webhook and check response
echo "Triggering export webhook..."
WEBHOOK_RESPONSE=$(curl -s -X POST "$WEBHOOK_URL" -H "Content-Type: application/json" -d "{\"noteId\": ${RAW_NOTE_ID}}" 2>&1 || echo "CURL_ERROR")

if echo "$WEBHOOK_RESPONSE" | grep -q "success\|exported\|Workflow was started"; then
    WEBHOOK_SUCCESS="1"
else
    WEBHOOK_SUCCESS="0"
    echo "Webhook response: $WEBHOOK_RESPONSE"
fi
run_test "Webhook triggered successfully" "1" "$WEBHOOK_SUCCESS"

# Wait for export to complete
echo "Waiting for export to complete..."
sleep 5

echo ""
echo -e "${YELLOW}Phase 4: Verify Export Results${NC}"
echo ""

# Check if database was updated
EXPORTED_FLAG=$(sqlite3 "$DB_PATH" "SELECT exported_to_obsidian FROM raw_notes WHERE test_run = '${TEST_RUN_ID}';" || echo "0")
run_test "Note marked as exported in database" "1" "$EXPORTED_FLAG"

# Check for exported file in vault (check various locations)
TEST_NOTE_PATTERN="*Export-Test-Note*${TEST_RUN_ID}*"
EXPORTED_FILES=$(find "$VAULT_PATH" -name "*.md" -newer "$DB_PATH" 2>/dev/null | wc -l | tr -d ' ')

# Also check By-Concept directory specifically
CONCEPT_DIR_CHECK=$(find "$VAULT_PATH/By-Concept" -type f -name "*.md" 2>/dev/null | head -5 | wc -l | tr -d ' ')

if [ "$EXPORTED_FILES" -gt 0 ] || [ "$CONCEPT_DIR_CHECK" -gt 0 ]; then
    FILES_CREATED="1"
else
    FILES_CREATED="0"
fi
run_test "Markdown files exist in vault" "1" "$FILES_CREATED"

echo ""
echo -e "${YELLOW}Phase 5: Cleanup${NC}"
echo ""

# Clean up test markdown files created
echo "Cleaning up test files..."
find "$VAULT_PATH" -name "*${TEST_RUN_ID}*" -type f -delete 2>/dev/null || true

# Clean up test data from database
echo "Cleaning up test data from database..."
sqlite3 "$DB_PATH" "DELETE FROM processed_notes WHERE raw_note_id IN (SELECT id FROM raw_notes WHERE test_run = '${TEST_RUN_ID}');"
sqlite3 "$DB_PATH" "DELETE FROM raw_notes WHERE test_run = '${TEST_RUN_ID}';"

# Verify cleanup
REMAINING=$(sqlite3 "$DB_PATH" "SELECT COUNT(*) FROM raw_notes WHERE test_run = '${TEST_RUN_ID}';")
run_test "Test data cleaned up" "0" "$REMAINING"

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

if [ $FAILED -eq 0 ]; then
    echo -e "${GREEN}All tests passed!${NC}"
    exit 0
else
    echo -e "${RED}Some tests failed. Check the output above for details.${NC}"
    exit 1
fi
