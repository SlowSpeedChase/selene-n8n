# User Stories Index

**Last Updated:** 2026-01-10

---

## Dashboard

| State | Count | Limit |
|-------|-------|-------|
| Active | 0 | 5 max |
| Ready | 1 | - |
| Draft | 0 | - |
| Done | 7 | - |
| Archived | 34 | - |

**Command:** `./scripts/story.sh status`

---

## Active (In Progress)

*None*

---

## Ready (Actionable)

| ID | Title | Phase | Effort |
|----|-------|-------|--------|
| US-046 | [Thread Detection Testing & Tuning](ready/US-046-thread-detection-tuning.md) | thread-system-2 | M |

---

## Draft (Needs Refinement)

*None*

---

## Done (Completed)

| ID | Title | Phase | Completed |
|----|-------|-------|-----------|
| US-029 | [Workflow Standardization](done/US-029-workflow-standardization.md) | infra | 2026-01-04 |
| US-040 | [Thread System Database Migration](done/US-040-thread-system-migration.md) | thread-system-1 | 2026-01-04 |
| US-041 | [Embedding Generation Workflow](done/US-041-embedding-generation-workflow.md) | thread-system-1 | 2026-01-05 |
| US-042 | [Batch Embed Existing Notes](done/US-042-batch-embed-existing-notes.md) | thread-system-1 | 2026-01-05 |
| US-043 | [Association Computation Workflow](done/US-043-association-computation-workflow.md) | thread-system-1 | 2026-01-06 |
| US-044 | [Verify Note Clusters](done/US-044-verify-note-clusters.md) | thread-system-1 | 2026-01-06 |
| US-045 | [Thread Detection Workflow](done/US-045-thread-detection-workflow.md) | thread-system-2 | 2026-01-10 |

---

## Future Phases (Stories TBD)

### Phase 3: Living System

| Title | Priority | Effort |
|-------|----------|--------|
| Wire Embedding into Processing Pipeline | critical | M |
| Reconsolidation Workflow | critical | L |

### Phase 4: Interfaces

| Title | Priority | Effort |
|-------|----------|--------|
| Thread Export to Obsidian | high | M |
| SeleneChat Thread Queries | high | L |
| Link Tasks to Threads | normal | S |

---

## Phase Mapping

Quick reference: which stories deliver which phases.

| Phase | Description | Stories | Status |
|-------|-------------|---------|--------|
| thread-system-1 | Foundation (Embeddings + Associations) | US-040, US-041, US-042, US-043, US-044 | **Done** |
| thread-system-2 | Thread Detection | US-045, US-046 | **In Progress** (US-045 done) |
| thread-system-3 | Living System | TBD | Future |
| thread-system-4 | Interfaces | TBD | Future |
| infra | Infrastructure | US-029 | Done |

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

## Archived

All previous Phase 7.x stories have been archived in `archived/` as of 2026-01-04.
The Thread System design supersedes the previous project-based approach.

<details>
<summary>View Archived Stories (34)</summary>

| ID | Title | Previous State |
|----|-------|----------------|
| US-001 | Auto-Extract Tasks from Voice Notes | ready |
| US-002 | Energy Level Assignment | ready |
| US-003 | Time Estimation | ready |
| US-004 | Overwhelm Factor Tracking | draft |
| US-005 | No Duplicate Tasks | draft |
| US-006 | Auto-Create Projects | done |
| US-007 | Project Energy Profile | draft |
| US-008 | Project Time Estimation | draft |
| US-009 | View Related Tasks | draft |
| US-010 | Filter by Energy | draft |
| US-011 | Project View | draft |
| US-012 | Completion Tracking | draft |
| US-013 | Energy Accuracy | draft |
| US-014 | Time Calibration | draft |
| US-015 | Overwhelm Warning | draft |
| US-016 | Time Blocking | draft |
| US-017 | Daily Planning | draft |
| US-018 | Evening Reflection | draft |
| US-019 | What Should I Do Now | draft |
| US-020 | Hyperfocus Capture | draft |
| US-021 | Automatic Project Grouping | draft |
| US-022 | n8n 2.x Upgrade | draft |
| US-023 | Plan Archive Agent | draft |
| US-024 | SeleneChat Auto-Builder | draft |
| US-025 | Feedback Pipeline | ready |
| US-026 | SeleneChat UAT System | draft |
| US-027 | Planning Persistence | draft |
| US-028 | Executive Function Dashboard | draft |
| US-030 | Process Gap Fixes | draft |
| US-031 | Auto-Assignment for New Tasks | active |
| US-032 | Headings Within Projects | draft |
| US-033 | Oversized Task Detection | draft |
| US-034 | Project Completion Tracking | draft |
| US-035 | Sub-Project Suggestions | draft |

</details>

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
