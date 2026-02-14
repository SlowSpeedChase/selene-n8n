# Thread Workspace Design

**Date:** 2026-02-06
**Status:** Done
**Topic:** selenechat
**Branch:** `feature/thread-workspace`

---

## Development Handoff

### Current State (Phase 2 Complete)

Phase 1 (read-only workspace) and Phase 2 (chat with task creation) are implemented.

### Completed

- Phase 1: Thread context, task list, notes display
- Phase 2: Thread-scoped chat, action extraction, confirmation banner, Things integration

---

## Problem

Tasks lose connection to their "why." When a task exists in Things without thread context:
- You skip it (no motivation without meaning)
- You do it wrong (lost context about purpose)
- You re-derive the purpose each time (wastes energy)

Completing tasks doesn't feed back to threads — progress feels invisible.

---

## Solution

A **Thread Workspace** in SeleneChat where you can:
- See a thread with full context (name, why, summary)
- See all tasks linked to that thread
- Chat to plan, break down, and generate tasks
- Have tasks update and "what's next" surface automatically

---

## Design

### Entry Point

From SeleneChat's thread list, tap a thread → enter Thread Workspace mode.

### Workspace Layout

```
┌─────────────────────────────────────────┐
│ [← Back]           Thread Workspace     │
├─────────────────────────────────────────┤
│ ADHD System Design                      │
│ Why: Build tools that externalize       │
│ executive function                      │
│                                         │
│ Momentum: ●●●○○  Last: 2 days ago       │
├─────────────────────────────────────────┤
│ Tasks (3)                    [+ Add]    │
│ ○ Research time-blocking approaches     │
│ ○ Draft capture interface spec          │
│ ● Write ADHD principles doc  ✓ Done     │
├─────────────────────────────────────────┤
│ Chat                                    │
│                                         │
│ ┌─────────────────────────────────────┐ │
│ │ What would you like to explore?     │ │
│ └─────────────────────────────────────┘ │
└─────────────────────────────────────────┘
```

**Key elements:**
- Thread name + "why" always visible (no re-deriving)
- Momentum indicator (from existing thread data)
- Tasks list showing linked Things tasks
- Chat area for planning/brainstorming

### Chat Capabilities

Chat is scoped to the thread with automatic context:
- Thread summary and "why"
- Recent notes in the thread
- Current tasks (from Things via the link)

| You say | System does |
|---------|-------------|
| "Break down [task]" | Generates subtasks, offers to create in Things |
| "What do I need for this?" | Generates equipment/materials list |
| "What's blocking this?" | Explores blockers, suggests next steps |
| "Let's brainstorm [aspect]" | Open-ended thinking with thread context |
| "What's next?" | Recommends next task based on thread state |
| "Update the summary" | Regenerates thread summary from progress |

**Task creation flow:**
1. Chat generates task suggestions
2. User confirms ("yes, create those" or edits first)
3. Tasks created in Things via URL scheme
4. Link stored in Selene (`thread_tasks` table)
5. Tasks appear in workspace task list

**Principle:** Chat proposes, user confirms. Nothing created without explicit approval.

---

## Data Model

### New Table: thread_tasks

```sql
CREATE TABLE thread_tasks (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    thread_id INTEGER NOT NULL,
    things_task_id TEXT NOT NULL,
    created_at TEXT DEFAULT CURRENT_TIMESTAMP,
    completed_at TEXT,
    FOREIGN KEY (thread_id) REFERENCES threads(id) ON DELETE CASCADE,
    UNIQUE(thread_id, things_task_id)
);

CREATE INDEX idx_thread_tasks_thread ON thread_tasks(thread_id);
CREATE INDEX idx_thread_tasks_things ON thread_tasks(things_task_id);
```

**Why a new table (vs. adding thread_id to task_metadata):**
- `task_metadata` is for tasks extracted from notes (automatic flow)
- `thread_tasks` is for tasks created via conversation (explicit flow)
- Keeps the two sources separate and clear

### Completion Sync

Extend existing `sync-things-status.sh` to also update `thread_tasks.completed_at` when Things marks a task complete.

---

## Implementation

### Swift Components

**ThreadWorkspaceView** — Main workspace UI
- Header: thread name, why, momentum
- Task list: fetched from Things via `thread_tasks` links
- Chat area: scoped to this thread

**ThreadTaskService** — Manages thread ↔ task relationship
- `getTasksForThread(threadId)` → queries `thread_tasks`, fetches from Things
- `createTaskForThread(threadId, task)` → creates in Things, stores link
- `syncCompletionStatus()` → updates completion from Things

**ThreadChatViewModel** — Chat logic scoped to thread
- Builds context from: thread summary, why, recent notes, current tasks
- Handles commands: "break down", "what do I need", "what's next"
- Parses task suggestions from LLM response
- Confirmation flow before creating tasks

### Thread Summary Updates

Extend `reconsolidate-threads.ts` to include task progress:

**New inputs to summary generation:**
- Completed tasks since last summary
- Open tasks remaining
- Recent notes (existing)

**"What's next" logic:**
1. Get open tasks for thread
2. Consider: task age, thread momentum
3. LLM recommends which to tackle with brief reasoning

---

## Phases

### Phase 1: Foundation
- Add `thread_tasks` table migration
- ThreadWorkspaceView with header + task list (read-only)
- Navigate from thread list to workspace
- No chat yet — just see thread + tasks together

### Phase 2: Task Creation
- Add chat to workspace (scoped to thread)
- "Break down" and task generation commands
- Create tasks in Things + store links
- Confirmation flow before creation

### Phase 3: Feedback Loop
- Extend `sync-things-status.sh` to update `thread_tasks`
- "What's next" command
- Thread summary includes task progress
- Completion triggers summary refresh

---

## Acceptance Criteria

- [ ] Can select a thread and see its tasks in one view
- [ ] Thread "why" is always visible (no re-deriving purpose)
- [ ] Can chat to break down tasks, generate subtasks
- [ ] Generated tasks go to Things and link to thread
- [ ] Completing tasks updates thread and surfaces "what's next"

---

## ADHD Check

| Principle | How This Helps |
|-----------|----------------|
| Externalize working memory | Thread "why" always visible, not held mentally |
| Make progress visible | Task completion updates summary |
| Reduce friction | One place for thread + tasks + planning |
| Surface next action | "What's next" removes decision fatigue |
| Visual over mental | See everything in one workspace |

---

## Scope Check

**Phase 1 estimate:** Database migration + read-only workspace view
**Phase 2 estimate:** Chat integration + task creation
**Phase 3 estimate:** Sync extension + summary updates

Each phase is independently useful:
- Phase 1: See thread + tasks together (value even without chat)
- Phase 2: Plan and create tasks (core workflow)
- Phase 3: Feedback loop (polishes the experience)

---

## Related

- `docs/plans/2026-02-05-selene-thinking-partner-design.md` — Thinking Partner (chat capabilities)
- `docs/plans/2026-01-04-selene-thread-system-design.md` — Thread system design
- `scripts/things-bridge/sync-things-status.sh` — Existing Things sync
- `.claude/ADHD_Principles.md` — ADHD design framework
