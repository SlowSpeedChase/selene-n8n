# ADHD-Optimized Obsidian Export - Setup Guide

**Time to complete:** 10 minutes
**Skill level:** Beginner-friendly

## Prerequisites Check

Before starting, verify you have:

```bash
# 1. Check n8n is running
curl http://localhost:5678/healthz
# Expected: HTTP 200 OK

# 2. Check workflows 01, 02, 05 are active
# Open http://localhost:5678 and verify:
# - 01-ingestion: Active ✅
# - 02-llm-processing: Active ✅
# - 05-sentiment-analysis: Active ✅

# 3. Check you have processed notes with sentiment data
sqlite3 data/selene.db "
SELECT COUNT(*) as ready_to_export
FROM raw_notes rn
JOIN processed_notes pn ON rn.id = pn.raw_note_id
WHERE rn.exported_to_obsidian = 0
  AND rn.status = 'processed'
  AND pn.sentiment_analyzed = 1;
"
# Expected: Number > 0
```

If any checks fail, see **Troubleshooting** section below.

## Step-by-Step Setup

### Step 1: Configure Vault Path (Optional)

You can set the vault path in two ways:

**Option A: Environment Variable (Recommended)**

Add to your `.env` file:
```bash
OBSIDIAN_VAULT_PATH=/Users/yourusername/Documents/ObsidianVault
```

Then restart n8n:
```bash
docker-compose restart n8n
```

**Option B: Edit Workflow Directly**

Edit line in the workflow function:
```javascript
const vaultPath = '/Users/yourusername/Documents/ObsidianVault';
```

**Default if not set:** `./vault` (creates vault in project directory)

### Step 2: Create Vault Structure

```bash
# Set your vault path (or use default)
VAULT_PATH="${OBSIDIAN_VAULT_PATH:-./vault}"

# Create directory structure
mkdir -p "${VAULT_PATH}/Selene/Timeline"
mkdir -p "${VAULT_PATH}/Selene/By-Concept"
mkdir -p "${VAULT_PATH}/Selene/By-Theme"
mkdir -p "${VAULT_PATH}/Selene/By-Energy/high"
mkdir -p "${VAULT_PATH}/Selene/By-Energy/medium"
mkdir -p "${VAULT_PATH}/Selene/By-Energy/low"
mkdir -p "${VAULT_PATH}/Selene/Concepts"
mkdir -p "${VAULT_PATH}/Selene/Themes"

# Verify structure
tree -L 3 "${VAULT_PATH}/Selene" 2>/dev/null || ls -R "${VAULT_PATH}/Selene"
```

Expected structure:
```
Selene/
├── Timeline/
├── By-Concept/
├── By-Theme/
├── By-Energy/
│   ├── high/
│   ├── medium/
│   └── low/
├── Concepts/
└── Themes/
```

### Step 3: Import Workflow to n8n

1. **Open n8n:** http://localhost:5678

2. **Import workflow:**
   - Click **Workflows** (left sidebar)
   - Click **Add Workflow** → **Import from File**
   - Select: `workflows/04-obsidian-export/workflow-adhd-optimized.json`
   - Click **Import**

3. **Configure credentials:**
   - Open any SQLite node (e.g., "Get Notes for Export")
   - Credential: Should auto-select "Selene SQLite"
   - If not available, create:
     - Name: `Selene SQLite`
     - Database Path: `/selene/data/selene.db`
   - Click **Save**

4. **Verify webhook URL:**
   - Open the "On-Demand Export Webhook" node
   - Note the webhook URL (e.g., `http://localhost:5678/webhook/obsidian-export`)
   - Copy this for later use

### Step 4: Test Export

**Test 1: Manual Trigger (Recommended First)**

In n8n workflow editor:
1. Click the "On-Demand Export Webhook" node
2. Click **"Execute Workflow"** button (top right)
3. Click **"Execute Node"**
4. Check execution log for success

**Test 2: Webhook Trigger**

```bash
curl -X POST http://localhost:5678/webhook/obsidian-export

# Expected response:
# {
#   "success": true,
#   "message": "Export triggered successfully",
#   "timestamp": "2025-10-30T..."
# }
```

**Test 3: Verify Files Created**

```bash
# Check files were created
ls -la "${VAULT_PATH}/Selene/By-Concept/"

# Should see folders for each concept with notes inside
# Example:
# Docker/
# ADHD/
# Python/
# etc.

# Check multiple organization paths
ls -la "${VAULT_PATH}/Selene/By-Energy/high/"
ls -la "${VAULT_PATH}/Selene/Timeline/2025/"
```

**Test 4: Inspect a Note**

```bash
# Find and read a note
find "${VAULT_PATH}/Selene" -name "*.md" -type f | head -1 | xargs cat

# Should see:
# - Frontmatter with ADHD metadata
# - Status at a glance table
# - Emoji indicators
# - Action items section (if any)
# - ADHD insights section
```

### Step 5: Activate Workflow

1. In n8n workflow editor
2. Click the **"Active"** toggle (top right)
3. Should turn green: ✅ Active
4. Click **"Save"** (top right)

Your workflow is now running!

## Verification Checklist

After setup, verify everything works:

- [ ] Workflow shows as "Active" in n8n
- [ ] Vault directory structure exists
- [ ] Test export succeeded (webhook curl command)
- [ ] Files appear in multiple folders (By-Concept, By-Energy, etc.)
- [ ] Notes have ADHD-optimized format (emoji, status table, etc.)
- [ ] Concept hub pages created in `Concepts/` folder
- [ ] Database updated (exported_to_obsidian = 1)

Check database:
```bash
sqlite3 data/selene.db "
SELECT
  rn.title,
  rn.exported_to_obsidian,
  rn.exported_at
FROM raw_notes rn
ORDER BY rn.exported_at DESC
LIMIT 5;
"

# Should show recently exported notes
```

## Usage After Setup

### Automatic Export (Hourly)

The workflow runs **every hour on the hour**.

Check next run time:
- Open workflow in n8n
- Click "Executions" tab
- See past runs and upcoming schedule

### On-Demand Export (Immediate)

Trigger export any time:

```bash
curl -X POST http://localhost:5678/webhook/obsidian-export
```

**Create shortcuts for easy access:**

**macOS Alfred Workflow:**
1. Create new workflow
2. Keyword trigger: "export notes"
3. Action: Run script:
   ```bash
   curl -X POST http://localhost:5678/webhook/obsidian-export
   ```

**iOS Shortcut:**
1. New Shortcut → Add Action
2. "Get contents of URL"
3. URL: `http://your-ip:5678/webhook/obsidian-export`
4. Method: POST
5. Name: "Export Selene Notes"

**Drafts Action:**
1. New Action → Script
2. Script:
   ```javascript
   let http = HTTP.create();
   let response = http.request({
     "url": "http://localhost:5678/webhook/obsidian-export",
     "method": "POST"
   });
   ```

### Finding Your Notes

**Primary method: By Concept**
```
Browse: vault/Selene/By-Concept/[concept-name]/
```

**Match energy level:**
```
Browse: vault/Selene/By-Energy/[high|medium|low]/
```

**Browse by theme:**
```
Browse: vault/Selene/By-Theme/[theme-name]/
```

**Chronological backup:**
```
Browse: vault/Selene/Timeline/[year]/[month]/
```

**See all notes for a concept:**
```
Open: vault/Selene/Concepts/[concept-name].md
Check backlinks section
```

## Troubleshooting

### Problem: "No notes ready to export"

**Cause:** Notes haven't been processed yet or missing sentiment analysis.

**Fix:**
```bash
# Check processing pipeline
sqlite3 data/selene.db "
SELECT
  COUNT(*) FILTER (WHERE status = 'pending') as pending,
  COUNT(*) FILTER (WHERE status = 'processed') as processed,
  COUNT(*) FILTER (WHERE status = 'processed' AND exported_to_obsidian = 0) as ready_to_export
FROM raw_notes;
"

# If pending > 0: Wait for workflow 02 to process
# If processed but not exported: Check sentiment analysis

# Check sentiment analysis status
sqlite3 data/selene.db "
SELECT
  COUNT(*) FILTER (WHERE sentiment_analyzed = 0) as pending_sentiment,
  COUNT(*) FILTER (WHERE sentiment_analyzed = 1) as sentiment_complete
FROM processed_notes;
"

# If pending_sentiment > 0: Wait for workflow 05 (runs every 45 sec)
```

### Problem: "Workflow not activated" error

**Cause:** Workflow isn't active or credentials missing.

**Fix:**
1. Open workflow in n8n
2. Check "Active" toggle is ON (green)
3. Check SQLite credential is configured
4. Click "Save"

### Problem: "Permission denied" when writing files

**Cause:** n8n doesn't have write permission to vault path.

**Fix:**
```bash
# Check vault path permissions
ls -la "${OBSIDIAN_VAULT_PATH}"

# Give write permission (adjust path as needed)
chmod -R 755 "${OBSIDIAN_VAULT_PATH}/Selene"

# If using Docker, ensure volume is mounted
docker-compose exec n8n ls -la /vault
```

### Problem: "Notes not appearing in multiple folders"

**Cause:** Directory creation failed or workflow error.

**Fix:**
```bash
# Check n8n execution logs
docker-compose logs n8n | grep -i error

# Manually create directory structure
VAULT_PATH="${OBSIDIAN_VAULT_PATH:-./vault}"
mkdir -p "${VAULT_PATH}/Selene"/{Timeline,By-Concept,By-Theme,By-Energy/{high,medium,low},Concepts}

# Re-run export
curl -X POST http://localhost:5678/webhook/obsidian-export
```

### Problem: "Webhook returns 404"

**Cause:** Workflow not active or webhook node not configured.

**Fix:**
1. Activate workflow in n8n
2. Check webhook node settings:
   - Path: `obsidian-export`
   - Method: POST
   - Mode: Production
3. Get correct URL from webhook node
4. Restart n8n if needed:
   ```bash
   docker-compose restart n8n
   ```

### Problem: "Missing ADHD markers in notes"

**Cause:** Sentiment analysis didn't run or data not available.

**Fix:**
```bash
# Verify sentiment data exists
sqlite3 data/selene.db "
SELECT
  id,
  sentiment_data IS NOT NULL as has_data,
  overall_sentiment,
  energy_level
FROM processed_notes
LIMIT 5;
"

# If has_data = 0: Sentiment analysis hasn't run
# Activate workflow 05 and wait 45 seconds

# If has_data = 1 but still missing in export:
# - Check export workflow is using latest version
# - Re-import workflow-adhd-optimized.json
```

### Problem: "Notes exported but look plain (no ADHD features)"

**Cause:** Wrong workflow is running (standard instead of ADHD-optimized).

**Fix:**
1. Check which workflow is active:
   - Standard: "Selene: Obsidian Export"
   - ADHD: "Selene: Obsidian Export (ADHD-Optimized)"
2. Deactivate standard, activate ADHD-optimized
3. Re-export test note:
   ```bash
   # Reset one note for re-export
   sqlite3 data/selene.db "
   UPDATE raw_notes
   SET exported_to_obsidian = 0
   WHERE id = (SELECT id FROM raw_notes ORDER BY created_at DESC LIMIT 1);
   "

   # Trigger export
   curl -X POST http://localhost:5678/webhook/obsidian-export
   ```

## Performance Notes

### Resource Usage

**CPU:**
- Very low (runs hourly)
- ~2-5 seconds per note processed
- 50 notes takes ~2-3 minutes

**Memory:**
- Negligible (< 50MB per execution)

**Storage:**
- ~50KB per note × 4 locations = ~200KB per note
- 100 notes = ~20MB
- 1000 notes = ~200MB

### Optimization Tips

**If you have thousands of notes:**

1. **Batch export in groups:**
   ```sql
   -- Export 50 at a time
   UPDATE raw_notes
   SET exported_to_obsidian = 0
   WHERE id IN (
     SELECT id FROM raw_notes
     WHERE exported_to_obsidian = 1
     LIMIT 50
   );
   ```

2. **Increase cron interval:**
   - Change from `0 * * * *` (hourly)
   - To `0 */3 * * *` (every 3 hours)

3. **Reduce duplication:**
   - Use symlinks instead of copies
   - Edit workflow to create links instead of full copies

## Next Steps

After successful setup:

1. **Install Obsidian Dataview plugin** for querying
2. **Create a dashboard** (see README-ADHD.md)
3. **Set up daily note template** with Selene integration
4. **Create shortcuts** for on-demand export (Alfred, iOS, etc.)
5. **Review COMPARISON.md** to understand all features

## Additional Resources

- **Full feature documentation:** README-ADHD.md
- **Standard vs ADHD comparison:** COMPARISON.md
- **Example queries:** See "Tracking Your Patterns" in README-ADHD.md
- **Obsidian Dataview docs:** https://blacksmithgu.github.io/obsidian-dataview/

## Support

If you encounter issues not covered here:

1. Check n8n execution logs:
   ```bash
   docker-compose logs n8n | tail -100
   ```

2. Check database state:
   ```bash
   sqlite3 data/selene.db "
   SELECT * FROM raw_notes ORDER BY created_at DESC LIMIT 1;
   "
   ```

3. Test workflow step by step:
   - Open in n8n editor
   - Click "Execute Workflow"
   - Check each node's output

4. Review full documentation in README-ADHD.md

---

**Setup complete! Your notes are now ADHD-optimized. 🚀**
