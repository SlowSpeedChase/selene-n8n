#!/bin/bash

# Test Suite for Database Migration (Phase 7.1)
# Following TDD: These tests MUST fail before migration is applied

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

DB_PATH="/Users/chaseeasterling/selene-n8n/data/selene.db"
TEST_RUN_ID="test-run-$(date +%s)"

PASSED=0
FAILED=0

# Test function
run_test() {
  local test_name="$1"
  local test_command="$2"

  echo -ne "${CYAN}Testing:${NC} $test_name... "

  if eval "$test_command" > /dev/null 2>&1; then
    echo -e "${GREEN}✓ PASS${NC}"
    ((PASSED++))
    return 0
  else
    echo -e "${RED}✗ FAIL${NC}"
    ((FAILED++))
    return 1
  fi
}

# Test assertions
assert_table_exists() {
  sqlite3 "$DB_PATH" "SELECT name FROM sqlite_master WHERE type='table' AND name='task_metadata';" | grep -q "task_metadata"
}

assert_column_exists() {
  local column="$1"
  sqlite3 "$DB_PATH" "PRAGMA table_info(task_metadata);" | grep -q "$column"
}

assert_index_exists() {
  local index_pattern="$1"
  sqlite3 "$DB_PATH" "SELECT name FROM sqlite_master WHERE type='index' AND tbl_name='task_metadata';" | grep -q "$index_pattern"
}

assert_can_insert() {
  # Create test note
  NOTE_ID=$(sqlite3 "$DB_PATH" "INSERT INTO raw_notes (title, content, content_hash, source_type, created_at, test_run)
    VALUES ('Test', 'Test content', 'test-hash-$TEST_RUN_ID', 'test', datetime('now'), '$TEST_RUN_ID');
    SELECT last_insert_rowid();")

  # Try to insert task
  sqlite3 "$DB_PATH" "INSERT INTO task_metadata (raw_note_id, things_task_id, energy_required, estimated_minutes, task_type, overwhelm_factor)
    VALUES ($NOTE_ID, 'test-task-$TEST_RUN_ID', 'medium', 30, 'action', 5);"

  # Clean up
  sqlite3 "$DB_PATH" "DELETE FROM task_metadata WHERE things_task_id='test-task-$TEST_RUN_ID';"
  sqlite3 "$DB_PATH" "DELETE FROM raw_notes WHERE id=$NOTE_ID;"
}

assert_energy_constraint() {
  # Create test note
  NOTE_ID=$(sqlite3 "$DB_PATH" "INSERT INTO raw_notes (title, content, content_hash, source_type, created_at, test_run)
    VALUES ('Test', 'Test content', 'test-hash-constraint-$TEST_RUN_ID', 'test', datetime('now'), '$TEST_RUN_ID');
    SELECT last_insert_rowid();")

  # Try to insert invalid energy (should fail)
  if sqlite3 "$DB_PATH" "INSERT INTO task_metadata (raw_note_id, things_task_id, energy_required)
    VALUES ($NOTE_ID, 'test-constraint-$TEST_RUN_ID', 'invalid');" 2>&1 | grep -q "constraint"; then
    # Cleanup
    sqlite3 "$DB_PATH" "DELETE FROM raw_notes WHERE id=$NOTE_ID;"
    return 0
  else
    # Cleanup
    sqlite3 "$DB_PATH" "DELETE FROM task_metadata WHERE things_task_id='test-constraint-$TEST_RUN_ID';"
    sqlite3 "$DB_PATH" "DELETE FROM raw_notes WHERE id=$NOTE_ID;"
    return 1
  fi
}

assert_foreign_key() {
  # Enable foreign keys for this test
  # Try to insert task with non-existent note (should fail)
  if sqlite3 "$DB_PATH" "PRAGMA foreign_keys=ON; INSERT INTO task_metadata (raw_note_id, things_task_id)
    VALUES (999999, 'test-fk-$TEST_RUN_ID');" 2>&1 | grep -q -E "FOREIGN KEY|constraint"; then
    return 0
  else
    # Cleanup if it somehow succeeded
    sqlite3 "$DB_PATH" "DELETE FROM task_metadata WHERE things_task_id='test-fk-$TEST_RUN_ID';"
    return 1
  fi
}

# Header
echo -e "${BLUE}═══════════════════════════════════════════════════════${NC}"
echo -e "${BLUE}  Database Migration Test Suite (TDD - RED Phase)${NC}"
echo -e "${BLUE}═══════════════════════════════════════════════════════${NC}"
echo -e "${YELLOW}Test Run ID: $TEST_RUN_ID${NC}"
echo ""

# DATABASE MIGRATION TESTS
echo -e "${BLUE}━━━ DATABASE MIGRATION TESTS ━━━${NC}"

run_test "task_metadata table exists" assert_table_exists

run_test "Column: raw_note_id exists" "assert_column_exists 'raw_note_id'"
run_test "Column: things_task_id exists" "assert_column_exists 'things_task_id'"
run_test "Column: energy_required exists" "assert_column_exists 'energy_required'"
run_test "Column: estimated_minutes exists" "assert_column_exists 'estimated_minutes'"
run_test "Column: task_type exists" "assert_column_exists 'task_type'"
run_test "Column: overwhelm_factor exists" "assert_column_exists 'overwhelm_factor'"
run_test "Column: related_concepts exists" "assert_column_exists 'related_concepts'"
run_test "Column: context_tags exists" "assert_column_exists 'context_tags'"

run_test "Index on raw_note_id exists" "assert_index_exists 'note'"
run_test "Index on things_task_id exists" "assert_index_exists 'things_id'"

run_test "Can insert task record" assert_can_insert
run_test "Enforces energy constraint" assert_energy_constraint
run_test "Enforces foreign key to raw_notes" assert_foreign_key

echo ""

# Summary
echo -e "${BLUE}═══════════════════════════════════════════════════════${NC}"
echo -e "${BLUE}  Test Summary${NC}"
echo -e "${BLUE}═══════════════════════════════════════════════════════${NC}"
echo -e "${GREEN}Passed: $PASSED${NC}"
echo -e "${RED}Failed: $FAILED${NC}"
echo "Total: $((PASSED + FAILED))"
echo ""

if [ $FAILED -eq 0 ]; then
  echo -e "${GREEN}✓ ALL TESTS PASSED (GREEN phase complete!)${NC}"
  exit 0
else
  echo -e "${YELLOW}⚠ TESTS FAILING (Expected for RED phase of TDD)${NC}"
  echo -e "${YELLOW}Next step: Create and apply migration to make tests pass${NC}"
  exit 1
fi
