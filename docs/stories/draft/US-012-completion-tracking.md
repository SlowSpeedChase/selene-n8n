# US-012: Task Completion Tracking

**Status:** draft
**Priority:** 🔥 critical
**Effort:** M
**Created:** 2026-01-04
**Updated:** 2026-01-04

---

## User Story

As a **user completing tasks in Things**,
I want **Selene to detect completion automatically**,
So that **my progress is reflected across both systems**.

---

## Context

Tasks completed in Things should update in Selene without manual intervention. This bidirectional sync provides dopamine feedback (seeing completed tasks) and enables pattern analysis for improving future estimates. Foundation for learning from user behavior.

---

## Acceptance Criteria

- [ ] Hourly sync checks task status via Things MCP
- [ ] When task completed in Things, completed_at timestamp stored in task_metadata
- [ ] SeleneChat shows checkmark on completed tasks
- [ ] Completed tasks remain visible but styled differently (grayed out)
- [ ] Sync failures are logged and retried

---

## ADHD Design Check

- [x] **Reduces friction?** No manual status updates needed
- [x] **Visible?** See completed tasks accumulate as proof of progress
- [x] **Externalizes cognition?** System tracks progress, not user

---

## Technical Notes

- Dependencies: US-001 (Auto-Extract Tasks)
- Affected components: n8n workflow 09, task_metadata table, SeleneChat TaskView
- Workflow 09 runs hourly
- Query Things MCP get-todo for each things_task_id
- Update task_metadata.completed_at if status changed
- Trigger pattern analysis workflow on completion

---

## Links

- **Branch:** (added when active)
- **PR:** (added when complete)
- **Source:** docs/user-stories/things-integration-stories.md (Story 4.1)
