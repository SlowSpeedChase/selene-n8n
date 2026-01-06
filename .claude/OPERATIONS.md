# Operations Context: Daily Development Tasks

**Purpose:** Common commands, testing procedures, and troubleshooting for daily Selene development. Read this when you need to DO something (test, debug, commit, deploy).

**Related Context:**
- `@workflows/CLAUDE.md` - Workflow-specific operations
- `@scripts/CLAUDE.md` - Script usage details
- `@.claude/DEVELOPMENT.md` - Why we do things this way

---

## Quick Command Reference

### n8n Operations (Local Installation)

**n8n runs locally (not Docker) - simpler debugging, direct file access.**

```bash
# Start n8n (foreground with logs)
./scripts/start-n8n-local.sh

# Start n8n (background)
./scripts/start-n8n-local.sh &

# Stop n8n
pkill -f "n8n start"

# Check if n8n is running
curl -s http://localhost:5678/healthz

# View n8n info
cat /tmp/n8n-local.log  # If redirected
```

**Environment when running locally:**
- n8n data: `.n8n-local/`
- Selene DB: `data/selene.db`
- Obsidian vault: `vault/`
- Ollama: `http://localhost:11434`
- n8n UI: `http://localhost:5678`

### Development Environment

#### Starting Development

```bash
# Start dev environment (creates dev database if needed)
./scripts/dev-start.sh

# Verify dev is running
docker ps | grep selene-n8n-dev

# Check current environment
cat .claude/CURRENT-ENV.md
```

#### Development Workflow

```bash
# 1. Start dev environment
./scripts/dev-start.sh

# 2. Edit workflow JSON files
# (Use Read/Edit tools on workflows/XX-name/workflow.json)

# 3. Import to dev
./scripts/manage-workflow.sh --dev update <id> /workflows/XX-name/workflow.json

# 4. Test with dev database
./workflows/XX-name/scripts/test-with-markers.sh

# 5. When ready, promote to production
./scripts/promote-workflow.sh XX-name
```

#### Dev Database Management

```bash
# Seed with sample data
./scripts/dev-seed-data.sh

# Reset to clean state (careful!)
./scripts/dev-reset-db.sh

# Query dev database
sqlite3 data/selene-dev.db "SELECT COUNT(*) FROM raw_notes;"
```

#### Stopping Development

```bash
# Stop dev environment
./scripts/dev-stop.sh

# Production remains running on port 5678
```

#### Environment Indicator

Claude should always check `.claude/CURRENT-ENV.md` before making changes:

- **PRODUCTION**: Do not modify workflows or test against production database
- **DEVELOPMENT**: Free to modify workflows and test against dev database

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

### Test Data Isolation

**Production data lives OUTSIDE the repo to prevent Claude Code from accessing it.**

**Directory Structure:**
```
~/selene-data/             # Production (outside repo - Claude cannot access)
├── selene.db              # Real notes database
└── obsidian-vault/        # Real Obsidian exports

~/selene-n8n/              # Repo (Claude can access)
├── data-test/
│   └── selene-test.db     # Synthetic test data (18 notes)
└── vault-test/            # Test Obsidian exports
```

**One-Time Setup (User Action Required):**
```bash
# Move production data outside repo
./scripts/setup-test-isolation.sh

# Seed test database with synthetic notes
./scripts/seed-test-data.sh
```

**How It Works:**
- All test scripts pass `"use_test_db": true` in webhook payloads
- Workflows check this flag and use `SELENE_TEST_DB_PATH` instead of `SELENE_DB_PATH`
- Production runs automatically (no flags needed) using `~/selene-data/selene.db`

**Environment Variables (set by start-n8n-local.sh):**
```bash
SELENE_DB_PATH=~/selene-data/selene.db              # Production
SELENE_TEST_DB_PATH=./data-test/selene-test.db      # Test
OBSIDIAN_VAULT_PATH=~/selene-data/obsidian-vault    # Production
OBSIDIAN_TEST_VAULT_PATH=./vault-test               # Test
```

**Test Database Contains:**
- 18 synthetic notes covering all workflow scenarios
- Task extraction, sentiment analysis, pattern detection test cases
- Connection network, feedback routing, duplicate detection tests

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

### Step 2: Check n8n Output

```bash
# If running in foreground, output is visible
# If running in background, check where you redirected output

# Or check recent n8n errors from terminal history
# n8n prints errors to stderr when executing workflows
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
// In n8n Function node (uses hardcoded local path)
const Database = require('better-sqlite3');
const db = new Database('/Users/chaseeasterling/selene-n8n/data/selene.db');

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
# Test Ollama directly (local n8n uses localhost)
curl http://localhost:11434/api/generate \
  -d '{"model": "mistral:7b", "prompt": "test", "stream": false}'
```

**Common Ollama issues:**
- Ollama not running: `ollama serve`
- Model not pulled: `ollama pull mistral:7b`

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

### "n8n won't start"

```bash
# Check if port 5678 in use
lsof -i :5678

# Kill process using port
kill -9 <PID>

# Verify n8n is installed
n8n --version  # Should show 1.110.1

# Verify better-sqlite3 is installed
npm ls -g better-sqlite3
```

### "Workflow fails immediately"

**Checklist:**
- [ ] Check credentials in n8n UI
- [ ] Verify database file exists (`data/selene.db`)
- [ ] Check Ollama running (`ollama serve`)
- [ ] Check n8n console output for errors

### "Database locked"

```bash
# Restart n8n
pkill -f "n8n start"
./scripts/start-n8n-local.sh

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
# Check if installed globally
npm ls -g better-sqlite3

# Reinstall if missing (must match n8n's expected version)
npm install -g better-sqlite3@11.0.0

# Restart n8n
pkill -f "n8n start"
./scripts/start-n8n-local.sh
```

---

## Environment Variables

**Location:** `scripts/start-n8n-local.sh` (committed to git, no secrets)

**Key variables set by startup script:**

```bash
# n8n data directory
N8N_USER_FOLDER=/Users/chaseeasterling/selene-n8n/.n8n-local

# Selene-specific paths (exposed to workflows via $env)
SELENE_DB_PATH=/Users/chaseeasterling/selene-n8n/data/selene.db
OBSIDIAN_VAULT_PATH=/Users/chaseeasterling/selene-n8n/vault
SELENE_PROJECT_ROOT=/Users/chaseeasterling/selene-n8n

# Ollama
OLLAMA_BASE_URL=http://localhost:11434

# Node modules
NODE_FUNCTION_ALLOW_EXTERNAL=better-sqlite3
```

**Note:** Workflows use hardcoded paths in Function nodes because n8n's VM2 sandbox
doesn't expose `process.env` or `$env` inside JavaScript code. The env vars above
are for n8n internal use and expression-based nodes.

**To change paths:**

```bash
# 1. Edit start script
nano scripts/start-n8n-local.sh

# 2. Update workflow JSON files
# (Database paths are hardcoded in Function nodes)

# 3. Re-import workflows
export N8N_USER_FOLDER=/path/to/.n8n-local
n8n import:workflow --input=workflows/XX-name/workflow.json

# 4. Restart n8n
pkill -f "n8n start"
./scripts/start-n8n-local.sh
```

---

## Daily Development Checklist

### Starting Work

- [ ] Check project status: `@.claude/PROJECT-STATUS.md`
- [ ] Start n8n: `./scripts/start-n8n-local.sh &`
- [ ] Check n8n: `curl -s http://localhost:5678/healthz`
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
