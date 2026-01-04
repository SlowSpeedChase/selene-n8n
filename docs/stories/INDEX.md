# User Stories Index

**Last Updated:** 2026-01-04

---

## Dashboard

| State | Count | Limit |
|-------|-------|-------|
| Active | 1 | 5 max |
| Ready | 4 | - |
| Draft | 29 | - |
| Done | 1 | - |

**Command:** `./scripts/story.sh status`

---

## Active (In Progress)

| ID | Title | Phase | Branch |
|----|-------|-------|--------|
| US-031 | [Auto-Assignment for New Tasks](active/US-031-auto-assignment.md) | 7.2f.2 | `US-031/auto-assignment` |

---

## Ready (Actionable)

| ID | Title | Phase | Priority | Effort |
|----|-------|-------|----------|--------|
| US-001 | [Auto-Extract Tasks from Voice Notes](ready/US-001-auto-extract-tasks.md) | 7.1 | critical | L |
| US-002 | [Energy Level Assignment](ready/US-002-energy-level-assignment.md) | 7.1 | critical | M |
| US-003 | [Time Estimation](ready/US-003-time-estimation.md) | 7.1 | critical | M |
| US-025 | [Feedback Pipeline](ready/US-025-feedback-pipeline.md) | infra | high | M |

---

## Done (Completed)

| ID | Title | Phase | Completed |
|----|-------|-------|-----------|
| US-006 | [Auto-Create Projects](done/US-006-auto-create-projects.md) | 7.2f.1 | 2026-01-04 |

---

## Draft (Needs Refinement)

### Phase 7.1: Task Extraction

| ID | Title | Phase | Priority | Effort |
|----|-------|-------|----------|--------|
| US-004 | [Overwhelm Factor Tracking](draft/US-004-overwhelm-factor.md) | 7.1 | high | M |
| US-005 | [No Duplicate Tasks](draft/US-005-no-duplicate-tasks.md) | 7.1 | high | M |

### Phase 7.2f: Project Grouping (Epic: US-021)

| ID | Title | Phase | Priority | Effort |
|----|-------|-------|----------|--------|
| US-021 | [Automatic Project Grouping](draft/US-021-project-grouping.md) | 7.2f (epic) | critical | L |
| US-032 | [Headings Within Projects](draft/US-032-headings-within-projects.md) | 7.2f.3 | normal | S |
| US-033 | [Oversized Task Detection](draft/US-033-oversized-task-detection.md) | 7.2f.4 | high | M |
| US-034 | [Project Completion Tracking](draft/US-034-project-completion.md) | 7.2f.5 | normal | S |
| US-035 | [Sub-Project Suggestions](draft/US-035-sub-project-suggestions.md) | 7.2f.6 | normal | M |
| US-007 | [Project Energy Profile](draft/US-007-project-energy-profile.md) | 7.2f | normal | S |
| US-008 | [Project Time Estimation](draft/US-008-project-time-estimation.md) | 7.2f | high | S |

### Phase 7.3: SeleneChat Display

| ID | Title | Priority | Effort |
|----|-------|----------|--------|
| US-009 | [View Related Tasks](draft/US-009-view-related-tasks.md) | critical | M |
| US-010 | [Filter by Energy](draft/US-010-filter-by-energy.md) | high | M |
| US-011 | [Project View](draft/US-011-project-view.md) | normal | L |

### Phase 7.4: Status Sync & Patterns

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

## Phase Mapping

Quick reference: which stories deliver which phases.

| Phase | Description | Stories | Status |
|-------|-------------|---------|--------|
| 7.1 | Task Extraction | US-001, US-002, US-003, US-004, US-005 | Ready |
| 7.2f.1 | Basic Project Creation | US-006 | **Done** |
| 7.2f.2 | Auto-Assignment | US-031 | **Active** |
| 7.2f.3 | Headings Within Projects | US-032 | Draft |
| 7.2f.4 | Oversized Task Detection | US-033 | Draft |
| 7.2f.5 | Project Completion | US-034 | Draft |
| 7.2f.6 | Sub-Project Suggestions | US-035 | Draft |
| 7.3 | SeleneChat Display | US-009, US-010, US-011 | Draft |
| 7.4 | Status Sync & Patterns | US-012, US-013, US-014, US-015 | Draft |
| infra | Infrastructure | US-022, US-025, US-029, US-030 | Mixed |

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
