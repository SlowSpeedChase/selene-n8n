#!/bin/bash

# Test Suite for Classification Fields Migration (Phase 7.1)
# Following TDD: These tests MUST fail before migration is applied
#
# Migration: 008_classification_fields.sql
# Tests:
#   - classification column on processed_notes
#   - planning_status column on processed_notes
#   - discussion_threads table
#   - CHECK constraints
#   - Indexes
#   - Foreign key relationships

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

DB_PATH="${DB_PATH:-/Users/chaseeasterling/selene-n8n/data/selene.db}"
TEST_RUN_ID="test-008-$(date +%s)"

PASSED=0
FAILED=0

# Test function
run_test() {
  local test_name="$1"
  local test_command="$2"

  echo -ne "${CYAN}Testing:${NC} $test_name... "

  if eval "$test_command" > /dev/null 2>&1; then
    echo -e "${GREEN}PASS${NC}"
    ((PASSED++))
    return 0
  else
    echo -e "${RED}FAIL${NC}"
    ((FAILED++))
    return 1
  fi
}

# =============================================================================
# TEST ASSERTIONS: processed_notes.classification
# =============================================================================

assert_classification_column_exists() {
  sqlite3 "$DB_PATH" "PRAGMA table_info(processed_notes);" | grep -q "classification"
}

assert_classification_default_archive_only() {
  # Create test raw_note first
  local raw_id=$(sqlite3 "$DB_PATH" "INSERT INTO raw_notes (title, content, content_hash, source_type, created_at, test_run)
    VALUES ('Test', 'Test content', 'hash-class-default-$TEST_RUN_ID', 'test', datetime('now'), '$TEST_RUN_ID');
    SELECT last_insert_rowid();")

  # Insert processed_note without specifying classification
  sqlite3 "$DB_PATH" "INSERT INTO processed_notes (raw_note_id) VALUES ($raw_id);"

  # Check that classification defaults to 'archive_only'
  local classification=$(sqlite3 "$DB_PATH" "SELECT classification FROM processed_notes WHERE raw_note_id = $raw_id;")

  # Cleanup
  sqlite3 "$DB_PATH" "DELETE FROM processed_notes WHERE raw_note_id = $raw_id;"
  sqlite3 "$DB_PATH" "DELETE FROM raw_notes WHERE id = $raw_id;"

  [ "$classification" = "archive_only" ]
}

assert_classification_accepts_actionable() {
  local raw_id=$(sqlite3 "$DB_PATH" "INSERT INTO raw_notes (title, content, content_hash, source_type, created_at, test_run)
    VALUES ('Test', 'Test content', 'hash-class-action-$TEST_RUN_ID', 'test', datetime('now'), '$TEST_RUN_ID');
    SELECT last_insert_rowid();")

  sqlite3 "$DB_PATH" "INSERT INTO processed_notes (raw_note_id, classification) VALUES ($raw_id, 'actionable');"
  local result=$?

  # Cleanup
  sqlite3 "$DB_PATH" "DELETE FROM processed_notes WHERE raw_note_id = $raw_id;"
  sqlite3 "$DB_PATH" "DELETE FROM raw_notes WHERE id = $raw_id;"

  [ $result -eq 0 ]
}

assert_classification_accepts_needs_planning() {
  local raw_id=$(sqlite3 "$DB_PATH" "INSERT INTO raw_notes (title, content, content_hash, source_type, created_at, test_run)
    VALUES ('Test', 'Test content', 'hash-class-plan-$TEST_RUN_ID', 'test', datetime('now'), '$TEST_RUN_ID');
    SELECT last_insert_rowid();")

  sqlite3 "$DB_PATH" "INSERT INTO processed_notes (raw_note_id, classification) VALUES ($raw_id, 'needs_planning');"
  local result=$?

  # Cleanup
  sqlite3 "$DB_PATH" "DELETE FROM processed_notes WHERE raw_note_id = $raw_id;"
  sqlite3 "$DB_PATH" "DELETE FROM raw_notes WHERE id = $raw_id;"

  [ $result -eq 0 ]
}

assert_classification_rejects_invalid() {
  local raw_id=$(sqlite3 "$DB_PATH" "INSERT INTO raw_notes (title, content, content_hash, source_type, created_at, test_run)
    VALUES ('Test', 'Test content', 'hash-class-invalid-$TEST_RUN_ID', 'test', datetime('now'), '$TEST_RUN_ID');
    SELECT last_insert_rowid();")

  # Try to insert invalid classification (should fail)
  if sqlite3 "$DB_PATH" "INSERT INTO processed_notes (raw_note_id, classification) VALUES ($raw_id, 'invalid_value');" 2>&1 | grep -qi "constraint"; then
    # Cleanup
    sqlite3 "$DB_PATH" "DELETE FROM raw_notes WHERE id = $raw_id;"
    return 0
  else
    # Cleanup
    sqlite3 "$DB_PATH" "DELETE FROM processed_notes WHERE raw_note_id = $raw_id;"
    sqlite3 "$DB_PATH" "DELETE FROM raw_notes WHERE id = $raw_id;"
    return 1
  fi
}

# =============================================================================
# TEST ASSERTIONS: processed_notes.planning_status
# =============================================================================

assert_planning_status_column_exists() {
  sqlite3 "$DB_PATH" "PRAGMA table_info(processed_notes);" | grep -q "planning_status"
}

assert_planning_status_allows_null() {
  local raw_id=$(sqlite3 "$DB_PATH" "INSERT INTO raw_notes (title, content, content_hash, source_type, created_at, test_run)
    VALUES ('Test', 'Test content', 'hash-plan-null-$TEST_RUN_ID', 'test', datetime('now'), '$TEST_RUN_ID');
    SELECT last_insert_rowid();")

  sqlite3 "$DB_PATH" "INSERT INTO processed_notes (raw_note_id, planning_status) VALUES ($raw_id, NULL);"
  local result=$?

  # Cleanup
  sqlite3 "$DB_PATH" "DELETE FROM processed_notes WHERE raw_note_id = $raw_id;"
  sqlite3 "$DB_PATH" "DELETE FROM raw_notes WHERE id = $raw_id;"

  [ $result -eq 0 ]
}

assert_planning_status_accepts_pending_review() {
  local raw_id=$(sqlite3 "$DB_PATH" "INSERT INTO raw_notes (title, content, content_hash, source_type, created_at, test_run)
    VALUES ('Test', 'Test content', 'hash-plan-pending-$TEST_RUN_ID', 'test', datetime('now'), '$TEST_RUN_ID');
    SELECT last_insert_rowid();")

  sqlite3 "$DB_PATH" "INSERT INTO processed_notes (raw_note_id, planning_status) VALUES ($raw_id, 'pending_review');"
  local result=$?

  # Cleanup
  sqlite3 "$DB_PATH" "DELETE FROM processed_notes WHERE raw_note_id = $raw_id;"
  sqlite3 "$DB_PATH" "DELETE FROM raw_notes WHERE id = $raw_id;"

  [ $result -eq 0 ]
}

assert_planning_status_accepts_in_planning() {
  local raw_id=$(sqlite3 "$DB_PATH" "INSERT INTO raw_notes (title, content, content_hash, source_type, created_at, test_run)
    VALUES ('Test', 'Test content', 'hash-plan-in-$TEST_RUN_ID', 'test', datetime('now'), '$TEST_RUN_ID');
    SELECT last_insert_rowid();")

  sqlite3 "$DB_PATH" "INSERT INTO processed_notes (raw_note_id, planning_status) VALUES ($raw_id, 'in_planning');"
  local result=$?

  # Cleanup
  sqlite3 "$DB_PATH" "DELETE FROM processed_notes WHERE raw_note_id = $raw_id;"
  sqlite3 "$DB_PATH" "DELETE FROM raw_notes WHERE id = $raw_id;"

  [ $result -eq 0 ]
}

assert_planning_status_accepts_planned() {
  local raw_id=$(sqlite3 "$DB_PATH" "INSERT INTO raw_notes (title, content, content_hash, source_type, created_at, test_run)
    VALUES ('Test', 'Test content', 'hash-plan-planned-$TEST_RUN_ID', 'test', datetime('now'), '$TEST_RUN_ID');
    SELECT last_insert_rowid();")

  sqlite3 "$DB_PATH" "INSERT INTO processed_notes (raw_note_id, planning_status) VALUES ($raw_id, 'planned');"
  local result=$?

  # Cleanup
  sqlite3 "$DB_PATH" "DELETE FROM processed_notes WHERE raw_note_id = $raw_id;"
  sqlite3 "$DB_PATH" "DELETE FROM raw_notes WHERE id = $raw_id;"

  [ $result -eq 0 ]
}

assert_planning_status_accepts_archived() {
  local raw_id=$(sqlite3 "$DB_PATH" "INSERT INTO raw_notes (title, content, content_hash, source_type, created_at, test_run)
    VALUES ('Test', 'Test content', 'hash-plan-archived-$TEST_RUN_ID', 'test', datetime('now'), '$TEST_RUN_ID');
    SELECT last_insert_rowid();")

  sqlite3 "$DB_PATH" "INSERT INTO processed_notes (raw_note_id, planning_status) VALUES ($raw_id, 'archived');"
  local result=$?

  # Cleanup
  sqlite3 "$DB_PATH" "DELETE FROM processed_notes WHERE raw_note_id = $raw_id;"
  sqlite3 "$DB_PATH" "DELETE FROM raw_notes WHERE id = $raw_id;"

  [ $result -eq 0 ]
}

assert_planning_status_rejects_invalid() {
  local raw_id=$(sqlite3 "$DB_PATH" "INSERT INTO raw_notes (title, content, content_hash, source_type, created_at, test_run)
    VALUES ('Test', 'Test content', 'hash-plan-invalid-$TEST_RUN_ID', 'test', datetime('now'), '$TEST_RUN_ID');
    SELECT last_insert_rowid();")

  # Try to insert invalid planning_status (should fail)
  if sqlite3 "$DB_PATH" "INSERT INTO processed_notes (raw_note_id, planning_status) VALUES ($raw_id, 'invalid_status');" 2>&1 | grep -qi "constraint"; then
    # Cleanup
    sqlite3 "$DB_PATH" "DELETE FROM raw_notes WHERE id = $raw_id;"
    return 0
  else
    # Cleanup
    sqlite3 "$DB_PATH" "DELETE FROM processed_notes WHERE raw_note_id = $raw_id;"
    sqlite3 "$DB_PATH" "DELETE FROM raw_notes WHERE id = $raw_id;"
    return 1
  fi
}

# =============================================================================
# TEST ASSERTIONS: discussion_threads table
# =============================================================================

assert_discussion_threads_table_exists() {
  sqlite3 "$DB_PATH" "SELECT name FROM sqlite_master WHERE type='table' AND name='discussion_threads';" | grep -q "discussion_threads"
}

assert_discussion_threads_has_id() {
  sqlite3 "$DB_PATH" "PRAGMA table_info(discussion_threads);" | grep -q "id"
}

assert_discussion_threads_has_raw_note_id() {
  sqlite3 "$DB_PATH" "PRAGMA table_info(discussion_threads);" | grep -q "raw_note_id"
}

assert_discussion_threads_has_thread_type() {
  sqlite3 "$DB_PATH" "PRAGMA table_info(discussion_threads);" | grep -q "thread_type"
}

assert_discussion_threads_has_prompt() {
  sqlite3 "$DB_PATH" "PRAGMA table_info(discussion_threads);" | grep -q "prompt"
}

assert_discussion_threads_has_status() {
  sqlite3 "$DB_PATH" "PRAGMA table_info(discussion_threads);" | grep -q "status"
}

assert_discussion_threads_has_created_at() {
  sqlite3 "$DB_PATH" "PRAGMA table_info(discussion_threads);" | grep -q "created_at"
}

assert_discussion_threads_has_surfaced_at() {
  sqlite3 "$DB_PATH" "PRAGMA table_info(discussion_threads);" | grep -q "surfaced_at"
}

assert_discussion_threads_has_completed_at() {
  sqlite3 "$DB_PATH" "PRAGMA table_info(discussion_threads);" | grep -q "completed_at"
}

assert_discussion_threads_has_related_concepts() {
  sqlite3 "$DB_PATH" "PRAGMA table_info(discussion_threads);" | grep -q "related_concepts"
}

assert_discussion_threads_has_test_run() {
  sqlite3 "$DB_PATH" "PRAGMA table_info(discussion_threads);" | grep -q "test_run"
}

assert_discussion_threads_can_insert() {
  # Create test raw_note first
  local raw_id=$(sqlite3 "$DB_PATH" "INSERT INTO raw_notes (title, content, content_hash, source_type, created_at, test_run)
    VALUES ('Test', 'Test content', 'hash-thread-insert-$TEST_RUN_ID', 'test', datetime('now'), '$TEST_RUN_ID');
    SELECT last_insert_rowid();")

  sqlite3 "$DB_PATH" "INSERT INTO discussion_threads (raw_note_id, thread_type, prompt, status, test_run)
    VALUES ($raw_id, 'planning', 'What would help you get started?', 'pending', '$TEST_RUN_ID');"
  local result=$?

  # Cleanup
  sqlite3 "$DB_PATH" "DELETE FROM discussion_threads WHERE test_run = '$TEST_RUN_ID';"
  sqlite3 "$DB_PATH" "DELETE FROM raw_notes WHERE id = $raw_id;"

  [ $result -eq 0 ]
}

assert_discussion_threads_thread_type_constraint() {
  local raw_id=$(sqlite3 "$DB_PATH" "INSERT INTO raw_notes (title, content, content_hash, source_type, created_at, test_run)
    VALUES ('Test', 'Test content', 'hash-thread-type-$TEST_RUN_ID', 'test', datetime('now'), '$TEST_RUN_ID');
    SELECT last_insert_rowid();")

  # Try to insert invalid thread_type (should fail)
  if sqlite3 "$DB_PATH" "INSERT INTO discussion_threads (raw_note_id, thread_type, prompt, test_run)
    VALUES ($raw_id, 'invalid_type', 'Test prompt', '$TEST_RUN_ID');" 2>&1 | grep -qi "constraint"; then
    # Cleanup
    sqlite3 "$DB_PATH" "DELETE FROM raw_notes WHERE id = $raw_id;"
    return 0
  else
    # Cleanup
    sqlite3 "$DB_PATH" "DELETE FROM discussion_threads WHERE test_run = '$TEST_RUN_ID';"
    sqlite3 "$DB_PATH" "DELETE FROM raw_notes WHERE id = $raw_id;"
    return 1
  fi
}

assert_discussion_threads_status_constraint() {
  local raw_id=$(sqlite3 "$DB_PATH" "INSERT INTO raw_notes (title, content, content_hash, source_type, created_at, test_run)
    VALUES ('Test', 'Test content', 'hash-thread-status-$TEST_RUN_ID', 'test', datetime('now'), '$TEST_RUN_ID');
    SELECT last_insert_rowid();")

  # Try to insert invalid status (should fail)
  if sqlite3 "$DB_PATH" "INSERT INTO discussion_threads (raw_note_id, thread_type, prompt, status, test_run)
    VALUES ($raw_id, 'planning', 'Test prompt', 'invalid_status', '$TEST_RUN_ID');" 2>&1 | grep -qi "constraint"; then
    # Cleanup
    sqlite3 "$DB_PATH" "DELETE FROM raw_notes WHERE id = $raw_id;"
    return 0
  else
    # Cleanup
    sqlite3 "$DB_PATH" "DELETE FROM discussion_threads WHERE test_run = '$TEST_RUN_ID';"
    sqlite3 "$DB_PATH" "DELETE FROM raw_notes WHERE id = $raw_id;"
    return 1
  fi
}

assert_discussion_threads_foreign_key() {
  # Try to insert thread with non-existent raw_note_id (should fail with FK enabled)
  if sqlite3 "$DB_PATH" "PRAGMA foreign_keys=ON; INSERT INTO discussion_threads (raw_note_id, thread_type, prompt, test_run)
    VALUES (999999, 'planning', 'Test prompt', '$TEST_RUN_ID');" 2>&1 | grep -qi -E "FOREIGN KEY|constraint"; then
    return 0
  else
    # Cleanup if it somehow succeeded
    sqlite3 "$DB_PATH" "DELETE FROM discussion_threads WHERE test_run = '$TEST_RUN_ID';"
    return 1
  fi
}

# =============================================================================
# TEST ASSERTIONS: Indexes
# =============================================================================

assert_classification_index_exists() {
  sqlite3 "$DB_PATH" "SELECT name FROM sqlite_master WHERE type='index' AND name='idx_processed_notes_classification';" | grep -q "idx_processed_notes_classification"
}

assert_planning_status_index_exists() {
  sqlite3 "$DB_PATH" "SELECT name FROM sqlite_master WHERE type='index' AND name='idx_processed_notes_planning_status';" | grep -q "idx_processed_notes_planning_status"
}

assert_discussion_threads_status_index_exists() {
  sqlite3 "$DB_PATH" "SELECT name FROM sqlite_master WHERE type='index' AND name='idx_discussion_threads_status';" | grep -q "idx_discussion_threads_status"
}

assert_discussion_threads_raw_note_index_exists() {
  sqlite3 "$DB_PATH" "SELECT name FROM sqlite_master WHERE type='index' AND name='idx_discussion_threads_raw_note_id';" | grep -q "idx_discussion_threads_raw_note_id"
}

assert_discussion_threads_test_run_index_exists() {
  sqlite3 "$DB_PATH" "SELECT name FROM sqlite_master WHERE type='index' AND name='idx_discussion_threads_test_run';" | grep -q "idx_discussion_threads_test_run"
}

# =============================================================================
# MAIN TEST RUNNER
# =============================================================================

# Header
echo -e "${BLUE}===============================================================================${NC}"
echo -e "${BLUE}  Migration 008: Classification Fields - Test Suite${NC}"
echo -e "${BLUE}===============================================================================${NC}"
echo -e "${YELLOW}Test Run ID: $TEST_RUN_ID${NC}"
echo -e "${YELLOW}Database: $DB_PATH${NC}"
echo ""

# Verify database exists
if [ ! -f "$DB_PATH" ]; then
  echo -e "${RED}ERROR: Database not found at $DB_PATH${NC}"
  exit 1
fi

# processed_notes.classification tests
echo -e "${BLUE}--- processed_notes.classification Column ---${NC}"
run_test "classification column exists" assert_classification_column_exists
run_test "classification defaults to 'archive_only'" assert_classification_default_archive_only
run_test "classification accepts 'actionable'" assert_classification_accepts_actionable
run_test "classification accepts 'needs_planning'" assert_classification_accepts_needs_planning
run_test "classification rejects invalid values" assert_classification_rejects_invalid
echo ""

# processed_notes.planning_status tests
echo -e "${BLUE}--- processed_notes.planning_status Column ---${NC}"
run_test "planning_status column exists" assert_planning_status_column_exists
run_test "planning_status allows NULL" assert_planning_status_allows_null
run_test "planning_status accepts 'pending_review'" assert_planning_status_accepts_pending_review
run_test "planning_status accepts 'in_planning'" assert_planning_status_accepts_in_planning
run_test "planning_status accepts 'planned'" assert_planning_status_accepts_planned
run_test "planning_status accepts 'archived'" assert_planning_status_accepts_archived
run_test "planning_status rejects invalid values" assert_planning_status_rejects_invalid
echo ""

# discussion_threads table tests
echo -e "${BLUE}--- discussion_threads Table ---${NC}"
run_test "discussion_threads table exists" assert_discussion_threads_table_exists
run_test "column: id" assert_discussion_threads_has_id
run_test "column: raw_note_id" assert_discussion_threads_has_raw_note_id
run_test "column: thread_type" assert_discussion_threads_has_thread_type
run_test "column: prompt" assert_discussion_threads_has_prompt
run_test "column: status" assert_discussion_threads_has_status
run_test "column: created_at" assert_discussion_threads_has_created_at
run_test "column: surfaced_at" assert_discussion_threads_has_surfaced_at
run_test "column: completed_at" assert_discussion_threads_has_completed_at
run_test "column: related_concepts" assert_discussion_threads_has_related_concepts
run_test "column: test_run" assert_discussion_threads_has_test_run
run_test "can insert valid record" assert_discussion_threads_can_insert
run_test "thread_type constraint (planning/followup/question)" assert_discussion_threads_thread_type_constraint
run_test "status constraint (pending/active/completed/dismissed)" assert_discussion_threads_status_constraint
run_test "foreign key to raw_notes" assert_discussion_threads_foreign_key
echo ""

# Index tests
echo -e "${BLUE}--- Indexes ---${NC}"
run_test "idx_processed_notes_classification exists" assert_classification_index_exists
run_test "idx_processed_notes_planning_status exists" assert_planning_status_index_exists
run_test "idx_discussion_threads_status exists" assert_discussion_threads_status_index_exists
run_test "idx_discussion_threads_raw_note_id exists" assert_discussion_threads_raw_note_index_exists
run_test "idx_discussion_threads_test_run exists" assert_discussion_threads_test_run_index_exists
echo ""

# Summary
echo -e "${BLUE}===============================================================================${NC}"
echo -e "${BLUE}  Test Summary${NC}"
echo -e "${BLUE}===============================================================================${NC}"
echo -e "${GREEN}Passed: $PASSED${NC}"
echo -e "${RED}Failed: $FAILED${NC}"
echo "Total: $((PASSED + FAILED))"
echo ""

if [ $FAILED -eq 0 ]; then
  echo -e "${GREEN}ALL TESTS PASSED - Migration 008 is complete!${NC}"
  exit 0
else
  echo -e "${YELLOW}TESTS FAILING - Expected for RED phase of TDD${NC}"
  echo -e "${YELLOW}Next step: Create 008_classification_fields.sql to make tests pass${NC}"
  exit 1
fi
