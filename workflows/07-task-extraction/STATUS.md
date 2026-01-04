# Task Extraction Workflow - Status & Development Log

## Current Status

**Phase:** 7.2f.2 - Auto-Assignment COMPLETE
**Last Updated:** 2026-01-04
**Status:** PRODUCTION READY - Classification + Task Extraction + Things Integration + Auto-Assignment Working

---

## Overview

The task extraction workflow automatically classifies notes and extracts actionable tasks, routing them to Things 3 via file-based handoff. Notes requiring planning are flagged for SeleneChat.

**Key Features:**
- **Three-way classification** using Ollama LLM: `actionable`, `needs_planning`, `archive_only`
- **Automatic task extraction** from actionable notes
- **ADHD enrichment** (energy levels, overwhelm factor, time estimates)
- **Things 3 integration** via file-based handoff with launchd automation
- **Discussion threads** created for notes needing planning

---

## Architecture

```
┌─────────────────────────────────────────────────────────────────────┐
│                      WORKFLOW 07: Task Extraction                    │
│                                                                      │
│  Webhook Trigger → Fetch Note → Build Classification Prompt         │
│       ↓                                                              │
│  Ollama Classify → Parse Classification → Switch by Classification  │
│       │                    │                       │                 │
│       ▼                    ▼                       ▼                 │
│  ┌─────────────┐    ┌─────────────┐        ┌─────────────┐          │
│  │  ACTIONABLE │    │NEEDS_PLANNING│        │ ARCHIVE_ONLY│          │
│  └──────┬──────┘    └──────┬──────┘        └──────┬──────┘          │
│         │                  │                      │                  │
│         ▼                  ▼                      ▼                  │
│  Build Prompt →     Flag for Planning →    Store Classification     │
│  Ollama Extract →   Create Discussion      (update DB only)         │
│  Parse Tasks →      Thread                                          │
│  Split Tasks →                                                      │
│  Write JSON File →                                                  │
│  Store Metadata →                                                   │
│  Update Status                                                      │
└─────────────────────────────────────────────────────────────────────┘
                         │
                         ▼
┌─────────────────────────────────────────────────────────────────────┐
│                     FILE-BASED THINGS BRIDGE                         │
│                                                                      │
│  /obsidian/things-pending/task-*.json                               │
│       ↓ (launchd watches)                                           │
│  process-pending-tasks.sh                                           │
│       ↓                                                              │
│  add-task-to-things.scpt (AppleScript)                              │
│       ↓                                                              │
│  Things 3 Inbox                                                     │
│       ↓                                                              │
│  /obsidian/things-processed/task-*.json (with things_task_id)       │
└─────────────────────────────────────────────────────────────────────┘
```

---

## E2E Test Results

### Test Run: 2025-12-30

#### Actionable Path Test

| Step | Status | Details |
|------|--------|---------|
| Note created | PASS | ID: 193 |
| Classification | PASS | `actionable` |
| Task extraction | PASS | 1 task extracted |
| JSON file written | PASS | `task-193-*.json` |
| launchd triggered | PASS | File detected in <3 seconds |
| Things task created | PASS | ID: `WUDog8Rfxx6HKnSMKBiLBD` |
| Metadata stored | PASS | `task_metadata` record created |
| File processed | PASS | Moved to `things-processed/` |

#### Needs Planning Path Test

| Step | Status | Details |
|------|--------|---------|
| Note created | PASS | IDs: 194, 195 |
| Classification | PASS | `needs_planning` |
| Planning status | PASS | `pending_review` |
| Discussion thread | PASS | Created with type `planning` |
| Task count | PASS | 0 (not sent to Things) |
| Things files | PASS | None created |

### Test Run: 2026-01-04 (Phase 7.2f.2 - Auto-Assignment)

#### Auto-Assignment Path Test

| Step | Status | Details |
|------|--------|---------|
| Note created | PASS | ID: 217 |
| Classification | PASS | `actionable` |
| Task extraction | PASS | 1 task extracted |
| Find Matching Project | PASS | Matched "Home Renovation" with overlap=2 |
| `matched_project_id` passed | PASS | `test-project-home-reno` |
| `task_metadata.things_project_id` | PASS | Stored correctly |

**Matching Algorithm Verified:**
- Task concepts: `["home-renovation", "shopping", "planning"]`
- Project "Home Renovation": `primary_concept="home-renovation"`, `related_concepts=["budgeting", "planning", "organization"]`
- Overlap count: 2 (`home-renovation` + `planning`)

---

## Things Bridge Components

### Files Created

```
scripts/things-bridge/
├── add-task-to-things.scpt      # AppleScript for Things API
├── process-pending-tasks.sh     # Wrapper script (processes all pending)
└── com.selene.things-bridge.plist  # launchd configuration
```

### Installation

The launchd job is installed at:
- `~/Library/LaunchAgents/com.selene.things-bridge.plist`

To manage:
```bash
# Check status
launchctl list | grep selene

# Reload
launchctl unload ~/Library/LaunchAgents/com.selene.things-bridge.plist
launchctl load ~/Library/LaunchAgents/com.selene.things-bridge.plist

# View logs
tail -f /Users/chaseeasterling/selene-n8n/logs/things-bridge.log
```

---

## Classification Logic

### Decision Rules

```
IF note has clear verb + specific object
   AND can be completed in single session
   AND "done" is unambiguous
   THEN classification = "actionable"

ELSE IF note expresses goal or desired outcome
   OR contains multiple potential tasks
   OR requires scoping/breakdown
   OR uses "want to", "should", "need to figure out"
   THEN classification = "needs_planning"

ELSE classification = "archive_only"
```

### Routing

| Classification | Action | Destination |
|----------------|--------|-------------|
| `actionable` | Extract tasks, write JSON | Things inbox |
| `needs_planning` | Create discussion thread | SeleneChat (Phase 7.2) |
| `archive_only` | Store classification | Obsidian only |

---

## Database Changes

### processed_notes (existing table, new columns)

```sql
classification TEXT DEFAULT 'archive_only'
    CHECK(classification IN ('actionable', 'needs_planning', 'archive_only'))

planning_status TEXT DEFAULT NULL
    CHECK(planning_status IS NULL OR
          planning_status IN ('pending_review', 'in_planning', 'planned', 'archived'))

things_integration_status TEXT DEFAULT 'pending'
    CHECK(things_integration_status IN ('pending', 'tasks_created', 'no_tasks', 'error'))
```

### discussion_threads (new table)

```sql
CREATE TABLE discussion_threads (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    raw_note_id INTEGER NOT NULL,
    thread_type TEXT NOT NULL CHECK(thread_type IN ('planning', 'followup', 'question')),
    prompt TEXT NOT NULL,
    status TEXT DEFAULT 'pending' CHECK(status IN ('pending', 'active', 'completed', 'dismissed')),
    created_at TEXT DEFAULT CURRENT_TIMESTAMP,
    surfaced_at TEXT,
    completed_at TEXT,
    related_concepts TEXT,
    test_run TEXT DEFAULT NULL,
    FOREIGN KEY (raw_note_id) REFERENCES raw_notes(id) ON DELETE CASCADE
);
```

---

## Usage

### Trigger Workflow

```bash
curl -X POST http://localhost:5678/webhook/task-extraction \
  -H "Content-Type: application/json" \
  -d '{"raw_note_id": 123}'
```

### With Test Marker

```bash
curl -X POST http://localhost:5678/webhook/task-extraction \
  -H "Content-Type: application/json" \
  -d '{"raw_note_id": 123, "test_run": "test-run-20251230-120000"}'
```

---

## Known Limitations

1. **Single task per run** - The workflow currently processes one note per webhook call
2. **No bidirectional sync yet** - Tasks created in Things are not synced back
3. **fs module not available** - n8n sandboxes prevent direct file system access; using `writeBinaryFile` node instead

---

## Development Log

### 2025-12-30: Phase 7.1 Implementation Complete

**Completed:**
- Created file-based Things bridge (AppleScript + shell wrapper + launchd)
- Modified workflow to write JSON files to `/obsidian/things-pending/`
- Fixed routing with Switch node (replaced broken multi-output Function node)
- E2E tested both actionable and needs_planning paths
- All paths verified working

**Key Decisions:**
- File-based handoff chosen over HTTP bridge (simpler, more reliable)
- launchd WatchPaths provides near-instant file detection
- Switch node for routing (n8n's Function multi-output doesn't work as expected)

**Files Changed:**
- `workflows/07-task-extraction/workflow.json`
- `scripts/things-bridge/add-task-to-things.scpt`
- `scripts/things-bridge/process-pending-tasks.sh`
- `scripts/things-bridge/com.selene.things-bridge.plist`

### 2025-11-25: TDD Foundation Complete

- Database migration (007_task_metadata.sql)
- 27 tests written and passing
- Mock test data created
- Things test project set up

---

## Next Steps (Phase 7.2+)

1. **SeleneChat Planning Integration** - Surface `needs_planning` items in SeleneChat
2. **Bidirectional Sync** - Track task completion from Things
3. **Batch Processing** - Process multiple notes per trigger
4. **Event-Driven Trigger** - Auto-trigger after sentiment analysis (workflow 05)

---

## Related Documentation

- **[Phase 7.1 Design](../../docs/plans/2025-12-30-task-extraction-planning-design.md)** - Architecture and classification logic
- **[Implementation Plan](../../docs/plans/2025-12-30-phase-7-1-implementation.md)** - Step-by-step implementation
- **[Metadata Definitions](../../docs/architecture/metadata-definitions.md)** - Field specifications
- **[Phase 7 Roadmap](../../docs/roadmap/16-PHASE-7-THINGS.md)** - Overall roadmap
