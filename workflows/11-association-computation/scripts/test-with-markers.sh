#!/bin/bash
#
# test-with-markers.sh
# Test workflow 11-association-computation with cleanup markers
#

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
WORKFLOW_DIR="$(dirname "$SCRIPT_DIR")"
PROJECT_ROOT="$(cd "$WORKFLOW_DIR/../.." && pwd)"

# Configuration
WEBHOOK_URL="${WEBHOOK_URL:-http://localhost:5678/webhook/api/associate}"
DB_PATH="${SELENE_DB_PATH:-$PROJECT_ROOT/data/selene.db}"
TEST_RUN="test-run-$(date +%Y%m%d-%H%M%S)"

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
NC='\033[0m'

log_info() { echo -e "${GREEN}[INFO]${NC} $1"; }
log_warn() { echo -e "${YELLOW}[WARN]${NC} $1"; }
log_error() { echo -e "${RED}[ERROR]${NC} $1"; }
log_test() { echo -e "${YELLOW}[TEST]${NC} $1"; }

echo "=== Workflow 11: Association Computation Tests ==="
echo "Test Run: $TEST_RUN"
echo "Database: $DB_PATH"
echo ""

# Pre-flight checks
if [[ ! -f "$DB_PATH" ]]; then
  log_error "Database not found: $DB_PATH"
  exit 1
fi

if ! curl -s --max-time 5 "http://localhost:5678/healthz" > /dev/null 2>&1; then
  log_error "n8n not reachable"
  exit 1
fi

# Get a note with embedding for testing
TEST_NOTE_ID=$(sqlite3 "$DB_PATH" "SELECT raw_note_id FROM note_embeddings LIMIT 1" 2>/dev/null || echo "")
if [[ -z "$TEST_NOTE_ID" ]]; then
  log_error "No notes with embeddings found. Run embedding workflow first."
  exit 1
fi

log_info "Using test note ID: $TEST_NOTE_ID"
echo ""

# Track test results
PASSED=0
FAILED=0

run_test() {
  local name="$1"
  local expected="$2"
  local actual="$3"

  if [[ "$actual" == *"$expected"* ]]; then
    log_info "PASS: $name"
    PASSED=$((PASSED + 1))
  else
    log_error "FAIL: $name (expected '$expected', got '$actual')"
    FAILED=$((FAILED + 1))
  fi
}

# Test 1: Single note association
log_test "Test 1: Single note association"
RESPONSE=$(curl -s -X POST "$WEBHOOK_URL" \
  -H "Content-Type: application/json" \
  -d "{\"note_id\": $TEST_NOTE_ID, \"test_run\": \"$TEST_RUN\"}")

run_test "Returns success" "success" "$RESPONSE"
echo "Response: $RESPONSE"
echo ""

# Test 2: Note without embedding (use non-existent ID)
log_test "Test 2: Note without embedding"
RESPONSE=$(curl -s -X POST "$WEBHOOK_URL" \
  -H "Content-Type: application/json" \
  -d '{"note_id": 999999, "test_run": "'"$TEST_RUN"'"}')

run_test "Skips gracefully" "skipped" "$RESPONSE"
echo "Response: $RESPONSE"
echo ""

# Test 3: Verify associations stored
log_test "Test 3: Verify associations in database"
ASSOC_COUNT=$(sqlite3 "$DB_PATH" "SELECT COUNT(*) FROM note_associations WHERE note_a_id = $TEST_NOTE_ID OR note_b_id = $TEST_NOTE_ID" 2>/dev/null || echo "0")
log_info "Associations for note $TEST_NOTE_ID: $ASSOC_COUNT"

if [[ "$ASSOC_COUNT" -gt 0 ]]; then
  log_info "PASS: Associations stored"
  PASSED=$((PASSED + 1))
else
  log_warn "No associations found (may be normal if no similar notes)"
fi

# Test 4: Verify similarity scores are valid
log_test "Test 4: Verify similarity scores"
INVALID_SCORES=$(sqlite3 "$DB_PATH" "SELECT COUNT(*) FROM note_associations WHERE similarity_score < 0 OR similarity_score > 1")
if [[ "$INVALID_SCORES" -eq 0 ]]; then
  log_info "PASS: All similarity scores in valid range [0,1]"
  PASSED=$((PASSED + 1))
else
  log_error "FAIL: Found $INVALID_SCORES invalid scores"
  FAILED=$((FAILED + 1))
fi
echo ""

# Test 5: Check storage convention (note_a_id < note_b_id)
log_test "Test 5: Storage convention (note_a_id < note_b_id)"
BAD_ORDER=$(sqlite3 "$DB_PATH" "SELECT COUNT(*) FROM note_associations WHERE note_a_id >= note_b_id")
if [[ "$BAD_ORDER" -eq 0 ]]; then
  log_info "PASS: All associations follow note_a_id < note_b_id convention"
  PASSED=$((PASSED + 1))
else
  log_error "FAIL: Found $BAD_ORDER associations with bad ordering"
  FAILED=$((FAILED + 1))
fi
echo ""

# Summary
echo "=== Test Summary ==="
echo "Passed: $PASSED"
echo "Failed: $FAILED"
echo ""

# Show sample associations
log_info "Sample associations:"
sqlite3 -header -column "$DB_PATH" "
  SELECT note_a_id, note_b_id, ROUND(similarity_score, 4) as similarity
  FROM note_associations
  ORDER BY similarity_score DESC
  LIMIT 5
"

echo ""

# Cleanup prompt
read -p "Cleanup test data? (y/n) " -n 1 -r
echo ""
if [[ $REPLY =~ ^[Yy]$ ]]; then
  log_info "Note: Association computation doesn't use test_run markers for storage."
  log_info "Associations are permanent (by design)."
fi

# Exit with appropriate code
if [[ "$FAILED" -gt 0 ]]; then
  exit 1
fi
