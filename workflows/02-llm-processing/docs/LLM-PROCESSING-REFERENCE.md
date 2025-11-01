# LLM Processing Quick Reference

## Quick Facts

| Property | Value |
|----------|-------|
| **Workflow Name** | Selene: LLM Processing |
| **Purpose** | Extract concepts and themes from notes using AI |
| **Trigger** | Cron (every 30 seconds) |
| **Processing Rate** | 1 note per execution |
| **LLM Required** | Yes (Ollama) |
| **Default Model** | mistral:7b |
| **Database Tables** | `raw_notes` (read), `processed_notes` (write) |
| **Average Processing Time** | 5-15 seconds per note |

---

## Workflow Nodes Overview

### 1. Every 30 Seconds
- **Type:** Cron Trigger
- **Purpose:** Triggers workflow at regular intervals
- **Configuration:** 30-second interval (adjustable)

### 2. Get Pending Note
- **Type:** Function (SQLite)
- **Purpose:** Query for the oldest pending note
- **Query:**
  ```sql
  SELECT id, title, content, created_at
  FROM raw_notes
  WHERE status = 'pending'
  ORDER BY created_at ASC
  LIMIT 1
  ```

### 3. Has Pending Notes?
- **Type:** Switch
- **Purpose:** Check if a pending note exists
- **Condition:** `$json.id` exists

### 4. Build Concept Extraction Prompt
- **Type:** Function
- **Purpose:** Detect note type and build LLM prompt for concept extraction
- **Output:** System prompt, user prompt, note metadata

### 5. Ollama: Extract Concepts
- **Type:** HTTP Request
- **URL:** `http://host.docker.internal:11434/api/generate`
- **Method:** POST
- **Timeout:** 60 seconds
- **Purpose:** Extract 3-5 key concepts using LLM

### 6. Parse Concepts
- **Type:** Function
- **Purpose:** Parse JSON response and extract concepts with confidence scores
- **Fallback:** Text parsing if JSON fails

### 7. Build Theme Detection Prompt
- **Type:** Function
- **Purpose:** Build LLM prompt for theme classification
- **Standard Vocabulary:** 20 predefined themes

### 8. Ollama: Detect Themes
- **Type:** HTTP Request
- **URL:** `http://host.docker.internal:11434/api/generate`
- **Method:** POST
- **Timeout:** 60 seconds
- **Purpose:** Classify note into primary and secondary themes

### 9. Parse Themes
- **Type:** Function
- **Purpose:** Parse theme response and combine with concepts
- **Fallback:** Default theme if parsing fails

### 10. Update Processed Note
- **Type:** Function (SQLite)
- **Purpose:** Insert results into `processed_notes` and update `raw_notes` status
- **Operations:**
  - UPDATE `raw_notes` SET `status='processed'`
  - INSERT into `processed_notes`

### 11. Build Completion Response
- **Type:** Function
- **Purpose:** Generate success message with processing summary

---

## Database Schema

### raw_notes Table (Read)

```sql
CREATE TABLE raw_notes (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    title TEXT NOT NULL,
    content TEXT NOT NULL,
    status TEXT DEFAULT 'pending',  -- Updated to 'processed'
    created_at DATETIME NOT NULL,
    imported_at DATETIME DEFAULT CURRENT_TIMESTAMP,
    processed_at DATETIME,  -- Set when processed
    -- ... other fields
);
```

### processed_notes Table (Write)

```sql
CREATE TABLE processed_notes (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    raw_note_id INTEGER NOT NULL,
    concepts TEXT,  -- JSON array: ["concept1", "concept2", ...]
    concept_confidence TEXT,  -- JSON object: {"concept1": 0.95, ...}
    primary_theme TEXT,  -- Single theme string
    secondary_themes TEXT,  -- JSON array: ["theme1", "theme2"]
    theme_confidence REAL,  -- 0.0 to 1.0
    processed_at DATETIME DEFAULT CURRENT_TIMESTAMP,
    FOREIGN KEY (raw_note_id) REFERENCES raw_notes(id)
);
```

---

## Note Types

The workflow detects these note types automatically:

| Note Type | Keywords/Patterns | Context Focus |
|-----------|-------------------|---------------|
| **meeting** | meeting, met with, discussed, action items | Decisions, action items, people, topics |
| **technical** | docker, api, database, code, git, python | Technologies, tools, methods, solutions |
| **idea** | idea, concept, what if, brainstorm | Core idea, implementation, challenges |
| **personal** | i feel, my goal, personally, overwhelmed | Activities, goals, challenges, actionable items |
| **task** | todo, must do, deadline, task | Main task, subtasks, people, deadlines |
| **reflection** | learned, realized, thinking about | Lessons learned, insights, improvements |
| **general** | (default) | Main topics, subjects, key points |

---

## Standard Theme Vocabulary

Primary and secondary themes are selected from this vocabulary:

```
work            meeting         project         task
personal        health          learning        reflection
idea            problem_solving planning        technical
tools           process         communication   collaboration
feedback        improvement     decision        notes
```

Themes are automatically normalized to lowercase with underscores replacing spaces.

---

## Ollama API Reference

### Request Format

```json
{
  "model": "mistral:7b",
  "prompt": "User prompt text here",
  "system": "System instructions here",
  "stream": false,
  "options": {
    "temperature": 0.3,
    "num_predict": 2000
  }
}
```

### Response Format

```json
{
  "model": "mistral:7b",
  "created_at": "2025-10-30T12:00:00Z",
  "response": "LLM generated text here",
  "done": true,
  "context": [...],
  "total_duration": 5000000000,
  "load_duration": 100000000,
  "prompt_eval_count": 50,
  "eval_count": 200,
  "eval_duration": 4800000000
}
```

---

## Expected JSON Formats

### Concept Extraction Response

```json
{
  "concepts": ["concept1", "concept2", "concept3"],
  "confidence_scores": {
    "concept1": 0.95,
    "concept2": 0.85,
    "concept3": 0.75
  }
}
```

### Theme Detection Response

```json
{
  "primary_theme": "technical",
  "secondary_themes": ["tools", "problem_solving"],
  "confidence": 0.88
}
```

---

## Common Queries

### Check Pending Notes

```bash
sqlite3 data/selene.db "
SELECT COUNT(*) as pending_count
FROM raw_notes
WHERE status = 'pending';
"
```

### View Recently Processed Notes

```bash
sqlite3 data/selene.db "
SELECT
  r.id,
  r.title,
  r.status,
  r.processed_at,
  p.primary_theme,
  p.concepts
FROM raw_notes r
LEFT JOIN processed_notes p ON r.id = p.raw_note_id
WHERE r.status = 'processed'
ORDER BY r.processed_at DESC
LIMIT 10;
"
```

### Get Processing Statistics

```bash
sqlite3 data/selene.db "
SELECT
  COUNT(*) as total_processed,
  COUNT(DISTINCT primary_theme) as unique_themes,
  AVG(theme_confidence) as avg_confidence,
  MIN(processed_at) as first_processed,
  MAX(processed_at) as last_processed
FROM processed_notes;
"
```

### Find Notes by Theme

```bash
sqlite3 data/selene.db "
SELECT
  r.title,
  p.primary_theme,
  p.concepts
FROM processed_notes p
JOIN raw_notes r ON p.raw_note_id = r.id
WHERE p.primary_theme = 'technical'
ORDER BY p.processed_at DESC
LIMIT 5;
"
```

### Find Notes by Concept

```bash
sqlite3 data/selene.db "
SELECT
  r.id,
  r.title,
  p.concepts
FROM processed_notes p
JOIN raw_notes r ON p.raw_note_id = r.id
WHERE p.concepts LIKE '%Docker%'
ORDER BY p.processed_at DESC;
"
```

### Check Processing Performance

```bash
sqlite3 data/selene.db "
SELECT
  COUNT(*) as notes_processed,
  AVG((JULIANDAY(processed_at) - JULIANDAY(imported_at)) * 24 * 60) as avg_processing_minutes,
  MIN(processed_at) as oldest,
  MAX(processed_at) as newest
FROM raw_notes
WHERE status = 'processed'
  AND processed_at IS NOT NULL;
"
```

---

## Test Commands

### Check Ollama Service

```bash
# Health check
curl http://localhost:11434/api/tags

# List available models
curl http://localhost:11434/api/tags | jq '.models[].name'
```

### Test Ollama from Docker Container

```bash
# Check connectivity from inside n8n container
docker exec -it selene-n8n sh -c "wget -qO- http://host.docker.internal:11434/api/tags"
```

### Test Concept Extraction

```bash
curl -X POST http://localhost:11434/api/generate \
  -H "Content-Type: application/json" \
  -d '{
    "model": "mistral:7b",
    "prompt": "Extract the key concepts from this text: Docker is a containerization platform for developers.",
    "stream": false,
    "options": {"temperature": 0.3, "num_predict": 500}
  }'
```

### Manually Trigger Processing

In n8n UI:
1. Open workflow
2. Click "Test workflow" button
3. View execution results

### Reset Note to Pending (for re-processing)

```bash
sqlite3 data/selene.db "
UPDATE raw_notes
SET status = 'pending', processed_at = NULL
WHERE id = 1;
"
```

---

## Configuration Parameters

### Ollama Settings

| Parameter | Default | Options | Description |
|-----------|---------|---------|-------------|
| model | mistral:7b | llama3.2:3b, mistral:7b, llama3.1:8b | LLM model to use |
| temperature | 0.3 | 0.0 - 1.0 | Randomness (lower = more focused) |
| num_predict | 2000 (concepts), 1000 (themes) | 100 - 4096 | Max tokens to generate |
| stream | false | true, false | Stream response (always false) |
| timeout | 60000ms | 10000 - 120000ms | Request timeout |

### Processing Settings

| Parameter | Default | Description |
|-----------|---------|-------------|
| Cron Interval | 30 seconds | How often to check for pending notes |
| Batch Size | 1 note | Notes processed per execution |
| Max Concepts | 5 | Maximum concepts to extract |
| Max Secondary Themes | 2 | Maximum secondary themes |

---

## Error Messages

### Connection Errors

| Error | Cause | Solution |
|-------|-------|----------|
| ECONNREFUSED | Ollama not running | Start Ollama: `ollama serve` |
| Timeout | LLM response too slow | Use faster model or increase timeout |
| 404 Not Found | Model not downloaded | `ollama pull mistral:7b` |
| Network unreachable | Docker networking issue | Check `host.docker.internal` configuration |

### Database Errors

| Error | Cause | Solution |
|-------|-------|----------|
| Database is locked | Concurrent access | Wait and retry, check for other processes |
| Table doesn't exist | Schema not initialized | Run schema creation script |
| Foreign key constraint | Data integrity issue | Check `raw_note_id` exists |
| Unique constraint | Duplicate entry | This shouldn't happen; check workflow logic |

### Processing Errors

| Error | Cause | Solution |
|-------|-------|----------|
| Invalid JSON | LLM returned non-JSON | Workflow uses fallback parsing |
| Empty concepts | Parsing failed completely | Check LLM response in execution log |
| Low confidence | Content ambiguous | Review note content, may be normal |
| Incorrect theme | Model misclassification | Try different model or adjust prompt |

---

## Performance Metrics

### Expected Processing Times (per note)

| Model | Avg Time | Concepts Accuracy | Themes Accuracy |
|-------|----------|-------------------|-----------------|
| llama3.2:3b | 2-5 seconds | Good (75-85%) | Good (80-90%) |
| mistral:7b | 5-10 seconds | Excellent (85-95%) | Excellent (90-95%) |
| llama3.1:8b | 10-20 seconds | Excellent (90-98%) | Excellent (92-98%) |

Times depend on:
- CPU/GPU available
- Note length
- System load
- Model size

### Throughput

With default settings (30-second interval, 1 note per execution):
- **Maximum:** 120 notes/hour
- **Typical:** 60-100 notes/hour (accounting for processing time)

To increase throughput:
- Reduce cron interval (e.g., 15 seconds)
- Increase batch size (process multiple notes per execution)
- Use faster model (llama3.2:3b)

---

## Workflow Maintenance

### Weekly Tasks

```bash
# Check processing status
sqlite3 data/selene.db "
SELECT
  status,
  COUNT(*) as count
FROM raw_notes
GROUP BY status;
"

# Check for stuck notes (pending > 24 hours)
sqlite3 data/selene.db "
SELECT id, title, imported_at
FROM raw_notes
WHERE status = 'pending'
  AND imported_at < datetime('now', '-1 day');
"
```

### Monthly Tasks

```bash
# Database maintenance
sqlite3 data/selene.db "VACUUM;"
sqlite3 data/selene.db "ANALYZE;"

# Check theme distribution
sqlite3 data/selene.db "
SELECT
  primary_theme,
  COUNT(*) as count
FROM processed_notes
GROUP BY primary_theme
ORDER BY count DESC;
"
```

### Quality Audits

```bash
# Review low-confidence results
sqlite3 data/selene.db "
SELECT
  r.title,
  p.primary_theme,
  p.theme_confidence,
  p.concepts
FROM processed_notes p
JOIN raw_notes r ON p.raw_note_id = r.id
WHERE p.theme_confidence < 0.5
ORDER BY p.theme_confidence ASC
LIMIT 10;
"
```

---

## Integration Points

### Upstream (Input)

**Source:** 01-ingestion workflow
- Creates `raw_notes` with `status='pending'`
- Provides `title`, `content`, `created_at`

### Downstream (Output)

**Consumed by:**

1. **03-pattern-detection**
   - Uses `primary_theme`, `concepts` for trend analysis

2. **04-obsidian-export**
   - Exports notes with extracted metadata

3. **05-sentiment-analysis**
   - Analyzes emotional context of processed notes

4. **06-connection-network**
   - Builds concept graphs from `concepts` data

---

## Customization Examples

### Add Custom Note Type

Edit "Build Concept Extraction Prompt" node:

```javascript
function detectNoteType(text) {
  const lower = text.toLowerCase();

  // Add custom type
  if (/(recipe|cooking|ingredients|bake)/i.test(lower)) {
    return 'recipe';
  }

  // ... existing types
}

// Add custom context guidance
const contextGuidance = {
  recipe: 'RECIPE CONTEXT: Focus on ingredients, cooking methods, cuisine type, dietary tags.',
  // ... existing guidance
};
```

### Filter Processing by Source

Edit "Get Pending Note" node:

```javascript
const query = `SELECT id, title, content, created_at
              FROM raw_notes
              WHERE status = 'pending'
                AND source_type = 'drafts'  -- Only process Drafts notes
              ORDER BY created_at ASC
              LIMIT 1`;
```

### Add Retry Logic

Add new node after "Parse Concepts":

```javascript
const concepts = $json.concepts || [];

if (concepts.length === 0) {
  // No concepts extracted, mark for retry
  return {
    json: {
      retry: true,
      noteId: $json.noteId,
      reason: 'No concepts extracted'
    }
  };
}

// Continue normal processing
return { json: $json };
```

---

## Resources

- **Workflow File:** `/workflows/02-llm-processing/workflow.json`
- **Setup Guide:** `LLM-PROCESSING-SETUP.md`
- **Ollama Docs:** https://ollama.ai/docs
- **n8n Function Nodes:** https://docs.n8n.io/integrations/builtin/core-nodes/n8n-nodes-base.function/
- **SQLite JSON Functions:** https://www.sqlite.org/json1.html
