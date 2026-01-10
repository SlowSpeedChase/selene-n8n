# 08-Daily-Summary Workflow

Generates a daily executive summary at midnight, combining recent note activity with emerging patterns. Saves to Obsidian vault and pushes to TRMNL e-ink display.

## Quick Start

1. **Import workflow:**
   ```bash
   ./scripts/manage-workflow.sh update <id> workflows/08-daily-summary/workflow.json
   ```

2. **Activate in n8n:**
   - Open n8n UI
   - Find "08-Daily-Summary | Selene"
   - Toggle Active switch ON

3. **Check output:**
   - Summaries appear in `vault/Daily/YYYY-MM-DD-summary.md`

## Schedule

- **Trigger:** Daily at midnight (00:00)
- **Timezone:** Server timezone

## Data Sources

1. **raw_notes** - Notes captured in the last 24 hours
2. **processed_notes** - LLM-extracted concepts and themes
3. **detected_patterns** - Active recurring patterns

## Output Format

```markdown
# Daily Summary - Monday, December 30, 2025

Captured 3 notes today focused on project planning and workflow automation.
The LLM extracted concepts around "task management" and "n8n integrations"
which connect to your ongoing theme of building external memory systems.

---

**Stats:** 3 notes captured, 2 processed, 1 active patterns

---
*Generated automatically at midnight by Selene*
```

## Configuration

### Ollama
- **URL:** `http://host.docker.internal:11434/api/generate`
- **Model:** `mistral:7b`
- **Timeout:** 120 seconds

### Output Path
- **Directory:** `/obsidian/Selene/Daily/`
- **Filename:** `YYYY-MM-DD-summary.md`

### TRMNL Integration
- **Webhook:** `https://usetrmnl.com/api/custom_plugins/{TRMNL_WEBHOOK_ID}`
- **Format:** Plain text (markdown stripped)
- **Env var:** `TRMNL_WEBHOOK_ID` in docker-compose.yml

## Testing

```bash
cd workflows/08-daily-summary
./scripts/test-with-markers.sh
```

## Troubleshooting

### Summary not generated
1. Check n8n logs: `docker-compose logs -f n8n`
2. Verify workflow is active in n8n UI
3. Check Ollama is running: `curl http://localhost:11434/api/tags`

### Ollama timeout
- Increase timeout in HTTP Request node
- Check Ollama resource usage

### Empty summary
- Verify notes exist: `sqlite3 data/selene.db "SELECT COUNT(*) FROM raw_notes WHERE date(created_at) >= date('now', '-1 day');"`

## Files

- `workflow.json` - Main workflow definition
- `README.md` - This file
- `docs/STATUS.md` - Test results and status
- `scripts/test-with-markers.sh` - Test script
