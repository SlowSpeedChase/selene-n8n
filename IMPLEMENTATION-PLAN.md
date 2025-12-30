# Task Extraction with Classification Implementation Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** Add classification logic (actionable/needs_planning/archive_only) to workflow 07, enabling intelligent routing of notes to Things (actionable only) while flagging planning items for SeleneChat.

**Architecture:** Modify existing workflow 07 to classify notes before task extraction. Add database schema for classification tracking and discussion threads. Use test_run markers throughout for safe testing.

**Tech Stack:** n8n workflows (JSON), SQLite (better-sqlite3), Ollama (mistral:7b), bash scripts for testing

---

## Overview

The existing workflow 07 extracts tasks from ALL notes and sends them to Things. This plan revises it to:

1. **Classify first** - Determine if note is actionable, needs_planning, or archive_only
2. **Route appropriately** - Only actionable notes get task extraction and Things integration
3. **Flag for planning** - needs_planning notes are flagged for SeleneChat (Phase 7.2)
4. **Track everything** - New database fields store classification and planning status

## Task Summary

| Task | Description | Est. Time |
|------|-------------|-----------|
| 1 | Database Schema Migration | 15 min |
| 2 | Classification Prompt Development | 20 min |
| 3 | Workflow Restructure - Add Classification Node | 25 min |
| 4 | Workflow Restructure - Add Routing Logic | 20 min |
| 5 | Update Task Extraction Prompt | 15 min |
| 6 | Workflow Restructure - Update Status Handling | 15 min |
| 7 | Test Script Creation | 20 min |
| 8 | Integration Testing | 30 min |
| 9 | Documentation Updates | 15 min |

**Total Estimated Time:** ~3 hours

---

## Task 1: Database Schema Migration

**Files:**
- Create: `database/migrations/004_add_classification_fields.sql`
- Modify: `database/schema.sql:22-39` (add columns to processed_notes)

**Step 1: Write the migration file**

```sql
-- database/migrations/004_add_classification_fields.sql
-- Phase 7.1: Add classification and planning status fields

-- Add classification field to processed_notes
ALTER TABLE processed_notes ADD COLUMN classification TEXT DEFAULT 'archive_only';
-- Values: 'actionable', 'needs_planning', 'archive_only'

-- Add planning_status field to processed_notes
ALTER TABLE processed_notes ADD COLUMN planning_status TEXT DEFAULT NULL;
-- Values: NULL, 'pending_review', 'in_planning', 'planned', 'archived'

-- Add index for classification queries
CREATE INDEX IF NOT EXISTS idx_processed_notes_classification ON processed_notes(classification);

-- Add index for planning status queries (SeleneChat will query this)
CREATE INDEX IF NOT EXISTS idx_processed_notes_planning_status ON processed_notes(planning_status);

-- Create discussion_threads table for SeleneChat continuations (Phase 7.2 prep)
CREATE TABLE IF NOT EXISTS discussion_threads (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    processed_note_id INTEGER NOT NULL,
    thread_type TEXT NOT NULL,  -- 'planning', 'exploration', 'followup'
    status TEXT DEFAULT 'pending',  -- 'pending', 'active', 'completed', 'archived'
    context TEXT,  -- JSON object with thread context
    created_at DATETIME DEFAULT CURRENT_TIMESTAMP,
    updated_at DATETIME,
    test_run TEXT DEFAULT NULL,
    FOREIGN KEY (processed_note_id) REFERENCES processed_notes(id)
);

CREATE INDEX IF NOT EXISTS idx_discussion_threads_status ON discussion_threads(status);
CREATE INDEX IF NOT EXISTS idx_discussion_threads_note ON discussion_threads(processed_note_id);
CREATE INDEX IF NOT EXISTS idx_discussion_threads_test_run ON discussion_threads(test_run);
```

**Step 2: Run migration**

```bash
sqlite3 data/selene.db < database/migrations/004_add_classification_fields.sql
```

Expected: No errors, tables/columns created

**Step 3: Verify migration**

```bash
sqlite3 data/selene.db ".schema processed_notes"
sqlite3 data/selene.db ".schema discussion_threads"
```

Expected: See new columns and table

**Step 4: Update schema.sql with new structure**

Add the new columns and table to `database/schema.sql` for future fresh installs.

**Step 5: Commit**

```bash
git add database/migrations/004_add_classification_fields.sql database/schema.sql
git commit -m "db: add classification and planning_status fields

- Add classification column to processed_notes (actionable/needs_planning/archive_only)
- Add planning_status column for SeleneChat integration
- Create discussion_threads table for future thread continuation
- Add indexes for query performance"
```

---

## Task 2: Classification Prompt Development

**Files:**
- Create: `workflows/07-task-extraction/prompts/classification-prompt.txt`

**Step 1: Write the classification prompt**

```text
You are a note classification assistant for an ADHD-optimized knowledge system.

Analyze the following note and classify it into ONE of three categories:

CATEGORIES:
1. actionable - Clear, specific task that can be done
   - Contains a clear verb + object
   - Can be completed in a single session
   - No ambiguity about what "done" means
   - Not dependent on decisions not yet made
   - Examples: "Call dentist tomorrow", "Fix login bug", "Email client about deadline"

2. needs_planning - Goal, project idea, or ambiguous intention
   - Expresses a goal or desired outcome
   - Contains multiple potential tasks
   - Requires scoping or breakdown
   - Uses phrases like "want to", "should", "need to figure out"
   - Overwhelm factor would be > 7
   - Examples: "Redo my website", "Figure out vacation plans", "Learn rust programming"

3. archive_only - Thought, reflection, note without action
   - Reflective or exploratory thought
   - No implied action
   - Information capture (quotes, ideas, observations)
   - Emotional processing
   - Examples: "Thinking about attention patterns", "Quote from book", "Observation about team dynamics"

INPUT:
Note Content: {{content}}
Concepts: {{concepts}}
Themes: {{themes}}
Energy Level: {{energy_level}}
Emotional Tone: {{emotional_tone}}
ADHD Markers: {{adhd_markers}}

DECISION RULES:
1. If note has clear verb + specific object AND completion is unambiguous → actionable
2. If note expresses desire/goal OR contains "want to/should/need to figure out" → needs_planning
3. If note is reflective, observational, or captures information → archive_only
4. When in doubt between actionable and needs_planning → needs_planning (safer)
5. When in doubt between needs_planning and archive_only → archive_only (less noise)

OUTPUT FORMAT (JSON only, no explanation):
{
  "classification": "actionable|needs_planning|archive_only",
  "confidence": 0.0-1.0,
  "reasoning": "Brief explanation of classification decision"
}

BEGIN ANALYSIS:
```

**Step 2: Create prompts directory**

```bash
mkdir -p workflows/07-task-extraction/prompts
```

**Step 3: Commit**

```bash
git add workflows/07-task-extraction/prompts/classification-prompt.txt
git commit -m "feat: add classification prompt for note triage

- Three-way classification: actionable/needs_planning/archive_only
- Clear decision rules based on design doc
- JSON output format for workflow parsing"
```

---

## Task 3: Workflow Restructure - Add Classification Node

**Files:**
- Modify: `workflows/07-task-extraction/workflow.json`

**Step 1: Export current workflow**

```bash
./scripts/manage-workflow.sh export 7
```

**Step 2: Add Classification Prompt Builder node**

Insert after "Fetch Note Data" node. Position: [550, 300]

```json
{
  "parameters": {
    "functionCode": "const note = $input.item.json;\n\nconst prompt = `You are a note classification assistant for an ADHD-optimized knowledge system.\n\nAnalyze the following note and classify it into ONE of three categories:\n\nCATEGORIES:\n1. actionable - Clear, specific task that can be done\n   - Contains a clear verb + object\n   - Can be completed in a single session\n   - No ambiguity about what \"done\" means\n   - Not dependent on decisions not yet made\n\n2. needs_planning - Goal, project idea, or ambiguous intention\n   - Expresses a goal or desired outcome\n   - Contains multiple potential tasks\n   - Requires scoping or breakdown\n   - Uses phrases like \"want to\", \"should\", \"need to figure out\"\n\n3. archive_only - Thought, reflection, note without action\n   - Reflective or exploratory thought\n   - No implied action\n   - Information capture (quotes, ideas, observations)\n   - Emotional processing\n\nINPUT:\nNote Content: ${note.content || ''}\nConcepts: ${note.concepts || '[]'}\nThemes: ${note.themes || '[]'}\nEnergy Level: ${note.energy_level || 'unknown'}\nEmotional Tone: ${note.emotional_tone || 'neutral'}\nADHD Markers: ${note.adhd_markers || 'none'}\n\nDECISION RULES:\n1. If note has clear verb + specific object AND completion is unambiguous → actionable\n2. If note expresses desire/goal OR contains \"want to/should/need to figure out\" → needs_planning\n3. If note is reflective, observational, or captures information → archive_only\n4. When in doubt between actionable and needs_planning → needs_planning\n5. When in doubt between needs_planning and archive_only → archive_only\n\nOUTPUT FORMAT (JSON only, no explanation):\n{\n  \"classification\": \"actionable|needs_planning|archive_only\",\n  \"confidence\": 0.0-1.0,\n  \"reasoning\": \"Brief explanation\"\n}\n\nBEGIN ANALYSIS:`;\n\nreturn {\n  json: {\n    ...note,\n    classification_prompt: prompt\n  }\n};"
  },
  "id": "build-classification-prompt",
  "name": "Build Classification Prompt",
  "type": "n8n-nodes-base.function",
  "typeVersion": 1,
  "position": [550, 300]
}
```

**Step 3: Add Ollama Classification node**

Position: [750, 300]

```json
{
  "parameters": {
    "method": "POST",
    "url": "http://host.docker.internal:11434/api/generate",
    "options": {
      "timeout": 30000
    },
    "sendBody": true,
    "bodyParameters": {
      "parameters": [
        {
          "name": "model",
          "value": "=mistral:7b"
        },
        {
          "name": "prompt",
          "value": "={{$json.classification_prompt}}"
        },
        {
          "name": "stream",
          "value": "={{false}}"
        },
        {
          "name": "format",
          "value": "json"
        }
      ]
    }
  },
  "id": "ollama-classify",
  "name": "Ollama Classify Note",
  "type": "n8n-nodes-base.httpRequest",
  "typeVersion": 3,
  "position": [750, 300]
}
```

**Step 4: Add Parse Classification node**

Position: [950, 300]

```json
{
  "parameters": {
    "functionCode": "const response = $input.item.json.response;\nconst noteData = $('Build Classification Prompt').first().json;\n\nconsole.log('[Parse Classification] Ollama response:', response);\n\nlet classification = 'archive_only';\nlet confidence = 0.5;\nlet reasoning = 'Default classification';\n\ntry {\n  const parsed = JSON.parse(response);\n  classification = parsed.classification || 'archive_only';\n  confidence = parsed.confidence || 0.5;\n  reasoning = parsed.reasoning || 'No reasoning provided';\n  \n  // Validate classification value\n  const validValues = ['actionable', 'needs_planning', 'archive_only'];\n  if (!validValues.includes(classification)) {\n    console.warn('[Parse Classification] Invalid classification:', classification);\n    classification = 'archive_only';\n  }\n} catch (e) {\n  console.error('[Parse Classification] Failed to parse:', e);\n}\n\nconsole.log('[Parse Classification] Result:', classification, 'Confidence:', confidence);\n\nreturn {\n  json: {\n    ...noteData,\n    classification: classification,\n    classification_confidence: confidence,\n    classification_reasoning: reasoning\n  }\n};"
  },
  "id": "parse-classification",
  "name": "Parse Classification",
  "type": "n8n-nodes-base.function",
  "typeVersion": 1,
  "position": [950, 300]
}
```

**Step 5: Update connections to flow through classification**

Update `connections` object to route:
- Fetch Note Data → Build Classification Prompt → Ollama Classify Note → Parse Classification

**Step 6: Commit checkpoint**

```bash
git add workflows/07-task-extraction/workflow.json
git commit -m "wip: add classification nodes to workflow 07

- Add Build Classification Prompt node
- Add Ollama Classify Note node
- Add Parse Classification node
- Three-way classification before task extraction"
```

---

## Task 4: Workflow Restructure - Add Routing Logic

**Files:**
- Modify: `workflows/07-task-extraction/workflow.json`

**Step 1: Add Route by Classification node (Switch)**

Position: [1150, 300]

```json
{
  "parameters": {
    "rules": {
      "rules": [
        {
          "value": "actionable",
          "operation": "equals",
          "outputKey": "actionable"
        },
        {
          "value": "needs_planning",
          "operation": "equals",
          "outputKey": "needs_planning"
        }
      ],
      "fallbackOutput": "archive_only"
    },
    "dataType": "string",
    "value": "={{$json.classification}}"
  },
  "id": "route-by-classification",
  "name": "Route by Classification",
  "type": "n8n-nodes-base.switch",
  "typeVersion": 3,
  "position": [1150, 300]
}
```

**Step 2: Add Store Classification node (for all paths)**

Position: [1350, 100] (archive_only path)

```json
{
  "parameters": {
    "functionCode": "const db = require('better-sqlite3')('/selene/data/selene.db');\n\ntry {\n  const rawNoteId = $json.raw_note_id;\n  const classification = $json.classification;\n  const confidence = $json.classification_confidence;\n  \n  // Update processed_notes with classification\n  db.prepare(`\n    UPDATE processed_notes\n    SET classification = ?,\n        planning_status = CASE \n          WHEN ? = 'needs_planning' THEN 'pending_review'\n          ELSE NULL\n        END\n    WHERE raw_note_id = ?\n  `).run(classification, classification, rawNoteId);\n  \n  console.log('[Store Classification] Updated note', rawNoteId, 'as', classification);\n  \n  return {\n    json: {\n      ...$json,\n      classification_stored: true\n    }\n  };\n} finally {\n  db.close();\n}"
  },
  "id": "store-classification",
  "name": "Store Classification",
  "type": "n8n-nodes-base.function",
  "typeVersion": 1,
  "position": [1350, 100]
}
```

**Step 3: Add Flag for Planning node (needs_planning path)**

Position: [1350, 300]

```json
{
  "parameters": {
    "functionCode": "const db = require('better-sqlite3')('/selene/data/selene.db');\n\ntry {\n  const rawNoteId = $json.raw_note_id;\n  const processedNoteId = $json.processed_note_id;\n  \n  // Update classification\n  db.prepare(`\n    UPDATE processed_notes\n    SET classification = 'needs_planning',\n        planning_status = 'pending_review'\n    WHERE raw_note_id = ?\n  `).run(rawNoteId);\n  \n  // Get processed_note_id if not provided\n  let pnId = processedNoteId;\n  if (!pnId) {\n    const row = db.prepare('SELECT id FROM processed_notes WHERE raw_note_id = ?').get(rawNoteId);\n    pnId = row ? row.id : null;\n  }\n  \n  // Create discussion thread for SeleneChat (Phase 7.2 prep)\n  if (pnId) {\n    db.prepare(`\n      INSERT INTO discussion_threads (processed_note_id, thread_type, status, context, test_run)\n      VALUES (?, 'planning', 'pending', ?, ?)\n    `).run(\n      pnId,\n      JSON.stringify({\n        original_content: $json.content,\n        concepts: $json.concepts,\n        themes: $json.themes,\n        classification_reasoning: $json.classification_reasoning\n      }),\n      $json.test_run || null\n    );\n    console.log('[Flag for Planning] Created discussion thread for note', rawNoteId);\n  }\n  \n  return {\n    json: {\n      ...$json,\n      flagged_for_planning: true,\n      planning_status: 'pending_review'\n    }\n  };\n} finally {\n  db.close();\n}"
  },
  "id": "flag-for-planning",
  "name": "Flag for Planning",
  "type": "n8n-nodes-base.function",
  "typeVersion": 1,
  "position": [1350, 300]
}
```

**Step 4: Update connections for routing**

```json
"Parse Classification": {
  "main": [[{ "node": "Route by Classification", "type": "main", "index": 0 }]]
},
"Route by Classification": {
  "main": [
    [{ "node": "Build Prompt", "type": "main", "index": 0 }],
    [{ "node": "Flag for Planning", "type": "main", "index": 0 }],
    [{ "node": "Store Classification", "type": "main", "index": 0 }]
  ]
}
```

**Step 5: Commit checkpoint**

```bash
git add workflows/07-task-extraction/workflow.json
git commit -m "wip: add routing logic to workflow 07

- Add Route by Classification switch node
- Add Store Classification for archive_only path
- Add Flag for Planning for needs_planning path
- Actionable notes continue to task extraction"
```

---

## Task 5: Update Task Extraction Prompt

**Files:**
- Modify: `workflows/07-task-extraction/workflow.json` (Build Prompt node)

**Step 1: Update Build Prompt node**

The existing prompt is good but needs to:
1. Add classification context
2. Emphasize that only clear actionable tasks should be extracted
3. Note has already been classified as actionable

Update the prompt template in "Build Prompt" node:

```javascript
const note = $input.item.json;

// Build prompt - note has already been classified as actionable
const prompt = `You are a task extraction assistant for an ADHD-optimized productivity system.

This note has already been classified as ACTIONABLE, meaning it contains clear, specific tasks.
Extract all actionable tasks from this note.

INPUT:
Note Content: ${note.content || ''}
Energy Level: ${note.energy_level || 'unknown'}
Concepts: ${note.concepts || '[]'}
Themes: ${note.themes || '[]'}
Emotional Tone: ${note.emotional_tone || 'neutral'}
ADHD Markers: ${note.adhd_markers || 'none'}
Classification Reasoning: ${note.classification_reasoning || 'Classified as actionable'}

INSTRUCTIONS:
1. Extract ALL actionable tasks (things the person can DO)
2. Each task should be specific and start with a verb
3. Tasks should be completable in a single session
4. Do NOT extract vague goals - those would be "needs_planning"

For each task, provide:
- task_text: Clear, actionable description (start with verb, <80 characters)
- energy_required: high/medium/low
  * high = creative work, learning, complex decisions, writing
  * medium = routine work, communication, light planning
  * low = organizing, simple responses, filing, sorting
- estimated_minutes: 5, 15, 30, 60, 120, or 240
  * Be realistic, ADHD users often underestimate
  * Add 25% buffer to initial estimates
- task_type: action/decision/research/communication/learning/planning
- context_tags: Array of relevant contexts (max 3)
  * Common: work, personal, home, creative, technical, social, urgent, deadline
- overwhelm_factor: 1-10 (how overwhelming this might feel)
  * 1-3 = Simple, clear, quick
  * 4-6 = Moderate complexity or time
  * 7-8 = Complex but doable
  * 9-10 = Should have been needs_planning

OUTPUT FORMAT (JSON only, no explanation):
[
  {
    "task_text": "Write project proposal draft",
    "energy_required": "high",
    "estimated_minutes": 60,
    "task_type": "action",
    "context_tags": ["work", "writing"],
    "overwhelm_factor": 6
  }
]

If somehow no tasks found: []

BEGIN EXTRACTION:`;

return {
  json: {
    ...note,
    prompt_text: prompt
  }
};
```

**Step 2: Commit**

```bash
git add workflows/07-task-extraction/workflow.json
git commit -m "feat: update task extraction prompt for classified notes

- Add classification context to prompt
- Emphasize note is pre-classified as actionable
- Clearer guidance on task extraction"
```

---

## Task 6: Workflow Restructure - Update Status Handling

**Files:**
- Modify: `workflows/07-task-extraction/workflow.json` (Update Note Status node)

**Step 1: Update Store Task Metadata node**

Add classification to stored metadata:

```javascript
const db = require('better-sqlite3')('/selene/data/selene.db');

try {
  // Get task data from passthrough or direct
  const inputData = $input.item.json;
  let task, rawNoteId, concepts, themes;

  if (inputData.task) {
    task = inputData.task;
    rawNoteId = inputData.raw_note_id || inputData.task.raw_note_id;
    concepts = inputData.concepts || inputData.task.concepts;
    themes = inputData.themes || inputData.task.themes;
  } else if (inputData.passthrough) {
    task = inputData.passthrough.task;
    rawNoteId = inputData.passthrough.raw_note_id;
    concepts = inputData.passthrough.concepts;
    themes = inputData.passthrough.themes;
  } else {
    throw new Error('Task data not found in input');
  }

  const thingsTaskId = $json.task_id || `selene-${Date.now()}-${Math.floor(Math.random() * 1000000)}`;

  // Check if task_metadata table exists, create if not
  const tableExists = db.prepare(`
    SELECT name FROM sqlite_master WHERE type='table' AND name='task_metadata'
  `).get();

  if (!tableExists) {
    db.prepare(`
      CREATE TABLE task_metadata (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        raw_note_id INTEGER NOT NULL,
        things_task_id TEXT,
        energy_required TEXT,
        estimated_minutes INTEGER,
        related_concepts TEXT,
        related_themes TEXT,
        overwhelm_factor INTEGER,
        task_type TEXT,
        context_tags TEXT,
        created_at DATETIME DEFAULT CURRENT_TIMESTAMP,
        test_run TEXT,
        FOREIGN KEY (raw_note_id) REFERENCES raw_notes(id)
      )
    `).run();
  }

  db.prepare(`
    INSERT INTO task_metadata (
      raw_note_id, things_task_id, energy_required, estimated_minutes,
      related_concepts, related_themes, overwhelm_factor, task_type, context_tags, test_run
    ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
  `).run(
    rawNoteId,
    thingsTaskId,
    task.energy_required,
    task.estimated_minutes,
    JSON.stringify(concepts || []),
    JSON.stringify(themes || []),
    task.overwhelm_factor,
    task.task_type,
    JSON.stringify(task.context_tags || []),
    inputData.test_run || null
  );

  return {
    json: {
      raw_note_id: rawNoteId,
      things_task_id: thingsTaskId,
      task_text: task.task_text
    }
  };
} finally {
  db.close();
}
```

**Step 2: Update Update Note Status node**

Update to handle classification:

```javascript
const db = require('better-sqlite3')('/selene/data/selene.db');

try {
  const rawNoteId = $input.first().json.raw_note_id;
  const taskCount = $input.all().length;

  // Update raw_notes
  db.prepare(`
    UPDATE raw_notes
    SET tasks_extracted = 1,
        tasks_extracted_at = CURRENT_TIMESTAMP
    WHERE id = ?
  `).run(rawNoteId);

  // Update processed_notes with classification and status
  const status = taskCount > 0 ? 'tasks_created' : 'no_tasks';
  db.prepare(`
    UPDATE processed_notes
    SET things_integration_status = ?,
        classification = 'actionable'
    WHERE raw_note_id = ?
  `).run(status, rawNoteId);

  return {
    json: {
      success: true,
      raw_note_id: rawNoteId,
      tasks_created: taskCount,
      classification: 'actionable'
    }
  };
} finally {
  db.close();
}
```

**Step 3: Commit**

```bash
git add workflows/07-task-extraction/workflow.json
git commit -m "feat: update status handling for classification

- Store classification in processed_notes
- Add test_run support to task_metadata
- Handle task_metadata table creation"
```

---

## Task 7: Test Script Creation

**Files:**
- Create: `workflows/07-task-extraction/scripts/test-classification.sh`

**Step 1: Write comprehensive test script**

```bash
#!/bin/bash
set -e

cd "$(dirname "$0")/.."

TEST_RUN="test-run-$(date +%Y%m%d-%H%M%S)"
WEBHOOK_URL="http://localhost:5678/webhook/task-extraction"
DB_PATH="../../data/selene.db"

echo "=========================================="
echo "Testing Task Extraction with Classification"
echo "Test Run: $TEST_RUN"
echo "=========================================="

# Helper function to create test note
create_test_note() {
  local content="$1"
  local title="$2"

  # Insert raw note
  sqlite3 "$DB_PATH" "INSERT INTO raw_notes (title, content, content_hash, test_run, created_at) VALUES ('$title', '$content', 'hash-$RANDOM', '$TEST_RUN', datetime('now'));"
  local raw_id=$(sqlite3 "$DB_PATH" "SELECT id FROM raw_notes WHERE test_run = '$TEST_RUN' ORDER BY id DESC LIMIT 1;")

  # Insert processed note
  sqlite3 "$DB_PATH" "INSERT INTO processed_notes (raw_note_id, concepts, primary_theme) VALUES ($raw_id, '[\"test-concept\"]', 'test-theme');"

  echo "$raw_id"
}

echo ""
echo "=== Test 1: Actionable Note ==="
echo "Content: 'Call dentist tomorrow at 3pm to reschedule appointment'"
NOTE_ID_1=$(create_test_note "Call dentist tomorrow at 3pm to reschedule appointment" "Dentist Call")
echo "Created test note ID: $NOTE_ID_1"

curl -s -X POST "$WEBHOOK_URL" \
  -H "Content-Type: application/json" \
  -d "{\"raw_note_id\": $NOTE_ID_1, \"test_run\": \"$TEST_RUN\"}"

echo ""
sleep 5

CLASSIFICATION_1=$(sqlite3 "$DB_PATH" "SELECT classification FROM processed_notes WHERE raw_note_id = $NOTE_ID_1;")
echo "Classification: $CLASSIFICATION_1"
if [ "$CLASSIFICATION_1" = "actionable" ]; then
  echo "PASS: Correctly classified as actionable"
else
  echo "FAIL: Expected 'actionable', got '$CLASSIFICATION_1'"
fi

echo ""
echo "=== Test 2: Needs Planning Note ==="
echo "Content: 'I want to redesign my personal website. Need to figure out hosting, maybe add a blog...'"
NOTE_ID_2=$(create_test_note "I want to redesign my personal website. Need to figure out hosting, maybe add a blog, portfolio section" "Website Redesign")
echo "Created test note ID: $NOTE_ID_2"

curl -s -X POST "$WEBHOOK_URL" \
  -H "Content-Type: application/json" \
  -d "{\"raw_note_id\": $NOTE_ID_2, \"test_run\": \"$TEST_RUN\"}"

echo ""
sleep 5

CLASSIFICATION_2=$(sqlite3 "$DB_PATH" "SELECT classification FROM processed_notes WHERE raw_note_id = $NOTE_ID_2;")
PLANNING_STATUS=$(sqlite3 "$DB_PATH" "SELECT planning_status FROM processed_notes WHERE raw_note_id = $NOTE_ID_2;")
THREAD_COUNT=$(sqlite3 "$DB_PATH" "SELECT COUNT(*) FROM discussion_threads WHERE test_run = '$TEST_RUN';")
echo "Classification: $CLASSIFICATION_2"
echo "Planning Status: $PLANNING_STATUS"
echo "Discussion Threads: $THREAD_COUNT"
if [ "$CLASSIFICATION_2" = "needs_planning" ]; then
  echo "PASS: Correctly classified as needs_planning"
else
  echo "FAIL: Expected 'needs_planning', got '$CLASSIFICATION_2'"
fi

echo ""
echo "=== Test 3: Archive Only Note ==="
echo "Content: 'Thinking about how my attention works differently in mornings versus afternoons'"
NOTE_ID_3=$(create_test_note "Thinking about how my attention works differently in mornings versus afternoons. Interesting pattern." "Attention Patterns")
echo "Created test note ID: $NOTE_ID_3"

curl -s -X POST "$WEBHOOK_URL" \
  -H "Content-Type: application/json" \
  -d "{\"raw_note_id\": $NOTE_ID_3, \"test_run\": \"$TEST_RUN\"}"

echo ""
sleep 5

CLASSIFICATION_3=$(sqlite3 "$DB_PATH" "SELECT classification FROM processed_notes WHERE raw_note_id = $NOTE_ID_3;")
echo "Classification: $CLASSIFICATION_3"
if [ "$CLASSIFICATION_3" = "archive_only" ]; then
  echo "PASS: Correctly classified as archive_only"
else
  echo "FAIL: Expected 'archive_only', got '$CLASSIFICATION_3'"
fi

echo ""
echo "=========================================="
echo "=== Test Summary ==="
echo "=========================================="

ACTIONABLE_COUNT=$(sqlite3 "$DB_PATH" "SELECT COUNT(*) FROM processed_notes WHERE test_run = '$TEST_RUN' AND classification = 'actionable';")
PLANNING_COUNT=$(sqlite3 "$DB_PATH" "SELECT COUNT(*) FROM processed_notes WHERE test_run = '$TEST_RUN' AND classification = 'needs_planning';")
ARCHIVE_COUNT=$(sqlite3 "$DB_PATH" "SELECT COUNT(*) FROM processed_notes WHERE test_run = '$TEST_RUN' AND classification = 'archive_only';")
TASK_COUNT=$(sqlite3 "$DB_PATH" "SELECT COUNT(*) FROM task_metadata WHERE test_run = '$TEST_RUN';")

echo "Actionable notes: $ACTIONABLE_COUNT (expected: 1)"
echo "Needs Planning notes: $PLANNING_COUNT (expected: 1)"
echo "Archive Only notes: $ARCHIVE_COUNT (expected: 1)"
echo "Tasks created: $TASK_COUNT (expected: 1+)"
echo "Discussion threads: $THREAD_COUNT (expected: 1)"

echo ""
read -p "Cleanup test data? (y/n) " -n 1 -r
echo ""
if [[ $REPLY =~ ^[Yy]$ ]]; then
  echo "Cleaning up test data..."
  sqlite3 "$DB_PATH" "DELETE FROM task_metadata WHERE test_run = '$TEST_RUN';"
  sqlite3 "$DB_PATH" "DELETE FROM discussion_threads WHERE test_run = '$TEST_RUN';"
  sqlite3 "$DB_PATH" "DELETE FROM processed_notes WHERE raw_note_id IN (SELECT id FROM raw_notes WHERE test_run = '$TEST_RUN');"
  sqlite3 "$DB_PATH" "DELETE FROM raw_notes WHERE test_run = '$TEST_RUN';"
  echo "Cleanup complete."
fi
```

**Step 2: Make executable**

```bash
chmod +x workflows/07-task-extraction/scripts/test-classification.sh
```

**Step 3: Create scripts directory if needed**

```bash
mkdir -p workflows/07-task-extraction/scripts
```

**Step 4: Commit**

```bash
git add workflows/07-task-extraction/scripts/test-classification.sh
git commit -m "test: add classification test script

- Test all three classification paths
- Verify database updates
- Verify discussion thread creation
- Automatic cleanup option"
```

---

## Task 8: Integration Testing

**Files:**
- None (manual testing procedure)

**Step 1: Ensure Docker is running**

```bash
docker-compose up -d
docker-compose logs -f n8n
```

**Step 2: Apply database migration**

```bash
sqlite3 data/selene.db < database/migrations/004_add_classification_fields.sql
```

**Step 3: Update workflow in n8n**

```bash
./scripts/manage-workflow.sh update 7 workflows/07-task-extraction/workflow.json
```

**Step 4: Run classification tests**

```bash
./workflows/07-task-extraction/scripts/test-classification.sh
```

Expected results:
- Test 1 (Actionable): classification = 'actionable', task created in Things
- Test 2 (Needs Planning): classification = 'needs_planning', discussion thread created
- Test 3 (Archive Only): classification = 'archive_only', no task or thread

**Step 5: Verify in database**

```bash
# Check classifications
sqlite3 data/selene.db "SELECT id, classification, planning_status FROM processed_notes WHERE test_run LIKE 'test-run-%' ORDER BY id DESC LIMIT 5;"

# Check discussion threads
sqlite3 data/selene.db "SELECT * FROM discussion_threads ORDER BY id DESC LIMIT 5;"

# Check task metadata
sqlite3 data/selene.db "SELECT * FROM task_metadata ORDER BY id DESC LIMIT 5;"
```

**Step 6: Test edge cases**

```bash
# Test with missing content
curl -X POST http://localhost:5678/webhook/task-extraction \
  -H "Content-Type: application/json" \
  -d '{"raw_note_id": 9999}'

# Test with empty content (should be archive_only)
# Create note with empty content and test
```

**Step 7: Cleanup test data**

```bash
./scripts/cleanup-tests.sh --list
./scripts/cleanup-tests.sh <test-run-id>
```

---

## Task 9: Documentation Updates

**Files:**
- Modify: `workflows/07-task-extraction/docs/STATUS.md`
- Modify: `workflows/07-task-extraction/README.md`
- Modify: `.claude/PROJECT-STATUS.md`

**Step 1: Update STATUS.md**

```markdown
# 07-Task-Extraction Workflow Status

**Last Updated:** 2025-12-30
**Test Results:** X/X passing

---

## Current Status

**Production Ready:** Yes (with classification)

**Test Coverage:**
- [x] Actionable note classification
- [x] Needs Planning note classification
- [x] Archive Only note classification
- [x] Task extraction from actionable notes
- [x] Discussion thread creation for planning items
- [x] Database updates for all paths
- [ ] Edge cases (empty content, missing data)

---

## Test Results

### Latest Run (2025-12-30)

**Test Suite:** `./scripts/test-classification.sh`

| Test Case | Status | Notes |
|-----------|--------|-------|
| Actionable classification | PASS | Correctly routes to task extraction |
| Needs Planning classification | PASS | Creates discussion thread |
| Archive Only classification | PASS | Stores classification only |
| Task creation | PASS | Tasks sent to Things |
| Database updates | PASS | All fields populated |

**Overall:** X/X critical tests passing

---

## Recent Changes

### 2025-12-30 - Phase 7.1 Classification
- Added three-way classification (actionable/needs_planning/archive_only)
- Added routing logic to workflow
- Added discussion_threads table for SeleneChat prep
- Updated task extraction to only process actionable notes
- Added comprehensive test suite

### Previous
- Initial task extraction implementation
- Things integration
```

**Step 2: Update README.md**

Add classification section:

```markdown
## Classification Logic

Before task extraction, notes are classified into three categories:

| Classification | Description | Routing |
|----------------|-------------|---------|
| `actionable` | Clear, specific task | Task extraction → Things |
| `needs_planning` | Goal/project needing breakdown | Flag for SeleneChat |
| `archive_only` | Thought/reflection | Store only |

### Testing

```bash
# Run classification tests
./scripts/test-classification.sh
```
```

**Step 3: Update PROJECT-STATUS.md**

Update Phase 7.1 status to in progress/complete.

**Step 4: Commit**

```bash
git add workflows/07-task-extraction/docs/STATUS.md
git add workflows/07-task-extraction/README.md
git add .claude/PROJECT-STATUS.md
git commit -m "docs: update documentation for Phase 7.1 classification

- Update STATUS.md with test results
- Add classification section to README
- Update PROJECT-STATUS.md"
```

---

## Verification Checklist

Before marking Phase 7.1 complete:

- [ ] Database migration applied successfully
- [ ] All three classification paths tested
- [ ] Actionable notes create tasks in Things
- [ ] Needs Planning notes create discussion threads
- [ ] Archive Only notes store classification without tasks
- [ ] Test cleanup works properly
- [ ] Documentation updated
- [ ] All commits made with descriptive messages

---

## Rollback Plan

If issues arise:

1. **Database:** Classification fields are nullable, no data loss
2. **Workflow:** Export current workflow before changes, restore if needed
3. **Things:** Tasks created during testing can be deleted manually

```bash
# Restore workflow from backup
./scripts/manage-workflow.sh list-backups 7
./scripts/manage-workflow.sh restore 7 <backup-timestamp>
```

---

## Next Steps (Phase 7.2)

After Phase 7.1 complete:

1. SeleneChat queries `planning_status = 'pending_review'` items
2. "Threads to Continue" UI in SeleneChat
3. Planning conversation with local AI
4. Generate tasks from planning → Things

See: `docs/plans/2025-12-30-task-extraction-planning-design.md` (Phase 7.2 section)
