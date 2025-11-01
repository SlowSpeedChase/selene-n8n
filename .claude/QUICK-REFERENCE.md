# Selene n8n - Quick Reference

## Project Essentials

**Location:** `/Users/chaseeasterling/selene-n8n`
**n8n URL:** http://localhost:5678 (admin/selene_n8n_2025)
**Database:** `data/selene.db` (SQLite)

---

## Current State

| Workflow | Status | Location |
|----------|--------|----------|
| 01-Ingestion | ✅ Complete (6/7 tests) | `workflows/01-ingestion/` |
| 02-LLM Processing | ⏳ Next Up | `02-llm-processing-workflow.json` |
| 03-Pattern Detection | 📋 Planned | `03-pattern-detection-workflow.json` |
| 04-Obsidian Export | 📋 Planned | `04-obsidian-export-workflow.json` |
| 05-Sentiment | 📋 Planned | `05-sentiment-analysis-workflow.json` |
| 06-Network | 📋 Planned | `06-connection-network-workflow.json` |

---

## Essential Commands

### Docker
```bash
docker-compose ps              # Status
docker-compose logs n8n -f     # Live logs
docker-compose restart n8n     # Restart
docker-compose exec selene-n8n bash  # Shell access
```

### Database
```bash
sqlite3 data/selene.db ".tables"
sqlite3 data/selene.db "SELECT * FROM raw_notes ORDER BY id DESC LIMIT 5;"
sqlite3 data/selene.db "SELECT COUNT(*) FROM raw_notes WHERE test_run IS NULL;"  # Production data
```

### Testing
```bash
cd workflows/01-ingestion
./scripts/test-with-markers.sh           # Run ingestion tests
./scripts/cleanup-tests.sh --list        # List test data
./scripts/cleanup-tests.sh --all         # Clean all test data
```

---

## Key Files

### Documentation
- `.claude/PROJECT-STATUS.md` - Complete project status (read this first!)
- `workflows/01-ingestion/INDEX.md` - Ingestion workflow guide
- `workflows/01-ingestion/docs/STATUS.md` - Test results

### Configuration
- `docker-compose.yml` - Container configuration
- `Dockerfile` - Custom n8n image
- `.env` - Environment variables (if exists)

### Database
- `database/schema.sql` - Database structure
- `data/selene.db` - SQLite database

### Workflows
- `workflows/01-ingestion/workflow.json` - Active ingestion workflow
- `02-llm-processing-workflow.json` - Next to implement
- Other `*-workflow.json` files - Future workflows

---

## Important Patterns

### 1. Test Data Marking
Always include `test_run` in test payloads:
```json
{
  "title": "Test",
  "content": "Test content",
  "test_run": "my-test"
}
```

### 2. better-sqlite3 Usage
```javascript
const Database = require('better-sqlite3');
const db = new Database('/selene/data/selene.db');
// ... use db
db.close();
```

### 3. Workflow Updates
When updating workflows:
1. Edit `workflow.json` file
2. Delete workflow in n8n UI
3. Re-import updated file
4. Activate workflow

### 4. Container Restarts
Environment variable changes require:
```bash
docker-compose down && docker-compose up -d
```
(Not just `restart`)

---

## Network Info

**Mac IPs:**
- Local: 192.168.1.26
- Tailscale: 100.111.6.10

**Drafts Webhook:**
- Same device: `http://localhost:5678/webhook/api/drafts`
- iOS (WiFi): `http://192.168.1.26:5678/webhook/api/drafts`

---

## Troubleshooting Quick Fixes

### Workflow not responding
```bash
docker-compose logs n8n --tail=50  # Check logs
docker-compose restart n8n          # Restart
```

### Database locked
```bash
# Check for locks
lsof data/selene.db
# Kill processes if needed
```

### Module not found errors
```bash
# Reinstall in workspace
docker exec -u root selene-n8n npm install --prefix /home/node/.n8n better-sqlite3@11.0.0
# Recreate container
docker-compose down && docker-compose up -d
```

### Test data cleanup
```bash
cd workflows/01-ingestion
./scripts/cleanup-tests.sh --all
```

---

## Next Session Checklist

Before starting on workflow 02:
- [ ] Read `.claude/PROJECT-STATUS.md`
- [ ] Review `02-llm-processing-workflow.json`
- [ ] Check Ollama is running: `curl http://localhost:11434/api/tags`
- [ ] Verify database: `sqlite3 data/selene.db ".schema processed_notes"`
- [ ] Check for pending notes: `sqlite3 data/selene.db "SELECT COUNT(*) FROM raw_notes WHERE status='pending';"`

---

## Common Issues & Solutions

| Issue | Solution |
|-------|----------|
| Webhook returns 404 | Workflow not activated in n8n |
| Module not found | Check NODE_PATH and NODE_FUNCTION_ALLOW_EXTERNAL |
| Database "no such table" | Run schema: `sqlite3 data/selene.db < database/schema.sql` |
| Can't connect from iOS | Check firewall, verify WiFi, test `/healthz` endpoint |
| Test data in production | Mark with test_run, clean with cleanup script |

---

## Useful Queries

```sql
-- Count production notes
SELECT COUNT(*) FROM raw_notes WHERE test_run IS NULL;

-- Count test notes
SELECT COUNT(*) FROM raw_notes WHERE test_run IS NOT NULL;

-- Recent notes
SELECT id, title, status, created_at
FROM raw_notes
ORDER BY imported_at DESC
LIMIT 10;

-- Pending processing
SELECT COUNT(*) FROM raw_notes WHERE status='pending';

-- Test runs
SELECT test_run, COUNT(*) as count
FROM raw_notes
WHERE test_run IS NOT NULL
GROUP BY test_run;
```

---

## Emergency Commands

### Reset Everything
```bash
# Stop container
docker-compose down

# Reset database
rm data/selene.db
sqlite3 data/selene.db < database/schema.sql

# Restart
docker-compose up -d
```

### Clean n8n Data
```bash
docker-compose down
docker volume rm selene_n8n_data
docker-compose up -d
# Will need to re-import all workflows!
```

---

**Pro Tip:** Keep this file and PROJECT-STATUS.md open when working on the project!
