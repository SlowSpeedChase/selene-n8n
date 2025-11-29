# Workflow Development Context

**Purpose:** n8n workflow implementation patterns, testing requirements, and modification procedures. Read this when working with any workflow.

**Related Context:**
- `@.claude/OPERATIONS.md` - Commands to manage workflows
- `@.claude/DEVELOPMENT.md` - Architecture and design decisions
- `@scripts/CLAUDE.md` - Script utilities (manage-workflow.sh)

---

## Table of Contents

1. [CRITICAL RULE: CLI-Only Workflow Modifications](#critical-rule-cli-only-workflow-modifications)
2. [Workflow Modification Workflow](#workflow-modification-workflow)
3. [Workflow JSON Structure](#workflow-json-structure)
4. [Node Naming Conventions](#node-naming-conventions)
5. [Error Handling Patterns](#error-handling-patterns)
6. [Database Integration Patterns](#database-integration-patterns)
7. [Testing Requirements](#testing-requirements)
8. [Documentation Requirements](#documentation-requirements)
9. [Common Workflow Patterns](#common-workflow-patterns)
10. [Integration Testing](#integration-testing)
11. [Performance Optimization](#performance-optimization)
12. [Workflow Directory Structure](#workflow-directory-structure)
13. [Related Context Files](#related-context-files)

---

## CRITICAL RULE: CLI-Only Workflow Modifications

**ALWAYS use command line tools to modify workflows. NEVER edit in n8n UI without exporting to JSON.**

**Why:**
- UI changes don't persist in git
- JSON files are source of truth
- CLI workflow ensures testing and documentation
- Version control requires committed JSON files

**See:** `@.claude/OPERATIONS.md` (Workflow Modification Procedure)

---

## Workflow Modification Workflow

### Standard Process (6 Steps)

**Step 1: Export Current Version**

```bash
./scripts/manage-workflow.sh export <workflow-id>
```

Creates timestamped backup automatically.

**Step 2: Edit JSON File**

```bash
# Use Read/Edit tools on:
workflows/XX-name/workflow.json
```

**Common modifications:**
- Add new node
- Change node parameters
- Modify connections
- Update error handling

**Step 3: Import Updated Version**

```bash
./scripts/manage-workflow.sh update <workflow-id> /workflows/XX-name/workflow.json
```

**Step 4: Test Workflow**

```bash
cd workflows/XX-name
./scripts/test-with-markers.sh
```

**Step 5: Update Documentation**

```bash
# REQUIRED updates:
workflows/XX-name/docs/STATUS.md    # Test results
workflows/XX-name/README.md         # If interface changed
.claude/PROJECT-STATUS.md           # If workflow complete
```

**Step 6: Commit Changes**

```bash
git add workflows/XX-name/workflow.json
git add workflows/XX-name/docs/STATUS.md
git commit -m "workflow: description of changes"
```

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
- ✅ "Parse Note Data"
- ✅ "Check for Duplicate"
- ✅ "Insert Raw Note"
- ✅ "Extract Concepts"
- ✅ "Send to Ollama"
- ✅ "Update Note Status"
- ✅ "Log Error Details"

**Bad Examples:**
- ❌ "Function" (what does it do?)
- ❌ "Main Logic" (too vague)
- ❌ "Process" (verb needs object)
- ❌ "Node 1" (meaningless)
- ❌ "TODO" (not descriptive)

**Why:** ADHD brains scan visually. Clear names reduce cognitive load when debugging flow.

### Verb Categories

**Data Operations:**
- Parse, Extract, Transform, Format, Validate

**Database Operations:**
- Insert, Update, Delete, Query, Check

**External Services:**
- Send, Receive, Fetch, Upload, Download

**Control Flow:**
- Route, Filter, Merge, Split, Aggregate

**Error Handling:**
- Log, Catch, Handle, Retry, Notify

---

## Error Handling Patterns

### Pattern 1: Error Output on Every Node

**Configuration:**

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

**Update Status Node (SQLite):**

```javascript
const Database = require('better-sqlite3');
const db = new Database('/selene/data/selene.db');

const noteId = $json.raw_note_id || $json.id;

db.prepare(`
  UPDATE raw_notes
  SET status = 'failed',
      error_message = ?
  WHERE id = ?
`).run($json.error, noteId);

db.close();

return {json: $json};
```

### Pattern 3: Retry Logic

**For transient failures (network, timeouts):**

```javascript
// Retry logic in Function node
const maxRetries = 3;
const retryCount = $json.retry_count || 0;

if (retryCount < maxRetries) {
  // Increment retry counter and try again
  return {
    json: {
      ...$json,
      retry_count: retryCount + 1
    }
  };
} else {
  // Max retries reached - fail permanently
  throw new Error('Max retries exceeded');
}
```

**Connect back to original operation for retry.**

---

## Database Integration Patterns

### Pattern 1: better-sqlite3 in Function Nodes

**Always follow this structure:**

```javascript
const Database = require('better-sqlite3');
const db = new Database('/selene/data/selene.db');

try {
  // Database operations here
  const result = db.prepare('SELECT * FROM raw_notes WHERE id = ?').get($json.id);

  return {json: result};

} catch (error) {
  console.error('Database error:', error);
  throw error;
} finally {
  // CRITICAL: Always close connection (prevents database locks)
  db.close();
}
```

**Why try/finally:**
- Ensures connection closes even on error
- Prevents database locks
- Clean resource management

### Pattern 2: Parameterized Queries (Prevent SQL Injection)

**Good (Parameterized):**

```javascript
db.prepare('SELECT * FROM raw_notes WHERE id = ?').get($json.id);
db.prepare('INSERT INTO raw_notes (title, content) VALUES (?, ?)').run($json.title, $json.content);
```

**Bad (String Concatenation - SQL Injection Risk):**

```javascript
// NEVER DO THIS
db.prepare(`SELECT * FROM raw_notes WHERE id = ${$json.id}`).get();
db.prepare(`INSERT INTO raw_notes (title) VALUES ('${$json.title}')`).run();
```

### Pattern 3: Transaction for Multi-Step Operations

**Use transactions when:**
- Multiple related inserts/updates
- Need atomicity (all or nothing)
- Rollback on error

**Example:**

```javascript
const Database = require('better-sqlite3');
const db = new Database('/selene/data/selene.db');

// Define transaction (runs all or nothing)
const transaction = db.transaction(() => {
  // Step 1: Insert raw note
  const rawNoteResult = db.prepare(`
    INSERT INTO raw_notes (title, content, status)
    VALUES (?, ?, 'pending')
  `).run($json.title, $json.content);

  const rawNoteId = rawNoteResult.lastInsertRowid;

  // Step 2: Insert processed note
  db.prepare(`
    INSERT INTO processed_notes (raw_note_id, concepts)
    VALUES (?, ?)
  `).run(rawNoteId, JSON.stringify($json.concepts));

  return rawNoteId;
});

try {
  const noteId = transaction();
  db.close();
  return {json: {id: noteId, success: true}};
} catch (error) {
  db.close();
  throw error;
}
```

**Benefits:**
- Atomic: Both inserts succeed or both fail
- Rollback: Error in step 2 undoes step 1
- Performance: Single write to disk

### Pattern 4: Handling NULL vs Undefined

**Problem:** SQLite NULL vs JavaScript undefined/null

**Solution: Explicit null checks**

```javascript
// Check for existence
const row = db.prepare('SELECT id FROM raw_notes WHERE content_hash = ?').get($json.hash);

if (row === undefined) {
  // No match found
  return {json: {exists: false}};
} else {
  // Match found
  return {json: {exists: true, id: row.id}};
}
```

**Common mistake:**

```javascript
// BAD: undefined != null in JavaScript
if (row == null) {
  // This catches both null and undefined, but confusing
}

// GOOD: Explicit
if (row === undefined) {
  // No row returned
}
```

---

## Testing Requirements

### Every Workflow Must Have

**1. Test Script:** `workflows/XX-name/scripts/test-with-markers.sh`

**Template:**

```bash
#!/bin/bash
set -e

cd "$(dirname "$0")/.."

# ============================================================================
# CUSTOMIZE THESE VALUES FOR YOUR WORKFLOW:
# - WEBHOOK_URL: Replace WORKFLOW_ENDPOINT with your actual webhook path
#   (e.g., "api/drafts" for ingestion, "api/process" for LLM processing)
# - Table name in verification queries (lines below)
# - Sleep time based on workflow complexity (2-15 seconds typical)
# ============================================================================

TEST_RUN="test-run-$(date +%Y%m%d-%H%M%S)"
WEBHOOK_URL="http://localhost:5678/webhook/api/WORKFLOW_ENDPOINT"

echo "Testing XX-name workflow with marker: $TEST_RUN"

# Test Case 1: Success path
echo "Test 1: Normal operation"
curl -X POST "$WEBHOOK_URL" \
  -H "Content-Type: application/json" \
  -d "{\"test_data\": \"value\", \"test_run\": \"$TEST_RUN\"}"

sleep 2  # Wait for processing

# Test Case 2: Error condition
echo "Test 2: Invalid input"
curl -X POST "$WEBHOOK_URL" \
  -H "Content-Type: application/json" \
  -d "{\"invalid\": true, \"test_run\": \"$TEST_RUN\"}"

# Verify results
PASS_COUNT=$(sqlite3 ../../data/selene.db "SELECT COUNT(*) FROM table WHERE test_run = '$TEST_RUN' AND status = 'completed';")
FAIL_COUNT=$(sqlite3 ../../data/selene.db "SELECT COUNT(*) FROM table WHERE test_run = '$TEST_RUN' AND status = 'failed';")

echo "Results: $PASS_COUNT passed, $FAIL_COUNT failed"

# Cleanup prompt
read -p "Cleanup test data? (y/n) " -n 1 -r
if [[ $REPLY =~ ^[Yy]$ ]]; then
    ../../scripts/cleanup-tests.sh "$TEST_RUN"
fi
```

**2. Test Cases Coverage:**

**Minimum required:**
- ✅ Success path (normal operation)
- ✅ Missing required fields
- ✅ Invalid data format
- ✅ Duplicate detection (if applicable)
- ✅ Database constraints (unique, foreign key)

**Nice to have:**
- Large data (stress test)
- Edge cases (empty strings, special characters)
- Concurrent requests
- Recovery from errors

**3. STATUS.md:** `workflows/XX-name/docs/STATUS.md`

**Template:**

```markdown
# XX-Name Workflow Status

**Last Updated:** YYYY-MM-DD
**Test Results:** X/Y passing

---

## Current Status

**Production Ready:** ✅ Yes / ❌ No

**Test Coverage:**
- ✅ Success path
- ✅ Error handling
- ✅ Database integration
- ❌ Edge cases (TODO)

---

## Test Results

### Latest Run (YYYY-MM-DD)

**Test Suite:** `./scripts/test-with-markers.sh`

| Test Case | Status | Notes |
|-----------|--------|-------|
| Normal operation | ✅ PASS | |
| Missing fields | ✅ PASS | Proper error message |
| Invalid format | ✅ PASS | |
| Duplicate | ✅ PASS | Rejected correctly |
| Large data | ⚠️ SKIP | Not critical |

**Overall:** 4/4 critical tests passing

---

## Known Issues

1. **Issue:** Description
   **Impact:** High/Medium/Low
   **Workaround:** Temporary solution
   **Status:** Open/In Progress/Fixed

---

## Recent Changes

### YYYY-MM-DD
- Added error handling for X
- Fixed duplicate detection
- Updated documentation

### YYYY-MM-DD
- Initial implementation
- Basic test coverage
```

---

## Documentation Requirements

### When You Modify a Workflow

**MUST update:**
1. ✅ `workflows/XX-name/docs/STATUS.md` - Test results and changes
2. ✅ `workflows/XX-name/README.md` - If interface/usage changed
3. ✅ `.claude/PROJECT-STATUS.md` - If workflow complete or status changed

**SHOULD update:**
4. `workflows/XX-name/docs/*-REFERENCE.md` - If technical details changed
5. `ROADMAP.md` - If phase complete

**Example workflow:**

```bash
# 1. Modify workflow
./scripts/manage-workflow.sh update 1 /workflows/01-ingestion/workflow.json

# 2. Test
cd workflows/01-ingestion
./scripts/test-with-markers.sh

# 3. Update STATUS.md
# (Document test results, changes made)

# 4. Update README.md (if needed)
# (Update usage examples if API changed)

# 5. Update PROJECT-STATUS.md
# (Mark workflow complete, note achievements)

# 6. Commit all together
git add workflows/01-ingestion/workflow.json
git add workflows/01-ingestion/docs/STATUS.md
git add .claude/PROJECT-STATUS.md
git commit -m "workflow: add sentiment extraction to ingestion

- Added sentiment analysis node
- Extracts emotional tone
- All 5/5 tests passing
- Updated documentation"
```

---

## Common Workflow Patterns

### Pattern 1: Webhook Trigger

**Configuration:**

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

**ADHD Impact:** Use "onReceived" to reduce perceived latency (user doesn't wait).

### Pattern 2: Schedule Trigger

**Configuration:**

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

**Common intervals:**
- Every 30 seconds: Processing loop
- Every 5 minutes: Periodic checks
- Daily at 6am: Batch operations

**Phase 6 Note:** Event-driven triggers preferred over schedules (3x faster, 100% efficient).

### Pattern 3: Conditional Routing (IF Node)

**Configuration:**

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

**Outputs:**
- `true` branch - Condition met
- `false` branch - Condition not met

**Common mistake:** Using Switch node with `notExists` for null checks (doesn't work). Use IF node with explicit null check.

### Pattern 4: Function Node (JavaScript)

**Always include error handling:**

```javascript
try {
  // Business logic here
  const result = processData($json);
  return {json: result};

} catch (error) {
  // Log error with context
  console.error('Function error:', error);

  // Return error in workflow-compatible format
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

**Whitelisted modules:**
- `better-sqlite3` - Database
- `crypto` - Hashing
- Standard library (fs, path, etc.)

### Pattern 4b: Complete Database + Function Error Handling

**When combining database operations with function logic, use nested try/catch with finally:**

```javascript
const Database = require('better-sqlite3');
let db;

try {
  // Outer try: Catches all errors (database + logic)
  db = new Database('/selene/data/selene.db');

  try {
    // Inner try: Your business logic
    const noteId = $json.id;

    // Database operations
    const note = db.prepare('SELECT * FROM raw_notes WHERE id = ?').get(noteId);

    if (!note) {
      throw new Error(`Note ${noteId} not found`);
    }

    // Additional processing
    const concepts = extractConcepts(note.content);

    // Update database
    db.prepare(`
      UPDATE processed_notes
      SET concepts = ?, status = 'completed'
      WHERE raw_note_id = ?
    `).run(JSON.stringify(concepts), noteId);

    return {
      json: {
        success: true,
        noteId: noteId,
        concepts: concepts
      }
    };

  } finally {
    // CRITICAL: Always close database, even on error
    if (db) {
      db.close();
    }
  }

} catch (error) {
  // Handle all errors (database connection, queries, or logic)
  console.error('Function error:', {
    message: error.message,
    stack: error.stack,
    input: $json
  });

  // Return error in workflow-compatible format
  return {
    json: {
      error: error.message,
      input: $json,
      timestamp: new Date().toISOString()
    }
  };
}
```

**Why this pattern:**
- **Outer try/catch**: Catches ALL errors (connection, queries, logic)
- **Inner try/finally**: Guarantees `db.close()` runs even on error
- **Prevents database locks**: Connection always closes
- **Clean error propagation**: Errors bubble up to outer catch
- **Workflow compatibility**: Returns error object instead of throwing

**When to use:**
- Any Function node that uses better-sqlite3
- Complex business logic with database operations
- Operations that might fail partway through
- Production workflows (not quick scripts)

### Pattern 5: Merge Node (Combine Data)

**Use when:**
- Joining data from multiple sources
- Adding enrichment data
- Combining parallel branches

**Configuration:**

```json
{
  "parameters": {
    "mode": "mergeByIndex",  // or "mergeByKey"
    "options": {}
  },
  "name": "Merge Data",
  "type": "n8n-nodes-base.Merge"
}
```

**Modes:**
- `mergeByIndex` - Combine items at same position
- `mergeByKey` - Join on matching field (like SQL JOIN)

---

## Integration Testing

### Test Full Pipeline

**Example: Ingestion → Processing → Export**

```bash
#!/bin/bash
set -e

TEST_RUN="integration-$(date +%Y%m%d-%H%M%S)"

echo "=== Integration Test: Full Pipeline ==="

# 1. Ingest note
echo "Step 1: Ingesting note..."
curl -X POST http://localhost:5678/webhook/api/drafts \
  -H "Content-Type: application/json" \
  -d "{
    \"title\": \"Integration Test Note\",
    \"content\": \"This is a test of the full pipeline from ingestion through export.\",
    \"test_run\": \"$TEST_RUN\"
  }"

echo "Waiting for processing..."
sleep 15

# 2. Verify ingestion
echo "Step 2: Checking ingestion..."
INGESTED=$(sqlite3 data/selene.db "SELECT COUNT(*) FROM raw_notes WHERE test_run = '$TEST_RUN';")
echo "Ingested: $INGESTED (expected: 1)"

# 3. Verify processing
echo "Step 3: Checking LLM processing..."
PROCESSED=$(sqlite3 data/selene.db "SELECT COUNT(*) FROM processed_notes WHERE test_run = '$TEST_RUN';")
echo "Processed: $PROCESSED (expected: 1)"

# 4. Verify sentiment
echo "Step 4: Checking sentiment analysis..."
SENTIMENT=$(sqlite3 data/selene.db "SELECT COUNT(*) FROM sentiment_history WHERE test_run = '$TEST_RUN';")
echo "Sentiment: $SENTIMENT (expected: 1)"

# 5. Verify export
echo "Step 5: Checking Obsidian export..."
if [ -f "vault/Selene/Integration Test Note.md" ]; then
  echo "Exported: Yes"
else
  echo "Exported: No (check export workflow)"
fi

# Summary
echo ""
echo "=== Integration Test Summary ==="
echo "Ingested: $INGESTED"
echo "Processed: $PROCESSED"
echo "Sentiment: $SENTIMENT"

# Cleanup prompt
read -p "Cleanup test data? (y/n) " -n 1 -r
if [[ $REPLY =~ ^[Yy]$ ]]; then
    ./scripts/cleanup-tests.sh "$TEST_RUN"
    rm -f "vault/Selene/Integration Test Note.md"
fi
```

---

## Performance Optimization

### Sequential vs Parallel Processing

**Current (Sequential):**
- Process 1 note at a time
- Wait for completion before next
- Prevents Ollama overload

**Why not parallel:**
- Ollama on M1 Mac handles 1 request well
- Parallel requests cause slowdowns
- ADHD users capture notes throughout day (not batches)

**When to consider parallel:**
- Bulk import of existing notes
- More powerful hardware
- Cloud-hosted Ollama

### Event-Driven vs Scheduled

**Phase 6 Migration:**

**Before (Scheduled):**
```json
{
  "type": "n8n-nodes-base.Schedule",
  "parameters": {
    "rule": {"interval": [{"field": "seconds", "secondsInterval": 30}]}
  }
}
```
- Runs every 30 seconds
- Wastes resources if no data
- 20-25 second processing time

**After (Event-Driven):**
```json
{
  "type": "n8n-nodes-base.Trigger",
  "parameters": {
    "events": ["workflow:completed"]
  }
}
```
- Triggers only when previous workflow completes
- Zero wasted executions
- ~14 second processing time
- 3x faster, 100% efficient

**See:** `@docs/roadmap/08-PHASE-6-EVENT-DRIVEN.md`

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
- `README.md` - Quick orientation (ADHD = needs fast context)
- `STATUS.md` - Current state visible (ADHD = needs status visible)
- `test-with-markers.sh` - Automated testing (prevents regressions)

---

## Related Context Files

- **`@.claude/OPERATIONS.md`** - Commands to execute workflows
- **`@.claude/DEVELOPMENT.md`** - Architecture and design patterns
- **`@scripts/CLAUDE.md`** - Script utilities (manage-workflow.sh)
- **`@.claude/PROJECT-STATUS.md`** - Current workflow status
