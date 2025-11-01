# Test Environment Strategy for Selene

**Created:** 2025-11-01
**Status:** Planning Phase
**Goal:** Enable safe feature development with isolated test environment while using Selene in production

---

## Table of Contents

1. [Overview](#overview)
2. [Architecture Design](#architecture-design)
3. [Test Environment Components](#test-environment-components)
4. [Implementation Plan](#implementation-plan)
5. [Testing Workflow](#testing-workflow)
6. [Feature Deployment Strategy](#feature-deployment-strategy)
7. [Data Isolation Strategy](#data-isolation-strategy)

---

## Overview

### Goals

1. **Dual Operation**: Use production Selene daily while developing new features
2. **Data Isolation**: Prevent test notes from polluting production database/vault
3. **Safe Testing**: Simulate Drafts webhook for testing (Drafts action → production only)
4. **Clean Migration**: Deploy tested features to production without corruption

### Key Requirements

- ✅ Separate test Obsidian vault from production vault
- ✅ Separate test database from production database
- ✅ Webhook-based test note submission (bypassing Drafts)
- ✅ Test runs are clearly labeled and isolated
- ✅ Feature changes can be validated before production deployment
- ✅ Production system remains stable during development

---

## Architecture Design

### Current Production Architecture

```
┌─────────────┐
│ Drafts App  │ (Production only)
└──────┬──────┘
       │ POST /webhook/api/drafts
       ▼
┌──────────────────────────────┐
│ Workflow 01: Ingestion       │
│ DB: ./data/selene.db         │
└──────┬───────────────────────┘
       │ POST /webhook/api/process-note
       ▼
┌──────────────────────────────┐
│ Workflow 02: LLM Processing  │
│ DB: ./data/selene.db         │
└──────┬───────────────────────┘
       │ POST /webhook/api/analyze-sentiment
       ▼
┌──────────────────────────────┐
│ Workflow 05: Sentiment       │
│ DB: ./data/selene.db         │
└──────┬───────────────────────┘
       │ POST /webhook/obsidian-export
       ▼
┌──────────────────────────────┐
│ Workflow 04: Obsidian Export │
│ Vault: ./vault               │
└──────────────────────────────┘
```

### Proposed Dual-Environment Architecture

```
PRODUCTION PATH:
┌─────────────┐
│ Drafts App  │
└──────┬──────┘
       │ POST /webhook/api/drafts
       ▼
┌──────────────────────────────┐
│ Workflow 01: Ingestion       │
│ DB: ./data/selene.db         │
│ Vault: ./vault               │
│ test_run: NULL               │
└──────────────────────────────┘
       ↓ (continue production chain)

TEST PATH:
┌─────────────────┐
│ Test Webhook    │
│ (curl/Postman)  │
└────────┬────────┘
         │ POST /webhook/api/test/drafts
         │ Body: {..., "test_run": "test_v1.2.3"}
         ▼
┌──────────────────────────────┐
│ Workflow 01-Test: Ingestion  │
│ DB: ./data/selene-test.db    │
│ Vault: ./vault-test          │
│ test_run: "test_v1.2.3"      │
└──────────────────────────────┘
         ↓ (continue test chain)
```

### Strategy: Database & Vault Isolation

**Option A: Parallel Workflows (Recommended)**
- Create test-specific copies of workflows (01-Test, 02-Test, etc.)
- Test workflows use different database path: `/selene/data-test/selene-test.db`
- Test workflows use different vault path: `/obsidian-test`
- Test webhooks use `/api/test/*` endpoints
- Production workflows unchanged, use `/api/*` endpoints

**Option B: Single Workflows with Branching**
- Modify existing workflows to detect `test_run` parameter
- Branch logic routes to test DB/vault if `test_run` present
- More complex but fewer workflows to maintain

**Recommendation: Option A (Parallel Workflows)**
- Cleaner separation
- Production workflows remain untouched during development
- Easier rollback if test changes break something
- Can test entire workflow changes, not just code logic

---

## Test Environment Components

### 1. Test Database

**Location:** `./data-test/selene-test.db`

**Setup:**
```bash
# Create test data directory
mkdir -p data-test

# Copy schema and initialize test database
sqlite3 data-test/selene-test.db < database/schema.sql

# Verify test database
sqlite3 data-test/selene-test.db "SELECT name FROM sqlite_master WHERE type='table';"
```

**Characteristics:**
- Identical schema to production database
- Completely separate file
- Can be wiped and recreated anytime
- No impact on production data

### 2. Test Obsidian Vault

**Location:** `./vault-test`

**Setup:**
```bash
# Create test vault directory structure
mkdir -p vault-test/Selene/Timeline/2025/{01,02,03,04,05,06,07,08,09,10,11,12}
mkdir -p vault-test/Selene/Concepts
mkdir -p vault-test/Selene/Themes
mkdir -p vault-test/Selene/Patterns

# Create vault configuration
cat > vault-test/.obsidian/config <<EOF
{
  "name": "Selene Test Vault",
  "baseFontSize": 16
}
EOF
```

**Characteristics:**
- Same structure as production vault
- Can be deleted/recreated anytime
- Open in separate Obsidian window for comparison
- No link pollution to production notes

### 3. Test Workflows

**Naming Convention:**
- Production: `Selene: 01 - Ingestion`
- Test: `Selene TEST: 01 - Ingestion`

**Test Workflow Endpoints:**
- Ingestion: `POST /webhook/api/test/drafts`
- LLM Processing: `POST /webhook/api/test/process-note`
- Sentiment: `POST /webhook/api/test/analyze-sentiment`
- Obsidian Export: `POST /webhook/test/obsidian-export`

**Key Differences:**
- Database path: `/selene/data-test/selene-test.db` instead of `/selene/data/selene.db`
- Vault path: `/obsidian-test` instead of `/obsidian`
- All `test_run` fields populated with identifier (e.g., "test_feature_v1")
- Otherwise identical logic to production workflows

### 4. Docker Compose Configuration

**Update `docker-compose.yml` to mount test directories:**

```yaml
services:
  n8n:
    volumes:
      # Production volumes (existing)
      - ${SELENE_DATA_PATH:-./data}:/selene/data:rw
      - ${OBSIDIAN_VAULT_PATH:-./vault}:/obsidian:rw

      # Test volumes (new)
      - ${SELENE_TEST_DATA_PATH:-./data-test}:/selene/data-test:rw
      - ${OBSIDIAN_TEST_VAULT_PATH:-./vault-test}:/obsidian-test:rw

      # Workflows
      - ./:/workflows:ro
```

**Update `.env`:**

```bash
# Production paths (existing)
SELENE_DATA_PATH=./data
OBSIDIAN_VAULT_PATH=./vault

# Test paths (new)
SELENE_TEST_DATA_PATH=./data-test
OBSIDIAN_TEST_VAULT_PATH=./vault-test
```

### 5. Test Note Submission Script

**Location:** `./scripts/test-ingest.sh`

```bash
#!/bin/bash
# Submit test note to test workflow

TEST_RUN="${1:-test_manual}"
TITLE="${2:-Test Note}"
CONTENT="${3:-This is a test note for development.}"

curl -X POST http://localhost:5678/webhook/api/test/drafts \
  -H "Content-Type: application/json" \
  -d "{
    \"title\": \"$TITLE\",
    \"content\": \"$CONTENT\",
    \"timestamp\": \"$(date -u +"%Y-%m-%dT%H:%M:%SZ")\",
    \"test_run\": \"$TEST_RUN\",
    \"source_type\": \"test_webhook\"
  }"

echo ""
echo "Test note submitted with test_run: $TEST_RUN"
echo "Query results:"
echo ""

# Wait for processing
sleep 2

# Show results
sqlite3 data-test/selene-test.db \
  "SELECT id, title, status, test_run FROM raw_notes ORDER BY id DESC LIMIT 1;"
```

**Usage:**
```bash
chmod +x scripts/test-ingest.sh

# Submit test note with default test_run
./scripts/test-ingest.sh

# Submit with specific test run identifier
./scripts/test-ingest.sh "feature_pattern_detection_v1" "Pattern Test" "Testing pattern detection feature"

# Submit with version tag
./scripts/test-ingest.sh "test_v2.1.0"
```

---

## Implementation Plan

### Phase 1: Set Up Test Infrastructure (1-2 hours)

**Tasks:**

1. **Create test directories**
   ```bash
   mkdir -p data-test
   mkdir -p vault-test/Selene/{Timeline/2025/{01..12},Concepts,Themes,Patterns}
   ```

2. **Initialize test database**
   ```bash
   sqlite3 data-test/selene-test.db < database/schema.sql
   ```

3. **Update docker-compose.yml**
   - Add test volume mounts

4. **Update .env**
   - Add test path variables

5. **Restart n8n**
   ```bash
   docker-compose down
   docker-compose up -d
   ```

6. **Verify mounts**
   ```bash
   docker exec selene-n8n ls -la /selene/data-test
   docker exec selene-n8n ls -la /obsidian-test
   ```

### Phase 2: Create Test Workflows (2-3 hours)

**Approach: Copy & Modify Production Workflows**

1. **Copy workflow 01 (Ingestion)**
   ```bash
   cp workflows/01-ingestion/workflow.json workflows/01-ingestion/workflow-test.json
   ```

2. **Modify test workflow:**
   - Change name: `"name": "Selene TEST: 01 - Ingestion"`
   - Change webhook path: `"path": "api/test/drafts"`
   - Update database path in all SQLite nodes: `/selene/data-test/selene-test.db`
   - Add `test_run` field to INSERT query
   - Update trigger webhook to test endpoint: `/webhook/api/test/process-note`

3. **Repeat for workflows 02, 04, 05**
   - Workflow 02: LLM Processing
     - Webhook: `/webhook/api/test/process-note`
     - DB path: `/selene/data-test/selene-test.db`
     - Trigger: `/webhook/api/test/analyze-sentiment`

   - Workflow 05: Sentiment Analysis
     - Webhook: `/webhook/api/test/analyze-sentiment`
     - DB path: `/selene/data-test/selene-test.db`
     - Trigger: `/webhook/test/obsidian-export`

   - Workflow 04: Obsidian Export
     - Webhook: `/webhook/test/obsidian-export`
     - DB path: `/selene/data-test/selene-test.db`
     - Vault path: `/obsidian-test`

4. **Import test workflows**
   ```bash
   docker exec selene-n8n n8n import:workflow --input=/workflows/workflows/01-ingestion/workflow-test.json
   docker exec selene-n8n n8n import:workflow --input=/workflows/workflows/02-llm-processing/workflow-test.json
   docker exec selene-n8n n8n import:workflow --input=/workflows/workflows/05-sentiment-analysis/workflow-test.json
   docker exec selene-n8n n8n import:workflow --input=/workflows/workflows/04-obsidian-export/workflow-test.json
   ```

5. **Activate test workflows in n8n UI**

### Phase 3: Create Test Tooling (30 min)

1. **Create test submission script:** `scripts/test-ingest.sh`
2. **Create test verification script:** `scripts/test-verify.sh`
3. **Create test cleanup script:** `scripts/test-reset.sh`

**test-verify.sh:**
```bash
#!/bin/bash
# Verify test note processing

TEST_RUN="${1:-test_manual}"

echo "=== Test Notes for: $TEST_RUN ==="
echo ""

echo "Raw Notes:"
sqlite3 data-test/selene-test.db \
  "SELECT id, title, status FROM raw_notes WHERE test_run = '$TEST_RUN';"

echo ""
echo "Processed Notes:"
sqlite3 data-test/selene-test.db \
  "SELECT pn.id, rn.title, pn.overall_sentiment, rn.exported_to_obsidian
   FROM processed_notes pn
   JOIN raw_notes rn ON pn.raw_note_id = rn.id
   WHERE rn.test_run = '$TEST_RUN';"

echo ""
echo "Exported Files:"
find vault-test/Selene -name "*.md" -newer data-test/selene-test.db -type f
```

**test-reset.sh:**
```bash
#!/bin/bash
# Reset test environment

read -p "This will delete all test data. Continue? (y/N) " -n 1 -r
echo
if [[ $REPLY =~ ^[Yy]$ ]]; then
  # Backup test DB (optional)
  if [ -f data-test/selene-test.db ]; then
    cp data-test/selene-test.db "data-test/backups/selene-test-$(date +%Y%m%d-%H%M%S).db"
  fi

  # Delete test database
  rm -f data-test/selene-test.db

  # Recreate test database
  sqlite3 data-test/selene-test.db < database/schema.sql

  # Clean test vault
  rm -rf vault-test/Selene/Timeline/*/*.md
  rm -rf vault-test/Selene/Concepts/*.md
  rm -rf vault-test/Selene/Themes/*.md

  echo "Test environment reset complete!"
else
  echo "Cancelled."
fi
```

### Phase 4: Test End-to-End (30 min)

1. **Submit test note**
   ```bash
   ./scripts/test-ingest.sh "test_e2e_v1" "End-to-End Test" "Testing complete workflow from ingestion to Obsidian export"
   ```

2. **Monitor processing**
   ```bash
   docker-compose logs -f n8n | grep -i "test"
   ```

3. **Verify results**
   ```bash
   ./scripts/test-verify.sh "test_e2e_v1"
   ```

4. **Check Obsidian vault**
   ```bash
   ls -lah vault-test/Selene/Timeline/2025/11/
   ```

5. **Compare with production**
   - Verify production vault/DB unchanged
   - Confirm test data isolated
   - Validate test note has `test_run` field populated

---

## Testing Workflow

### Daily Development Cycle

**Morning: Start with clean test environment**
```bash
# Optional: Reset if needed
./scripts/test-reset.sh

# Verify production is clean
sqlite3 data/selene.db "SELECT COUNT(*) FROM raw_notes WHERE test_run IS NOT NULL;"
# Should return: 0
```

**Development: Test feature changes**
```bash
# 1. Modify test workflow (e.g., improve LLM prompt)
vim workflows/02-llm-processing/workflow-test.json

# 2. Reimport test workflow
docker exec selene-n8n n8n import:workflow --input=/workflows/workflows/02-llm-processing/workflow-test.json
docker-compose restart n8n

# 3. Submit test note
./scripts/test-ingest.sh "feature_better_prompts_v1" "Prompt Test" "Testing improved concept extraction prompts"

# 4. Verify results
./scripts/test-verify.sh "feature_better_prompts_v1"

# 5. Check quality
sqlite3 data-test/selene-test.db \
  "SELECT concepts, confidence_score FROM processed_notes ORDER BY id DESC LIMIT 1;"
```

**Iteration: Repeat until satisfied**
```bash
# Make adjustments
vim workflows/02-llm-processing/workflow-test.json

# Reimport & restart
docker exec selene-n8n n8n import:workflow --input=/workflows/workflows/02-llm-processing/workflow-test.json
docker-compose restart n8n

# Test again
./scripts/test-ingest.sh "feature_better_prompts_v2" "Prompt Test v2" "Iteration 2 of prompt improvements"

# Compare results
sqlite3 data-test/selene-test.db \
  "SELECT test_run, concepts, confidence_score FROM processed_notes pn
   JOIN raw_notes rn ON pn.raw_note_id = rn.id
   WHERE rn.test_run LIKE 'feature_better_prompts%';"
```

**Production: Use Selene normally**
- Send notes from Drafts as usual
- Production workflows process via `/webhook/api/drafts`
- Production DB and vault remain untouched
- No `test_run` field in production notes

---

## Feature Deployment Strategy

### Goal: Move tested changes to production safely

### Strategy 1: Workflow Promotion (Recommended)

**When:** Feature development complete and tested

**Steps:**

1. **Final validation in test**
   ```bash
   # Run comprehensive test suite
   ./scripts/test-ingest.sh "final_validation" "Final Test" "Pre-production validation"
   sleep 40
   ./scripts/test-verify.sh "final_validation"
   ```

2. **Backup production**
   ```bash
   # Backup production database
   cp data/selene.db "data/backups/selene-prod-$(date +%Y%m%d-%H%M%S).db"

   # Backup production vault (optional)
   tar -czf "vault/backups/vault-prod-$(date +%Y%m%d-%H%M%S).tar.gz" vault/
   ```

3. **Copy test workflow to production**
   ```bash
   # Example: Promoting workflow 02 changes
   cp workflows/02-llm-processing/workflow-test.json workflows/02-llm-processing/workflow.json

   # IMPORTANT: Revert test-specific changes:
   # - Change webhook paths back to /api/* (from /api/test/*)
   # - Change DB path to /selene/data/selene.db (from /selene/data-test/*)
   # - Change vault path to /obsidian (from /obsidian-test)
   # - Remove test_run field additions
   # - Change name back to "Selene: 02 - LLM Processing"

   vim workflows/02-llm-processing/workflow.json
   # Make above changes manually or with sed
   ```

4. **Import updated production workflow**
   ```bash
   docker exec selene-n8n n8n import:workflow --input=/workflows/workflows/02-llm-processing/workflow.json
   ```

5. **Restart n8n**
   ```bash
   docker-compose restart n8n
   ```

6. **Validate production**
   ```bash
   # Send test note via Drafts or webhook
   curl -X POST http://localhost:5678/webhook/api/drafts \
     -H "Content-Type: application/json" \
     -d '{
       "title": "Production Validation",
       "content": "Testing new feature in production",
       "timestamp": "'$(date -u +"%Y-%m-%dT%H:%M:%SZ")'"
     }'

   # Wait and verify
   sleep 40

   # Check results
   sqlite3 data/selene.db \
     "SELECT id, title, status FROM raw_notes ORDER BY id DESC LIMIT 1;"
   ```

7. **Monitor for issues**
   ```bash
   docker-compose logs -f n8n
   ```

8. **Rollback if needed**
   ```bash
   # Restore from backup
   cp "data/backups/selene-prod-YYYYMMDD-HHMMSS.db" data/selene.db

   # Reimport old workflow
   # (Keep old workflow versions in git)
   docker exec selene-n8n n8n import:workflow --input=/workflows/workflows/02-llm-processing/workflow-old.json
   docker-compose restart n8n
   ```

### Strategy 2: Gradual Rollout

**When:** Major changes or risky features

**Steps:**

1. **Deploy to production but keep test endpoint active**
   - Production workflow uses new logic
   - Test workflow remains for validation
   - Can compare production vs test results

2. **Use `test_run` flag in production temporarily**
   - Add optional `test_run` parameter to production ingestion
   - Test notes in production marked with `test_run = "prod_test_v1"`
   - Easy to identify and remove if issues arise

3. **Monitor for 24-48 hours**
   - Check error rates
   - Compare confidence scores
   - Validate Obsidian exports

4. **Full rollout or rollback**
   - If stable: remove test-specific code
   - If issues: rollback to previous version

### Strategy 3: Feature Flags (Advanced)

**When:** Multiple features in development

**Implementation:**
- Add `feature_flags` table to database
- Workflows check flags before executing new logic
- Enable/disable features without workflow reimport

**Example:**
```sql
CREATE TABLE feature_flags (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  feature_name TEXT UNIQUE NOT NULL,
  enabled INTEGER DEFAULT 0,
  description TEXT,
  created_at DATETIME DEFAULT CURRENT_TIMESTAMP
);

INSERT INTO feature_flags (feature_name, enabled, description)
VALUES ('enhanced_sentiment', 1, 'Enhanced ADHD sentiment analysis');
```

**In workflow:**
```javascript
// Check feature flag
const db = require('better-sqlite3')('/selene/data/selene.db');
const flag = db.prepare('SELECT enabled FROM feature_flags WHERE feature_name = ?')
  .get('enhanced_sentiment');

if (flag && flag.enabled) {
  // Use new logic
} else {
  // Use old logic
}
```

---

## Data Isolation Strategy

### Preventing Cross-Contamination

**Database Level:**
- ✅ Separate database files
- ✅ `test_run` column in all test notes (NOT NULL in test DB)
- ✅ Foreign key constraints prevent cross-references
- ✅ Test database can be wiped without affecting production

**Obsidian Level:**
- ✅ Separate vault directories
- ✅ No links between test and production vaults
- ✅ Can open both vaults simultaneously (different windows)
- ✅ Test vault clearly labeled: "Selene Test Vault"

**Workflow Level:**
- ✅ Different webhook endpoints (/api/* vs /api/test/*)
- ✅ Different workflow names (visual distinction in n8n)
- ✅ Different database/vault paths hardcoded
- ✅ Production workflows never access test resources

**Verification Queries:**

```bash
# Ensure no test notes in production
sqlite3 data/selene.db \
  "SELECT COUNT(*) FROM raw_notes WHERE test_run IS NOT NULL;"
# Expected: 0

# Ensure all test notes labeled
sqlite3 data-test/selene-test.db \
  "SELECT COUNT(*) FROM raw_notes WHERE test_run IS NULL;"
# Expected: 0

# Verify production vault has no test files
grep -r "test_run" vault/Selene/
# Expected: no matches

# Verify test vault isolated
ls -la vault-test/Selene/Timeline/2025/11/ | wc -l
# Should only show test files
```

---

## Maintenance & Best Practices

### Test Environment Hygiene

**Weekly:**
```bash
# Archive old test data
tar -czf "data-test/archives/test-$(date +%Y%m%d).tar.gz" data-test/selene-test.db vault-test/

# Clean up old test runs
sqlite3 data-test/selene-test.db \
  "DELETE FROM raw_notes WHERE created_at < datetime('now', '-7 days');"

# Vacuum test database
sqlite3 data-test/selene-test.db "VACUUM;"
```

**Monthly:**
```bash
# Full test environment reset
./scripts/test-reset.sh

# Verify production integrity
sqlite3 data/selene.db "PRAGMA integrity_check;"

# Verify test isolation
./scripts/verify-isolation.sh
```

### Git Strategy

**Branches:**
- `main` - Production workflows
- `develop` - Test workflow development
- `feature/*` - Specific feature branches

**Workflow:**
```bash
# Start new feature
git checkout -b feature/better-sentiment develop

# Modify test workflows
vim workflows/05-sentiment-analysis/workflow-test.json

# Test thoroughly
./scripts/test-ingest.sh "feature_better_sentiment"

# Commit test workflow changes
git add workflows/05-sentiment-analysis/workflow-test.json
git commit -m "Test: Enhanced sentiment analysis for ADHD patterns"

# Merge to develop for integration testing
git checkout develop
git merge feature/better-sentiment

# When ready for production
git checkout main
git merge develop

# Update production workflow (remove test-specific code)
# Deploy to production
```

### Documentation

**Update after each deployment:**
- `docs/roadmap/02-CURRENT-STATUS.md` - Mark features complete
- `docs/CHANGELOG.md` - Document changes
- `workflows/*/README.md` - Update workflow docs
- `docs/TEST-RESULTS.md` - Record test outcomes

---

## Example: Complete Feature Development Cycle

### Scenario: Adding "Focus Level" to Sentiment Analysis

**1. Design Phase**
```bash
# Create feature branch
git checkout -b feature/focus-level develop

# Document the feature
vim docs/features/FOCUS-LEVEL.md
```

**2. Database Update**
```bash
# Update test database schema
sqlite3 data-test/selene-test.db \
  "ALTER TABLE processed_notes ADD COLUMN focus_level TEXT;"

# Add to schema file for production deployment later
vim database/schema.sql
# Add: focus_level TEXT after energy_level
```

**3. Modify Test Workflow**
```bash
# Update test sentiment workflow
vim workflows/05-sentiment-analysis/workflow-test.json

# Modify Ollama prompt to detect focus level
# Update INSERT query to include focus_level field
```

**4. Import & Test**
```bash
# Import updated test workflow
docker exec selene-n8n n8n import:workflow --input=/workflows/workflows/05-sentiment-analysis/workflow-test.json
docker-compose restart n8n

# Submit test notes
./scripts/test-ingest.sh "focus_v1" "High Focus Test" "Deep work session on complex problem"
./scripts/test-ingest.sh "focus_v1" "Low Focus Test" "Distracted, bouncing between tasks"
./scripts/test-ingest.sh "focus_v1" "Medium Focus Test" "Getting things done but some distractions"
```

**5. Validate Results**
```bash
# Check focus level detection
sqlite3 data-test/selene-test.db \
  "SELECT rn.title, pn.focus_level, pn.energy_level, pn.emotional_tone
   FROM processed_notes pn
   JOIN raw_notes rn ON pn.raw_note_id = rn.id
   WHERE rn.test_run = 'focus_v1';"

# Expected:
# High Focus Test|high|medium|focused
# Low Focus Test|low|medium|scattered
# Medium Focus Test|medium|medium|engaged
```

**6. Iterate if Needed**
```bash
# If results not accurate, adjust prompt
vim workflows/05-sentiment-analysis/workflow-test.json

# Reimport and test again with v2
./scripts/test-ingest.sh "focus_v2" "High Focus Test 2" "..."
```

**7. Promote to Production**
```bash
# Backup production
cp data/selene.db "data/backups/selene-prod-$(date +%Y%m%d).db"

# Update production database schema
sqlite3 data/selene.db \
  "ALTER TABLE processed_notes ADD COLUMN focus_level TEXT;"

# Copy test workflow to production (manual modifications)
cp workflows/05-sentiment-analysis/workflow-test.json workflows/05-sentiment-analysis/workflow.json

# Modify for production:
# - Change webhook path: /api/analyze-sentiment
# - Change DB path: /selene/data/selene.db
# - Remove test_run references
vim workflows/05-sentiment-analysis/workflow.json

# Import to production
docker exec selene-n8n n8n import:workflow --input=/workflows/workflows/05-sentiment-analysis/workflow.json
docker-compose restart n8n

# Test production
curl -X POST http://localhost:5678/webhook/api/drafts \
  -H "Content-Type: application/json" \
  -d '{"title":"Prod Focus Test","content":"Testing focus level in production",...}'

sleep 40

# Verify
sqlite3 data/selene.db \
  "SELECT title, focus_level FROM processed_notes pn
   JOIN raw_notes rn ON pn.raw_note_id = rn.id
   ORDER BY pn.id DESC LIMIT 1;"
```

**8. Document & Commit**
```bash
# Commit production changes
git add workflows/05-sentiment-analysis/workflow.json database/schema.sql
git commit -m "Add focus_level to sentiment analysis"

# Update roadmap
vim docs/roadmap/02-CURRENT-STATUS.md
git add docs/roadmap/02-CURRENT-STATUS.md
git commit -m "Update roadmap: Focus level feature complete"

# Merge to main
git checkout main
git merge feature/focus-level
git push
```

---

## Troubleshooting

### Issue: Test notes appearing in production

**Diagnosis:**
```bash
sqlite3 data/selene.db "SELECT * FROM raw_notes WHERE test_run IS NOT NULL;"
```

**Fix:**
- Verify test workflows use correct webhook paths (/api/test/*)
- Check test script uses test endpoint
- Delete contaminated notes:
  ```bash
  sqlite3 data/selene.db "DELETE FROM raw_notes WHERE test_run IS NOT NULL;"
  ```

### Issue: Production workflows not triggering

**Diagnosis:**
```bash
# Check webhook status in n8n UI
# Verify workflows are active
docker-compose logs n8n | grep -i "activated"
```

**Fix:**
```bash
# Restart n8n
docker-compose restart n8n

# Reactivate workflows in UI
```

### Issue: Test and production data mixed in Obsidian

**Prevention:**
- Always use separate vault directories
- Never modify vault paths after setup
- Use different Obsidian windows

**Fix:**
```bash
# Clean up mixed vault
rm -rf vault/Selene/Timeline/2025/11/*test*.md

# Verify test vault separation
ls vault-test/Selene/Timeline/2025/11/
```

### Issue: Cannot connect to test database

**Diagnosis:**
```bash
docker exec selene-n8n ls -la /selene/data-test/
```

**Fix:**
```bash
# Verify volume mount in docker-compose.yml
# Recreate test database
mkdir -p data-test
sqlite3 data-test/selene-test.db < database/schema.sql

# Restart n8n
docker-compose down
docker-compose up -d
```

---

## Summary

### Test Environment Benefits

1. **Safety**: Develop features without risking production data
2. **Confidence**: Thoroughly test before deploying
3. **Speed**: Iterate quickly without affecting daily usage
4. **Isolation**: Complete separation of test and production
5. **Flexibility**: Easy rollback and experimentation

### Key Principles

- ✅ **Separate databases**: Never mix test and production data
- ✅ **Separate vaults**: No cross-linking or contamination
- ✅ **Parallel workflows**: Test and production coexist
- ✅ **Webhook isolation**: Different endpoints for test/prod
- ✅ **Clear labeling**: `test_run` field marks all test data
- ✅ **Easy cleanup**: Reset test environment anytime
- ✅ **Safe deployment**: Test → validate → backup → deploy → verify

### Next Steps

1. Implement Phase 1: Set up test infrastructure
2. Implement Phase 2: Create test workflows
3. Implement Phase 3: Create test tooling scripts
4. Implement Phase 4: Test end-to-end
5. Begin using test environment for feature development
6. Document first feature deployment using this strategy

---

**Ready to build with confidence!** 🚀
