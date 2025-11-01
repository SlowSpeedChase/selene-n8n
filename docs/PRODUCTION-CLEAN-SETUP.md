# Production Clean Setup Guide

**Goal:** Ensure production database never contains test notes and establish clear separation between production and test environments.

---

## Current State

Your production database at `./data/selene.db` currently contains:
- **Total notes:** 19
- **Test notes:** 4 (these should not be in production)
- **Production notes:** 15

## Quick Start: Clean Production Database

### Step 1: Run the cleanup script

```bash
cd /Users/chaseeasterling/selene-n8n
./scripts/clean-production-database.sh
```

This script will:
1. Show you which test notes are in production
2. Ask for confirmation before removing them
3. Create a backup before making changes
4. Remove all test notes from production
5. Verify production is clean

### Step 2: Verify production is clean

```bash
./scripts/verify-production-clean.sh
```

Expected output:
```
✓ Production database is CLEAN
✓ No test notes found
```

---

## Preventing Future Contamination

### Strategy 1: Workflow Validation (Recommended)

**Modify production ingestion workflow to reject test notes:**

In workflow `01-ingestion/workflow.json`, add validation node after receiving webhook:

```javascript
// Reject if test_run field is present
const body = $input.item.json.body || $input.item.json;

if (body.test_run || body.testRun) {
    throw new Error("Test notes not allowed in production. Use /api/test/drafts endpoint.");
}

// Continue processing
return { ...body };
```

This ensures that even if someone accidentally sends a test note to production webhook, it will be rejected.

### Strategy 2: Separate Webhooks

**Production endpoints (NEVER accept test_run):**
- `/webhook/api/drafts` - Production ingestion from Drafts app
- `/webhook/api/process-note` - Production LLM processing
- `/webhook/api/analyze-sentiment` - Production sentiment
- `/webhook/obsidian-export` - Production export

**Test endpoints (REQUIRE test_run):**
- `/webhook/api/test/drafts` - Test ingestion
- `/webhook/api/test/process-note` - Test LLM processing
- `/webhook/api/test/analyze-sentiment` - Test sentiment
- `/webhook/test/obsidian-export` - Test export

Production workflows should NEVER respond to `/api/test/*` endpoints.

### Strategy 3: Database Constraints (Optional)

Add a check constraint to production database that prevents test notes:

```sql
-- This would need to be added when creating table
-- Not recommended for existing database as it requires recreation
CREATE TABLE raw_notes (
    -- ... other fields ...
    test_run TEXT CHECK(test_run IS NULL),  -- Enforce NULL in production
    -- ... other fields ...
);
```

**However**, since your table already exists, we'll use workflow validation instead.

---

## Test Environment Setup

Once production is clean, set up the test environment:

### 1. Create test database

```bash
mkdir -p data-test
sqlite3 data-test/selene-test.db < database/schema.sql
```

### 2. Create test vault

```bash
mkdir -p vault-test/Selene/Timeline/2025/{01,02,03,04,05,06,07,08,09,10,11,12}
mkdir -p vault-test/Selene/Concepts
mkdir -p vault-test/Selene/Themes
mkdir -p vault-test/Selene/Patterns
```

### 3. Update docker-compose.yml

Add test mounts:

```yaml
services:
  n8n:
    volumes:
      # Production (existing)
      - ${SELENE_DATA_PATH:-./data}:/selene/data:rw
      - ${OBSIDIAN_VAULT_PATH:-./vault}:/obsidian:rw

      # Test (new)
      - ${SELENE_TEST_DATA_PATH:-./data-test}:/selene/data-test:rw
      - ${OBSIDIAN_TEST_VAULT_PATH:-./vault-test}:/obsidian-test:rw

      # Workflows
      - ./:/workflows:ro
```

### 4. Update .env

Add test paths:

```bash
# Production paths
SELENE_DATA_PATH=./data
OBSIDIAN_VAULT_PATH=./vault

# Test paths
SELENE_TEST_DATA_PATH=./data-test
OBSIDIAN_TEST_VAULT_PATH=./vault-test
```

### 5. Restart n8n

```bash
docker-compose down
docker-compose up -d
```

### 6. Verify mounts

```bash
docker exec selene-n8n ls -la /selene/data-test
docker exec selene-n8n ls -la /obsidian-test
```

---

## Daily Usage Pattern

### Production Usage (Normal Selene Use)

**From Drafts App:**
- Your Drafts action sends to: `http://localhost:5678/webhook/api/drafts`
- Notes go to production database: `./data/selene.db`
- Notes exported to production vault: `./vault`
- **NO** `test_run` field present
- Works exactly as it does now

### Test Usage (Feature Development)

**From Test Webhook:**
```bash
curl -X POST http://localhost:5678/webhook/api/test/drafts \
  -H "Content-Type: application/json" \
  -d '{
    "title": "Test Note",
    "content": "Testing new feature",
    "timestamp": "'$(date -u +"%Y-%m-%dT%H:%M:%SZ")'",
    "test_run": "feature_name_v1"
  }'
```

- Goes to test database: `./data-test/selene-test.db`
- Exported to test vault: `./vault-test`
- **ALWAYS** has `test_run` field
- Never touches production

---

## Verification Checklist

Run this checklist daily during development:

```bash
# 1. Verify production is clean
./scripts/verify-production-clean.sh

# 2. Check production stats
sqlite3 data/selene.db "SELECT COUNT(*) FROM raw_notes WHERE test_run IS NULL;"

# 3. Check test database exists
ls -lah data-test/selene-test.db

# 4. Verify test notes are isolated
sqlite3 data-test/selene-test.db "SELECT COUNT(*) FROM raw_notes WHERE test_run IS NOT NULL;"

# 5. Check vault separation
ls vault/ | head -5
ls vault-test/ | head -5
```

---

## Emergency: Test Notes in Production

If you accidentally get test notes in production:

### Option 1: Run cleanup script

```bash
./scripts/clean-production-database.sh
```

### Option 2: Manual cleanup

```bash
# Backup first
cp data/selene.db "data/backups/selene-$(date +%Y%m%d-%H%M%S).db"

# Remove test notes
sqlite3 data/selene.db <<EOF
-- Delete processed notes for test notes
DELETE FROM processed_notes WHERE raw_note_id IN (
  SELECT id FROM raw_notes WHERE test_run IS NOT NULL
);

-- Delete processed_notes_apple for test notes
DELETE FROM processed_notes_apple WHERE raw_note_id IN (
  SELECT id FROM raw_notes WHERE test_run IS NOT NULL
);

-- Delete test notes from raw_notes
DELETE FROM raw_notes WHERE test_run IS NOT NULL;

-- Optimize database
VACUUM;
EOF

# Verify
./scripts/verify-production-clean.sh
```

---

## Production Workflow Safeguards

### Add to Workflow 01 (Ingestion)

After the webhook trigger, add a validation node:

**Node Name:** "Validate Production Note"
**Type:** Function
**Code:**

```javascript
// Get webhook body
const body = $input.item.json.body || $input.item.json;

// Reject test notes
if (body.test_run || body.testRun) {
    throw new Error(
        "ERROR: Test notes not allowed in production workflow. " +
        "Please use /webhook/api/test/drafts for testing."
    );
}

// Log production note
console.log("Processing production note:", body.title || "Untitled");

// Pass through (without test_run field)
return {
    title: body.title || "",
    content: body.content || "",
    timestamp: body.timestamp || new Date().toISOString(),
    tags: body.tags || [],
    source_type: body.source_type || "drafts"
};
```

This ensures production workflow will **reject** any note with `test_run` field.

### Test the Safeguard

Try to send a test note to production (should fail):

```bash
curl -X POST http://localhost:5678/webhook/api/drafts \
  -H "Content-Type: application/json" \
  -d '{
    "title": "Should Fail",
    "content": "This should be rejected",
    "timestamp": "'$(date -u +"%Y-%m-%dT%H:%M:%SZ")'",
    "test_run": "should_fail"
  }'
```

Expected: Error message about test notes not allowed.

Send a normal note (should succeed):

```bash
curl -X POST http://localhost:5678/webhook/api/drafts \
  -H "Content-Type: application/json" \
  -d '{
    "title": "Production Note",
    "content": "This should work",
    "timestamp": "'$(date -u +"%Y-%m-%dT%H:%M:%SZ")'"
  }'
```

Expected: Note processed successfully.

---

## Summary

**Clean Production:**
1. ✓ Run `./scripts/clean-production-database.sh` to remove test notes
2. ✓ Run `./scripts/verify-production-clean.sh` to verify
3. ✓ Add validation to workflow to reject future test notes

**Test Environment:**
1. ✓ Create test database at `./data-test/selene-test.db`
2. ✓ Create test vault at `./vault-test`
3. ✓ Create test workflows with `/api/test/*` endpoints
4. ✓ Use test webhooks for all development

**Daily Practice:**
- Production: Use Drafts app as normal → goes to `/api/drafts`
- Testing: Use curl/scripts → goes to `/api/test/drafts`
- Never mix: Production workflows reject `test_run` field
- Verify daily: Run `./scripts/verify-production-clean.sh`

---

**Ready to start with a clean production environment!** 🎉

See `docs/TEST-ENVIRONMENT-STRATEGY.md` for complete test environment setup and feature development workflow.
