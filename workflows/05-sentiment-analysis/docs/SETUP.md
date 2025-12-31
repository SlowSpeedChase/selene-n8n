# Sentiment Analysis Workflow Setup Guide

## Quick Setup

### 1. Import the Workflow

1. **Open n8n web interface**: http://localhost:5678
2. **Login** with credentials: `admin` / `selene_n8n_2025`
3. **Import workflow**:
   - Click "+" → "Import from File"
   - Select: `workflows/05-sentiment-analysis/workflow.json`
   - Or drag and drop the file into n8n
4. **Save** the workflow

### 2. Activate the Workflow

- Toggle the switch in the top-right corner to **Active**
- The workflow will now run every 45 seconds automatically

### 3. Verify It's Running

```bash
# Check n8n logs for workflow activity
docker-compose logs n8n --tail=20 -f
# Look for: "Workflow 'Selene: Sentiment Analysis (Enhanced v2)' started"
# Press Ctrl+C to exit

# Check if notes are being processed
sqlite3 data/selene.db "SELECT COUNT(*) FROM processed_notes WHERE sentiment_analyzed = 0;"
# This number should decrease over time
```

---

## Technical Details

### Database Access

This workflow uses `better-sqlite3` directly in Function nodes (not the SQLite community node), matching the pattern used in the ingestion workflow.

**Why better-sqlite3?**
- No credentials configuration needed
- Direct file access: `/selene/data/selene.db`
- More reliable for read/write operations
- Consistent with other Selene workflows

**Docker volume mapping:**
```yaml
volumes:
  - ${SELENE_DATA_PATH:-./data}:/selene/data:rw
```

The database at `./data/selene.db` is mounted inside the container at `/selene/data/selene.db`.

### Node Configuration

**1. Get Unanalyzed Note** (Function node)
- Uses `better-sqlite3` in readonly mode
- Queries for notes where `sentiment_analyzed = 0`
- Returns one note at a time (LIMIT 1)
- Automatically closes database connection

**2. Store Enhanced Sentiment** (Function node)
- Uses `better-sqlite3` in read/write mode
- Updates `processed_notes` table
- Inserts into `sentiment_history` table
- Uses parameterized queries to prevent SQL injection

### Environment Variables

Required (already configured in docker-compose.yml):

```bash
NODE_FUNCTION_ALLOW_EXTERNAL=better-sqlite3
NODE_PATH=/home/node/.n8n/node_modules
SELENE_DB_PATH=/selene/data/selene.db
OLLAMA_BASE_URL=http://localhost:11434
OLLAMA_MODEL=mistral:7b
```

---

## Workflow Architecture

```
┌──────────────────┐
│  Every 45 Seconds│  (Cron trigger)
└────────┬─────────┘
         │
         ▼
┌─────────────────────────────┐
│  Get Unanalyzed Note        │  Function node with better-sqlite3
│  (better-sqlite3 query)     │  SELECT WHERE sentiment_analyzed = 0
└────────┬────────────────────┘
         │
         ▼
┌──────────────────┐
│   Has Note?      │  Switch node: check if note exists
└────────┬─────────┘
         │ (yes)
         ▼
┌────────────────────────────┐
│  Build Enhanced Prompt     │  Function node
│  - ADHD pattern detection  │  Creates system + user prompts
└────────┬───────────────────┘
         │
         ▼
┌────────────────────────────┐
│  Ollama: Sentiment Analysis│  HTTP Request node
│  - mistral:7b model        │  Calls local Ollama API
│  - Temperature: 0.35       │
└────────┬───────────────────┘
         │
         ▼
┌────────────────────────────┐
│  Parse Sentiment Results   │  Function node
│  - JSON parsing            │  Extracts sentiment data
│  - Fallback regex          │
└────────┬───────────────────┘
         │
         ▼
┌─────────────────────────────┐
│  Store Enhanced Sentiment   │  Function node with better-sqlite3
│  (better-sqlite3 update)    │  UPDATE + INSERT operations
└─────────────────────────────┘
```

---

## Testing the Setup

### Quick Test

```bash
# Run the automated test suite
./workflows/05-sentiment-analysis/tests/run-tests.sh
```

This will:
1. Send 8 test notes covering different ADHD patterns
2. Wait for processing (2-3 minutes)
3. Display sentiment analysis results
4. Show ADHD marker detection summary

### Manual Test

Send a single test note:

```bash
curl -X POST http://localhost:5678/webhook/api/drafts \
  -H "Content-Type: application/json" \
  -d '{
    "query": {
      "title": "Manual Test: Overwhelm",
      "content": "I have 15 different projects and cant focus. Everything feels urgent. Too much at once.",
      "timestamp": "'$(date -u +"%Y-%m-%dT%H:%M:%SZ")'"
    }
  }'
```

Wait ~2 minutes, then check results:

```bash
sqlite3 data/selene.db "
SELECT rn.title, pn.overall_sentiment, pn.emotional_tone,
       json_extract(pn.sentiment_data, '$.adhd_markers.overwhelm') as overwhelm
FROM processed_notes pn
JOIN raw_notes rn ON pn.raw_note_id = rn.id
WHERE pn.sentiment_analyzed = 1
ORDER BY pn.sentiment_analyzed_at DESC
LIMIT 1;" -header -column
```

Expected: `overwhelm` should be `true`

---

## Troubleshooting

### Issue: Workflow not processing notes

**Symptom:** Unanalyzed note count stays the same

**Check:**
```bash
# 1. Is workflow active in n8n?
# → Open http://localhost:5678, verify toggle is ON

# 2. Are there actually unanalyzed notes?
sqlite3 data/selene.db "SELECT COUNT(*) FROM processed_notes WHERE sentiment_analyzed = 0;"

# 3. Check for errors in n8n logs
docker-compose logs n8n --tail=50 | grep -i error
```

**Solution:**
- Ensure workflow is activated (toggle must be ON)
- Check that workflow 02 (LLM Processing) has run first
- Verify Ollama is running: `curl http://localhost:11434/api/tags`

### Issue: "Module 'better-sqlite3' not found"

**Symptom:** Function nodes fail with module not found error

**Check:**
```bash
docker-compose logs n8n | grep "better-sqlite3\|NODE_FUNCTION"
```

**Solution:**
Verify environment variables in `docker-compose.yml`:
```yaml
- NODE_FUNCTION_ALLOW_EXTERNAL=better-sqlite3
- NODE_PATH=/home/node/.n8n/node_modules
```

Restart n8n:
```bash
docker-compose restart n8n
```

### Issue: Database file not found

**Symptom:** Error: `ENOENT: no such file or directory, open '/selene/data/selene.db'`

**Check:**
```bash
# Verify database exists locally
ls -la data/selene.db

# Check volume mount
docker-compose exec n8n ls -la /selene/data/
```

**Solution:**
- Ensure `data/selene.db` exists in project root
- Verify volume mount in docker-compose.yml
- Check file permissions: `chmod 644 data/selene.db`

### Issue: Ollama connection failed

**Symptom:** HTTP request node fails to reach Ollama

**Check:**
```bash
# Test Ollama from host
curl http://localhost:11434/api/tags

# Test from container
docker-compose exec n8n curl http://host.docker.internal:11434/api/tags
```

**Solution:**
- Ensure Ollama is running on host
- Verify `extra_hosts` in docker-compose.yml includes `host.docker.internal:host-gateway`
- Check workflow uses: `http://host.docker.internal:11434` (not `localhost`)

### Issue: Low analysis confidence

**Symptom:** `analysis_confidence` consistently < 0.6

**Check:**
```bash
sqlite3 data/selene.db "
SELECT AVG(json_extract(sentiment_data, '$.analysis_confidence')) as avg_confidence
FROM processed_notes
WHERE sentiment_analyzed = 1;"
```

**If < 0.7, consider:**
1. **Adjust temperature**: Edit "Ollama: Enhanced Sentiment Analysis" node
   - Current: 0.35 (conservative)
   - Try: 0.4-0.5 (more nuanced)

2. **Increase token limit**: Change `num_predict` from 2000 to 2500

3. **Use larger model**:
   - Current: `mistral:7b`
   - Try: `llama2:13b` (slower but more accurate)

---

## Configuration Options

### Change Processing Interval

Default: **45 seconds**

To change:
1. Open workflow in n8n
2. Click "Every 45 Seconds" node
3. Edit → Change `secondsInterval`
4. Save workflow

Recommendations:
- **30 seconds**: Faster, more CPU usage
- **45 seconds**: Balanced (default)
- **60 seconds**: Slower, lower CPU

### Customize ADHD Detection Patterns

Edit the "Build Enhanced Sentiment Prompt" node:

1. Open workflow in n8n
2. Click "Build Enhanced Sentiment Prompt"
3. Edit the `systemPrompt` in the function code
4. Add/modify detection patterns
5. Save workflow

Example: Add rejection sensitivity detection
```javascript
⚡ REJECTION SENSITIVITY INDICATORS:
- Over-interpreting neutral feedback
- Anxiety about others' opinions
- Language: "they hate me", "I messed up everything"
```

### Change Ollama Model

Edit "Ollama: Enhanced Sentiment Analysis" node:

1. Current model: `mistral:7b`
2. Other options:
   - `llama2:7b` - Faster, simpler
   - `llama2:13b` - More accurate, slower
   - `mixtral:8x7b` - Best quality, much slower

Remember to pull the model first:
```bash
ollama pull llama2:13b
```

---

## Database Schema Reference

### processed_notes Table

```sql
sentiment_analyzed INTEGER DEFAULT 0,
sentiment_data TEXT,           -- Full JSON object
overall_sentiment TEXT,         -- positive|negative|neutral|mixed
sentiment_score REAL,           -- 0.0 - 1.0
emotional_tone TEXT,            -- calm|excited|anxious|etc.
energy_level TEXT,              -- high|medium|low
sentiment_analyzed_at DATETIME
```

### sentiment_history Table

```sql
processed_note_id INTEGER,
raw_note_id INTEGER,
overall_sentiment TEXT,
sentiment_score REAL,
emotional_tone TEXT,
energy_level TEXT,
stress_indicators INTEGER,      -- 0 or 1
key_emotions TEXT,             -- JSON array
adhd_markers TEXT,             -- JSON object
analysis_confidence REAL,      -- 0.0 - 1.0
analyzed_at DATETIME
```

---

## Performance Expectations

| Metric | Value |
|--------|-------|
| **Processing time per note** | 5-10 seconds |
| **Throughput** | ~80 notes/hour (at 45s interval) |
| **Memory usage** | ~100MB for workflow |
| **CPU usage** | Moderate (mostly Ollama) |
| **Database writes** | 2 per note (UPDATE + INSERT) |

---

## Next Steps

After setup:

1. ✅ Verify workflow is active and running
2. ✅ Process existing unanalyzed notes
3. ✅ Run test suite to validate ADHD detection
4. ⬜ Monitor accuracy over first 50-100 notes
5. ⬜ Tune prompts if needed based on results
6. ⬜ Enable Obsidian export (Workflow 04) to include sentiment

---

## Related Documentation

- [README.md](./README.md) - Full workflow documentation
- [tests/TESTING.md](./tests/TESTING.md) - Comprehensive testing guide
- [Workflow 02](../02-llm-processing/README.md) - Upstream dependency
- [Workflow 04](../04-obsidian-export/README.md) - Downstream consumer

---

**Questions?** Check the troubleshooting section or review n8n execution logs in the UI.
