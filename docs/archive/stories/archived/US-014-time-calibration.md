# US-014: Time Estimation Calibration

**Status:** draft
**Priority:** 🟡 high
**Effort:** L
**Created:** 2026-01-04
**Updated:** 2026-01-04

---

## User Story

As an **ADHD user with time blindness and planning fallacy**,
I want **Selene to learn my actual completion times**,
So that **estimates become realistic, not optimistic**.

---

## Context

ADHD users chronically underestimate task duration (planning fallacy). Initial estimates are based on task type, but actual completion data is gold. After enough data, Selene can say "your 'writing' tasks average 90 minutes" and apply that to future estimates. Data beats intuition.

---

## Acceptance Criteria

- [ ] System calculates actual completion time (completed_at - created_at)
- [ ] Compares to estimated_minutes for each task
- [ ] Adjusts future estimates for similar task types
- [ ] Shows calibration progress: "Estimates now 85% accurate"
- [ ] User can see variance patterns by task type

---

## ADHD Design Check

- [x] **Reduces friction?** Automatic learning, no manual time tracking
- [x] **Visible?** Shows estimate accuracy improving over time
- [x] **Externalizes cognition?** System compensates for time blindness

---

## Technical Notes

- Dependencies: US-012 (Completion Tracking), US-003 (Time Estimation)
- Affected components: detected_patterns table, LLM prompts
- Calculate: (completed_at - created_at) in minutes
- Group by task_type and context_tags
- Store rolling average in detected_patterns
- Apply to LLM prompt: "User's 'writing' tasks average 90 minutes"

---

## Links

- **Branch:** (added when active)
- **PR:** (added when complete)
- **Source:** docs/user-stories/things-integration-stories.md (Story 4.3)
