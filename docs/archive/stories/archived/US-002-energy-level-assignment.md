# US-002: Energy Level Assignment

**Status:** ready
**Priority:** 🔥 critical
**Effort:** M
**Created:** 2026-01-04
**Updated:** 2026-01-04

---

## User Story

As an **ADHD user with variable energy throughout the day**,
I want **tasks tagged with required energy level (high/medium/low)**,
So that **I can match tasks to my current energy state**.

---

## Context

ADHD brains have unpredictable energy fluctuations. Attempting high-cognitive tasks during low-energy periods leads to frustration and failure. By tagging tasks with energy requirements, users can work WITH their brain instead of against it - picking appropriate tasks for their current state.

---

## Acceptance Criteria

- [ ] Every auto-created task has an energy_required field
- [ ] Energy assignment is based on task complexity and note's energy_level
- [ ] Energy is visible in Things task notes ("Energy: high")
- [ ] SeleneChat displays energy with emoji indicators

---

## ADHD Design Check

- [x] **Reduces friction?** No decision about task appropriateness - it's tagged
- [x] **Visible?** Emoji indicators enable fast visual scanning
- [x] **Externalizes cognition?** System tracks energy requirements

---

## Technical Notes

- Dependencies: US-001 (task extraction)
- Affected components: LLM prompt, task_metadata table, SeleneChat UI
- Derive from processed_notes.energy_level
- LLM considers task complexity (creative > routine, learning > executing)
- Store in task_metadata.energy_required
- Display with visual indicators

---

## Links

- **Branch:** (added when active)
- **PR:** (added when complete)
- **Source:** docs/user-stories/things-integration-stories.md (Story 1.2)
