# Things Project Grouping Design

**Status:** Approved
**Created:** 2026-01-01
**Author:** Chase Easterling + Claude

---

## Overview

Automatically organize tasks into Things projects based on shared concepts, with hierarchical structure and intelligent breakdown detection.

### Core Principles

1. **Concepts become projects** - 3+ tasks sharing a concept triggers project creation
2. **Outcome = project completion** - A project is "done" when all its tasks are done
3. **Hierarchical breakdown** - Large tasks get detected and broken down; projects have internal structure via headings
4. **Script-driven operations** - Deterministic scripts handle all Things operations; AI only for creative decisions
5. **Things authoritative, Selene caches** - Things is source of truth for state; Selene caches for fast queries

---

## Phased Implementation

### Phase 7.2a: Basic Project Creation
- Query `task_metadata` for tasks grouped by `related_concepts`
- 3+ tasks with shared concept → create Things project
- LLM generates human-readable project name
- Move existing inbox tasks into project
- Calculate project energy profile (aggregate from tasks)
- Store in `project_metadata` table
- **Trigger:** Daily schedule + on-demand webhook

### Phase 7.2b: Auto-Assignment for New Tasks
- When new task is created (Workflow 07), check if matching project exists
- **Concept overlap rule:** Assign to project with most existing tasks from that concept
- If tie: Assign to most recently active project
- Update `task_metadata.things_project_id`
- **No AI calls in hot path**

### Phase 7.2c: Headings Within Projects
- Use `task_type` directly as headings (Action, Research, Communication, etc.)
- **Pre-work:** Verify Things AppleScript/URL scheme supports heading assignment
- If not supported: Defer or use task notes prefix as workaround

### Phase 7.2d: Oversized Task Detection
- Flag tasks where `overwhelm_factor > 7` OR `estimated_minutes >= 240`
- Route to `needs_planning` → SeleneChat discussion thread
- After breakdown: Sub-tasks inherit concept → auto-assign to project (via 7.2b)

### Phase 7.2e: Project Completion
- When all tasks in project are completed (via status sync)
- Log to `detected_patterns` for productivity analysis
- Option to archive project in Things
- Surface completion celebration in SeleneChat

### Phase 7.2f: Sub-Project Suggestions (Approval-Only)
- After heading accumulates 5+ tasks with distinct sub-concept
- Surface suggestion in SeleneChat: "Spin off 'Frontend Work' as its own project?"
- User approves → Create new project, move tasks
- User declines → Don't suggest again for this heading

---

## Architecture

### Script-Driven Design

**Principle:** Deterministic scripts handle all Things operations. AI only involved for creative/classification decisions.

```
n8n Workflow → Deterministic Scripts → Things 3
                      ↑
                AI outputs structured data
                (only when creative decision needed)
```

### AI vs Script Responsibilities

| Feature | AI Role | Script Role |
|---------|---------|-------------|
| 7.2a Project creation | Generate name | `create_project(name, concept)` |
| 7.2b Auto-assignment | None | `assign_to_project(task_id, project_id)` |
| 7.2c Headings | None (use task_type) | `set_heading(task_id, heading)` |
| 7.2d Oversized detection | Classify if borderline | `flag_for_planning(task_id)` |
| 7.2e Completion | None | `mark_completed(project_id)` |
| 7.2f Sub-project suggestions | Generate suggestion text | `surface_suggestion(heading_id)` |

### Reusable Script Library

```
scripts/things-bridge/
├── create-project.scpt      # (name, notes, area?) → project_id
├── assign-to-project.scpt   # (task_id, project_id) → success
├── set-heading.scpt         # (task_id, heading) → success
├── get-task-status.scpt     # (task_id) → {status, completed_at}
├── get-project-tasks.scpt   # (project_id) → [task_ids]
├── complete-project.scpt    # (project_id) → success
├── add-task-to-things.scpt  # (existing) task creation
└── lib/
    └── things-helpers.scpt  # Shared utilities
```

### Structured Data Shapes (AI Outputs)

```javascript
// When AI generates a project name:
{
  "action": "create_project",
  "data": {
    "name": "Website Redesign",
    "concept": "web-design",
    "task_ids": ["abc123", "def456", "ghi789"]
  }
}

// When AI flags task for breakdown:
{
  "action": "flag_for_planning",
  "data": {
    "task_id": "xyz999",
    "reason": "overwhelm_factor_high",
    "suggested_breakdown": ["Research options", "Draft outline", "Review with team"]
  }
}

// When AI suggests sub-project:
{
  "action": "suggest_subproject",
  "data": {
    "source_heading": "Frontend Work",
    "suggested_name": "React Component Library",
    "task_ids": ["aaa", "bbb", "ccc", "ddd", "eee"]
  }
}
```

---

## Data Model

### Source of Truth Split

**Things = Authoritative for:**
- Task existence (is it there?)
- Task state (pending, completed, canceled)
- Due dates and scheduling
- Project membership (which project is it in?)
- User-made edits (renamed tasks, added notes)

**Selene = Authoritative for:**
- Task origin (which note spawned it)
- ADHD metadata (energy, overwhelm, estimated time)
- Concept/theme relationships
- Project-to-concept mapping
- Pattern analysis data

**Selene = Cache for:**
- Task state (synced from Things every 15 min)
- Project state (synced from Things)

### New Table: project_metadata

```sql
CREATE TABLE project_metadata (
    id INTEGER PRIMARY KEY AUTOINCREMENT,

    -- Things integration
    things_project_id TEXT NOT NULL UNIQUE,
    project_name TEXT NOT NULL,

    -- Concept linkage
    primary_concept TEXT NOT NULL,
    related_concepts TEXT,  -- JSON array of secondary concepts

    -- ADHD optimization
    energy_profile TEXT CHECK(energy_profile IN ('high', 'mixed', 'low')),
    total_estimated_minutes INTEGER DEFAULT 0,

    -- Counts (denormalized for quick access)
    task_count INTEGER DEFAULT 0,
    completed_task_count INTEGER DEFAULT 0,

    -- Lifecycle
    status TEXT DEFAULT 'active'
        CHECK(status IN ('active', 'completed', 'archived')),
    created_at TEXT DEFAULT CURRENT_TIMESTAMP,
    completed_at TEXT,
    last_synced_at TEXT,

    -- Things state (cached)
    things_status TEXT DEFAULT 'active'
        CHECK(things_status IN ('active', 'completed', 'canceled')),

    test_run TEXT
);

CREATE INDEX idx_project_metadata_concept ON project_metadata(primary_concept);
CREATE INDEX idx_project_metadata_things_id ON project_metadata(things_project_id);
CREATE INDEX idx_project_metadata_status ON project_metadata(status);
```

### Modifications to task_metadata

```sql
-- Add sync columns
ALTER TABLE task_metadata ADD COLUMN things_status TEXT DEFAULT 'pending'
    CHECK(things_status IN ('pending', 'completed', 'canceled'));
ALTER TABLE task_metadata ADD COLUMN things_due_date TEXT;
ALTER TABLE task_metadata ADD COLUMN things_modified_at TEXT;
ALTER TABLE task_metadata ADD COLUMN last_synced_at TEXT;
ALTER TABLE task_metadata ADD COLUMN sync_conflict INTEGER DEFAULT 0;
```

---

## Workflow Architecture

### Workflow 08: Project Detection & Creation

```
Trigger: Daily schedule (8am) + Manual webhook /project-detection

1. Query Concept Clusters (SQL only)
   └─ SELECT related_concepts, GROUP_CONCAT(things_task_id)
      FROM task_metadata
      WHERE things_project_id IS NULL
      GROUP BY related_concepts
      HAVING COUNT(*) >= 3

2. For each cluster:
   ├─ Check: Project exists for concept? (SQL lookup)
   │   └─ If yes: Skip to assignment step
   │
   ├─ LLM: Generate project name (ONLY AI CALL)
   │   └─ Input: concept + task titles
   │   └─ Output: { "name": "Website Redesign" }
   │
   ├─ Script: create-project.scpt
   │   └─ Input: name, concept
   │   └─ Output: things_project_id
   │
   ├─ SQL: Insert project_metadata
   │
   └─ Script: assign-to-project.scpt (loop)
       └─ Input: task_id, project_id
       └─ SQL: Update task_metadata.things_project_id

3. SQL: Calculate energy_profile
   └─ Aggregate from task energy_required values
   └─ >60% high → "high", >60% low → "low", else "mixed"

4. Log results to integration_logs
```

### Workflow 07 Modification: Auto-Assignment

```
After "Store Task Metadata" node, add:

1. SQL: Find project for this concept
   └─ SELECT things_project_id FROM project_metadata
      WHERE primary_concept = ? OR related_concepts LIKE ?
      ORDER BY task_count DESC LIMIT 1

   ├─ If exists:
   │   └─ Script: assign-to-project.scpt
   │   └─ SQL: Update task_metadata.things_project_id
   └─ If not:
       └─ Leave in inbox (Workflow 08 will batch later)

2. SQL: Check for oversized task
   └─ WHERE overwhelm_factor > 7 OR estimated_minutes >= 240

   └─ If true:
       └─ SQL: Update classification to 'needs_planning'
       └─ SQL: Insert discussion_thread for SeleneChat

(No AI calls in hot path)
```

### Workflow 09: Status Sync

```
Trigger: Every 15 minutes + on-demand webhook /sync-status

1. SQL: Get tasks needing sync
   └─ WHERE last_synced_at IS NULL
      OR last_synced_at < datetime('now', '-15 minutes')
   └─ LIMIT 50 (batch size)

2. For each task:
   └─ Script: get-task-status.scpt
   └─ Compare to cached things_status
   │   ├─ If changed:
   │   │   └─ SQL: Update cache
   │   │   └─ SQL: Log to integration_logs
   │   └─ If completed:
   │       └─ SQL: Set completed_at
   │       └─ Trigger: Pattern analysis
   └─ SQL: Update last_synced_at

3. SQL: Get projects needing sync
   └─ Same pattern as tasks

4. SQL: Recalculate project stats
   └─ UPDATE project_metadata SET
      task_count = (SELECT COUNT(*) FROM task_metadata WHERE things_project_id = ?),
      completed_task_count = (SELECT COUNT(*) FROM task_metadata
                              WHERE things_project_id = ? AND things_status = 'completed')

5. SQL: Check project completion
   └─ WHERE task_count > 0 AND task_count = completed_task_count AND status = 'active'
   └─ For each:
       └─ Script: complete-project.scpt (optional, if Things API supports)
       └─ SQL: Update status = 'completed', completed_at = now
       └─ SQL: Log pattern for productivity analysis

(No AI calls - pure sync)
```

---

## Things Integration

### Integration Stack

```
n8n Workflow → HTTP (optional) → AppleScript → Things 3
                                      ↑
                            things-mcp for complex queries
```

### Things MCP Usage

Use things-mcp (hildersantos/things-mcp) via wrapper for:
- Complex queries (search-todos)
- Operations AppleScript can't handle
- Future: bi-directional sync improvements

### Heading Support Investigation

Before 7.2c implementation, verify:
- [ ] Can AppleScript assign headings to tasks?
- [ ] Can things-mcp assign headings?
- [ ] If not: Document workaround (task notes prefix)

---

## Success Criteria

### Phase 7.2a: Basic Project Creation
- [ ] 3+ tasks with shared concept → project auto-created
- [ ] Project name is human-readable (not raw concept slug)
- [ ] Tasks moved from inbox to project in Things
- [ ] `project_metadata` row created with correct energy profile
- [ ] No duplicate projects for same concept

### Phase 7.2b: Auto-Assignment
- [ ] New task with matching concept → assigned to existing project immediately
- [ ] Concept overlap → assigned to project with most tasks
- [ ] `task_metadata.things_project_id` updated

### Phase 7.2c: Headings
- [ ] Tasks grouped by `task_type` within project
- [ ] (If heading API not available: graceful degradation documented)

### Phase 7.2d: Oversized Task Detection
- [ ] Tasks with overwhelm > 7 OR estimated_minutes >= 240 flagged
- [ ] Discussion thread created in SeleneChat
- [ ] Sub-tasks after breakdown auto-assign to parent project

### Phase 7.2e: Project Completion
- [ ] All tasks done → project marked completed
- [ ] Completion logged for pattern analysis
- [ ] SeleneChat shows celebration/acknowledgment

### Phase 7.2f: Sub-Project Suggestions
- [ ] 5+ tasks in heading with distinct sub-concept → suggestion surfaced
- [ ] Approval creates new project and moves tasks
- [ ] Decline suppresses future suggestions for that heading

---

## Future Enhancements (Post 7.2)

### Deadline-Based Planning
- User states deadline: "launch by Friday"
- System works backwards using time estimates
- Shows what's feasible vs. what to cut

### Things Areas Integration
- Auto-assign projects to Areas based on context_tags
- "work" tagged tasks → Work area

---

## Related Documentation

- [Things Integration Architecture](../architecture/things-integration.md)
- [User Stories: Things Integration](../user-stories/things-integration-stories.md)
- [ADHD Principles](../../.claude/ADHD_Principles.md)
- [Phase 7 Roadmap](../roadmap/16-PHASE-7-THINGS.md)

---

**Document Status:** Approved
**Next Step:** Create implementation plan with superpowers:writing-plans
