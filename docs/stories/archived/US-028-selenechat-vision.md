# US-028: SeleneChat Executive Function Dashboard

**Status:** draft
**Priority:** 🔥 critical
**Effort:** XL
**Created:** 2026-01-04
**Updated:** 2026-01-04

---

## User Story

As an **ADHD user needing direction**,
I want **SeleneChat to show me what to do next based on my current state**,
So that **I can act without decision paralysis**.

---

## Context

SeleneChat should be where you get *directed*, not where you *capture*. The vision: a dashboard showing recent notes + insights, plus a "Direct Me" feature that suggests the optimal next action based on energy, time, and priorities. Externalized executive function.

---

## Acceptance Criteria

- [ ] Dashboard shows recent notes with insights
- [ ] "Direct Me" button suggests optimal next task
- [ ] Considers current energy state (user can indicate)
- [ ] Shows task with one-tap start action
- [ ] Provides skip option with alternatives

---

## ADHD Design Check

- [x] **Reduces friction?** One button = direction
- [x] **Visible?** Dashboard overview without scrolling
- [x] **Externalizes cognition?** System decides, you execute

---

## Technical Notes

- Dependencies: US-019 (What Should I Do), US-001-003 (Task metadata)
- Affected components: New DashboardView, DirectMeView
- Three roles: Librarian (notes), Task Manager (tasks), Executive Director (direction)
- Design doc: docs/plans/2025-12-31-selenechat-vision-and-feedback-loop-design.md
- This is the capstone feature - requires most other stories first

---

## Links

- **Branch:** (added when active)
- **PR:** (added when complete)
- **Design doc:** docs/plans/2025-12-31-selenechat-vision-and-feedback-loop-design.md
