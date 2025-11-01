# Testing the Obsidian Export Workflow

**Time needed:** 15-20 minutes
**Difficulty:** Easy

## Prerequisites Check (5 minutes)

Run these commands to verify you're ready to test:

### 1. Check workflows are running

```bash
# Open n8n in browser
open http://localhost:5678

# Look for these workflows and verify they're ACTIVE (green toggle):
# - 01-ingestion ✅
# - 02-llm-processing ✅
# - 05-sentiment-analysis ✅
```

### 2. Check you have notes ready to export

```bash
sqlite3 data/selene.db "
SELECT COUNT(*) as ready_notes
FROM raw_notes rn
JOIN processed_notes pn ON rn.id = pn.raw_note_id
WHERE rn.exported_to_obsidian = 0
  AND rn.status = 'processed'
  AND pn.sentiment_analyzed = 1;
"
```

**Expected:** Number > 0 (like "3" or "5")

**If you see "0":**
- Workflows 01, 02, 05 need to process some notes first
- Wait a few minutes, then check again
- Or create a test note (see "Create Test Note" below)

### 3. Check vault directory exists

```bash
ls -la vault/
```

**Expected:** You should see a `Selene/` folder

**If missing:**
```bash
mkdir -p vault/Selene/{Timeline,By-Concept,By-Theme,By-Energy/{high,medium,low},Concepts,Themes}
```

---

## Test 1: Import Workflow to n8n (5 minutes)

### Step 1: Open n8n

```bash
open http://localhost:5678
```

### Step 2: Import the workflow

1. Click **"Workflows"** in left sidebar
2. Click **"Add Workflow"** button (top right)
3. Click **"Import from File"**
4. Navigate to and select: `workflows/04-obsidian-export/workflow.json`
5. Click **"Import"**

**Expected:** Workflow opens in editor, you see multiple nodes connected

### Step 3: Configure SQLite credentials

n8n will show **red error badges** on the SQLite nodes saying "No credentials"

1. Click on **"Get Notes for Export"** node
2. Under "Credential to connect with", click **"+ Create New"**
3. Enter:
   - **Name:** `Selene SQLite`
   - **Database Path:** `/selene/data/selene.db`
4. Click **"Save"**
5. Click back to close the node panel

**Expected:** The "Get Notes for Export" node error is gone

6. Click on **"Mark as Exported"** node
7. Under "Credential to connect with", select **"Selene SQLite"** (from dropdown)
8. Click back to close the node panel

**Expected:** Both SQLite nodes now have green checkmarks

### Step 4: Save and activate

1. Click **"Save"** button (top right)
2. Give it a name (or keep default): **"Selene: Obsidian Export (ADHD-Optimized)"**
3. Toggle **"Active"** switch to ON (should turn green)
4. Click **"Save"** again

**Expected:** Workflow is saved and active (green indicator)

---

## Test 2: Manual Execution (5 minutes)

### Step 1: Execute manually

Still in the workflow editor:

1. Click **"Execute Workflow"** button (top right, play icon)
2. Wait for execution to complete (watch the nodes light up)
3. Check for errors

**Expected:**
- Nodes turn green as they execute
- You see "Successfully executed workflow" message
- No red error nodes

**If you see errors:**
- Click on the red node to see error details
- Most common: "No credentials" → Go back to Test 1, Step 3
- Other errors: See Troubleshooting section below

### Step 2: Check the execution data

1. Click the **last node** ("Respond to Webhook")
2. Look at the output data in the right panel

**Expected:** You should see data flowing through each node

### Step 3: Verify files were created

```bash
# Check if notes were exported
ls -la vault/Selene/By-Concept/

# Should see folders for each concept
# Example output:
# Docker/
# ADHD/
# Python/
# etc.

# Check a specific note
find vault/Selene -name "*.md" -type f | head -1
```

**Expected:** You see `.md` files

**View a note:**
```bash
# View the first note found
find vault/Selene -name "*.md" -type f | head -1 | xargs cat
```

**Expected:** You should see:
- Frontmatter with YAML metadata
- Status at a glance table with emoji
- Quick Context box
- Action items section (if any)
- Full content
- ADHD Insights section

---

## Test 3: Webhook Trigger (5 minutes)

### Step 1: Get webhook URL

In n8n workflow editor:

1. Click on **"On-Demand Export Webhook"** node
2. Look for **"Test URL"** or **"Production URL"**
3. Copy the URL

**It should look like:**
```
http://localhost:5678/webhook/obsidian-export
```

### Step 2: Trigger the webhook

```bash
curl -X POST http://localhost:5678/webhook/obsidian-export
```

**Expected response:**
```json
{
  "success": true,
  "message": "Export triggered successfully",
  "timestamp": "2025-10-30T..."
}
```

**If you see "404":**
- Workflow isn't active → Go activate it
- Wrong URL → Check the webhook node for correct path

### Step 3: Check execution happened

In n8n:

1. Click **"Executions"** in left sidebar
2. Look for recent execution (just now)
3. Click on it to see details

**Expected:** Execution succeeded (green checkmark)

### Step 4: Verify more files created

```bash
# Count markdown files
find vault/Selene -name "*.md" -type f | wc -l

# Should be more than before the webhook trigger
```

---

## Test 4: Verify ADHD Features (5 minutes)

### Check a specific note has all features

```bash
# Find and open a note
NOTE=$(find vault/Selene -name "*.md" -type f | head -1)
cat "$NOTE"
```

### Checklist - Your note should have:

- [ ] **Frontmatter** (YAML at top with ---)
  - [ ] `energy:` field (high/medium/low)
  - [ ] `mood:` field (excited/calm/anxious/etc)
  - [ ] `sentiment:` field (positive/negative/neutral)
  - [ ] `adhd_markers:` section
  - [ ] `concepts:` list
  - [ ] `tags:` list

- [ ] **Status table** with emoji:
  - [ ] Energy indicator (⚡🔋🪫)
  - [ ] Mood emoji (🚀😌😰 etc)
  - [ ] Sentiment badge (✅⚠️⚪)
  - [ ] ADHD markers (🧠🎯⚠️ or ✨ BASELINE)

- [ ] **Quick Context box** (starts with `>`)
  - [ ] TL;DR summary
  - [ ] "Why this matters"
  - [ ] Reading time
  - [ ] Brain state

- [ ] **Action Items** section (if note had TODOs)
  - [ ] Checkbox format: `- [ ]`

- [ ] **Full Content** section
  - [ ] Your original note text

- [ ] **ADHD Insights** section
  - [ ] Brain State Analysis
  - [ ] Energy level interpretation
  - [ ] Emotional tone
  - [ ] Context Clues

### Check multiple organization paths

```bash
# Same note should be in 4 places
# Replace "test-note" with your actual note filename

NOTE_NAME="2025-10-30-your-note-title.md"

# Check all 4 locations
ls vault/Selene/Timeline/2025/10/$NOTE_NAME
ls vault/Selene/By-Concept/*/$ NOTE_NAME
ls vault/Selene/By-Theme/*/$NOTE_NAME
ls vault/Selene/By-Energy/*/$NOTE_NAME

# All 4 should exist
```

### Check concept hub pages

```bash
ls vault/Selene/Concepts/

# Should see concept hub pages like:
# Docker.md
# ADHD.md
# Python.md
# etc.

# View one:
cat vault/Selene/Concepts/Docker.md
```

**Expected:** Hub page with backlinks placeholder

---

## Test 5: Database Updated (2 minutes)

### Verify notes were marked as exported

```bash
sqlite3 data/selene.db "
SELECT
  id,
  title,
  exported_to_obsidian,
  exported_at
FROM raw_notes
WHERE exported_to_obsidian = 1
ORDER BY exported_at DESC
LIMIT 5;
"
```

**Expected:** You see your exported notes with timestamps

---

## Test 6: Automatic Hourly Run (Optional)

If you want to test the hourly cron trigger:

### Option A: Wait an hour

- Workflow will auto-run at top of next hour
- Check executions tab to verify

### Option B: Change cron to run sooner

1. Edit workflow
2. Click "Every Hour" node
3. Change cron to: `*/5 * * * *` (every 5 minutes)
4. Save
5. Wait 5 minutes
6. Check Executions tab

**Remember to change it back to hourly later!**

---

## Troubleshooting

### ❌ "No credentials found"

**Problem:** SQLite nodes show red error

**Fix:**
```bash
# In n8n workflow editor:
1. Click the red SQLite node
2. Credential section → "Create New"
3. Database Path: /selene/data/selene.db
4. Save
5. Apply to both SQLite nodes
```

### ❌ "No notes to export"

**Problem:** Query returns 0 results

**Fix:**
```bash
# Check if notes exist and are ready
sqlite3 data/selene.db "
SELECT
  rn.status,
  pn.sentiment_analyzed,
  rn.exported_to_obsidian,
  COUNT(*) as count
FROM raw_notes rn
JOIN processed_notes pn ON rn.id = pn.raw_note_id
GROUP BY rn.status, pn.sentiment_analyzed, rn.exported_to_obsidian;
"

# If sentiment_analyzed = 0:
# → Activate workflow 05 (sentiment analysis)
# → Wait 45 seconds for it to run

# If status = 'pending':
# → Activate workflow 02 (LLM processing)
# → Wait 30 seconds for it to run
```

### ❌ "Permission denied" writing files

**Problem:** Can't write to vault directory

**Fix:**
```bash
# Give write permissions
chmod -R 755 vault/

# Verify
ls -la vault/
```

### ❌ "Webhook 404 Not Found"

**Problem:** Webhook URL doesn't work

**Fix:**
1. Workflow must be **Active** (green toggle in n8n)
2. Check webhook URL in the webhook node
3. Copy exact URL shown
4. Restart n8n if needed: `docker-compose restart n8n`

### ❌ No ADHD markers showing

**Problem:** Notes exported but missing ADHD features

**Likely cause:** Workflow 05 (sentiment analysis) didn't run

**Fix:**
```bash
# Check if sentiment data exists
sqlite3 data/selene.db "
SELECT
  id,
  sentiment_analyzed,
  overall_sentiment,
  emotional_tone,
  energy_level
FROM processed_notes
LIMIT 5;
"

# If sentiment_analyzed = 0:
# 1. Activate workflow 05
# 2. Wait 45 seconds
# 3. Re-export notes:

sqlite3 data/selene.db "
UPDATE raw_notes
SET exported_to_obsidian = 0
WHERE id IN (SELECT id FROM raw_notes LIMIT 5);
"

# 4. Trigger export again
curl -X POST http://localhost:5678/webhook/obsidian-export
```

### ❌ Files not in multiple folders

**Problem:** Note only in one folder, not all 4

**Fix:**
```bash
# Check execution logs in n8n for errors
# Usually means directory creation failed

# Manually create structure:
mkdir -p vault/Selene/{Timeline,By-Concept,By-Theme,By-Energy/{high,medium,low},Concepts}

# Try export again
curl -X POST http://localhost:5678/webhook/obsidian-export
```

---

## Create a Test Note (If Needed)

If you don't have any notes ready, create one:

```bash
# 1. Send a test note to ingestion webhook
curl -X POST http://localhost:5678/webhook/api/drafts \
  -H "Content-Type: application/json" \
  -d '{
    "query": {
      "title": "Test Note for Obsidian Export",
      "content": "This is a test note about Docker and ADHD productivity. I need to set up my development environment and organize my tasks better. TODO: Install Docker, TODO: Create workflow documentation, TODO: Test the export feature.",
      "timestamp": "'$(date -u +"%Y-%m-%dT%H:%M:%SZ")'"
    }
  }'

# 2. Wait 30 seconds for workflow 02 to process it

# 3. Wait 45 seconds for workflow 05 to add sentiment data

# 4. Now you have a note ready to export!
```

---

## Success Criteria

You've successfully tested the workflow if:

✅ Workflow imports without errors
✅ SQLite credentials configured
✅ Manual execution succeeds
✅ Webhook trigger works
✅ Files created in vault/
✅ Notes have ADHD features (emoji, status table, insights)
✅ Notes in 4 different folders (Timeline, By-Concept, By-Theme, By-Energy)
✅ Concept hub pages created
✅ Database shows exported_to_obsidian = 1
✅ No errors in n8n Executions tab

---

## Quick Test Summary

**Fastest test path (10 minutes):**

```bash
# 1. Prerequisites (2 min)
sqlite3 data/selene.db "SELECT COUNT(*) FROM raw_notes WHERE status='processed'" # > 0?
mkdir -p vault/Selene/{Timeline,By-Concept,By-Theme,By-Energy/{high,medium,low},Concepts}

# 2. Import (3 min)
# - Open http://localhost:5678
# - Import workflow.json
# - Configure SQLite credential: /selene/data/selene.db
# - Save & Activate

# 3. Test (2 min)
curl -X POST http://localhost:5678/webhook/obsidian-export

# 4. Verify (3 min)
ls -la vault/Selene/By-Concept/
find vault/Selene -name "*.md" | head -1 | xargs cat | head -50

# ✅ If you see markdown with emoji and status tables, it worked!
```

---

## Next Steps After Testing

Once testing is complete:

1. **Keep workflow active** for hourly auto-export
2. **Open vault in Obsidian** to see the results
3. **Install Dataview plugin** for powerful queries
4. **Create shortcuts** for on-demand export (Alfred, iOS, etc)
5. **Read the full guide:** [docs/OBSIDIAN-EXPORT-GUIDE.md](docs/OBSIDIAN-EXPORT-GUIDE.md)

---

**Need help?** See [docs/OBSIDIAN-EXPORT-SETUP.md](docs/OBSIDIAN-EXPORT-SETUP.md) for detailed troubleshooting.
