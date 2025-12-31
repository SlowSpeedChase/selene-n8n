# Daily Executive Summary Implementation Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** Create an n8n workflow that generates a daily executive summary at midnight, combining recent note activity with emerging patterns, and saves it to Obsidian.

**Architecture:** Schedule-triggered workflow that queries SQLite for today's notes, processed insights, and patterns, builds a context prompt, sends to Ollama for summarization, and writes markdown to the Obsidian vault.

**Tech Stack:** n8n Schedule Trigger, better-sqlite3, Ollama HTTP API, Node.js fs for file writing

---

## Task 1: Create Directory Structure

**Files:**
- Create: `workflows/08-daily-summary/`
- Create: `workflows/08-daily-summary/docs/`
- Create: `workflows/08-daily-summary/scripts/`

**Step 1: Create workflow directories**

```bash
mkdir -p workflows/08-daily-summary/docs
mkdir -p workflows/08-daily-summary/scripts
```

**Step 2: Verify structure**

Run: `ls -la workflows/08-daily-summary/`
Expected: `docs/` and `scripts/` directories exist

**Step 3: Commit**

```bash
git add workflows/08-daily-summary
git commit -m "chore: create workflow 08-daily-summary directory structure"
```

---

## Task 2: Create Workflow JSON - Schedule Trigger Node

**Files:**
- Create: `workflows/08-daily-summary/workflow.json`

**Step 1: Create workflow.json with Schedule Trigger**

Create file `workflows/08-daily-summary/workflow.json`:

```json
{
  "name": "08-Daily-Summary | Selene",
  "active": false,
  "nodes": [
    {
      "parameters": {
        "rule": {
          "interval": [
            {
              "field": "cronExpression",
              "expression": "0 0 * * *"
            }
          ]
        }
      },
      "id": "schedule-trigger",
      "name": "Schedule: Midnight Daily",
      "type": "n8n-nodes-base.scheduleTrigger",
      "typeVersion": 1.2,
      "position": [250, 300]
    }
  ],
  "connections": {},
  "settings": {
    "executionOrder": "v1"
  }
}
```

**Step 2: Verify JSON is valid**

Run: `python3 -c "import json; json.load(open('workflows/08-daily-summary/workflow.json'))"`
Expected: No output (valid JSON)

**Step 3: Commit**

```bash
git add workflows/08-daily-summary/workflow.json
git commit -m "feat(08): add schedule trigger node (midnight cron)"
```

---

## Task 3: Add Query Today's Notes Node

**Files:**
- Modify: `workflows/08-daily-summary/workflow.json`

**Step 1: Add Function node for querying today's notes**

Add to the `nodes` array in workflow.json:

```json
{
  "parameters": {
    "functionCode": "const Database = require('better-sqlite3');\nlet db;\n\ntry {\n  db = new Database('/selene/data/selene.db', { readonly: true });\n  \n  // Get notes captured in the last 24 hours\n  const query = `\n    SELECT id, title, tags, word_count, created_at\n    FROM raw_notes\n    WHERE date(created_at) >= date('now', '-1 day')\n    AND test_run IS NULL\n    ORDER BY created_at DESC\n  `;\n  \n  const notes = db.prepare(query).all();\n  \n  db.close();\n  \n  return {\n    json: {\n      notes: notes,\n      count: notes.length,\n      queryDate: new Date().toISOString().split('T')[0]\n    }\n  };\n  \n} catch (error) {\n  if (db) db.close();\n  console.error('Query notes error:', error);\n  return {\n    json: {\n      notes: [],\n      count: 0,\n      error: error.message,\n      queryDate: new Date().toISOString().split('T')[0]\n    }\n  };\n}"
  },
  "id": "query-notes",
  "name": "Query Today's Notes",
  "type": "n8n-nodes-base.function",
  "typeVersion": 1,
  "position": [450, 300]
}
```

**Step 2: Add connection from trigger to query**

Update the `connections` object:

```json
"connections": {
  "Schedule: Midnight Daily": {
    "main": [[{ "node": "Query Today's Notes", "type": "main", "index": 0 }]]
  }
}
```

**Step 3: Verify JSON is valid**

Run: `python3 -c "import json; json.load(open('workflows/08-daily-summary/workflow.json'))"`
Expected: No output (valid JSON)

**Step 4: Commit**

```bash
git add workflows/08-daily-summary/workflow.json
git commit -m "feat(08): add query today's notes node"
```

---

## Task 4: Add Query Processed Insights Node

**Files:**
- Modify: `workflows/08-daily-summary/workflow.json`

**Step 1: Add Function node for querying processed insights**

Add to the `nodes` array:

```json
{
  "parameters": {
    "functionCode": "const Database = require('better-sqlite3');\nlet db;\n\ntry {\n  db = new Database('/selene/data/selene.db', { readonly: true });\n  \n  // Get processed insights from the last 24 hours\n  const query = `\n    SELECT \n      p.id,\n      p.concepts,\n      p.primary_theme,\n      p.secondary_themes,\n      r.title\n    FROM processed_notes p\n    JOIN raw_notes r ON p.raw_note_id = r.id\n    WHERE date(p.processed_at) >= date('now', '-1 day')\n    AND r.test_run IS NULL\n    ORDER BY p.processed_at DESC\n  `;\n  \n  const insights = db.prepare(query).all();\n  \n  db.close();\n  \n  // Parse JSON fields\n  const parsedInsights = insights.map(i => ({\n    ...i,\n    concepts: i.concepts ? JSON.parse(i.concepts) : [],\n    secondary_themes: i.secondary_themes ? JSON.parse(i.secondary_themes) : []\n  }));\n  \n  return {\n    json: {\n      insights: parsedInsights,\n      count: parsedInsights.length\n    }\n  };\n  \n} catch (error) {\n  if (db) db.close();\n  console.error('Query insights error:', error);\n  return {\n    json: {\n      insights: [],\n      count: 0,\n      error: error.message\n    }\n  };\n}"
  },
  "id": "query-insights",
  "name": "Query Processed Insights",
  "type": "n8n-nodes-base.function",
  "typeVersion": 1,
  "position": [450, 450]
}
```

**Step 2: Add parallel connection from trigger**

Update `connections`:

```json
"connections": {
  "Schedule: Midnight Daily": {
    "main": [[
      { "node": "Query Today's Notes", "type": "main", "index": 0 },
      { "node": "Query Processed Insights", "type": "main", "index": 0 }
    ]]
  }
}
```

**Step 3: Commit**

```bash
git add workflows/08-daily-summary/workflow.json
git commit -m "feat(08): add query processed insights node"
```

---

## Task 5: Add Query Patterns Node

**Files:**
- Modify: `workflows/08-daily-summary/workflow.json`

**Step 1: Add Function node for querying patterns**

Add to the `nodes` array:

```json
{
  "parameters": {
    "functionCode": "const Database = require('better-sqlite3');\nlet db;\n\ntry {\n  db = new Database('/selene/data/selene.db', { readonly: true });\n  \n  // Get recent active patterns\n  const query = `\n    SELECT \n      pattern_type,\n      pattern_name,\n      description,\n      confidence,\n      discovered_at\n    FROM detected_patterns\n    WHERE is_active = 1\n    ORDER BY discovered_at DESC\n    LIMIT 5\n  `;\n  \n  const patterns = db.prepare(query).all();\n  \n  db.close();\n  \n  return {\n    json: {\n      patterns: patterns,\n      count: patterns.length\n    }\n  };\n  \n} catch (error) {\n  if (db) db.close();\n  console.error('Query patterns error:', error);\n  return {\n    json: {\n      patterns: [],\n      count: 0,\n      error: error.message\n    }\n  };\n}"
  },
  "id": "query-patterns",
  "name": "Query Active Patterns",
  "type": "n8n-nodes-base.function",
  "typeVersion": 1,
  "position": [450, 600]
}
```

**Step 2: Add parallel connection from trigger**

Update `connections` to include all three parallel nodes:

```json
"connections": {
  "Schedule: Midnight Daily": {
    "main": [[
      { "node": "Query Today's Notes", "type": "main", "index": 0 },
      { "node": "Query Processed Insights", "type": "main", "index": 0 },
      { "node": "Query Active Patterns", "type": "main", "index": 0 }
    ]]
  }
}
```

**Step 3: Commit**

```bash
git add workflows/08-daily-summary/workflow.json
git commit -m "feat(08): add query active patterns node"
```

---

## Task 6: Add Merge Node

**Files:**
- Modify: `workflows/08-daily-summary/workflow.json`

**Step 1: Add Merge node to combine all query results**

Add to the `nodes` array:

```json
{
  "parameters": {
    "mode": "combine",
    "combinationMode": "mergeByPosition",
    "options": {}
  },
  "id": "merge-data",
  "name": "Merge Query Results",
  "type": "n8n-nodes-base.merge",
  "typeVersion": 3,
  "position": [700, 450]
}
```

**Step 2: Update connections - connect queries to merge**

```json
"connections": {
  "Schedule: Midnight Daily": {
    "main": [[
      { "node": "Query Today's Notes", "type": "main", "index": 0 },
      { "node": "Query Processed Insights", "type": "main", "index": 0 },
      { "node": "Query Active Patterns", "type": "main", "index": 0 }
    ]]
  },
  "Query Today's Notes": {
    "main": [[{ "node": "Merge Query Results", "type": "main", "index": 0 }]]
  },
  "Query Processed Insights": {
    "main": [[{ "node": "Merge Query Results", "type": "main", "index": 1 }]]
  },
  "Query Active Patterns": {
    "main": [[{ "node": "Merge Query Results", "type": "main", "index": 2 }]]
  }
}
```

**Step 3: Commit**

```bash
git add workflows/08-daily-summary/workflow.json
git commit -m "feat(08): add merge node to combine query results"
```

---

## Task 7: Add Build Prompt Node

**Files:**
- Modify: `workflows/08-daily-summary/workflow.json`

**Step 1: Add Function node to build the Ollama prompt**

Add to the `nodes` array:

```json
{
  "parameters": {
    "functionCode": "// Get data from all three query nodes\nconst items = $input.all();\n\n// Extract data from merged items\nconst notesData = items[0]?.json || { notes: [], count: 0 };\nconst insightsData = items[1]?.json || { insights: [], count: 0 };\nconst patternsData = items[2]?.json || { patterns: [], count: 0 };\n\n// Format today's date\nconst today = new Date();\nconst dateStr = today.toLocaleDateString('en-US', { \n  weekday: 'long', \n  year: 'numeric', \n  month: 'long', \n  day: 'numeric' \n});\n\n// Build notes section\nlet notesSection = '';\nif (notesData.count === 0) {\n  notesSection = 'No new notes captured today.';\n} else {\n  notesSection = notesData.notes.map(n => {\n    const tags = n.tags ? JSON.parse(n.tags).join(', ') : 'no tags';\n    return `- \"${n.title}\" (${n.word_count} words, tags: ${tags})`;\n  }).join('\\n');\n}\n\n// Build insights section\nlet insightsSection = '';\nif (insightsData.count === 0) {\n  insightsSection = 'No notes processed today.';\n} else {\n  const allConcepts = insightsData.insights.flatMap(i => i.concepts || []);\n  const allThemes = insightsData.insights.map(i => i.primary_theme).filter(Boolean);\n  const uniqueConcepts = [...new Set(allConcepts)].slice(0, 10);\n  const uniqueThemes = [...new Set(allThemes)];\n  insightsSection = `Concepts: ${uniqueConcepts.join(', ') || 'none'}\\nThemes: ${uniqueThemes.join(', ') || 'none'}`;\n}\n\n// Build patterns section\nlet patternsSection = '';\nif (patternsData.count === 0) {\n  patternsSection = 'No active patterns detected yet.';\n} else {\n  patternsSection = patternsData.patterns.map(p => \n    `- ${p.pattern_name}: ${p.description || 'No description'}`\n  ).join('\\n');\n}\n\n// Build the prompt\nconst prompt = `You are summarizing a personal knowledge capture system for someone with ADHD.\nBe brief and clear. Write 2-4 sentences max.\n\nToday's date: ${dateStr}\n\nNotes captured today (${notesData.count}):\n${notesSection}\n\nInsights extracted:\n${insightsSection}\n\nRecurring themes:\n${patternsSection}\n\nWrite a brief executive summary paragraph covering:\n- What was captured today (or note if quiet day)\n- Any notable insights or themes emerging`;\n\nreturn {\n  json: {\n    prompt: prompt,\n    date: dateStr,\n    dateISO: today.toISOString().split('T')[0],\n    stats: {\n      notesCount: notesData.count,\n      insightsCount: insightsData.count,\n      patternsCount: patternsData.count\n    }\n  }\n};"
  },
  "id": "build-prompt",
  "name": "Build Summary Prompt",
  "type": "n8n-nodes-base.function",
  "typeVersion": 1,
  "position": [900, 450]
}
```

**Step 2: Connect merge to build prompt**

Add to `connections`:

```json
"Merge Query Results": {
  "main": [[{ "node": "Build Summary Prompt", "type": "main", "index": 0 }]]
}
```

**Step 3: Commit**

```bash
git add workflows/08-daily-summary/workflow.json
git commit -m "feat(08): add build summary prompt node"
```

---

## Task 8: Add Ollama HTTP Request Node

**Files:**
- Modify: `workflows/08-daily-summary/workflow.json`

**Step 1: Add HTTP Request node to call Ollama**

Add to the `nodes` array:

```json
{
  "parameters": {
    "method": "POST",
    "url": "http://host.docker.internal:11434/api/generate",
    "sendBody": true,
    "specifyBody": "json",
    "jsonBody": "={{ JSON.stringify({ model: 'mistral:7b', prompt: $json.prompt, stream: false }) }}",
    "options": {
      "timeout": 120000
    }
  },
  "id": "ollama-request",
  "name": "Send to Ollama",
  "type": "n8n-nodes-base.httpRequest",
  "typeVersion": 4.2,
  "position": [1100, 450]
}
```

**Step 2: Connect build prompt to Ollama**

Add to `connections`:

```json
"Build Summary Prompt": {
  "main": [[{ "node": "Send to Ollama", "type": "main", "index": 0 }]]
}
```

**Step 3: Commit**

```bash
git add workflows/08-daily-summary/workflow.json
git commit -m "feat(08): add Ollama HTTP request node"
```

---

## Task 9: Add Write to Obsidian Node

**Files:**
- Modify: `workflows/08-daily-summary/workflow.json`

**Step 1: Add Function node to write markdown file**

Add to the `nodes` array:

```json
{
  "parameters": {
    "functionCode": "const fs = require('fs');\nconst path = require('path');\n\n// Get prompt data from earlier node\nconst promptData = $('Build Summary Prompt').item.json;\nconst ollamaResponse = $json;\n\n// Extract summary from Ollama response\nconst summary = ollamaResponse.response || 'Summary generation failed. Please check Ollama connection.';\n\n// Format the date for filename and title\nconst dateISO = promptData.dateISO;\nconst dateTitle = promptData.date;\nconst stats = promptData.stats;\n\n// Build markdown content\nconst markdown = `# Daily Summary - ${dateTitle}\n\n${summary}\n\n---\n\n**Stats:** ${stats.notesCount} notes captured, ${stats.insightsCount} processed, ${stats.patternsCount} active patterns\n\n---\n*Generated automatically at midnight by Selene*\n`;\n\n// Ensure Daily directory exists\nconst dailyDir = '/obsidian/Daily';\nif (!fs.existsSync(dailyDir)) {\n  fs.mkdirSync(dailyDir, { recursive: true });\n}\n\n// Write file\nconst filename = `${dateISO}-summary.md`;\nconst filepath = path.join(dailyDir, filename);\nfs.writeFileSync(filepath, markdown, 'utf8');\n\nreturn {\n  json: {\n    success: true,\n    filepath: filepath,\n    filename: filename,\n    date: dateISO,\n    summaryLength: summary.length,\n    stats: stats\n  }\n};"
  },
  "id": "write-obsidian",
  "name": "Write to Obsidian",
  "type": "n8n-nodes-base.function",
  "typeVersion": 1,
  "position": [1300, 450]
}
```

**Step 2: Connect Ollama to write node**

Add to `connections`:

```json
"Send to Ollama": {
  "main": [[{ "node": "Write to Obsidian", "type": "main", "index": 0 }]]
}
```

**Step 3: Commit**

```bash
git add workflows/08-daily-summary/workflow.json
git commit -m "feat(08): add write to Obsidian node"
```

---

## Task 10: Add Error Handling - Ollama Fallback

**Files:**
- Modify: `workflows/08-daily-summary/workflow.json`

**Step 1: Add onError to Ollama node**

Update the Ollama node to include error handling:

```json
{
  "parameters": {
    "method": "POST",
    "url": "http://host.docker.internal:11434/api/generate",
    "sendBody": true,
    "specifyBody": "json",
    "jsonBody": "={{ JSON.stringify({ model: 'mistral:7b', prompt: $json.prompt, stream: false }) }}",
    "options": {
      "timeout": 120000
    }
  },
  "id": "ollama-request",
  "name": "Send to Ollama",
  "type": "n8n-nodes-base.httpRequest",
  "typeVersion": 4.2,
  "position": [1100, 450],
  "onError": "continueErrorOutput"
}
```

**Step 2: Add fallback node for Ollama errors**

Add to `nodes` array:

```json
{
  "parameters": {
    "functionCode": "// Get prompt data from earlier node\nconst promptData = $('Build Summary Prompt').item.json;\nconst stats = promptData.stats;\n\n// Create fallback summary\nconst fallbackSummary = stats.notesCount > 0\n  ? `Captured ${stats.notesCount} note(s) today. Summary generation unavailable - Ollama may be offline.`\n  : `No new notes captured today. Summary generation unavailable - Ollama may be offline.`;\n\nreturn {\n  json: {\n    response: fallbackSummary,\n    fallback: true,\n    error: 'Ollama unavailable'\n  }\n};"
  },
  "id": "ollama-fallback",
  "name": "Fallback: Ollama Error",
  "type": "n8n-nodes-base.function",
  "typeVersion": 1,
  "position": [1100, 600]
}
```

**Step 3: Update connections for error path**

Update the Ollama connection to include error output:

```json
"Send to Ollama": {
  "main": [
    [{ "node": "Write to Obsidian", "type": "main", "index": 0 }],
    [{ "node": "Fallback: Ollama Error", "type": "main", "index": 0 }]
  ]
},
"Fallback: Ollama Error": {
  "main": [[{ "node": "Write to Obsidian", "type": "main", "index": 0 }]]
}
```

**Step 4: Commit**

```bash
git add workflows/08-daily-summary/workflow.json
git commit -m "feat(08): add Ollama error fallback handling"
```

---

## Task 11: Create Test Script

**Files:**
- Create: `workflows/08-daily-summary/scripts/test-with-markers.sh`

**Step 1: Create test script**

Create file `workflows/08-daily-summary/scripts/test-with-markers.sh`:

```bash
#!/bin/bash
set -e

cd "$(dirname "$0")/.."

# This workflow is schedule-triggered, so we test by:
# 1. Inserting test data into raw_notes
# 2. Manually triggering the workflow via n8n API
# 3. Checking the output file

TEST_RUN="test-run-$(date +%Y%m%d-%H%M%S)"
DB_PATH="../../data/selene.db"
OBSIDIAN_PATH="../../vault"

echo "========================================"
echo "Testing 08-daily-summary workflow"
echo "Test marker: $TEST_RUN"
echo "========================================"

# Test 1: Insert test note data
echo ""
echo "Test 1: Inserting test note data..."
sqlite3 "$DB_PATH" "INSERT INTO raw_notes (title, content, content_hash, created_at, test_run, status) VALUES ('Test Summary Note', 'This is a test note for the daily summary workflow. #testing #summary', 'test-hash-$TEST_RUN', datetime('now'), '$TEST_RUN', 'processed');"

# Verify insert
INSERTED=$(sqlite3 "$DB_PATH" "SELECT COUNT(*) FROM raw_notes WHERE test_run = '$TEST_RUN';")
echo "Inserted test notes: $INSERTED"

if [ "$INSERTED" -eq "1" ]; then
    echo "PASS: Test data inserted"
else
    echo "FAIL: Test data not inserted"
    exit 1
fi

# Test 2: Check Obsidian directory exists
echo ""
echo "Test 2: Checking Obsidian vault access..."
if [ -d "$OBSIDIAN_PATH" ]; then
    echo "PASS: Obsidian vault accessible at $OBSIDIAN_PATH"
else
    echo "WARN: Obsidian vault not found at $OBSIDIAN_PATH (may need Docker mount)"
fi

# Test 3: Manual workflow execution note
echo ""
echo "Test 3: Manual workflow execution"
echo "NOTE: To fully test this workflow, you need to:"
echo "  1. Import workflow to n8n: ./scripts/manage-workflow.sh update <id> workflows/08-daily-summary/workflow.json"
echo "  2. Manually trigger via n8n UI (Test workflow button)"
echo "  3. Check vault/Daily/ for output file"
echo ""

# Cleanup prompt
echo ""
echo "========================================"
read -p "Cleanup test data? (y/n) " -n 1 -r
echo ""
if [[ $REPLY =~ ^[Yy]$ ]]; then
    sqlite3 "$DB_PATH" "DELETE FROM raw_notes WHERE test_run = '$TEST_RUN';"
    echo "Test data cleaned up"

    # Remove test summary file if created
    TODAY=$(date +%Y-%m-%d)
    if [ -f "$OBSIDIAN_PATH/Daily/$TODAY-summary.md" ]; then
        rm "$OBSIDIAN_PATH/Daily/$TODAY-summary.md"
        echo "Removed test summary file"
    fi
else
    echo "Test data retained. Clean up with: ../../scripts/cleanup-tests.sh $TEST_RUN"
fi

echo ""
echo "========================================"
echo "Test Summary"
echo "========================================"
echo "Test marker: $TEST_RUN"
echo "Results: Manual verification required"
```

**Step 2: Make script executable**

```bash
chmod +x workflows/08-daily-summary/scripts/test-with-markers.sh
```

**Step 3: Verify script runs**

Run: `bash -n workflows/08-daily-summary/scripts/test-with-markers.sh`
Expected: No output (syntax valid)

**Step 4: Commit**

```bash
git add workflows/08-daily-summary/scripts/test-with-markers.sh
git commit -m "feat(08): add test script with markers"
```

---

## Task 12: Create README

**Files:**
- Create: `workflows/08-daily-summary/README.md`

**Step 1: Create README**

Create file `workflows/08-daily-summary/README.md`:

```markdown
# 08-Daily-Summary Workflow

Generates a daily executive summary at midnight, combining recent note activity with emerging patterns, and saves it to your Obsidian vault.

## Quick Start

1. **Import workflow:**
   ```bash
   ./scripts/manage-workflow.sh update <id> workflows/08-daily-summary/workflow.json
   ```

2. **Activate in n8n:**
   - Open n8n UI
   - Find "08-Daily-Summary | Selene"
   - Toggle Active switch ON

3. **Check output:**
   - Summaries appear in `vault/Daily/YYYY-MM-DD-summary.md`

## Schedule

- **Trigger:** Daily at midnight (00:00)
- **Timezone:** Server timezone

## Data Sources

1. **raw_notes** - Notes captured in the last 24 hours
2. **processed_notes** - LLM-extracted concepts and themes
3. **detected_patterns** - Active recurring patterns

## Output Format

```markdown
# Daily Summary - Monday, December 30, 2025

Captured 3 notes today focused on project planning and workflow automation.
The LLM extracted concepts around "task management" and "n8n integrations"
which connect to your ongoing theme of building external memory systems.

---

**Stats:** 3 notes captured, 2 processed, 1 active patterns

---
*Generated automatically at midnight by Selene*
```

## Configuration

### Ollama
- **URL:** `http://host.docker.internal:11434/api/generate`
- **Model:** `mistral:7b`
- **Timeout:** 120 seconds

### Output Path
- **Directory:** `/obsidian/Daily/`
- **Filename:** `YYYY-MM-DD-summary.md`

## Testing

```bash
cd workflows/08-daily-summary
./scripts/test-with-markers.sh
```

## Troubleshooting

### Summary not generated
1. Check n8n logs: `docker-compose logs -f n8n`
2. Verify workflow is active in n8n UI
3. Check Ollama is running: `curl http://localhost:11434/api/tags`

### Ollama timeout
- Increase timeout in HTTP Request node
- Check Ollama resource usage

### Empty summary
- Verify notes exist: `sqlite3 data/selene.db "SELECT COUNT(*) FROM raw_notes WHERE date(created_at) >= date('now', '-1 day');"`

## Files

- `workflow.json` - Main workflow definition
- `README.md` - This file
- `docs/STATUS.md` - Test results and status
- `scripts/test-with-markers.sh` - Test script
```

**Step 2: Commit**

```bash
git add workflows/08-daily-summary/README.md
git commit -m "docs(08): add README"
```

---

## Task 13: Create STATUS.md

**Files:**
- Create: `workflows/08-daily-summary/docs/STATUS.md`

**Step 1: Create STATUS.md**

Create file `workflows/08-daily-summary/docs/STATUS.md`:

```markdown
# 08-Daily-Summary Workflow Status

**Last Updated:** 2025-12-30
**Test Results:** Pending initial test

---

## Current Status

**Production Ready:** No (pending testing)

**Test Coverage:**
- [ ] Schedule trigger fires
- [ ] Notes query returns data
- [ ] Insights query returns data
- [ ] Patterns query returns data
- [ ] Ollama generates summary
- [ ] File written to Obsidian
- [ ] Error handling works

---

## Test Results

### Initial Implementation (2025-12-30)

**Status:** Not yet tested

| Test Case | Status | Notes |
|-----------|--------|-------|
| Schedule trigger | Pending | |
| Query notes | Pending | |
| Query insights | Pending | |
| Query patterns | Pending | |
| Build prompt | Pending | |
| Ollama request | Pending | |
| Write file | Pending | |
| Ollama fallback | Pending | |

---

## Known Issues

None yet - pending initial testing.

---

## Recent Changes

### 2025-12-30
- Initial implementation
- Schedule trigger (midnight daily)
- Three parallel queries (notes, insights, patterns)
- Ollama summarization
- Obsidian file output
- Error fallback for Ollama failures
```

**Step 2: Commit**

```bash
git add workflows/08-daily-summary/docs/STATUS.md
git commit -m "docs(08): add STATUS.md"
```

---

## Task 14: Assemble Complete Workflow JSON

**Files:**
- Modify: `workflows/08-daily-summary/workflow.json`

**Step 1: Create the complete workflow.json**

Replace the entire contents of `workflows/08-daily-summary/workflow.json` with the complete workflow (all nodes and connections assembled):

```json
{
  "name": "08-Daily-Summary | Selene",
  "active": false,
  "nodes": [
    {
      "parameters": {
        "rule": {
          "interval": [
            {
              "field": "cronExpression",
              "expression": "0 0 * * *"
            }
          ]
        }
      },
      "id": "schedule-trigger",
      "name": "Schedule: Midnight Daily",
      "type": "n8n-nodes-base.scheduleTrigger",
      "typeVersion": 1.2,
      "position": [250, 300]
    },
    {
      "parameters": {
        "functionCode": "const Database = require('better-sqlite3');\nlet db;\n\ntry {\n  db = new Database('/selene/data/selene.db', { readonly: true });\n  \n  const query = `\n    SELECT id, title, tags, word_count, created_at\n    FROM raw_notes\n    WHERE date(created_at) >= date('now', '-1 day')\n    AND test_run IS NULL\n    ORDER BY created_at DESC\n  `;\n  \n  const notes = db.prepare(query).all();\n  \n  db.close();\n  \n  return {\n    json: {\n      notes: notes,\n      count: notes.length,\n      queryDate: new Date().toISOString().split('T')[0]\n    }\n  };\n  \n} catch (error) {\n  if (db) db.close();\n  console.error('Query notes error:', error);\n  return {\n    json: {\n      notes: [],\n      count: 0,\n      error: error.message,\n      queryDate: new Date().toISOString().split('T')[0]\n    }\n  };\n}"
      },
      "id": "query-notes",
      "name": "Query Today's Notes",
      "type": "n8n-nodes-base.function",
      "typeVersion": 1,
      "position": [450, 200]
    },
    {
      "parameters": {
        "functionCode": "const Database = require('better-sqlite3');\nlet db;\n\ntry {\n  db = new Database('/selene/data/selene.db', { readonly: true });\n  \n  const query = `\n    SELECT \n      p.id,\n      p.concepts,\n      p.primary_theme,\n      p.secondary_themes,\n      r.title\n    FROM processed_notes p\n    JOIN raw_notes r ON p.raw_note_id = r.id\n    WHERE date(p.processed_at) >= date('now', '-1 day')\n    AND r.test_run IS NULL\n    ORDER BY p.processed_at DESC\n  `;\n  \n  const insights = db.prepare(query).all();\n  \n  db.close();\n  \n  const parsedInsights = insights.map(i => ({\n    ...i,\n    concepts: i.concepts ? JSON.parse(i.concepts) : [],\n    secondary_themes: i.secondary_themes ? JSON.parse(i.secondary_themes) : []\n  }));\n  \n  return {\n    json: {\n      insights: parsedInsights,\n      count: parsedInsights.length\n    }\n  };\n  \n} catch (error) {\n  if (db) db.close();\n  console.error('Query insights error:', error);\n  return {\n    json: {\n      insights: [],\n      count: 0,\n      error: error.message\n    }\n  };\n}"
      },
      "id": "query-insights",
      "name": "Query Processed Insights",
      "type": "n8n-nodes-base.function",
      "typeVersion": 1,
      "position": [450, 350]
    },
    {
      "parameters": {
        "functionCode": "const Database = require('better-sqlite3');\nlet db;\n\ntry {\n  db = new Database('/selene/data/selene.db', { readonly: true });\n  \n  const query = `\n    SELECT \n      pattern_type,\n      pattern_name,\n      description,\n      confidence,\n      discovered_at\n    FROM detected_patterns\n    WHERE is_active = 1\n    ORDER BY discovered_at DESC\n    LIMIT 5\n  `;\n  \n  const patterns = db.prepare(query).all();\n  \n  db.close();\n  \n  return {\n    json: {\n      patterns: patterns,\n      count: patterns.length\n    }\n  };\n  \n} catch (error) {\n  if (db) db.close();\n  console.error('Query patterns error:', error);\n  return {\n    json: {\n      patterns: [],\n      count: 0,\n      error: error.message\n    }\n  };\n}"
      },
      "id": "query-patterns",
      "name": "Query Active Patterns",
      "type": "n8n-nodes-base.function",
      "typeVersion": 1,
      "position": [450, 500]
    },
    {
      "parameters": {
        "mode": "combine",
        "combinationMode": "mergeByPosition",
        "options": {}
      },
      "id": "merge-data",
      "name": "Merge Query Results",
      "type": "n8n-nodes-base.merge",
      "typeVersion": 3,
      "position": [700, 350]
    },
    {
      "parameters": {
        "functionCode": "const items = $input.all();\n\nconst notesData = items[0]?.json || { notes: [], count: 0 };\nconst insightsData = items[1]?.json || { insights: [], count: 0 };\nconst patternsData = items[2]?.json || { patterns: [], count: 0 };\n\nconst today = new Date();\nconst dateStr = today.toLocaleDateString('en-US', { \n  weekday: 'long', \n  year: 'numeric', \n  month: 'long', \n  day: 'numeric' \n});\n\nlet notesSection = '';\nif (notesData.count === 0) {\n  notesSection = 'No new notes captured today.';\n} else {\n  notesSection = notesData.notes.map(n => {\n    const tags = n.tags ? JSON.parse(n.tags).join(', ') : 'no tags';\n    return `- \"${n.title}\" (${n.word_count} words, tags: ${tags})`;\n  }).join('\\n');\n}\n\nlet insightsSection = '';\nif (insightsData.count === 0) {\n  insightsSection = 'No notes processed today.';\n} else {\n  const allConcepts = insightsData.insights.flatMap(i => i.concepts || []);\n  const allThemes = insightsData.insights.map(i => i.primary_theme).filter(Boolean);\n  const uniqueConcepts = [...new Set(allConcepts)].slice(0, 10);\n  const uniqueThemes = [...new Set(allThemes)];\n  insightsSection = `Concepts: ${uniqueConcepts.join(', ') || 'none'}\\nThemes: ${uniqueThemes.join(', ') || 'none'}`;\n}\n\nlet patternsSection = '';\nif (patternsData.count === 0) {\n  patternsSection = 'No active patterns detected yet.';\n} else {\n  patternsSection = patternsData.patterns.map(p => \n    `- ${p.pattern_name}: ${p.description || 'No description'}`\n  ).join('\\n');\n}\n\nconst prompt = `You are summarizing a personal knowledge capture system for someone with ADHD.\nBe brief and clear. Write 2-4 sentences max.\n\nToday's date: ${dateStr}\n\nNotes captured today (${notesData.count}):\n${notesSection}\n\nInsights extracted:\n${insightsSection}\n\nRecurring themes:\n${patternsSection}\n\nWrite a brief executive summary paragraph covering:\n- What was captured today (or note if quiet day)\n- Any notable insights or themes emerging`;\n\nreturn {\n  json: {\n    prompt: prompt,\n    date: dateStr,\n    dateISO: today.toISOString().split('T')[0],\n    stats: {\n      notesCount: notesData.count,\n      insightsCount: insightsData.count,\n      patternsCount: patternsData.count\n    }\n  }\n};"
      },
      "id": "build-prompt",
      "name": "Build Summary Prompt",
      "type": "n8n-nodes-base.function",
      "typeVersion": 1,
      "position": [900, 350]
    },
    {
      "parameters": {
        "method": "POST",
        "url": "http://host.docker.internal:11434/api/generate",
        "sendBody": true,
        "specifyBody": "json",
        "jsonBody": "={{ JSON.stringify({ model: 'mistral:7b', prompt: $json.prompt, stream: false }) }}",
        "options": {
          "timeout": 120000
        }
      },
      "id": "ollama-request",
      "name": "Send to Ollama",
      "type": "n8n-nodes-base.httpRequest",
      "typeVersion": 4.2,
      "position": [1100, 350],
      "onError": "continueErrorOutput"
    },
    {
      "parameters": {
        "functionCode": "const promptData = $('Build Summary Prompt').item.json;\nconst stats = promptData.stats;\n\nconst fallbackSummary = stats.notesCount > 0\n  ? `Captured ${stats.notesCount} note(s) today. Summary generation unavailable - Ollama may be offline.`\n  : `No new notes captured today. Summary generation unavailable - Ollama may be offline.`;\n\nreturn {\n  json: {\n    response: fallbackSummary,\n    fallback: true,\n    error: 'Ollama unavailable'\n  }\n};"
      },
      "id": "ollama-fallback",
      "name": "Fallback: Ollama Error",
      "type": "n8n-nodes-base.function",
      "typeVersion": 1,
      "position": [1100, 500]
    },
    {
      "parameters": {
        "functionCode": "const fs = require('fs');\nconst path = require('path');\n\nconst promptData = $('Build Summary Prompt').item.json;\nconst ollamaResponse = $json;\n\nconst summary = ollamaResponse.response || 'Summary generation failed. Please check Ollama connection.';\n\nconst dateISO = promptData.dateISO;\nconst dateTitle = promptData.date;\nconst stats = promptData.stats;\n\nconst markdown = `# Daily Summary - ${dateTitle}\n\n${summary}\n\n---\n\n**Stats:** ${stats.notesCount} notes captured, ${stats.insightsCount} processed, ${stats.patternsCount} active patterns\n\n---\n*Generated automatically at midnight by Selene*\n`;\n\nconst dailyDir = '/obsidian/Daily';\nif (!fs.existsSync(dailyDir)) {\n  fs.mkdirSync(dailyDir, { recursive: true });\n}\n\nconst filename = `${dateISO}-summary.md`;\nconst filepath = path.join(dailyDir, filename);\nfs.writeFileSync(filepath, markdown, 'utf8');\n\nreturn {\n  json: {\n    success: true,\n    filepath: filepath,\n    filename: filename,\n    date: dateISO,\n    summaryLength: summary.length,\n    stats: stats\n  }\n};"
      },
      "id": "write-obsidian",
      "name": "Write to Obsidian",
      "type": "n8n-nodes-base.function",
      "typeVersion": 1,
      "position": [1300, 400]
    }
  ],
  "connections": {
    "Schedule: Midnight Daily": {
      "main": [[
        { "node": "Query Today's Notes", "type": "main", "index": 0 },
        { "node": "Query Processed Insights", "type": "main", "index": 0 },
        { "node": "Query Active Patterns", "type": "main", "index": 0 }
      ]]
    },
    "Query Today's Notes": {
      "main": [[{ "node": "Merge Query Results", "type": "main", "index": 0 }]]
    },
    "Query Processed Insights": {
      "main": [[{ "node": "Merge Query Results", "type": "main", "index": 1 }]]
    },
    "Query Active Patterns": {
      "main": [[{ "node": "Merge Query Results", "type": "main", "index": 2 }]]
    },
    "Merge Query Results": {
      "main": [[{ "node": "Build Summary Prompt", "type": "main", "index": 0 }]]
    },
    "Build Summary Prompt": {
      "main": [[{ "node": "Send to Ollama", "type": "main", "index": 0 }]]
    },
    "Send to Ollama": {
      "main": [
        [{ "node": "Write to Obsidian", "type": "main", "index": 0 }],
        [{ "node": "Fallback: Ollama Error", "type": "main", "index": 0 }]
      ]
    },
    "Fallback: Ollama Error": {
      "main": [[{ "node": "Write to Obsidian", "type": "main", "index": 0 }]]
    }
  },
  "settings": {
    "executionOrder": "v1"
  }
}
```

**Step 2: Verify JSON is valid**

Run: `python3 -c "import json; json.load(open('workflows/08-daily-summary/workflow.json'))"`
Expected: No output (valid JSON)

**Step 3: Commit**

```bash
git add workflows/08-daily-summary/workflow.json
git commit -m "feat(08): complete workflow with all nodes and connections"
```

---

## Task 15: Import and Test Workflow

**Step 1: Start Docker if not running**

```bash
docker-compose ps
# If not running:
docker-compose up -d
```

**Step 2: Import workflow to n8n**

```bash
# First, check if workflow already exists
./scripts/manage-workflow.sh list

# If creating new:
# Note: You may need to import via n8n UI first, then use update
# Or use the n8n API directly

# After import, get the workflow ID and update:
./scripts/manage-workflow.sh update <workflow-id> workflows/08-daily-summary/workflow.json
```

**Step 3: Test workflow manually**

1. Open n8n UI at http://localhost:5678
2. Find "08-Daily-Summary | Selene"
3. Click "Test workflow" button
4. Check execution logs for errors

**Step 4: Verify output**

```bash
ls -la vault/Daily/
cat vault/Daily/$(date +%Y-%m-%d)-summary.md
```

**Step 5: Update STATUS.md with test results**

Update `workflows/08-daily-summary/docs/STATUS.md` with actual test results.

**Step 6: Commit**

```bash
git add workflows/08-daily-summary/docs/STATUS.md
git commit -m "test(08): verify workflow execution and update status"
```

---

## Task 16: Activate Workflow for Production

**Step 1: Activate workflow in n8n**

1. Open n8n UI
2. Find "08-Daily-Summary | Selene"
3. Toggle the "Active" switch ON

**Step 2: Verify activation**

```bash
./scripts/manage-workflow.sh list | grep "08-Daily"
```
Expected: Shows "active: true"

**Step 3: Final commit**

```bash
git add -A
git commit -m "feat(08): daily summary workflow complete and activated"
```

---

## Summary

**Total Tasks:** 16
**Estimated Commits:** 14

**Files Created:**
- `workflows/08-daily-summary/workflow.json`
- `workflows/08-daily-summary/README.md`
- `workflows/08-daily-summary/docs/STATUS.md`
- `workflows/08-daily-summary/scripts/test-with-markers.sh`

**Workflow Flow:**
```
Schedule (midnight)
    → Query Notes (parallel)
    → Query Insights (parallel)
    → Query Patterns (parallel)
        → Merge Results
            → Build Prompt
                → Ollama Request
                    → Write to Obsidian
                    → (on error) Fallback → Write to Obsidian
```
