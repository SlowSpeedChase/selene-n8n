# Operations Context: Daily Development Tasks

**Purpose:** Common commands, testing procedures, and troubleshooting for daily Selene development. Read this when you need to DO something (test, debug, commit, deploy).

**Related Context:**
- `@workflows/CLAUDE.md` - Workflow-specific operations
- `@scripts/CLAUDE.md` - Script usage details
- `@.claude/DEVELOPMENT.md` - Why we do things this way

---

## Quick Command Reference

### Docker Operations

```bash
# Start n8n
docker-compose up -d

# Stop n8n
docker-compose down

# View logs (follow mode)
docker-compose logs -f n8n

# Restart n8n
docker-compose restart n8n

# Check container status
docker-compose ps

# Shell into container
docker exec -it selene-n8n /bin/sh
```

### n8n Workflow Management

**CRITICAL: Always use CLI commands. Never manual UI edits.**

```bash
# List all workflows with IDs
./scripts/manage-workflow.sh list

# Export workflow to JSON (auto-backup)
./scripts/manage-workflow.sh export <workflow-id>

# Export to specific file
./scripts/manage-workflow.sh export <workflow-id> /workflows/XX-name/workflow.json

# Import new workflow
./scripts/manage-workflow.sh import /workflows/XX-name/workflow.json

# Update existing workflow (backup + import)
./scripts/manage-workflow.sh update <workflow-id> /workflows/XX-name/workflow.json

# Show workflow details
./scripts/manage-workflow.sh show <workflow-id>

# Backup credentials
./scripts/manage-workflow.sh backup-creds
```

**See:** `@workflows/CLAUDE.md` for workflow modification procedures

### Database Operations

```bash
# Open SQLite CLI
sqlite3 data/selene.db

# Common queries
sqlite3 data/selene.db "SELECT COUNT(*) FROM raw_notes;"
sqlite3 data/selene.db "SELECT * FROM raw_notes WHERE status='pending' LIMIT 5;"
sqlite3 data/selene.db ".schema raw_notes"
sqlite3 data/selene.db ".tables"

# Export database
sqlite3 data/selene.db ".backup data/selene-backup-$(date +%Y%m%d).db"

# Check database integrity
sqlite3 data/selene.db "PRAGMA integrity_check;"
```

### Testing Operations

```bash
# Test specific workflow
cd workflows/01-ingestion
./scripts/test-with-markers.sh

# List all test runs
./scripts/cleanup-tests.sh --list

# Cleanup specific test run
./scripts/cleanup-tests.sh test-run-20251127-120000

# Cleanup all test data
./scripts/cleanup-tests.sh --all

# Test ingestion endpoint directly
./scripts/test-ingest.sh
```

### Git Operations

```bash
# Check status
git status

# Stage workflow changes
git add workflows/XX-name/workflow.json workflows/XX-name/docs/STATUS.md

# Commit with convention
git commit -m "workflow: add error handling to ingestion"

# View recent commits
git log --oneline -10

# Check for uncommitted test data
git status | grep test-run
```

---

## Workflow Modification Procedure

**MANDATORY STEPS - Do not skip any step**

### Step 1: List Workflows

```bash
./scripts/manage-workflow.sh list
```

Output shows workflow IDs and names.

### Step 2: Export Current Version (Backup)

```bash
./scripts/manage-workflow.sh export <workflow-id>
```

Creates timestamped backup in `/workflows/backup-<id>-<timestamp>.json`

### Step 3: Edit Workflow JSON

Use Read/Edit tools on `workflows/XX-name/workflow.json`

**Common edits:**
- Add new node
- Modify node parameters
- Change connections
- Update credentials

**Do NOT:**
- Edit in n8n UI (changes won't persist in git)
- Skip backup step
- Modify without testing

### Step 4: Import Updated Workflow

```bash
./scripts/manage-workflow.sh update <workflow-id> /workflows/XX-name/workflow.json
```

This automatically:
1. Creates backup
2. Imports new version
3. Replaces existing workflow

### Step 5: Test Workflow

```bash
cd workflows/XX-name
./scripts/test-with-markers.sh
```

**Verify:**
- All test cases pass
- No errors in n8n execution logs
- Database updated correctly
- Cleanup works

### Step 6: Update Documentation

```bash
# Edit STATUS.md with test results
# Edit README.md if interface changed
# Update PROJECT-STATUS.md if workflow complete
```

### Step 7: Commit to Git

```bash
git add workflows/XX-name/workflow.json
git add workflows/XX-name/docs/STATUS.md
git commit -m "workflow: description of changes"
```

**See:** `@workflows/CLAUDE.md` for detailed workflow patterns

---

## Testing Procedures

### Test Data Pattern

**ALWAYS use test_run markers for test data**

```bash
# Generate unique test run ID
TEST_RUN="test-run-$(date +%Y%m%d-%H%M%S)"

# Use in test payload
curl -X POST http://localhost:5678/webhook/api/drafts \
  -H "Content-Type: application/json" \
  -d "{
    \"title\": \"Test Note\",
    \"content\": \"Test content\",
    \"test_run\": \"$TEST_RUN\"
  }"

# Verify data created
sqlite3 data/selene.db "SELECT * FROM raw_notes WHERE test_run = '$TEST_RUN';"

# Cleanup
./scripts/cleanup-tests.sh "$TEST_RUN"
```

**Why:**
- Production data: `test_run IS NULL`
- Test data: `test_run = 'test-run-...'`
- Zero risk of deleting production data
- Programmatic cleanup

### Workflow Testing Pattern

**Every workflow should have:**

1. **Test script:** `workflows/XX-name/scripts/test-with-markers.sh`
2. **Test cases:**
   - Success path (normal operation)
   - Error conditions (missing data, invalid input)
   - Edge cases (duplicates, large data, etc.)
3. **Cleanup:** Automatic cleanup prompt
4. **Documentation:** Results in `docs/STATUS.md`

**Example Test Script:**

```bash
#!/bin/bash
set -e

cd "$(dirname "$0")/.."

TEST_RUN="test-run-$(date +%Y%m%d-%H%M%S)"
WEBHOOK_URL="http://localhost:5678/webhook/api/drafts"

echo "Testing with marker: $TEST_RUN"

# Test 1: Normal note
curl -X POST "$WEBHOOK_URL" \
  -H "Content-Type: application/json" \
  -d "{\"title\": \"Test\", \"content\": \"Test\", \"test_run\": \"$TEST_RUN\"}"

# Verify
COUNT=$(sqlite3 ../../data/selene.db "SELECT COUNT(*) FROM raw_notes WHERE test_run = '$TEST_RUN';")
echo "Created $COUNT notes (expected: 1)"

# Cleanup prompt
read -p "Cleanup test data? (y/n) " -n 1 -r
if [[ $REPLY =~ ^[Yy]$ ]]; then
    ../../scripts/cleanup-tests.sh "$TEST_RUN"
fi
```

### Integration Testing

**Test full pipeline:**

```bash
# 1. Ingest note
curl -X POST http://localhost:5678/webhook/api/drafts \
  -H "Content-Type: application/json" \
  -d '{"title": "Integration Test", "content": "Test full pipeline", "test_run": "integration-test"}'

# 2. Wait for processing (if event-driven) or trigger manually

# 3. Verify each stage
sqlite3 data/selene.db "SELECT status FROM raw_notes WHERE test_run = 'integration-test';"
sqlite3 data/selene.db "SELECT COUNT(*) FROM processed_notes WHERE test_run = 'integration-test';"
sqlite3 data/selene.db "SELECT COUNT(*) FROM sentiment_history WHERE test_run = 'integration-test';"

# 4. Cleanup
./scripts/cleanup-tests.sh integration-test
```

---

## Debugging Workflows

### Step 1: Check Execution Logs

**In n8n UI:**
1. Open workflow
2. Click "Executions" tab
3. Find failed execution
4. Click to view details
5. Check each node's input/output

**Common issues:**
- Node received empty data
- JSON parsing error
- Database connection failed
- Ollama timeout

### Step 2: Check Docker Logs

```bash
# Real-time logs
docker-compose logs -f n8n

# Last 100 lines
docker-compose logs --tail=100 n8n

# Search for errors
docker-compose logs n8n | grep -i error
```

### Step 3: Check Database State

```bash
# Check if data exists
sqlite3 data/selene.db "SELECT * FROM raw_notes WHERE id = <id>;"

# Check status
sqlite3 data/selene.db "SELECT id, status, created_at FROM raw_notes ORDER BY id DESC LIMIT 10;"

# Check for locks
sqlite3 data/selene.db "PRAGMA wal_checkpoint;"
```

### Step 4: Manual Node Testing

**Test individual nodes:**

1. In n8n UI, click "Execute Node"
2. Provide sample input data
3. Verify output
4. Check for errors

**Test database queries:**

```javascript
// In n8n Function node
const Database = require('better-sqlite3');
const db = new Database('/selene/data/selene.db');

try {
  const result = db.prepare('SELECT * FROM raw_notes LIMIT 1').get();
  console.log('Result:', result);
  return {json: result};
} catch (error) {
  console.error('Error:', error);
  throw error;
} finally {
  db.close();
}
```

### Step 5: Ollama Connection Testing

```bash
# From host machine
curl http://localhost:11434/api/generate \
  -d '{"model": "mistral:7b", "prompt": "test", "stream": false}'

# From n8n container
docker exec selene-n8n curl http://host.docker.internal:11434/api/generate \
  -d '{"model": "mistral:7b", "prompt": "test", "stream": false}'
```

**Common Ollama issues:**
- Ollama not running: `ollama serve`
- Model not pulled: `ollama pull mistral:7b`
- host.docker.internal not mapped (check docker-compose.yml)

---

## Git Commit Procedures

### Before Committing

**Checklist:**
- [ ] All tests pass
- [ ] Documentation updated (STATUS.md, README.md)
- [ ] No test data in commit
- [ ] Workflow JSON validated

**Check for test data:**

```bash
# Should return nothing
git diff | grep test-run
git status | grep test-run

# If found, unstage
git reset HEAD <file-with-test-data>
```

### Commit Message Format

**Format:** `type: description`

**Types:**
- `feat:` New feature (e.g., new workflow)
- `fix:` Bug fix
- `docs:` Documentation only
- `refactor:` Code restructure, no behavior change
- `test:` Add or modify tests
- `workflow:` n8n workflow changes
- `chore:` Maintenance (dependencies, config)

**Examples:**

```bash
# Good
git commit -m "feat: add task extraction workflow (07)"
git commit -m "fix: duplicate detection in ingestion workflow"
git commit -m "docs: update STATUS.md with Phase 1.5 results"
git commit -m "workflow: add error handling to LLM processing"

# Bad (too vague)
git commit -m "updates"
git commit -m "fix stuff"
git commit -m "changes to workflow"
```

### Commit Workflow Changes

**Always commit these together:**

```bash
# 1. Workflow JSON
git add workflows/XX-name/workflow.json

# 2. Updated documentation
git add workflows/XX-name/docs/STATUS.md
git add workflows/XX-name/README.md  # if changed

# 3. Project status (if workflow complete)
git add .claude/PROJECT-STATUS.md

# 4. Commit with descriptive message
git commit -m "workflow: add sentiment analysis to ingestion pipeline

- Added sentiment node after LLM processing
- Extracts emotional tone and ADHD markers
- Updates processed_notes with sentiment data
- All 7/7 tests passing"
```

---

## Troubleshooting Quick Reference

### "Container won't start"

```bash
# Check if port 5678 in use
lsof -i :5678

# Kill process using port
kill -9 <PID>

# Remove old containers
docker-compose down -v
docker-compose up -d
```

### "Workflow fails immediately"

**Checklist:**
- [ ] Check credentials in n8n UI
- [ ] Verify database file exists (`data/selene.db`)
- [ ] Check Ollama running (`ollama serve`)
- [ ] Check Docker logs for errors

### "Database locked"

```bash
# Close all connections
docker-compose restart n8n

# Check for WAL files
ls -la data/selene.db*

# Checkpoint WAL
sqlite3 data/selene.db "PRAGMA wal_checkpoint(TRUNCATE);"
```

### "Ollama timeout"

**Causes:**
- Model not loaded (first request is slow)
- System under load
- Ollama crashed

**Solutions:**

```bash
# Restart Ollama
pkill ollama
ollama serve

# Check Ollama logs
tail -f ~/.ollama/logs/server.log

# Test Ollama directly
ollama run mistral:7b "test prompt"
```

### "better-sqlite3 not found"

```bash
# Check if installed in container
docker exec selene-n8n ls /home/node/.n8n/node_modules/better-sqlite3

# Reinstall if missing
docker exec selene-n8n npm install -g better-sqlite3

# Restart container
docker-compose restart n8n
```

---

## Environment Variables

**Location:** `.env` file (not committed to git)

**Key variables:**

```bash
# Authentication
N8N_BASIC_AUTH_USER=admin
N8N_BASIC_AUTH_PASSWORD=your_secure_password

# Paths
SELENE_DB_PATH=/selene/data/selene.db
OBSIDIAN_VAULT_PATH=./vault

# Ollama
OLLAMA_BASE_URL=http://localhost:11434
OLLAMA_MODEL=mistral:7b

# Node modules
NODE_FUNCTION_ALLOW_EXTERNAL=better-sqlite3
NODE_PATH=/home/node/.n8n/node_modules

# Timezone
TIMEZONE=America/Chicago
```

**To change:**

```bash
# 1. Edit .env file
nano .env

# 2. Restart container
docker-compose down
docker-compose up -d
```

---

## Daily Development Checklist

### Starting Work

- [ ] Check project status: `@.claude/PROJECT-STATUS.md`
- [ ] Start Docker: `docker-compose up -d`
- [ ] Check container: `docker-compose ps`
- [ ] Pull latest: `git pull`
- [ ] Review what's next in `@ROADMAP.md`

### During Work

- [ ] Test frequently with `test-run` markers
- [ ] Update STATUS.md after changes
- [ ] Commit logical chunks (not giant diffs)
- [ ] Keep documentation current

### Before Ending Session

- [ ] Run full test suite
- [ ] Update PROJECT-STATUS.md
- [ ] Commit all changes
- [ ] Note next steps in PROJECT-STATUS.md
- [ ] Cleanup test data: `./scripts/cleanup-tests.sh --list`

---

## Related Context Files

- **`@workflows/CLAUDE.md`** - Workflow-specific operations
- **`@scripts/CLAUDE.md`** - Script usage details
- **`@.claude/DEVELOPMENT.md`** - Why we do things this way
- **`@.claude/PROJECT-STATUS.md`** - Current state
