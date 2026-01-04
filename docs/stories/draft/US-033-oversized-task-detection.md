# US-033: Oversized Task Detection

**Status:** draft
**Priority:** high
**Effort:** M
**Phase:** 7.2f.4
**Created:** 2026-01-04
**Updated:** 2026-01-04

---

## User Story

As an **ADHD user who sometimes captures overwhelming tasks**,
I want **large tasks flagged for breakdown before they hit my task list**,
So that **I don't avoid them due to overwhelm**.

---

## Context

ADHD brains avoid tasks that feel too big. A task like "Redesign entire website" paralyzes action. Detecting oversized tasks and routing them for breakdown creates actionable pieces. This prevents task avoidance and the guilt spiral that follows.

---

## Acceptance Criteria

- [ ] Tasks with `overwhelm_factor > 7` OR `estimated_minutes >= 240` flagged
- [ ] Flagged tasks reclassified as `needs_planning`
- [ ] Discussion thread created in SeleneChat for breakdown
- [ ] After breakdown: sub-tasks inherit concept
- [ ] Sub-tasks auto-assign to parent project (via 7.2f.2)

---

## ADHD Design Check

- [x] **Reduces friction?** Prevents paralysis from big tasks
- [x] **Visible?** Surfaces in SeleneChat for action
- [x] **Externalizes cognition?** System detects overwhelm, not user

---

## Technical Notes

- Dependencies: Phase 7.2f.2 (Auto-Assignment)
- Affected components: Workflow 07 (add detection after task creation)
- Scripts: `flag_for_planning(task_id)` function
- Design doc: [Project Grouping Design](../../plans/2026-01-01-project-grouping-design.md) (Phase 7.2d section)

**Implementation from design doc:**
```
SQL: Check for oversized task
WHERE overwhelm_factor > 7 OR estimated_minutes >= 240

If true:
- SQL: Update classification to 'needs_planning'
- SQL: Insert discussion_thread for SeleneChat
```

---

## Links

- **Branch:** (added when active)
- **PR:** (added when complete)
- **Parent Epic:** US-021 (Automatic Project Grouping)
- **Design doc:** docs/plans/2026-01-01-project-grouping-design.md
