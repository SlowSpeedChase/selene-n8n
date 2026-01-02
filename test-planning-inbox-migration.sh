#!/bin/bash
set -euo pipefail

DB_FILE=$(mktemp) || exit 1

cleanup() {
  [[ -f "$DB_FILE" ]] && rm -f "$DB_FILE"
}
trap cleanup EXIT INT TERM

# Apply migrations
sqlite3 "$DB_FILE" < database/schema.sql
sqlite3 "$DB_FILE" < database/migrations/011_planning_inbox.sql

# Verify tables exist
echo "Checking projects table..."
sqlite3 "$DB_FILE" "SELECT sql FROM sqlite_master WHERE name='projects';" | grep -q . || { echo "ERROR: projects table not found"; exit 1; }

echo "Checking project_notes table..."
sqlite3 "$DB_FILE" "SELECT sql FROM sqlite_master WHERE name='project_notes';" | grep -q . || { echo "ERROR: project_notes table not found"; exit 1; }

echo "Checking raw_notes columns..."
sqlite3 "$DB_FILE" "PRAGMA table_info(raw_notes);" | grep -qE "(inbox_status|suggested_type|suggested_project_id)" || { echo "ERROR: Expected columns not found"; exit 1; }

echo "Migration test passed!"
