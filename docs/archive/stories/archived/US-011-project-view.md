# US-011: Project View with Task List

**Status:** draft
**Priority:** 🟢 normal
**Effort:** L
**Created:** 2026-01-04
**Updated:** 2026-01-04

---

## User Story

As a **user working on a specific project**,
I want **to see all project notes and tasks in one view**,
So that **I have full context without switching between apps**.

---

## Context

Projects in Things become more powerful when paired with the notes that spawned them. Currently switching between Things and SeleneChat breaks flow. A unified project view keeps all related context together, supporting the ADHD need for object permanence.

---

## Acceptance Criteria

- [ ] SeleneChat shows Projects list from project_metadata
- [ ] Clicking project shows: notes, tasks, energy profile, time estimate
- [ ] Tasks grouped by status (incomplete / completed)
- [ ] Can navigate to source notes from project view
- [ ] "Open in Things" button opens project in Things app

---

## ADHD Design Check

- [x] **Reduces friction?** No app switching for full context
- [x] **Visible?** Everything related stays together
- [x] **Externalizes cognition?** Visual project mind-map without building it manually

---

## Technical Notes

- Dependencies: US-006 (Auto-Create Projects), US-009 (View Related Tasks)
- Affected components: SeleneChat ProjectView, project_metadata table
- New ProjectView in SeleneChat
- Query project_metadata for project list
- Join task_metadata + Things MCP for tasks
- Join raw_notes via note_project_links table

---

## Links

- **Branch:** (added when active)
- **PR:** (added when complete)
- **Source:** docs/user-stories/things-integration-stories.md (Story 3.3)
