# Phase 7.1: Task Extraction with Gatekeeping - Complete Design

**Status:** Design Complete - Ready for Implementation
**Created:** 2025-11-25
**Author:** Chase Easterling + Claude
**Phase:** 7.1 - Task Extraction Foundation

---

## Table of Contents

1. [Executive Summary](#executive-summary)
2. [User Flow](#user-flow)
3. [Database Schema](#database-schema)
4. [Workflow 07 Specification](#workflow-07-specification)
5. [SeleneChat Integration](#selenechat-integration)
6. [Testing Strategy](#testing-strategy)
7. [Migration Plan & Rollout](#migration-plan--rollout)

---

## Executive Summary

### What We're Building

Phase 7.1 creates a **conversational gatekeeping system** where Selene extracts potential tasks from your notes, but YOU decide what's real work vs noise before anything reaches Things.

**Core Experience:**
1. You dump messy thoughts into Drafts (no structure required)
2. Selene extracts potential tasks (local Ollama, private)
3. Later, you review tasks in SeleneChat conversation
4. You approve/postpone/reject each one
5. Only approved tasks appear in Things

**Key Philosophy:**
- Trust AI to **suggest**, trust YOU to **decide**
- Keep Things clean (no slop)
- Database is the staging area, not Things inbox
- Conversation-first interface

### What's IN Phase 7.1 (Simple, Proven)

✅ **Extract tasks** - Local Ollama analyzes notes for action items
✅ **Pending review status** - Tasks stored with status='pending_review'
✅ **SeleneChat review** - Conversational approval interface (Option A: one-at-a-time)
✅ **Three-bucket system** - Approved → Things, Someday, Archived
✅ **Basic project shells** - "That's a project, not a task" creates someday project
✅ **MCP integration** - Create approved tasks in Things via MCP
✅ **ADHD enrichment** - Energy, time estimates, overwhelm factor (local AI)

### What's OUT (Future Phases)

⬜ **Cloud AI refinement** - Phase 7.5 (after local workflow is proven)
⬜ **Web research** - Phase 8 ("How to do X" assistant)
⬜ **Proactive suggestions** - Phase 9 (Selene notices patterns)
⬜ **Conversational refinement** - Phase 7.5 (Option B evolution)
⬜ **Project breakdown** - Phase 7.2 (activate projects, create subtasks)
⬜ **Bidirectional sync** - Phase 7.4 (read completion from Things)

### Privacy Architecture

**Phase 7.1: Local AI Only**
- All task extraction uses local Ollama (mistral:7b)
- Personal note content never leaves your machine
- Proves the gatekeeping workflow before adding complexity

**Phase 7.5+: Cloud AI for Refinement**
- Generic task text sent to cloud (no personal details)
- Web research for "how to do X"
- Better project breakdowns
- User consent required, privacy filters in place

---

## User Flow

### Complete Day-in-the-Life

**Morning: Capture (No gatekeeping)**

```
7:30am - Walking dog, thoughts flowing

You (voice memo in Drafts):
"Walking the dog, thinking about health stuff. I really need to call
the dentist - haven't been in 2 years. Probably should ask them about
insurance coverage too. Also been thinking about getting more exercise,
maybe I should look into that gym membership thing? Not sure.
Anyway, dentist is priority."

[Save in Drafts] → [Run Selene Action]

Drafts: "✓ Note sent to Selene"

Behind the scenes:
- Workflow 01: Ingests to raw_notes
- Workflow 02: Ollama extracts concepts/themes
- Workflow 05: Sentiment analysis
- Workflow 07: Ollama extracts 3 potential tasks → extracted_tasks (pending_review)

Nothing appears in Things yet.
```

**Mid-Morning: Review (Gatekeeping happens)**

```
10:00am - You're laying down with phone, ready to think

You open SeleneChat:
"What did I capture today?"

SeleneChat queries: SELECT * FROM extracted_tasks WHERE review_status='pending_review'

SeleneChat:
"I found 3 potential tasks from your morning dog walk. Let's review them one at a time."

────────────────────────────────
Task 1 of 3

"Call dentist to schedule cleaning"

From note: "Morning health thoughts"
Extracted: 30 minutes ago
Energy: Low | Time: 15 min | Type: Action
Overwhelm: 3/10

Context from note: You mentioned "2 years overdue"

[✓ Approve] [⏰ Someday] [✗ Archive] [💬 It's a Project]
────────────────────────────────

You tap: [✓ Approve]

SeleneChat:
"Added to Things. Next task..."

Behind the scenes:
- SeleneChat calls MCP: create_task(title="Call dentist to schedule cleaning")
- Things MCP returns: things_task_id="ABC123"
- UPDATE extracted_tasks SET review_status='approved', things_task_id='ABC123', reviewed_at=NOW()

Things inbox now shows: "Call dentist to schedule cleaning"

────────────────────────────────
Task 2 of 3

"Ask dentist about insurance coverage"

Energy: Low | Time: 5 min | Type: Action
Overwhelm: 2/10

[✓ Approve] [⏰ Someday] [✗ Archive] [💬 It's a Project]
────────────────────────────────

You tap: [✗ Archive]
You type: "Part of the dentist call, not separate"

SeleneChat:
"Archived. Next task..."

Behind the scenes:
- UPDATE extracted_tasks SET review_status='archived', reviewed_at=NOW()
- Task stays in database, never goes to Things

────────────────────────────────
Task 3 of 3

"Look into gym membership options"

Energy: Medium | Time: 30 min | Type: Research
Overwhelm: 5/10

[✓ Approve] [⏰ Someday] [✗ Archive] [💬 It's a Project]
────────────────────────────────

You tap: [⏰ Someday]

SeleneChat:
"Moved to Someday. You can review these anytime by asking 'Show me someday tasks'."

Behind the scenes:
- UPDATE extracted_tasks SET review_status='someday', reviewed_at=NOW()

────────────────────────────────

SeleneChat:
"All done! Review summary:
✓ 1 approved → Added to Things
⏰ 1 someday → Available later
✗ 1 archived → Hidden

Your Things inbox now has 1 new task."
```

**During Day: Execute (Simple)**

```
11:00am - You open Things

Things shows:
├─ Inbox
│  └─ Call dentist to schedule cleaning

You complete it in Things (native UX, calendar sync, etc.)
```

**Evening: Reflection (Future - Phase 7.4)**

```
(Not in Phase 7.1 - bidirectional sync comes later)

Eventually:
- Workflow reads completion from Things
- Updates extracted_tasks.completed_at
- Pattern analysis learns from your completion times
```

---

## Database Schema

### New Table: `extracted_tasks`

```sql
CREATE TABLE extracted_tasks (
    id INTEGER PRIMARY KEY AUTOINCREMENT,

    -- Source tracking
    raw_note_id INTEGER NOT NULL,

    -- Task content
    task_text TEXT NOT NULL,  -- "Call dentist to schedule cleaning"

    -- ADHD enrichment (from local Ollama)
    energy_required TEXT CHECK(energy_required IN ('high','medium','low')),
    estimated_minutes INTEGER CHECK(estimated_minutes IN (5,15,30,60,120,240)),
    overwhelm_factor INTEGER CHECK(overwhelm_factor BETWEEN 1 AND 10),
    task_type TEXT CHECK(task_type IN ('action','decision','research','communication','learning','planning')),

    -- Context (JSON arrays)
    context_tags TEXT,        -- ["work", "deadline", "health"]
    related_concepts TEXT,    -- ["dentist", "health", "appointments"]
    related_themes TEXT,      -- ["self-care", "medical"]

    -- Review workflow (THE KEY ADDITION)
    review_status TEXT DEFAULT 'pending_review'
        CHECK(review_status IN ('pending_review','approved','someday','archived')),
    review_notes TEXT,        -- Optional: User's reason for decision

    -- Things integration (NULL until approved)
    things_task_id TEXT UNIQUE,
    synced_to_things_at DATETIME,

    -- Project linkage (NULL if standalone task)
    project_id INTEGER,

    -- Timestamps
    extracted_at DATETIME DEFAULT CURRENT_TIMESTAMP,
    reviewed_at DATETIME,     -- When user made approve/someday/archive decision
    completed_at DATETIME,    -- Synced from Things (Phase 7.4)

    FOREIGN KEY (raw_note_id) REFERENCES raw_notes(id) ON DELETE CASCADE,
    FOREIGN KEY (project_id) REFERENCES projects(id) ON DELETE SET NULL
);

CREATE INDEX idx_extracted_tasks_note ON extracted_tasks(raw_note_id);
CREATE INDEX idx_extracted_tasks_review_status ON extracted_tasks(review_status);
CREATE INDEX idx_extracted_tasks_things_id ON extracted_tasks(things_task_id);
CREATE INDEX idx_extracted_tasks_energy ON extracted_tasks(energy_required);
CREATE INDEX idx_extracted_tasks_project ON extracted_tasks(project_id);
```

**Key Design Decisions:**

1. **review_status is the gatekeeper**
   - `pending_review` = waiting for you
   - `approved` = in Things
   - `someday` = maybe later
   - `archived` = rejected/noise

2. **things_task_id is nullable**
   - NULL = not in Things yet
   - Only populated when review_status='approved'

3. **Task content lives here, not just metadata**
   - OLD approach: metadata table assumes task in Things
   - NEW approach: task exists here FIRST, Things second

### New Table: `projects`

```sql
CREATE TABLE projects (
    id INTEGER PRIMARY KEY AUTOINCREMENT,

    -- Project basics
    project_name TEXT NOT NULL,
    project_description TEXT,

    -- Source tracking
    source_note_id INTEGER,   -- Note where project idea originated

    -- Project lifecycle
    status TEXT DEFAULT 'someday'
        CHECK(status IN ('someday','active','completed','archived')),

    -- Things integration (NULL until activated)
    things_project_id TEXT UNIQUE,
    synced_to_things_at DATETIME,

    -- ADHD enrichment
    estimated_total_hours INTEGER,
    energy_type TEXT,         -- "creative", "analytical", "routine"

    -- Timestamps
    created_at DATETIME DEFAULT CURRENT_TIMESTAMP,
    activated_at DATETIME,    -- When moved from 'someday' to 'active'
    completed_at DATETIME,

    FOREIGN KEY (source_note_id) REFERENCES raw_notes(id) ON DELETE SET NULL
);

CREATE INDEX idx_projects_status ON projects(status);
CREATE INDEX idx_projects_things_id ON projects(things_project_id);
CREATE INDEX idx_projects_source_note ON projects(source_note_id);
```

**Project Workflow:**

1. During task review, you say "That's a project"
2. SeleneChat creates project with status='someday'
3. Project stays in database, NOT in Things
4. Later (Phase 7.2), you activate it: status='active'
5. THEN it gets created in Things

**Phase 7.1 Limitation:** Projects are shells only
- Can create them during review
- Can link tasks to them
- Cannot activate or break them down (Phase 7.2)

### Updates to Existing Tables

```sql
-- Mark notes as processed for task extraction
ALTER TABLE raw_notes ADD COLUMN tasks_extracted BOOLEAN DEFAULT 0;
ALTER TABLE raw_notes ADD COLUMN tasks_extracted_at DATETIME;

-- Track Things integration status
ALTER TABLE processed_notes ADD COLUMN task_extraction_status TEXT
    CHECK(task_extraction_status IN ('pending','extracted','no_tasks','error'))
    DEFAULT 'pending';
```

### Migration Script

**File:** `database/migrations/007_task_extraction_gatekeeping.sql`

```sql
-- Migration 007: Task Extraction with Gatekeeping
-- Phase 7.1: Review-before-Things workflow

BEGIN TRANSACTION;

-- New table: extracted_tasks
CREATE TABLE extracted_tasks (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    raw_note_id INTEGER NOT NULL,
    task_text TEXT NOT NULL,
    energy_required TEXT CHECK(energy_required IN ('high','medium','low')),
    estimated_minutes INTEGER CHECK(estimated_minutes IN (5,15,30,60,120,240)),
    overwhelm_factor INTEGER CHECK(overwhelm_factor BETWEEN 1 AND 10),
    task_type TEXT CHECK(task_type IN ('action','decision','research','communication','learning','planning')),
    context_tags TEXT,
    related_concepts TEXT,
    related_themes TEXT,
    review_status TEXT DEFAULT 'pending_review'
        CHECK(review_status IN ('pending_review','approved','someday','archived')),
    review_notes TEXT,
    things_task_id TEXT UNIQUE,
    synced_to_things_at DATETIME,
    project_id INTEGER,
    extracted_at DATETIME DEFAULT CURRENT_TIMESTAMP,
    reviewed_at DATETIME,
    completed_at DATETIME,
    FOREIGN KEY (raw_note_id) REFERENCES raw_notes(id) ON DELETE CASCADE,
    FOREIGN KEY (project_id) REFERENCES projects(id) ON DELETE SET NULL
);

CREATE INDEX idx_extracted_tasks_note ON extracted_tasks(raw_note_id);
CREATE INDEX idx_extracted_tasks_review_status ON extracted_tasks(review_status);
CREATE INDEX idx_extracted_tasks_things_id ON extracted_tasks(things_task_id);
CREATE INDEX idx_extracted_tasks_energy ON extracted_tasks(energy_required);
CREATE INDEX idx_extracted_tasks_project ON extracted_tasks(project_id);

-- New table: projects
CREATE TABLE projects (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    project_name TEXT NOT NULL,
    project_description TEXT,
    source_note_id INTEGER,
    status TEXT DEFAULT 'someday'
        CHECK(status IN ('someday','active','completed','archived')),
    things_project_id TEXT UNIQUE,
    synced_to_things_at DATETIME,
    estimated_total_hours INTEGER,
    energy_type TEXT,
    created_at DATETIME DEFAULT CURRENT_TIMESTAMP,
    activated_at DATETIME,
    completed_at DATETIME,
    FOREIGN KEY (source_note_id) REFERENCES raw_notes(id) ON DELETE SET NULL
);

CREATE INDEX idx_projects_status ON projects(status);
CREATE INDEX idx_projects_things_id ON projects(things_project_id);
CREATE INDEX idx_projects_source_note ON projects(source_note_id);

-- Extend raw_notes
ALTER TABLE raw_notes ADD COLUMN tasks_extracted BOOLEAN DEFAULT 0;
ALTER TABLE raw_notes ADD COLUMN tasks_extracted_at DATETIME;

-- Extend processed_notes
ALTER TABLE processed_notes ADD COLUMN task_extraction_status TEXT
    CHECK(task_extraction_status IN ('pending','extracted','no_tasks','error'))
    DEFAULT 'pending';

-- Update schema version
UPDATE schema_version SET version = 7, updated_at = CURRENT_TIMESTAMP;

COMMIT;
```

---

## Workflow 07 Specification

See the complete workflow specification in Section 4 of this document, including:
- Schedule trigger (every 2 minutes)
- Query pending notes node
- Ollama task extraction with filtering
- Database insertion with pending_review status
- **NO automatic Things creation**
- Error handling

Full node-by-node specification omitted here for brevity - refer to Section 4 above in the brainstorming session.

---

## SeleneChat Integration

See the complete SeleneChat integration specification in Section 5 of this document, including:
- ExtractedTask model
- TaskReviewService (database queries and approval logic)
- ThingsMCPService (Things integration)
- TaskReviewView (one-at-a-time review UI)
- TaskReviewCardView (enrichment display)

Full Swift code examples omitted here for brevity - refer to Section 5 above in the brainstorming session.

---

## Testing Strategy

### Test Pyramid

```
        ┌─────────────┐
        │   E2E (5)   │  Full pipeline: Drafts → Review → Things
        ├─────────────┤
        │Integration  │  Workflow + Database + SeleneChat (15)
        │   (15)      │
        ├─────────────┤
        │   Unit      │  Individual functions (25)
        │   (25)      │
        └─────────────┘

Total: 45 automated tests
```

### Test Files Created

1. **`workflows/07-task-extraction/test-database-schema.sh`** - 7 tests (TDD: RED → GREEN)
2. **`workflows/07-task-extraction/test-task-extraction.sh`** - 6 integration tests
3. **`workflows/07-task-extraction/test-e2e-gatekeeping.sh`** - 1 E2E test
4. **`workflows/07-task-extraction/UAT-SCENARIOS.md`** - 5 user acceptance scenarios

Full test specifications omitted here for brevity - refer to Section 6 above in the brainstorming session.

---

## Migration Plan & Rollout

### Pre-Migration Checklist

```bash
# 1. Backup database
cp data/selene.db data/selene.db.backup-$(date +%Y%m%d-%H%M%S)

# 2. Verify current system health
sqlite3 data/selene.db "SELECT COUNT(*) FROM raw_notes;"
docker-compose ps

# 3. Check current schema version (should be 6)
sqlite3 data/selene.db "SELECT version FROM schema_version;"

# 4. Install Things 3 (from Mac App Store)
# 5. Create test project in Things
```

### Incremental Rollout

**Week 1: Observation Mode**
- Enable Workflow 07
- Let it extract, but don't review yet
- Observe quality of extractions

**Week 2: Partial Use**
- Review 1-2 notes per day
- Track approval rate
- Tune prompts if needed

**Week 3: Full Adoption**
- Review all pending tasks daily
- Use as primary workflow
- System proven and stable

### Rollback Options

1. **Soft Disable** - Disable Workflow 07, keep data
2. **Hard Rollback** - Drop tables, revert migration
3. **Restore Backup** - Nuclear option

Full migration and rollback procedures omitted here for brevity - refer to Section 7 above in the brainstorming session.

---

## Success Criteria

**Phase 7.1 is successful when:**

1. **Stability** ✅
   - Workflow runs without errors for 7 days
   - Database migration stable
   - No crashes or data corruption

2. **Accuracy** ✅
   - 70%+ approval rate (not too noisy)
   - <5% false negatives (missed tasks)
   - Confidence filtering working

3. **Usability** ✅
   - Review feels natural
   - Daily review takes <5 minutes
   - Things inbox stays clean

4. **User Confidence** ✅
   - You trust the extraction
   - You use it daily
   - You don't go back to manual task creation

5. **Metrics** ✅
   - 10+ notes processed with tasks
   - 30+ tasks reviewed
   - Clear patterns in approval decisions

---

## Next Steps

**After Phase 7.1 is stable:**

- **Phase 7.2:** Project activation and breakdown (Weeks 4-5)
- **Phase 7.3:** SeleneChat enhanced display (Week 6)
- **Phase 7.4:** Bidirectional sync from Things (Weeks 7-8)
- **Phase 7.5:** Cloud AI refinement (Month 2)
- **Phase 8:** Web research assistant (Month 3)

---

## Related Documentation

- **[Phase 7 Roadmap](../roadmap/16-PHASE-7-THINGS.md)** - Full Things integration plan
- **[Architecture](../architecture/things-integration.md)** - System architecture
- **[User Stories](../user-stories/things-integration-stories.md)** - ADHD-focused scenarios
- **[ADHD Principles](../../.claude/ADHD_Principles.md)** - Core ADHD design principles

---

**Document Status:** ✅ Complete and Ready for Implementation
**Next Action:** Apply database migration and begin testing
**Owner:** Chase Easterling
**Created:** 2025-11-25
