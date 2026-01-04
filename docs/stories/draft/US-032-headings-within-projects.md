# US-032: Headings Within Projects

**Status:** draft
**Priority:** normal
**Effort:** S
**Phase:** 7.2f.3
**Created:** 2026-01-04
**Updated:** 2026-01-04

---

## User Story

As an **ADHD user viewing a project in Things**,
I want **tasks organized under headings by type**,
So that **I can scan and find what I need without reading every task**.

---

## Context

Projects with 10+ tasks become walls of text. Headings create visual structure using task_type (Action, Research, Communication, etc.). This provides scannable organization without requiring the user to manually categorize.

---

## Acceptance Criteria

- [ ] Tasks grouped by `task_type` as headings within Things project
- [ ] Pre-work: Verify Things AppleScript/URL scheme supports heading assignment
- [ ] If not supported: Document workaround (task notes prefix)
- [ ] New tasks auto-assigned to correct heading

---

## ADHD Design Check

- [x] **Reduces friction?** No manual categorization
- [x] **Visible?** Visual structure in project view
- [ ] **Externalizes cognition?** Partially - still requires scanning

---

## Technical Notes

- Dependencies: Phase 7.2f.2 (Auto-Assignment)
- Affected components: Things bridge scripts, Workflow 07
- Scripts: `set-heading.scpt` (new)
- Design doc: [Project Grouping Design](../../plans/2026-01-01-project-grouping-design.md) (Phase 7.2c section)

**Pre-work investigation needed:**
- [ ] Can AppleScript assign headings to tasks?
- [ ] Can things-mcp assign headings?
- [ ] If not: Document workaround (task notes prefix)

---

## Links

- **Branch:** (added when active)
- **PR:** (added when complete)
- **Parent Epic:** US-021 (Automatic Project Grouping)
- **Design doc:** docs/plans/2026-01-01-project-grouping-design.md
