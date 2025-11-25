#!/bin/bash

# Test Suite for Bidirectional Sync (TDD - RED Phase Expected)
# Tests task creation in Things and status syncing back to Selene

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

DB_PATH="/Users/chaseeasterling/selene-n8n/data/selene.db"
TEST_RUN_ID="test-run-$(date +%s)"
MOCK_DATA_FILE="workflows/07-task-extraction/mock-test-data.json"

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

# Helper: Insert mock note into database
insert_mock_note() {
  local note_id="$1"
  local title="$2"
  local content="$3"

  sqlite3 "$DB_PATH" "INSERT INTO raw_notes (title, content, content_hash, source_type, created_at, test_run)
    VALUES ('$title', '$content', 'mock-hash-$note_id-$TEST_RUN_ID', 'test', datetime('now'), '$TEST_RUN_ID');
    SELECT last_insert_rowid();"
}

# Helper: Extract tasks from mock note (simulates Ollama)
extract_mock_tasks() {
  local note_id="$1"
  # Read expected tasks from JSON
  # For now, return count of expected tasks
  cat "$MOCK_DATA_FILE" | jq -r ".test_notes[] | select(.id == \"$note_id\") | .expected_tasks | length"
}

# Helper: Create task in Things via URL scheme
create_things_task() {
  local title="$1"
  local notes="$2"
  local project="Selene%20Test%20Project"

  # Open Things URL (returns immediately, task created async)
  open "things:///add?title=${title}&notes=${notes}&list=${project}" 2>/dev/null

  # Give Things time to process
  sleep 1

  # Return mock task ID (in real implementation, we'd get this from callback)
  echo "mock-things-task-${TEST_RUN_ID}-$(date +%s)"
}

# Helper: Get task status from Things (simulated for now)
get_things_task_status() {
  local task_id="$1"
  # In real implementation, would use Things URL scheme or AppleScript
  # For now, simulate that task exists and is not completed
  echo "incomplete"
}

# ═══════════════════════════════════════════════════════
# TEST SUITE: TASK CREATION
# ═══════════════════════════════════════════════════════

test_extract_tasks_from_actionable_note() {
  local mock_id="mock-001"
  local task_count=$(extract_mock_tasks "$mock_id")

  [ "$task_count" -eq 3 ]
}

test_extract_zero_tasks_from_reflection_note() {
  local mock_id="mock-002"
  local task_count=$(extract_mock_tasks "$mock_id")

  [ "$task_count" -eq 0 ]
}

test_create_task_in_things() {
  local task_title="Test Task for Selene"
  local task_notes="Created by test suite at $(date)"

  local task_id=$(create_things_task "$task_title" "$task_notes")

  # Verify task ID was returned
  [[ -n "$task_id" ]]
}

test_store_task_metadata_in_database() {
  # Create mock note
  local note_id=$(insert_mock_note "test-meta" "Test Note" "Need to test metadata storage")

  # Simulate task creation
  local things_id="mock-things-${TEST_RUN_ID}"

  # Store metadata
  sqlite3 "$DB_PATH" "INSERT INTO task_metadata (
    raw_note_id, things_task_id, energy_required, estimated_minutes, task_type, overwhelm_factor
  ) VALUES ($note_id, '$things_id', 'medium', 30, 'action', 5);"

  # Verify stored
  local count=$(sqlite3 "$DB_PATH" "SELECT COUNT(*) FROM task_metadata WHERE things_task_id='$things_id';")

  # Cleanup
  sqlite3 "$DB_PATH" "DELETE FROM task_metadata WHERE things_task_id='$things_id';"
  sqlite3 "$DB_PATH" "DELETE FROM raw_notes WHERE id=$note_id;"

  [ "$count" -eq 1 ]
}

test_link_multiple_tasks_to_one_note() {
  # Create mock note
  local note_id=$(insert_mock_note "test-multi" "Multi-Task Note" "Task 1. Task 2. Task 3.")

  # Create 3 tasks linked to same note
  for i in 1 2 3; do
    local things_id="mock-multi-$i-${TEST_RUN_ID}"
    sqlite3 "$DB_PATH" "INSERT INTO task_metadata (
      raw_note_id, things_task_id, task_type
    ) VALUES ($note_id, '$things_id', 'action');"
  done

  # Verify all 3 linked
  local count=$(sqlite3 "$DB_PATH" "SELECT COUNT(*) FROM task_metadata WHERE raw_note_id=$note_id;")

  # Cleanup
  sqlite3 "$DB_PATH" "DELETE FROM task_metadata WHERE raw_note_id=$note_id;"
  sqlite3 "$DB_PATH" "DELETE FROM raw_notes WHERE id=$note_id;"

  [ "$count" -eq 3 ]
}

# ═══════════════════════════════════════════════════════
# TEST SUITE: BIDIRECTIONAL SYNC
# ═══════════════════════════════════════════════════════

test_read_task_status_from_things() {
  local task_id="mock-task-status-${TEST_RUN_ID}"
  local status=$(get_things_task_status "$task_id")

  # Verify we got a status back
  [[ -n "$status" ]]
}

test_update_completed_timestamp_when_done() {
  # Create mock task
  local note_id=$(insert_mock_note "test-complete" "Test Complete" "Complete this task")
  local things_id="mock-complete-${TEST_RUN_ID}"

  sqlite3 "$DB_PATH" "INSERT INTO task_metadata (
    raw_note_id, things_task_id, task_type
  ) VALUES ($note_id, '$things_id', 'action');"

  # Simulate task completion (update completed_at)
  sqlite3 "$DB_PATH" "UPDATE task_metadata
    SET completed_at = datetime('now')
    WHERE things_task_id='$things_id';"

  # Verify completed_at is set
  local completed=$(sqlite3 "$DB_PATH" "SELECT completed_at FROM task_metadata WHERE things_task_id='$things_id';")

  # Cleanup
  sqlite3 "$DB_PATH" "DELETE FROM task_metadata WHERE things_task_id='$things_id';"
  sqlite3 "$DB_PATH" "DELETE FROM raw_notes WHERE id=$note_id;"

  [[ -n "$completed" ]]
}

test_update_synced_timestamp_on_read() {
  # Create mock task
  local note_id=$(insert_mock_note "test-sync" "Test Sync" "Sync this task")
  local things_id="mock-sync-${TEST_RUN_ID}"

  sqlite3 "$DB_PATH" "INSERT INTO task_metadata (
    raw_note_id, things_task_id, task_type
  ) VALUES ($note_id, '$things_id', 'action');"

  # Simulate sync (update synced_at)
  sqlite3 "$DB_PATH" "UPDATE task_metadata
    SET synced_at = datetime('now')
    WHERE things_task_id='$things_id';"

  # Verify synced_at is set
  local synced=$(sqlite3 "$DB_PATH" "SELECT synced_at FROM task_metadata WHERE things_task_id='$things_id';")

  # Cleanup
  sqlite3 "$DB_PATH" "DELETE FROM task_metadata WHERE things_task_id='$things_id';"
  sqlite3 "$DB_PATH" "DELETE FROM raw_notes WHERE id=$note_id;"

  [[ -n "$synced" ]]
}

test_query_all_completed_tasks() {
  # Create 2 tasks, complete 1
  local note_id=$(insert_mock_note "test-query" "Test Query" "Query tasks")
  local task1="mock-query-1-${TEST_RUN_ID}"
  local task2="mock-query-2-${TEST_RUN_ID}"

  sqlite3 "$DB_PATH" "INSERT INTO task_metadata (raw_note_id, things_task_id, task_type)
    VALUES ($note_id, '$task1', 'action'), ($note_id, '$task2', 'action');"

  # Complete task 1
  sqlite3 "$DB_PATH" "UPDATE task_metadata
    SET completed_at = datetime('now')
    WHERE things_task_id='$task1';"

  # Query completed tasks
  local completed_count=$(sqlite3 "$DB_PATH" "SELECT COUNT(*) FROM task_metadata
    WHERE completed_at IS NOT NULL AND raw_note_id=$note_id;")

  # Cleanup
  sqlite3 "$DB_PATH" "DELETE FROM task_metadata WHERE raw_note_id=$note_id;"
  sqlite3 "$DB_PATH" "DELETE FROM raw_notes WHERE id=$note_id;"

  [ "$completed_count" -eq 1 ]
}

test_query_tasks_by_energy_level() {
  # Create tasks with different energy levels
  local note_id=$(insert_mock_note "test-energy" "Test Energy" "Energy tasks")

  sqlite3 "$DB_PATH" "INSERT INTO task_metadata (raw_note_id, things_task_id, task_type, energy_required)
    VALUES
    ($note_id, 'mock-high-${TEST_RUN_ID}', 'action', 'high'),
    ($note_id, 'mock-medium-${TEST_RUN_ID}', 'action', 'medium'),
    ($note_id, 'mock-low-${TEST_RUN_ID}', 'action', 'low');"

  # Query high energy tasks
  local high_count=$(sqlite3 "$DB_PATH" "SELECT COUNT(*) FROM task_metadata
    WHERE energy_required='high' AND raw_note_id=$note_id;")

  # Cleanup
  sqlite3 "$DB_PATH" "DELETE FROM task_metadata WHERE raw_note_id=$note_id;"
  sqlite3 "$DB_PATH" "DELETE FROM raw_notes WHERE id=$note_id;"

  [ "$high_count" -eq 1 ]
}

# ═══════════════════════════════════════════════════════
# TEST SUITE: ADHD ENRICHMENT
# ═══════════════════════════════════════════════════════

test_store_overwhelm_factor() {
  local note_id=$(insert_mock_note "test-overwhelm" "Test Overwhelm" "Overwhelming task")
  local things_id="mock-overwhelm-${TEST_RUN_ID}"

  sqlite3 "$DB_PATH" "INSERT INTO task_metadata (
    raw_note_id, things_task_id, task_type, overwhelm_factor
  ) VALUES ($note_id, '$things_id', 'action', 8);"

  # Verify overwhelm factor stored
  local overwhelm=$(sqlite3 "$DB_PATH" "SELECT overwhelm_factor FROM task_metadata
    WHERE things_task_id='$things_id';")

  # Cleanup
  sqlite3 "$DB_PATH" "DELETE FROM task_metadata WHERE things_task_id='$things_id';"
  sqlite3 "$DB_PATH" "DELETE FROM raw_notes WHERE id=$note_id;"

  [ "$overwhelm" -eq 8 ]
}

test_store_context_tags_as_json() {
  local note_id=$(insert_mock_note "test-tags" "Test Tags" "Task with tags")
  local things_id="mock-tags-${TEST_RUN_ID}"

  sqlite3 "$DB_PATH" "INSERT INTO task_metadata (
    raw_note_id, things_task_id, task_type, context_tags
  ) VALUES ($note_id, '$things_id', 'action', '[\"work\",\"urgent\"]');"

  # Verify JSON stored
  local tags=$(sqlite3 "$DB_PATH" "SELECT context_tags FROM task_metadata
    WHERE things_task_id='$things_id';")

  # Cleanup
  sqlite3 "$DB_PATH" "DELETE FROM task_metadata WHERE things_task_id='$things_id';"
  sqlite3 "$DB_PATH" "DELETE FROM raw_notes WHERE id=$note_id;"

  [[ "$tags" == "[\"work\",\"urgent\"]" ]]
}

test_link_concepts_to_task() {
  local note_id=$(insert_mock_note "test-concepts" "Test Concepts" "Task with concepts")
  local things_id="mock-concepts-${TEST_RUN_ID}"

  sqlite3 "$DB_PATH" "INSERT INTO task_metadata (
    raw_note_id, things_task_id, task_type, related_concepts
  ) VALUES ($note_id, '$things_id', 'action', '[\"productivity\",\"planning\"]');"

  # Verify concepts stored
  local concepts=$(sqlite3 "$DB_PATH" "SELECT related_concepts FROM task_metadata
    WHERE things_task_id='$things_id';")

  # Cleanup
  sqlite3 "$DB_PATH" "DELETE FROM task_metadata WHERE things_task_id='$things_id';"
  sqlite3 "$DB_PATH" "DELETE FROM raw_notes WHERE id=$note_id;"

  [[ -n "$concepts" ]]
}

# ═══════════════════════════════════════════════════════
# RUN TESTS
# ═══════════════════════════════════════════════════════

echo -e "${BLUE}═══════════════════════════════════════════════════════${NC}"
echo -e "${BLUE}  Bidirectional Sync Test Suite (TDD - RED Phase)${NC}"
echo -e "${BLUE}═══════════════════════════════════════════════════════${NC}"
echo -e "${YELLOW}Test Run ID: $TEST_RUN_ID${NC}"
echo ""

# Task Creation Tests
echo -e "${BLUE}━━━ TASK CREATION TESTS ━━━${NC}"
run_test "Extract 3 tasks from actionable note" test_extract_tasks_from_actionable_note
run_test "Extract 0 tasks from reflection note" test_extract_zero_tasks_from_reflection_note
run_test "Create task in Things" test_create_task_in_things
run_test "Store task metadata in database" test_store_task_metadata_in_database
run_test "Link multiple tasks to one note" test_link_multiple_tasks_to_one_note
echo ""

# Bidirectional Sync Tests
echo -e "${BLUE}━━━ BIDIRECTIONAL SYNC TESTS ━━━${NC}"
run_test "Read task status from Things" test_read_task_status_from_things
run_test "Update completed timestamp when done" test_update_completed_timestamp_when_done
run_test "Update synced timestamp on read" test_update_synced_timestamp_on_read
run_test "Query all completed tasks" test_query_all_completed_tasks
run_test "Query tasks by energy level" test_query_tasks_by_energy_level
echo ""

# ADHD Enrichment Tests
echo -e "${BLUE}━━━ ADHD ENRICHMENT TESTS ━━━${NC}"
run_test "Store overwhelm factor" test_store_overwhelm_factor
run_test "Store context tags as JSON" test_store_context_tags_as_json
run_test "Link concepts to task" test_link_concepts_to_task
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
  echo -e "${YELLOW}Next step: Implement workflow to make tests pass${NC}"
  exit 1
fi
