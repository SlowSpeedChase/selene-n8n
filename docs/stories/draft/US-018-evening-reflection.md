# US-018: Evening Reflection

**Status:** draft
**Priority:** 🟢 normal
**Effort:** M
**Created:** 2026-01-04
**Updated:** 2026-01-04

---

## User Story

As an **ADHD user who needs closure**,
I want **an evening prompt to review completed tasks and set tomorrow's intention**,
So that **I can celebrate wins and plan without anxiety**.

---

## Context

ADHD brains often forget what they accomplished - leading to "I did nothing today" feelings even after productive days. Evening reflection shows concrete evidence of progress, provides dopamine feedback, and sets tomorrow's intention before the day ends (when motivation is still present).

---

## Acceptance Criteria

- [ ] Evening notification at configurable time
- [ ] Shows tasks completed today with celebratory framing
- [ ] Acknowledges incomplete tasks without shame
- [ ] Prompts for tomorrow's top priority (optional)
- [ ] Shows streak of daily check-ins (gamification)

---

## ADHD Design Check

- [x] **Reduces friction?** One-tap review, not journaling
- [x] **Visible?** Today's wins visible, not forgotten
- [x] **Externalizes cognition?** System remembers what you accomplished

---

## Technical Notes

- Dependencies: US-012 (Completion Tracking), US-017 (Daily Planning)
- Affected components: SeleneChat notifications, daily workflow
- Evening workflow triggered by schedule
- Query task_metadata WHERE completed_at = today
- Celebratory tone: "You completed 4 tasks today!"
- Tomorrow's intention stored for morning prompt
- Track consecutive days for streak display

---

## Links

- **Branch:** (added when active)
- **PR:** (added when complete)
- **Source:** docs/user-stories/things-integration-stories.md (Story F.3)
