# 05-Sentiment Analysis Workflow Context

## Purpose

Analyzes emotional tone and energy levels in notes using Ollama LLM. Tracks sentiment trends over time for ADHD-focused emotional awareness and energy management.

## Tech Stack

- Ollama HTTP API (mistral:7b model via `host.docker.internal:11434`)
- better-sqlite3 (direct access, no credentials)
- Cron trigger (every 45 seconds for batch processing)
- JSON parsing for LLM responses

## Key Files

- workflow.json (249 lines) - Main workflow using better-sqlite3
- README.md - Full workflow documentation
- SETUP.md - Import and activation guide
- tests/TESTING.md - Comprehensive testing guide
- tests/test-notes.json - 8 ADHD pattern test cases
- tests/run-tests.sh - Automated test runner

## Data Flow

1. **Cron Trigger** - Every 45 seconds, query for one unanalyzed note
2. **Query Note** - SELECT FROM processed_notes WHERE sentiment_analyzed = 0 LIMIT 1
3. **Prepare Prompt** - Format note content for sentiment analysis
4. **Call Ollama** - POST to `http://host.docker.internal:11434/api/generate`
5. **Parse Response** - Extract sentiment, energy level, confidence, emotion tags
6. **Store Results** - INSERT into sentiment_history + UPDATE processed_notes
7. **Log Success** - Console output for debugging

## Common Patterns

### Database Access (CRITICAL)
```javascript
// Always use better-sqlite3 in Function nodes (no credentials needed)
const Database = require('better-sqlite3');
const db = new Database('/selene/data/selene.db', { readonly: true }); // readonly for SELECT

const query = `SELECT * FROM processed_notes WHERE sentiment_analyzed = 0 LIMIT 1`;
const result = db.prepare(query).get();
db.close(); // Always close connection

return { json: result || { id: null } };
```

### IF Node for Null Checks (CRITICAL)
```javascript
// Use IF node (not Switch) for existence checks
{
  "type": "n8n-nodes-base.if",
  "conditions": {
    "boolean": [{
      "value1": "={{ $json.id != null && $json.id != undefined }}",
      "value2": true
    }]
  }
}
```

### Ollama API Call
```javascript
// Use host.docker.internal (not localhost) from Docker container
const response = await fetch('http://host.docker.internal:11434/api/generate', {
    method: 'POST',
    headers: { 'Content-Type': 'application/json' },
    body: JSON.stringify({
        model: 'mistral:7b',
        prompt: `Analyze emotional tone and energy level: ${content}
                 Return JSON: {"sentiment": "positive/negative/neutral",
                               "energy": "high/medium/low",
                               "confidence": 0.0-1.0,
                               "emotion_tags": [...]}`,
        stream: false
    })
});
```

### Database Write with Individual Fields
```javascript
// Store both JSON and extracted fields for fast queries
const db = new Database('/selene/data/selene.db'); // No readonly for writes

db.prepare(`
    INSERT INTO sentiment_history
    (note_id, sentiment_data, overall_sentiment, sentiment_score, emotional_tone, energy_level)
    VALUES (?, ?, ?, ?, ?, ?)
`).run(noteId, JSON.stringify(fullData), sentiment, score, tone, energy);

db.prepare('UPDATE processed_notes SET sentiment_analyzed = 1 WHERE id = ?').run(noteId);
db.close();
```

## Testing

### Run Tests
```bash
cd workflows/05-sentiment-analysis
./tests/run-tests.sh
```

### Prerequisites
```bash
# Ensure Ollama is running
ollama serve

# Verify mistral model
ollama list | grep mistral

# Check Docker environment
docker-compose exec n8n env | grep NODE_FUNCTION_ALLOW_EXTERNAL
```

### Test Checklist
- [ ] Test with unanalyzed notes in database
- [ ] Test with empty database (no notes to process)
- [ ] Verify IF node handles null values
- [ ] Check Ollama connection via host.docker.internal
- [ ] Validate sentiment_history inserts
- [ ] Verify ADHD markers detection
- [ ] Check average confidence > 0.7

## Database Schema

**Table: sentiment_history**
```sql
CREATE TABLE sentiment_history (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    note_id INTEGER NOT NULL,
    sentiment_data TEXT,             -- Full JSON for future analysis
    overall_sentiment TEXT,          -- 'positive', 'negative', 'neutral'
    sentiment_score REAL,            -- -1.0 to 1.0
    emotional_tone TEXT,             -- Descriptive tone
    energy_level TEXT,               -- 'high', 'medium', 'low' (ADHD focus)
    analysis_confidence REAL,        -- 0.0 to 1.0
    created_at DATETIME DEFAULT CURRENT_TIMESTAMP,
    test_run TEXT,
    FOREIGN KEY (note_id) REFERENCES processed_notes(id)
);
```

## Architecture Decisions

### Why Cron Trigger?
- Batch processing (one note at a time)
- Natural rate limiting (45-second intervals = ~80 notes/hour)
- No external dependencies
- Automatic queue processing
- Resilient to Ollama downtime

### Why LIMIT 1?
- Prevents Ollama timeout on large batches
- Each analysis takes 5-10 seconds
- Cron interval allows completion before next run
- FIFO queue (ORDER BY processed_at DESC)

### Why Store Both JSON and Fields?
- **sentiment_data** (JSON) - Complete data for future analysis
- **Individual fields** - Fast queries without JSON parsing
- **Backwards compatible** - Add JSON fields without schema changes
- **Obsidian export** - Individual fields easy for frontmatter

## ADHD-Specific Features

### Energy Tracking
- **High energy** - Productive periods, optimal for complex tasks
- **Low energy** - Rest needed, avoid demanding work
- **Patterns** - Weekly/monthly trends inform scheduling

### Emotional Awareness
- **Sentiment trends** - Track mood over time
- **Trigger identification** - Correlate negative sentiment with topics
- **Positive reinforcement** - Highlight wins

## Do NOT

- **NEVER use SQLite community nodes** - Use better-sqlite3 in Function nodes
- **NEVER use Switch node for null checks** - Use IF node with explicit checks
- **NEVER use localhost for Ollama** - Use host.docker.internal from Docker
- **NEVER skip database connection close** - Always call db.close()
- **NEVER use string concatenation for SQL** - Use parameterized queries
- **NEVER skip energy level extraction** - Critical for ADHD users

## Docker Configuration

### Required in docker-compose.yml
```yaml
environment:
  - NODE_FUNCTION_ALLOW_EXTERNAL=better-sqlite3
  - OLLAMA_BASE_URL=http://host.docker.internal:11434

extra_hosts:
  - "host.docker.internal:host-gateway"

volumes:
  - ./data:/selene/data:rw
```

## Troubleshooting

### Module Not Found Error
```
Error: Cannot find module 'better-sqlite3'
```
**Solution:** Add `NODE_FUNCTION_ALLOW_EXTERNAL=better-sqlite3` to environment, restart

### Database Permission Denied
```bash
chmod 644 data/selene.db
chmod 755 data/
```

### Ollama Connection Fails
- Check `host.docker.internal` in URL (not `localhost`)
- Verify `extra_hosts` in docker-compose.yml
- Test: `curl http://host.docker.internal:11434/api/tags`

## Related Context

@workflows/05-sentiment-analysis/README.md
@workflows/05-sentiment-analysis/SETUP.md
@workflows/02-llm-processing/CLAUDE.md
@database/schema.sql
@workflows/CLAUDE.md
