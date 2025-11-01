# 01-Ingestion Workflow

> 📑 **Quick Reference:** See [INDEX.md](INDEX.md) for a complete file guide and common tasks

## Purpose

The ingestion workflow is the entry point for all notes entering the Selene system. It receives notes via webhook, validates them, checks for duplicates, and stores them in the `raw_notes` database table.

## Quick Start

### 1. Import Workflow
```bash
# In n8n UI (http://localhost:5678):
# 1. Go to Workflows
# 2. Click "Import from File"
# 3. Select: workflows/01-ingestion/workflow.json
# 4. Activate the workflow
```

### 2. Test the Workflow
```bash
# Run automated tests with automatic cleanup markers (RECOMMENDED)
./scripts/test-with-markers.sh

# Or test manually with curl (with test marker)
curl -X POST http://localhost:5678/webhook/api/drafts \
  -H "Content-Type: application/json" \
  -d '{
    "title": "My First Note",
    "content": "This is a test note",
    "created_at": "2025-10-29T22:00:00Z",
    "test_run": "my-test"
  }'

# Clean up test data
./scripts/cleanup-tests.sh my-test
```

### 3. Verify Results
```bash
# Check database
sqlite3 data/selene.db "SELECT * FROM raw_notes ORDER BY id DESC LIMIT 5;"
```

## Directory Structure

```
01-ingestion/
├── workflow.json           # Active n8n workflow definition
├── README.md              # This file (quick start guide)
│
├── docs/                  # Documentation
│   ├── DRAFTS-QUICKSTART.md      # Quick setup for Drafts app
│   ├── DRAFTS-SETUP.md           # Complete Drafts integration guide
│   ├── STATUS.md                 # Testing results & current status
│   ├── TEST.md                   # Manual test cases
│   ├── TEST-DATA-MANAGEMENT.md   # Guide for test data cleanup
│   └── CHANGELOG.md              # Version history
│
├── scripts/               # Executable scripts
│   ├── test-with-markers.sh      # Test suite with auto-marking
│   └── cleanup-tests.sh          # Test data cleanup utility
│
└── archive/               # Deprecated/archived files
    ├── test.sh.deprecated        # Old test script
    └── workflow-v2-*.json        # Experimental versions
```

## Workflow Steps

1. **Webhook Receiver** - Receives POST requests at `/webhook/api/drafts`
2. **Parse Note Data** - Extracts and validates input, generates content hash
3. **Check for Duplicate** - Queries database to prevent duplicate entries
4. **Is New Note?** - Decision node based on duplicate check
5. **Insert Note** - Stores new note in `raw_notes` table
6. **Build Response** - Creates success or duplicate response
7. **Respond to Webhook** - Returns JSON response to caller

## Database Schema

```sql
CREATE TABLE raw_notes (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    title TEXT NOT NULL,
    content TEXT NOT NULL,
    content_hash TEXT UNIQUE NOT NULL,
    source_type TEXT DEFAULT 'drafts',
    word_count INTEGER DEFAULT 0,
    character_count INTEGER DEFAULT 0,
    tags TEXT,
    created_at DATETIME NOT NULL,
    imported_at DATETIME DEFAULT CURRENT_TIMESTAMP,
    processed_at DATETIME,
    exported_at DATETIME,
    status TEXT DEFAULT 'pending',
    exported_to_obsidian INTEGER DEFAULT 0
);
```

## Input Format

### Standard Format (Recommended)
```json
{
  "title": "Note Title",
  "content": "The full text of the note",
  "created_at": "2025-10-29T22:00:00Z",
  "source_type": "drafts"
}
```

### Query Parameter Format (Alternative)
```json
{
  "query": {
    "title": "Note Title",
    "content": "The full text",
    "timestamp": "2025-10-29T22:00:00Z"
  }
}
```

### Minimal Format
```json
{
  "content": "Just the content is required"
}
```

## Output Format

### Success Response
```json
{
  "success": true,
  "action": "stored",
  "message": "Note successfully ingested into raw_notes table",
  "noteId": 123,
  "title": "Note Title",
  "wordCount": 50,
  "contentHash": "abc123...",
  "sourceType": "drafts",
  "status": "pending"
}
```

### Duplicate Response
```json
{
  "success": true,
  "action": "duplicate_skipped",
  "message": "Duplicate note detected and skipped",
  "contentHash": "abc123...",
  "title": "Note Title",
  "existingNoteId": 123,
  "existingNoteTitle": "Note Title",
  "existingNoteCreatedAt": "2025-10-29T22:00:00Z"
}
```

## Features

- ✅ Webhook endpoint for external integrations
- ✅ Content hash-based duplicate detection
- ✅ Automatic tag extraction from content (#hashtags)
- ✅ Word count and character count calculation
- ✅ Flexible input format support
- ✅ Input validation and error handling
- ✅ Default values for optional fields
- ✅ Multiple source type support

## Integration Points

### Upstream
- **Drafts App** - iOS/Mac app for capturing notes
- **Email** - Can forward emails to webhook
- **Other Apps** - Any system that can POST JSON

### Downstream
- **02-llm-processing** - Processes notes where `status = 'pending'`

## Testing

See **TEST.md** for detailed test cases.

Quick test:
```bash
./workflows/01-ingestion/test.sh
```

## Status Tracking

Document your testing and production status in **STATUS.md**.

## Configuration

The workflow uses these environment variables (configured in docker-compose.yml):
- `SELENE_DB_PATH=/selene/data/selene.db` - Database location

## Troubleshooting

### Webhook returns 404
- Ensure workflow is activated in n8n
- Check webhook URL matches the configured path

### SQLite errors
- Verify database exists: `ls -la data/selene.db`
- Reinitialize if needed: `sqlite3 data/selene.db < database/schema.sql`

### better-sqlite3 not found
- Rebuild container: `docker-compose build --no-cache`

## Maintenance

### View Recent Notes
```bash
sqlite3 data/selene.db "SELECT id, title, created_at FROM raw_notes ORDER BY imported_at DESC LIMIT 10;"
```

### Check for Duplicates
```bash
sqlite3 data/selene.db "SELECT content_hash, COUNT(*) FROM raw_notes GROUP BY content_hash HAVING COUNT(*) > 1;"
```

### Clear Test Data
```bash
sqlite3 data/selene.db "DELETE FROM raw_notes WHERE title LIKE '%Test%';"
```

## Next Steps

After successful ingestion:
1. Notes are stored with `status = 'pending'`
2. Proceed to **02-llm-processing** workflow
3. Processing workflow will update `status = 'processed'`
4. Continue through the pipeline to Obsidian export
