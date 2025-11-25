# 02-LLM Processing Workflow Context

## Purpose

Uses Ollama (mistral:7b) to extract concepts, themes, and keywords from notes in raw_notes table, storing results in processed_notes table. Core LLM processing pipeline for semantic analysis.

## Tech Stack

- Ollama HTTP API (local LLM hosting)
- mistral:7b model (7 billion parameter LLM)
- better-sqlite3 for database operations
- JSON parsing for LLM responses
- Queue management for processing order

## Key Files

- workflow.json (293 lines) - Main workflow definition
- docs/LLM-PROCESSING-STATUS.md - Current implementation state
- docs/OLLAMA-SETUP.md - LLM model setup guide
- docs/QUEUE-MANAGEMENT.md - Processing queue details
- docs/LLM-PROCESSING-REFERENCE.md - Technical reference

## Data Flow

1. **Query Raw Notes** - SELECT unprocessed notes from raw_notes (status = NULL or 'pending')
2. **Prepare Prompt** - Format note content for LLM extraction
3. **Call Ollama API** - POST to http://localhost:11434/api/generate
4. **Parse Response** - Extract concepts, themes, keywords from JSON
5. **Store Results** - INSERT into processed_notes with extracted data
6. **Update Status** - Mark note as 'completed' or 'failed'

## Common Patterns

### Ollama API Call
```javascript
// HTTP Request to Ollama
const response = await fetch('http://localhost:11434/api/generate', {
    method: 'POST',
    headers: { 'Content-Type': 'application/json' },
    body: JSON.stringify({
        model: 'mistral:7b',
        prompt: `Extract concepts from: ${content}`,
        stream: false
    })
});
```

### LLM Prompt Template
```
Analyze this note and extract:
1. Main concepts (3-5 key ideas)
2. Themes (1-3 overarching topics)
3. Keywords (5-10 important terms)

Note: {content}

Return as JSON: {"concepts": [...], "themes": [...], "keywords": [...]}
```

### Queue Management
- Process notes in chronological order (ORDER BY created_at ASC)
- Limit batch size (e.g., LIMIT 10 per run)
- Skip already processed (WHERE status IS NULL OR status = 'pending')

### Error Handling
- LLM timeout → Set status = 'failed', retry_count++
- Parse error → Log raw response, set status = 'parse_error'
- Max retries (3) → Set status = 'failed_permanent'

## Testing

### Run Tests
```bash
cd workflows/02-llm-processing
# Note: Requires Ollama running locally
./scripts/test-with-markers.sh
```

### Prerequisites
```bash
# Ensure Ollama is running
ollama serve

# Verify mistral model is installed
ollama list | grep mistral
```

## Database Schema

**Table: processed_notes**
```sql
CREATE TABLE processed_notes (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    raw_note_id INTEGER NOT NULL,       -- Foreign key to raw_notes
    concepts TEXT,                       -- JSON array of concepts
    themes TEXT,                         -- JSON array of themes
    keywords TEXT,                       -- JSON array of keywords
    status TEXT,                         -- 'completed', 'failed', 'processing'
    processed_at DATETIME,
    test_run TEXT,
    FOREIGN KEY (raw_note_id) REFERENCES raw_notes(id)
);
```

## Do NOT

- **NEVER process without checking Ollama is running** - will fail silently
- **NEVER store raw LLM response** - extract and validate JSON first
- **NEVER process same note twice** - check status before queuing
- **NEVER use larger models** (13b, 70b) without testing performance
- **NEVER skip retry logic** - LLM calls can be flaky

## Known Issues

1. **Ollama Timeout on Long Notes** - Notes >5000 chars may timeout
   - Workaround: Truncate or chunk long notes

2. **JSON Parse Failures** - LLM sometimes returns invalid JSON
   - Current handling: Log and mark as 'parse_error'

## Related Context

@workflows/02-llm-processing/README.md
@workflows/02-llm-processing/docs/OLLAMA-SETUP.md
@database/schema.sql
@workflows/CLAUDE.md
