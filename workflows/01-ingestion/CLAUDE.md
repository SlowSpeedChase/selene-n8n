# 01-Ingestion Workflow Context

## Purpose

Captures notes from Drafts app via webhook, performs SHA256-based duplicate detection, and stores new notes in SQLite raw_notes table. First step in the note processing pipeline.

## Tech Stack

- n8n Webhook trigger
- better-sqlite3 for database operations
- SHA256 for content hashing (duplicate detection)
- JSON parsing for Drafts payload

## Key Files

- workflow.json (365 lines) - Main workflow definition
- docs/STATUS.md - Test results (6/7 tests passing as of last run)
- docs/DRAFTS-SETUP.md - Drafts app integration guide
- scripts/test-with-markers.sh - Automated testing script
- scripts/cleanup-tests.sh - Test data cleanup utility

## Data Flow

1. **Webhook Receives** - Drafts app sends POST with JSON payload
2. **Parse Note Data** - Extract content, uuid, timestamp from payload
3. **Generate Hash** - Create SHA256 hash of content for deduplication
4. **Check for Duplicate** - Query raw_notes for existing content_hash
5. **Insert or Skip** - If new, insert into raw_notes; if duplicate, log and skip
6. **Return Response** - Send 200 OK back to Drafts

## Common Patterns

### Duplicate Detection
```javascript
// SHA256 hash generation (n8n doesn't support MD5)
const crypto = require('crypto');
const contentHash = crypto.createHash('sha256')
    .update(content)
    .digest('hex');
```

### Test Data Marking
```javascript
// All test records marked with test_run
const testRun = $input.item.json.test_run || null;  // NULL = production
db.prepare('INSERT INTO raw_notes (..., test_run) VALUES (..., ?)').run(..., testRun);
```

### Error Handling
- Duplicate content → Log and return 200 (not an error)
- Missing required fields → Return 400 with error message
- Database errors → Log to console, return 500

### Node Naming
- "Receive Webhook" - Webhook trigger
- "Parse Note Data" - Extract JSON fields
- "Generate Content Hash" - SHA256 hashing
- "Check for Duplicate" - Database query
- "Insert Note" - Database insert
- "Return Success" - HTTP response

## Testing

### Run Tests
```bash
cd workflows/01-ingestion
./scripts/test-with-markers.sh
```

### Expected Results
- 7 test cases total
- Current status: 6/7 passing
- Known issue: Duplicate detection failing on edge case (empty content)

### Cleanup
```bash
# List test runs
./scripts/cleanup-tests.sh --list

# Clean specific run
./scripts/cleanup-tests.sh test-run-20251124-120000
```

## Database Schema

**Table: raw_notes**
```sql
CREATE TABLE raw_notes (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    content TEXT NOT NULL,
    content_hash TEXT UNIQUE NOT NULL,  -- SHA256 for deduplication
    source_uuid TEXT,                    -- UUID from Drafts
    created_at DATETIME DEFAULT CURRENT_TIMESTAMP,
    test_run TEXT                        -- NULL = production, otherwise test marker
);
```

**Indexes:**
- `content_hash` (UNIQUE) - Fast duplicate lookup
- `created_at` - Temporal queries

## Webhook Configuration

**Endpoint:** `http://localhost:5678/webhook/ingest-note`

**Payload Format:**
```json
{
  "content": "Note content here",
  "uuid": "draft-uuid-12345",
  "timestamp": "2025-11-24T12:00:00Z",
  "test_run": "test-run-20251124-120000"  // Optional, for testing only
}
```

## Do NOT

- **NEVER skip content_hash generation** - breaks deduplication
- **NEVER insert without checking duplicates** - creates data pollution
- **NEVER modify webhook URL without updating Drafts action**
- **NEVER commit test data** - always use test_run marker
- **NEVER change raw_notes schema** without migrating existing data

## Known Issues

1. **Empty Content Edge Case** - Duplicate detection fails when content is empty string
   - Status: Open
   - Workaround: Validate content length before hashing

2. **Timestamp Format** - Drafts sends ISO 8601, database stores as TEXT
   - Status: Working as designed
   - Note: SQLite handles ISO 8601 strings natively for date comparisons

## Related Context

@workflows/01-ingestion/README.md
@workflows/01-ingestion/docs/STATUS.md
@workflows/01-ingestion/docs/DRAFTS-SETUP.md
@database/schema.sql
@workflows/CLAUDE.md
