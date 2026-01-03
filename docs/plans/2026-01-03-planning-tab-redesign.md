# Planning Tab Redesign

**Status:** Design Complete
**Created:** 2026-01-03
**Author:** Chase Easterling + Claude
**Supersedes:** Section ordering from `2026-01-02-planning-inbox-redesign.md`

---

## Executive Summary

This design restructures the Planning tab to put **Active Projects first** and consolidate conversations **inside projects** rather than as separate entities. Key insight: conversations and projects were treated as separate things, causing fragmentation where Selene suggested multiple projects that were really aspects of the same thing.

### Core Principles

1. **Projects contain threads** — No standalone conversations
2. **Smart grouping with confirmation** — Selene suggests, user approves
3. **One project = one Things project** — Threads become headings
4. **Active first, Inbox second-to-last** — Focus on what you're working on

---

## Planning Tab Structure

### Section Order

```
Planning Tab
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

⭐ Active Projects (2)        ← TOP: Current focus
   [Projects with review badges inline]

💡 Suggestions (1)            ← Grouping proposals
   [Smart groupings to approve]

📥 Inbox (4)                  ← Notes awaiting triage
   [New notes to process]

🅿️ Parked (8)                 ← BOTTOM: Out of sight
   [Collapsed by default]
```

### Why This Order

- **Active Projects first:** What you're working on should be immediately visible
- **Suggestions before Inbox:** Grouping proposals help you triage faster
- **Inbox second-to-last:** Important but not the primary focus
- **Parked last:** Out of sight, prevents overwhelm

---

## Project Structure

### Projects Contain Sub-Topic Threads

A project like "Website Redesign" contains focused threads for different aspects:

```
Website Redesign
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
📎 5 notes attached

Threads:
┌────────────────────────────────┐
│ 🎨 Design & Branding           │
│    2 notes • 1 task • active   │
└────────────────────────────────┘
┌────────────────────────────────┐
│ ⚙️ Tech Stack                  │
│    2 notes • 2 tasks • paused  │
└────────────────────────────────┘
┌────────────────────────────────┐
│ 📝 Content Migration           │
│    1 note • no tasks yet       │
└────────────────────────────────┘

[+ New thread]
```

### Thread Characteristics

- Each thread has its own focused conversation
- Threads can be active, paused, or completed
- Notes attach to threads (or just to the project generally)
- Tasks created in a thread go to Things under that thread's heading

---

## Smart Grouping

### How It Works

When notes come in that relate to the same concept:

1. Selene detects conceptual similarity
2. Shows suggestion in Suggestions section
3. User confirms or corrects

```
💡 Suggestions
┌────────────────────────────────────────────┐
│ 3 notes seem related to "Website Redesign" │
│                                            │
│ • "Research Astro for blog"                │
│ • "Vercel seems good for hosting"          │
│ • "Color palette ideas"                    │
│                                            │
│ [Add to Project]  [Create New]  [Dismiss]  │
└────────────────────────────────────────────┘
```

### User Actions

| Action | Result |
|--------|--------|
| **Add to Project** | Attaches notes to suggested project |
| **Create New** | Creates new project from these notes |
| **Dismiss** | Notes stay in Inbox for manual triage |

---

## Things Integration

### Mapping Model

| SeleneChat | Things |
|------------|--------|
| Project | Project |
| Thread | Heading |
| Task | Task (under heading) |

### Example

SeleneChat:
```
Website Redesign (project)
├── Tech Stack (thread)
│   └── "Research Astro vs Next.js" (task)
└── Design (thread)
    └── "Pick color palette" (task)
```

Things:
```
Website Redesign (project)
├── Tech Stack (heading)
│   └── Research Astro vs Next.js
└── Design (heading)
    └── Pick color palette
```

### Task Creation Flow

1. Conversation in thread extracts task
2. User confirms task text
3. Task created in Things under matching heading
4. If heading doesn't exist, Things creates it
5. `task_links` table stores relationship

---

## No Standalone Conversations

### The Rule

Every conversation must belong to a project. No orphan threads.

### Starting a Conversation

When tapping "Discuss" on an Inbox note:

```
┌────────────────────────────────────────┐
│ Start a conversation about this note   │
│                                        │
│ ○ Create new project                   │
│   [Website Redesign____________]       │
│                                        │
│ ○ Add to existing project              │
│   • Career Planning                    │
│   • Home Office Setup                  │
│                                        │
│ ○ Quick thought (no project)           │
│   Goes to "Scratch Pad"                │
│                                        │
│         [Cancel]  [Start]              │
└────────────────────────────────────────┘
```

### Scratch Pad Project

- Default catch-all for loose threads
- System-created, always exists
- User can drag threads from Scratch Pad into real projects
- Prevents orphan conversations while allowing quick capture

---

## Resurface Triggers (Review Badges)

### No Separate Section

Instead of a "Needs Review" section, resurface alerts appear as badges on projects:

```
⭐ Active Projects (2)
┌────────────────────────────────┐
│ Website Redesign        🔔 1   │  ← Badge shows attention needed
│ 3 threads • 5 tasks            │
└────────────────────────────────┘
```

### Inside the Project

The triggering thread is highlighted:

```
Website Redesign
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

Threads:
┌────────────────────────────────┐
│ ⚙️ Tech Stack           🔔     │
│ "All tasks done! Ready to      │
│  reflect or plan next steps?"  │
└────────────────────────────────┘
```

### Trigger Types (unchanged)

| Trigger | Condition | Message |
|---------|-----------|---------|
| Progress | 50% tasks done | "Good progress! Ready to plan next steps?" |
| Stuck | 3 days inactive | "This seems stuck. Want to rethink?" |
| Completion | 100% tasks done | "All done! Reflect or plan what's next?" |

---

## UI Changes Required

### PlanningView.swift

Current section order:
1. Needs Review
2. Suggestions
3. Inbox
4. Planning Conversations
5. Active Projects
6. Parked Projects

New section order:
1. Active Projects (with review badges)
2. Suggestions
3. Inbox
4. Parked Projects

Remove:
- Standalone "Needs Review" section
- Standalone "Planning Conversations" section

### ProjectDetailView.swift

Add:
- Thread list inside project
- Thread creation flow
- Review badge display on threads

### New Components

| Component | Purpose |
|-----------|---------|
| `ThreadListView` | Shows threads inside a project |
| `ThreadRow` | Single thread with status, note count |
| `StartConversationSheet` | Project picker when starting discussion |
| `ScratchPadProject` | System default project for loose threads |

---

## Database Changes

### Modify: discussion_threads

```sql
-- Threads must belong to a project
ALTER TABLE discussion_threads ADD COLUMN project_id INTEGER NOT NULL;
ALTER TABLE discussion_threads ADD COLUMN thread_name TEXT;

-- Foreign key to projects
FOREIGN KEY (project_id) REFERENCES projects(id)
```

### New: scratch_pad handling

```sql
-- System creates default Scratch Pad project on first launch
INSERT INTO projects (id, name, status, is_system)
VALUES (0, 'Scratch Pad', 'active', 1);
```

### Modify: task_links

```sql
-- Add heading name for Things integration
ALTER TABLE task_links ADD COLUMN things_heading TEXT;
```

---

## Migration Path

### Existing Data

1. **Standalone threads** → Move to Scratch Pad project
2. **Existing projects** → Keep as-is, threads attach to them
3. **Resurfaced threads** → Convert to badge on parent project

### Code Changes

1. Remove `planningThreadsSection` from PlanningView
2. Remove `needsReviewSection` from PlanningView
3. Reorder remaining sections
4. Add thread list to ProjectDetailView
5. Add review badge to project rows
6. Add "Start conversation" project picker sheet

---

## Success Criteria

- [ ] Active Projects appears at top of Planning tab
- [ ] Inbox appears second-to-last
- [ ] Projects show sub-topic threads when opened
- [ ] No standalone conversations exist
- [ ] Scratch Pad catches loose threads
- [ ] Review badges appear on projects (not separate section)
- [ ] Smart grouping suggestions work with confirmation
- [ ] Tasks go to Things with correct heading

---

## Related Documents

- [Planning Inbox Redesign](./2026-01-02-planning-inbox-redesign.md) — Triage UX (still applies)
- [Phase 7.2 SeleneChat Planning](./2025-12-31-phase-7.2-selenechat-planning-design.md) — Original design
- [Project Grouping Design](./2026-01-01-project-grouping-design.md) — Auto-grouping logic

---

## Open Questions

1. **Thread naming:** Should Selene auto-name threads based on conversation, or require user input?
2. **Thread limits:** Should projects have a max thread count to prevent sprawl?
3. **Scratch Pad visibility:** Should it appear in Active Projects or be a special section?

---

**Document Status:** Design Complete
**Next Step:** Implementation planning with superpowers:writing-plans
