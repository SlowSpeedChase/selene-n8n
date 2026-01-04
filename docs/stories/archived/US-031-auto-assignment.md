# US-031: Auto-Assignment for New Tasks

**Status:** ready
**Priority:** high
**Effort:** M
**Phase:** 7.2f.2
**Created:** 2026-01-04
**Updated:** 2026-01-04

---

## User Story

As an **ADHD user creating tasks throughout the day**,
I want **new tasks automatically assigned to matching projects**,
So that **I don't have to manually file tasks and they stay organized**.

---

## Context

When a new task is extracted from a note, it often relates to an existing project. Manual filing requires context-switching and decision-making that ADHD brains avoid. Auto-assignment keeps tasks organized without user intervention.

---

## Acceptance Criteria

- [ ] When new task is created (Workflow 07), check for matching project
- [ ] Concept overlap rule: assign to project with most existing tasks from that concept
- [ ] If tie: assign to most recently active project
- [ ] `task_metadata.things_project_id` updated immediately
- [ ] No LLM calls in hot path (pure SQL + script)
- [ ] Tasks without matching project stay in inbox (Workflow 08 batches later)

---

## ADHD Design Check

- [x] **Reduces friction?** Zero decisions - tasks auto-file
- [x] **Visible?** Tasks appear in correct project immediately
- [x] **Externalizes cognition?** System knows where tasks belong

---

## Technical Notes

- Dependencies: Phase 7.2f.1 (Basic Project Creation) - COMPLETE
- Affected components: Workflow 07 (modify after "Store Task Metadata" node)
- Scripts: `assign-to-project.scpt`
- Design doc: [Project Grouping Design](../../plans/2026-01-01-project-grouping-design.md) (Phase 7.2b section)

**Implementation (refined 2026-01-04):**

**Best-Overlap Matching Algorithm:**
```sql
-- Count how many of task's concepts match each project
-- Assign to project with most overlap (tie-breaker: task_count)
WITH task_concepts AS (
  SELECT value as concept FROM json_each(:task_concepts)
),
project_overlap AS (
  SELECT
    pm.things_project_id,
    pm.project_name,
    pm.task_count,
    SUM(CASE
      WHEN tc.concept = pm.primary_concept THEN 1
      WHEN tc.concept IN (SELECT value FROM json_each(pm.related_concepts)) THEN 1
      ELSE 0
    END) as overlap_count
  FROM project_metadata pm
  CROSS JOIN task_concepts tc
  WHERE pm.status = 'active'
  GROUP BY pm.things_project_id
)
SELECT things_project_id, project_name, overlap_count
FROM project_overlap
WHERE overlap_count > 0
ORDER BY overlap_count DESC, task_count DESC
LIMIT 1
```

**Workflow 07 modification (after "Store Task Metadata" node):**

1. New node: "Find Matching Project" (Function)
   - Input: task's `related_concepts` JSON array
   - Run best-overlap SQL query above
   - Output: `things_project_id` or null

2. New node: "Route by Project Match" (IF)
   - If `things_project_id` exists → assign path
   - Else → skip (stays in inbox)

3. New node: "Assign to Project" (Function)
   - Run: `assign-to-project.scpt` via osascript
   - Update: `task_metadata.things_project_id`

**Why best-overlap:**
- Task: `["home-renovation", "budgeting"]`
- Project A: `primary = "home-renovation"` → overlap = 1
- Project B: `primary = "budgeting", related = ["home-renovation"]` → overlap = 2
- Winner: Project B (better fit)

---

## Links

- **Branch:** (added when active)
- **PR:** (added when complete)
- **Parent Epic:** US-021 (Automatic Project Grouping)
- **Design doc:** docs/plans/2026-01-01-project-grouping-design.md
