# Ingestion Workflow - Test Instructions

## Overview
This workflow receives incoming notes/drafts via webhook, validates them, checks for duplicates, and stores them in the `raw_notes` SQLite table.

## Prerequisites

1. **Docker container running:**
   ```bash
   docker-compose ps
   # Should show selene-n8n as healthy
   ```

2. **Database initialized:**
   ```bash
   sqlite3 data/selene.db ".tables"
   # Should show: raw_notes, processed_notes, etc.
   ```

3. **Workflow imported and activated in n8n:**
   - Go to http://localhost:5678
   - Import `workflows/01-ingestion/workflow.json`
   - Click "Active" toggle to enable the workflow

## Test Cases

### Test 1: Basic Note Ingestion

**Purpose:** Verify that a simple note can be ingested successfully.

**Command:**
```bash
curl -X POST http://localhost:5678/webhook/api/drafts \
  -H "Content-Type: application/json" \
  -d '{
    "title": "Test Note 1",
    "content": "This is a basic test note to verify ingestion works.",
    "created_at": "2025-10-29T22:00:00Z",
    "source_type": "drafts"
  }'
```

**Expected Response:**
```json
{
  "success": true,
  "action": "stored",
  "message": "Note successfully ingested into raw_notes table",
  "noteId": 1,
  "title": "Test Note 1",
  "wordCount": 10,
  "contentHash": "...",
  "sourceType": "drafts",
  "status": "pending"
}
```

**Verification:**
```bash
sqlite3 data/selene.db "SELECT id, title, word_count, status FROM raw_notes WHERE id = 1;"
```

**Expected Output:**
```
1|Test Note 1|10|pending
```

---

### Test 2: Note with Tags

**Purpose:** Verify tag extraction works correctly.

**Command:**
```bash
curl -X POST http://localhost:5678/webhook/api/drafts \
  -H "Content-Type: application/json" \
  -d '{
    "title": "Tagged Note",
    "content": "This note has #productivity and #testing tags in it.",
    "created_at": "2025-10-29T22:05:00Z"
  }'
```

**Expected Response:**
- `success: true`
- `action: "stored"`
- Tags should be extracted

**Verification:**
```bash
sqlite3 data/selene.db "SELECT id, title, tags FROM raw_notes WHERE title = 'Tagged Note';"
```

**Expected Output:**
```
2|Tagged Note|["productivity","testing"]
```

---

### Test 3: Duplicate Detection

**Purpose:** Verify duplicate notes are detected and skipped.

**Command:** Run the same request as Test 1 again:
```bash
curl -X POST http://localhost:5678/webhook/api/drafts \
  -H "Content-Type: application/json" \
  -d '{
    "title": "Test Note 1",
    "content": "This is a basic test note to verify ingestion works.",
    "created_at": "2025-10-29T22:00:00Z",
    "source_type": "drafts"
  }'
```

**Expected Response:**
```json
{
  "success": true,
  "action": "duplicate_skipped",
  "message": "Duplicate note detected and skipped",
  "contentHash": "...",
  "title": "Test Note 1",
  "existingNoteId": 1,
  "existingNoteTitle": "Test Note 1",
  "existingNoteCreatedAt": "2025-10-29T22:00:00Z"
}
```

**Verification:**
```bash
sqlite3 data/selene.db "SELECT COUNT(*) FROM raw_notes WHERE title = 'Test Note 1';"
```

**Expected Output:**
```
1
```
(Should still be only 1 record, not 2)

---

### Test 4: Long Content

**Purpose:** Verify the workflow handles longer content correctly.

**Command:**
```bash
curl -X POST http://localhost:5678/webhook/api/drafts \
  -H "Content-Type: application/json" \
  -d '{
    "title": "Long Form Note",
    "content": "This is a much longer note with multiple paragraphs.\n\nIt contains several sentences and spans multiple lines.\n\nWe want to test that word count, character count, and content hash all work correctly with longer content.\n\n#longform #testing #content",
    "created_at": "2025-10-29T22:10:00Z"
  }'
```

**Expected Response:**
- `success: true`
- `wordCount` should be approximately 40-50
- `characterCount` should be accurate

**Verification:**
```bash
sqlite3 data/selene.db "SELECT title, word_count, character_count FROM raw_notes WHERE title = 'Long Form Note';"
```

---

### Test 5: Minimal Required Fields

**Purpose:** Verify the workflow works with only required fields.

**Command:**
```bash
curl -X POST http://localhost:5678/webhook/api/drafts \
  -H "Content-Type: application/json" \
  -d '{
    "content": "Minimal note with no title or timestamp"
  }'
```

**Expected Response:**
- `success: true`
- `title` should default to "Untitled Note"
- `timestamp` should be auto-generated
- `sourceType` should default to "drafts"

---

### Test 6: Error Handling - Empty Content

**Purpose:** Verify validation rejects empty content.

**Command:**
```bash
curl -X POST http://localhost:5678/webhook/api/drafts \
  -H "Content-Type: application/json" \
  -d '{
    "title": "Empty Note",
    "content": ""
  }'
```

**Expected Response:**
- Should return an error
- Message should indicate content is required

---

### Test 7: Alternative Input Format

**Purpose:** Verify the workflow supports query parameter format.

**Command:**
```bash
curl -X POST http://localhost:5678/webhook/api/drafts \
  -H "Content-Type: application/json" \
  -d '{
    "query": {
      "title": "Query Format Note",
      "content": "Testing alternative input format",
      "timestamp": "2025-10-29T22:15:00Z"
    }
  }'
```

**Expected Response:**
- `success: true`
- Note should be stored correctly

---

## Quick Test Script

Run all tests at once using the provided test script:

```bash
./workflows/01-ingestion/test.sh
```

This will run all test cases and report results.

---

## Cleanup After Testing

To reset the database and start fresh:

```bash
# Remove all test data
sqlite3 data/selene.db "DELETE FROM raw_notes;"

# Or reset the entire database
rm data/selene.db
sqlite3 data/selene.db < database/schema.sql
```

---

## Common Issues

### Issue: Webhook returns 404
**Solution:** Make sure the workflow is activated in n8n and the webhook node is properly configured.

### Issue: SQLite database not found
**Solution:** Initialize the database:
```bash
sqlite3 data/selene.db < database/schema.sql
```

### Issue: better-sqlite3 module not found
**Solution:** Rebuild the Docker container:
```bash
docker-compose down
docker-compose build --no-cache
docker-compose up -d
```

### Issue: Permission denied on database
**Solution:** Check volume mounts and permissions:
```bash
ls -la data/
# Fix permissions if needed
chmod 644 data/selene.db
```

---

## Success Criteria

The ingestion workflow passes testing if:

1. ✅ Basic notes can be ingested and appear in database
2. ✅ Tags are extracted correctly from content
3. ✅ Duplicate notes are detected and rejected
4. ✅ Word count and character count are accurate
5. ✅ Content hash prevents duplicates
6. ✅ Default values are applied when fields are missing
7. ✅ Empty or invalid content is rejected
8. ✅ Multiple input formats are supported

---

## Next Steps

After successful testing:
1. Document results in `STATUS.md`
2. Move to Phase 2: LLM Processing Workflow
3. Test integration between ingestion and processing
