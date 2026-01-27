# US-001: Auto-Extract Tasks from Voice Notes

**Status:** ready
**Priority:** 🔥 critical
**Effort:** L
**Created:** 2026-01-04
**Updated:** 2026-01-04

---

## User Story

As an **ADHD user who captures ideas via voice notes**,
I want **tasks automatically extracted and created in Things**,
So that **I don't have to remember or manually process my capture dump**.

---

## Context

Voice notes capture thoughts in the moment but create a processing burden later. For ADHD users, this "inbox" of unprocessed notes becomes invisible and overwhelming. Automatic task extraction externalizes working memory - the system remembers what needs doing, not the user.

---

## Acceptance Criteria

- [ ] When I send a voice note from Drafts that contains action items
- [ ] Selene processes the note and identifies actionable tasks
- [ ] Tasks appear in my Things inbox within 2 minutes
- [ ] Task titles are clear and action-oriented (verb-first)
- [ ] Original note content is linked in task notes field

---

## ADHD Design Check

- [x] **Reduces friction?** Zero decisions - tasks appear automatically
- [x] **Visible?** Tasks in Things inbox are visible daily
- [x] **Externalizes cognition?** System extracts and tracks, not user

---

## Technical Notes

- Dependencies: Workflow 01 (Ingestion), Ollama, Things MCP
- Affected components: n8n workflow, task_metadata table
- Design doc: See Phase 7.1 implementation plans
- LLM prompt must extract verb-first task descriptions
- Handle multiple tasks per note
- Link back to raw_note_id in task_metadata table
- Store Things task ID for bi-directional tracking

---

## Links

- **Branch:** (added when active)
- **PR:** (added when complete)
- **Source:** docs/user-stories/things-integration-stories.md (Story 1.1)
