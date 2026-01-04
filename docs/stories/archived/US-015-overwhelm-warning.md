# US-015: Overwhelm Early Warning

**Status:** draft
**Priority:** 🟢 normal
**Effort:** M
**Created:** 2026-01-04
**Updated:** 2026-01-04

---

## User Story

As an **ADHD user prone to burnout**,
I want **Selene to detect when I'm accumulating too many high-overwhelm tasks**,
So that **I can course-correct before hitting a wall**.

---

## Context

Task paralysis often sneaks up - by the time you realize it, you're already stuck. Proactive detection of accumulating overwhelm enables intervention while still manageable. The system validates that tasks ARE overwhelming (it's not "just you") and suggests concrete actions.

---

## Acceptance Criteria

- [ ] System tracks average overwhelm_factor over time
- [ ] If average rises above threshold (e.g., 6.5), trigger alert
- [ ] Notification: "You have 5 high-overwhelm tasks. Consider breaking them down."
- [ ] Suggests specific tasks to postpone or simplify
- [ ] Alerts are gentle, not anxiety-inducing

---

## ADHD Design Check

- [x] **Reduces friction?** Prevents the paralysis spiral before it starts
- [x] **Visible?** Makes invisible stress visible and quantified
- [x] **Externalizes cognition?** System catches patterns you'd miss

---

## Technical Notes

- Dependencies: US-004 (Overwhelm Factor), US-012 (Completion Tracking)
- Affected components: n8n workflow, SeleneChat notifications
- Daily pattern detection workflow
- Calculate: avg(overwhelm_factor) for incomplete tasks
- Check: tasks with overwhelm > 7 AND created_at > 2 weeks ago
- Trigger: gentle notification in SeleneChat
- Suggest "break it down" action for specific high-overwhelm tasks

---

## Links

- **Branch:** (added when active)
- **PR:** (added when complete)
- **Source:** docs/user-stories/things-integration-stories.md (Story 4.4)
