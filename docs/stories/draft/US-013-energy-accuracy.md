# US-013: Energy Accuracy Analysis

**Status:** draft
**Priority:** 🟡 high
**Effort:** L
**Created:** 2026-01-04
**Updated:** 2026-01-04

---

## User Story

As an **ADHD user whose energy fluctuates unpredictably**,
I want **Selene to learn which energy assignments are accurate**,
So that **future task estimates match reality**.

---

## Context

Initial energy assignments are educated guesses. Over time, Selene should learn YOUR patterns - not generic ADHD advice. If you consistently complete "high-energy" writing tasks during low-energy afternoons, the system should adjust. Personalized learning validates your experience.

---

## Acceptance Criteria

- [ ] System compares estimated energy vs. actual completion patterns
- [ ] If high-energy tasks consistently completed during low-energy note times, adjust
- [ ] Confidence score increases over time as data accumulates
- [ ] Insights visible: "You complete 'writing' tasks best in afternoons"
- [ ] Adjustments apply to future task creation

---

## ADHD Design Check

- [x] **Reduces friction?** Removes guesswork from energy matching
- [x] **Visible?** Shows insights about your patterns
- [x] **Externalizes cognition?** System learns patterns you can't consciously track

---

## Technical Notes

- Dependencies: US-012 (Completion Tracking), US-002 (Energy Level Assignment)
- Affected components: detected_patterns table, LLM prompts
- Compare task_metadata.energy_required vs. raw_notes.energy_level at completion
- Store patterns in detected_patterns table
- Use for future LLM prompts: "User typically completes X type tasks in Y energy state"
- Display insights in SeleneChat dashboard

---

## Links

- **Branch:** (added when active)
- **PR:** (added when complete)
- **Source:** docs/user-stories/things-integration-stories.md (Story 4.2)
