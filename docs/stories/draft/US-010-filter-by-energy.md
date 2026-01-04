# US-010: Filter Tasks by Energy Level

**Status:** draft
**Priority:** 🟡 high
**Effort:** M
**Created:** 2026-01-04
**Updated:** 2026-01-04

---

## User Story

As an **ADHD user with variable energy**,
I want **to filter all my tasks by energy level**,
So that **I can quickly find tasks matching my current state**.

---

## Context

When energy is low, scrolling through all tasks to find appropriate ones is exhausting. Energy-based filtering answers "what can I do right now?" without cognitive overhead.

---

## Acceptance Criteria

- [ ] SeleneChat has "Tasks" tab with energy filters
- [ ] Filter buttons: High / Medium / Low / All
- [ ] Shows task count for each energy level
- [ ] Clicking filter shows matching tasks across all notes

---

## ADHD Design Check

- [ ] **Reduces friction?** One tap to find appropriate tasks
- [ ] **Visible?** Energy counts shown upfront
- [ ] **Externalizes cognition?** Filtering is automatic

---

## Technical Notes

- Dependencies: US-002 (energy levels), SeleneChat
- Affected components: New TasksView in SeleneChat
- Query task_metadata grouped by energy_required
- Join with Things MCP for current status
- Filter incomplete tasks only (or toggle for completed)

---

## Links

- **Source:** docs/user-stories/things-integration-stories.md (Story 3.2)
