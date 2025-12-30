# Task Extraction and Planning Architecture Design

**Created:** 2025-12-30
**Status:** Approved
**Phase:** 7.1 Revision - Supersedes previous task extraction design
**Context:** Brainstorming session on project identification, planning, and task extraction

---

## Executive Summary

This design revises the Phase 7.1 task extraction approach to support a broader vision: Selene as a personal knowledge system with AI-assisted project planning. The task extractor becomes a **triage system** that classifies notes and routes them appropriately, rather than simply extracting tasks.

### Key Architectural Decisions

1. **Local AI (Ollama)** handles metadata extraction, classification, organization, and archiving
2. **Cloud AI (external service)** handles planning, scoping, and breakdown for non-sensitive topics
3. **SeleneChat** is the primary interface for querying knowledge, discussing topics, and planning
4. **Things** receives only clear, actionable tasks - not projects or ambiguous items
5. **Sanitization layer** generalizes personal details before sending to cloud AI

---

## System Architecture

```
┌─────────────────────────────────────────────────────────────────────┐
│                         CAPTURE LAYER                                │
│  Drafts App = Raw capture, brain dump, zero friction                │
└─────────────────────────────────────────────────────────────────────┘
                                   │
                                   ▼
┌─────────────────────────────────────────────────────────────────────┐
│                      PROCESSING LAYER (Local AI)                     │
│                                                                      │
│  ┌─────────────────┐    ┌─────────────────┐    ┌─────────────────┐ │
│  │ Extract Metadata │    │    Classify     │    │   Sanitize      │ │
│  │ - concepts       │ →  │ - actionable    │ →  │ (for cloud AI)  │ │
│  │ - themes         │    │ - needs_planning│    │ - context-based │ │
│  │ - energy         │    │ - archive_only  │    │ - user rules    │ │
│  │ - overwhelm      │    │                 │    │                 │ │
│  └─────────────────┘    └─────────────────┘    └─────────────────┘ │
│                                                                      │
│  Ollama (mistral:7b) - All processing stays local                   │
└─────────────────────────────────────────────────────────────────────┘
                                   │
                    ┌──────────────┼──────────────┐
                    ▼              ▼              ▼
            ┌───────────┐  ┌───────────┐  ┌───────────┐
            │ ACTIONABLE│  │  NEEDS    │  │  ARCHIVE  │
            │           │  │ PLANNING  │  │   ONLY    │
            └─────┬─────┘  └─────┬─────┘  └─────┬─────┘
                  │              │              │
                  ▼              ▼              ▼
            ┌───────────┐  ┌───────────┐  ┌───────────┐
            │  Things   │  │ SeleneChat│  │  Obsidian │
            │   Inbox   │  │  Planning │  │  Archive  │
            └───────────┘  └───────────┘  └───────────┘
```

---

## Classification Logic

### Categories

| Classification | Description | Routing | Example |
|----------------|-------------|---------|---------|
| `actionable` | Clear, specific task that can be done | Things inbox | "Call dentist tomorrow" |
| `needs_planning` | Goal, project idea, or ambiguous intention | Flag for SeleneChat | "Want to redo my website" |
| `archive_only` | Thought, reflection, note without action | Obsidian only | "Thinking about how attention works" |

### Decision Rules

**Actionable if:**
- Contains a clear verb + object
- Can be completed in a single session
- No ambiguity about what "done" means
- Not dependent on decisions not yet made

**Needs Planning if:**
- Expresses a goal or desired outcome
- Contains multiple potential tasks
- Requires scoping or breakdown
- Uses phrases like "want to", "should", "need to figure out"
- Overwhelm factor > 7

**Archive Only if:**
- Reflective or exploratory thought
- No implied action
- Information capture (quotes, ideas, observations)
- Emotional processing

---

## Metadata Extraction

Every note gets full metadata regardless of classification:

| Field | Type | Purpose |
|-------|------|---------|
| `classification` | enum | Routing decision |
| `concepts` | array | Semantic topics for linking |
| `themes` | array | Higher-level patterns |
| `energy_required` | enum | Capacity matching |
| `overwhelm_factor` | 1-10 | Complexity/emotional weight |
| `estimated_minutes` | enum | Time scoping |
| `task_type` | enum | Nature of work |
| `context_tags` | array | Situational filters |

See `docs/architecture/metadata-definitions.md` for complete field specifications.

---

## SeleneChat Role

SeleneChat is the **primary interface** for:

### 1. Knowledge Querying
- "What have I written about productivity systems?"
- "Show me my thoughts on X from last month"
- Search across personal archive

### 2. Topic Discussion
- Explore ideas from your notes
- Refine thinking through conversation
- Connect related concepts

### 3. Planning Sessions
- Items flagged as `needs_planning` surface here
- SeleneChat facilitates breakdown and scoping
- Calls cloud AI (with sanitization) for complex planning
- Generates actionable tasks → Things

### 4. Thread Continuation
- Generates discussion prompts for later
- Surfaces contextually when related topics come up
- "Threads to continue" section when you open SeleneChat

### Surfacing Behavior

SeleneChat is **ambient, not interruptive**:

| Trigger | Behavior |
|---------|----------|
| You mention related topic | "This connects to something you wrote about last week..." |
| You open SeleneChat | "Threads to continue" section visible |
| You ask | "What needs planning?" shows flagged items |

No push notifications. No scheduled reminders. Available when you engage.

---

## Cloud AI Integration

### Purpose
Complex planning, scoping, and breakdown that benefits from more capable models.

### Sanitization Layer

Local AI sanitizes before sending to cloud:

| Context | Sanitization Level | Details |
|---------|-------------------|---------|
| Simple tasks | Light | Names replaced with generic equivalents |
| Work projects | Medium | User can mark specific details to keep/remove |
| Health/finance/relationships | Heavy | Abstract the problem completely |
| User-configured sensitive topics | Per rules | User defines patterns to always sanitize |

### Example

**Raw note:**
> "Plan trip to visit mom in Seattle, $2000 budget, need to work around her chemo schedule"

**Sanitized for cloud:**
> "Plan a week-long trip to a major west coast city, moderate budget, need flexibility around a fixed recurring commitment"

**Cloud returns:** Generic trip planning structure

**Local re-applies:** Specifics from original note

### User Control
- Sensitive topics require confirmation before sending
- User can override sanitization level
- User configures sensitive patterns (names, medical terms, amounts, etc.)

---

## Things Integration

### Scope for Phase 7.1

Things receives **only actionable tasks**:
- Clear next actions with metadata
- No project creation (tasks go to inbox)
- No ambiguous items

### Task Properties

| Selene Field | Things Property |
|--------------|-----------------|
| task_text | Title |
| context_tags | Tags |
| estimated_minutes | Notes (for reference) |
| energy_required | Notes (for reference) |
| raw_note_id | Notes (link back to source) |

### What Things Does NOT Receive
- `needs_planning` items (stay in SeleneChat)
- `archive_only` items (go to Obsidian)
- Projects (manual organization for now)

---

## Data Flow Examples

### Example 1: Clear Task

**Input:** "Call dentist tomorrow about appointment"

```
Drafts → Selene Processing
         ├── classification: actionable
         ├── concepts: ["health", "appointments"]
         ├── energy_required: low
         ├── overwhelm_factor: 2
         └── estimated_minutes: 15
              ↓
         Things Inbox: "Call dentist about appointment"
```

### Example 2: Needs Planning

**Input:** "I want to redo my personal website. Should have a portfolio, maybe a blog, need to figure out hosting..."

```
Drafts → Selene Processing
         ├── classification: needs_planning
         ├── concepts: ["web-design", "portfolio", "blog", "hosting"]
         ├── energy_required: high
         ├── overwhelm_factor: 7
         └── themes: ["creative-projects"]
              ↓
         Flagged for SeleneChat
              ↓
         User opens SeleneChat later
              ↓
         "You had an idea about redoing your website. Want to plan this out?"
              ↓
         Planning session (cloud AI if non-sensitive)
              ↓
         Generates tasks → Things
```

### Example 3: Archive Only

**Input:** "Thinking about how my attention works differently in the morning vs afternoon"

```
Drafts → Selene Processing
         ├── classification: archive_only
         ├── concepts: ["attention", "energy-patterns", "self-awareness"]
         ├── themes: ["adhd-insights"]
         └── (no task extraction)
              ↓
         Obsidian archive
              ↓
         Later in SeleneChat: "What have I noticed about my attention patterns?"
         → Surfaces this note as part of response
```

---

## Implementation Phases

### Phase 7.1 (Revised) - Task Extraction with Classification

**Scope:**
- Local AI extracts metadata for all notes
- Classifies as actionable / needs_planning / archive_only
- Actionable tasks → Things inbox (with metadata)
- needs_planning → flagged in database (SeleneChat integration later)
- archive_only → Obsidian export only

**Database additions:**
- `classification` field on processed_notes
- `planning_status` field (null, pending_review, planned, archived)
- `discussion_threads` table (for SeleneChat continuations)

### Phase 7.2 - SeleneChat Planning Integration

**Scope:**
- SeleneChat queries flagged items
- "Threads to continue" UI
- Basic planning conversation (local AI only)
- Generate tasks from planning → Things

### Phase 7.3 - Cloud AI Integration

**Scope:**
- Sanitization layer
- Cloud AI planning sessions
- User sensitivity configuration
- Re-personalization of cloud responses

### Phase 7.4 - Contextual Surfacing

**Scope:**
- SeleneChat recognizes related topics
- "This connects to..." prompts
- Pattern-based suggestions

---

## Success Criteria

### Phase 7.1
- [ ] 90%+ classification accuracy (validated by user)
- [ ] Actionable tasks reach Things within 2 minutes
- [ ] needs_planning items correctly flagged
- [ ] Full metadata attached to all notes

### Overall Vision
- [ ] SeleneChat feels like a knowledgeable assistant
- [ ] Planning sessions reduce overwhelm
- [ ] Personal data stays private (sanitization works)
- [ ] System learns your patterns over time

---

## Open Questions (Future Sessions)

1. **Thread continuation UX** - Exact UI for "Threads to continue"
2. **Sanitization rules UI** - How to configure sensitive patterns
3. **Cloud AI selection** - Which service(s) to integrate
4. **Planning session structure** - How structured vs freeform

---

## Related Documents

- `docs/architecture/metadata-definitions.md` - Field specifications
- `.claude/METADATA.md` - AI context for metadata
- `docs/roadmap/16-PHASE-7-THINGS.md` - Phase 7 roadmap (to be updated)
- `docs/plans/2025-11-25-phase-7-1-gatekeeping-design.md` - Previous design (superseded)

---

**Document Status:** Approved
**Next Action:** Implement Phase 7.1 with classification logic
**Owner:** Chase Easterling
