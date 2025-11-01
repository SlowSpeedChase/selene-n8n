# 02-LLM-Processing_Apple Workflow

**Status:** ✅ Complete and Documented
**Version:** 2.0 (Simplified)
**Last Updated:** October 31, 2025

## Overview

The Apple Intelligence LLM Processing workflow provides an alternative to Ollama by using Apple's local AI models through Apple Shortcuts. It processes notes using the same concept extraction, theme detection, and sentiment analysis as the Ollama workflow, allowing for direct comparison between the two AI systems.

**What makes this special:** The Apple Shortcut is SIMPLE (only 10 actions). All the complex parsing happens in n8n, making it easy to set up and maintain.

**What it does:**
- Provides REST API endpoints for Apple Shortcuts integration
- Pulls pending notes from the database via webhook
- Builds ONE combined prompt requesting all three analyses
- Receives raw AI response from Apple Shortcut
- Parses and extracts concepts, themes, and sentiment in n8n
- Saves processed results to a separate `processed_notes_apple` table
- Enables comparison between Ollama and Apple Intelligence results

---

## Quick Start

### Prerequisites

1. **n8n running** at http://localhost:5678
2. **Database migrated** with `processed_notes_apple` table
3. **Apple device** with Shortcuts app (iOS 18+ or macOS 15+)
4. **Apple Intelligence** or ChatGPT integration enabled
5. **Pending notes** marked as `status_apple='pending_apple'`

### Setup Steps

1. **Import workflow to n8n:**
   - Open http://localhost:5678
   - Import `workflow.json`

2. **Activate the workflow:**
   - Toggle "Active" in n8n UI

3. **Set up Apple Shortcut:**
   - Follow the guide: [APPLE-SHORTCUT-SETUP.md](docs/APPLE-SHORTCUT-SETUP.md)

4. **Run the shortcut:**
   - Manually or via automation
   - Monitor results in database

---

## Architecture

### Simplified Pull-Based Processing Model

Unlike Ollama's push model (n8n triggers Ollama), Apple uses a simplified pull model:

```
[Apple Shortcut Runs] (10 actions total!)
    ↓
GET /api/apple/get-pending-note
    ↓
n8n: Query DB for pending_apple notes
    ↓
n8n: Build ONE combined prompt (concepts + themes + sentiment)
    ↓
n8n: Lock note (status → processing_apple)
    ↓
n8n: Return {noteId, prompt}  ← Simple response
    ↓
[Shortcut asks Apple Intelligence ONCE]
    ↓
POST /api/apple/save-processed-note with {noteId, rawResponse}
    ↓
n8n: Parse raw response (handles JSON or text)
    ↓
n8n: Extract concepts, themes, sentiment
    ↓
n8n: Save to processed_notes_apple
    ↓
n8n: Update status → processed_apple
```

**Key Innovation:** Shortcut just passes raw AI output. n8n does ALL parsing!

### Comparison: Ollama vs Apple

| Feature | Ollama Workflow | Apple Workflow |
|---------|----------------|----------------|
| **Trigger** | Cron (auto) | Manual/Automation |
| **Model** | Push (n8n → Ollama) | Pull (Shortcut → n8n) |
| **Processing** | Server-side | Client-side (Apple device) |
| **Speed** | 5-10s per note | 30-60s per note |
| **Table** | `processed_notes` | `processed_notes_apple` |
| **Status** | `pending` → `processed` | `pending_apple` → `processed_apple` |

---

## Workflow Nodes

### Webhook 1: Get Pending Note

**Endpoint:** `GET /api/apple/get-pending-note`

**Purpose:** Returns the next pending note with ONE combined prompt

**Response (when notes exist):**
```json
{
  "noteId": 123,
  "title": "Example Note",
  "content": "Full note content...",
  "noteType": "technical",
  "hasPendingNotes": true,
  "prompt": "You are an expert note analysis AI. Analyze the following note and provide a comprehensive analysis in THREE parts:\n\nThis is a TECHNICAL note. Focus on technologies, tools, methods, problems, solutions, and technical concepts discussed.\n\n## PART 1: CONCEPT EXTRACTION\nExtract 3-5 of the most important concepts from the text.\n- Focus on concrete topics, themes, and subjects discussed\n- Concepts should be 1-4 words each\n- Provide confidence scores (0.0-1.0) for each concept\n\n## PART 2: THEME DETECTION\nIdentify themes from this note.\n- ONE primary theme\n- 1-2 secondary themes\n- Use these standard themes when possible: work, meeting, project, task, personal, health, learning, reflection, idea, problem_solving, planning, technical, tools, process, communication, collaboration, feedback, improvement, decision, notes\n- Provide overall theme confidence score\n\n## PART 3: SENTIMENT ANALYSIS\nAnalyze the emotional tone and sentiment.\n- Overall sentiment: positive, negative, or neutral\n- Sentiment score: -1.0 to 1.0\n- Emotional tone\n- Energy level: high, medium, or low\n\n## NOTE TO ANALYZE:\n\n[note content here]\n\n## REQUIRED OUTPUT FORMAT:\n\nReturn ONLY valid JSON in this EXACT format:\n\n{\n  \"concepts\": [\"concept1\", \"concept2\", \"concept3\"],\n  \"concept_confidence\": {\"concept1\": 0.95, \"concept2\": 0.85},\n  \"primary_theme\": \"technical\",\n  \"secondary_themes\": [\"tools\", \"learning\"],\n  \"theme_confidence\": 0.87,\n  \"overall_sentiment\": \"positive\",\n  \"sentiment_score\": 0.7,\n  \"emotional_tone\": \"motivated\",\n  \"energy_level\": \"high\"\n}"
}
```

**Response (no pending notes):**
```json
{
  "message": "No pending notes for Apple processing",
  "hasPendingNotes": false,
  "timestamp": "2025-10-31T12:00:00.000Z"
}
```

**Node Flow:**
1. `Webhook: Get Pending Note` - Receives GET request
2. `Get Note and Lock` - Queries DB for `status_apple='pending_apple'`, locks with `'processing_apple'`
3. `Check if Note Found` - Branches based on whether note exists
4. `Build Combined Prompt` - Creates ONE mega-prompt for all 3 analyses
5. `Respond with Note and Prompt` - Returns JSON to Shortcut

### Webhook 2: Save Processed Note

**Endpoint:** `POST /api/apple/save-processed-note`

**Purpose:** Receives raw AI response and parses it

**Request Body (Simplified!):**
```json
{
  "noteId": 123,
  "rawResponse": "{\n  \"concepts\": [\"productivity\", \"workflows\", \"automation\"],\n  \"concept_confidence\": {\"productivity\": 0.95, \"workflows\": 0.88, \"automation\": 0.82},\n  \"primary_theme\": \"technical\",\n  \"secondary_themes\": [\"tools\", \"learning\"],\n  \"theme_confidence\": 0.87,\n  \"overall_sentiment\": \"positive\",\n  \"sentiment_score\": 0.7,\n  \"emotional_tone\": \"motivated\",\n  \"energy_level\": \"high\"\n}"
}
```

**Note:** The Shortcut just passes whatever Apple Intelligence returned. n8n handles:
- Stripping markdown code blocks (```json)
- Parsing JSON
- Fallback text extraction if JSON fails
- Extracting all fields into database format

**Response:**
```json
{
  "success": true,
  "processed_id": 42,
  "noteId": 123,
  "message": "Note 123 processed successfully with Apple Intelligence"
}
```

**Node Flow:**
1. `Webhook: Save Processed Note` - Receives POST request with `{noteId, rawResponse}`
2. `Parse AI Response` - Extracts concepts, themes, sentiment from raw text (handles JSON or fallback)
3. `Save to Database` - Validates note state, inserts into `processed_notes_apple`, updates `status_apple='processed_apple'`
4. `Respond: Save Success` - Returns success confirmation with extracted data

---

## Database

### Input: raw_notes

Query for pending Apple notes:
```sql
SELECT id, title, content, created_at
FROM raw_notes
WHERE status_apple = 'pending_apple'
ORDER BY created_at ASC
LIMIT 1
```

### Output: processed_notes_apple

Insert processed results:
```sql
INSERT INTO processed_notes_apple (
  raw_note_id, concepts, concept_confidence,
  primary_theme, secondary_themes, theme_confidence,
  sentiment_analyzed, sentiment_data, overall_sentiment,
  sentiment_score, emotional_tone, energy_level,
  sentiment_analyzed_at, processed_at, processing_model
) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
```

### Status Updates

```sql
-- Lock note for processing
UPDATE raw_notes
SET status_apple = 'processing_apple'
WHERE id = ? AND status_apple = 'pending_apple'

-- Mark as completed
UPDATE raw_notes
SET status_apple = 'processed_apple',
    processed_at_apple = datetime('now')
WHERE id = ?
```

---

## Apple Shortcut Integration

### Required Shortcut Actions (Only 10!)

1. **GET Contents of URL** - Fetch pending note with combined prompt
2. **Get Dictionary from Input** - Parse response
3. **If** - Check if notes exist
4. **Get Dictionary Value** (2x) - Extract noteId and prompt
5. **Ask ChatGPT/Apple Intelligence** (1x) - Process combined prompt ONCE
6. **Dictionary** - Build `{noteId, rawResponse}`
7. **POST Contents of URL** - Save raw response
8. **Show Notification** - Success message

**That's it! Super simple.**

See detailed guide: [APPLE-SHORTCUT-SETUP.md](docs/APPLE-SHORTCUT-SETUP.md)

---

## Testing

### Manual Testing

1. **Test GET endpoint:**
   ```bash
   curl http://localhost:5678/webhook/api/apple/get-pending-note
   ```

2. **Create test note:**
   ```bash
   curl -X POST http://localhost:5678/webhook/api/ingest \
     -H "Content-Type: application/json" \
     -d '{"title": "Test Note", "content": "This is a test note about productivity and workflows."}'
   ```

3. **Check pending notes:**
   ```bash
   sqlite3 data/selene.db "SELECT id, title, status_apple FROM raw_notes WHERE status_apple = 'pending_apple';"
   ```

4. **Run Apple Shortcut** and verify success

5. **Check results:**
   ```bash
   sqlite3 data/selene.db "
   SELECT
     pna.id,
     pna.raw_note_id,
     pna.concepts,
     pna.primary_theme,
     pna.overall_sentiment
   FROM processed_notes_apple pna
   ORDER BY pna.processed_at DESC
   LIMIT 1;
   "
   ```

### Comparison Query

Compare Ollama vs Apple results:
```sql
SELECT
  rn.id,
  rn.title,
  pn.concepts AS ollama_concepts,
  pn.primary_theme AS ollama_theme,
  pna.concepts AS apple_concepts,
  pna.primary_theme AS apple_theme
FROM raw_notes rn
LEFT JOIN processed_notes pn ON rn.id = pn.raw_note_id
LEFT JOIN processed_notes_apple pna ON rn.id = pna.raw_note_id
WHERE pn.id IS NOT NULL AND pna.id IS NOT NULL
ORDER BY rn.created_at DESC
LIMIT 10;
```

---

## Configuration

### Workflow Settings

| Setting | Value |
|---------|-------|
| Processing Trigger | Manual (via Apple Shortcut) |
| Model | Apple Intelligence / ChatGPT |
| Status Field | `status_apple` |
| Output Table | `processed_notes_apple` |
| Webhook Timeout | 300 seconds |

### Apple Shortcut Settings

| Setting | Recommendation |
|---------|---------------|
| Run Frequency | Hourly or on-demand |
| Timeout per Note | 60-90 seconds |
| Automation Trigger | Time of Day / Location |
| Error Handling | Show notification on failure |

---

## Performance

### Expected Processing Times

| Step | Duration |
|------|----------|
| GET pending note | < 1 second |
| Concepts extraction | 10-20 seconds |
| Theme detection | 10-15 seconds |
| Sentiment analysis | 10-15 seconds |
| POST save results | < 1 second |
| **Total per note** | **30-60 seconds** |

### Throughput

- **Manual:** 1-2 notes per minute
- **Automated (hourly):** 60-120 notes per hour
- **Batch mode:** Process until no pending notes remain

---

## Troubleshooting

### No Pending Notes

**Symptoms:** GET always returns `hasPendingNotes: false`

**Solutions:**
- Verify 01-ingestion is setting `status_apple='pending_apple'`
- Check if notes were already processed
- Query: `SELECT COUNT(*) FROM raw_notes WHERE status_apple = 'pending_apple';`

### Shortcut Cannot Connect

**Symptoms:** "Could not connect to server" error

**Solutions:**
- Verify n8n is running: `curl http://localhost:5678/healthz`
- Check workflow is active in n8n UI
- Ensure device is on same network as n8n
- Try IP address instead of localhost: `http://192.168.x.x:5678`

### Invalid JSON from Apple Intelligence

**Symptoms:** Shortcut fails to parse AI response

**Solutions:**
- The prompts explicitly request JSON-only output
- Add error handling in Shortcut to strip markdown code blocks
- Use "Get Dictionary from Input" with fallback logic
- Consider reducing prompt complexity

### Note Stuck in "processing_apple"

**Symptoms:** Note never completes processing

**Solutions:**
- Shortcut may have crashed or timed out
- Reset status manually:
  ```sql
  UPDATE raw_notes
  SET status_apple = 'pending_apple'
  WHERE status_apple = 'processing_apple';
  ```

---

## Integration

### Upstream
- **01-ingestion:** Marks notes as `status_apple='pending_apple'`

### Downstream
- **03-pattern-detection:** Can analyze Apple-processed notes
- **04-obsidian-export:** Can export with Apple metadata
- **Comparison tools:** Compare Ollama vs Apple results

---

## Files

```
02-llm-processing_apple/
├── workflow.json                          # n8n workflow (10 nodes)
├── README.md                              # This file
└── docs/
    └── APPLE-SHORTCUT-SETUP.md           # Detailed Shortcut setup guide
```

---

## Next Steps

1. **Read APPLE-SHORTCUT-SETUP.md** for complete Shortcut instructions
2. **Import and activate the workflow** in n8n
3. **Create and test the Apple Shortcut**
4. **Process some notes** and verify quality
5. **Compare results** with Ollama processing
6. **Set up automation** for periodic processing

---

## Resources

- **n8n UI:** http://localhost:5678
- **Database:** `/data/selene.db`
- **Ollama Workflow:** `/workflows/02-llm-processing/`
- **Migration:** `/database/migrations/003_add_apple_intelligence.sql`

---

## Comparison Benefits

Having both Ollama and Apple Intelligence processing allows you to:

1. **Evaluate accuracy** - Compare which model extracts better concepts
2. **Test consistency** - See if both models identify similar themes
3. **Benchmark speed** - Measure processing time differences
4. **Choose best model** - Use results to inform future decisions
5. **Ensemble approach** - Combine results from both models for higher confidence

---

**Ready to process notes with Apple Intelligence! 🍎✨**
