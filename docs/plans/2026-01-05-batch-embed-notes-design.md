# Batch Embed Notes Design

**Story:** US-042
**Created:** 2026-01-05
**Status:** Approved

---

## Overview

Create a script to backfill embeddings for all existing processed notes (~75 notes) by calling the embedding workflow (10-Embedding-Generation) sequentially.

## Approach

**Sequential curl calls** to the webhook endpoint. One request per note with 1-second delay between requests.

**Why this approach:**
- Keeps embedding logic in one place (the workflow)
- Resume-safe by design (re-running skips already-embedded notes)
- Simple and reliable
- ~75 seconds for 75 notes is acceptable for a one-time backfill

## Implementation

### File: `scripts/batch-embed-notes.sh`

```bash
#!/bin/bash
set -euo pipefail

# Configuration
WEBHOOK_URL="${WEBHOOK_URL:-http://localhost:5678/webhook/api/embed}"
DB_PATH="${SELENE_DB_PATH:-./data/selene.db}"
DELAY_SECONDS="${DELAY_SECONDS:-1}"

# Pre-flight checks
echo "=== Batch Embed Notes ==="

if [[ ! -f "$DB_PATH" ]]; then
  echo "ERROR: Database not found at $DB_PATH"
  exit 1
fi

if ! curl -s --max-time 5 "http://localhost:5678/healthz" > /dev/null 2>&1; then
  echo "ERROR: n8n not reachable at localhost:5678"
  exit 1
fi

if ! curl -s --max-time 5 "http://localhost:11434/api/tags" > /dev/null 2>&1; then
  echo "ERROR: Ollama not reachable at localhost:11434"
  exit 1
fi

echo "✓ Database: $DB_PATH"
echo "✓ n8n: reachable"
echo "✓ Ollama: reachable"
echo ""

# Get notes needing embeddings
NOTE_IDS=$(sqlite3 "$DB_PATH" "
  SELECT DISTINCT pn.raw_note_id
  FROM processed_notes pn
  LEFT JOIN note_embeddings ne ON pn.raw_note_id = ne.raw_note_id
  WHERE ne.id IS NULL
  ORDER BY pn.raw_note_id
")

if [[ -z "$NOTE_IDS" ]]; then
  echo "All notes already have embeddings. Nothing to do."
  exit 0
fi

# Progress tracking
TOTAL=$(echo "$NOTE_IDS" | wc -l | tr -d ' ')
CURRENT=0
SUCCESS=0
FAILED=0

echo "Found $TOTAL notes needing embeddings"
echo ""

for NOTE_ID in $NOTE_IDS; do
  CURRENT=$((CURRENT + 1))
  echo -n "[$CURRENT/$TOTAL] Embedding note $NOTE_ID... "

  RESPONSE=$(curl -s -w "%{http_code}" -X POST "$WEBHOOK_URL" \
    -H "Content-Type: application/json" \
    -d "{\"note_id\": $NOTE_ID}")

  HTTP_CODE="${RESPONSE: -3}"

  if [[ "$HTTP_CODE" == "200" ]]; then
    echo "✓"
    SUCCESS=$((SUCCESS + 1))
  else
    echo "✗ (HTTP $HTTP_CODE)"
    FAILED=$((FAILED + 1))
  fi

  sleep "$DELAY_SECONDS"
done

echo ""
echo "=== Complete ==="
echo "Success: $SUCCESS"
echo "Failed: $FAILED"
echo "Total: $TOTAL"
```

### Usage

```bash
# Default (1 second delay)
./scripts/batch-embed-notes.sh

# Faster (0.5 second delay)
DELAY_SECONDS=0.5 ./scripts/batch-embed-notes.sh

# Custom database path
SELENE_DB_PATH=/path/to/selene.db ./scripts/batch-embed-notes.sh
```

## Files Changed

| File | Change |
|------|--------|
| `scripts/batch-embed-notes.sh` | New - the batch script |
| `scripts/CLAUDE.md` | Update - document new script |

## Acceptance Criteria

- [x] Script queries processed_notes that lack embeddings
- [x] Calls webhook for each note with rate limiting (1 req/sec)
- [x] Progress logged to console
- [x] Can resume from interruption (skips already-embedded)
- [ ] All existing processed notes have embeddings after completion
- [ ] Script documented in scripts/CLAUDE.md
