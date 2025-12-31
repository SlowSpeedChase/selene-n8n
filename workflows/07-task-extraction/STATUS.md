# Task Extraction Workflow - Status & Development Log

## Current Status

**Phase:** 7.1 - Classification and Routing Complete
**Last Updated:** 2025-12-30
**Status:** Workflow restructured with classification routing - Ready for testing

---

## Overview

The task extraction workflow now includes intelligent classification to triage notes before task extraction:

- **actionable** - Clear tasks routed to Things 3 inbox
- **needs_planning** - Goals/projects flagged for SeleneChat planning sessions
- **archive_only** - Thoughts/reflections stored for Obsidian export (no task extraction)

**Key Features:**
- **Three-way classification** using Ollama LLM before task extraction
- **Intelligent routing** via Switch node based on classification
- **Discussion threads** created for needs_planning items (Phase 7.2 prep)
- **ADHD enrichment** (energy levels, overwhelm factor, time estimates)
- **Things 3 integration** via URL scheme wrapper
- **Test data isolation** via test_run marker throughout

---

## Workflow Architecture

```
[Webhook Trigger]
       |
[Fetch Note Data]
       |
[Build Classification Prompt]
       |
[Ollama Classify Note]
       |
[Parse Classification]
       |
[Route by Classification] ----+----+
       |                      |    |
  actionable           needs_planning  archive_only
       |                      |         |
[Build Task Extraction]  [Flag for    [Store Classification]
       |                  Planning]
[Ollama Extract Tasks]        |
       |              (creates discussion_thread)
[Parse Tasks JSON]
       |
[Split Tasks]
       |
[Create Things Task]
       |
[Store Task Metadata]
       |
[Update Status (Actionable)]
```

---

## Recent Changes

### 2025-12-30: Phase 7.1 Classification (Batch 2)

**Tasks Completed:**

1. **Task 3: Add Classification Node**
   - Added "Build Classification Prompt" node with full classification template
   - Added "Ollama Classify Note" HTTP request node (30s timeout)
   - Added "Parse Classification" node with JSON parsing and validation
   - Classification values: actionable, needs_planning, archive_only

2. **Task 4: Add Routing Logic (Switch Node)**
   - Added "Route by Classification" Switch node with 3 outputs
   - Output 0: actionable -> Task extraction pipeline
   - Output 1: needs_planning -> Flag for Planning node
   - Output 2 (fallback): archive_only -> Store Classification node

3. **Task 5: Update Task Extraction Prompt**
   - Renamed to "Build Task Extraction Prompt" for clarity
   - Added classification context to prompt
   - Notes that content is pre-classified as actionable
   - Updated metadata extraction based on metadata-definitions.md

4. **Task 6: Update Status Handling**
   - "Update Status (Actionable)" - Updates classification and things_integration_status
   - "Flag for Planning" - Creates discussion_thread record for SeleneChat
   - "Store Classification (Archive)" - Updates classification only, no task extraction

**Files Modified:**
- `workflows/07-task-extraction/workflow.json` - Complete workflow restructure

---

## Database Schema Updates (Batch 1)

**Migration:** `database/migrations/008_classification_fields.sql`

**New Columns (processed_notes):**
```sql
classification TEXT DEFAULT 'archive_only'
    CHECK(classification IN ('actionable', 'needs_planning', 'archive_only'))

planning_status TEXT DEFAULT NULL
    CHECK(planning_status IS NULL OR planning_status IN
          ('pending_review', 'in_planning', 'planned', 'archived'))
```

**New Table (discussion_threads):**
```sql
CREATE TABLE discussion_threads (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    raw_note_id INTEGER NOT NULL,
    thread_type TEXT NOT NULL,  -- 'planning', 'followup', 'question'
    prompt TEXT NOT NULL,
    status TEXT DEFAULT 'pending',
    created_at TEXT DEFAULT CURRENT_TIMESTAMP,
    surfaced_at TEXT,
    completed_at TEXT,
    related_concepts TEXT,  -- JSON array
    test_run TEXT DEFAULT NULL,
    FOREIGN KEY (raw_note_id) REFERENCES raw_notes(id) ON DELETE CASCADE
);
```

---

## Node Summary (14 Nodes)

| Node Name | Type | Purpose |
|-----------|------|---------|
| Webhook Trigger | webhook | POST /webhook/task-extraction |
| Fetch Note Data | function | Query raw_notes + processed_notes + sentiment_history |
| Build Classification Prompt | function | Generate classification prompt with note data |
| Ollama Classify Note | httpRequest | Call Ollama for classification |
| Parse Classification | function | Parse JSON, validate, default to archive_only |
| Route by Classification | switch | 3-way routing based on classification |
| Build Task Extraction Prompt | function | Generate task extraction prompt (actionable only) |
| Ollama Extract Tasks | httpRequest | Call Ollama for task extraction |
| Parse Tasks JSON | function | Parse tasks, embed metadata for Split |
| Split Tasks | splitOut | One item per task |
| Create Things Task | httpRequest | POST to Things wrapper |
| Store Task Metadata | function | INSERT into task_metadata table |
| Update Status (Actionable) | function | Update classification and things_integration_status |
| Flag for Planning | function | Create discussion_thread, set planning_status |
| Store Classification (Archive) | function | Update classification only |

---

## Test Coverage

### Classification Tests (Pending)
- [ ] Actionable note classification
- [ ] Needs_planning note classification
- [ ] Archive_only note classification
- [ ] Edge cases (mixed content, ambiguous notes)

### Task Extraction Tests (From Previous)
- [x] Multi-task extraction from actionable note
- [x] Zero tasks from reflection note
- [x] ADHD enrichment fields stored

### Database Tests
- [x] 32 migration tests passing (008_classification_fields.sql)
- [x] 26 prompt tests passing (classification-prompt.txt)
- [x] 14 task_metadata tests passing (007_task_metadata.sql)

**Total: 72+ tests in test suites**

---

## Testing

### Test Classification

```bash
# Generate test ID
TEST_RUN="test-run-$(date +%Y%m%d-%H%M%S)"

# Test actionable note
curl -X POST http://localhost:5678/webhook/task-extraction \
  -H "Content-Type: application/json" \
  -d "{\"raw_note_id\": 1, \"test_run\": \"$TEST_RUN\"}"

# Verify classification
sqlite3 data/selene.db "SELECT classification, planning_status FROM processed_notes WHERE raw_note_id = 1;"

# Check discussion threads (for needs_planning)
sqlite3 data/selene.db "SELECT * FROM discussion_threads WHERE test_run = '$TEST_RUN';"

# Cleanup
./scripts/cleanup-tests.sh "$TEST_RUN"
```

---

## Known Issues

### 1. Migration Not Yet Applied
**Issue:** Migration 008 not yet applied to production database
**Impact:** classification and planning_status columns don't exist
**Resolution:** Run migration before testing workflow

### 2. Things Wrapper Dependency
**Issue:** Workflow requires Things HTTP wrapper on port 3456
**Impact:** Task creation fails if wrapper not running
**Workaround:** Start wrapper before testing actionable path

---

## Related Documentation

- **Classification Prompt:** `prompts/classification-prompt.txt`
- **Database Migration:** `database/migrations/008_classification_fields.sql`
- **Design Doc:** `docs/plans/2025-12-30-task-extraction-planning-design.md`
- **Metadata Definitions:** `docs/architecture/metadata-definitions.md`
- **Implementation Plan:** `IMPLEMENTATION-PLAN.md`

---

## Development Log

### 2025-12-30: Batch 2 Complete (Tasks 3-6)

**Completed:**
- Restructured workflow with classification pipeline
- Added 6 new nodes for classification and routing
- Updated task extraction prompt with classification context
- Added three separate paths: actionable, needs_planning, archive_only
- Created discussion_threads for needs_planning items

**Architecture Decisions:**
- Classification before task extraction (not after)
- Single Ollama call for classification, separate call for extraction (reliability)
- Switch node for routing (cleaner than IF chains)
- Discussion threads with planning prompt for SeleneChat

**Next Steps:**
- Apply database migration
- Run integration tests
- Create test script with all three scenarios
- Update documentation

---

## Previous Work

### 2025-11-25: TDD Foundation Complete

**Completed:**
- Created database migration (007_task_metadata.sql)
- Applied migration (version 7 recorded)
- Wrote 14 migration tests (RED -> GREEN)
- Wrote 13 sync tests (all passing)
- Created 5 mock test scenarios
- Set up Things test project
- Verified all 27 tests passing

**Test Results:**
- Database migration: 14/14
- Bidirectional sync: 13/13
- Total: 27/27 (100% pass rate)

---

## Conclusion

**Phase 7.1 Batch 2 (Workflow Restructure) is COMPLETE.**

The workflow now includes:
1. Three-way classification (actionable/needs_planning/archive_only)
2. Intelligent routing via Switch node
3. Discussion thread creation for planning items
4. Updated task extraction for pre-classified notes
5. Proper status handling for all three paths

**Ready for:** Integration testing and migration application.
