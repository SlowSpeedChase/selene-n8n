# Workflow 05: Sentiment Analysis (Advanced)

**Purpose:** Analyze emotional tone, energy levels, and ADHD markers in processed notes

**Trigger:** Webhook (POST to `/webhook/api/analyze-sentiment`)

**Processing Time:** ~5-10 seconds per note

**Dependencies:** Workflow 02 (LLM Processing) must complete first

**Status:** Production Ready (71 notes analyzed)

---

## Overview

The Sentiment Analysis workflow is designed specifically for ADHD minds, detecting not just basic sentiment (positive/negative/neutral) but also:

- **Energy levels** (high/medium/low) - Are you hyperfocused or crashing?
- **Emotional tone** (excited, anxious, overwhelmed, calm, etc.)
- **ADHD markers** (overwhelm, hyperfocus, executive dysfunction)
- **Stress indicators** - Signs of burnout or cognitive load
- **Confidence levels** - How certain you seem in your note

This enables you to:
1. Track emotional patterns over time
2. Identify when you're most productive or struggling
3. Recognize ADHD-specific thinking patterns
4. Export notes with emotional context to Obsidian

---

## Architecture

```
┌─────────────────────────────┐
│  Webhook: Analyze Sentiment │  POST with processedNoteId
└──────────────┬──────────────┘
               │
               ▼
┌─────────────────────────────┐
│  Get Note for Analysis      │  Query processed_notes + raw_notes
│  (better-sqlite3)           │  WHERE id = processedNoteId
└──────────────┬──────────────┘
               │
               ▼
┌─────────────────────────────┐
│  Build Enhanced Prompt      │  Create ADHD-aware system prompt
│  - Extract title/content    │  Include theme/concepts context
└──────────────┬──────────────┘
               │
               ▼
┌─────────────────────────────┐
│  Ollama: Sentiment Analysis │  POST to host.docker.internal:11434
│  - Model: mistral:7b        │  Temperature: 0.35
│  - Timeout: 90s             │
└──────────────┬──────────────┘
               │
               ▼
┌─────────────────────────────┐
│  Parse Sentiment Results    │  Extract JSON from LLM response
│  - JSON parsing             │  Fallback to regex if needed
│  - ADHD marker extraction   │
└──────────────┬──────────────┘
               │
               ▼
┌─────────────────────────────┐
│  Store Enhanced Sentiment   │  UPDATE processed_notes
│  (better-sqlite3)           │  INSERT into sentiment_history
└──────────────┬──────────────┘
               │
               ▼
┌──────────────┴──────────────┐
│                             │
▼                             ▼
┌───────────────────┐  ┌───────────────────┐
│ Trigger Obsidian  │  │ Trigger Task      │
│ Export            │  │ Extraction        │
└─────────┬─────────┘  └─────────┬─────────┘
          │                      │
          └──────────┬───────────┘
                     ▼
           ┌─────────────────────┐
           │ Build Response      │
           └─────────┬───────────┘
                     ▼
           ┌─────────────────────┐
           │ Respond to Webhook  │
           └─────────────────────┘
```

---

## Database Integration

### Tables Modified

1. **processed_notes**
   - Sets `sentiment_analyzed = 1`
   - Stores `sentiment_data` (full JSON)
   - Updates `overall_sentiment`, `sentiment_score`, `emotional_tone`, `energy_level`
   - Records `sentiment_analyzed_at` timestamp

2. **sentiment_history**
   - Inserts complete analysis record
   - Tracks changes over time
   - Enables trend analysis

### Query Logic

```sql
-- Find next note to analyze
SELECT pn.id, pn.raw_note_id, rn.title, rn.content,
       pn.primary_theme, pn.concepts
FROM processed_notes pn
JOIN raw_notes rn ON pn.raw_note_id = rn.id
WHERE pn.sentiment_analyzed = 0
ORDER BY pn.processed_at DESC
LIMIT 1;
```

Only processes notes where:
- `sentiment_analyzed = 0` (not yet analyzed)
- Already processed by Workflow 02 (has concepts & themes)

---

## Sentiment Analysis Output

### JSON Structure

```json
{
  "overall_sentiment": "positive|negative|neutral|mixed",
  "sentiment_score": 0.75,
  "emotional_tone": "excited|anxious|calm|frustrated|overwhelmed|motivated",
  "energy_level": "high|medium|low",
  "stress_indicators": true,
  "confidence_level": "high|medium|low",
  "key_emotions": ["excitement", "anticipation", "slight_anxiety"],
  "adhd_markers": {
    "overwhelm": false,
    "hyperfocus": true,
    "executive_dysfunction": false
  },
  "analysis_confidence": 0.85
}
```

### Field Descriptions

| Field | Type | Description |
|-------|------|-------------|
| `overall_sentiment` | enum | General emotional valence |
| `sentiment_score` | float | 0.0 (very negative) to 1.0 (very positive) |
| `emotional_tone` | enum | Specific emotional state |
| `energy_level` | enum | Mental energy at time of note |
| `stress_indicators` | boolean | Signs of stress/burnout detected |
| `confidence_level` | enum | How certain the writer seems |
| `key_emotions` | array | List of detected emotions |
| `adhd_markers.overwhelm` | boolean | Signs of cognitive overload |
| `adhd_markers.hyperfocus` | boolean | Deep engagement with topic |
| `adhd_markers.executive_dysfunction` | boolean | Difficulty with planning/organization |
| `analysis_confidence` | float | How confident the AI is (0.0-1.0) |

---

## ADHD Marker Detection

### What We Look For

#### 🧠 Overwhelm Indicators
- Language like "too much", "can't handle", "drowning in"
- Lists with 10+ items without structure
- Scattered thoughts jumping between topics
- Repetitive phrases indicating rumination

#### 🎯 Hyperfocus Indicators
- Extremely detailed notes on single topic
- Technical depth and precision
- Time-blindness mentions ("I've been at this for hours")
- Flow state language ("in the zone")

#### ⚠️ Executive Dysfunction Indicators
- Difficulty starting tasks
- Unclear priorities or goals
- Procrastination mentions
- Decision paralysis language

### Example Detections

**Note showing overwhelm:**
```
"I have 15 projects and can't decide where to start.
Everything feels urgent. My brain won't stop racing."
```
→ `overwhelm: true`, `stress_indicators: true`, `energy_level: "high"` (but chaotic)

**Note showing hyperfocus:**
```
"Spent 6 hours debugging this Docker networking issue.
Finally figured it out - the problem was the bridge network
configuration and the order of container startup..."
```
→ `hyperfocus: true`, `energy_level: "high"`, `confidence_level: "high"`

**Note showing executive dysfunction:**
```
"Need to organize my notes but don't know how to start.
Maybe by concept? Or theme? Or date? I'll think about it tomorrow."
```
→ `executive_dysfunction: true`, `confidence_level: "low"`

---

## Prompting Strategy

### System Prompt Design

The system prompt is carefully crafted to:
1. **Be specific** about output format (JSON only)
2. **Include ADHD awareness** in analysis
3. **Provide clear enum options** to reduce hallucination
4. **Emphasize evidence-based analysis** (not assumptions)

### Temperature Setting

We use **0.4 temperature** because:
- **Lower than default (0.7)** for more consistent output
- **Higher than 0.0** to allow nuanced emotional detection
- Balances creativity with reliability

### Token Limit

`num_predict: 1500` tokens allows for:
- Complete JSON response
- Detailed analysis
- Error recovery if model adds explanations

---

## Error Handling

### Fallback Parsing

If JSON parsing fails, the workflow uses regex to extract:
- Sentiment words (positive, negative, neutral)
- ADHD marker keywords (overwhelm, hyperfocus, etc.)
- Sets `analysis_confidence: 0.3` (lower confidence)

### Example Fallback

```javascript
if (/(overwhelm|too much|can't handle)/i.test(response)) {
  sentimentData.adhd_markers.overwhelm = true;
  sentimentData.stress_indicators = true;
}
```

This ensures:
- **No note is skipped** due to parsing errors
- **Basic analysis always available**
- **Lower confidence score** signals fallback was used

---

## Performance

### Processing Speed

| Metric | Value |
|--------|-------|
| **Query time** | ~50ms |
| **Ollama processing** | 3-8 seconds |
| **Database update** | ~100ms |
| **Total per note** | 5-10 seconds |

### Throughput

- **45-second interval** = ~80 notes/hour max
- **Actual rate** depends on queue size
- **No backlog buildup** if notes arrive slower than processing

### Resource Usage

- **CPU**: Moderate (mostly Ollama)
- **Memory**: ~100MB for n8n workflow
- **Disk**: Minimal (SQLite writes)

---

## Integration with Other Workflows

### Upstream (Dependencies)

**Workflow 02: LLM Processing**
- Must complete first (sets `status = 'processed'`)
- Provides `primary_theme` and `concepts` for context
- Sentiment analysis uses these to understand note better

### Downstream (Consumers)

**Workflow 04: Obsidian Export**
- Checks `sentiment_analyzed = 1` before exporting
- Includes emotional tone in frontmatter
- Uses energy level for file organization
- Adds ADHD markers to note metadata

**Workflow 03: Pattern Detection**
- Can analyze sentiment trends over time
- Detect emotional patterns in themes
- Future: Sentiment-aware pattern detection

---

## Configuration

### Ollama Model

Current: **mistral:7b**

Alternatives:
- `llama2:7b` - Faster, less nuanced
- `llama2:13b` - More accurate, slower
- `mixtral:8x7b` - Best quality, much slower

Change in workflow node: **"Ollama: Analyze Sentiment"** → Edit → bodyParameters → model

### Interval Timing

Current: **45 seconds**

Adjust in workflow node: **"Every 45 Seconds"** → Edit → interval

Recommendations:
- **30 seconds** - Faster processing, more CPU
- **60 seconds** - Lower CPU, slower queue
- **45 seconds** - Good balance (default)

### Sentiment Categories

Edit in Function node: **"Build Sentiment Prompt"** → systemPrompt

Current categories:
- Sentiment: positive, negative, neutral, mixed
- Tone: calm, excited, anxious, frustrated, content, overwhelmed, motivated
- Energy: high, medium, low

Add custom categories based on your needs.

---

## Testing

See [tests/TESTING.md](./tests/TESTING.md) for comprehensive testing guide.

Quick test:
```bash
# 1. Create test note
curl -X POST http://localhost:5678/webhook/api/drafts \
  -H "Content-Type: application/json" \
  -d '{
    "query": {
      "title": "Sentiment Test: Overwhelmed",
      "content": "I have so many projects and cant focus on any of them. Everything feels urgent. My brain wont stop racing between tasks.",
      "timestamp": "'$(date -u +"%Y-%m-%dT%H:%M:%SZ")'"
    }
  }'

# 2. Wait 30s for workflow 02 (LLM processing)

# 3. Wait 45s for workflow 05 (sentiment analysis)

# 4. Check results
sqlite3 data/selene.db "
SELECT overall_sentiment, emotional_tone, energy_level, adhd_markers
FROM processed_notes
WHERE sentiment_analyzed = 1
ORDER BY sentiment_analyzed_at DESC
LIMIT 1;
"
```

Expected: `overwhelm: true`, `stress_indicators: true`

---

## Troubleshooting

### No notes being analyzed

**Check:**
```sql
-- Are there unanalyzed notes?
SELECT COUNT(*) FROM processed_notes WHERE sentiment_analyzed = 0;
```

If 0: Workflow 02 needs to process notes first

### Ollama connection errors

**Check:**
```bash
# Is Ollama running?
curl http://localhost:11434/api/tags

# Is mistral:7b installed?
ollama list | grep mistral
```

Fix: `ollama pull mistral:7b`

### JSON parsing failures

**Check execution logs in n8n:**
1. Open workflow in n8n
2. Click "Executions" tab
3. Look for errors in "Parse Sentiment Results" node

**Common causes:**
- Model added explanation text before JSON
- Temperature too high (increase randomness)
- Token limit too low

**Fix:** Fallback parser handles this, but check `analysis_confidence` values

### Sentiment data not in exports

**Check:**
```sql
SELECT sentiment_analyzed, exported_to_obsidian
FROM raw_notes rn
JOIN processed_notes pn ON rn.id = pn.raw_note_id
LIMIT 5;
```

If `sentiment_analyzed = 0` but `exported_to_obsidian = 1`:
- Notes exported before sentiment analysis completed
- Re-export: Set `exported_to_obsidian = 0` and wait for export workflow

---

## Visualization & Analysis

### Query Sentiment Trends

```sql
-- Sentiment distribution
SELECT overall_sentiment, COUNT(*) as count
FROM sentiment_history
GROUP BY overall_sentiment;

-- Energy levels over time
SELECT DATE(analyzed_at) as date,
       energy_level,
       COUNT(*) as count
FROM sentiment_history
GROUP BY date, energy_level
ORDER BY date DESC;

-- ADHD marker frequency
SELECT
  SUM(CASE WHEN adhd_markers LIKE '%"overwhelm":true%' THEN 1 ELSE 0 END) as overwhelm_count,
  SUM(CASE WHEN adhd_markers LIKE '%"hyperfocus":true%' THEN 1 ELSE 0 END) as hyperfocus_count,
  SUM(CASE WHEN adhd_markers LIKE '%"executive_dysfunction":true%' THEN 1 ELSE 0 END) as exec_dysfunction_count,
  COUNT(*) as total_notes
FROM sentiment_history;

-- Average sentiment score by theme
SELECT pn.primary_theme,
       AVG(sh.sentiment_score) as avg_sentiment,
       AVG(sh.analysis_confidence) as avg_confidence
FROM sentiment_history sh
JOIN processed_notes pn ON sh.processed_note_id = pn.id
GROUP BY pn.primary_theme
ORDER BY avg_sentiment DESC;
```

### Obsidian Dataview Queries

Add to Obsidian vault for visualization:

```dataview
# High Energy Notes
TABLE energy_level, emotional_tone, sentiment
FROM "Selene"
WHERE energy_level = "high"
SORT file.mtime DESC
LIMIT 10
```

```dataview
# Notes with ADHD Markers
TABLE adhd_markers, emotional_tone
FROM "Selene"
WHERE adhd_markers != "✨ BASELINE"
SORT file.mtime DESC
```

---

## Future Enhancements

### Planned Features

1. **Sentiment-based recommendations**
   - "You seem overwhelmed, here are calmer notes from similar situations"
   - Energy-matched task suggestions

2. **Mood tracking dashboard**
   - Daily/weekly sentiment graphs
   - ADHD marker trends over time
   - Correlation with productivity themes

3. **Adaptive prompting**
   - Learn from manual corrections
   - Personalize emotion categories
   - User-specific ADHD patterns

4. **Multi-model ensemble**
   - Run 2-3 models simultaneously
   - Compare results for higher confidence
   - Fall back to simpler model on timeout

5. **Real-time mood alerts**
   - Webhook notification if overwhelm detected
   - Suggest coping strategies
   - Link to previous similar states

### API Extensions

```javascript
// Future: GET /api/sentiment/trends
{
  "last_7_days": {
    "avg_sentiment": 0.65,
    "dominant_emotion": "motivated",
    "energy_trend": "increasing",
    "adhd_markers": {
      "overwhelm_frequency": 0.2,
      "hyperfocus_frequency": 0.4
    }
  }
}
```

---

## Key Metrics to Track

| Metric | Query | Interpretation |
|--------|-------|----------------|
| **Average sentiment** | `AVG(sentiment_score)` | Overall emotional state |
| **Energy variance** | `STDEV(sentiment_score)` | Emotional stability |
| **Overwhelm frequency** | Count of `overwhelm: true` | Stress levels |
| **Hyperfocus periods** | Consecutive high-energy notes | Deep work tracking |
| **Confidence trends** | `AVG(analysis_confidence)` | Prompt quality |

---

## Best Practices

1. **Let it run continuously** - 45s interval catches all new notes
2. **Review low-confidence analyses** - Check `analysis_confidence < 0.5`
3. **Customize emotion categories** - Add your personal emotional states
4. **Use with pattern detection** - Combine for powerful insights
5. **Export regularly** - Keep Obsidian vault updated with sentiment data

---

## Related Documentation

- [Workflow 02: LLM Processing](../02-llm-processing/README.md) - Upstream dependency
- [Workflow 04: Obsidian Export](../04-obsidian-export/README.md) - Downstream consumer
- [Database Schema](../../docs/architecture/database.md) - Table structures
- [Ollama Configuration](../../docs/api/ollama.md) - Model setup

---

**Questions?** Check [Troubleshooting](../../docs/troubleshooting/workflows.md) or [FAQ](../../docs/troubleshooting/faq.md)
