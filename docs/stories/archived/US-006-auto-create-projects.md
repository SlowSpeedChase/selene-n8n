# US-006: Auto-Create Projects from Concept Clusters

**Status:** done
**Priority:** 🔥 critical
**Effort:** L
**Phase:** 7.2f.1
**Created:** 2026-01-04
**Updated:** 2026-01-04
**Completed:** 2026-01-04 (Phase 7.2f.1 complete)

---

## User Story

As an **ADHD user with multiple ongoing interests**,
I want **related notes and tasks automatically grouped into Things projects**,
So that **I don't have to manually organize my growing task list**.

---

## Context

ADHD users often have many parallel interests but struggle with organization. When 3+ notes share a concept, they likely represent a project worth tracking. Automatic project creation provides structure without requiring the user to build it.

---

## Acceptance Criteria

- [ ] When 3+ notes share a primary concept, system suggests project creation
- [ ] Project name is derived from concept + LLM interpretation
- [ ] Related tasks are automatically moved to the project in Things
- [ ] User can review and rename before final creation

---

## ADHD Design Check

- [ ] **Reduces friction?** No decision fatigue about categorization
- [ ] **Visible?** Related items stay visible together
- [ ] **Externalizes cognition?** System detects patterns

---

## Technical Notes

- Dependencies: US-001, concept extraction (Workflow 02)
- Affected components: Workflow 08, Things MCP
- Daily workflow runs clustering analysis
- LLM prompt: "Given these notes, is this a cohesive project?"
- Create Things project via MCP

---

## Links

- **Branch:** phase-7.2f/project-grouping (merged)
- **PR:** Merged to main
- **Parent Epic:** US-021 (Automatic Project Grouping)
- **Source:** docs/user-stories/things-integration-stories.md (Story 2.1)
