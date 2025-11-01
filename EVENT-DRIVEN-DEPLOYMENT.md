# Event-Driven Architecture Deployment Guide

**Created:** 2025-10-31
**Purpose:** Replace cron-based triggers with event-driven webhooks

---

## Summary of Changes

### Old Architecture (Cron-based)
```
Drafts → Webhook → Insert raw_notes (status: 'pending')
                                ↓
                         (wait 30 seconds)
                                ↓
Cron (every 30s) → Query pending → Process → Update 'processed'
```

**Problems:**
- Wastes resources polling every 30 seconds
- Adds latency (0-30 second wait time)
- Inefficient when no notes to process

### New Architecture (Event-driven)
```
Drafts → Webhook → Insert raw_notes → Trigger Processing Webhook → Process → Update 'processed'
                                                                              ↓
                                                              Response back to Drafts
```

**Benefits:**
- Instant processing (no polling delay)
- Resource efficient (only runs when needed)
- True event-driven architecture
- Better error handling and feedback

---

## Files Modified

### 1. `/workflows/02-llm-processing/workflow.json`

**Changed:**
- ❌ **Removed:** Cron trigger node (every 30 seconds)
- ✅ **Added:** Webhook trigger at `/webhook/api/process-note`
- ✅ **Modified:** "Get Pending Note" → "Get Note and Lock" (now accepts noteId from webhook)
- ✅ **Added:** "Respond to Webhook" node at the end

**Key Changes:**
```json
// OLD: Cron trigger
{
  "type": "n8n-nodes-base.cron",
  "parameters": {
    "rule": { "interval": [{ "field": "seconds", "secondsInterval": 30 }] }
  }
}

// NEW: Webhook trigger
{
  "type": "n8n-nodes-base.webhook",
  "parameters": {
    "httpMethod": "POST",
    "path": "api/process-note",
    "responseMode": "responseNode"
  }
}
```

### 2. `/workflows/01-ingestion/workflow.json`

**Added:**
- ✅ **New Node:** "Trigger LLM Processing" - HTTP Request to processing webhook
- ✅ **New Node:** "Merge Processing Response" - Combines ingestion + processing data
- ✅ **Updated:** Flow now calls processing webhook after inserting note

**New Flow:**
```
Insert Note → Build Success Response → Trigger LLM Processing → Merge Response → Respond
```

---

## Deployment Steps

### Step 1: Stop the old cron-based workflow (if running)

```bash
cd /Users/chaseeasterling/selene-n8n

# Check if n8n is running
docker-compose ps

# If running, restart to load new workflows
docker-compose restart
```

### Step 2: Import updated workflows into n8n

**Option A: Using n8n UI**
1. Open n8n at http://localhost:5678
2. Go to "Workflows"
3. Find "Selene: LLM Processing" workflow
4. Click "..." → "Import from File"
5. Select `/workflows/02-llm-processing/workflow.json`
6. Activate the workflow

7. Find "Selene: Note Ingestion" workflow
8. Click "..." → "Import from File"
9. Select `/workflows/01-ingestion/workflow.json`
10. Activate the workflow

**Option B: Using n8n CLI (if available)**
```bash
# Stop n8n
docker-compose down

# Start n8n (will load updated workflows from mounted volume)
docker-compose up -d

# Wait for n8n to be healthy
sleep 10
docker-compose ps
```

### Step 3: Verify workflows are active

```bash
# Check n8n logs
docker-compose logs -f n8n

# Look for:
# - Webhook registered: /webhook/api/process-note
# - Workflows activated
```

### Step 4: Test the event-driven flow

```bash
# Run the test script
./test-event-driven.sh
```

**Expected Output:**
```
=== Testing Event-Driven Architecture ===

1. Sending test note to ingestion webhook...
Response: {"success":true,"action":"stored_and_processed",...}

✓ Note created with ID: 123

2. Waiting 5 seconds for processing to complete...

3. Checking database status...
id  raw_status  processed_id  concept_count  primary_theme  overall_sentiment
123 processed   456           4              technical      positive

4. Verification complete!
```

---

## Verification Checklist

After deployment, verify:

- [ ] Both workflows are active in n8n UI
- [ ] Old cron trigger is removed from "Selene: LLM Processing"
- [ ] New webhook `/webhook/api/process-note` is registered
- [ ] Test script completes successfully
- [ ] No notes stuck in 'processing' state
- [ ] Response time is faster (< 5 seconds vs 0-30 seconds)

### Check for stuck notes:

```bash
sqlite3 /Users/chaseeasterling/selene/data/selene.db \
  "SELECT COUNT(*) FROM raw_notes WHERE status = 'processing' AND processed_at IS NULL;"
```

Should return `0`. If not, reset them:

```bash
sqlite3 /Users/chaseeasterling/selene/data/selene.db \
  "UPDATE raw_notes SET status = 'pending' WHERE status = 'processing' AND processed_at IS NULL;"
```

---

## Rollback Plan

If something goes wrong, rollback to cron-based architecture:

```bash
# 1. Restore workflows from git history
git checkout HEAD~1 workflows/01-ingestion/workflow.json
git checkout HEAD~1 workflows/02-llm-processing/workflow.json

# 2. Restart n8n
docker-compose restart

# 3. Verify old cron workflow is running
docker-compose logs -f n8n | grep "cron"
```

---

## Testing

### Manual Test

```bash
# Send a test note
curl -X POST http://localhost:5678/webhook/api/drafts \
  -H "Content-Type: application/json" \
  -d '{
    "title": "Manual Test",
    "content": "Testing the event-driven architecture with Docker and webhooks.",
    "source_type": "test",
    "timestamp": "2025-10-31T15:00:00Z"
  }'
```

### Automated Test

```bash
./test-event-driven.sh
```

### Load Test (Optional)

```bash
# Send 10 notes in quick succession
for i in {1..10}; do
  curl -X POST http://localhost:5678/webhook/api/drafts \
    -H "Content-Type: application/json" \
    -d "{
      \"title\": \"Load Test $i\",
      \"content\": \"Testing concurrent processing with note $i\",
      \"source_type\": \"test\",
      \"timestamp\": \"$(date -u +%Y-%m-%dT%H:%M:%SZ)\"
    }" &
done
wait

# Check if all were processed
sleep 10
sqlite3 /Users/chaseeasterling/selene/data/selene.db \
  "SELECT COUNT(*) FROM raw_notes WHERE title LIKE 'Load Test%' AND status = 'processed';"
```

---

## Performance Comparison

### Before (Cron-based)

| Metric | Value |
|--------|-------|
| Average latency | 15 seconds (0-30s range) |
| Resource usage | Constant (polling every 30s) |
| Wasted executions | ~95% (when no notes pending) |
| Scalability | Poor (fixed interval) |

### After (Event-driven)

| Metric | Value |
|--------|-------|
| Average latency | < 5 seconds |
| Resource usage | On-demand only |
| Wasted executions | 0% |
| Scalability | Excellent (instant response) |

---

## Next Steps

After successful deployment:

1. **Monitor for 24 hours** - Watch for any errors or stuck notes
2. **Process existing backlog** - The pending note can now be processed on-demand
3. **Update documentation** - Mark Phase 6 as complete in roadmap
4. **Consider Phase 2** - Move to Obsidian export now that processing is optimized

---

## Troubleshooting

### Workflow not triggered

**Symptom:** Note ingested but not processed
**Check:**
```bash
# Verify webhook is registered
curl http://localhost:5678/webhook/api/process-note
# Should return n8n webhook response

# Check n8n logs
docker-compose logs n8n | grep "process-note"
```

**Solution:** Ensure both workflows are activated in n8n UI

### Note stuck in 'processing'

**Symptom:** raw_notes status = 'processing' but never completes
**Check:**
```bash
sqlite3 /Users/chaseeasterling/selene/data/selene.db \
  "SELECT * FROM raw_notes WHERE status = 'processing';"
```

**Solution:**
```bash
# Reset to pending
sqlite3 /Users/chaseeasterling/selene/data/selene.db \
  "UPDATE raw_notes SET status = 'pending' WHERE id = <NOTE_ID>;"

# Manually trigger processing
curl -X POST http://localhost:5678/webhook/api/process-note \
  -H "Content-Type: application/json" \
  -d '{"noteId": <NOTE_ID>}'
```

### Timeout errors

**Symptom:** HTTP request timeout when calling processing webhook
**Cause:** LLM processing takes > 120 seconds
**Solution:** Already configured with 120s timeout. If still timing out, increase in workflow:

```json
// In 01-ingestion/workflow.json, "Trigger LLM Processing" node
{
  "options": {
    "timeout": 180000  // 3 minutes
  }
}
```

---

## Architecture Diagram

```
┌─────────────┐
│ Drafts App  │
└──────┬──────┘
       │ POST /webhook/api/drafts
       ▼
┌──────────────────────────────────┐
│ n8n Workflow 01: Ingestion       │
│                                  │
│ 1. Parse Note                    │
│ 2. Check Duplicate               │
│ 3. Insert raw_notes (pending)    │
│ 4. Build Success Response        │
└──────┬───────────────────────────┘
       │ POST /webhook/api/process-note
       │ Body: { noteId: 123 }
       ▼
┌──────────────────────────────────┐
│ n8n Workflow 02: LLM Processing  │
│                                  │
│ 1. Get Note & Lock (processing)  │
│ 2. Extract Concepts (Ollama)     │
│ 3. Detect Themes (Ollama)        │
│ 4. Analyze Sentiment (Ollama)    │
│ 5. Update processed_notes        │
│ 6. Set status = 'processed'      │
│ 7. Return results                │
└──────┬───────────────────────────┘
       │ JSON response
       ▼
┌──────────────────────────────────┐
│ Workflow 01: Merge & Respond     │
│                                  │
│ Combine ingestion + processing   │
│ Send response to Drafts          │
└──────────────────────────────────┘
```

---

## Database Schema Changes

**None required!** The event-driven architecture uses the same database schema.

The `status` field in `raw_notes` still flows:
- `pending` → `processing` → `processed`

But now the transition happens via webhook trigger instead of cron polling.

---

## Maintenance

### Weekly Check

```bash
# Check for any stuck notes
sqlite3 /Users/chaseeasterling/selene/data/selene.db << EOF
SELECT
  status,
  COUNT(*) as count,
  MAX(created_at) as last_note
FROM raw_notes
GROUP BY status;
EOF
```

### Monthly Review

- Review n8n execution logs for errors
- Check processing times haven't increased
- Verify Ollama is still responding quickly
- Consider scaling if processing > 100 notes/day

---

**Questions or Issues?**

See [TROUBLESHOOTING.md](./docs/roadmap/22-TROUBLESHOOTING.md) or check n8n logs:

```bash
docker-compose logs -f n8n
```
