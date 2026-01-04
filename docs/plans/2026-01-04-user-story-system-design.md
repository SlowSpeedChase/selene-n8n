# User Story System Design

**Status:** Ready for Implementation
**Created:** 2026-01-04
**Phase:** Infrastructure

---

## Overview

Migrate Selene development to a story-driven workflow where all work starts with a user story. Stories live in state-based directories and drive git branches. Design docs become optional supporting artifacts for complex stories.

---

## Directory Structure

```
docs/stories/
├── INDEX.md              # Dashboard: active, ready, draft, done
├── templates/
│   └── STORY-TEMPLATE.md
├── draft/                # Ideas needing refinement
├── ready/                # Actionable, has acceptance criteria
├── active/               # In-progress (max 5)
└── done/                 # Completed archive
```

---

## Story Lifecycle

```
draft/ → ready/ → active/ → done/
  │        │         │        │
Ideas   Refined   Working   Merged
         with       on
       criteria   branch
```

**Constraints:**
- Max 5 active stories (ADHD: prevents overwhelm)
- Must have acceptance criteria before `ready/`
- Moving to `active/` creates git branch
- No implementation without a story

---

## Story Template

```markdown
# US-{NNN}: {Title}

**Status:** draft | ready | active | done
**Priority:** 🔥 critical | 🟡 high | 🟢 normal
**Effort:** S | M | L | XL
**Created:** YYYY-MM-DD
**Updated:** YYYY-MM-DD

---

## User Story

As a **[type of user]**,
I want **[goal/desire]**,
So that **[benefit/value]**.

---

## Context

*Why does this matter? What problem does it solve?*

---

## Acceptance Criteria

- [ ] Criterion 1
- [ ] Criterion 2

---

## ADHD Design Check

- [ ] **Reduces friction?** (fewer steps/decisions)
- [ ] **Visible?** (won't be forgotten)
- [ ] **Externalizes cognition?** (system remembers, not user)

---

## Technical Notes

- Dependencies:
- Affected components:
- Design doc: (link if exists)

---

## Links

- **Branch:** (added when active)
- **PR:** (added when complete)
- **Source:** (original location if migrated)
```

---

## Migration Plan

### From things-integration-stories.md (20 stories)

| Original Story | New ID | Directory |
|----------------|--------|-----------|
| 1.1: Auto-Extract Tasks | US-001 | ready/ |
| 1.2: Energy Level Assignment | US-002 | ready/ |
| 1.3: Time Estimation | US-003 | ready/ |
| 1.4: Overwhelm Factor | US-004 | draft/ |
| 1.5: No Duplicate Tasks | US-005 | draft/ |
| 2.1: Auto-Create Projects | US-006 | draft/ |
| 2.2: Project Energy Profile | US-007 | draft/ |
| 2.3: Project Time Estimation | US-008 | draft/ |
| 3.1: View Related Tasks | US-009 | draft/ |
| 3.2: Filter by Energy | US-010 | draft/ |
| 3.3: Project View | US-011 | draft/ |
| 4.1: Completion Tracking | US-012 | draft/ |
| 4.2: Energy Accuracy | US-013 | draft/ |
| 4.3: Time Calibration | US-014 | draft/ |
| 4.4: Overwhelm Warning | US-015 | draft/ |
| F.1: Time Blocking | US-016 | draft/ |
| F.2: Daily Planning | US-017 | draft/ |
| F.3: Evening Reflection | US-018 | draft/ |
| F.4: What Should I Do | US-019 | draft/ |
| F.5: Hyperfocus Capture | US-020 | draft/ |

### From Active Design Docs (10 stories)

| Design Doc | New ID | Directory |
|------------|--------|-----------|
| project-grouping-design.md | US-021 | draft/ |
| n8n-upgrade-design.md | US-022 | draft/ |
| plan-archive-agent-design.md | US-023 | draft/ |
| selenechat-auto-builder-design.md | US-024 | draft/ |
| feedback-pipeline-design.md | US-025 | ready/ |
| selenechat-uat-system-design.md | US-026 | draft/ |
| planning-persistence-refinement-design.md | US-027 | draft/ |
| selenechat-vision-and-feedback-loop-design.md | US-028 | draft/ |
| workflow-standardization-design.md | US-029 | draft/ |
| process-gap-fixes-design.md | US-030 | draft/ |

---

## Git Integration

### Branch Naming

```
Old:  phase-X.Y/feature-name
New:  US-NNN/brief-description
```

### Commit Format

```
US-NNN: description

- Detail 1
- Detail 2
```

### PR Format

```
US-NNN: Story title
```

### Workflow

| Stage | Story State | Action |
|-------|-------------|--------|
| Planning | draft → ready | Refine, add acceptance criteria |
| Start | ready → active | promote + create branch |
| Work | active | Develop, reference in commits |
| Complete | active → done | Merge PR, move story |

---

## Helper Script

`scripts/story.sh`:

```bash
./scripts/story.sh status              # Show counts per state
./scripts/story.sh new <title>         # Create in draft/
./scripts/story.sh promote US-NNN      # Move to next state
./scripts/story.sh list [state]        # List stories
```

---

## Design Docs Relationship

- **Simple stories:** No design doc needed
- **Complex stories:** Create design doc, link from story
- **Existing design docs:** Stay in `docs/plans/`, linked from stories
- **Going forward:** Story first, design doc only if needed

---

## Files to Create/Update

1. `docs/stories/` directory structure
2. `docs/stories/templates/STORY-TEMPLATE.md`
3. `docs/stories/INDEX.md`
4. `.claude/STORIES.md` (workflow guide)
5. `scripts/story.sh`
6. Update `CLAUDE.md` Context Navigation
7. Update `.claude/GITOPS.md` branch naming
8. Archive `docs/user-stories/things-integration-stories.md`
9. Archive `docs/backlog/user-stories.md`

---

## Implementation Checklist

- [x] Create directory structure
- [x] Create STORY-TEMPLATE.md
- [x] Create story.sh script
- [x] Migrate 20 stories from things-integration-stories.md
- [x] Create 10 stories from active design docs
- [x] Create INDEX.md with all stories
- [x] Create .claude/STORIES.md
- [x] Update CLAUDE.md
- [x] Update GITOPS.md
- [x] Archive original files
- [ ] Commit all changes
