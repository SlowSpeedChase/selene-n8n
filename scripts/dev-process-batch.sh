#!/bin/bash
#
# dev-process-batch.sh - Process a batch of dev notes through the full pipeline
#
# Runs each workflow step once against the dev database with configurable batch sizes.
# Designed to be run repeatedly (daily/hourly) to gradually process all notes.
#
# Usage:
#   ./scripts/dev-process-batch.sh              # Default: 15 notes per step
#   ./scripts/dev-process-batch.sh 10           # Custom batch size
#   ./scripts/dev-process-batch.sh --status     # Show processing status only
#

set -e

# Colors
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
RED='\033[0;31m'
NC='\033[0m'

BATCH_SIZE="${1:-15}"
DEV_DB="$HOME/selene-data-dev/selene.db"

# Verify dev environment
if [ ! -f "$DEV_DB" ]; then
  echo -e "${RED}Error: Dev database not found at $DEV_DB${NC}"
  echo "Run: ./scripts/create-dev-db.sh first"
  exit 1
fi

ENV=$(sqlite3 "$DEV_DB" "SELECT value FROM _selene_metadata WHERE key='environment';")
if [ "$ENV" != "development" ]; then
  echo -e "${RED}Error: Database environment is '$ENV', expected 'development'${NC}"
  exit 1
fi

show_status() {
  echo -e "${BLUE}=== Dev Database Processing Status ===${NC}"
  echo ""

  RAW=$(sqlite3 "$DEV_DB" "SELECT COUNT(*) FROM raw_notes;")
  PROCESSED=$(sqlite3 "$DEV_DB" "SELECT COUNT(*) FROM processed_notes;")
  PENDING=$(sqlite3 "$DEV_DB" "SELECT COUNT(*) FROM raw_notes WHERE status = 'pending';")
  RELATIONSHIPS=$(sqlite3 "$DEV_DB" "SELECT COUNT(*) FROM note_relationships;")
  ASSOCIATIONS=$(sqlite3 "$DEV_DB" "SELECT COUNT(*) FROM note_associations;")
  THREADS=$(sqlite3 "$DEV_DB" "SELECT COUNT(*) FROM threads;")
  THREAD_NOTES=$(sqlite3 "$DEV_DB" "SELECT COUNT(*) FROM thread_notes;")
  EXPORTED=$(sqlite3 "$DEV_DB" "SELECT COUNT(*) FROM raw_notes WHERE exported_to_obsidian = 1;")

  echo -e "  Raw notes:        ${GREEN}${RAW}${NC}"
  echo -e "  LLM processed:    ${GREEN}${PROCESSED}${NC} / ${RAW}"
  echo -e "  Pending LLM:      ${YELLOW}${PENDING}${NC}"
  echo -e "  Relationships:    ${GREEN}${RELATIONSHIPS}${NC}"
  echo -e "  Associations:     ${GREEN}${ASSOCIATIONS}${NC}"
  echo -e "  Threads:          ${GREEN}${THREADS}${NC}"
  echo -e "  Thread notes:     ${GREEN}${THREAD_NOTES}${NC}"
  echo -e "  Obsidian export:  ${GREEN}${EXPORTED}${NC} / ${RAW}"
  echo ""
}

# Status-only mode
if [ "$1" = "--status" ]; then
  show_status
  exit 0
fi

echo -e "${BLUE}=== Dev Batch Processing (batch size: ${BATCH_SIZE}) ===${NC}"
echo ""

show_status

# Step 1: Index vectors (embed unindexed notes into LanceDB)
echo -e "${YELLOW}Step 1: Index vectors (limit ${BATCH_SIZE})...${NC}"
SELENE_ENV=development npx ts-node src/workflows/index-vectors.ts "$BATCH_SIZE" 2>&1 | grep -E "(complete|error|No notes)" || true
echo ""

# Step 2: Compute associations (pairwise similarity via LanceDB)
echo -e "${YELLOW}Step 2: Compute associations (limit ${BATCH_SIZE})...${NC}"
SELENE_ENV=development npx ts-node src/workflows/compute-associations.ts "$BATCH_SIZE" 2>&1 | grep -E "(complete|error|All indexed)" || true
echo ""

# Step 3: Compute relationships (temporal, thread, project)
echo -e "${YELLOW}Step 3: Compute relationships...${NC}"
SELENE_ENV=development npx ts-node src/workflows/compute-relationships.ts 2>&1 | grep -E "(complete|error)" || true
echo ""

# Step 4: Detect threads
echo -e "${YELLOW}Step 4: Detect threads...${NC}"
SELENE_ENV=development npx ts-node src/workflows/detect-threads.ts 2>&1 | grep -E "(complete|error|Created|Assigned)" || true
echo ""

# Step 5: Reconsolidate threads
echo -e "${YELLOW}Step 5: Reconsolidate threads...${NC}"
SELENE_ENV=development npx ts-node src/workflows/reconsolidate-threads.ts 2>&1 | grep -E "(complete|error|Updated)" || true
echo ""

# Step 6: Export to Obsidian
echo -e "${YELLOW}Step 6: Export to Obsidian vault...${NC}"
SELENE_ENV=development npx ts-node src/workflows/export-obsidian.ts 2>&1 | grep -E "(complete|error|Exported)" || true
echo ""

echo -e "${BLUE}=== After Processing ===${NC}"
echo ""
show_status

echo -e "${GREEN}Done!${NC} Run again to process the next batch."
