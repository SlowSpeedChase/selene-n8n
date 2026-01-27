# US-021: Automatic Project Grouping (Epic)

**Status:** draft (epic)
**Priority:** 🔥 critical
**Effort:** L (aggregate)
**Phase:** 7.2f (umbrella)
**Created:** 2026-01-04
**Updated:** 2026-01-04

---

## User Story

As an **ADHD user with scattered tasks across topics**,
I want **related tasks automatically grouped into Things projects**,
So that **I don't have to manually organize and can see work by theme**.

---

## Context

Tasks extracted from notes naturally cluster around concepts (web-design, book-writing, home-improvement). Manual project creation requires decision-making that ADHD brains avoid. Auto-grouping creates visual structure without cognitive overhead, making scattered thoughts feel organized.

---

## Acceptance Criteria

- [ ] 3+ tasks sharing a concept triggers project creation
- [ ] Project name is human-readable (LLM-generated)
- [ ] Existing inbox tasks move to new project
- [ ] New tasks auto-assign to matching projects
- [ ] Project shows energy profile and time estimate
- [ ] Daily workflow scans for new grouping opportunities

---

## ADHD Design Check

- [x] **Reduces friction?** Zero decisions - projects appear automatically
- [x] **Visible?** Related work grouped visually
- [x] **Externalizes cognition?** System organizes, not user

---

## Sub-Stories (Phase 7.2f)

| Phase | Story | Title | Status |
|-------|-------|-------|--------|
| 7.2f.1 | [US-006](../done/US-006-auto-create-projects.md) | Basic Project Creation | done |
| 7.2f.2 | [US-031](../ready/US-031-auto-assignment.md) | Auto-Assignment for New Tasks | ready |
| 7.2f.3 | [US-032](US-032-headings-within-projects.md) | Headings Within Projects | draft |
| 7.2f.4 | [US-033](US-033-oversized-task-detection.md) | Oversized Task Detection | draft |
| 7.2f.5 | [US-034](US-034-project-completion.md) | Project Completion Tracking | draft |
| 7.2f.6 | [US-035](US-035-sub-project-suggestions.md) | Sub-Project Suggestions | draft |

---

## Technical Notes

- Dependencies: US-001 (Auto-Extract Tasks), US-002 (Energy Level)
- Affected components: Workflow 07, Workflow 08, project_metadata table, Things MCP
- Design doc: docs/plans/2026-01-01-project-grouping-design.md

---

## Links

- **Branch:** (work tracked via sub-stories)
- **PR:** (work tracked via sub-stories)
- **Design doc:** docs/plans/2026-01-01-project-grouping-design.md
