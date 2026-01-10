# Workflow Development Context

**Claude: Before ANY workflow action, read the relevant PROCEDURE below and follow it step-by-step.**

**Related Context:**
- `@.claude/OPERATIONS.md` - Commands to manage workflows
- `@.claude/DEVELOPMENT.md` - Architecture and design decisions
- `@scripts/CLAUDE.md` - Script utilities (manage-workflow.sh)

---

## Table of Contents

1. [PROCEDURES (MANDATORY)](#procedures-mandatory)
   - [Create New Workflow](#procedure-create-new-workflow)
   - [Modify Existing Workflow](#procedure-modify-existing-workflow)
   - [Delete Workflow](#procedure-delete-workflow)
2. [Quick Reference](#quick-reference)
3. [Reference Material](#reference-material)
   - [Workflow JSON Structure](#workflow-json-structure)
   - [Node Naming Conventions](#node-naming-conventions)
   - [Error Handling Patterns](#error-handling-patterns)
   - [Database Integration Patterns](#database-integration-patterns)
   - [Testing Requirements](#testing-requirements)
   - [Common Workflow Patterns](#common-workflow-patterns)

---

# PROCEDURES (MANDATORY)

**These procedures are not optional. Follow step-by-step. Do not skip steps.**

---

## PROCEDURE: Create New Workflow

**When to use:** User asks to create, add, or build a new workflow.

### Pre-flight Checks
1. Confirm the workflow doesn't already exist: `ls workflows/`
2. Determine the next workflow number (e.g., if 08 exists, use 09)
3. Confirm the workflow name with user if ambiguous

### Step-by-Step Process

**Step 1: Copy Template**
```bash
cp -r workflows/_template workflows/XX-new-name
```
Replace `XX` with the number and `new-name` with descriptive kebab-case name.

**Step 2: Rename Template Files**
```bash
mv workflows/XX-new-name/workflow.template.json workflows/XX-new-name/workflow.json
```

**Step 3: Edit workflow.json**
- Update the `"name"` field to match workflow purpose
- Add/modify nodes for the workflow's functionality
- Set up connections between nodes
- Configure webhook path if needed (use `api/descriptive-name`)

**Step 4: Update Documentation**
- Edit `README.md` - describe what the workflow does
- Edit `docs/STATUS.md` - set initial status to "In Development"

**Step 5: Import to n8n**
```bash
./scripts/manage-workflow.sh import /workflows/XX-new-name/workflow.json
```

**Step 6: Get the Workflow ID**
```bash
./scripts/manage-workflow.sh list
```
Note the ID assigned to your new workflow.

**Step 7: Test the Workflow**
```bash
./workflows/XX-new-name/scripts/test-with-markers.sh
```

**Step 8: Update STATUS.md**
Record test results and mark as "Ready" or note issues.

**Step 9: Commit**
```bash
git add workflows/XX-new-name/
git commit -m "feat(XX): add new-name workflow

- Brief description of what it does
- Key features"
```

### Verification Checklist
- [ ] Workflow appears in `./scripts/manage-workflow.sh list`
- [ ] Test script runs without errors
- [ ] STATUS.md reflects current state
- [ ] All files committed to git

---

## PROCEDURE: Modify Existing Workflow

**When to use:** User asks to edit, fix, debug, update, add nodes to, or change an existing workflow.

### Pre-flight Checks
1. Identify the workflow by name or number
2. Get the workflow ID: `./scripts/manage-workflow.sh list`
3. Confirm n8n is running: `curl -s http://localhost:5678/healthz`

### Step-by-Step Process

**Step 1: Export Current Version (Creates Backup)**
```bash
./scripts/manage-workflow.sh export <workflow-id>
```
This creates a timestamped backup automatically.

**Step 2: Read the Current workflow.json**
Use the Read tool to examine:
```
workflows/XX-name/workflow.json
```
Understand the current structure before making changes.

**Step 3: Edit the JSON File**
Use the Edit tool to make changes to `workflows/XX-name/workflow.json`.

Common modifications:
- Add new node (add to `nodes` array, update `connections`)
- Change node parameters (find node by name, edit `parameters`)
- Fix bug (locate problematic node, correct the logic)
- Update connections (modify `connections` object)

**Step 4: Update Workflow in n8n**
```bash
./scripts/manage-workflow.sh update <workflow-id> /workflows/XX-name/workflow.json
```

**Step 5: Test the Workflow**
```bash
./workflows/XX-name/scripts/test-with-markers.sh
```

**Step 6: Update Documentation**
Edit `workflows/XX-name/docs/STATUS.md`:
- Record test results
- Note what changed and why
- Update date

**Step 7: Commit Changes**
```bash
git add workflows/XX-name/workflow.json workflows/XX-name/docs/STATUS.md
git commit -m "fix(XX): description of change

- What was changed
- Why it was changed"
```

### If Tests Fail
1. Do NOT commit
2. Read error output carefully
3. Return to Step 3 and fix
4. Repeat Steps 4-6

### Verification Checklist
- [ ] Backup exists (check for timestamped file)
- [ ] Tests pass
- [ ] STATUS.md updated with today's date
- [ ] Changes committed to git

---

## PROCEDURE: Delete Workflow

**When to use:** User asks to remove, delete, retire, or decommission a workflow.

### Pre-flight Checks
1. Confirm which workflow to delete (get explicit confirmation from user)
2. Get the workflow ID: `./scripts/manage-workflow.sh list`
3. Check if workflow is currently active: `./scripts/manage-workflow.sh show <id>`

### Step-by-Step Process

**Step 1: Confirm with User**
Ask: "You want to delete workflow XX-name (ID: N). This will:
- Deactivate it in n8n
- Archive the files to `workflows/_archived/`
- Remove it from active workflows

Proceed? (yes/no)"

**Do NOT proceed without explicit confirmation.**

**Step 2: Export Final Version**
```bash
./scripts/manage-workflow.sh export <workflow-id>
```
Ensures we have the latest state before archiving.

**Step 3: Deactivate in n8n**
```bash
export N8N_USER_FOLDER=/Users/chaseeasterling/selene-n8n/.n8n-local
n8n update:workflow --id=<workflow-id> --active=false
```

**Step 4: Create Archive Directory (if needed)**
```bash
mkdir -p workflows/_archived
```

**Step 5: Move to Archive**
```bash
mv workflows/XX-name workflows/_archived/XX-name
```

**Step 6: Add Archive Note**
Create `workflows/_archived/XX-name/ARCHIVED.md`:
```markdown
# Archived: XX-name

**Archived Date:** YYYY-MM-DD
**Reason:** [User's reason or "User requested deletion"]
**Last Workflow ID:** N

## Notes
- Any relevant context about why this was archived
- What replaced it (if applicable)
```

**Step 7: Delete from n8n (Optional)**
Only if user explicitly wants it removed from n8n entirely:
```bash
export N8N_USER_FOLDER=/Users/chaseeasterling/selene-n8n/.n8n-local
n8n delete:workflow --id=<workflow-id>
```
Skip this step if user might want to restore later.

**Step 8: Commit**
```bash
git add workflows/_archived/XX-name/
git rm -r workflows/XX-name/  # Stages the removal
git commit -m "chore(XX): archive XX-name workflow

- Reason: [reason]
- Archived to workflows/_archived/"
```

### Verification Checklist
- [ ] User explicitly confirmed deletion
- [ ] Final export completed
- [ ] Workflow deactivated in n8n
- [ ] Files moved to `_archived/` (not deleted)
- [ ] ARCHIVED.md created with context
- [ ] Changes committed to git

---

# Quick Reference

| Action | Command |
|--------|---------|
| List workflows | `./scripts/manage-workflow.sh list` |
| Export workflow | `./scripts/manage-workflow.sh export <id>` |
| Update workflow | `./scripts/manage-workflow.sh update <id> <file>` |
| Import new | `./scripts/manage-workflow.sh import <file>` |
| Show workflow | `./scripts/manage-workflow.sh show <id>` |
| Test workflow | `./workflows/XX-name/scripts/test-with-markers.sh` |
| Cleanup tests | `./scripts/cleanup-tests.sh <test-run-id>` |

---

# Reference Material

The sections below provide reference information for workflow development. Consult these when implementing the procedures above.

---

## Workflow JSON Structure

### Top-Level Properties

```json
{
  "name": "01-Ingestion Workflow",
  "nodes": [...],
  "connections": {...},
  "settings": {...},
  "staticData": null,
  "tags": [],
  "triggerCount": 1,
  "updatedAt": "2025-11-27T10:00:00.000Z"
}
```

### Node Structure

```json
{
  "parameters": {
    // Node-specific configuration
  },
  "id": "unique-uuid",
  "name": "Verb + Object Format",
  "type": "n8n-nodes-base.Function",
  "typeVersion": 1,
  "position": [x, y],
  "onError": "continueErrorOutput"  // Error handling
}
```

### Connection Structure

```json
{
  "Node Name": {
    "main": [
      [
        {
          "node": "Next Node",
          "type": "main",
          "index": 0
        }
      ]
    ]
  }
}
```

---

## Node Naming Conventions

### Format: [Verb] + [Object]

**Good Examples:**
- "Parse Note Data"
- "Check for Duplicate"
- "Insert Raw Note"
- "Extract Concepts"
- "Send to Ollama"
- "Update Note Status"
- "Log Error Details"

**Bad Examples:**
- "Function" (what does it do?)
- "Main Logic" (too vague)
- "Process" (verb needs object)
- "Node 1" (meaningless)

**Why:** ADHD brains scan visually. Clear names reduce cognitive load when debugging.

### Verb Categories

**Data Operations:** Parse, Extract, Transform, Format, Validate

**Database Operations:** Insert, Update, Delete, Query, Check

**External Services:** Send, Receive, Fetch, Upload, Download

**Control Flow:** Route, Filter, Merge, Split, Aggregate

**Error Handling:** Log, Catch, Handle, Retry, Notify

---

## Error Handling Patterns

### Pattern 1: Error Output on Every Node

```json
{
  "parameters": {...},
  "onError": "continueErrorOutput"
}
```

**Benefit:** Error path can handle failures without stopping workflow.

### Pattern 2: Dedicated Error Handler

**Structure:**
```
[Any Node] → [Success Path] → ...
     ↓
[Error Output] → [Log Error] → [Update Status to Failed] → [Stop]
```

**Log Error Node (Function):**

```javascript
const error = $input.item.json.error || 'Unknown error';
const context = $input.item.json;

console.error('Workflow Error:', {
  error: error,
  node: context.node,
  timestamp: new Date().toISOString(),
  data: context
});

return {
  json: {
    error: error,
    logged_at: new Date().toISOString()
  }
};
```

### Pattern 3: Retry Logic

**For transient failures (network, timeouts):**

```javascript
const maxRetries = 3;
const retryCount = $json.retry_count || 0;

if (retryCount < maxRetries) {
  return {
    json: {
      ...$json,
      retry_count: retryCount + 1
    }
  };
} else {
  throw new Error('Max retries exceeded');
}
```

---

## Database Integration Patterns

### Pattern 1: Test-Aware Database Access (REQUIRED)

**All Function nodes that access the database MUST use this pattern:**

```javascript
const Database = require('better-sqlite3');

// Check for test mode from incoming data
const useTestDb = $json.use_test_db || false;

// Select database path based on test flag
const dbPath = useTestDb
  ? process.env.SELENE_TEST_DB_PATH
  : process.env.SELENE_DB_PATH;

const db = new Database(dbPath);

try {
  const result = db.prepare('SELECT * FROM raw_notes WHERE id = ?').get($json.id);
  return {
    json: {
      ...result,
      use_test_db: useTestDb  // Propagate flag to downstream nodes
    }
  };
} catch (error) {
  console.error('Database error:', error);
  throw error;
} finally {
  db.close();  // CRITICAL: Always close
}
```

**Why:** Production data lives at `~/selene-data/` (outside repo), test data at `./data-test/`. This prevents Claude Code from accessing production notes during testing.

### Pattern 2: Parameterized Queries (Prevent SQL Injection)

**Good:**
```javascript
db.prepare('SELECT * FROM raw_notes WHERE id = ?').get($json.id);
db.prepare('INSERT INTO raw_notes (title, content) VALUES (?, ?)').run($json.title, $json.content);
```

**Bad (SQL Injection Risk):**
```javascript
// NEVER DO THIS
db.prepare(`SELECT * FROM raw_notes WHERE id = ${$json.id}`).get();
```

### Pattern 3: Transaction for Multi-Step Operations

```javascript
const Database = require('better-sqlite3');

// Test-aware database path selection
const useTestDb = $json.use_test_db || false;
const dbPath = useTestDb
  ? process.env.SELENE_TEST_DB_PATH
  : process.env.SELENE_DB_PATH;

const db = new Database(dbPath);

const transaction = db.transaction(() => {
  const rawNoteResult = db.prepare(`
    INSERT INTO raw_notes (title, content, status)
    VALUES (?, ?, 'pending')
  `).run($json.title, $json.content);

  const rawNoteId = rawNoteResult.lastInsertRowid;

  db.prepare(`
    INSERT INTO processed_notes (raw_note_id, concepts)
    VALUES (?, ?)
  `).run(rawNoteId, JSON.stringify($json.concepts));

  return rawNoteId;
});

try {
  const noteId = transaction();
  db.close();
  return {json: {id: noteId, success: true, use_test_db: useTestDb}};
} catch (error) {
  db.close();
  throw error;
}
```

---

## Testing Requirements

### Every Workflow Must Have

**1. Test Script:** `workflows/XX-name/scripts/test-with-markers.sh`

**2. Test Cases Coverage:**

Minimum required:
- Success path (normal operation)
- Missing required fields
- Invalid data format
- Duplicate detection (if applicable)
- Database constraints

**3. STATUS.md:** `workflows/XX-name/docs/STATUS.md`

Must contain:
- Last updated date
- Test results table
- Known issues
- Change log

---

## Common Workflow Patterns

### Pattern 1: Webhook Trigger

```json
{
  "parameters": {
    "path": "api/drafts",
    "responseMode": "onReceived",
    "options": {}
  },
  "name": "Webhook Trigger",
  "type": "n8n-nodes-base.Webhook"
}
```

**Options:**
- `responseMode: "onReceived"` - Return immediately, process async
- `responseMode: "lastNode"` - Wait for workflow completion

### Pattern 2: Schedule Trigger

```json
{
  "parameters": {
    "rule": {
      "interval": [
        {
          "field": "seconds",
          "secondsInterval": 30
        }
      ]
    }
  },
  "name": "Schedule Trigger",
  "type": "n8n-nodes-base.Schedule"
}
```

### Pattern 3: Conditional Routing (IF Node)

```json
{
  "parameters": {
    "conditions": {
      "string": [
        {
          "value1": "={{$json.status}}",
          "operation": "equals",
          "value2": "pending"
        }
      ]
    }
  },
  "name": "Check Status",
  "type": "n8n-nodes-base.If"
}
```

**Common mistake:** Using Switch node with `notExists` for null checks (doesn't work). Use IF node with explicit null check.

### Pattern 4: Function Node (JavaScript)

**Always include error handling:**

```javascript
try {
  const result = processData($json);
  return {json: result};
} catch (error) {
  console.error('Function error:', error);
  return {
    json: {
      error: error.message,
      input: $json
    }
  };
}
```

**Available globals:**
- `$json` - Current item data
- `$input` - All input items
- `$env` - Environment variables
- `require()` - Node.js modules (whitelisted)

---

## Workflow Directory Structure

**Standard structure for each workflow:**

```
workflows/XX-name/
├── workflow.json          # Main n8n workflow (source of truth)
├── README.md             # Quick start guide
├── docs/
│   ├── STATUS.md         # Test results and current state
│   ├── SETUP.md          # Configuration instructions
│   └── REFERENCE.md      # Technical details
├── scripts/
│   ├── test-with-markers.sh   # Automated test suite
│   └── cleanup-tests.sh       # Test data cleanup (optional)
└── tests/                # Test data/fixtures (optional)
```

**Why this structure:**
- `workflow.json` - Version controlled, single source of truth
- `README.md` - Quick orientation
- `STATUS.md` - Current state visible
- `test-with-markers.sh` - Automated testing

---

## Related Context Files

- **`@.claude/OPERATIONS.md`** - Commands to execute workflows
- **`@.claude/DEVELOPMENT.md`** - Architecture and design patterns
- **`@scripts/CLAUDE.md`** - Script utilities (manage-workflow.sh)
- **`@.claude/PROJECT-STATUS.md`** - Current workflow status
