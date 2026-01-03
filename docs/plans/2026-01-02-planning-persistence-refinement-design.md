# Planning Conversation Persistence & Task Refinement

**Status:** Ready for Implementation
**Created:** 2026-01-02
**Author:** Chase Easterling + Claude

---

## Overview

Enable SeleneChat to persist planning conversations and refine tasks that are already in Things. When returning to a planning thread, the AI has context (tasks + recent messages) to continue intelligently. Tasks can be refined from SeleneChat or by adding a `#refine` tag in Things.

**Key Principles:**
- Action-focused context (tasks + status over verbatim history)
- ADHD-friendly (no decision fatigue, automatic smart defaults)
- Builds on existing 7.2e/7.2f infrastructure

---

## Features

| Feature | Description |
|---------|-------------|
| **Conversation Persistence** | Store last 15 messages per thread, resume with full context |
| **Task Refinement (SeleneChat)** | Tap any task to refine/break down |
| **Task Refinement (Things)** | Add `#refine` tag, appears in SeleneChat |
| **Smart Output** | 2-4 items → checklist, 5+ items → project |
| **Sequencing Support** | Ask "in order or any order?", use defer dates |

---

## Architecture

### Conversation Resume Flow

```
┌─────────────────────────────────────────────────────────────┐
│ User opens Planning tab / selects thread                     │
└─────────────────────────────────────────────────────────────┘
                            │
                            ▼
┌─────────────────────────────────────────────────────────────┐
│ 1. Sync task statuses from Things (existing 7.2e)           │
│ 2. Load thread metadata from discussion_threads             │
│ 3. Load messages from planning_messages (last 15)           │
│ 4. Query task_links for tasks created in this thread        │
│ 5. Build AI context prompt                                   │
└─────────────────────────────────────────────────────────────┘
                            │
                            ▼
┌─────────────────────────────────────────────────────────────┐
│ Context sent to AI:                                          │
│                                                              │
│ """                                                          │
│ You're continuing a planning conversation.                   │
│                                                              │
│ ORIGINAL TOPIC:                                              │
│ [Thread prompt from discussion_threads.prompt]               │
│                                                              │
│ TASKS CREATED (current status):                              │
│ - ✅ Task 1 (completed Jan 2)                               │
│ - 🔲 Task 2 (open)                                          │
│ - 🔲 Task 3 (open)                                          │
│                                                              │
│ RECENT CONVERSATION:                                         │
│ [Last 15 messages]                                           │
│ """                                                          │
└─────────────────────────────────────────────────────────────┘
```

### Task Refinement Flow (via #refine tag)

```
┌─────────────────────────────────────────────────────────────┐
│ Things 3                                                     │
│   Task: "Fix the website performance issues"                │
│   Tags: #refine                                              │
└─────────────────────────────────────────────────────────────┘
                            │
                            ▼ (sync on Planning tab open)
┌─────────────────────────────────────────────────────────────┐
│ SeleneChat - Planning Tab                                    │
│                                                              │
│ ┌─ NEEDS REFINEMENT ──────────────────────────────────────┐ │
│ │ 🔧 Fix the website performance issues                   │ │
│ │    Added 2 hours ago                                    │ │
│ └─────────────────────────────────────────────────────────┘ │
│                                                              │
│ ┌─ ACTIVE THREADS ────────────────────────────────────────┐ │
│ │ ...                                                     │ │
└─────────────────────────────────────────────────────────────┘
                            │
                            ▼ (tap task)
┌─────────────────────────────────────────────────────────────┐
│ Refinement Conversation                                      │
│                                                              │
│ 🤖 "Let's break down 'Fix website performance issues'.      │
│     What's the main problem you're seeing?"                 │
│                                                              │
│ 👤 "Pages load slow, especially the dashboard"              │
│                                                              │
│ 🤖 "Got it. Here's a breakdown:                             │
│     1. Profile dashboard load time                          │
│     2. Identify slow queries                                │
│     3. Add caching layer                                    │
│     4. Test and measure improvement                         │
│                                                              │
│     4 items - I'll add these as a checklist.               │
│     Should these be done in order, or any order?"          │
└─────────────────────────────────────────────────────────────┘
```

### Smart Output Rules

| Breakdown Size | Action | Rationale |
|----------------|--------|-----------|
| 2-4 items | Add as checklist items inside original task | Small breakdowns stay simple |
| 5+ items | Convert to Things project with tasks inside | Large breakdowns need visibility |

**No user decision required** - automatic based on count (ADHD-friendly).

### Sequencing

Things doesn't have native task dependencies. Workaround:

| User Choice | Implementation |
|-------------|----------------|
| **"In order"** | First task: no defer. Others: defer to "Someday" with note "After: [Previous Task]" |
| **"Any order"** | All tasks available immediately |

**Follow-up (via 7.2e sync):** When Task 1 completes, SeleneChat can prompt "Task 1 done! Ready to start Task 2?" and un-defer.

---

## Database Changes

### New Table: planning_messages

```sql
CREATE TABLE planning_messages (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    thread_id INTEGER NOT NULL,
    role TEXT NOT NULL CHECK(role IN ('user', 'assistant', 'system', 'task_created')),
    content TEXT NOT NULL,
    created_at TEXT DEFAULT CURRENT_TIMESTAMP,

    -- For task_created messages, link to the task
    task_link_id INTEGER,

    FOREIGN KEY (thread_id) REFERENCES discussion_threads(id) ON DELETE CASCADE,
    FOREIGN KEY (task_link_id) REFERENCES task_links(id)
);

CREATE INDEX idx_planning_messages_thread ON planning_messages(thread_id);
```

### Modification: task_links

```sql
ALTER TABLE task_links ADD COLUMN refine_tag_detected_at TEXT;
```

### Rolling Window

Keep last 15 messages per thread. On insert:

```sql
-- Delete oldest messages beyond 15
DELETE FROM planning_messages
WHERE thread_id = ?
AND id NOT IN (
    SELECT id FROM planning_messages
    WHERE thread_id = ?
    ORDER BY created_at DESC
    LIMIT 15
);
```

---

## New Scripts

```
scripts/things-bridge/
├── get-tasks-with-tag.scpt     # Find tasks tagged #refine
├── add-checklist-item.scpt     # Add checklist item to existing task
├── remove-tag.scpt             # Remove #refine after refinement complete
└── (existing scripts unchanged)
```

### get-tasks-with-tag.scpt

```applescript
on run argv
    set tagName to item 1 of argv

    tell application "Things3"
        set matchingTasks to to dos whose tag names contains tagName
        set output to "["

        repeat with t in matchingTasks
            set taskId to id of t
            set taskName to name of t
            -- Build JSON array
            set output to output & "{\"id\":\"" & taskId & "\",\"name\":\"" & taskName & "\"},"
        end repeat

        -- Remove trailing comma and close array
        if output ends with "," then
            set output to text 1 thru -2 of output
        end if
        set output to output & "]"

        return output
    end tell
end run
```

### add-checklist-item.scpt

```applescript
on run argv
    set taskId to item 1 of argv
    set itemTitle to item 2 of argv

    tell application "Things3"
        set targetTask to to do id taskId

        -- Things uses "checklist items" within a to do
        tell targetTask
            make new to do with properties {name:itemTitle}
        end tell

        return "success"
    end tell
end run
```

### remove-tag.scpt

```applescript
on run argv
    set taskId to item 1 of argv
    set tagName to item 2 of argv

    tell application "Things3"
        set targetTask to to do id taskId
        set currentTags to tag names of targetTask

        -- Remove the specified tag
        set newTags to {}
        repeat with t in currentTags
            if t as string is not equal to tagName then
                set end of newTags to t
            end if
        end repeat

        set tag names of targetTask to newTags
        return "success"
    end tell
end run
```

---

## Swift Changes

### DatabaseService.swift

```swift
// MARK: - Planning Messages

func saveMessage(threadId: Int64, role: String, content: String, taskLinkId: Int64? = nil) throws {
    let insert = planning_messages.insert(
        thread_id_col <- threadId,
        role_col <- role,
        content_col <- content,
        task_link_id_col <- taskLinkId,
        created_at_col <- ISO8601DateFormatter().string(from: Date())
    )
    try db.run(insert)

    // Prune old messages (keep last 15)
    try pruneOldMessages(threadId: threadId)
}

func loadMessages(threadId: Int64) throws -> [PlanningMessage] {
    let query = planning_messages
        .filter(thread_id_col == threadId)
        .order(created_at_col.asc)
        .limit(15)

    return try db.prepare(query).map { row in
        PlanningMessage(
            id: row[id_col],
            role: PlanningMessage.Role(rawValue: row[role_col]) ?? .system,
            content: row[content_col],
            taskLinkId: row[task_link_id_col],
            createdAt: row[created_at_col]
        )
    }
}

func pruneOldMessages(threadId: Int64, keepCount: Int = 15) throws {
    let oldMessages = planning_messages
        .filter(thread_id_col == threadId)
        .order(created_at_col.desc)
        .limit(-1, offset: keepCount)

    try db.run(oldMessages.delete())
}
```

### PlanningView.swift Changes

```swift
// Add "Needs Refinement" section
struct PlanningView: View {
    @State private var tasksNeedingRefinement: [ThingsTask] = []

    var body: some View {
        List {
            // NEW: Needs Refinement section
            if !tasksNeedingRefinement.isEmpty {
                Section("Needs Refinement") {
                    ForEach(tasksNeedingRefinement) { task in
                        RefinementRow(task: task)
                            .onTapGesture {
                                startRefinementConversation(for: task)
                            }
                    }
                }
            }

            // Existing sections...
            Section("Active Threads") { ... }
            Section("Completed") { ... }
        }
        .task {
            await loadTasksWithRefineTag()
        }
    }

    private func loadTasksWithRefineTag() async {
        // Call AppleScript to get tasks tagged #refine
        tasksNeedingRefinement = await thingsService.getTasksWithTag("refine")
    }
}

// Persist messages on send
private func sendMessage(_ content: String) async {
    // Save user message
    try? await databaseService.saveMessage(
        threadId: currentThread.id,
        role: "user",
        content: content
    )

    // Get AI response...
    let response = try await providerService.sendPlanningMessage(...)

    // Save assistant message
    try? await databaseService.saveMessage(
        threadId: currentThread.id,
        role: "assistant",
        content: response.content
    )
}
```

### ThingsStatusService.swift Additions

```swift
func getTasksWithTag(_ tag: String) async -> [ThingsTask] {
    let scriptPath = Bundle.main.path(forResource: "get-tasks-with-tag", ofType: "scpt")
    // Execute AppleScript and parse JSON response
    ...
}

func addChecklistItem(taskId: String, title: String) async throws {
    let scriptPath = Bundle.main.path(forResource: "add-checklist-item", ofType: "scpt")
    // Execute AppleScript
    ...
}

func removeTag(taskId: String, tag: String) async throws {
    let scriptPath = Bundle.main.path(forResource: "remove-tag", ofType: "scpt")
    // Execute AppleScript
    ...
}
```

---

## UI Changes

### Planning Tab Layout

```
┌─────────────────────────────────────────────────────────────┐
│ Planning                                            [⚙️]    │
├─────────────────────────────────────────────────────────────┤
│                                                              │
│ ┌─ NEEDS REFINEMENT ──────────────────────────────────────┐ │
│ │ 🔧 Fix the website performance issues        2h ago    │ │
│ │ 🔧 Plan Q1 marketing campaign                1d ago    │ │
│ └─────────────────────────────────────────────────────────┘ │
│                                                              │
│ ┌─ REVIEW (resurfaced) ───────────────────────────────────┐ │
│ │ 💬 Database migration planning    50% complete         │ │
│ └─────────────────────────────────────────────────────────┘ │
│                                                              │
│ ┌─ ACTIVE ────────────────────────────────────────────────┐ │
│ │ 💬 API redesign discussion        3 tasks              │ │
│ │ 💬 Onboarding flow improvements   5 tasks              │ │
│ └─────────────────────────────────────────────────────────┘ │
│                                                              │
└─────────────────────────────────────────────────────────────┘
```

### Conversation View (with task progress)

```
┌─────────────────────────────────────────────────────────────┐
│ ← Back    API redesign discussion                    [...] │
├─────────────────────────────────────────────────────────────┤
│ ┌─ TASK PROGRESS ─────────────────────────────────────────┐ │
│ │ ✅ Define API endpoints                                 │ │
│ │ ✅ Write OpenAPI spec                                   │ │
│ │ 🔲 Implement authentication                             │ │
│ │ 🔲 Add rate limiting                                    │ │
│ │ 🔲 Write documentation                                  │ │
│ └─────────────────────────────────────────────────────────┘ │
│                                                              │
│ 👤 Should we use JWT or session tokens?                     │
│                                                              │
│ 🤖 For a public API, JWT is typically better because...     │
│                                                              │
│ [Message input field]                            [Send]     │
└─────────────────────────────────────────────────────────────┘
```

---

## Integration with Existing Designs

| Existing Design | How This Feature Uses It |
|-----------------|--------------------------|
| **7.2e: Status sync** | Task status (✅/🔲) from existing sync on tab open |
| **7.2e: Resurface triggers** | Conversation persistence enables context when resurfaced |
| **7.2f: Project creation** | Refinement with 5+ tasks uses existing project scripts |
| **7.2f: Auto-assignment** | Sub-tasks inherit concept, auto-assign to project |

---

## Implementation Order

1. **Database migration** - Add `planning_messages` table and `task_links.refine_tag_detected_at`
2. **DatabaseService** - Add message save/load/prune methods
3. **PlanningView persistence** - Save messages on send, load on thread open
4. **Context building** - Build AI resume context with tasks + messages
5. **AppleScripts** - Create get-tasks-with-tag, add-checklist-item, remove-tag
6. **ThingsStatusService** - Add Swift wrappers for new scripts
7. **Refinement UI** - Add "Needs Refinement" section to Planning tab
8. **Refinement conversation** - Implement guided breakdown flow
9. **Smart output** - Checklist vs project logic based on item count
10. **Sequencing** - Add "in order or any order" prompt and defer date handling

---

## Success Criteria

### Conversation Persistence
- [ ] Messages saved to database on send
- [ ] Messages loaded when returning to thread
- [ ] Rolling window keeps last 15 messages
- [ ] AI receives context with tasks + recent messages
- [ ] AI continues conversation naturally

### Task Refinement
- [ ] #refine tag detected on sync
- [ ] Tasks appear in "Needs Refinement" section
- [ ] Tapping starts refinement conversation
- [ ] 2-4 items → checklist added to original task
- [ ] 5+ items → Things project created
- [ ] #refine tag removed after completion

### Sequencing
- [ ] "In order or any order?" prompt shown
- [ ] "In order" defers subsequent tasks
- [ ] Task completion can trigger un-defer prompt

---

## Future Enhancements

### Emotional/Procrastination Layer
- Track when tasks sit untouched
- Surface prompts: "This has been open 5 days. What's blocking you?"
- Connect to Selene knowledge for personalized strategies
- Build procrastination pattern recognition over time

### Refinement from SeleneChat
- Browse all Things tasks (not just #refine tagged)
- Quick refinement without going to Things first

---

## Related Documentation

- [Phase 7.2e: Bidirectional Things Flow](./2026-01-02-bidirectional-things-flow-design.md)
- [Phase 7.2f: Project Grouping](./2026-01-01-project-grouping-design.md)
- [Phase 7.2: SeleneChat Planning Design](./2025-12-31-phase-7.2-selenechat-planning-design.md)
