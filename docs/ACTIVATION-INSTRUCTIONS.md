# Test Workflow Activation Instructions

## Important: Test Workflows Need Manual Activation

The test workflows have been imported into n8n but are **deactivated by default**. You need to activate them manually via the n8n UI.

---

## Quick Activation Steps

### 1. Open n8n UI

```bash
open http://localhost:5678
```

Login credentials (from .env):
- Username: `admin`
- Password: `selene_n8n_2025`

### 2. Activate Test Workflows

You should see these test workflows (with "TEST" in the name):

- ✅ **Selene TEST: Note Ingestion**
- ✅ **Selene TEST: LLM Processing**
- ✅ **Selene TEST: Sentiment Analysis**
- ✅ **Selene TEST: Obsidian Export**

**To activate each workflow:**

1. Click on the workflow name
2. Look for the toggle switch in the top right (should be OFF/gray)
3. Click the toggle to turn it ON (will turn green/blue)
4. Repeat for all 4 test workflows

**Visual Guide:**
```
┌─────────────────────────────────────────┐
│  Selene TEST: Note Ingestion           │
│  Status: ○ Inactive  →  Click here!   │
└─────────────────────────────────────────┘
```

After activation:
```
┌─────────────────────────────────────────┐
│  Selene TEST: Note Ingestion           │
│  Status: ● Active  ✓                   │
└─────────────────────────────────────────┘
```

### 3. Verify Activation

After activating all 4 workflows, test the webhook:

```bash
curl http://localhost:5678/webhook/api/test/drafts
```

Expected response if active:
```
Workflow was started
```

If inactive:
```
The requested webhook is not registered
```

---

## Alternative: Activate via CLI (Advanced)

If you prefer command-line activation:

```bash
# Get workflow IDs
docker exec selene-n8n n8n list:workflow | grep "TEST"

# Activate by ID (replace XXX with actual ID)
# Note: This method requires knowing the workflow ID
```

However, **manual UI activation is recommended** as it's simpler and more reliable.

---

## After Activation: Test End-to-End

Once all test workflows are active:

```bash
# Submit a test note
./scripts/test-ingest.sh "first_test" "My First Test" "Testing the complete workflow"

# Wait 40-60 seconds for processing
sleep 60

# Verify results
./scripts/test-verify.sh "first_test"
```

---

## Troubleshooting

### Issue: Can't access n8n UI

**Solution:**
```bash
# Check if n8n is running
docker ps | grep selene-n8n

# Check logs
docker-compose logs n8n | tail -20

# Restart if needed
docker-compose restart n8n
```

### Issue: Workflows don't appear in UI

**Possible causes:**
1. Workflows not imported correctly
2. n8n database issue

**Solution:**
```bash
# Reimport workflows
docker exec selene-n8n n8n import:workflow --input=/workflows/workflows/01-ingestion/workflow-test.json
docker exec selene-n8n n8n import:workflow --input=/workflows/workflows/02-llm-processing/workflow-test.json
docker exec selene-n8n n8n import:workflow --input=/workflows/workflows/05-sentiment-analysis/workflow-test.json
docker exec selene-n8n n8n import:workflow --input=/workflows/workflows/04-obsidian-export/workflow-test.json

# Restart n8n
docker-compose restart n8n
```

### Issue: Webhook returns "not registered"

**Cause:** Workflow not activated

**Solution:** Follow activation steps above

### Issue: Multiple workflows with same name

**Cause:** Workflows imported multiple times

**Solution:**
1. Open n8n UI
2. Delete duplicate workflows (keep the active ones)
3. Or delete all and reimport cleanly

---

## Production Workflows

Your **production workflows** should still be active and working:

- ✅ **Selene: Note Ingestion** (active)
- ✅ **Selene: LLM Processing** (active)
- ✅ **Selene: Sentiment Analysis (Enhanced v2)** (active)
- ✅ **Selene: Obsidian Export (ADHD-Optimized) v2** (active)

**Do NOT deactivate production workflows!** They handle your real Drafts notes.

---

## Summary

**Before testing:**
1. Open http://localhost:5678
2. Activate all 4 TEST workflows
3. Verify webhooks respond

**After activation:**
```bash
./scripts/test-ingest.sh
```

Then proceed with testing! 🚀
