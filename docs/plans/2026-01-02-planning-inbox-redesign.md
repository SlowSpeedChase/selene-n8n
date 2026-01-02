# Planning Inbox Redesign

**Status:** Approved
**Created:** 2026-01-02
**Author:** Chase Easterling + Claude
**Supersedes:** Parts of Phase 7.1 and 7.2 designs

---

## Executive Summary

This design revises the Phase 7 planning flow based on user story analysis. The key change: **ALL notes go through SeleneChat Inbox for user triage before any tasks are created.** No automatic task creation in Things.

### Why This Change

The original design auto-routed "actionable" notes directly to Things. Through discussion, we identified problems:

1. **Inbox overwhelm** - Auto-created tasks fill Things without user buy-in
2. **AI misinterpretation** - User can't verify the AI understood correctly
3. **Missing context** - Even "simple" tasks benefit from a moment of reflection
4. **Loss of control** - User doesn't decide what becomes a "real" task

### Core Principle

> The value isn't in "extracting tasks from notes" - it's in **having a conversation that produces a plan you actually understand and believe in.**

---

## Architecture Overview

### Before (Original Design)

```
Note → Classify → Actionable? → Auto-create task in Things
                → Needs planning? → Park in SeleneChat
                → Archive only? → Obsidian
```

### After (This Design)

```
Note → Process/Enrich → ALL park in SeleneChat Inbox
                              │
                              ▼
                        User Triage
                              │
          ┌───────────────────┼───────────────────┐
          ▼                   ▼                   ▼
     Quick Task          Start Project          Park
          │                   │                   │
          ▼                   ▼                   ▼
    Confirm text →      Planning Conv →      Parked List
    Things Inbox        Tasks → Things       (revisit later)
```

---

## Planning Tab Structure

### Three Sections

```
┌─────────────────────────────────────────────────────────┐
│  Planning                                        ⚙️     │
├─────────────────────────────────────────────────────────┤
│                                                         │
│  📥 Inbox (4)                                           │
│  [New notes waiting for triage]                         │
│                                                         │
│  ─────────────────────────────────────────────────────  │
│                                                         │
│  🔥 Active (2)                                          │
│  [Projects you're currently working on]                 │
│                                                         │
│  ─────────────────────────────────────────────────────  │
│                                                         │
│  🅿️ Parked (12)                              [View →]   │
│  [Everything else - not deleted, just not in focus]     │
│                                                         │
└─────────────────────────────────────────────────────────┘
```

**Active limit:** 3-5 projects max to force focus and prevent overwhelm.

---

## Inbox Triage UX

### Note Type Detection

AI analyzes each note and suggests a type:

| Badge | Meaning | Primary Actions |
|-------|---------|-----------------|
| 📋 Quick task | Clear, simple action | Create Task, Park, Archive |
| 🔗 Relates to project | Concept match found | Add to Project, New Project, Park |
| 🆕 New project idea | Complex, needs planning | Start Project, Park, Archive |
| 💭 Reflection | No action implied | Keep in Knowledge, Link to..., Archive |

### Triage Card Layout

```
┌────────────────────────────────────────────────────────┐
│ "Maybe use Astro for the blog section"                 │
│ 🔗 Website Redesign (parked)                           │
│                                                        │
│ [Add to Project] [New Project] [Park] [Archive]        │
└────────────────────────────────────────────────────────┘
```

### Action Behaviors

| Action | What Happens |
|--------|--------------|
| **Create Task** | Shows confirmation with editable text → sends to Things |
| **Add to Project** | Attaches immediately, clears from Inbox |
| **Start Project** | Creates project with AI-generated name, opens planning conversation |
| **Park** | Moves to Parked list (standalone or as future project idea) |
| **Archive** | Stored in database/Obsidian, removed from Planning tab |
| **Keep in Knowledge** | Searchable in SeleneChat, not actionable |
| **Link to...** | Opens project picker to attach note as context |
| **Discuss** | Opens conversation before deciding |

### Quick Task Confirmation

When tapping "Create Task":

```
┌────────────────────────────────────────────────────────┐
│ "Call dentist about cleaning appointment"              │
│ 📋 Quick task                                          │
├────────────────────────────────────────────────────────┤
│                                                        │
│  Task to create:                                       │
│  ┌──────────────────────────────────────────────────┐  │
│  │ Call dentist about cleaning appointment          │  │
│  └──────────────────────────────────────────────────┘  │
│                                                        │
│           [Send to Things ✓]    [Cancel]               │
│                                                        │
└────────────────────────────────────────────────────────┘
```

- Tap text to edit if needed
- AI handles metadata (energy, time estimates)
- Things handles scheduling

---

## Project Lifecycle

### States

```
┌──────────┐    ┌──────────┐    ┌──────────┐
│  Parked  │◄──►│  Active  │───►│ Complete │
└──────────┘    └──────────┘    └──────────┘
```

- **Parked**: Not in focus, but not forgotten
- **Active**: Currently working on (limited to 3-5)
- **Complete**: All tasks done, archived

### Context Memory

When a new note relates to an existing project (even parked), the system preserves:

1. **Conversation history** - All previous planning discussions
2. **Accumulated notes** - Every note attached to the project
3. **Task status** - Current state from Things (synced)
4. **Decisions made** - So you don't re-litigate

When reopening a parked project:

```
┌─────────────────────────────────────────────────────────┐
│  ← Back                          Website Redesign       │
├─────────────────────────────────────────────────────────┤
│                                                         │
│  📎 Project Context (tap to expand)                     │
│     • 4 notes attached                                  │
│     • 4 tasks (2 done, 2 pending)                       │
│     • Last active: 3 weeks ago                          │
│                                                         │
│  ─────────────────────────────────────────────────────  │
│                                                         │
│  🆕 New note added:                                     │
│  "Maybe use Astro for the blog section"                 │
│                                                         │
│  🤖 Welcome back to Website Redesign. You were          │
│     researching hosting options last time.              │
│                                                         │
│     This new note is about tech stack for the blog.     │
│     Want to explore this now, or just add it to         │
│     your research list?                                 │
│                                                         │
└─────────────────────────────────────────────────────────┘
```

---

## Classification Role Change

### Before
Classification determined routing:
- `actionable` → Things (automatic)
- `needs_planning` → SeleneChat
- `archive_only` → Obsidian

### After
Classification becomes a **UI hint**:
- Suggests note type badge in Inbox (📋, 🔗, 🆕, 💭)
- Suggests related projects (concept matching)
- Enriches metadata for future use
- Does NOT auto-route anything

### What Stays
- Metadata extraction (concepts, themes, energy, overwhelm)
- Database schema for classification
- The LLM classification logic itself
- Concept-based project matching

---

## Changes to Existing Components

### Workflow 07 (Task Extraction)

**Before:** Classifies notes, auto-creates tasks in Things for `actionable` items.

**After:**
- Still extracts metadata and classification
- Stores everything in database
- Does NOT talk to Things
- Things integration moves to SeleneChat (user-initiated)

### Phase 7.2 (SeleneChat Planning)

**Before:** Planning tab shows only `needs_planning` items.

**After:**
- Planning tab gets Inbox section (all notes)
- Adds Active/Parked structure
- Triage UX with buttons (conversation optional)
- "Quick task" path for simple items

### Phase 7.2e (Bidirectional Things Flow)

**Before:** Resurface triggers surface threads.

**After:**
- Same trigger logic
- Triggers can promote from Parked to Active
- Or surface within Active for review

### Phase 7.2f (Project Grouping)

**Before:** Auto-create Things projects from concept clusters.

**After:**
- Projects created in SeleneChat first (user-initiated)
- Things projects created when tasks are sent
- Concept clustering suggests "Add to Project" in Inbox

---

## New Swift Components Needed

```
SeleneChat/
├── Views/
│   ├── Planning/
│   │   ├── PlanningView.swift          # Main tab (existing, modify)
│   │   ├── InboxView.swift             # NEW: Inbox section
│   │   ├── TriageCardView.swift        # NEW: Note card with actions
│   │   ├── ActiveProjectsList.swift    # NEW: Active projects section
│   │   ├── ParkedProjectsList.swift    # NEW: Parked projects section
│   │   ├── QuickTaskConfirmation.swift # NEW: Task confirmation sheet
│   │   └── PlanningConversationView.swift # Existing, keep
│   │
├── Services/
│   ├── InboxService.swift              # NEW: Fetch/manage inbox notes
│   ├── ProjectService.swift            # NEW: Active/Parked management
│   └── ThingsURLService.swift          # Existing, keep
│
└── Models/
    ├── InboxNote.swift                 # NEW: Note in inbox
    ├── Project.swift                   # NEW: Project with state
    └── NoteType.swift                  # NEW: Enum for note badges
```

---

## Database Changes

### New: projects table

```sql
CREATE TABLE projects (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    name TEXT NOT NULL,
    status TEXT DEFAULT 'parked'
        CHECK(status IN ('active', 'parked', 'completed')),
    primary_concept TEXT,
    things_project_id TEXT,
    created_at TEXT DEFAULT CURRENT_TIMESTAMP,
    last_active_at TEXT,
    completed_at TEXT
);
```

### New: project_notes junction

```sql
CREATE TABLE project_notes (
    project_id INTEGER NOT NULL,
    raw_note_id INTEGER NOT NULL,
    attached_at TEXT DEFAULT CURRENT_TIMESTAMP,
    PRIMARY KEY (project_id, raw_note_id),
    FOREIGN KEY (project_id) REFERENCES projects(id),
    FOREIGN KEY (raw_note_id) REFERENCES raw_notes(id)
);
```

### Modify: raw_notes

```sql
ALTER TABLE raw_notes ADD COLUMN inbox_status TEXT DEFAULT 'pending'
    CHECK(inbox_status IN ('pending', 'triaged', 'archived'));
ALTER TABLE raw_notes ADD COLUMN suggested_type TEXT
    CHECK(suggested_type IN ('quick_task', 'relates_to_project', 'new_project', 'reflection'));
ALTER TABLE raw_notes ADD COLUMN suggested_project_id INTEGER;
```

---

## Future Features

These were identified during brainstorming but are NOT part of initial implementation:

### Parking Lot Rot Detection
Surface parked items that haven't been touched in X days:
```
🕸️ "Career pivot ideas" hasn't been touched in 6 weeks
   Still relevant?     [Reactivate] [Archive] [Snooze]
```

### AI Suggestions When Active Doesn't Appeal
```
🤖 "Nothing in Active clicking today?
    Based on your energy and recent notes, you might
    want to pick up 'Home Office Setup' - it's mostly
    low-energy research tasks."
```

### Task Check-in Conversations
```
🤖 "You created 'Call dentist' 5 days ago but haven't
    done it. This seemed important - what's getting
    in the way?"

👤 "I hate phone calls"

🤖 "That's real. Would it help to:
    - Schedule a specific time?
    - Check for online booking?
    - Just find the number first?"
```

### Explicit Project Suggestion Correction
"Not this" button when AI suggests wrong project match.

### Auto-Park Suggestions
"You haven't touched this active project in 2 weeks - park it?"

---

## Success Criteria

- [ ] All notes appear in Inbox (no auto-routing)
- [ ] Triage buttons work for all note types
- [ ] Quick task confirmation sends to Things correctly
- [ ] Active/Parked distinction visible and manageable
- [ ] Projects preserve context when reopened
- [ ] New notes attach to existing projects correctly
- [ ] User reports feeling in control of what becomes a task

---

## Implementation Priority

1. **Inbox View** - Core triage experience
2. **Active/Parked structure** - Project organization
3. **Quick task flow** - Simple notes → Things
4. **Project conversations** - Complex planning
5. **Context memory** - Reopen with history

---

## Related Documents

- [Original Task Extraction Design](./2025-12-30-task-extraction-planning-design.md) - Superseded for routing
- [Phase 7.2 SeleneChat Planning](./2025-12-31-phase-7.2-selenechat-planning-design.md) - Being modified
- [Phase 7 Roadmap](../roadmap/16-PHASE-7-THINGS.md) - Update needed
- [Project Grouping Design](./2026-01-01-project-grouping-design.md) - Adjust for new model

---

**Document Status:** Approved
**Next Step:** Create implementation plan with superpowers:writing-plans
