# Thread Workspace Phase 3: Feedback Loop

**Date:** 2026-02-13
**Status:** Done
**Topic:** selenechat

---

## Problem

Tasks flow out of thread workspaces into Things, but completion status never comes back. Progress is invisible — you don't know what's done without checking Things manually, momentum scores don't reflect task completion, and there's no guidance on what to tackle next.

---

## Solution

Close the feedback loop with three components:

1. **On-demand sync** — When you open a thread workspace, Selene queries Things for completion status of all linked tasks and updates the database.
2. **Momentum boost** — Task completions count as thread activity, making threads with progress "hotter" in the Today view.
3. **"What's next" command** — LLM-powered recommendation of which task to tackle, with reasoning based on thread context.

---

## Design

### On-Demand Task Sync

When `ThreadWorkspaceView` appears, it calls `ThingsURLService.syncTaskStatuses(for:)`. For each incomplete `ThreadTask`, it runs `get-task-status.scpt` with the Things task ID. If Things reports the task completed, it calls `DatabaseService.markThreadTaskCompleted()` and refreshes the task list.

Only incomplete tasks are checked. A typical thread has 3-5 tasks, so sync takes under a second.

**Files:**
- Modify: `ThingsURLService.swift` — add `syncTaskStatuses(for tasks: [ThreadTask]) -> [String]` (returns IDs of newly completed tasks)
- Modify: `ThreadWorkspaceView.swift` — call sync on appear, refresh task list

### Momentum Boost from Task Completion

A new `thread_activity` table records events that affect momentum:

```sql
CREATE TABLE thread_activity (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    thread_id INTEGER NOT NULL,
    activity_type TEXT NOT NULL CHECK(activity_type IN ('note_added', 'task_completed')),
    occurred_at TEXT DEFAULT CURRENT_TIMESTAMP,
    FOREIGN KEY (thread_id) REFERENCES threads(id) ON DELETE CASCADE
);

CREATE INDEX idx_thread_activity_thread ON thread_activity(thread_id);
CREATE INDEX idx_thread_activity_recent ON thread_activity(occurred_at);
```

When sync discovers a newly completed task, it inserts a `task_completed` row. The hourly `reconsolidate-threads.ts` extends its momentum calculation to include recent `thread_activity` rows alongside note activity.

Momentum calculation stays centralized in TypeScript (single source of truth). Swift records events; TypeScript computes scores.

**Files:**
- Create: `database/migrations/018_thread_activity.sql`
- Modify: `DatabaseService.swift` — add `recordThreadActivity(threadId:, type:, timestamp:)`
- Modify: `reconsolidate-threads.ts` — extend momentum query to include `thread_activity`

### LLM-Powered "What's Next"

When the user sends "what's next" in workspace chat, the system builds a specialized prompt with:

- Thread summary and "why"
- Open tasks (titles + ages)
- Recently completed tasks (last 5)
- Recent notes in the thread

The prompt asks Ollama to recommend one task with brief reasoning (considering energy, dependencies, momentum). Goes through the existing Ollama chat pipeline — no new service needed.

Detection: `ThreadWorkspacePromptBuilder` gets `isWhatsNextQuery()` (pattern match on "what's next", "what should I do", etc.) and `buildWhatsNextPrompt()` with task-focused context.

**Files:**
- Modify: `ThreadWorkspacePromptBuilder.swift` — add `isWhatsNextQuery()` and `buildWhatsNextPrompt()`
- Modify: `ThreadWorkspaceChatViewModel.swift` — detect "what's next" queries, use specialized prompt

---

## Architecture Decision: All in Swift

The sync, activity recording, and "what's next" logic all live in SeleneChat. No new TypeScript workflows or launchd jobs. On-demand sync is fundamentally UI-triggered — keeping it in Swift avoids unnecessary hops (Swift → TypeScript → AppleScript) and extra moving parts.

The one exception is momentum calculation, which stays in `reconsolidate-threads.ts` to maintain a single source of truth for thread scores.

---

## Acceptance Criteria

- [ ] Opening a thread workspace syncs task completion status from Things
- [ ] Newly completed tasks show as done in the workspace task list
- [ ] Task completions boost thread momentum scores
- [ ] "What's next" in workspace chat returns an LLM recommendation with reasoning
- [ ] Sync handles edge cases: Things unreachable, task deleted in Things, task already marked complete

## ADHD Check

- [x] **Makes progress visible?** Yes — completed tasks are reflected without manual checking
- [x] **Reduces friction?** Yes — no need to cross-reference Things and Selene
- [x] **Externalizes cognition?** Yes — "what's next" removes decision fatigue about task selection
- [x] **Surfaces next action?** Yes — LLM recommendation with reasoning

## Scope Check

- [x] Less than 1 week of focused work? Yes — 3 components, each ~1 day
