# Sentiment Analysis Testing Guide

## Quick Start Testing

### Prerequisites

1. **Services Running:**
   ```bash
   docker-compose ps
   # Verify n8n is "Up" and "healthy"

   curl http://localhost:11434/api/tags
   # Verify Ollama responds with model list including mistral:7b
   ```

2. **Database Ready:**
   ```bash
   sqlite3 data/selene.db "SELECT COUNT(*) FROM processed_notes WHERE sentiment_analyzed = 0;"
   # Shows how many notes are waiting for sentiment analysis
   ```

---

## Step 1: Import Workflow into n8n

The sentiment analysis workflow must be imported and activated in n8n:

1. **Open n8n web interface:**
   - Navigate to: http://localhost:5678
   - Login: `admin` / `selene_n8n_2025` (or your custom credentials)

2. **Import the workflow:**
   - Click "+" → "Import from File" or "Import from URL"
   - Select: `workflows/05-sentiment-analysis/workflow-v2-enhanced.json`
   - Or drag and drop the file into n8n

3. **Verify SQLite credentials:**
   - Click on "Get Unanalyzed Note" node
   - Check SQLite credentials are set to "Selene SQLite"
   - Path should be: `/selene/data/selene.db`
   - If missing, create credential:
     - Name: `Selene SQLite`
     - Database: `/selene/data/selene.db`

4. **Activate the workflow:**
   - Toggle switch in top right to "Active"
   - Verify cron trigger shows "Every 45 Seconds"

---

## Step 2: Verify Workflow is Running

```bash
# Check n8n logs for workflow activity
docker-compose logs n8n --tail=50 -f
# Look for: "Workflow 'Selene: Sentiment Analysis (Enhanced v2)' started"
# Press Ctrl+C to exit
```

**What to expect:**
- Every 45 seconds, the workflow should execute
- If no unanalyzed notes exist, it will complete immediately
- If notes exist, you'll see Ollama API calls

---

## Step 3: Test with Existing Notes

You likely have 9 unanalyzed notes in the queue. Let them process:

```bash
# Monitor progress
watch -n 5 'sqlite3 data/selene.db "SELECT COUNT(*) FROM processed_notes WHERE sentiment_analyzed = 0;"'
# Press Ctrl+C when count reaches 0
```

**Processing time:**
- 45 second interval between checks
- 5-10 seconds for Ollama analysis
- ~1 minute per note total

---

## Step 4: Validate Results

### Check Sentiment Data

```bash
# View recent sentiment analyses
sqlite3 data/selene.db "
SELECT
    rn.title,
    pn.overall_sentiment,
    pn.emotional_tone,
    pn.energy_level,
    pn.sentiment_score
FROM processed_notes pn
JOIN raw_notes rn ON pn.raw_note_id = rn.id
WHERE pn.sentiment_analyzed = 1
ORDER BY pn.sentiment_analyzed_at DESC
LIMIT 10;
" -header -column
```

### Check ADHD Markers

```bash
sqlite3 data/selene.db "
SELECT
    rn.title,
    json_extract(pn.sentiment_data, '$.adhd_markers.overwhelm') as overwhelm,
    json_extract(pn.sentiment_data, '$.adhd_markers.hyperfocus') as hyperfocus,
    json_extract(pn.sentiment_data, '$.adhd_markers.executive_dysfunction') as exec_dysfunction,
    json_extract(pn.sentiment_data, '$.adhd_markers.scattered') as scattered,
    json_extract(pn.sentiment_data, '$.adhd_markers.burnout') as burnout,
    json_extract(pn.sentiment_data, '$.cognitive_load') as cognitive_load
FROM processed_notes pn
JOIN raw_notes rn ON pn.raw_note_id = rn.id
WHERE pn.sentiment_analyzed = 1
ORDER BY pn.sentiment_analyzed_at DESC
LIMIT 10;
" -header -column
```

### View Full Sentiment JSON

```bash
sqlite3 data/selene.db "
SELECT
    rn.title,
    pn.sentiment_data
FROM processed_notes pn
JOIN raw_notes rn ON pn.raw_note_id = rn.id
WHERE pn.sentiment_analyzed = 1
ORDER BY pn.sentiment_analyzed_at DESC
LIMIT 1;
" | python3 -m json.tool
```

---

## Step 5: Test Specific ADHD Patterns

### Create Test Notes

Use the provided test script or send notes manually:

```bash
# Automated test (sends 8 test notes covering different patterns)
./workflows/05-sentiment-analysis/run-tests.sh
```

Or send individual tests:

#### Test: Overwhelm Pattern
```bash
curl -X POST http://localhost:5678/webhook/api/drafts \
  -H "Content-Type: application/json" \
  -d '{
    "query": {
      "title": "TEST: Overwhelm",
      "content": "I have 15 different projects and cant focus on any single one. Everything feels urgent. My brain is racing between tasks. Too much at once. Drowning in work.",
      "timestamp": "'$(date -u +"%Y-%m-%dT%H:%M:%SZ")'"
    }
  }'
```

**Expected detection:**
- `overwhelm: true`
- `stress_indicators: true`
- `cognitive_load: high`
- `overall_sentiment: negative`

#### Test: Hyperfocus Pattern
```bash
curl -X POST http://localhost:5678/webhook/api/drafts \
  -H "Content-Type: application/json" \
  -d '{
    "query": {
      "title": "TEST: Hyperfocus",
      "content": "Been at this for 6 hours straight. Lost track of time completely. Started at 2pm, looked up and its 8pm. Completely dialed in on this problem. In the zone and dont want to stop.",
      "timestamp": "'$(date -u +"%Y-%m-%dT%H:%M:%SZ")'"
    }
  }'
```

**Expected detection:**
- `hyperfocus: true`
- `time_blindness: true`
- `energy_level: high`
- `overall_sentiment: positive`

#### Test: Executive Dysfunction
```bash
curl -X POST http://localhost:5678/webhook/api/drafts \
  -H "Content-Type: application/json" \
  -d '{
    "query": {
      "title": "TEST: Executive Dysfunction",
      "content": "I know I need to write documentation but I just cant get started. Every time I open the file I freeze up. Dont know where to begin. Been thinking about it for days but stuck. Procrastinating hard.",
      "timestamp": "'$(date -u +"%Y-%m-%dT%H:%M:%SZ")'"
    }
  }'
```

**Expected detection:**
- `executive_dysfunction: true`
- `self_efficacy: low`
- `stress_indicators: true`
- `emotional_tone: frustrated`

#### Test: Burnout
```bash
curl -X POST http://localhost:5678/webhook/api/drafts \
  -H "Content-Type: application/json" \
  -d '{
    "query": {
      "title": "TEST: Burnout",
      "content": "Im so tired. Been pushing hard for weeks and I just have no energy left. Even things I usually find exciting feel like a chore. Going through the motions. No motivation. Burnt out.",
      "timestamp": "'$(date -u +"%Y-%m-%dT%H:%M:%SZ")'"
    }
  }'
```

**Expected detection:**
- `burnout: true`
- `energy_level: low`
- `emotional_tone: burnt_out`
- `overall_sentiment: negative`

---

## Step 6: Monitor Processing

### Wait for Processing
After sending test notes, wait for processing pipeline:

1. **Workflow 01 (Ingestion)**: Creates `raw_notes` entry (~1 second)
2. **Workflow 02 (LLM Processing)**: Extracts concepts/themes (~30 seconds)
3. **Workflow 05 (Sentiment Analysis)**: Analyzes sentiment (~45s interval + 5-10s)

**Total time:** ~2-3 minutes per note from submission to sentiment analysis

### Check Processing Pipeline
```bash
# Show notes and their status through the pipeline
sqlite3 data/selene.db "
SELECT
    rn.id,
    rn.title,
    rn.status as raw_status,
    CASE WHEN pn.id IS NOT NULL THEN 'YES' ELSE 'NO' END as llm_processed,
    CASE WHEN pn.sentiment_analyzed = 1 THEN 'YES' ELSE 'NO' END as sentiment_done
FROM raw_notes rn
LEFT JOIN processed_notes pn ON rn.id = pn.raw_note_id
WHERE rn.title LIKE 'TEST:%'
ORDER BY rn.created_at DESC;
" -header -column
```

---

## Step 7: Analyze Results

### Accuracy Validation

For each test note, check if the detected markers match expectations:

```bash
# Compare actual vs expected for test notes
sqlite3 data/selene.db "
SELECT
    rn.title,
    pn.overall_sentiment,
    json_extract(pn.sentiment_data, '$.adhd_markers') as adhd_markers,
    json_extract(pn.sentiment_data, '$.analysis_confidence') as confidence
FROM processed_notes pn
JOIN raw_notes rn ON pn.raw_note_id = rn.id
WHERE rn.title LIKE 'TEST:%'
ORDER BY pn.sentiment_analyzed_at DESC;
" -header
```

### Check Analysis Confidence

```bash
# Find low-confidence analyses (may need review)
sqlite3 data/selene.db "
SELECT
    rn.title,
    json_extract(pn.sentiment_data, '$.analysis_confidence') as confidence,
    json_extract(pn.sentiment_data, '$.parsed_via') as parse_method
FROM processed_notes pn
JOIN raw_notes rn ON pn.raw_note_id = rn.id
WHERE pn.sentiment_analyzed = 1
  AND json_extract(pn.sentiment_data, '$.analysis_confidence') < 0.6
ORDER BY confidence ASC;
" -header -column
```

Low confidence (< 0.6) indicates:
- JSON parsing failed (fallback regex used)
- Ambiguous emotional content
- Model uncertainty

### Sentiment Distribution

```bash
# Overall sentiment breakdown
sqlite3 data/selene.db "
SELECT
    overall_sentiment,
    COUNT(*) as count,
    ROUND(AVG(sentiment_score), 2) as avg_score
FROM processed_notes
WHERE sentiment_analyzed = 1
GROUP BY overall_sentiment;
" -header -column
```

### ADHD Marker Frequency

```bash
sqlite3 data/selene.db "
SELECT
    SUM(CASE WHEN sentiment_data LIKE '%\"overwhelm\":true%' THEN 1 ELSE 0 END) as overwhelm,
    SUM(CASE WHEN sentiment_data LIKE '%\"hyperfocus\":true%' THEN 1 ELSE 0 END) as hyperfocus,
    SUM(CASE WHEN sentiment_data LIKE '%\"executive_dysfunction\":true%' THEN 1 ELSE 0 END) as exec_dysfunction,
    SUM(CASE WHEN sentiment_data LIKE '%\"scattered\":true%' THEN 1 ELSE 0 END) as scattered,
    SUM(CASE WHEN sentiment_data LIKE '%\"burnout\":true%' THEN 1 ELSE 0 END) as burnout,
    SUM(CASE WHEN sentiment_data LIKE '%\"time_blindness\":true%' THEN 1 ELSE 0 END) as time_blindness,
    SUM(CASE WHEN sentiment_data LIKE '%\"positive_traits\":true%' THEN 1 ELSE 0 END) as positive_traits,
    COUNT(*) as total
FROM processed_notes
WHERE sentiment_analyzed = 1;
" -header -column
```

---

## Troubleshooting

### Issue: Workflow not processing notes

**Check:**
```bash
# Is workflow active in n8n?
# → Open http://localhost:5678 and verify toggle is ON

# Are there unanalyzed notes?
sqlite3 data/selene.db "SELECT COUNT(*) FROM processed_notes WHERE sentiment_analyzed = 0;"

# Check n8n logs for errors
docker-compose logs n8n --tail=100 | grep -i error
```

### Issue: JSON parsing failures

**Check confidence scores:**
```bash
sqlite3 data/selene.db "
SELECT AVG(json_extract(sentiment_data, '$.analysis_confidence')) as avg_confidence
FROM processed_notes WHERE sentiment_analyzed = 1;"
```

If average confidence < 0.7, consider:
- Adjusting temperature (currently 0.35)
- Increasing `num_predict` token limit
- Using a larger model (mistral:7b → llama2:13b)

### Issue: Inaccurate sentiment detection

**Review specific cases:**
```bash
# Show cases where sentiment seems wrong
sqlite3 data/selene.db "
SELECT rn.title, SUBSTR(rn.content, 1, 100) as content_preview,
       pn.overall_sentiment, pn.emotional_tone
FROM processed_notes pn
JOIN raw_notes rn ON pn.raw_note_id = rn.id
WHERE pn.sentiment_analyzed = 1;" -header
```

**Tune the system prompt:**
Edit workflow node "Build Enhanced Sentiment Prompt" to adjust detection patterns.

### Issue: ADHD markers not detected

Check if the content actually contains marker keywords:
- Overwhelm: "too much", "can't handle", "drowning"
- Hyperfocus: "lost track of time", "hours", "in the zone"
- Executive dysfunction: "can't start", "stuck", "procrastinating"

If patterns are subtle, enhance the system prompt with more examples.

---

## Performance Testing

### Measure Processing Speed

```bash
# Time a single note through the pipeline
START_TIME=$(date +%s)

curl -X POST http://localhost:5678/webhook/api/drafts \
  -H "Content-Type: application/json" \
  -d '{
    "query": {
      "title": "PERF TEST",
      "content": "Testing performance of sentiment analysis pipeline",
      "timestamp": "'$(date -u +"%Y-%m-%dT%H:%M:%SZ")'"
    }
  }'

# Wait for sentiment analysis to complete
while [ $(sqlite3 data/selene.db "SELECT sentiment_analyzed FROM processed_notes pn JOIN raw_notes rn ON pn.raw_note_id = rn.id WHERE rn.title = 'PERF TEST';" 2>/dev/null) != "1" ]; do
    sleep 5
done

END_TIME=$(date +%s)
echo "Total time: $((END_TIME - START_TIME)) seconds"
```

**Expected timing:**
- Fast path: 60-90 seconds
- Normal: 90-120 seconds
- Slow: 120+ seconds (may indicate bottleneck)

---

## Validation Checklist

Use this checklist to confirm sentiment analysis is working correctly:

- [ ] Workflow imported and activated in n8n
- [ ] SQLite credentials configured correctly
- [ ] Ollama accessible and mistral:7b model available
- [ ] Existing unanalyzed notes being processed (count decreasing)
- [ ] Sentiment data appearing in `processed_notes` table
- [ ] ADHD markers detected in test cases
- [ ] Analysis confidence > 0.7 for most notes
- [ ] Overwhelm pattern detected correctly
- [ ] Hyperfocus pattern detected correctly
- [ ] Executive dysfunction detected correctly
- [ ] Burnout pattern detected correctly
- [ ] Positive/neutral sentiments also working
- [ ] No errors in n8n execution logs

---

## Next Steps After Validation

Once testing confirms everything works:

1. **Clear test data:**
   ```bash
   ./workflows/01-ingestion/scripts/cleanup-tests.sh
   ```

2. **Start using with real notes** from Drafts or other sources

3. **Monitor accuracy** over first 50-100 notes and tune prompts if needed

4. **Enable Obsidian export** (Workflow 04) to include sentiment in notes

5. **Build dashboards** using the sentiment data for trend analysis

---

## Test Notes Reference

All test notes are defined in: `workflows/05-sentiment-analysis/test-notes.json`

Includes 8 test patterns:
1. Overwhelm Pattern
2. Hyperfocus Pattern
3. Executive Dysfunction
4. Burnout Pattern
5. Scattered/Distracted
6. Positive ADHD Traits
7. Calm and Productive
8. Mixed Emotions

Each has expected marker values for validation.
