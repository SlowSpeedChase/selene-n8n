# Weekly Review: React Flow Design

**Date:** 2026-01-05
**Status:** Approved for Implementation
**Prerequisite:** Thread System Phase 1 (embeddings + associations)

---

## Core Philosophy

**"System presents -> You react -> System files it correctly"**

The user never organizes. Never decides where things go. They just respond to what the system shows them. The system interprets their reaction and does the filing.

This is the foundational UX pattern for all of Selene going forward.

---

## Overview

A weekly review file in Obsidian that presents the state of your thinking and lets you react with button clicks. The system processes your reactions - some instantly, some queued.

**Key Insight:** Reading and clicking is lower friction than typing and organizing. The ADHD brain can react to what's presented far easier than it can initiate organization.

---

## File Structure

```
vault/
└── Selene/
    └── Reviews/
        ├── Weekly-Review.md          <- Current review (regenerated)
        ├── 2026-W01-Review.md        <- Archived after completion
        └── 2026-W02-Review.md
```

**Generation:**
- **Scheduled:** n8n workflow runs Sunday 8pm, generates `Weekly-Review.md`
- **Manual:** Button at top of file triggers regeneration
- **Archive:** When marked complete, current file archived with week number

---

## Review Sections

### 1. Header

```markdown
# Weekly Review - Week 2, 2026
Generated: Sunday Jan 5, 8:00pm
Last refreshed: Monday Jan 6, 9:15am

[! Refresh Now]  [Complete Review ->]

---

Your thinking this week: 12 notes captured, 3 threads updated, 2 new patterns detected.

**How this works:** React to each section below. ! = instant action. -> = queued for next processing run.
```

### 2. Active Threads (Momentum)

Threads that gained activity this week.

```markdown
## Active Threads

Threads that grew this week. What do you want to do with them?

---

### Writing in Public
**+3 notes this week** | 8 total | Direction: Emerging

> Latest: "Saw a guy at the coffee shop working on a blog post. Felt jealous."

The emotional charge is increasing. You've mentioned fear of judgment twice now,
but the desire keeps coming back.

**React:**
[! Keep Watching]  [Create Project ->]  [Needs Discussion ->]

**Your words** (optional): _______________
```

**Actions:**
- `[! Keep Watching]` - No action, thread stays active (instant)
- `[Create Project ->]` - Queues creation of Things project with thread context
- `[Needs Discussion ->]` - Flags for SeleneChat planning conversation

### 3. Stale Threads

No activity in 30+ days.

```markdown
## Stale Threads

No activity in 30+ days. Still relevant?

---

### Learning Spanish
**Last activity: 42 days ago** | 4 notes | Direction: Was exploring

> Last note: "Duolingo streak broke again. Maybe I need a different approach."

**React:**
[! Still Thinking]  [! Archive]  [Merge With -> v]
```

**Actions:**
- `[! Still Thinking]` - Resets stale timer, keeps active (instant)
- `[! Archive]` - Moves to archived, out of active view (instant)
- `[Merge With -> v]` - Dropdown to select thread to combine with (queued)

### 4. Orphan Notes

Notes not connected to any thread.

```markdown
## Orphan Notes

These notes aren't connected to any thread. Where do they belong?

---

### "Need to call the dentist" (Jan 3)
Simple task, no deeper thread.

**React:**
[! Just a Task -> Things]  [! Ignore]  [Assign to -> v]  [New Thread ->]

---

### "Why do I always procrastinate on phone calls?" (Jan 4)
Might connect to something deeper.

**React:**
[! Ignore]  [Assign to -> v]  [New Thread ->]

**Your words** (optional): _______________
```

**Actions:**
- `[! Just a Task -> Things]` - Sends to Things inbox (instant)
- `[! Ignore]` - Marks reviewed, won't resurface (instant)
- `[Assign to -> v]` - Dropdown of existing threads (queued)
- `[New Thread ->]` - Creates thread seeded with this note (queued)

### 5. Pending Tasks

Tasks extracted but not acted on.

```markdown
## Pending Tasks

These tasks were extracted but haven't been acted on.

---

### "Research adult soccer leagues nearby"
**From thread:** Soccer & Community | **Extracted:** Dec 28

**React:**
[! Send to Things]  [! Not a Task]  [Needs Planning ->]  [! Delete]
```

**Actions:**
- `[! Send to Things]` - Routes to Things with thread context (instant)
- `[! Not a Task]` - Removes from tasks, stays in thread (instant)
- `[Needs Planning ->]` - Queues for SeleneChat breakdown (queued)
- `[! Delete]` - Remove entirely (instant)

### 6. Emerging Patterns

Recurring themes not yet threads.

```markdown
## Emerging Patterns

I'm noticing these themes across your recent notes.

---

### "Feeling isolated at work"
**Mentioned in:** 4 notes over 3 weeks
**Related threads:** Soccer & Community, Remote Work

You keep returning to this. It's showing up in multiple contexts.

**React:**
[! Yes, This Matters]  [! Noise, Ignore]  [Tell Me More ->]
```

**Actions:**
- `[! Yes, This Matters]` - Elevates to tracked pattern, may seed thread (instant)
- `[! Noise, Ignore]` - Suppresses from future reviews (instant)
- `[Tell Me More ->]` - Queues SeleneChat exploration (queued)

---

## Backend Processing

### Instant Actions (!)

```
Button click -> Obsidian Buttons plugin -> Shell command
                                              |
                            scripts/review-actions.sh <action> <id>
                                              |
                            Direct SQLite update + Things URL scheme
```

Examples:
- `review-actions.sh archive thread-42` - Updates thread status
- `review-actions.sh things-task task-17` - Opens `things:///add?title=...`
- `review-actions.sh ignore-pattern pattern-5` - Marks suppressed

### Queued Actions (->)

```
Button click -> Appends to vault/Selene/.pending-actions.json
                                              |
                            n8n workflow runs hourly (or on demand)
                                              |
                            Reads pending, processes each:
                            - Create Project: builds Things project
                            - New Thread: runs thread synthesis
                            - Needs Discussion: creates SeleneChat prompt
                                              |
                            Clears processed, updates review file
```

### Review Completion

```
[Complete Review ->] clicked
          |
Archive current review as 2026-W02-Review.md
Log completion timestamp
Clear pending state
```

---

## Database Additions

```sql
-- Track review state and user reactions
CREATE TABLE review_reactions (
    id INTEGER PRIMARY KEY,
    review_week TEXT NOT NULL,        -- "2026-W02"
    item_type TEXT NOT NULL,          -- thread/note/task/pattern
    item_id INTEGER NOT NULL,
    action TEXT NOT NULL,             -- archive/keep/create-project/etc
    user_words TEXT,                  -- optional reaction text
    processed_at TEXT,
    created_at TEXT DEFAULT CURRENT_TIMESTAMP
);

-- Track suppressed patterns
CREATE TABLE suppressed_patterns (
    id INTEGER PRIMARY KEY,
    pattern_signature TEXT UNIQUE,    -- hash of pattern for matching
    suppressed_at TEXT DEFAULT CURRENT_TIMESTAMP
);
```

---

## New Components

| Component | Type | Purpose |
|-----------|------|---------|
| `13-weekly-review-generation` | n8n workflow | Generates review file on schedule |
| `scripts/review-actions.sh` | Shell script | Handles instant button actions |
| `vault/Selene/.pending-actions.json` | Data file | Queue for complex actions |
| `14-pending-actions-processor` | n8n workflow | Processes queued actions |

---

## Obsidian Requirements

- **Buttons plugin** - Required for clickable actions
- **Templater** - Optional, review is regenerated not templated

---

## Implementation Order

### Phase 1: Static Review Generation
1. Create workflow 13-weekly-review-generation
2. Query threads, orphans, tasks, patterns from database
3. Generate markdown with button syntax
4. Write to Obsidian vault
5. Test: review file appears with correct data

### Phase 2: Instant Actions
1. Create `scripts/review-actions.sh`
2. Wire Obsidian buttons to shell commands
3. Implement: archive, keep-watching, ignore, things-task
4. Test: clicking buttons updates database

### Phase 3: Queued Actions
1. Create pending-actions.json schema
2. Wire buttons to append to queue
3. Create workflow 14-pending-actions-processor
4. Implement: create-project, new-thread, needs-discussion
5. Test: queued actions process correctly

### Phase 4: Polish
1. Add manual refresh button
2. Add review completion flow
3. Archive past reviews
4. Add week-over-week stats

---

## Success Criteria

1. User opens Weekly-Review.md on Monday
2. Sees threads, orphans, tasks, patterns laid out
3. Clicks buttons to react - no typing required
4. Instant actions happen immediately
5. Queued actions process within the hour
6. User marks complete, review archives
7. Next Sunday, fresh review generates

**The user's only job: read and react.**

---

## Future Extensions

Once weekly review works, the same pattern extends to:
- **Daily check-in** - Smaller scope, morning routine
- **SeleneChat prompts** - "Here's what I noticed, react"
- **Push notifications** - High-momentum thread alerts
- **Mobile review** - Same format, Obsidian mobile

The weekly review is the proof of concept for the entire "present -> react -> file" paradigm.
