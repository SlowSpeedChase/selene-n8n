# SeleneChat Vision and Feedback Loop Design

**Status:** Design Complete
**Created:** 2025-12-31
**Author:** Chase Easterling + Claude

---

## Overview

This document defines the core vision for SeleneChat as an externalized executive function system, plus a structured feedback loop for continuous product improvement.

**Key Concepts:**
- SeleneChat is where you get *directed*, not where you *capture*
- Things 3 is the task database; Selene adds intelligence on top
- Feedback flows through the same capture channel, just tagged differently
- User stories auto-generate to a markdown backlog for review sessions

---

## Part 1: SeleneChat Mental Model

### Purpose

Externalized executive function. You capture thoughts elsewhere (Drafts, on-the-go), SeleneChat is where you:
1. See your organized mind (library/archive)
2. Get directed to your next action
3. Resume plans and projects

### Three Roles

| Role | Function |
|------|----------|
| **Librarian** | Organizes notes into searchable archive with insights |
| **Task Manager** | Tracks plans and tasks via Things integration |
| **Executive Director** | Tells you what to do next based on your current state |

### Primary Interface: Dashboard + Direct Me

```
┌─────────────────────────────────────────────────────────┐
│  SeleneChat                                             │
├─────────────────────────────────────────────────────────┤
│  DASHBOARD                                              │
│  ┌──────────────────┐ ┌──────────────────────────────┐ │
│  │ Recent Notes     │ │ Insights                     │ │
│  │ • "Website idea" │ │ Today: 4 notes captured      │ │
│  │ • "Career thought"│ │ Week: "Career" theme (3x)   │ │
│  │ • "Book notes"   │ │ Month: 2 projects started    │ │
│  └──────────────────┘ └──────────────────────────────┘ │
│                                                         │
│  DIRECT ME                                              │
│  ┌─────────────────────────────────────────────────────┐│
│  │  Energy:  ○ Low   ● Medium   ○ High                ││
│  │  Time:    ○ 15m   ○ 30m   ● 1hr   ○ 2hr+           ││
│  │  Context: ● Desk   ○ Mobile   ○ Anywhere           ││
│  │                                                     ││
│  │              [ What should I work on? ]            ││
│  └─────────────────────────────────────────────────────┘│
└─────────────────────────────────────────────────────────┘
```

### User Flow

1. Open SeleneChat
2. Dashboard shows recent notes + insights (day/week/month trends)
3. "I'm ready to work" → Select energy, time, context
4. Selene queries Things for matching tasks
5. Returns recommendation with plan context
6. User clicks through to task or continues planning conversation

---

## Part 2: Things Integration for Task Filtering

### Core Principle

Things is the task database. Selene adds intelligence on top.

### Task Metadata Tags

During planning conversations, extracted tasks get tagged with filterable metadata:

```
Task: "List website requirements"
Tags: #low-energy #15min #anywhere #selene #project-website
Notes: [selene:note-42:thread-7]
```

### Tag Schema

| Category | Tags |
|----------|------|
| Energy | `#low-energy` `#medium-energy` `#high-energy` |
| Time | `#5min` `#15min` `#30min` `#1hr` `#2hr` `#half-day` |
| Location | `#desk` `#mobile` `#anywhere` |
| Project | `#project-{name}` |
| System | `#selene` (all Selene-created tasks) |

### "Direct Me" Query Flow

```
User input: Medium energy, 1hr, Desk
                    │
                    ▼
Query Things via AppleScript:
  #selene tasks WHERE
  energy ≤ medium AND time ≤ 1hr AND location IN (desk, anywhere)
                    │
                    ▼
Get matching tasks → Pick best fit (or offer choices)
                    │
                    ▼
Pull plan context from Selene DB using [selene:note-X:thread-Y]
                    │
                    ▼
Present: "From your Website project: 'List requirements'
          Here's where this fits in the plan..."
```

### AppleScript Query Example

```applescript
tell application "Things3"
    set matchingTasks to to dos of list "Anytime" whose ¬
        (tag names contains "selene") and ¬
        (tag names contains "low-energy" or tag names contains "medium-energy") and ¬
        (tag names contains "15min" or tag names contains "30min" or tag names contains "1hr")
    return matchingTasks
end tell
```

---

## Part 3: Feedback Loop System

### Principle

Feedback flows through the same capture channel (Drafts), just tagged differently. No special process to remember.

### Capture Flow

```
Drafts note: "Task suggestion was off - gave me a coding task
when I said low energy #selene-feedback"
        │
        ▼
Same webhook: /webhook/api/drafts
        │
        ▼
Ingestion workflow detects #selene-feedback tag
        │
        ▼
Routes to: feedback_notes table (NOT raw_notes)
```

### Processing Pipeline

```
Raw feedback note
        │
        ▼
LLM converts to user story:
  "As a user, I want energy levels to filter out
   high-cognitive tasks so I get appropriate suggestions"
        │
        ▼
LLM detects theme: "Task Routing"
        │
        ▼
Clusters with similar stories (if any exist)
        │
        ▼
Updates docs/backlog/user-stories.md (real-time)
```

### Database Schema

```sql
CREATE TABLE feedback_notes (
    id INTEGER PRIMARY KEY,
    content TEXT NOT NULL,
    content_hash TEXT UNIQUE NOT NULL,
    created_at TEXT DEFAULT CURRENT_TIMESTAMP,
    processed_at TEXT,
    user_story TEXT,          -- LLM-generated
    theme TEXT,               -- LLM-detected category
    cluster_id INTEGER,       -- Links related feedback
    priority INTEGER DEFAULT 1, -- Star rating (1-3)
    mention_count INTEGER DEFAULT 1,
    status TEXT DEFAULT 'open', -- open, implemented, dismissed
    implemented_pr TEXT,      -- Link to PR when implemented
    implemented_at TEXT
);

CREATE INDEX idx_feedback_theme ON feedback_notes(theme);
CREATE INDEX idx_feedback_status ON feedback_notes(status);
CREATE INDEX idx_feedback_cluster ON feedback_notes(cluster_id);
```

### Backlog File Format

Auto-generated at `docs/backlog/user-stories.md`:

```markdown
# Selene Backlog

Last updated: 2025-12-31 14:30

## Task Routing (3 stories)

### Energy-based task filtering
As a user, I want energy levels to filter out high-cognitive
tasks so I get appropriate suggestions when tired.

- Priority: 3
- Mentions: 3
- Last feedback: 2025-12-31
- Related notes: [feedback-12], [feedback-8], [feedback-3]
- Status: open

### Location-aware suggestions
As a user, I want location context so I only see tasks
I can actually do in my current environment.

- Priority: 2
- Mentions: 1
- Last feedback: 2025-12-28
- Status: open

## Dashboard (1 story)

### Weekly insight summaries
As a user, I want to see weekly theme summaries so I can
spot patterns in my thinking over time.

- Priority: 1
- Mentions: 1
- Last feedback: 2025-12-27
- Status: open

---

## Completed

### [2025-12-20] Basic task creation
As a user, I want tasks extracted from planning to go to Things.

- Implemented in: PR #5
- Closed: 2025-12-20
```

---

## Part 4: Review Workflow

### Trigger

During Claude Code sessions, say:
- "Let's review the backlog"
- "What feedback have I logged?"
- "Show me the user stories"

### Process

```
You: "Let's look at the Selene backlog"
        │
        ▼
Claude reads: docs/backlog/user-stories.md
        │
        ▼
Present summary: "You have 7 stories across 3 themes.
                  Task Routing has the most activity (4 stories).
                  2 new items since last review."
        │
        ▼
You choose action:
  A) Design something    → Brainstorming session
  B) Implement something → Create branch, write code
  C) Reprioritize        → Merge, dismiss, reorder
  D) Just review         → Discuss, no action yet
```

### After Action

| Choice | Outcome |
|--------|---------|
| Design | New design doc in `docs/plans/YYYY-MM-DD-{topic}-design.md` |
| Implement | Branch created via git worktree, work tracked in Things |
| Reprioritize | `user-stories.md` updated with changes |
| Just review | No file changes, conversation only |

### Closing the Loop

When a story gets implemented:
1. Status changes to `implemented`
2. PR link added
3. Moves to "Completed" section in backlog file
4. History preserved for reference

---

## Part 5: Implementation Scope

### New Components

| Component | Type | Description |
|-----------|------|-------------|
| DashboardView.swift | NEW | Main view with recent notes + insights |
| DirectMeView.swift | NEW | Energy/time/context selectors |
| ThingsQueryService.swift | NEW | AppleScript queries to Things |
| Feedback ingestion route | MODIFY | Detect `#selene-feedback` in workflow 01 |
| Feedback processing workflow | NEW | n8n workflow 09-feedback-processing |
| Backlog generator | NEW | Script or workflow to write user-stories.md |

### Modified Components

| Component | Change |
|-----------|--------|
| Task extraction (Phase 7.2) | Add energy/time/location tag generation |
| Ingestion workflow (01) | Add feedback tag detection and routing |
| Database schema | Add feedback_notes table |

### New Files

```
docs/backlog/user-stories.md           -- Auto-generated backlog
prompts/feedback/
  └── user-story-conversion.md         -- LLM prompt for story generation
  └── theme-detection.md               -- LLM prompt for categorization
workflows/09-feedback-processing/
  └── workflow.json                    -- Feedback processing workflow
  └── README.md
  └── scripts/test-with-markers.sh
SeleneChat/Sources/
  └── Views/DashboardView.swift        -- New main view
  └── Views/DirectMeView.swift         -- Task direction interface
  └── Services/ThingsQueryService.swift -- Query Things by tags
```

### Database Migration

```sql
-- Migration 009: Add feedback system
CREATE TABLE feedback_notes (
    id INTEGER PRIMARY KEY,
    content TEXT NOT NULL,
    content_hash TEXT UNIQUE NOT NULL,
    created_at TEXT DEFAULT CURRENT_TIMESTAMP,
    processed_at TEXT,
    user_story TEXT,
    theme TEXT,
    cluster_id INTEGER,
    priority INTEGER DEFAULT 1,
    mention_count INTEGER DEFAULT 1,
    status TEXT DEFAULT 'open',
    implemented_pr TEXT,
    implemented_at TEXT
);

CREATE INDEX idx_feedback_theme ON feedback_notes(theme);
CREATE INDEX idx_feedback_status ON feedback_notes(status);
CREATE INDEX idx_feedback_cluster ON feedback_notes(cluster_id);
```

---

## Implementation Order

### Phase A: Feedback Pipeline (Foundation)
1. Add feedback_notes table migration
2. Modify ingestion workflow to detect #selene-feedback
3. Create feedback processing workflow (LLM → user story)
4. Create backlog file generator
5. Test end-to-end: Drafts → feedback → user-stories.md

### Phase B: Dashboard View
1. Create DashboardView.swift with recent notes
2. Add insights queries (day/week/month)
3. Replace or augment main navigation

### Phase C: Direct Me Feature
1. Create DirectMeView.swift with selectors
2. Create ThingsQueryService.swift
3. Integrate with plan context from Selene DB
4. Test full flow: select state → query Things → show recommendation

### Phase D: Enhanced Task Tagging
1. Modify planning conversation task extraction
2. Add energy/time/location prompts during extraction
3. Include tags when creating Things tasks
4. Test tag-based filtering

---

## Success Criteria

- [ ] Feedback captured via `#selene-feedback` appears in backlog within 1 minute
- [ ] User stories are coherent and actionable
- [ ] Backlog file is always current and well-formatted
- [ ] Dashboard shows meaningful insights, not just raw data
- [ ] "Direct Me" returns relevant tasks matching selected criteria
- [ ] Full loop works: feedback → story → design → implement → completed

---

## Related Documentation

- [Phase 7.2 SeleneChat Planning Design](./2025-12-31-phase-7.2-selenechat-planning-design.md)
- [Phase 7.1 Task Extraction Design](./2025-12-30-task-extraction-planning-design.md)
- [ADHD Principles](../.claude/ADHD_Principles.md)
- [Things URL Scheme](https://culturedcode.com/things/support/articles/2803573/)
