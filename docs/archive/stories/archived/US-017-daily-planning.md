# US-017: Daily Planning Ritual

**Status:** draft
**Priority:** 🟡 high
**Effort:** M
**Created:** 2026-01-04
**Updated:** 2026-01-04

---

## User Story

As an **ADHD user who needs daily reset**,
I want **a morning planning prompt that shows today's tasks + energy forecast**,
So that **I start the day with clarity and realistic expectations**.

---

## Context

Mornings are vulnerable for ADHD - decision fatigue hits before coffee kicks in. A structured morning prompt removes the "what should I do?" paralysis. Shows: your energy prediction for today, tasks that match, and a realistic goal count. Sets intention without overwhelming.

---

## Acceptance Criteria

- [ ] Morning notification/prompt at configurable time
- [ ] Shows predicted energy pattern for the day
- [ ] Lists suggested tasks matched to energy forecast
- [ ] Allows quick selection of "today's focus" (max 3 tasks)
- [ ] Can snooze or skip without guilt messaging

---

## ADHD Design Check

- [x] **Reduces friction?** Pre-made decisions, just approve
- [x] **Visible?** Day's plan visible in one glance
- [x] **Externalizes cognition?** System proposes, you dispose

---

## Technical Notes

- Dependencies: US-002 (Energy Level), US-016 (Time Blocking)
- Affected components: SeleneChat notifications, daily workflow
- Morning workflow triggered by schedule or app open
- Pull incomplete tasks, sort by energy match for predicted state
- Limit suggestions to realistic count (3-5 max)
- Store "daily focus" selection for evening review

---

## Links

- **Branch:** (added when active)
- **PR:** (added when complete)
- **Source:** docs/user-stories/things-integration-stories.md (Story F.2)
