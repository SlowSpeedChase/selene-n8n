# US-021: Automatic Project Grouping

**Status:** draft
**Priority:** 🔥 critical
**Effort:** L
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

## Technical Notes

- Dependencies: US-001 (Auto-Extract Tasks), US-002 (Energy Level)
- Affected components: Workflow 08, project_metadata table, Things MCP
- Phases: 7.2a (basic creation), 7.2b (auto-assignment), 7.2c (headings), 7.2d (oversized detection)
- Design doc: docs/plans/2026-01-01-project-grouping-design.md

---

## Links

- **Branch:** (added when active)
- **PR:** (added when complete)
- **Design doc:** docs/plans/2026-01-01-project-grouping-design.md
