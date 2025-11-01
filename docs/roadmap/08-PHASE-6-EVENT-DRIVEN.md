# Phase 6: Event-Driven Architecture

**Status:** ⚡ PARTIALLY COMPLETE
**Priority:** Medium (Performance Optimization)
**Estimated Effort:** 4-6 hours
**Dependencies:** Phase 1 (Core System)

---

## Overview

Convert remaining cron/schedule-based workflows to event-driven webhook architecture for improved performance, resource efficiency, and real-time processing.

### ✅ Completed (2025-10-31)

**Workflows 01 & 02: Note Ingestion → LLM Processing**
- ❌ **OLD**: Cron trigger every 30 seconds polling for pending notes
- ✅ **NEW**: Ingestion workflow triggers processing via webhook immediately
- **Results**: 3x faster processing (~14s vs 20-25s), 100% resource efficiency

---

## Remaining Work

### 🔄 Workflow 05: Sentiment Analysis

**Current State:**
- Trigger: Cron (every 45 seconds)
- Queries for `sentiment_analyzed = 0` in processed_notes
- Processes one note at a time

**Proposed Event-Driven Architecture:**

```
LLM Processing (Workflow 02)
  → Insert processed_notes
  → Trigger Sentiment Analysis Webhook
    → POST /webhook/api/analyze-sentiment
    → Body: { processedNoteId: 123 }
      → Ollama Sentiment Analysis
      → Update processed_notes.sentiment_analyzed = 1
      → Return results
```

**Benefits:**
- Instant sentiment analysis after LLM processing completes
- No 0-45 second polling delay
- Eliminates wasted cron executions when no notes pending
- Maintains batch processing safety (one note at a time)

**Implementation Notes:**
- Add HTTP Request node at end of Workflow 02 (LLM Processing)
- Create webhook trigger in Workflow 05 (Sentiment Analysis)
- Update to accept `processedNoteId` in POST body instead of querying
- Keep same error handling and retry logic
- Preserve analysis confidence scoring

**Files to Modify:**
1. `/workflows/02-llm-processing/workflow.json` - Add webhook call to sentiment analysis
2. `/workflows/05-sentiment-analysis/workflow.json` - Replace cron with webhook trigger
3. `/workflows/05-sentiment-analysis/CLAUDE.md` - Document event-driven pattern

---

### 📁 Workflow 04: Obsidian Export

**Current State:**
- Trigger: Schedule (every 1 hour)
- Already has on-demand webhook: `/webhook/obsidian-export`
- Exports notes with `exported_to_obsidian = 0`

**Proposed Hybrid Architecture:**

Keep both triggers for flexibility:

1. **Event-Driven (Real-time):**
   ```
   Sentiment Analysis (Workflow 05)
     → Update sentiment_analyzed = 1
     → Trigger Obsidian Export Webhook
       → POST /webhook/obsidian-export
       → Body: { noteId: 123 } (optional, export specific note)
         → Export to Obsidian vault
         → Update exported_to_obsidian = 1
   ```

2. **Schedule-Based (Batch cleanup):**
   - Keep hourly schedule for batch export of any missed notes
   - Safety net for error recovery
   - Handles manual database updates

**Benefits:**
- Notes appear in Obsidian within seconds of processing
- Hourly schedule provides backup safety net
- User can trigger manual export via webhook
- Supports both real-time and batch workflows

**Implementation Notes:**
- Modify webhook to accept optional `noteId` parameter
- If `noteId` provided: export that specific note
- If no `noteId`: export all pending notes (current behavior)
- Keep schedule trigger for safety/backup
- Add deduplication check to prevent double-export

**Files to Modify:**
1. `/workflows/05-sentiment-analysis/workflow.json` - Add webhook call to Obsidian export
2. `/workflows/04-obsidian-export/workflow.json` - Update webhook to accept noteId parameter

---

## Architecture Flow (Complete)

```
┌─────────────┐
│ Drafts App  │
└──────┬──────┘
       │ POST /webhook/api/drafts
       ▼
┌──────────────────────────────┐
│ Workflow 01: Ingestion ✅    │
│ - Parse note                 │
│ - Check duplicate            │
│ - Insert raw_notes           │
└──────┬───────────────────────┘
       │ POST /webhook/api/process-note
       │ Body: { noteId: 123 }
       ▼
┌──────────────────────────────┐
│ Workflow 02: LLM Processing ✅│
│ - Extract concepts           │
│ - Detect themes              │
│ - Analyze with Ollama        │
│ - Insert processed_notes     │
└──────┬───────────────────────┘
       │ POST /webhook/api/analyze-sentiment
       │ Body: { processedNoteId: 456 }
       ▼
┌──────────────────────────────┐
│ Workflow 05: Sentiment ⬜    │
│ - Analyze sentiment          │
│ - Detect ADHD patterns       │
│ - Update sentiment fields    │
└──────┬───────────────────────┘
       │ POST /webhook/obsidian-export
       │ Body: { noteId: 123 }
       ▼
┌──────────────────────────────┐
│ Workflow 04: Obsidian ⬜     │
│ - Generate markdown          │
│ - Export to vault            │
│ - Update export status       │
└──────────────────────────────┘
       │
       ▼
   Obsidian Vault (Ready!)
```

**Total Processing Time:**
- OLD: 0-30s (ingestion cron) + 5-10s (LLM) + 0-45s (sentiment cron) + 0-60min (export) = **~3-10s + 0-60min**
- NEW: <5s (ingestion) + 5-10s (LLM) + 5-10s (sentiment) + <5s (export) = **~15-30s total!** 🚀

---

## Implementation Steps

### For Workflow 05 (Sentiment Analysis)

1. **Update Workflow 02** (LLM Processing):
   ```json
   {
     "name": "Trigger Sentiment Analysis",
     "type": "n8n-nodes-base.httpRequest",
     "parameters": {
       "method": "POST",
       "url": "http://localhost:5678/webhook/api/analyze-sentiment",
       "sendBody": true,
       "specifyBody": "json",
       "jsonBody": "={{ { \"processedNoteId\": $json.processedNoteId } }}",
       "options": {
         "timeout": 60000
       }
     }
   }
   ```

2. **Update Workflow 05** (Sentiment Analysis):
   - Replace cron trigger node with webhook trigger:
     ```json
     {
       "type": "n8n-nodes-base.webhook",
       "parameters": {
         "httpMethod": "POST",
         "path": "api/analyze-sentiment",
         "responseMode": "responseNode"
       }
     }
     ```

   - Update "Get Unanalyzed Note" to accept ID from webhook:
     ```javascript
     const body = $input.item.json.body || $input.item.json;
     const processedNoteId = body.processedNoteId || body.processed_note_id;

     const query = `SELECT pn.id, pn.raw_note_id, rn.title, rn.content, ...
                    FROM processed_notes pn
                    JOIN raw_notes rn ON pn.raw_note_id = rn.id
                    WHERE pn.id = ?`;

     const result = db.prepare(query).get(processedNoteId);
     ```

   - Add `"active": true` to workflow JSON

3. **Deploy via n8n CLI:**
   ```bash
   # Add active field
   # (edit workflow.json to add "active": true)

   # Import updated workflows
   docker exec selene-n8n n8n import:workflow --input=/workflows/workflows/02-llm-processing/workflow.json
   docker exec selene-n8n n8n import:workflow --input=/workflows/workflows/05-sentiment-analysis/workflow.json

   # Activate in n8n UI or restart n8n
   docker-compose restart
   ```

4. **Test:**
   ```bash
   # Send test note
   curl -X POST http://localhost:5678/webhook/api/drafts \
     -H "Content-Type: application/json" \
     -d '{"title":"Test Sentiment","content":"I feel amazing and energized today!","source_type":"test"}'

   # Wait 15 seconds
   sleep 15

   # Verify sentiment analyzed
   sqlite3 /Users/chaseeasterling/selene-n8n/data/selene.db \
     "SELECT rn.title, pn.overall_sentiment, pn.emotional_tone
      FROM raw_notes rn
      JOIN processed_notes pn ON pn.raw_note_id = rn.id
      WHERE rn.title = 'Test Sentiment';"
   ```

### For Workflow 04 (Obsidian Export)

1. **Update Workflow 05** (Sentiment Analysis):
   - Add HTTP Request node at the end:
     ```json
     {
       "name": "Trigger Obsidian Export",
       "type": "n8n-nodes-base.httpRequest",
       "parameters": {
         "method": "POST",
         "url": "http://localhost:5678/webhook/obsidian-export",
         "sendBody": true,
         "specifyBody": "json",
         "jsonBody": "={{ { \"noteId\": $('Get Unanalyzed Note').item.json.raw_note_id } }}",
         "options": {
           "timeout": 30000
         }
       }
     }
     ```

2. **Update Workflow 04** (Obsidian Export):
   - Modify webhook handler to accept optional `noteId`
   - If `noteId` provided: export that specific note
   - If not provided: export all pending (current behavior)
   - Keep schedule trigger as backup

3. **Deploy and Test:**
   ```bash
   # Import updated workflows
   docker exec selene-n8n n8n import:workflow --input=/workflows/workflows/05-sentiment-analysis/workflow.json
   docker exec selene-n8n n8n import:workflow --input=/workflows/workflows/04-obsidian-export/workflow.json

   # Activate and restart
   docker-compose restart

   # Send test note and verify appears in Obsidian within 30 seconds
   ```

---

## Lessons Learned from Workflows 01 & 02 Migration

### ✅ What Worked Well

1. **n8n CLI Import:**
   ```bash
   docker exec selene-n8n n8n import:workflow --input=/workflows/workflows/XX/workflow.json
   ```
   - Fast, reliable, scriptable
   - No UI interaction needed
   - Validates workflow JSON automatically

2. **Required Workflow Metadata:**
   - Must include `"active": true` in workflow JSON
   - n8n validates and imports successfully
   - Can be activated via UI after import

3. **Database Location:**
   - Container: `/selene/data/selene.db`
   - Host: `./data/selene.db` (relative to docker-compose directory)
   - Actual path: `/Users/chaseeasterling/selene-n8n/data/selene.db`

4. **Webhook Response Modes:**
   - `responseMode: "onReceived"` - Returns immediately (for quick ack)
   - `responseMode: "responseNode"` - Waits for workflow completion (for data return)
   - Use "responseNode" when chaining workflows for better error handling

5. **HTTP Request Timeouts:**
   - Default: 300000ms (5 minutes)
   - LLM processing: Set 120000ms (2 minutes)
   - Sentiment analysis: Set 60000ms (1 minute)
   - Always configure based on expected processing time

### ⚠️ Gotchas to Avoid

1. **Workflow Activation:**
   - Importing workflow doesn't auto-activate it
   - Must either:
     - Activate in n8n UI manually
     - Update database and restart: `UPDATE workflow_entity SET active = 1 WHERE id = 'XXX'`
   - Restart n8n to reload activated workflows

2. **Database Path Confusion:**
   - Don't query `/Users/chaseeasterling/selene/data/selene.db` (wrong location!)
   - Always use `/Users/chaseeasterling/selene-n8n/data/selene.db`
   - Or inside container: `/selene/data/selene.db`

3. **Webhook Path Conflicts:**
   - If old and new workflows use same webhook path, last activated wins
   - Deactivate old workflows before testing new ones
   - Or delete old workflows after confirming new ones work

4. **Timing/Timestamp Issues:**
   - Use consistent timestamp format across workflows
   - `created_at` should use same timezone (UTC recommended)
   - `processed_at` uses `datetime('now')` in SQLite

5. **Error Visibility:**
   - Webhook responds "Workflow was started" even if execution fails
   - Must check n8n execution logs in UI for actual errors
   - Enable execution logging: `EXECUTIONS_DATA_SAVE_ON_ERROR=all`

### 🛠️ Best Practices

1. **Testing Workflow:**
   - Always test with curl before integrating with Drafts
   - Check database state before and after
   - Verify all nodes executed successfully in n8n UI
   - Monitor n8n logs: `docker-compose logs -f n8n`

2. **Deployment Workflow:**
   ```bash
   # 1. Add "active": true to workflow JSON
   # 2. Import via CLI
   docker exec selene-n8n n8n import:workflow --input=/workflows/workflows/XX/workflow.json
   # 3. Activate in UI
   # 4. Restart n8n
   docker-compose restart
   # 5. Test with curl
   # 6. Verify in database
   ```

3. **Rollback Plan:**
   - Keep old workflows deactivated (don't delete immediately)
   - Can reactivate if new workflows have issues
   - Git commit workflow changes before deploying

4. **Documentation:**
   - Update workflow README.md with event-driven flow
   - Update CLAUDE.md with webhook integration details
   - Document webhook endpoints and payloads
   - Note any timing/performance improvements

---

## Performance Metrics

### Workflows 01 & 02 (Completed)

| Metric | Old (Cron) | New (Event) | Improvement |
|--------|------------|-------------|-------------|
| Avg latency | 15s | < 5s | **3x faster** |
| Min latency | 0s | < 5s | Consistent |
| Max latency | 30s | < 5s | **6x faster** |
| Resource waste | 95% | 0% | **100% elimination** |
| Executions/hour | 120 | ~0-10 | **Demand-based** |

### Projected: Workflows 04 & 05 (Estimate)

| Metric | Old | New (Event) | Improvement |
|--------|-----|-------------|-------------|
| Sentiment latency | 0-45s | < 10s | **Up to 4.5x faster** |
| Export latency | 0-60min | < 10s | **Up to 360x faster** |
| Total end-to-end | 3-10s + 0-60min | ~30s | **Near real-time** |

---

## Success Criteria

- [ ] Workflow 05 triggers immediately after LLM processing
- [ ] Sentiment analysis completes within 15 seconds of note creation
- [ ] Workflow 04 triggers after sentiment analysis (or on-demand)
- [ ] Notes appear in Obsidian within 30 seconds of creation
- [ ] No notes stuck in pending state
- [ ] Cron triggers removed or deactivated
- [ ] Documentation updated with new architecture
- [ ] Test suite passes with event-driven flow

---

## Timeline Estimate

| Task | Estimated Time |
|------|----------------|
| Update Workflow 02 (add sentiment webhook) | 30 min |
| Update Workflow 05 (webhook trigger) | 1 hour |
| Update Workflow 05 (add export webhook) | 30 min |
| Update Workflow 04 (accept noteId param) | 1 hour |
| Testing and debugging | 1-2 hours |
| Documentation updates | 1 hour |
| **Total** | **4-6 hours** |

---

## Dependencies

**Required:**
- Phase 1 complete (workflows 01, 02 working)
- Docker and n8n running
- Ollama accessible
- Database at correct path

**Optional:**
- Obsidian vault configured (for workflow 04 testing)
- Test notes in database (for end-to-end testing)

---

## Related Documentation

- [CRON-TO-EVENT-SUMMARY.md](../../CRON-TO-EVENT-SUMMARY.md) - Workflows 01 & 02 migration summary
- [EVENT-DRIVEN-DEPLOYMENT.md](../../EVENT-DRIVEN-DEPLOYMENT.md) - Detailed deployment guide
- [Workflow 05 README](../../workflows/05-sentiment-analysis/README.md)
- [Workflow 04 README](../../workflows/04-obsidian-export/README.md)

---

**Next Steps:** Start with Workflow 05 (Sentiment Analysis) as it has clearer event trigger (after LLM processing). Then add Workflow 04 (Obsidian Export) as the final step in the pipeline.
