#!/bin/bash
# Cleanup test data from database
# Usage: ./scripts/cleanup-tests.sh [--list | --all | <test-run-id>]

set -e

DB_PATH="${SELENE_DB_PATH:-./data/selene.db}"

if [ ! -f "$DB_PATH" ]; then
    echo "ERROR: Database not found: $DB_PATH"
    exit 1
fi

list_test_runs() {
    echo "Test runs in database:"
    echo "----------------------"
    sqlite3 "$DB_PATH" "
        SELECT test_run, COUNT(*) as count
        FROM raw_notes
        WHERE test_run IS NOT NULL
        GROUP BY test_run
        ORDER BY test_run DESC;
    "
}

cleanup_test_run() {
    local test_run=$1
    echo "Cleaning test run: $test_run"

    # Clean from all tables
    sqlite3 "$DB_PATH" "DELETE FROM raw_notes WHERE test_run = '$test_run';"
    sqlite3 "$DB_PATH" "DELETE FROM processed_notes WHERE test_run = '$test_run';" 2>/dev/null || true
    sqlite3 "$DB_PATH" "DELETE FROM note_embeddings WHERE test_run = '$test_run';" 2>/dev/null || true
    sqlite3 "$DB_PATH" "DELETE FROM note_associations WHERE test_run = '$test_run';" 2>/dev/null || true

    echo "Cleanup complete"
}

cleanup_all() {
    echo "Cleaning ALL test data..."

    sqlite3 "$DB_PATH" "DELETE FROM raw_notes WHERE test_run IS NOT NULL;"
    sqlite3 "$DB_PATH" "DELETE FROM processed_notes WHERE test_run IS NOT NULL;" 2>/dev/null || true
    sqlite3 "$DB_PATH" "DELETE FROM note_embeddings WHERE test_run IS NOT NULL;" 2>/dev/null || true
    sqlite3 "$DB_PATH" "DELETE FROM note_associations WHERE test_run IS NOT NULL;" 2>/dev/null || true

    echo "All test data cleaned"
}

case "${1:---list}" in
    --list)
        list_test_runs
        ;;
    --all)
        read -p "Delete ALL test data? (y/n) " -n 1 -r
        echo
        if [[ $REPLY =~ ^[Yy]$ ]]; then
            cleanup_all
        fi
        ;;
    *)
        cleanup_test_run "$1"
        ;;
esac
