# US-003: Time Estimation

**Status:** ready
**Priority:** 🔥 critical
**Effort:** M
**Created:** 2026-01-04
**Updated:** 2026-01-04

---

## User Story

As an **ADHD user with time blindness**,
I want **realistic time estimates for each task**,
So that **I can plan my day without over-committing**.

---

## Context

Time blindness is a core ADHD challenge - tasks feel like they'll take "a few minutes" when they actually take hours. Concrete time estimates make the invisible visible, preventing over-scheduling and reducing the shame of "not getting enough done."

---

## Acceptance Criteria

- [ ] Every task includes estimated_minutes (5, 15, 30, 60, 120, 240)
- [ ] Estimates are based on task type and past completion patterns
- [ ] Visible in Things notes ("Est: 30 min")
- [ ] Over time, estimates improve based on actual completion time

---

## ADHD Design Check

- [x] **Reduces friction?** No guessing - time is provided
- [x] **Visible?** Concrete numbers combat time blindness
- [x] **Externalizes cognition?** System learns patterns, not user

---

## Technical Notes

- Dependencies: US-001 (task extraction)
- Affected components: LLM prompt, task_metadata table
- LLM provides initial estimates based on task type
- Store in task_metadata.estimated_minutes
- Phase 7.4: Compare estimated vs. actual (completion_time - created_at)
- Adjust future estimates based on user's patterns

---

## Links

- **Branch:** (added when active)
- **PR:** (added when complete)
- **Source:** docs/user-stories/things-integration-stories.md (Story 1.3)
