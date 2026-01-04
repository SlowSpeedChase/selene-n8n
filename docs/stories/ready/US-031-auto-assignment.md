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

**Implementation from design doc:**
```
After "Store Task Metadata" node, add:

1. SQL: Find project for this concept
   SELECT things_project_id FROM project_metadata
   WHERE primary_concept = ? OR related_concepts LIKE ?
   ORDER BY task_count DESC LIMIT 1

2. If exists:
   - Script: assign-to-project.scpt
   - SQL: Update task_metadata.things_project_id

3. If not:
   - Leave in inbox (Workflow 08 will batch later)
```

---

## Links

- **Branch:** (added when active)
- **PR:** (added when complete)
- **Parent Epic:** US-021 (Automatic Project Grouping)
- **Design doc:** docs/plans/2026-01-01-project-grouping-design.md
