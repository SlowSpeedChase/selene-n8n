# US-008: Project Time Estimation

**Status:** draft
**Priority:** 🟡 high
**Effort:** S
**Created:** 2026-01-04
**Updated:** 2026-01-04

---

## User Story

As an **ADHD user who underestimates project scope**,
I want **to see total estimated time for project completion**,
So that **I can make realistic commitments**.

---

## Context

The "planning fallacy" is amplified in ADHD - projects feel quick until you add up the tasks. Showing total time commitment prevents over-committing and helps users understand why projects take longer than expected.

---

## Acceptance Criteria

- [ ] Project shows sum of all task estimated_minutes
- [ ] Displayed as "Est. total: 6h 30m"
- [ ] Visible in Things project notes and SeleneChat
- [ ] Updates as tasks are added/completed

---

## ADHD Design Check

- [ ] **Reduces friction?** No mental math required
- [ ] **Visible?** Total scope is explicit
- [ ] **Externalizes cognition?** System sums task times

---

## Technical Notes

- Dependencies: US-003 (time estimation), US-006 (projects)
- Affected components: project_metadata table, SeleneChat
- Sum task_metadata.estimated_minutes where things_project_id matches
- Store in project_metadata.estimated_total_time

---

## Links

- **Source:** docs/user-stories/things-integration-stories.md (Story 2.3)
