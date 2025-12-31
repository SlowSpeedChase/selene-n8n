# Workflow 07: Task Extraction with Classification

**Status:** Ready for Testing
**Phase:** 7.1 - Task Extraction with Classification
**Last Updated:** 2025-12-30

## Overview

Automatically classifies notes and extracts actionable tasks using Ollama LLM. Notes are triaged into three categories before processing:

| Classification | Description | Routing |
|----------------|-------------|---------|
| `actionable` | Clear, specific task | Task extraction -> Things |
| `needs_planning` | Goal/project needing breakdown | Flag for SeleneChat |
| `archive_only` | Thought/reflection | Store only |

## What This Workflow Does

1. **Receives webhook** with note ID and optional test_run marker
2. **Fetches note data** from database (raw_notes + processed_notes + sentiment_history)
3. **Classifies note** using Ollama (actionable/needs_planning/archive_only)
4. **Routes based on classification:**
   - **actionable** -> Extract tasks -> Create in Things -> Store metadata
   - **needs_planning** -> Create discussion thread -> Flag for SeleneChat
   - **archive_only** -> Store classification only
5. **Updates database** with classification and status

## Prerequisites

- Ollama running with mistral:7b model
- Things HTTP wrapper running on port 3456 (for actionable path)
- Database migrations applied:
  - 007_task_metadata.sql (task_metadata table)
  - 008_classification_fields.sql (classification columns + discussion_threads table)
- Workflow 05 (sentiment analysis) active (optional, for energy_level data)

## Import Instructions

1. Open n8n: http://localhost:5678
2. Go to Workflows → Import from File
3. Select: `workflows/07-task-extraction/workflow.json`
4. Click Import
5. **Activate** the workflow

## Webhook URL

```
POST http://localhost:5678/webhook/task-extraction
```

**Request body:**
```json
{
  "raw_note_id": 123,
  "test_run": "test-run-20251230-120000"  // Optional, for test data isolation
}
```

## Testing

### Manual Test

```bash
# Generate test ID
TEST_RUN="test-run-$(date +%Y%m%d-%H%M%S)"

# Test with an existing processed note
curl -X POST http://localhost:5678/webhook/task-extraction \
  -H "Content-Type: application/json" \
  -d "{\"raw_note_id\": 1, \"test_run\": \"$TEST_RUN\"}"
```

### Verify Results

```bash
# Check classification
sqlite3 data/selene.db "SELECT id, raw_note_id, classification, planning_status FROM processed_notes ORDER BY id DESC LIMIT 5;"

# Check discussion threads (for needs_planning)
sqlite3 data/selene.db "SELECT * FROM discussion_threads ORDER BY created_at DESC LIMIT 5;"

# Check task_metadata (for actionable)
sqlite3 data/selene.db "SELECT * FROM task_metadata ORDER BY created_at DESC LIMIT 5;"

# Check Things app (for actionable)
# Open Things 3 and look in Inbox

# Cleanup test data
./scripts/cleanup-tests.sh "$TEST_RUN"
```

## Classification Logic

The workflow uses Ollama to classify notes before task extraction:

### Decision Rules

1. **Actionable Check**
   - Has clear verb + specific object
   - Can be completed in a single session
   - Completion is unambiguous
   - Not dependent on unmade decisions

2. **Needs Planning Check**
   - Expresses goal or desired outcome
   - Contains multiple potential tasks
   - Requires scoping or breakdown
   - Uses "want to", "should", "need to figure out"
   - Overwhelm factor > 7

3. **Archive Only (Default)**
   - Reflective or observational
   - No implied action
   - Information capture

### Edge Cases
- When in doubt between actionable and needs_planning: Choose **needs_planning**
- When in doubt between needs_planning and archive_only: Choose **archive_only**

## Configuration

All configuration is automatic:
- Ollama URL: `http://host.docker.internal:11434`
- Wrapper URL: `http://host.docker.internal:3456`
- Database: `/selene/data/selene.db`
- Prompt: `/workflows/07-task-extraction/task-extraction-prompt.txt`

## ADHD Features

Tasks created with:
- **Energy Required:** high/medium/low (matches to user capacity)
- **Estimated Minutes:** 5, 15, 30, 60, 120, 240 (with 25% buffer)
- **Overwhelm Factor:** 1-10 scale (helps prioritize manageable tasks)
- **Task Type:** action/decision/research/communication/learning/planning
- **Context Tags:** Extracted from note themes/concepts

## Troubleshooting

**No tasks extracted:**
- Check Ollama logs: `docker logs ollama`
- Verify prompt template exists
- Check note has actionable content

**Tasks not appearing in Things:**
- Verify wrapper is running: `curl http://localhost:3456/health`
- Check Things app is open
- Review wrapper logs

**Database errors:**
- Verify migration 007 applied: `sqlite3 data/selene.db "SELECT name FROM sqlite_master WHERE name='task_metadata';"`
- Check foreign key constraints

## Next Steps

After importing:
1. Test with manual webhook call
2. Integrate with Workflow 05 (automatic trigger)
3. Monitor for 3 days
4. Collect user feedback on accuracy

## Files

- `workflow.json` - n8n workflow definition
- `task-extraction-prompt.txt` - Ollama prompt template
- `README.md` - This file
