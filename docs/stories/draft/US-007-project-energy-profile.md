# US-007: Project Energy Profile

**Status:** draft
**Priority:** 🟢 normal
**Effort:** S
**Created:** 2026-01-04
**Updated:** 2026-01-04

---

## User Story

As an **ADHD user with limited high-energy time**,
I want **to see the overall energy profile of each project**,
So that **I can assess if a project fits my current capacity**.

---

## Context

Some projects are mostly high-energy tasks, others are low-energy maintenance. Knowing a project's energy profile helps users avoid starting high-energy projects during burnout periods and balance their portfolio of active work.

---

## Acceptance Criteria

- [ ] Each project has energy profile: "high-energy", "mixed", or "low-energy"
- [ ] Profile calculated from all tasks' energy_required values
- [ ] Visible in project_metadata and SeleneChat
- [ ] Helps with project selection decisions

---

## ADHD Design Check

- [ ] **Reduces friction?** No analysis needed - profile is computed
- [ ] **Visible?** Energy commitment shown upfront
- [ ] **Externalizes cognition?** System aggregates task data

---

## Technical Notes

- Dependencies: US-002 (energy levels), US-006 (projects)
- Affected components: project_metadata table, SeleneChat
- Calculate from task_metadata.energy_required distribution
- Recalculate when tasks added/completed

---

## Links

- **Source:** docs/user-stories/things-integration-stories.md (Story 2.2)
