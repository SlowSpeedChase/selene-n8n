#!/bin/bash
set -e

# Test script for 09-feedback-processing workflow
# Uses test_run markers for safe testing and cleanup

TEST_RUN="test-run-$(date +%Y%m%d-%H%M%S)"
DB_PATH="data/selene.db"

echo "============================================"
echo "09-Feedback-Processing Test Script"
echo "============================================"
echo ""
echo "Test run ID: $TEST_RUN"
echo ""

# Check database exists
if [ ! -f "$DB_PATH" ]; then
    echo "ERROR: Database not found at $DB_PATH"
    echo "Make sure you're running from the project root directory."
    exit 1
fi

# Check feedback_notes table exists
TABLE_EXISTS=$(sqlite3 "$DB_PATH" "SELECT name FROM sqlite_master WHERE type='table' AND name='feedback_notes';" 2>/dev/null || echo "")
if [ -z "$TABLE_EXISTS" ]; then
    echo "ERROR: feedback_notes table does not exist."
    echo "Run the schema migration first (Task 2)."
    exit 1
fi

echo "Inserting test feedback..."
echo ""

# Insert test feedback data
sqlite3 "$DB_PATH" "INSERT INTO feedback_notes (content, content_hash, test_run) VALUES ('The task suggestion felt wrong when I was tired - gave me a coding task when I said low energy #selene-feedback', 'test-hash-$TEST_RUN', '$TEST_RUN')"

echo "Test feedback inserted successfully."
echo ""
echo "============================================"
echo "Verification Commands"
echo "============================================"
echo ""
echo "To check inserted test data:"
echo "  sqlite3 $DB_PATH \"SELECT id, content, processed_at FROM feedback_notes WHERE test_run = '$TEST_RUN'\""
echo ""
echo "After workflow processes (wait ~5 minutes or trigger manually):"
echo "  sqlite3 $DB_PATH \"SELECT id, user_story, theme, priority, processed_at FROM feedback_notes WHERE test_run = '$TEST_RUN'\""
echo ""
echo "To cleanup test data:"
echo "  sqlite3 $DB_PATH \"DELETE FROM feedback_notes WHERE test_run = '$TEST_RUN'\""
echo ""
echo "============================================"
echo "Quick verification (pre-processing):"
echo "============================================"
sqlite3 "$DB_PATH" "SELECT id, substr(content, 1, 60) || '...' as content, processed_at FROM feedback_notes WHERE test_run = '$TEST_RUN'"
echo ""
echo "Test run ID for cleanup: $TEST_RUN"
