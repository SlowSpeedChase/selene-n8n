# US-034: Project Completion Tracking

**Status:** draft
**Priority:** normal
**Effort:** S
**Phase:** 7.2f.5
**Created:** 2026-01-04
**Updated:** 2026-01-04

---

## User Story

As an **ADHD user who finishes projects**,
I want **completed projects automatically recognized and celebrated**,
So that **I get the dopamine hit of completion and see my progress**.

---

## Context

ADHD brains need external validation and visible progress. When all tasks in a project complete, that's an achievement worth marking. Automatic detection and celebration reinforces the habit of finishing things.

---

## Acceptance Criteria

- [ ] When all tasks in project are completed (via status sync)
- [ ] Project marked as completed in `project_metadata`
- [ ] Completion logged to `detected_patterns` for productivity analysis
- [ ] SeleneChat shows celebration/acknowledgment message
- [ ] Option to archive project in Things (if API supports)

---

## ADHD Design Check

- [x] **Reduces friction?** No manual archiving needed
- [x] **Visible?** Celebration surfaces achievement
- [x] **Externalizes cognition?** System tracks completion

---

## Technical Notes

- Dependencies: Workflow 09 (Status Sync) must be operational
- Affected components: Workflow 09 (add completion detection), SeleneChat
- Design doc: [Project Grouping Design](../../plans/2026-01-01-project-grouping-design.md) (Phase 7.2e section)

**Implementation from design doc:**
```
SQL: Check project completion
WHERE task_count > 0
  AND task_count = completed_task_count
  AND status = 'active'

For each:
- Script: complete-project.scpt (optional)
- SQL: Update status = 'completed', completed_at = now
- SQL: Log pattern for productivity analysis
```

---

## Links

- **Branch:** (added when active)
- **PR:** (added when complete)
- **Parent Epic:** US-021 (Automatic Project Grouping)
- **Design doc:** docs/plans/2026-01-01-project-grouping-design.md
