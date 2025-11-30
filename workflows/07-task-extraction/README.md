# Workflow 07: Task Extraction

**Status:** Ready for Import
**Phase:** 7.1 - Task Extraction Foundation
**Created:** 2025-11-25

## Overview

Automatically extracts actionable tasks from processed notes using Ollama LLM and creates them in Things 3 with ADHD-optimized enrichment data.

## What This Workflow Does

1. **Receives webhook** with note ID
2. **Fetches note data** from database (raw_notes + processed_notes + sentiment_history)
3. **Builds LLM prompt** with note content and metadata
4. **Calls Ollama** to extract tasks
5. **Parses JSON response** and validates task structure
6. **Creates tasks in Things** via HTTP wrapper (one per extracted task)
7. **Stores metadata** in task_metadata table
8. **Updates note status** (tasks_extracted = 1, things_integration_status)

## Prerequisites

- ✅ Ollama running with mistral:7b model
- ✅ Things HTTP wrapper running on port 3456
- ✅ Database migration 007 applied (task_metadata table)
- ✅ Workflow 05 (sentiment analysis) active

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
  "raw_note_id": 123
}
```

## Testing

### Manual Test

```bash
# Test with an existing processed note
curl -X POST http://localhost:5678/webhook/task-extraction \
  -H "Content-Type: application/json" \
  -d '{"raw_note_id": 1}'
```

### Verify Results

```bash
# Check task_metadata table
sqlite3 data/selene.db "SELECT * FROM task_metadata ORDER BY created_at DESC LIMIT 5;"

# Check Things app
# Open Things 3 and look in Inbox
```

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
