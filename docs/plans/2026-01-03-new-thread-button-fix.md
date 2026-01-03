# New Thread Button Fix - Implementation Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** Enable the "+" button in ProjectDetailView to create new threads directly, without requiring an associated note.

**Architecture:** Currently, `discussion_threads.raw_note_id` is NOT NULL, and `createThread()` requires a note ID. We make the column nullable, update the model and service, then wire up a simple `NewThreadSheet` that collects a topic/prompt and creates the thread directly in the current project.

**Tech Stack:** Swift 5.9+, SwiftUI, SQLite.swift

**Design Doc:** Derived from `docs/plans/2026-01-03-planning-tab-redesign.md` (line 82-83 shows `[+ New thread]` button)

---

## Task 1: Create Migration to Make raw_note_id Nullable

**Files:**
- Create: `SeleneChat/Sources/Services/Migrations/Migration006_OptionalRawNoteId.swift`
- Modify: `SeleneChat/Sources/Services/DatabaseService.swift:104` (add migration call)

**Step 1: Create the migration file**

```swift
// Migration006_OptionalRawNoteId.swift
// SeleneChat
//
// Phase 7.2: Allow threads without associated notes
// Makes raw_note_id nullable to support creating threads directly from projects

import Foundation
import SQLite

struct Migration006_OptionalRawNoteId {
    static func run(db: Connection) throws {
        // SQLite doesn't support ALTER COLUMN directly.
        // Recreate table with nullable raw_note_id.

        // 1. Create new table with nullable raw_note_id
        try db.run("""
            CREATE TABLE IF NOT EXISTS discussion_threads_new (
                id INTEGER PRIMARY KEY AUTOINCREMENT,
                raw_note_id INTEGER,
                thread_type TEXT NOT NULL CHECK(thread_type IN ('planning', 'followup', 'question')),
                prompt TEXT NOT NULL,
                status TEXT DEFAULT 'pending' CHECK(status IN ('pending', 'active', 'completed', 'dismissed', 'review')),
                created_at TEXT DEFAULT CURRENT_TIMESTAMP,
                surfaced_at TEXT,
                completed_at TEXT,
                related_concepts TEXT,
                test_run TEXT DEFAULT NULL,
                project_id INTEGER REFERENCES projects(id),
                thread_name TEXT,
                resurface_reason_code TEXT,
                last_resurfaced_at TEXT,
                FOREIGN KEY (raw_note_id) REFERENCES raw_notes(id) ON DELETE SET NULL
            )
        """)

        // 2. Copy data from old table
        try db.run("""
            INSERT INTO discussion_threads_new
            SELECT id, raw_note_id, thread_type, prompt, status, created_at,
                   surfaced_at, completed_at, related_concepts, test_run,
                   project_id, thread_name, resurface_reason_code, last_resurfaced_at
            FROM discussion_threads
        """)

        // 3. Drop old table
        try db.run("DROP TABLE discussion_threads")

        // 4. Rename new table
        try db.run("ALTER TABLE discussion_threads_new RENAME TO discussion_threads")

        // 5. Recreate indexes
        try db.run("""
            CREATE INDEX IF NOT EXISTS idx_threads_project
            ON discussion_threads(project_id)
        """)

        try db.run("""
            CREATE INDEX IF NOT EXISTS idx_threads_status
            ON discussion_threads(status)
        """)

        print("Migration 006: raw_note_id is now nullable in discussion_threads")
    }
}
```

**Step 2: Add migration call to DatabaseService**

In `DatabaseService.swift`, after line 104 (`try? Migration005_ProjectThreads.run(db: db!)`), add:

```swift
            try? Migration006_OptionalRawNoteId.run(db: db!)
```

**Step 3: Build to verify migration compiles**

Run: `cd SeleneChat && swift build`
Expected: Build succeeds

**Step 4: Commit**

```bash
git add SeleneChat/Sources/Services/Migrations/Migration006_OptionalRawNoteId.swift
git add SeleneChat/Sources/Services/DatabaseService.swift
git commit -m "feat(db): add Migration006 to make raw_note_id nullable"
```

---

## Task 2: Update DiscussionThread Model

**Files:**
- Modify: `SeleneChat/Sources/Models/DiscussionThread.swift:5`

**Step 1: Change rawNoteId from Int to Int?**

Change line 5 from:
```swift
    let rawNoteId: Int
```

To:
```swift
    let rawNoteId: Int?
```

**Step 2: Build to verify model compiles**

Run: `cd SeleneChat && swift build`
Expected: Build may have errors in DatabaseService where rawNoteId is used - that's expected, we fix in Task 3

**Step 3: Commit**

```bash
git add SeleneChat/Sources/Models/DiscussionThread.swift
git commit -m "feat(model): make rawNoteId optional in DiscussionThread"
```

---

## Task 3: Update DatabaseService for Optional rawNoteId

**Files:**
- Modify: `SeleneChat/Sources/Services/DatabaseService.swift`

**Step 1: Update threadRawNoteId expression type**

Find line with `private let threadRawNoteId` and change from:
```swift
    private let threadRawNoteId = Expression<Int64>("raw_note_id")
```

To:
```swift
    private let threadRawNoteId = Expression<Int64?>("raw_note_id")
```

**Step 2: Update createThread signature and implementation**

Find the `createThread` function (around line 1030) and modify:

```swift
    func createThread(
        projectId: Int,
        rawNoteId: Int?,  // Changed from Int to Int?
        threadType: DiscussionThread.ThreadType,
        prompt: String,
        threadName: String? = nil  // Added for direct naming
    ) async throws -> DiscussionThread {
        guard let db = db else {
            throw DatabaseError.notConnected
        }

        let dateFormatter = ISO8601DateFormatter()
        let now = dateFormatter.string(from: Date())

        var setter: [Setter] = [
            self.threadType <- threadType.rawValue,
            threadPrompt <- prompt,
            threadStatus <- "active",  // Start as active since user initiated
            threadCreatedAt <- now,
            threadProjectId <- Int64(projectId)
        ]

        // Only add rawNoteId if provided
        if let noteId = rawNoteId {
            setter.append(threadRawNoteId <- Int64(noteId))
        }

        // Add thread name if provided
        if let name = threadName {
            setter.append(self.threadName <- name)
        }

        let insertId = try db.run(discussionThreads.insert(setter))

        return DiscussionThread(
            id: Int(insertId),
            rawNoteId: rawNoteId,
            threadType: threadType,
            projectId: projectId,
            threadName: threadName,
            prompt: prompt,
            status: .active,
            createdAt: Date(),
            surfacedAt: nil,
            completedAt: nil,
            relatedConcepts: nil
        )
    }
```

**Step 3: Update fetchThreadsForProject to handle nullable rawNoteId**

In `fetchThreadsForProject` (around line 1000), update the row parsing:

```swift
            let thread = DiscussionThread(
                id: Int(try row.get(threadId)),
                rawNoteId: (try? row.get(threadRawNoteId)).map { Int($0) },  // Handle nullable
                threadType: DiscussionThread.ThreadType(rawValue: try row.get(self.threadType)) ?? .planning,
                // ... rest unchanged
            )
```

**Step 4: Build to verify all usages compile**

Run: `cd SeleneChat && swift build`
Expected: Build succeeds

**Step 5: Commit**

```bash
git add SeleneChat/Sources/Services/DatabaseService.swift
git commit -m "feat(db): update createThread to accept optional rawNoteId"
```

---

## Task 4: Create NewThreadSheet Component

**Files:**
- Create: `SeleneChat/Sources/Views/Planning/NewThreadSheet.swift`

**Step 1: Create the sheet view**

```swift
// NewThreadSheet.swift
// SeleneChat
//
// Phase 7.2: Planning Tab Redesign
// Simple sheet for creating a new thread directly in a project

import SwiftUI

struct NewThreadSheet: View {
    let projectId: Int
    let projectName: String
    let onCreate: (DiscussionThread) -> Void
    let onCancel: () -> Void

    @EnvironmentObject var databaseService: DatabaseService
    @State private var topic = ""
    @State private var isCreating = false
    @State private var errorMessage: String?

    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                Text("New Thread")
                    .font(.headline)
                Spacer()
                Button(action: onCancel) {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundColor(.secondary)
                }
                .buttonStyle(.plain)
            }
            .padding()

            Divider()

            // Project context
            HStack {
                Image(systemName: "folder")
                    .foregroundColor(.secondary)
                Text("In: \(projectName)")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                Spacer()
            }
            .padding(.horizontal)
            .padding(.vertical, 8)
            .background(Color.accentColor.opacity(0.05))

            Divider()

            // Topic input
            VStack(alignment: .leading, spacing: 8) {
                Text("What do you want to discuss?")
                    .font(.subheadline)
                    .foregroundColor(.secondary)

                TextField("e.g., API design for user auth", text: $topic)
                    .textFieldStyle(.roundedBorder)
                    .onSubmit { createThread() }

                Text("This becomes the thread's name. You can always change it later.")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            .padding()

            if let error = errorMessage {
                Text(error)
                    .font(.caption)
                    .foregroundColor(.red)
                    .padding(.horizontal)
            }

            Spacer()

            Divider()

            // Actions
            HStack {
                Button("Cancel") { onCancel() }
                    .keyboardShortcut(.escape)

                Spacer()

                Button("Create Thread") {
                    createThread()
                }
                .keyboardShortcut(.return)
                .buttonStyle(.borderedProminent)
                .disabled(!canCreate || isCreating)
            }
            .padding()
        }
        .frame(width: 400, height: 280)
    }

    private var canCreate: Bool {
        !topic.trimmingCharacters(in: .whitespaces).isEmpty
    }

    private func createThread() {
        guard canCreate else { return }

        isCreating = true
        errorMessage = nil

        Task {
            do {
                let thread = try await databaseService.createThread(
                    projectId: projectId,
                    rawNoteId: nil,  // No associated note
                    threadType: .planning,
                    prompt: topic.trimmingCharacters(in: .whitespaces),
                    threadName: topic.trimmingCharacters(in: .whitespaces)
                )
                await MainActor.run {
                    onCreate(thread)
                }
            } catch {
                await MainActor.run {
                    errorMessage = "Failed to create thread: \(error.localizedDescription)"
                    isCreating = false
                }
            }
        }
    }
}
```

**Step 2: Build to verify component compiles**

Run: `cd SeleneChat && swift build`
Expected: Build succeeds

**Step 3: Commit**

```bash
git add SeleneChat/Sources/Views/Planning/NewThreadSheet.swift
git commit -m "feat(view): add NewThreadSheet for creating threads directly"
```

---

## Task 5: Wire Up Sheet in ProjectDetailView

**Files:**
- Modify: `SeleneChat/Sources/Views/ProjectDetailView.swift`

**Step 1: Add sheet modifier after the body's closing brace**

After the closing `}` of `var body: some View {` (around line 122), before `onAppear`, add:

```swift
        .sheet(isPresented: $showNewThreadSheet) {
            NewThreadSheet(
                projectId: project.id,
                projectName: project.name,
                onCreate: { thread in
                    showNewThreadSheet = false
                    selectedThread = thread
                },
                onCancel: {
                    showNewThreadSheet = false
                }
            )
        }
```

**Step 2: Build to verify wiring compiles**

Run: `cd SeleneChat && swift build`
Expected: Build succeeds

**Step 3: Commit**

```bash
git add SeleneChat/Sources/Views/ProjectDetailView.swift
git commit -m "feat(view): wire up NewThreadSheet in ProjectDetailView"
```

---

## Task 6: Build, Test, and Verify

**Step 1: Full build**

Run: `cd SeleneChat && swift build`
Expected: Build succeeds with no errors

**Step 2: Manual verification checklist**

1. Open SeleneChat
2. Go to Planning tab
3. Click on any project to open ProjectDetailView
4. Click the "+" button in the Threads section header
5. Verify: NewThreadSheet appears
6. Enter a topic like "Test thread"
7. Click "Create Thread"
8. Verify: Sheet closes, new thread appears in list

**Step 3: Final commit with verification**

```bash
git add -A
git commit -m "chore: verify new thread button fix complete"
```

---

## Summary

| Task | Description | Files |
|------|-------------|-------|
| 1 | Migration to make raw_note_id nullable | Migration006_OptionalRawNoteId.swift |
| 2 | Update DiscussionThread model | DiscussionThread.swift |
| 3 | Update DatabaseService for optional rawNoteId | DatabaseService.swift |
| 4 | Create NewThreadSheet component | NewThreadSheet.swift |
| 5 | Wire up sheet in ProjectDetailView | ProjectDetailView.swift |
| 6 | Build and verify | - |

**Estimated commits:** 6
**Key principle:** Each task is one logical change with a commit.

---

## Root Cause Reference

**Bug:** The "+" button in ProjectDetailView sets `showNewThreadSheet = true` but no `.sheet` modifier exists to present anything.

**Location:** `ProjectDetailView.swift:100` - button action exists, sheet presentation missing.

**Additional blocker:** `createThread()` required a `rawNoteId`, but creating a thread directly from a project has no associated note.
