# US-004: Overwhelm Factor Tracking

**Status:** draft
**Priority:** 🟡 high
**Effort:** M
**Created:** 2026-01-04
**Updated:** 2026-01-04

---

## User Story

As an **ADHD user who experiences task paralysis**,
I want **tasks tagged with an overwhelm factor (1-10)**,
So that **I can identify and break down overwhelming tasks**.

---

## Context

Some tasks feel impossible not because they're hard, but because they're emotionally heavy or vague. Tracking overwhelm helps identify which tasks will cause procrastination before they become stuck. High-overwhelm tasks can be proactively broken down.

---

## Acceptance Criteria

- [ ] Each task has overwhelm_factor between 1-10
- [ ] Factor considers task complexity, vagueness, and emotional weight
- [ ] Tasks with overwhelm > 7 are flagged for review
- [ ] High overwhelm tasks trigger "break it down" suggestions

---

## ADHD Design Check

- [ ] **Reduces friction?** Identifies blockers before they block
- [ ] **Visible?** Overwhelm is quantified, not hidden
- [ ] **Externalizes cognition?** System flags problems proactively

---

## Technical Notes

- Dependencies: US-001
- Affected components: LLM prompt, task_metadata table
- LLM analyzes task clarity, scope, and emotional tone
- Store in task_metadata.overwhelm_factor
- Phase 7.4: Trigger intervention workflow for overwhelm > 7

---

## Links

- **Source:** docs/user-stories/things-integration-stories.md (Story 1.4)
