# US-019: "What Should I Work On Now?"

**Status:** draft
**Priority:** 🔥 critical
**Effort:** L
**Created:** 2026-01-04
**Updated:** 2026-01-04

---

## User Story

As an **ADHD user struggling to choose next task**,
I want **a "moment view" that suggests the optimal task for right now**,
So that **I can start working without analysis paralysis**.

---

## Context

The hardest part of task management isn't tracking - it's starting. When faced with a list, ADHD brains freeze. "What Should I Do Now?" removes choice entirely. One task, right now, based on current energy, available time, and task priority. Just say "yes" and start.

---

## Acceptance Criteria

- [ ] One-tap "What now?" button in SeleneChat
- [ ] Returns SINGLE best task for current moment
- [ ] Considers: current energy, available time, task priority, overwhelm
- [ ] Shows task with "Start" button and "Skip" option
- [ ] Skipping shows next best option (max 3 skips then encouragement)

---

## ADHD Design Check

- [x] **Reduces friction?** No choice = no paralysis
- [x] **Visible?** One task, full screen, can't ignore
- [x] **Externalizes cognition?** System makes the decision for you

---

## Technical Notes

- Dependencies: US-002 (Energy), US-003 (Time), US-004 (Overwhelm)
- Affected components: SeleneChat MomentView
- Algorithm: score = f(energy_match, time_fit, priority, -overwhelm, -age)
- User can indicate current energy state before asking
- Track skipped tasks to learn preferences
- "Start" opens task in Things for tracking

---

## Links

- **Branch:** (added when active)
- **PR:** (added when complete)
- **Source:** docs/user-stories/things-integration-stories.md (Story F.4)
