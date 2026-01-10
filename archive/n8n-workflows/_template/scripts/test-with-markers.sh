#!/bin/bash
set -e

cd "$(dirname "$0")/.."

# ============================================================================
# CUSTOMIZE FOR YOUR WORKFLOW:
# 1. Update WEBHOOK_PATH to your endpoint
# 2. Update TABLE_NAME to the table this workflow writes to
# 3. Add test cases specific to your workflow
# ============================================================================

TEST_RUN="test-run-$(date +%Y%m%d-%H%M%S)"
WEBHOOK_URL="http://localhost:5678/webhook/api/ENDPOINT-NAME"
DB_PATH="../../data/selene.db"
TABLE_NAME="raw_notes"  # Change to your table

echo "================================================"
echo "Testing XX-workflow-name"
echo "Test marker: $TEST_RUN"
echo "================================================"

# Test 1: Basic success case
echo ""
echo "Test 1: Normal operation"
curl -s -X POST "$WEBHOOK_URL" \
  -H "Content-Type: application/json" \
  -d "{
    \"test_field\": \"test value\",
    \"test_run\": \"$TEST_RUN\",
    \"use_test_db\": true
  }"

sleep 2

# Verify
COUNT=$(sqlite3 "$DB_PATH" "SELECT COUNT(*) FROM $TABLE_NAME WHERE test_run = '$TEST_RUN';")
echo "Records created: $COUNT"

# Results
echo ""
echo "================================================"
echo "Test complete. Marker: $TEST_RUN"
echo "Cleanup: ../../scripts/cleanup-tests.sh $TEST_RUN"
echo "================================================"
