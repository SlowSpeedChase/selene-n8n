# Workflow 08: Project Detection & Creation

## Purpose

Automatically groups tasks into Things projects when 3+ tasks share a concept.

## Trigger

- **Daily Schedule:** 8:00 AM local time
- **Manual Webhook:** POST `/webhook/project-detection`

## Process Flow

1. Query task_metadata for concept clusters (3+ tasks sharing concept)
2. For each cluster without existing project:
   - Call Ollama to generate human-readable project name
   - Write project JSON to `vault/projects-pending/`
3. Host-side script (`process-pending-projects.sh`) picks up files:
   - Creates project in Things via AppleScript
   - Assigns tasks to project
   - Updates database with results
4. Energy profile calculated from task aggregation
5. Results logged to integration_logs

## Architecture Note

This workflow uses a **file-based bridge** pattern because:
- n8n runs in a Linux Docker container
- AppleScript requires macOS
- JSON files in `vault/projects-pending/` bridge the two environments
- A launchd job on the host processes pending files

## Dependencies

- Workflow 07 (Task Extraction) must have created tasks
- Things 3 running on macOS
- Ollama with mistral:7b model
- launchd configured to run process-pending-projects.sh

## Testing

```bash
./workflows/08-project-detection/scripts/test-with-markers.sh
```

## Files

- `workflow.json` - n8n workflow definition
- `docs/STATUS.md` - Current status and test results
- `scripts/test-with-markers.sh` - Automated test script
