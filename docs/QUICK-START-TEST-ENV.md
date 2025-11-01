# Quick Start: Test Environment Setup

**Time Required:** 30 minutes
**Goal:** Get test environment running alongside production

---

## Prerequisites

- ✓ Production Selene running and working
- ✓ Docker and n8n operational
- ✓ Basic understanding of your workflow

---

## Step 1: Clean Production (5 minutes)

```bash
cd /Users/chaseeasterling/selene-n8n

# Check current state
./scripts/verify-production-clean.sh

# If contaminated, clean it
./scripts/clean-production-database.sh

# Verify clean
./scripts/verify-production-clean.sh
```

**Expected output:**
```
✓ Production database is CLEAN
✓ No test notes found
```

---

## Step 2: Create Test Infrastructure (10 minutes)

```bash
# Create test database directory
mkdir -p data-test

# Initialize test database with same schema as production
sqlite3 data-test/selene-test.db < database/schema.sql

# Create test vault structure
mkdir -p vault-test/Selene/Timeline/2025/{01,02,03,04,05,06,07,08,09,10,11,12}
mkdir -p vault-test/Selene/{Concepts,Themes,Patterns}

# Verify created
ls -la data-test/
ls -la vault-test/
```

---

## Step 3: Update Docker Configuration (5 minutes)

### Edit docker-compose.yml

Add these lines under `volumes:` section in the `n8n` service:

```yaml
services:
  n8n:
    volumes:
      # ... existing production volumes ...

      # Test volumes (ADD THESE)
      - ${SELENE_TEST_DATA_PATH:-./data-test}:/selene/data-test:rw
      - ${OBSIDIAN_TEST_VAULT_PATH:-./vault-test}:/obsidian-test:rw
```

### Edit .env

Add these lines at the end:

```bash
# Test Environment Paths
SELENE_TEST_DATA_PATH=./data-test
OBSIDIAN_TEST_VAULT_PATH=./vault-test
```

### Restart n8n

```bash
docker-compose down
docker-compose up -d
```

### Verify mounts

```bash
docker exec selene-n8n ls /selene/data-test
docker exec selene-n8n ls /obsidian-test
```

Should show the directories exist inside the container.

---

## Step 4: Create Test Workflows (Option A: Manual - 10 minutes)

**For now, let's create a simple test ingestion endpoint to validate the setup:**

### Test Script Method (Quickest)

Create a test submission script:

```bash
cat > scripts/test-note.sh <<'EOF'
#!/bin/bash
# Quick test note submission

TEST_RUN="${1:-manual_test}"
TITLE="${2:-Test Note $(date +%H:%M:%S)}"
CONTENT="${3:-This is a test note submitted at $(date)}"

echo "Submitting test note..."
echo "Test Run: $TEST_RUN"
echo "Title: $TITLE"
echo ""

# Submit to production webhook but we'll modify it to handle test_run
curl -X POST http://localhost:5678/webhook/api/drafts \
  -H "Content-Type: application/json" \
  -d "{
    \"title\": \"$TITLE\",
    \"content\": \"$CONTENT\",
    \"timestamp\": \"$(date -u +"%Y-%m-%dT%H:%M:%SZ")\",
    \"test_run\": \"$TEST_RUN\",
    \"source_type\": \"test_webhook\"
  }"

echo ""
echo ""
echo "Checking if note was created..."
sleep 2

# Check in test database
if [ -f "data-test/selene-test.db" ]; then
    echo "Test Database:"
    sqlite3 data-test/selene-test.db \
      "SELECT id, title, status, test_run FROM raw_notes ORDER BY id DESC LIMIT 1;"
else
    echo "Test database not found yet"
fi

echo ""
EOF

chmod +x scripts/test-note.sh
```

---

## Step 5: Create Production Safeguard (IMPORTANT)

Before creating test workflows, let's protect production from accidental test notes:

### Option A: Update Ingestion Workflow (Recommended later)

We'll do this after test workflows are working. For now, just be careful not to send test_run to production.

### Option B: Use Separate Endpoints

This is what we'll implement with test workflows in Step 6.

---

## Step 6: Validate Setup

Let's make sure everything is working before creating full test workflows:

```bash
# 1. Verify production database is clean
./scripts/verify-production-clean.sh

# 2. Verify test database exists and is empty
sqlite3 data-test/selene-test.db "SELECT COUNT(*) FROM raw_notes;"
# Should return: 0

# 3. Verify mounts
docker exec selene-n8n ls -la /selene/data-test/selene-test.db
docker exec selene-n8n ls -la /obsidian-test/Selene/

# 4. Check production can still receive notes (test with curl or Drafts)
# Use your Drafts app to send a real note - should work normally
```

---

## Step 7: Next Steps

You now have:
- ✓ Clean production database (no test notes)
- ✓ Separate test database (`./data-test/selene-test.db`)
- ✓ Separate test vault (`./vault-test`)
- ✓ Docker configured to mount both environments

**Next steps:**

### Option A: Start Simple (Recommended)

1. **Use production workflows for now** but manually segregate:
   - Production notes: From Drafts app (no test_run field)
   - Test notes: From curl with test_run field
   - Query test notes separately: `SELECT * FROM raw_notes WHERE test_run LIKE 'test_%'`

2. **When ready, create dedicated test workflows:**
   - See `docs/TEST-ENVIRONMENT-STRATEGY.md` Phase 2
   - Create copies of workflows with test endpoints
   - Point them to test database and vault

### Option B: Create Full Test Workflows Now

Follow the detailed guide in `docs/TEST-ENVIRONMENT-STRATEGY.md` Phase 2 to create:
- Test Workflow 01: Ingestion (webhook: `/api/test/drafts`)
- Test Workflow 02: LLM Processing (webhook: `/api/test/process-note`)
- Test Workflow 05: Sentiment (webhook: `/api/test/analyze-sentiment`)
- Test Workflow 04: Export (webhook: `/test/obsidian-export`)

---

## Quick Test

Let's do a simple test to make sure the infrastructure works:

```bash
# Manually insert a test note into test database
sqlite3 data-test/selene-test.db <<EOF
INSERT INTO raw_notes (title, content, content_hash, created_at, test_run, source_type)
VALUES (
  'Infrastructure Test',
  'Testing that test database is working',
  'test-hash-' || datetime('now'),
  datetime('now'),
  'infrastructure_test',
  'manual'
);
EOF

# Verify it's in test database
echo "Test Database:"
sqlite3 data-test/selene-test.db \
  "SELECT id, title, test_run FROM raw_notes;"

echo ""
echo "Production Database (should not have this note):"
sqlite3 data/selene.db \
  "SELECT COUNT(*) FROM raw_notes WHERE test_run = 'infrastructure_test';"
# Should return: 0

echo ""
echo "✓ If test database shows the note and production shows 0, setup is working!"
```

---

## Troubleshooting

### Issue: docker-compose won't start

```bash
# Check syntax
docker-compose config

# View errors
docker-compose up
```

### Issue: Can't access test database from container

```bash
# Check mount
docker exec selene-n8n ls -la /selene/data-test/

# If missing, verify docker-compose.yml volume mapping
# Restart with down/up (not just restart)
docker-compose down
docker-compose up -d
```

### Issue: Production still getting test notes

```bash
# Clean production
./scripts/clean-production-database.sh

# Add production safeguard (see PRODUCTION-CLEAN-SETUP.md)
```

---

## Daily Workflow

### Using Production (Normal Use)

Send notes from Drafts app → processes normally → goes to production DB and vault

### Testing Features

```bash
# Manually add test note to test database for now
sqlite3 data-test/selene-test.db <<EOF
INSERT INTO raw_notes (title, content, content_hash, created_at, test_run, source_type)
VALUES (
  'Feature Test',
  'Testing new feature',
  'test-' || datetime('now'),
  datetime('now'),
  'feature_v1',
  'manual_test'
);
EOF

# Or create test workflows to handle via webhooks
# (See full guide in TEST-ENVIRONMENT-STRATEGY.md)
```

---

## Summary

You've now set up the foundation for isolated test and production environments:

- ✓ Production database is clean
- ✓ Test database created and isolated
- ✓ Test vault created and isolated
- ✓ Docker configured for both environments
- ✓ Ready to create test workflows

**Next:** Choose your path:
- **Simple:** Continue using production workflows but segregate data by test_run field
- **Advanced:** Create full test workflow copies (see TEST-ENVIRONMENT-STRATEGY.md)

**Resources:**
- Full strategy: `docs/TEST-ENVIRONMENT-STRATEGY.md`
- Production setup: `docs/PRODUCTION-CLEAN-SETUP.md`
- Clean production: `./scripts/clean-production-database.sh`
- Verify clean: `./scripts/verify-production-clean.sh`

---

**Ready to develop features safely!** 🚀
