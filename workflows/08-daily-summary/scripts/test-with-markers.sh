#!/bin/bash
set -e

cd "$(dirname "$0")/.."

# This workflow is schedule-triggered, so we test by:
# 1. Inserting test data into raw_notes
# 2. Manually triggering the workflow via n8n API
# 3. Checking the output file

TEST_RUN="test-run-$(date +%Y%m%d-%H%M%S)"
DB_PATH="../../data/selene.db"
OBSIDIAN_PATH="../../vault"

echo "========================================"
echo "Testing 08-daily-summary workflow"
echo "Test marker: $TEST_RUN"
echo "========================================"

# Test 1: Insert test note data
echo ""
echo "Test 1: Inserting test note data..."
sqlite3 "$DB_PATH" "INSERT INTO raw_notes (title, content, content_hash, created_at, test_run, status) VALUES ('Test Summary Note', 'This is a test note for the daily summary workflow. #testing #summary', 'test-hash-$TEST_RUN', datetime('now'), '$TEST_RUN', 'processed');"

# Verify insert
INSERTED=$(sqlite3 "$DB_PATH" "SELECT COUNT(*) FROM raw_notes WHERE test_run = '$TEST_RUN';")
echo "Inserted test notes: $INSERTED"

if [ "$INSERTED" -eq "1" ]; then
    echo "PASS: Test data inserted"
else
    echo "FAIL: Test data not inserted"
    exit 1
fi

# Test 2: Check Obsidian directory exists
echo ""
echo "Test 2: Checking Obsidian vault access..."
if [ -d "$OBSIDIAN_PATH" ]; then
    echo "PASS: Obsidian vault accessible at $OBSIDIAN_PATH"
else
    echo "WARN: Obsidian vault not found at $OBSIDIAN_PATH (may need Docker mount)"
fi

# Test 3: Manual workflow execution note
echo ""
echo "Test 3: Manual workflow execution"
echo "NOTE: To fully test this workflow, you need to:"
echo "  1. Import workflow to n8n: ./scripts/manage-workflow.sh update <id> workflows/08-daily-summary/workflow.json"
echo "  2. Manually trigger via n8n UI (Test workflow button)"
echo "  3. Check vault/Daily/ for output file"
echo ""

# Cleanup prompt
echo ""
echo "========================================"
read -p "Cleanup test data? (y/n) " -n 1 -r
echo ""
if [[ $REPLY =~ ^[Yy]$ ]]; then
    sqlite3 "$DB_PATH" "DELETE FROM raw_notes WHERE test_run = '$TEST_RUN';"
    echo "Test data cleaned up"

    # Remove test summary file if created
    TODAY=$(date +%Y-%m-%d)
    if [ -f "$OBSIDIAN_PATH/Daily/$TODAY-summary.md" ]; then
        rm "$OBSIDIAN_PATH/Daily/$TODAY-summary.md"
        echo "Removed test summary file"
    fi
else
    echo "Test data retained. Clean up with: ../../scripts/cleanup-tests.sh $TEST_RUN"
fi

echo ""
echo "========================================"
echo "Test Summary"
echo "========================================"
echo "Test marker: $TEST_RUN"
echo "Results: Manual verification required"
