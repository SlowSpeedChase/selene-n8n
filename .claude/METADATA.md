# Metadata Quick Reference

> **For Claude:** Quick reference for metadata fields during development. For complete specifications, see `@docs/architecture/metadata-definitions.md`.

---

## Classification (Routing Decision)

Every note MUST be classified. This determines where it goes:

| Classification | Criteria | Routes To |
|----------------|----------|-----------|
| `actionable` | Clear verb + object, completable in one session | Things inbox |
| `needs_planning` | Goal/outcome, multiple tasks, or overwhelm > 7 | SeleneChat flag |
| `archive_only` | Reflection, observation, no action implied | Obsidian only |

### Classification Logic

```
actionable IF:
  - Clear verb + specific object
  - Single session completable
  - "Done" is unambiguous
  - No unmade dependencies

needs_planning IF:
  - Expresses goal/outcome
  - Multiple potential tasks
  - Needs scoping/breakdown
  - Uses "want to", "should", "need to figure out"
  - overwhelm_factor > 7

archive_only: Default (everything else)
```

---

## Core Fields

### Required for All Notes

| Field | Type | Values |
|-------|------|--------|
| `classification` | enum | `actionable`, `needs_planning`, `archive_only` |
| `concepts` | array | Extracted semantic topics |
| `themes` | array | Higher-level patterns |
| `overwhelm_factor` | 1-10 | Complexity/emotional weight |

### Required for Actionable Tasks

| Field | Type | Values |
|-------|------|--------|
| `energy_required` | enum | `high`, `medium`, `low` |
| `estimated_minutes` | enum | `5`, `15`, `30`, `60`, `120`, `240` |
| `task_type` | enum | `action`, `decision`, `research`, `communication`, `learning`, `planning` |
| `context_tags` | array | Max 3, situational filters |

---

## Energy Levels

| Level | When to Use |
|-------|-------------|
| `high` | Creative work, learning, complex decisions, deep writing |
| `medium` | Routine work, communication, light planning |
| `low` | Organizing, simple responses, filing, sorting |

---

## Overwhelm Factor

| Range | Meaning | Implication |
|-------|---------|-------------|
| 1-3 | Simple, clear | Execute directly |
| 4-6 | Moderate | May need energy matching |
| 7-8 | Complex/emotional | Consider breakdown |
| 9-10 | Paralysis risk | Requires planning session |

**Rule:** If overwhelm > 7, prefer `classification = needs_planning`

---

## Time Estimates

Always include 25% ADHD buffer. Use these discrete values:

- `5` - Quick (1-5 min actual)
- `15` - Short (10-15 min actual)
- `30` - Focused (20-30 min actual)
- `60` - Moderate (45-60 min actual)
- `120` - Deep work (1.5-2 hours actual)
- `240` - Major (3-4 hours actual)

---

## Naming Conventions

- Field names: `snake_case`
- Enum values: `lowercase`
- Concepts/themes: `hyphenated-lowercase`
- Example concept: `web-design`, `productivity-systems`
- Example theme: `creative-projects`, `health-goals`

---

## Common Context Tags

Use max 3 per task:

- Situation: `work`, `personal`, `home`
- Type: `creative`, `technical`, `administrative`
- Mode: `social`, `solo`, `phone`, `computer`
- Urgency: `urgent`, `deadline`

---

## Workflow Usage

| Workflow | Writes |
|----------|--------|
| 02-LLM Processing | `concepts`, `themes`, `energy_required` |
| 05-Sentiment | `emotional_tone`, `adhd_markers`, `overwhelm_factor` |
| 07-Task Extraction | `classification`, `task_type`, `estimated_minutes`, `context_tags` |

---

## Quick Validation Checklist

When extracting/processing notes, verify:

- [ ] `classification` is set
- [ ] `concepts` extracted (can be empty array)
- [ ] `overwhelm_factor` assigned (1-10)
- [ ] If actionable: `energy_required`, `estimated_minutes`, `task_type` set
- [ ] `context_tags` has max 3 items
- [ ] `estimated_minutes` is valid enum value

---

**Full specification:** `@docs/architecture/metadata-definitions.md`
