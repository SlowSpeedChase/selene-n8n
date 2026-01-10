#!/bin/bash

# Cleanup Test Data Script
# Removes test data from the database

set -e

# Colors for output
GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Configuration
DB_PATH="data/selene.db"

# Show usage
usage() {
    echo "Usage: $0 [TEST_RUN_ID|--all|--list]"
    echo ""
    echo "Options:"
    echo "  TEST_RUN_ID    Delete test data for a specific test run"
    echo "  --all          Delete ALL test data (use with caution)"
    echo "  --list         List all test runs"
    echo ""
    echo "Examples:"
    echo "  $0 test-run-20251030-120000"
    echo "  $0 --list"
    echo "  $0 --all"
    exit 1
}

# Check if database exists
if [ ! -f "$DB_PATH" ]; then
    echo -e "${RED}Error: Database not found at $DB_PATH${NC}"
    exit 1
fi

# Parse arguments
if [ $# -eq 0 ]; then
    usage
fi

case "$1" in
    --list)
        echo "=========================================="
        echo "Test Runs in Database"
        echo "=========================================="
        echo ""

        # List all test runs with counts
        sqlite3 "$DB_PATH" <<EOF
.headers on
.mode column
SELECT
    test_run,
    COUNT(*) as count,
    MIN(imported_at) as first_import,
    MAX(imported_at) as last_import
FROM raw_notes
WHERE test_run IS NOT NULL
GROUP BY test_run
ORDER BY last_import DESC;
EOF
        echo ""
        ;;

    --all)
        echo -e "${YELLOW}WARNING: This will delete ALL test data from the database!${NC}"
        echo -n "Are you sure? (yes/no): "
        read confirmation

        if [ "$confirmation" != "yes" ]; then
            echo "Cancelled."
            exit 0
        fi

        count=$(sqlite3 "$DB_PATH" "SELECT COUNT(*) FROM raw_notes WHERE test_run IS NOT NULL;")

        if [ "$count" -eq 0 ]; then
            echo -e "${BLUE}No test data found.${NC}"
            exit 0
        fi

        echo -e "${BLUE}Deleting $count test records...${NC}"
        sqlite3 "$DB_PATH" "DELETE FROM raw_notes WHERE test_run IS NOT NULL;"

        echo -e "${GREEN}Successfully deleted $count test records.${NC}"
        ;;

    *)
        TEST_RUN_ID="$1"

        # Check if test run exists
        count=$(sqlite3 "$DB_PATH" "SELECT COUNT(*) FROM raw_notes WHERE test_run='$TEST_RUN_ID';")

        if [ "$count" -eq 0 ]; then
            echo -e "${RED}No test data found for test run: $TEST_RUN_ID${NC}"
            echo ""
            echo "Available test runs:"
            sqlite3 "$DB_PATH" "SELECT DISTINCT test_run FROM raw_notes WHERE test_run IS NOT NULL;"
            exit 1
        fi

        echo -e "${BLUE}Found $count records for test run: $TEST_RUN_ID${NC}"
        echo ""

        # Show what will be deleted
        echo "Records to be deleted:"
        sqlite3 "$DB_PATH" <<EOF
.headers on
.mode column
SELECT id, title, created_at
FROM raw_notes
WHERE test_run='$TEST_RUN_ID'
ORDER BY id;
EOF
        echo ""

        echo -n "Delete these records? (yes/no): "
        read confirmation

        if [ "$confirmation" != "yes" ]; then
            echo "Cancelled."
            exit 0
        fi

        sqlite3 "$DB_PATH" "DELETE FROM raw_notes WHERE test_run='$TEST_RUN_ID';"

        echo -e "${GREEN}Successfully deleted $count records from test run: $TEST_RUN_ID${NC}"
        ;;
esac

# Show remaining test data count
remaining=$(sqlite3 "$DB_PATH" "SELECT COUNT(*) FROM raw_notes WHERE test_run IS NOT NULL;")
echo ""
echo -e "${BLUE}Remaining test records in database: $remaining${NC}"
