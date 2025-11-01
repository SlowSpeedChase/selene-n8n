# 02-LLM-Processing Workflow

**Status:** ✅ Complete and Documented
**Version:** 1.0
**Last Updated:** October 30, 2025

## Overview

The LLM Processing workflow automatically processes notes from the ingestion layer using a local AI model (Ollama). It extracts key concepts, detects themes, and stores structured metadata for downstream workflows.

**What it does:**
- Polls database every 30 seconds for pending notes
- Extracts 3-5 key concepts using AI
- Detects primary and secondary themes
- Calculates confidence scores
- Updates note status to "processed"

---

## Quick Start

### Prerequisites

1. **Ollama installed and running** with `mistral:7b` model
2. **n8n running** at http://localhost:5678
3. **Pending notes** in the database from 01-ingestion

### Setup Steps

1. **Set up Ollama (if needed):**
   ```bash
   # macOS
   brew install ollama
   ollama pull mistral:7b
   ```

2. **Import workflow to n8n:**
   - Open http://localhost:5678
   - Import `workflow.json`

3. **Activate the workflow:**
   - Toggle "Active" in n8n UI

4. **Monitor processing:**
   - Check "Executions" tab
   - Query database for results

---

## Documentation

### Primary Documentation

📖 **[LLM-PROCESSING-SETUP.md](docs/LLM-PROCESSING-SETUP.md)**
- Complete setup guide from installation to activation
- Troubleshooting for common issues
- Testing procedures
- Production tips

📖 **[LLM-PROCESSING-REFERENCE.md](docs/LLM-PROCESSING-REFERENCE.md)**
- Quick reference for all workflow nodes
- Database schema
- SQL query examples
- Configuration parameters

📖 **[OLLAMA-SETUP.md](docs/OLLAMA-SETUP.md)**
- Ollama installation guide for all platforms
- Model selection and management
- Docker integration
- Performance tuning

📖 **[LLM-PROCESSING-STATUS.md](docs/LLM-PROCESSING-STATUS.md)**
- Project completion summary
- Test results
- Current configuration
- Next steps

---

## Architecture

```
[Cron: Every 30s] → [Get Pending Note]
                            ↓
                    [Build Concept Prompt]
                            ↓
                    [Ollama: Extract Concepts]
                            ↓
                    [Parse Concepts]
                            ↓
                    [Build Theme Prompt]
                            ↓
                    [Ollama: Detect Themes]
                            ↓
                    [Parse Themes]
                            ↓
                    [Update Database]
```

---

## Features

### Concept Extraction
- 3-5 key concepts per note
- Confidence scoring (0.0-1.0)
- Context-aware based on note type
- Fallback parsing for reliability

### Theme Detection
- Primary theme from standard vocabulary
- 1-2 secondary themes
- 20 predefined themes covering common use cases
- Confidence scoring

### Note Type Detection
Automatically detects 7 note types:
- Meeting notes
- Technical notes
- Ideas
- Personal notes
- Tasks
- Reflections
- General notes

---

## Configuration

### Default Settings

| Setting | Value |
|---------|-------|
| Processing Interval | 30 seconds |
| LLM Model | mistral:7b |
| Temperature | 0.3 |
| Batch Size | 1 note per execution |
| Timeout | 60 seconds |

### Customization Options

**Change processing speed:**
- Adjust cron interval (15-60 seconds)

**Change LLM model:**
- Use `llama3.2:3b` (faster)
- Use `llama3.1:8b` (more accurate)

**Adjust accuracy vs speed:**
- Lower temperature (0.1-0.2) = more focused
- Reduce tokens (500-1000) = faster

---

## Database

### Input Table: raw_notes

```sql
SELECT id, title, content, created_at
FROM raw_notes
WHERE status = 'pending'
ORDER BY created_at ASC
LIMIT 1
```

### Output Table: processed_notes

```sql
INSERT INTO processed_notes (
  raw_note_id,
  concepts,              -- JSON: ["concept1", "concept2", ...]
  concept_confidence,    -- JSON: {"concept1": 0.95, ...}
  primary_theme,         -- String: "technical"
  secondary_themes,      -- JSON: ["tools", "learning"]
  theme_confidence,      -- Float: 0.88
  processed_at
) VALUES (?, ?, ?, ?, ?, ?, ?)
```

### Status Update

```sql
UPDATE raw_notes
SET status = 'processed',
    processed_at = datetime('now')
WHERE id = ?
```

---

## Testing

### Verify Prerequisites

```bash
# Check Ollama
curl http://localhost:11434/api/tags

# Check pending notes
sqlite3 data/selene.db "SELECT COUNT(*) FROM raw_notes WHERE status='pending';"

# Test from Docker
docker exec selene-n8n sh -c "wget -qO- http://host.docker.internal:11434/api/tags"
```

### Monitor Processing

```bash
# Check status distribution
sqlite3 data/selene.db "
SELECT status, COUNT(*) as count
FROM raw_notes
GROUP BY status;
"

# View processed results
sqlite3 data/selene.db "
SELECT r.title, p.concepts, p.primary_theme
FROM processed_notes p
JOIN raw_notes r ON p.raw_note_id = r.id
ORDER BY p.processed_at DESC
LIMIT 5;
"
```

---

## Performance

### Expected Processing Times

| Model | Speed | Accuracy |
|-------|-------|----------|
| llama3.2:3b | 2-5s | Good (75-85%) |
| mistral:7b | 5-10s | Excellent (85-95%) |
| llama3.1:8b | 10-20s | Excellent (90-98%) |

### Throughput

- **Default (30s interval):** 60-100 notes/hour
- **Fast (15s interval):** 120-200 notes/hour
- **Batch mode:** 200+ notes/hour (with modifications)

---

## Troubleshooting

### Common Issues

**Workflow not processing:**
- Check workflow is activated (green toggle)
- Verify pending notes exist
- Check Ollama is running

**Connection errors:**
- Test: `curl http://localhost:11434/api/tags`
- Restart Ollama: `ollama serve`
- Check Docker connectivity

**Slow processing:**
- Use faster model: `ollama pull llama3.2:3b`
- Reduce tokens in workflow
- Check system resources

**See full troubleshooting in LLM-PROCESSING-SETUP.md**

---

## Integration

### Upstream
- **01-ingestion:** Creates pending notes

### Downstream
- **03-pattern-detection:** Analyzes trends
- **04-obsidian-export:** Exports with metadata
- **05-sentiment-analysis:** Adds emotional context
- **06-connection-network:** Builds concept graphs

---

## Files

```
02-llm-processing/
├── workflow.json                           # n8n workflow (11 nodes)
├── README.md                               # This file
└── docs/
    ├── LLM-PROCESSING-SETUP.md            # Setup guide (673 lines)
    ├── LLM-PROCESSING-REFERENCE.md        # Reference (601 lines)
    ├── OLLAMA-SETUP.md                    # Ollama guide (794 lines)
    └── LLM-PROCESSING-STATUS.md           # Status (473 lines)
```

**Total Documentation:** 2,541 lines

---

## Next Steps

1. **Read LLM-PROCESSING-SETUP.md** for complete setup instructions
2. **Install and configure Ollama** using OLLAMA-SETUP.md
3. **Import and activate the workflow** in n8n
4. **Process your pending notes** and verify quality
5. **Move on to 03-pattern-detection** for trend analysis

---

## Resources

- **n8n UI:** http://localhost:5678
- **Ollama API:** http://localhost:11434
- **Database:** `/data/selene.db`
- **Ollama Docs:** https://ollama.ai/docs
- **n8n Docs:** https://docs.n8n.io

---

## Supports

For issues or questions:
1. Check the troubleshooting sections in the docs
2. Review n8n execution logs in the UI
3. Check Ollama logs: `journalctl -u ollama -f` (Linux)
4. Verify database connectivity and schema

---

**Ready to process your notes with AI! 🚀**
