#!/bin/bash
# Reset notes stuck in 'processing' status back to 'pending'
# Use this if the workflow crashes mid-processing

DB_PATH="${1:-./data/selene.db}"

echo "Checking for stuck notes in 'processing' status..."

STUCK_COUNT=$(sqlite3 "$DB_PATH" "SELECT COUNT(*) FROM raw_notes WHERE status = 'processing';")

if [ "$STUCK_COUNT" -eq 0 ]; then
  echo "✓ No stuck notes found. All good!"
  exit 0
fi

echo "Found $STUCK_COUNT note(s) stuck in 'processing' status"
echo ""
echo "Stuck notes:"
sqlite3 "$DB_PATH" "SELECT id, title, imported_at FROM raw_notes WHERE status = 'processing';"
echo ""

read -p "Reset these notes to 'pending'? (y/N) " -n 1 -r
echo
if [[ $REPLY =~ ^[Yy]$ ]]; then
  sqlite3 "$DB_PATH" "UPDATE raw_notes SET status = 'pending' WHERE status = 'processing';"
  echo "✓ Reset $STUCK_COUNT note(s) to 'pending'"
else
  echo "Cancelled"
fi
