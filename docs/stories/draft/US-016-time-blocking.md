# US-016: Time Blocking Assistant

**Status:** draft
**Priority:** 🟢 normal
**Effort:** XL
**Created:** 2026-01-04
**Updated:** 2026-01-04

---

## User Story

As an **ADHD user who needs structured time**,
I want **Selene to suggest when to work on tasks based on my calendar**,
So that **I can plan realistically without over-scheduling**.

---

## Context

ADHD users struggle with "phantom time" - imagining they have more free time than they actually do. By integrating calendar data with task time estimates, Selene can prevent over-commitment. Shows concrete blocks: "You have 3 hours of unscheduled time tomorrow. Here are tasks that fit."

---

## Acceptance Criteria

- [ ] Reads calendar data to identify free time blocks
- [ ] Suggests tasks that fit available time slots
- [ ] Respects energy patterns (high-energy tasks for high-energy times)
- [ ] Shows total committed time vs. available time
- [ ] Warns when scheduled tasks exceed available time

---

## ADHD Design Check

- [x] **Reduces friction?** No manual calendar + task juggling
- [x] **Visible?** Makes time concrete, not abstract
- [x] **Externalizes cognition?** System does the math you'd get wrong

---

## Technical Notes

- Dependencies: US-003 (Time Estimation), US-013 (Energy Accuracy)
- Affected components: Calendar integration (future), SeleneChat planning view
- Requires calendar API integration (Apple Calendar or Google)
- Match task.estimated_minutes to available time blocks
- Consider task.energy_required vs. time-of-day energy patterns
- Phase 8+ feature

---

## Links

- **Branch:** (added when active)
- **PR:** (added when complete)
- **Source:** docs/user-stories/things-integration-stories.md (Story F.1)
