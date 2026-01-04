# US-009: View Related Tasks in Note Detail

**Status:** draft
**Priority:** 🔥 critical
**Effort:** M
**Created:** 2026-01-04
**Updated:** 2026-01-04

---

## User Story

As a **SeleneChat user reviewing my notes**,
I want **to see tasks created from each note**,
So that **I can track what actions came from my thoughts**.

---

## Context

Notes generate tasks, but that connection becomes invisible. Showing related tasks in the note detail view creates bidirectional navigation - users can trace thoughts to actions and actions back to their origin.

---

## Acceptance Criteria

- [ ] Note detail view includes "Related Tasks" section
- [ ] Shows task title, status (complete/incomplete), and energy level
- [ ] Real-time status from Things (not stale cache)
- [ ] "Open in Things" button for each task

---

## ADHD Design Check

- [ ] **Reduces friction?** No app-switching to see related tasks
- [ ] **Visible?** Tasks shown in context of originating thought
- [ ] **Externalizes cognition?** Connection is maintained automatically

---

## Technical Notes

- Dependencies: US-001, SeleneChat
- Affected components: SeleneChat NoteDetailView
- Query task_metadata by raw_note_id
- Fetch current status from Things MCP (async)
- Cache for 5 minutes to reduce API calls
- Deep link: things:///show?id={things_task_id}

---

## Links

- **Source:** docs/user-stories/things-integration-stories.md (Story 3.1)
