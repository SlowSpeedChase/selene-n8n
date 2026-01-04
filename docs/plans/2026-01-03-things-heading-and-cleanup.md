# Things Heading Support & Legacy Cleanup Implementation Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** Add Things heading support so tasks appear under thread-named headings, and remove unused legacy code from PlanningView.

**Architecture:** Tasks created from a thread conversation will be assigned to the thread's parent project in Things, with the thread name as a heading. This maps SeleneChat threads to Things headings for organized task grouping.

**Tech Stack:** Swift, SQLite, AppleScript

---

## Task 1: Add heading support to AppleScript

**Files:**
- Modify: `scripts/things-bridge/add-task-to-things.scpt`

**Step 1: Add heading JSON field extraction**

After line 72 (projectName extraction), add:

```applescript
        -- Extract heading name (optional)
        set headingName to do shell script jqPath & " -r '.heading // \"\"' " & quoted form of jsonFilePath
```

**Step 2: Add heading assignment logic**

After line 110 (end of project/area assignment block), before tag handling, add:

```applescript
            -- Assign to heading if specified (within the project)
            if headingName is not "" then
                try
                    -- Create or find heading and move task under it
                    tell targetProject
                        set targetHeading to make new to do with properties {name:headingName, status:open}
                        set status of targetHeading to open
                    end tell
                    -- Note: Things 3 doesn't have heading API - tasks under headings must be created via URL scheme
                    -- Fallback: add heading name to notes
                    set notes of newToDo to notes of newToDo & linefeed & "[Heading: " & headingName & "]"
                on error
                    -- Ignore heading errors
                end try
            end if
```

**Note:** Things 3 AppleScript API doesn't support headings directly. We'll document the heading in notes and use URL scheme for full support in future.

**Step 3: Verify script syntax**

Run: `osacompile -o /dev/null scripts/things-bridge/add-task-to-things.scpt`
Expected: No errors

**Step 4: Commit**

```bash
git add scripts/things-bridge/add-task-to-things.scpt
git commit -m "feat(things): add heading field support to AppleScript"
```

---

## Task 2: Add heading parameter to ThingsURLService

**Files:**
- Modify: `SeleneChat/Sources/Services/ThingsURLService.swift`

**Step 1: Add heading parameter to createTask method**

Change line 114-122 from:

```swift
    func createTask(
        title: String,
        notes: String? = nil,
        tags: [String] = [],
        energy: String? = nil,
        sourceNoteId: Int? = nil,
        threadId: Int? = nil,
        project: String? = nil  // Things project name to assign to
    ) async throws -> String {
```

To:

```swift
    func createTask(
        title: String,
        notes: String? = nil,
        tags: [String] = [],
        energy: String? = nil,
        sourceNoteId: Int? = nil,
        threadId: Int? = nil,
        project: String? = nil,
        heading: String? = nil  // Things heading (sub-group within project)
    ) async throws -> String {
```

**Step 2: Include heading in JSON payload**

After line 159 (project assignment), add:

```swift
        // Add heading if specified
        if let heading = heading, !heading.isEmpty {
            taskData["heading"] = heading
        }
```

**Step 3: Verify build**

Run: `cd SeleneChat && swift build`
Expected: Build succeeds

**Step 4: Commit**

```bash
git add SeleneChat/Sources/Services/ThingsURLService.swift
git commit -m "feat(things): add heading parameter to createTask"
```

---

## Task 3: Add things_heading column to database

**Files:**
- Create: `SeleneChat/Sources/Services/Migrations/Migration007_ThingsHeading.swift`
- Modify: `SeleneChat/Sources/Services/DatabaseService.swift` (migration registration)

**Step 1: Create migration file**

```swift
// Migration007_ThingsHeading.swift
// SeleneChat
//
// Adds things_heading column to task_links for heading tracking

import Foundation
import SQLite

struct Migration007_ThingsHeading {
    static func run(db: Connection) throws {
        // Add things_heading column
        try db.run("""
            ALTER TABLE task_links ADD COLUMN things_heading TEXT
        """)

        print("Migration 007: things_heading added to task_links")
    }
}
```

**Step 2: Register migration in DatabaseService**

Find the migrations array and add Migration007:

```swift
private let migrations: [(Int, (Connection) throws -> Void)] = [
    // ... existing migrations
    (7, Migration007_ThingsHeading.run)
]
```

**Step 3: Verify build**

Run: `cd SeleneChat && swift build`
Expected: Build succeeds

**Step 4: Commit**

```bash
git add SeleneChat/Sources/Services/Migrations/Migration007_ThingsHeading.swift
git add SeleneChat/Sources/Services/DatabaseService.swift
git commit -m "feat(db): add things_heading column via Migration007"
```

---

## Task 4: Update insertTaskLink to include heading

**Files:**
- Modify: `SeleneChat/Sources/Services/DatabaseService.swift`

**Step 1: Find insertTaskLink method and add heading parameter**

Update the method signature and INSERT statement to include things_heading.

**Step 2: Update ThingsURLService.recordTaskLink call**

Pass the heading through to insertTaskLink.

**Step 3: Verify build**

Run: `cd SeleneChat && swift build`
Expected: Build succeeds

**Step 4: Commit**

```bash
git add SeleneChat/Sources/Services/DatabaseService.swift
git add SeleneChat/Sources/Services/ThingsURLService.swift
git commit -m "feat(db): record things_heading in task_links"
```

---

## Task 5: Pass thread name as heading in task creation

**Files:**
- Modify: `SeleneChat/Sources/Views/PlanningView.swift` (PlanningConversationView section)

**Step 1: Find sendAllToThings function (around line 954)**

Update the createTask call to pass thread name as heading:

```swift
try await thingsService.createTask(
    title: task.title,
    notes: nil,
    tags: [],
    energy: task.energy,
    sourceNoteId: thread.rawNoteId,
    threadId: thread.id,
    project: nil,  // TODO: Get project name from thread.projectId
    heading: thread.threadName ?? thread.prompt.prefix(50).description
)
```

**Step 2: Verify build**

Run: `cd SeleneChat && swift build`
Expected: Build succeeds

**Step 3: Commit**

```bash
git add SeleneChat/Sources/Views/PlanningView.swift
git commit -m "feat(planning): pass thread name as Things heading"
```

---

## Task 6: Remove legacy needsReviewSection

**Files:**
- Modify: `SeleneChat/Sources/Views/PlanningView.swift`

**Step 1: Remove needsReviewSection computed property**

Delete lines 379-421 (the entire `needsReviewSection` computed property).

**Step 2: Remove isNeedsReviewExpanded state variable**

Delete line 28: `@State private var isNeedsReviewExpanded = true`

**Step 3: Verify build**

Run: `cd SeleneChat && swift build`
Expected: Build succeeds (no references to removed code)

**Step 4: Commit**

```bash
git add SeleneChat/Sources/Views/PlanningView.swift
git commit -m "refactor(planning): remove legacy needsReviewSection"
```

---

## Task 7: Remove legacy planningThreadsSection

**Files:**
- Modify: `SeleneChat/Sources/Views/PlanningView.swift`

**Step 1: Remove planningThreadsSection computed property**

Delete the entire `planningThreadsSection` computed property (lines 487-529 after previous removal shifts line numbers).

**Step 2: Remove isConversationsExpanded state variable**

Delete: `@State private var isConversationsExpanded = true`

**Step 3: Check if activeThreads is still used elsewhere**

Search for `activeThreads` - if only used in removed section, remove the state variable too.

**Step 4: Verify build**

Run: `cd SeleneChat && swift build`
Expected: Build succeeds

**Step 5: Commit**

```bash
git add SeleneChat/Sources/Views/PlanningView.swift
git commit -m "refactor(planning): remove legacy planningThreadsSection"
```

---

## Task 8: Final verification and cleanup

**Step 1: Full build test**

Run: `cd SeleneChat && swift build -c release`
Expected: Build succeeds with no warnings about unused variables

**Step 2: Update design doc status**

Update `docs/plans/2026-01-03-planning-tab-redesign.md`:
- Mark "Tasks go to Things with correct heading" as complete in Success Criteria
- Update Document Status to reflect implementation

**Step 3: Commit**

```bash
git add docs/plans/2026-01-03-planning-tab-redesign.md
git commit -m "docs: mark Things heading support as complete"
```

---

## Summary

| Task | Description | Estimated Changes |
|------|-------------|-------------------|
| 1 | AppleScript heading support | ~10 lines |
| 2 | ThingsURLService heading param | ~5 lines |
| 3 | Migration007 for things_heading | New file + 1 line |
| 4 | insertTaskLink with heading | ~5 lines |
| 5 | Pass thread name as heading | ~3 lines |
| 6 | Remove needsReviewSection | Delete ~45 lines |
| 7 | Remove planningThreadsSection | Delete ~45 lines |
| 8 | Final verification | Doc update |

**Total:** ~8 commits, net reduction of ~70 lines of code
