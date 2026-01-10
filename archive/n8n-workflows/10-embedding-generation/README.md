# 10-Embedding-Generation Workflow

## Purpose

Generates vector embeddings for notes using Ollama's `nomic-embed-text` model and stores them in SQLite for semantic similarity searches.

## Endpoint

**POST** `http://localhost:5678/webhook/api/embed`

## Input Format

Single note:
```json
{
  "note_id": 123
}
```

Batch processing:
```json
{
  "note_ids": [123, 456, 789]
}
```

With test marker:
```json
{
  "note_id": 123,
  "test_run": "test-run-20260104-120000"
}
```

## Output Format

```json
{
  "success": true,
  "summary": {
    "total": 3,
    "embedded": 2,
    "skipped": 1,
    "not_found": 0,
    "failed": 0
  },
  "results": [
    {"note_id": 123, "status": "embedded", "dimensions": 768},
    {"note_id": 456, "status": "skipped", "reason": "already_embedded"},
    {"note_id": 789, "status": "embedded", "dimensions": 768}
  ]
}
```

## Example Usage

```bash
# Embed a single note
curl -X POST http://localhost:5678/webhook/api/embed \
  -H "Content-Type: application/json" \
  -d '{"note_id": 1}'

# Embed multiple notes
curl -X POST http://localhost:5678/webhook/api/embed \
  -H "Content-Type: application/json" \
  -d '{"note_ids": [1, 2, 3]}'
```

## Behavior

- **Idempotent**: Skips notes that already have embeddings
- **Graceful**: Reports not_found for missing notes without failing
- **Batched**: Can process multiple notes in one request

## Dependencies

- **Ollama** running at `http://host.docker.internal:11434`
- **Model**: `nomic-embed-text` (768 dimensions)
- **Database**: `note_embeddings` table must exist

### Pull the model (if not installed)

```bash
ollama pull nomic-embed-text
```

## Database Schema

**Table: note_embeddings**
```sql
CREATE TABLE note_embeddings (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    raw_note_id INTEGER NOT NULL UNIQUE,
    embedding BLOB NOT NULL,  -- JSON array of 768 floats
    model_version TEXT NOT NULL,
    created_at TEXT DEFAULT CURRENT_TIMESTAMP,
    test_run TEXT,
    FOREIGN KEY (raw_note_id) REFERENCES raw_notes(id)
);
```

## Testing

```bash
# Run test suite
./scripts/test-with-markers.sh

# Manual test
curl -X POST http://localhost:5678/webhook/api/embed \
  -H "Content-Type: application/json" \
  -d '{"note_id": 1, "test_run": "manual-test"}'

# Verify embedding stored
sqlite3 data/selene.db "SELECT raw_note_id, model_version, json_array_length(embedding) as dims FROM note_embeddings WHERE raw_note_id = 1;"

# Cleanup
sqlite3 data/selene.db "DELETE FROM note_embeddings WHERE test_run = 'manual-test';"
```

## Error Handling

| Scenario | Response |
|----------|----------|
| Note not found | `status: "not_found"` |
| Ollama timeout | `status: "failed", error: "..."` |
| Already embedded | `status: "skipped"` |
| Invalid input | HTTP 500 with error |

## Related Files

- `workflow.json` - Workflow definition
- `docs/STATUS.md` - Test results
- `scripts/test-with-markers.sh` - Automated tests
