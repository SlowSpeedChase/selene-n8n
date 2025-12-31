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

- workflow.json - Main workflow definition (webhook-triggered)
- docs/STATUS.md - Test results and current state
- docs/OLLAMA-SETUP.md - LLM model setup guide
- docs/QUEUE-MANAGEMENT.md - Processing queue details
- docs/LLM-PROCESSING-REFERENCE.md - Technical reference
- scripts/test-with-markers.sh - Automated test suite
- scripts/reset-stuck-notes.sh - Reset processing state

## Trigger

**Webhook:** `POST http://localhost:5678/webhook/api/process-note`
**Payload:** `{"noteId": <integer>}`

## Data Flow

1. **Receive Webhook** - Get noteId from POST payload
2. **Lock Note** - Mark as 'processing' to prevent duplicates
3. **Build Concept Prompt** - Detect note type, create context-aware prompt
4. **Call Ollama** - POST to http://host.docker.internal:11434/api/generate
5. **Parse Concepts** - Extract concepts with confidence scores
6. **Build Theme Prompt** - Create theme detection prompt
7. **Call Ollama** - Detect primary and secondary themes
8. **Parse Themes** - Extract themes with confidence
9. **Update Database** - INSERT to processed_notes, UPDATE raw_notes status
10. **Trigger Sentiment** - Call sentiment analysis webhook

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

1. **No HTTP Error Response for Invalid Notes**
   - Workflow throws internal error but returns HTTP 200
   - Workaround: Check database status after calling webhook

2. **Ollama Timeout on Long Notes** - Notes >5000 chars may timeout
   - Workaround: Truncate or chunk long notes

3. **JSON Parse Failures** - LLM sometimes returns invalid JSON
   - Current handling: Fallback parsing attempts

## Related Context

@workflows/02-llm-processing/README.md
@workflows/02-llm-processing/docs/OLLAMA-SETUP.md
@database/schema.sql
@workflows/CLAUDE.md
