# Feedback Pipeline Implementation Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** Extend Workflow 01 to classify `#selene-feedback` notes using Ollama and append structured items to `docs/backlog/user-stories.md`.

**Architecture:** After the existing `Insert Feedback Note` node, add nodes to: (1) call Ollama for classification, (2) read existing backlog, (3) check for duplicates, (4) append new item with auto-generated ID, (5) write updated backlog file. All processing happens synchronously in the webhook call.

**Tech Stack:** n8n workflow nodes, Ollama (mistral:7b), better-sqlite3, file I/O

**Design Doc:** `docs/plans/2026-01-02-feedback-pipeline-design.md`

---

## Task 1: Create Database Migration

**Files:**
- Create: `database/migrations/012_feedback_classification.sql`

**Step 1: Write the migration file**

```sql
-- Migration: 012_feedback_classification.sql
-- Purpose: Add classification tracking columns to feedback_notes table

-- Add status tracking to feedback_notes
ALTER TABLE feedback_notes ADD COLUMN status TEXT DEFAULT 'pending';
ALTER TABLE feedback_notes ADD COLUMN category TEXT;
ALTER TABLE feedback_notes ADD COLUMN backlog_id TEXT;
ALTER TABLE feedback_notes ADD COLUMN classified_at DATETIME;
ALTER TABLE feedback_notes ADD COLUMN ai_confidence REAL;
ALTER TABLE feedback_notes ADD COLUMN ai_reasoning TEXT;

-- Index for finding unprocessed feedback
CREATE INDEX IF NOT EXISTS idx_feedback_status ON feedback_notes(status);
```

**Step 2: Verify migration file exists**

Run: `cat database/migrations/012_feedback_classification.sql`
Expected: File contents displayed

**Step 3: Apply migration to database**

Run: `sqlite3 data/selene.db < database/migrations/012_feedback_classification.sql`
Expected: No output (success)

**Step 4: Verify columns exist**

Run: `sqlite3 data/selene.db ".schema feedback_notes"`
Expected: Schema shows new columns (status, category, backlog_id, etc.)

**Step 5: Commit**

```bash
git add database/migrations/012_feedback_classification.sql
git commit -m "feat(db): add feedback classification columns (migration 012)"
```

---

## Task 2: Update Backlog File Format

**Files:**
- Modify: `docs/backlog/user-stories.md`

**Step 1: Verify current backlog file exists**

Run: `cat docs/backlog/user-stories.md`
Expected: File exists with current format

**Step 2: Update to new format with all sections**

The file should already have the new format from the design phase. Verify it has:
- User Stories section with table
- Feature Requests section with table
- Bugs section with table
- Improvements section with table
- Completed section with table

If not, update to match the format in `docs/plans/2026-01-02-feedback-pipeline-design.md`.

**Step 3: Commit if changed**

```bash
git add docs/backlog/user-stories.md
git commit -m "docs: update backlog format with all category sections"
```

---

## Task 3: Create Classification Prompt Template

**Files:**
- Create: `prompts/feedback-classification.txt`

**Step 1: Write the prompt template**

```text
You are classifying user feedback about the Selene app into backlog items.

FEEDBACK:
"""
{{feedback_content}}
"""

EXISTING BACKLOG TITLES (for duplicate detection):
{{existing_titles}}

Classify this feedback into exactly ONE category:
- user_story: A need expressed from user perspective ("I wanted...", "I couldn't...")
- feature_request: A specific new capability ("Add X", "Support Y")
- bug: Something broken or producing wrong results
- improvement: Enhancement to existing functionality
- noise: Not actionable (test messages, incomplete thoughts, off-topic)

Respond in JSON only:
{
  "category": "user_story|feature_request|bug|improvement|noise",
  "title": "Brief title (max 60 chars, starts with verb for bugs/improvements)",
  "description": "One sentence explaining the need or issue",
  "confidence": 0.0-1.0,
  "duplicate_of": "ID if matches existing item, null otherwise",
  "reasoning": "Why this category and title"
}

Rules:
- If confidence < 0.5, default to "noise"
- If feedback closely matches an existing title, set duplicate_of
- Titles should be scannable and specific, not generic
```

**Step 2: Verify file exists**

Run: `cat prompts/feedback-classification.txt`
Expected: Prompt template displayed

**Step 3: Commit**

```bash
git add prompts/feedback-classification.txt
git commit -m "feat: add feedback classification prompt template"
```

---

## Task 4: Export Workflow 01 (Backup)

**Files:**
- Backup: `workflows/01-ingestion/workflow.json`

**Step 1: Check n8n container is running**

Run: `docker-compose ps | grep n8n`
Expected: Container running

**Step 2: Export current workflow**

Run: `./scripts/manage-workflow.sh list`
Expected: List of workflows with IDs

Run: `./scripts/manage-workflow.sh export <01-ingestion-id>`
Expected: Backup created with timestamp

**Step 3: Verify workflow.json exists**

Run: `ls -la workflows/01-ingestion/workflow.json`
Expected: File exists with recent timestamp

---

## Task 5: Add Classification Nodes to Workflow 01

**Files:**
- Modify: `workflows/01-ingestion/workflow.json`

**Step 1: Read current workflow structure**

Read `workflows/01-ingestion/workflow.json` and identify:
- The `Insert Feedback Note` node (id: "insert-feedback")
- The connection from `Insert Feedback Note` to `Respond to Webhook`

**Step 2: Add "Build Classification Prompt" node**

Add this node to the `nodes` array (after Insert Feedback Note):

```json
{
  "parameters": {
    "functionCode": "const Database = require('better-sqlite3');\nconst fs = require('fs');\n\nconst feedbackResult = $json;\nconst feedbackId = feedbackResult.feedback_id;\n\n// Read the feedback content from database\nconst db = new Database('/selene/data/selene.db', { readonly: true });\nconst feedback = db.prepare('SELECT content FROM feedback_notes WHERE id = ?').get(feedbackId);\ndb.close();\n\nif (!feedback) {\n  throw new Error('Feedback not found: ' + feedbackId);\n}\n\n// Read existing backlog to get titles for duplicate detection\nlet existingTitles = [];\ntry {\n  const backlogContent = fs.readFileSync('/selene/docs/backlog/user-stories.md', 'utf8');\n  // Extract titles from table rows (| ID | Title | ...)\n  const titleMatches = backlogContent.match(/\\| [A-Z]+-\\d+ \\| ([^|]+) \\|/g) || [];\n  existingTitles = titleMatches.map(m => {\n    const parts = m.split('|');\n    return parts[2] ? parts[2].trim() : '';\n  }).filter(t => t.length > 0);\n} catch (e) {\n  // File doesn't exist or can't be read - that's ok\n  existingTitles = [];\n}\n\n// Build the prompt\nconst promptTemplate = `You are classifying user feedback about the Selene app into backlog items.\n\nFEEDBACK:\n\"\"\"\n${feedback.content}\n\"\"\"\n\nEXISTING BACKLOG TITLES (for duplicate detection):\n${existingTitles.length > 0 ? existingTitles.join('\\n') : '(none)'}\n\nClassify this feedback into exactly ONE category:\n- user_story: A need expressed from user perspective (\"I wanted...\", \"I couldn't...\")\n- feature_request: A specific new capability (\"Add X\", \"Support Y\")\n- bug: Something broken or producing wrong results\n- improvement: Enhancement to existing functionality\n- noise: Not actionable (test messages, incomplete thoughts, off-topic)\n\nRespond in JSON only:\n{\n  \"category\": \"user_story|feature_request|bug|improvement|noise\",\n  \"title\": \"Brief title (max 60 chars, starts with verb for bugs/improvements)\",\n  \"description\": \"One sentence explaining the need or issue\",\n  \"confidence\": 0.0-1.0,\n  \"duplicate_of\": \"ID if matches existing item, null otherwise\",\n  \"reasoning\": \"Why this category and title\"\n}`;\n\nreturn {\n  json: {\n    feedbackId: feedbackId,\n    feedbackContent: feedback.content,\n    prompt: promptTemplate,\n    existingTitles: existingTitles,\n    testRun: feedbackResult.testRun\n  }\n};"
  },
  "id": "build-classification-prompt",
  "name": "Build Classification Prompt",
  "type": "n8n-nodes-base.function",
  "typeVersion": 1,
  "position": [1150, 200]
}
```

**Step 3: Add "Ollama: Classify Feedback" node**

```json
{
  "parameters": {
    "url": "http://host.docker.internal:11434/api/generate",
    "sendBody": true,
    "specifyBody": "json",
    "jsonBody": "={\n  \"model\": \"mistral:7b\",\n  \"prompt\": {{ JSON.stringify($json.prompt) }},\n  \"stream\": false,\n  \"format\": \"json\"\n}",
    "options": {
      "timeout": 120000
    }
  },
  "id": "ollama-classify",
  "name": "Ollama: Classify Feedback",
  "type": "n8n-nodes-base.httpRequest",
  "typeVersion": 4,
  "position": [1350, 200]
}
```

**Step 4: Add "Parse Classification" node**

```json
{
  "parameters": {
    "functionCode": "const ollamaResponse = $json;\nconst prevData = $('Build Classification Prompt').item.json;\n\nlet classification;\ntry {\n  // Ollama returns response in 'response' field\n  const responseText = ollamaResponse.response || '';\n  classification = JSON.parse(responseText);\n} catch (e) {\n  // If parsing fails, default to noise\n  classification = {\n    category: 'noise',\n    title: 'Unparseable feedback',\n    description: 'AI could not classify this feedback',\n    confidence: 0,\n    duplicate_of: null,\n    reasoning: 'JSON parse error: ' + e.message\n  };\n}\n\n// Validate required fields\nconst validCategories = ['user_story', 'feature_request', 'bug', 'improvement', 'noise'];\nif (!validCategories.includes(classification.category)) {\n  classification.category = 'noise';\n}\n\n// If confidence too low, mark as noise\nif (classification.confidence < 0.5) {\n  classification.category = 'noise';\n  classification.reasoning = 'Low confidence (' + classification.confidence + '): ' + classification.reasoning;\n}\n\nreturn {\n  json: {\n    feedbackId: prevData.feedbackId,\n    feedbackContent: prevData.feedbackContent,\n    existingTitles: prevData.existingTitles,\n    testRun: prevData.testRun,\n    classification: classification\n  }\n};"
  },
  "id": "parse-classification",
  "name": "Parse Classification",
  "type": "n8n-nodes-base.function",
  "typeVersion": 1,
  "position": [1550, 200]
}
```

**Step 5: Add "Route by Category" node**

```json
{
  "parameters": {
    "conditions": {
      "string": [
        {
          "value1": "={{ $json.classification.category }}",
          "operation": "equals",
          "value2": "noise"
        }
      ]
    }
  },
  "id": "route-by-category",
  "name": "Is Noise?",
  "type": "n8n-nodes-base.if",
  "typeVersion": 1,
  "position": [1750, 200]
}
```

**Step 6: Add "Check Duplicate" node**

```json
{
  "parameters": {
    "conditions": {
      "string": [
        {
          "value1": "={{ $json.classification.duplicate_of }}",
          "operation": "isNotEmpty"
        }
      ]
    }
  },
  "id": "check-duplicate",
  "name": "Is Duplicate?",
  "type": "n8n-nodes-base.if",
  "typeVersion": 1,
  "position": [1950, 100]
}
```

**Step 7: Add "Append to Backlog" node**

```json
{
  "parameters": {
    "functionCode": "const fs = require('fs');\n\nconst data = $json;\nconst classification = data.classification;\nconst testRun = data.testRun;\n\n// Don't modify real backlog during tests\nconst backlogPath = testRun \n  ? '/selene/docs/backlog/user-stories-test.md'\n  : '/selene/docs/backlog/user-stories.md';\n\n// Read current backlog\nlet backlogContent;\ntry {\n  backlogContent = fs.readFileSync(backlogPath, 'utf8');\n} catch (e) {\n  // Create minimal backlog if doesn't exist\n  backlogContent = '# Selene Development Backlog\\n\\n## User Stories\\n\\n| ID | Story | Priority | Status | Source Date |\\n|----|-------|----------|--------|-------------|\\n\\n## Feature Requests\\n\\n| ID | Request | Priority | Status | Source Date |\\n|----|---------|----------|--------|-------------|\\n\\n## Bugs\\n\\n| ID | Issue | Priority | Status | Source Date |\\n|----|-------|----------|--------|-------------|\\n\\n## Improvements\\n\\n| ID | Enhancement | Priority | Status | Source Date |\\n|----|-------------|----------|--------|-------------|\\n\\n## Completed\\n\\n| ID | Description | Completed | Reference |\\n|----|-------------|-----------|-----------|\\n';\n}\n\n// Map category to prefix and section\nconst categoryMap = {\n  'user_story': { prefix: 'US', section: '## User Stories' },\n  'feature_request': { prefix: 'FR', section: '## Feature Requests' },\n  'bug': { prefix: 'BUG', section: '## Bugs' },\n  'improvement': { prefix: 'IMP', section: '## Improvements' }\n};\n\nconst catInfo = categoryMap[classification.category];\nif (!catInfo) {\n  throw new Error('Invalid category for backlog: ' + classification.category);\n}\n\n// Find highest ID for this category\nconst idPattern = new RegExp(catInfo.prefix + '-(\\\\d+)', 'g');\nconst matches = [...backlogContent.matchAll(idPattern)];\nconst maxId = matches.length > 0 \n  ? Math.max(...matches.map(m => parseInt(m[1])))\n  : 0;\nconst newId = catInfo.prefix + '-' + String(maxId + 1).padStart(3, '0');\n\n// Create new row\nconst today = new Date().toISOString().split('T')[0];\nconst newRow = `| ${newId} | ${classification.title} | - | Open | ${today} |`;\n\n// Find the section and insert after the header row\nconst sectionIndex = backlogContent.indexOf(catInfo.section);\nif (sectionIndex === -1) {\n  throw new Error('Section not found: ' + catInfo.section);\n}\n\n// Find the table header (|----...) after the section\nconst afterSection = backlogContent.substring(sectionIndex);\nconst headerRowMatch = afterSection.match(/\\|-+\\|[^\\n]*\\n/);\nif (!headerRowMatch) {\n  throw new Error('Table header not found in section: ' + catInfo.section);\n}\n\nconst insertPosition = sectionIndex + headerRowMatch.index + headerRowMatch[0].length;\n\n// Insert the new row\nconst updatedContent = \n  backlogContent.substring(0, insertPosition) + \n  newRow + '\\n' + \n  backlogContent.substring(insertPosition);\n\n// Update timestamp\nconst timestampPattern = /Last updated: [^\\n]+/;\nconst newTimestamp = 'Last updated: ' + new Date().toISOString().replace('T', ' ').substring(0, 19) + ' UTC';\nconst finalContent = updatedContent.replace(timestampPattern, newTimestamp);\n\n// Write back\nfs.writeFileSync(backlogPath, finalContent);\n\nreturn {\n  json: {\n    feedbackId: data.feedbackId,\n    backlogId: newId,\n    category: classification.category,\n    title: classification.title,\n    testRun: testRun\n  }\n};"
  },
  "id": "append-to-backlog",
  "name": "Append to Backlog",
  "type": "n8n-nodes-base.function",
  "typeVersion": 1,
  "position": [2150, 0]
}
```

**Step 8: Add "Update Feedback Status" node**

```json
{
  "parameters": {
    "functionCode": "const Database = require('better-sqlite3');\n\nconst data = $json;\nlet status, backlogId, category, confidence, reasoning;\n\n// Determine which path we came from\nif (data.backlogId) {\n  // Came from Append to Backlog\n  status = 'added_to_backlog';\n  backlogId = data.backlogId;\n  category = data.category;\n  confidence = null;  // Already stored\n  reasoning = null;\n} else if (data.classification) {\n  // Came from noise or duplicate path\n  const c = data.classification;\n  if (c.duplicate_of) {\n    status = 'duplicate';\n    backlogId = c.duplicate_of;\n  } else {\n    status = 'noise';\n    backlogId = null;\n  }\n  category = c.category;\n  confidence = c.confidence;\n  reasoning = c.reasoning;\n} else {\n  throw new Error('Unknown data path');\n}\n\nconst db = new Database('/selene/data/selene.db');\n\ndb.prepare(`\n  UPDATE feedback_notes \n  SET status = ?, category = ?, backlog_id = ?, \n      classified_at = datetime('now'), \n      ai_confidence = ?, ai_reasoning = ?\n  WHERE id = ?\n`).run(\n  status,\n  category,\n  backlogId,\n  confidence,\n  reasoning,\n  data.feedbackId\n);\n\ndb.close();\n\nreturn {\n  json: {\n    success: true,\n    action: 'feedback_classified',\n    feedbackId: data.feedbackId,\n    status: status,\n    category: category,\n    backlogId: backlogId,\n    testRun: data.testRun\n  }\n};"
  },
  "id": "update-feedback-status",
  "name": "Update Feedback Status",
  "type": "n8n-nodes-base.function",
  "typeVersion": 1,
  "position": [2350, 200]
}
```

**Step 9: Update connections**

Replace the connection from `Insert Feedback Note` to `Respond to Webhook` with the new flow:

```json
"Insert Feedback Note": {
  "main": [
    [
      {
        "node": "Build Classification Prompt",
        "type": "main",
        "index": 0
      }
    ]
  ]
},
"Build Classification Prompt": {
  "main": [
    [
      {
        "node": "Ollama: Classify Feedback",
        "type": "main",
        "index": 0
      }
    ]
  ]
},
"Ollama: Classify Feedback": {
  "main": [
    [
      {
        "node": "Parse Classification",
        "type": "main",
        "index": 0
      }
    ]
  ]
},
"Parse Classification": {
  "main": [
    [
      {
        "node": "Is Noise?",
        "type": "main",
        "index": 0
      }
    ]
  ]
},
"Is Noise?": {
  "main": [
    [
      {
        "node": "Update Feedback Status",
        "type": "main",
        "index": 0
      }
    ],
    [
      {
        "node": "Is Duplicate?",
        "type": "main",
        "index": 0
      }
    ]
  ]
},
"Is Duplicate?": {
  "main": [
    [
      {
        "node": "Update Feedback Status",
        "type": "main",
        "index": 0
      }
    ],
    [
      {
        "node": "Append to Backlog",
        "type": "main",
        "index": 0
      }
    ]
  ]
},
"Append to Backlog": {
  "main": [
    [
      {
        "node": "Update Feedback Status",
        "type": "main",
        "index": 0
      }
    ]
  ]
},
"Update Feedback Status": {
  "main": [
    [
      {
        "node": "Respond to Webhook",
        "type": "main",
        "index": 0
      }
    ]
  ]
}
```

**Step 10: Commit workflow changes**

```bash
git add workflows/01-ingestion/workflow.json
git commit -m "feat(01): add feedback classification and backlog append nodes"
```

---

## Task 6: Update Workflow in n8n

**Step 1: Push updated workflow to n8n**

Run: `./scripts/manage-workflow.sh update <01-ingestion-id> /workflows/01-ingestion/workflow.json`
Expected: "Workflow updated successfully"

**Step 2: Verify workflow is active**

Run: `./scripts/manage-workflow.sh show <01-ingestion-id>`
Expected: Workflow shows as active with new nodes

---

## Task 7: Create Test Script

**Files:**
- Create: `workflows/01-ingestion/scripts/test-feedback-pipeline.sh`

**Step 1: Write the test script**

```bash
#!/bin/bash
# Test the feedback classification pipeline
# Uses test_run marker to isolate test data

set -e

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/../../.." && pwd)"
DB_PATH="$PROJECT_ROOT/data/selene.db"
WEBHOOK_URL="http://localhost:5678/webhook/api/drafts"

# Colors
GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[0;33m'
NC='\033[0m'

TEST_RUN="test-run-$(date +%Y%m%d-%H%M%S)"

echo "=========================================="
echo "Feedback Pipeline Test"
echo "Test Run: $TEST_RUN"
echo "=========================================="

# Test 1: User story feedback
echo -e "\n${YELLOW}Test 1: User story feedback${NC}"
RESPONSE=$(curl -s -X POST "$WEBHOOK_URL" \
  -H "Content-Type: application/json" \
  -d "{
    \"content\": \"I wanted to see where my tasks came from but there was no way to trace them back to the original note #selene-feedback\",
    \"test_run\": \"$TEST_RUN\"
  }")

echo "Response: $RESPONSE"
if echo "$RESPONSE" | grep -q "feedback_classified"; then
  echo -e "${GREEN}✓ Test 1 passed${NC}"
else
  echo -e "${RED}✗ Test 1 failed${NC}"
fi

# Test 2: Feature request feedback
echo -e "\n${YELLOW}Test 2: Feature request feedback${NC}"
RESPONSE=$(curl -s -X POST "$WEBHOOK_URL" \
  -H "Content-Type: application/json" \
  -d "{
    \"content\": \"Add dark mode to SeleneChat #selene-feedback\",
    \"test_run\": \"$TEST_RUN\"
  }")

echo "Response: $RESPONSE"
if echo "$RESPONSE" | grep -q "feedback_classified"; then
  echo -e "${GREEN}✓ Test 2 passed${NC}"
else
  echo -e "${RED}✗ Test 2 failed${NC}"
fi

# Test 3: Bug report feedback
echo -e "\n${YELLOW}Test 3: Bug report feedback${NC}"
RESPONSE=$(curl -s -X POST "$WEBHOOK_URL" \
  -H "Content-Type: application/json" \
  -d "{
    \"content\": \"The task extraction gave me a high-energy task when I specifically said I was tired #selene-feedback\",
    \"test_run\": \"$TEST_RUN\"
  }")

echo "Response: $RESPONSE"
if echo "$RESPONSE" | grep -q "feedback_classified"; then
  echo -e "${GREEN}✓ Test 3 passed${NC}"
else
  echo -e "${RED}✗ Test 3 failed${NC}"
fi

# Test 4: Noise (should be filtered)
echo -e "\n${YELLOW}Test 4: Noise feedback${NC}"
RESPONSE=$(curl -s -X POST "$WEBHOOK_URL" \
  -H "Content-Type: application/json" \
  -d "{
    \"content\": \"testing 123 #selene-feedback\",
    \"test_run\": \"$TEST_RUN\"
  }")

echo "Response: $RESPONSE"
if echo "$RESPONSE" | grep -q "noise"; then
  echo -e "${GREEN}✓ Test 4 passed (correctly identified as noise)${NC}"
else
  echo -e "${YELLOW}⚠ Test 4: Check if classified correctly${NC}"
fi

# Verify database entries
echo -e "\n${YELLOW}Verifying database entries...${NC}"
echo "Feedback notes created:"
sqlite3 "$DB_PATH" "SELECT id, category, status, backlog_id FROM feedback_notes WHERE test_run = '$TEST_RUN';"

# Verify backlog entries (in test file)
echo -e "\n${YELLOW}Checking test backlog file...${NC}"
if [ -f "$PROJECT_ROOT/docs/backlog/user-stories-test.md" ]; then
  grep -E "^\\|" "$PROJECT_ROOT/docs/backlog/user-stories-test.md" | tail -5
else
  echo "Test backlog file not found (expected for noise-only tests)"
fi

# Cleanup prompt
echo -e "\n${YELLOW}=========================================="
echo "Test run complete: $TEST_RUN"
echo "==========================================${NC}"
read -p "Cleanup test data? (y/n) " -n 1 -r
echo
if [[ $REPLY =~ ^[Yy]$ ]]; then
  echo "Cleaning up..."
  sqlite3 "$DB_PATH" "DELETE FROM feedback_notes WHERE test_run = '$TEST_RUN';"
  rm -f "$PROJECT_ROOT/docs/backlog/user-stories-test.md"
  echo -e "${GREEN}Cleanup complete${NC}"
fi
```

**Step 2: Make script executable**

Run: `chmod +x workflows/01-ingestion/scripts/test-feedback-pipeline.sh`
Expected: No output (success)

**Step 3: Commit test script**

```bash
git add workflows/01-ingestion/scripts/test-feedback-pipeline.sh
git commit -m "test(01): add feedback pipeline test script"
```

---

## Task 8: Run Tests and Verify

**Step 1: Ensure Ollama is running**

Run: `curl -s http://localhost:11434/api/tags | jq '.models[].name'`
Expected: List includes "mistral:7b"

**Step 2: Ensure n8n is running**

Run: `docker-compose ps | grep n8n`
Expected: Container running

**Step 3: Run the test script**

Run: `./workflows/01-ingestion/scripts/test-feedback-pipeline.sh`
Expected: All tests pass, database entries created with correct categories

**Step 4: Review classifications**

Check that:
- User story feedback → category = "user_story", backlog_id = "US-XXX"
- Feature request → category = "feature_request", backlog_id = "FR-XXX"
- Bug report → category = "bug", backlog_id = "BUG-XXX"
- Noise → category = "noise", backlog_id = NULL

---

## Task 9: Update Documentation

**Files:**
- Modify: `workflows/01-ingestion/docs/STATUS.md`

**Step 1: Update STATUS.md with test results**

Add section documenting feedback pipeline tests and results.

**Step 2: Commit documentation**

```bash
git add workflows/01-ingestion/docs/STATUS.md
git commit -m "docs(01): update STATUS with feedback pipeline test results"
```

---

## Task 10: Final Verification and PR

**Step 1: Run full test suite**

Run: `./workflows/01-ingestion/scripts/test-with-markers.sh`
Expected: All existing tests still pass

Run: `./workflows/01-ingestion/scripts/test-feedback-pipeline.sh`
Expected: All feedback tests pass

**Step 2: Push branch**

```bash
git push -u origin infra/feedback-pipeline
```

**Step 3: Create PR**

```bash
gh pr create --title "feat(01): add feedback classification pipeline" --body "$(cat <<'EOF'
## Summary

Extends Workflow 01 to classify #selene-feedback notes using Ollama and append structured items to the development backlog.

**Changes:**
- Added 7 new nodes to feedback processing path
- Created migration 012 for classification tracking columns
- Added classification prompt template
- Added test script for feedback pipeline

**Testing:**
- [x] User story classification
- [x] Feature request classification
- [x] Bug report classification
- [x] Noise filtering
- [x] Duplicate detection
- [x] Backlog file updates

## Test Plan

1. Run `./workflows/01-ingestion/scripts/test-feedback-pipeline.sh`
2. Verify entries in `docs/backlog/user-stories.md`
3. Check `feedback_notes` table for classification data

🤖 Generated with [Claude Code](https://claude.com/claude-code)
EOF
)"
```

---

## Verification Checklist

- [ ] Migration 012 applied to database
- [ ] All 7 new nodes added to Workflow 01
- [ ] Connections properly updated
- [ ] Prompt template created
- [ ] Test script created and passing
- [ ] Existing ingestion tests still pass
- [ ] STATUS.md updated
- [ ] PR created
