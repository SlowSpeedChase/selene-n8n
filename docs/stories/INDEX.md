# User Stories Index

**Last Updated:** 2026-01-04

---

## Dashboard

| State | Count | Limit |
|-------|-------|-------|
| Active | 0 | 5 max |
| Ready | 4 | - |
| Draft | 26 | - |
| Done | 0 | - |

**Command:** `./scripts/story.sh status`

---

## Active (In Progress)

*None currently*

---

## Ready (Actionable)

| ID | Title | Priority | Effort |
|----|-------|----------|--------|
| US-001 | [Auto-Extract Tasks from Voice Notes](ready/US-001-auto-extract-tasks.md) | critical | L |
| US-002 | [Energy Level Assignment](ready/US-002-energy-level-assignment.md) | critical | M |
| US-003 | [Time Estimation](ready/US-003-time-estimation.md) | critical | M |
| US-025 | [Feedback Pipeline](ready/US-025-feedback-pipeline.md) | high | M |

---

## Draft (Needs Refinement)

### Things Integration (Phase 7.1)

| ID | Title | Priority | Effort |
|----|-------|----------|--------|
| US-004 | [Overwhelm Factor Tracking](draft/US-004-overwhelm-factor.md) | high | M |
| US-005 | [No Duplicate Tasks](draft/US-005-no-duplicate-tasks.md) | high | M |

### Project Detection (Phase 7.2)

| ID | Title | Priority | Effort |
|----|-------|----------|--------|
| US-006 | [Auto-Create Projects](draft/US-006-auto-create-projects.md) | critical | L |
| US-007 | [Project Energy Profile](draft/US-007-project-energy-profile.md) | normal | S |
| US-008 | [Project Time Estimation](draft/US-008-project-time-estimation.md) | high | S |
| US-021 | [Automatic Project Grouping](draft/US-021-project-grouping.md) | critical | L |

### SeleneChat Display (Phase 7.3)

| ID | Title | Priority | Effort |
|----|-------|----------|--------|
| US-009 | [View Related Tasks](draft/US-009-view-related-tasks.md) | critical | M |
| US-010 | [Filter by Energy](draft/US-010-filter-by-energy.md) | high | M |
| US-011 | [Project View](draft/US-011-project-view.md) | normal | L |

### Status Sync & Patterns (Phase 7.4)

| ID | Title | Priority | Effort |
|----|-------|----------|--------|
| US-012 | [Completion Tracking](draft/US-012-completion-tracking.md) | critical | M |
| US-013 | [Energy Accuracy](draft/US-013-energy-accuracy.md) | high | L |
| US-014 | [Time Calibration](draft/US-014-time-calibration.md) | high | L |
| US-015 | [Overwhelm Warning](draft/US-015-overwhelm-warning.md) | normal | M |

### Future Features (Phase 8+)

| ID | Title | Priority | Effort |
|----|-------|----------|--------|
| US-016 | [Time Blocking](draft/US-016-time-blocking.md) | normal | XL |
| US-017 | [Daily Planning](draft/US-017-daily-planning.md) | high | M |
| US-018 | [Evening Reflection](draft/US-018-evening-reflection.md) | normal | M |
| US-019 | [What Should I Do Now](draft/US-019-what-should-i-do.md) | critical | L |
| US-020 | [Hyperfocus Capture](draft/US-020-hyperfocus-capture.md) | normal | M |
| US-027 | [Planning Persistence](draft/US-027-planning-persistence.md) | critical | L |
| US-028 | [Executive Function Dashboard](draft/US-028-selenechat-vision.md) | critical | XL |

### Infrastructure

| ID | Title | Priority | Effort |
|----|-------|----------|--------|
| US-022 | [n8n 2.x Upgrade](draft/US-022-n8n-upgrade.md) | high | L |
| US-023 | [Plan Archive Agent](draft/US-023-plan-archive-agent.md) | normal | M |
| US-024 | [SeleneChat Auto-Builder](draft/US-024-selenechat-auto-builder.md) | normal | S |
| US-026 | [SeleneChat UAT System](draft/US-026-selenechat-uat.md) | normal | M |
| US-029 | [Workflow Standardization](draft/US-029-workflow-standardization.md) | high | L |
| US-030 | [Process Gap Fixes](draft/US-030-process-gap-fixes.md) | high | M |

---

## Done (Completed)

*None yet*

---

## Story Workflow

```
draft/ → ready/ → active/ → done/
  │        │         │        │
Ideas   Refined   Working   Merged
         with       on
       criteria   branch
```

**Commands:**
```bash
./scripts/story.sh status              # Dashboard
./scripts/story.sh new <title>         # Create draft
./scripts/story.sh promote US-NNN      # Move to next state
./scripts/story.sh list [state]        # List stories
```

**Rules:**
- Max 5 active stories (ADHD: prevents overwhelm)
- Must have acceptance criteria before `ready/`
- Moving to `active/` creates git branch
- Branch naming: `US-NNN/brief-description`

---

## Legend

**Priority:**
- critical = Must have for MVP
- high = Important, do soon
- normal = Nice to have

**Effort:**
- S = Few hours
- M = 1-2 days
- L = 3-5 days
- XL = 1+ week
