# US-005: No Duplicate Task Creation

**Status:** draft
**Priority:** 🟡 high
**Effort:** M
**Created:** 2026-01-04
**Updated:** 2026-01-04

---

## User Story

As a **user who sometimes manually creates tasks**,
I want **Selene to detect existing similar tasks in Things**,
So that **I don't end up with duplicate entries**.

---

## Context

Duplicate tasks create noise and confusion. When auto-extraction creates a task that already exists (perhaps manually created), the user ends up with two entries for the same work. Detection and deduplication keeps the task list clean.

---

## Acceptance Criteria

- [ ] Before creating task, Selene searches Things for similar titles (fuzzy match)
- [ ] If 80%+ match found, skip creation and link to existing task
- [ ] User is notified: "Linked to existing task: [title]"
- [ ] task_metadata stores existing things_task_id

---

## ADHD Design Check

- [ ] **Reduces friction?** Less clutter to manage
- [ ] **Visible?** Clear which task to work on
- [ ] **Externalizes cognition?** System handles deduplication

---

## Technical Notes

- Dependencies: US-001, Things MCP
- Affected components: n8n workflow
- Use Things MCP search before creating
- Fuzzy string matching (Levenshtein distance < 20%)
- If found: just create task_metadata entry, don't create new task

---

## Links

- **Source:** docs/user-stories/things-integration-stories.md (Story 1.5)
