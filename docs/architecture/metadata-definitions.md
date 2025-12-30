# Metadata Definitions

**Created:** 2025-12-30
**Status:** Active
**Purpose:** Single source of truth for all metadata fields across Selene components

---

## Overview

This document defines all metadata fields used throughout the Selene system. All components (n8n workflows, SeleneChat, Obsidian export, Things integration) must use these definitions consistently.

---

## Field Reference

### Classification Fields

| Field | Type | Values | Required | Description |
|-------|------|--------|----------|-------------|
| `classification` | enum | `actionable`, `needs_planning`, `archive_only` | Yes | Determines routing of note |
| `planning_status` | enum | `null`, `pending_review`, `in_planning`, `planned`, `archived` | No | Status of planning process |

### Content Analysis Fields

| Field | Type | Values | Required | Description |
|-------|------|--------|----------|-------------|
| `concepts` | array[string] | Extracted terms | Yes | Semantic topics for linking related content |
| `themes` | array[string] | Pattern categories | Yes | Higher-level recurring patterns |
| `emotional_tone` | enum | `positive`, `negative`, `neutral`, `mixed` | Yes | Overall emotional quality |
| `adhd_markers` | array[string] | `overwhelm`, `hyperfocus`, `avoidance`, `impulsivity` | No | ADHD-relevant behavioral indicators |

### Task-Specific Fields

| Field | Type | Values | Required | Description |
|-------|------|--------|----------|-------------|
| `energy_required` | enum | `high`, `medium`, `low` | For tasks | Cognitive/emotional energy needed |
| `estimated_minutes` | enum | `5`, `15`, `30`, `60`, `120`, `240` | For tasks | Time estimate with ADHD buffer |
| `task_type` | enum | `action`, `decision`, `research`, `communication`, `learning`, `planning` | For tasks | Nature of the work |
| `context_tags` | array[string] | User-defined | For tasks | Situational filters (max 3) |
| `overwhelm_factor` | integer | 1-10 | Yes | Complexity/emotional weight |

### Tracking Fields

| Field | Type | Values | Required | Description |
|-------|------|--------|----------|-------------|
| `things_task_id` | string | UUID | For synced tasks | Things app task identifier |
| `source_uuid` | string | UUID | Yes | Original Drafts UUID |
| `test_run` | string | Marker ID | No | Test data identification |

---

## Field Details

### classification

Determines where a note gets routed after processing.

**Values:**

| Value | Criteria | Routing |
|-------|----------|---------|
| `actionable` | Clear verb + object, single session, unambiguous completion | Things inbox |
| `needs_planning` | Goal/outcome, multiple tasks, requires scoping, overwhelm > 7 | SeleneChat flag |
| `archive_only` | Reflection, observation, no implied action | Obsidian only |

**Classification Rules:**

```
IF note contains clear verb + specific object
   AND can be completed in single session
   AND "done" is unambiguous
   AND not dependent on unmade decisions
   THEN classification = "actionable"

ELSE IF note expresses goal or desired outcome
   OR contains multiple potential tasks
   OR requires scoping/breakdown
   OR uses "want to", "should", "need to figure out"
   OR overwhelm_factor > 7
   THEN classification = "needs_planning"

ELSE classification = "archive_only"
```

### energy_required

Maps tasks to user's current capacity.

| Value | Indicators | Examples |
|-------|-----------|----------|
| `high` | Creative work, learning, complex decisions, deep writing | "Write project proposal", "Design new feature" |
| `medium` | Routine work, communication, light planning | "Email client", "Review document" |
| `low` | Organizing, simple responses, filing, sorting | "File receipts", "Reply to scheduling email" |

**Usage:** SeleneChat can filter tasks by current energy. "What can I do right now?" with low energy shows only low-energy tasks.

### estimated_minutes

Time estimates with built-in ADHD buffer (25% added to naive estimates).

| Value | Raw Estimate | Use Case |
|-------|--------------|----------|
| `5` | 1-5 min | Quick replies, simple lookups |
| `15` | 10-15 min | Short emails, small fixes |
| `30` | 20-30 min | Focused task, single deliverable |
| `60` | 45-60 min | Moderate project work |
| `120` | 1.5-2 hours | Deep work session |
| `240` | 3-4 hours | Major deliverable, half-day focus |

### overwhelm_factor

Subjective complexity and emotional weight on 1-10 scale.

| Range | Meaning | Action |
|-------|---------|--------|
| 1-3 | Simple, clear, quick | Direct execution |
| 4-6 | Moderate complexity or time | May need energy matching |
| 7-8 | Complex, vague, or emotionally difficult | Consider breakdown |
| 9-10 | Overwhelming, paralysis risk | Requires planning session |

**Note:** If `overwhelm_factor > 7`, strongly prefer `classification = needs_planning`.

### task_type

Nature of the work, useful for batching similar tasks.

| Value | Description | Examples |
|-------|-------------|----------|
| `action` | Physical or digital task with clear output | "Send invoice", "Fix bug" |
| `decision` | Requires choosing between options | "Pick hosting provider" |
| `research` | Information gathering | "Research competitors" |
| `communication` | Interaction with others | "Call client", "Email team" |
| `learning` | Skill or knowledge acquisition | "Read documentation" |
| `planning` | Organizing or scoping future work | "Plan sprint", "Outline project" |

### context_tags

Situational filters, max 3 per task.

**Common values:**
- `work`, `personal`, `home`
- `creative`, `technical`, `administrative`
- `social`, `solo`
- `urgent`, `deadline`
- `errand`, `computer`, `phone`

**Usage:** Filter tasks by context. "What can I do while waiting?" → show `phone` or `short` tasks.

### concepts

Semantic topics extracted from content. Used for:
- Linking related notes in Obsidian
- SeleneChat knowledge queries
- Project detection (future)

**Format:** Lowercase, hyphenated compound terms
**Examples:** `web-design`, `productivity-systems`, `adhd-strategies`, `tax-preparation`

### themes

Higher-level patterns that emerge across notes.

**Examples:** `creative-projects`, `health-goals`, `work-stress`, `learning-journey`

**Difference from concepts:** Concepts are specific topics. Themes are recurring patterns or categories.

---

## Usage by Component

### n8n Workflows

| Workflow | Reads | Writes |
|----------|-------|--------|
| 01-Ingestion | - | `source_uuid`, `test_run` |
| 02-LLM Processing | raw content | `concepts`, `themes`, `energy_required` |
| 05-Sentiment | processed data | `emotional_tone`, `adhd_markers`, `overwhelm_factor` |
| 07-Task Extraction | all metadata | `classification`, `task_type`, `estimated_minutes`, `context_tags`, `things_task_id` |

### SeleneChat

| Feature | Fields Used |
|---------|-------------|
| Knowledge queries | `concepts`, `themes` |
| Task filtering | `energy_required`, `context_tags`, `task_type` |
| Planning flags | `classification`, `planning_status`, `overwhelm_factor` |
| Thread continuation | `concepts`, `themes` (for contextual matching) |

### Obsidian Export

| Frontmatter Field | Source |
|-------------------|--------|
| `tags` | `concepts` + `themes` |
| `energy` | `energy_required` |
| `status` | `classification` |
| `created` | `created_at` |

### Things Integration

| Things Property | Source Field |
|-----------------|--------------|
| Title | extracted `task_text` |
| Tags | `context_tags` |
| Notes | `energy_required`, `estimated_minutes`, `raw_note_id` |
| When | Default: "anytime" |

---

## Validation Rules

### Required Fields (All Notes)

- `classification`
- `concepts` (can be empty array)
- `themes` (can be empty array)
- `overwhelm_factor`

### Required for Actionable Tasks

- `energy_required`
- `estimated_minutes`
- `task_type`

### Constraints

| Field | Constraint |
|-------|------------|
| `context_tags` | Max 3 items |
| `concepts` | Max 10 items |
| `themes` | Max 5 items |
| `overwhelm_factor` | Integer 1-10 |
| `estimated_minutes` | Must be one of: 5, 15, 30, 60, 120, 240 |

### Default Values

| Field | Default |
|-------|---------|
| `classification` | `archive_only` |
| `planning_status` | `null` |
| `energy_required` | `medium` |
| `overwhelm_factor` | `5` |
| `emotional_tone` | `neutral` |

---

## Extension Guidelines

### Adding New Fields

1. Document in this file first
2. Add to database schema (`database/migrations/`)
3. Update relevant workflow nodes
4. Update SeleneChat queries if applicable
5. Update Obsidian export if applicable

### Deprecating Fields

1. Mark as deprecated in this file with date
2. Add migration to remove from new records
3. Keep reading old data for backwards compatibility
4. Remove after 90 days with no usage

### Naming Conventions

- Use `snake_case` for field names
- Use lowercase for enum values
- Use hyphenated-lowercase for concept/theme values
- Prefix boolean fields with `is_` or `has_`

---

## Changelog

| Date | Change |
|------|--------|
| 2025-12-30 | Initial version with classification logic |

---

## Related Documents

- `.claude/METADATA.md` - AI context file (quick reference)
- `database/schema.sql` - Database implementation
- `docs/plans/2025-12-30-task-extraction-planning-design.md` - Architectural context
