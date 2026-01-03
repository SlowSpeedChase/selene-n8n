# Planning Tab Redesign Implementation Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** Restructure Planning tab so projects contain threads, Active Projects appears first, and no standalone conversations exist.

**Architecture:** Projects are containers for sub-topic threads. Each thread has its own focused conversation. The Scratch Pad is a system project for loose threads. Section order: Active Projects → Scratch Pad → Suggestions → Inbox → Parked.

**Tech Stack:** Swift 5.9+, SwiftUI, SQLite.swift

**Design Doc:** `docs/plans/2026-01-03-planning-tab-redesign.md`

---

## Task 1: Database Migration - Add Thread-Project Relationship

**Files:**
- Create: `SeleneChat/Sources/Services/Migrations/Migration005_ProjectThreads.swift`
- Modify: `SeleneChat/Sources/Services/DatabaseService.swift:100` (add migration call)

**Step 1: Create the migration file**

```swift
// Migration005_ProjectThreads.swift
// SeleneChat
//
// Phase 7.2: Planning Tab Redesign
// Adds project_id and thread_name to discussion_threads
// Creates system Scratch Pad project

import Foundation
import SQLite

struct Migration005_ProjectThreads {
    static func run(db: Connection) throws {
        // Add project_id column (nullable for migration, will default to Scratch Pad)
        try db.run("""
            ALTER TABLE discussion_threads ADD COLUMN project_id INTEGER
            REFERENCES projects(id)
        """)

        // Add thread_name column (auto-generated from first message)
        try db.run("""
            ALTER TABLE discussion_threads ADD COLUMN thread_name TEXT
        """)

        // Create index for quick project->threads lookup
        try db.run("""
            CREATE INDEX IF NOT EXISTS idx_threads_project
            ON discussion_threads(project_id)
        """)

        // Create system Scratch Pad project (id=1, is_system=1)
        try db.run("""
            INSERT OR IGNORE INTO projects (id, name, status, is_system, created_at, last_active_at)
            VALUES (1, 'Scratch Pad', 'active', 1, datetime('now'), datetime('now'))
        """)

        // Add is_system column to projects if not exists
        do {
            try db.run("ALTER TABLE projects ADD COLUMN is_system INTEGER DEFAULT 0")
        } catch {
            // Column may already exist
        }

        // Migrate existing orphan threads to Scratch Pad
        try db.run("""
            UPDATE discussion_threads
            SET project_id = 1
            WHERE project_id IS NULL
        """)

        print("Migration 005: project_id added to discussion_threads, Scratch Pad created")
    }
}
```

**Step 2: Add migration call to DatabaseService**

In `DatabaseService.swift`, after line 100 (Migration004), add:

```swift
try? Migration005_ProjectThreads.run(db: db!)
```

**Step 3: Build to verify migration compiles**

Run: `cd SeleneChat && swift build`
Expected: Build succeeds

**Step 4: Commit**

```bash
git add SeleneChat/Sources/Services/Migrations/Migration005_ProjectThreads.swift
git add SeleneChat/Sources/Services/DatabaseService.swift
git commit -m "feat(db): add Migration005 for thread-project relationship"
```

---

## Task 2: Update DiscussionThread Model

**Files:**
- Modify: `SeleneChat/Sources/Models/DiscussionThread.swift`

**Step 1: Add new properties to DiscussionThread**

After line 6 (`let threadType: ThreadType`), add:

```swift
    var projectId: Int?
    var threadName: String?
```

**Step 2: Build to verify model compiles**

Run: `cd SeleneChat && swift build`
Expected: Build succeeds (may have warnings about unused properties)

**Step 3: Commit**

```bash
git add SeleneChat/Sources/Models/DiscussionThread.swift
git commit -m "feat(model): add projectId and threadName to DiscussionThread"
```

---

## Task 3: Update Project Model for System Flag

**Files:**
- Modify: `SeleneChat/Sources/Models/Project.swift`

**Step 1: Add isSystem property**

After line 12 (`var testRun: String?`), add:

```swift
    var isSystem: Bool = false
```

**Step 2: Add thread count property**

After line 17 (`var completedTaskCount: Int = 0`), add:

```swift
    var threadCount: Int = 0
    var hasReviewBadge: Bool = false
```

**Step 3: Build to verify**

Run: `cd SeleneChat && swift build`
Expected: Build succeeds

**Step 4: Commit**

```bash
git add SeleneChat/Sources/Models/Project.swift
git commit -m "feat(model): add isSystem, threadCount, hasReviewBadge to Project"
```

---

## Task 4: Add Thread CRUD to DatabaseService

**Files:**
- Modify: `SeleneChat/Sources/Services/DatabaseService.swift`

**Step 1: Add column expressions for new fields**

After line 76 (`private let threadTestRun`), add:

```swift
    private let threadProjectId = Expression<Int64?>("project_id")
    private let threadName = Expression<String?>("thread_name")
```

**Step 2: Add fetchThreadsForProject method**

At the end of the class (before the closing `}`), add:

```swift
    // MARK: - Thread-Project Operations

    func fetchThreadsForProject(_ projectIdValue: Int) async throws -> [DiscussionThread] {
        guard let db = db else {
            throw DatabaseError.notConnected
        }

        let query = discussionThreads
            .filter(threadProjectId == Int64(projectIdValue))
            .filter(threadTestRun == nil)
            .order(threadCreatedAt.desc)

        var threads: [DiscussionThread] = []
        let dateFormatter = ISO8601DateFormatter()

        for row in try db.prepare(query) {
            let thread = DiscussionThread(
                id: Int(try row.get(threadId)),
                rawNoteId: Int(try row.get(threadRawNoteId)),
                threadType: DiscussionThread.ThreadType(rawValue: try row.get(threadType)) ?? .planning,
                prompt: try row.get(threadPrompt),
                status: DiscussionThread.Status(rawValue: try row.get(threadStatus)) ?? .pending,
                createdAt: dateFormatter.date(from: try row.get(threadCreatedAt)) ?? Date(),
                surfacedAt: (try? row.get(threadSurfacedAt)).flatMap { dateFormatter.date(from: $0) },
                completedAt: (try? row.get(threadCompletedAt)).flatMap { dateFormatter.date(from: $0) },
                relatedConcepts: (try? row.get(threadRelatedConcepts)).flatMap { try? JSONDecoder().decode([String].self, from: $0.data(using: .utf8)!) },
                projectId: (try? row.get(threadProjectId)).map { Int($0) },
                threadName: try? row.get(threadName)
            )
            threads.append(thread)
        }

        return threads
    }

    func createThread(
        projectId: Int,
        rawNoteId: Int,
        threadType: DiscussionThread.ThreadType,
        prompt: String
    ) async throws -> DiscussionThread {
        guard let db = db else {
            throw DatabaseError.notConnected
        }

        let dateFormatter = ISO8601DateFormatter()
        let now = dateFormatter.string(from: Date())

        let id = try db.run(discussionThreads.insert(
            threadRawNoteId <- Int64(rawNoteId),
            threadType <- threadType.rawValue,
            threadPrompt <- prompt,
            threadStatus <- "pending",
            threadCreatedAt <- now,
            threadProjectId <- Int64(projectId)
        ))

        return DiscussionThread(
            id: Int(id),
            rawNoteId: rawNoteId,
            threadType: threadType,
            prompt: prompt,
            status: .pending,
            createdAt: Date(),
            projectId: projectId
        )
    }

    func updateThreadName(_ threadIdValue: Int, name: String) async throws {
        guard let db = db else {
            throw DatabaseError.notConnected
        }

        let thread = discussionThreads.filter(threadId == Int64(threadIdValue))
        try db.run(thread.update(threadName <- name))
    }

    func moveThreadToProject(_ threadIdValue: Int, projectId: Int) async throws {
        guard let db = db else {
            throw DatabaseError.notConnected
        }

        let thread = discussionThreads.filter(threadId == Int64(threadIdValue))
        try db.run(thread.update(threadProjectId <- Int64(projectId)))
    }

    func getScratchPadProject() async throws -> Project? {
        guard let db = db else {
            throw DatabaseError.notConnected
        }

        let projects = Table("projects")
        let isSystem = Expression<Int64>("is_system")
        let query = projects.filter(isSystem == 1).limit(1)

        guard let row = try db.pluck(query) else { return nil }

        let dateFormatter = ISO8601DateFormatter()
        let projectId = Expression<Int64>("id")
        let projectName = Expression<String>("name")
        let projectStatus = Expression<String>("status")
        let createdAt = Expression<String>("created_at")

        return Project(
            id: Int(try row.get(projectId)),
            name: try row.get(projectName),
            status: Project.Status(rawValue: try row.get(projectStatus)) ?? .active,
            createdAt: dateFormatter.date(from: try row.get(createdAt)) ?? Date(),
            isSystem: true
        )
    }

    func hasProjectReviewBadge(_ projectIdValue: Int) async throws -> Bool {
        guard let db = db else { return false }

        // Check if any thread in this project has status = 'review'
        let count = try db.scalar(
            discussionThreads
                .filter(threadProjectId == Int64(projectIdValue))
                .filter(threadStatus == "review")
                .count
        )
        return count > 0
    }
```

**Step 3: Build to verify**

Run: `cd SeleneChat && swift build`
Expected: Build succeeds

**Step 4: Commit**

```bash
git add SeleneChat/Sources/Services/DatabaseService.swift
git commit -m "feat(db): add thread-project CRUD operations"
```

---

## Task 5: Update ProjectService for Thread Support

**Files:**
- Modify: `SeleneChat/Sources/Services/ProjectService.swift`

**Step 1: Add thread count and review badge fetching**

Replace the `parseProject` method and add thread count logic. After `getNoteCount`, add:

```swift
    private func getThreadCount(for projectIdValue: Int) async throws -> Int {
        guard let db = db else { return 0 }

        let threads = Table("discussion_threads")
        let projectId = Expression<Int64?>("project_id")
        let testRun = Expression<String?>("test_run")

        let count = try db.scalar(
            threads.filter(projectId == Int64(projectIdValue)).filter(testRun == nil).count
        )
        return count
    }

    private func hasReviewBadge(for projectIdValue: Int) async throws -> Bool {
        guard let db = db else { return false }

        let threads = Table("discussion_threads")
        let projectId = Expression<Int64?>("project_id")
        let status = Expression<String>("status")

        let count = try db.scalar(
            threads.filter(projectId == Int64(projectIdValue)).filter(status == "review").count
        )
        return count > 0
    }
```

**Step 2: Update getActiveProjects to include thread count and badge**

In `getActiveProjects`, after `project.noteCount = try await getNoteCount(for: project.id)`, add:

```swift
            project.threadCount = try await getThreadCount(for: project.id)
            project.hasReviewBadge = try await hasReviewBadge(for: project.id)
```

**Step 3: Do the same for getParkedProjects**

**Step 4: Add getScratchPad method**

```swift
    func getScratchPad() async throws -> Project? {
        guard let db = db else {
            throw DatabaseService.DatabaseError.notConnected
        }

        let isSystem = Expression<Int64>("is_system")
        let query = projects.filter(isSystem == 1).limit(1)

        guard let row = try db.pluck(query) else { return nil }

        var project = try parseProject(from: row)
        project.isSystem = true
        project.threadCount = try await getThreadCount(for: project.id)
        return project
    }
```

**Step 5: Build to verify**

Run: `cd SeleneChat && swift build`
Expected: Build succeeds

**Step 6: Commit**

```bash
git add SeleneChat/Sources/Services/ProjectService.swift
git commit -m "feat(service): add thread count and review badge to ProjectService"
```

---

## Task 6: Create ThreadListView Component

**Files:**
- Create: `SeleneChat/Sources/Views/Planning/ThreadListView.swift`

**Step 1: Create the view file**

```swift
// ThreadListView.swift
// SeleneChat
//
// Phase 7.2: Planning Tab Redesign
// Displays threads inside a project

import SwiftUI

struct ThreadListView: View {
    let projectId: Int
    let onSelectThread: (DiscussionThread) -> Void

    @EnvironmentObject var databaseService: DatabaseService
    @State private var threads: [DiscussionThread] = []
    @State private var isLoading = true

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            if isLoading {
                ProgressView()
                    .frame(maxWidth: .infinity, alignment: .center)
                    .padding()
            } else if threads.isEmpty {
                emptyState
            } else {
                LazyVStack(spacing: 8) {
                    ForEach(threads, id: \.id) { thread in
                        ThreadRow(thread: thread)
                            .onTapGesture {
                                onSelectThread(thread)
                            }
                    }
                }
                .padding()
            }
        }
        .task {
            await loadThreads()
        }
    }

    private var emptyState: some View {
        VStack(spacing: 8) {
            Image(systemName: "bubble.left.and.bubble.right")
                .font(.largeTitle)
                .foregroundColor(.secondary)
            Text("No threads yet")
                .font(.headline)
                .foregroundColor(.secondary)
            Text("Start a conversation to create a thread")
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 32)
    }

    private func loadThreads() async {
        isLoading = true
        defer { isLoading = false }

        do {
            threads = try await databaseService.fetchThreadsForProject(projectId)
        } catch {
            #if DEBUG
            print("[ThreadListView] Error loading threads: \(error)")
            #endif
        }
    }
}

struct ThreadRow: View {
    let thread: DiscussionThread

    var body: some View {
        HStack(spacing: 12) {
            // Status indicator
            Image(systemName: thread.status.icon)
                .foregroundColor(statusColor)
                .frame(width: 20)

            VStack(alignment: .leading, spacing: 4) {
                // Thread name or prompt preview
                Text(thread.threadName ?? thread.prompt.prefix(50) + "...")
                    .font(.body)
                    .lineLimit(1)

                // Metadata
                HStack(spacing: 8) {
                    Label(thread.threadType.displayName, systemImage: thread.threadType.icon)
                    Text("•")
                    Text(thread.timeSinceCreated)
                }
                .font(.caption)
                .foregroundColor(.secondary)
            }

            Spacer()

            // Review badge if needed
            if thread.status == .review {
                Image(systemName: "bell.badge.fill")
                    .foregroundColor(.orange)
            }

            Image(systemName: "chevron.right")
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .padding(12)
        .background(Color(NSColor.controlBackgroundColor))
        .cornerRadius(8)
        .contentShape(Rectangle())
    }

    private var statusColor: Color {
        switch thread.status {
        case .pending: return .gray
        case .active: return .blue
        case .completed: return .green
        case .dismissed: return .secondary
        case .review: return .orange
        }
    }
}
```

**Step 2: Build to verify**

Run: `cd SeleneChat && swift build`
Expected: Build succeeds

**Step 3: Commit**

```bash
git add SeleneChat/Sources/Views/Planning/ThreadListView.swift
git commit -m "feat(view): add ThreadListView component"
```

---

## Task 7: Create StartConversationSheet Component

**Files:**
- Create: `SeleneChat/Sources/Views/Planning/StartConversationSheet.swift`

**Step 1: Create the sheet view**

```swift
// StartConversationSheet.swift
// SeleneChat
//
// Phase 7.2: Planning Tab Redesign
// Project picker when starting a new conversation

import SwiftUI

struct StartConversationSheet: View {
    let note: InboxNote
    let onStart: (Int, String?) -> Void  // projectId, new project name if creating
    let onCancel: () -> Void

    @EnvironmentObject var databaseService: DatabaseService
    @StateObject private var projectService = ProjectService.shared

    @State private var selection: Selection = .scratchPad
    @State private var newProjectName = ""
    @State private var activeProjects: [Project] = []
    @State private var parkedProjects: [Project] = []
    @State private var scratchPad: Project?
    @State private var isLoading = true

    enum Selection: Hashable {
        case scratchPad
        case existing(Int)
        case new
    }

    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                Text("Start Conversation")
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

            // Note preview
            VStack(alignment: .leading, spacing: 4) {
                Text(note.title)
                    .font(.subheadline)
                    .fontWeight(.medium)
                Text(note.content.prefix(100) + "...")
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .lineLimit(2)
            }
            .padding()
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Color.accentColor.opacity(0.05))

            Divider()

            // Options
            ScrollView {
                VStack(alignment: .leading, spacing: 12) {
                    Text("Where should this conversation live?")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                        .padding(.horizontal)

                    // Scratch Pad option
                    if let pad = scratchPad {
                        optionRow(
                            icon: "note.text",
                            title: "Scratch Pad",
                            subtitle: "Quick thought, organize later",
                            isSelected: selection == .scratchPad
                        ) {
                            selection = .scratchPad
                        }
                    }

                    // Create new project
                    optionRow(
                        icon: "plus.circle",
                        title: "Create New Project",
                        subtitle: newProjectName.isEmpty ? "Enter name below" : newProjectName,
                        isSelected: selection == .new
                    ) {
                        selection = .new
                    }

                    if selection == .new {
                        TextField("Project name", text: $newProjectName)
                            .textFieldStyle(.roundedBorder)
                            .padding(.horizontal)
                    }

                    // Existing projects
                    if !activeProjects.isEmpty {
                        Text("Active Projects")
                            .font(.caption)
                            .foregroundColor(.secondary)
                            .padding(.horizontal)
                            .padding(.top, 8)

                        ForEach(activeProjects) { project in
                            optionRow(
                                icon: "star.fill",
                                title: project.name,
                                subtitle: "\(project.threadCount) threads",
                                isSelected: selection == .existing(project.id)
                            ) {
                                selection = .existing(project.id)
                            }
                        }
                    }

                    if !parkedProjects.isEmpty {
                        Text("Parked Projects")
                            .font(.caption)
                            .foregroundColor(.secondary)
                            .padding(.horizontal)
                            .padding(.top, 8)

                        ForEach(parkedProjects.prefix(5)) { project in
                            optionRow(
                                icon: "moon.zzz",
                                title: project.name,
                                subtitle: "\(project.threadCount) threads",
                                isSelected: selection == .existing(project.id)
                            ) {
                                selection = .existing(project.id)
                            }
                        }
                    }
                }
                .padding(.vertical)
            }

            Divider()

            // Actions
            HStack {
                Button("Cancel") { onCancel() }
                    .keyboardShortcut(.escape)

                Spacer()

                Button("Start Conversation") {
                    startConversation()
                }
                .keyboardShortcut(.return)
                .buttonStyle(.borderedProminent)
                .disabled(!canStart)
            }
            .padding()
        }
        .frame(width: 400, height: 500)
        .task {
            await loadProjects()
        }
    }

    private func optionRow(
        icon: String,
        title: String,
        subtitle: String,
        isSelected: Bool,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            HStack(spacing: 12) {
                Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                    .foregroundColor(isSelected ? .accentColor : .secondary)

                Image(systemName: icon)
                    .foregroundColor(.secondary)
                    .frame(width: 20)

                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .font(.body)
                    Text(subtitle)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }

                Spacer()
            }
            .padding(.horizontal)
            .padding(.vertical, 8)
            .background(isSelected ? Color.accentColor.opacity(0.1) : Color.clear)
            .cornerRadius(8)
        }
        .buttonStyle(.plain)
    }

    private var canStart: Bool {
        switch selection {
        case .scratchPad, .existing:
            return true
        case .new:
            return !newProjectName.trimmingCharacters(in: .whitespaces).isEmpty
        }
    }

    private func loadProjects() async {
        isLoading = true
        defer { isLoading = false }

        do {
            activeProjects = try await projectService.getActiveProjects()
            parkedProjects = try await projectService.getParkedProjects()
            scratchPad = try await projectService.getScratchPad()
        } catch {
            #if DEBUG
            print("[StartConversationSheet] Error: \(error)")
            #endif
        }
    }

    private func startConversation() {
        switch selection {
        case .scratchPad:
            if let pad = scratchPad {
                onStart(pad.id, nil)
            }
        case .existing(let projectId):
            onStart(projectId, nil)
        case .new:
            onStart(-1, newProjectName)  // -1 signals create new
        }
    }
}
```

**Step 2: Build to verify**

Run: `cd SeleneChat && swift build`
Expected: Build succeeds

**Step 3: Commit**

```bash
git add SeleneChat/Sources/Views/Planning/StartConversationSheet.swift
git commit -m "feat(view): add StartConversationSheet for project picker"
```

---

## Task 8: Update ProjectDetailView to Show Threads

**Files:**
- Modify: `SeleneChat/Sources/Views/ProjectDetailView.swift`

**Step 1: Read current file to understand structure**

**Step 2: Add thread list section**

After the existing content sections, add a ThreadListView:

```swift
// Add to the body, after attached notes section:

// Threads section
VStack(alignment: .leading, spacing: 0) {
    HStack {
        Image(systemName: "bubble.left.and.bubble.right")
            .foregroundColor(.blue)
        Text("Threads")
            .font(.headline)
        Text("(\(project.threadCount))")
            .font(.caption)
            .foregroundColor(.secondary)
        Spacer()
        Button(action: { showNewThreadSheet = true }) {
            Image(systemName: "plus")
        }
        .buttonStyle(.plain)
    }
    .padding()

    Divider()

    ThreadListView(projectId: project.id) { thread in
        selectedThread = thread
    }
}
```

**Step 3: Add state variables for thread selection**

```swift
@State private var selectedThread: DiscussionThread?
@State private var showNewThreadSheet = false
```

**Step 4: Build to verify**

Run: `cd SeleneChat && swift build`
Expected: Build succeeds

**Step 5: Commit**

```bash
git add SeleneChat/Sources/Views/ProjectDetailView.swift
git commit -m "feat(view): add thread list to ProjectDetailView"
```

---

## Task 9: Update PlanningView Section Order

**Files:**
- Modify: `SeleneChat/Sources/Views/PlanningView.swift`

**Step 1: Remove needsReviewSection and planningThreadsSection**

These sections become badges on projects instead.

**Step 2: Add Scratch Pad section**

Add state:
```swift
@State private var scratchPad: Project?
@State private var isScratchPadExpanded = true
```

Add section between Active Projects and Suggestions:
```swift
// Scratch Pad section (only if has threads)
if let pad = scratchPad, pad.threadCount > 0 {
    scratchPadSection
        .id("scratchPad")
}
```

**Step 3: Reorder sections in ScrollView**

New order:
1. activeProjectsSection
2. scratchPadSection (if populated)
3. suggestionsSection
4. inboxSection
5. parkedProjectsSection

**Step 4: Add review badge to project rows**

In ActiveProjectsList, show badge when `project.hasReviewBadge == true`.

**Step 5: Build to verify**

Run: `cd SeleneChat && swift build`
Expected: Build succeeds

**Step 6: Commit**

```bash
git add SeleneChat/Sources/Views/PlanningView.swift
git commit -m "feat(view): reorder Planning tab sections, add Scratch Pad"
```

---

## Task 10: Update ActiveProjectsList for Review Badges

**Files:**
- Modify: `SeleneChat/Sources/Views/Planning/ActiveProjectsList.swift`

**Step 1: Add review badge indicator to project row**

After the project name, add:

```swift
if project.hasReviewBadge {
    Image(systemName: "bell.badge.fill")
        .foregroundColor(.orange)
        .font(.caption)
}
```

**Step 2: Show thread count instead of/alongside note count**

```swift
Text("\(project.threadCount) threads • \(project.noteCount) notes")
    .font(.caption)
    .foregroundColor(.secondary)
```

**Step 3: Build to verify**

Run: `cd SeleneChat && swift build`
Expected: Build succeeds

**Step 4: Commit**

```bash
git add SeleneChat/Sources/Views/Planning/ActiveProjectsList.swift
git commit -m "feat(view): add review badge and thread count to project rows"
```

---

## Task 11: Update Sidebar Navigation

**Files:**
- Modify: `SeleneChat/Sources/Views/PlanningView.swift` (sectionSidebar)

**Step 1: Update sidebar order**

Reorder sidebar buttons to match new section order:
1. Active Projects
2. Scratch Pad (if visible)
3. Suggestions
4. Inbox
5. Parked

**Step 2: Remove Conversations and Needs Review buttons**

These are now integrated into projects.

**Step 3: Build to verify**

Run: `cd SeleneChat && swift build`
Expected: Build succeeds

**Step 4: Commit**

```bash
git add SeleneChat/Sources/Views/PlanningView.swift
git commit -m "feat(view): update sidebar navigation order"
```

---

## Task 12: Final Build and Test

**Step 1: Full build**

Run: `cd SeleneChat && swift build`
Expected: Build succeeds with no errors

**Step 2: Update BRANCH-STATUS.md**

Mark development tasks complete.

**Step 3: Commit**

```bash
git add BRANCH-STATUS.md
git commit -m "chore: update BRANCH-STATUS.md - development complete"
```

---

## Summary

| Task | Description | Files |
|------|-------------|-------|
| 1 | Database migration | Migration005_ProjectThreads.swift |
| 2 | Update DiscussionThread model | DiscussionThread.swift |
| 3 | Update Project model | Project.swift |
| 4 | Add thread CRUD to DatabaseService | DatabaseService.swift |
| 5 | Update ProjectService | ProjectService.swift |
| 6 | Create ThreadListView | ThreadListView.swift |
| 7 | Create StartConversationSheet | StartConversationSheet.swift |
| 8 | Update ProjectDetailView | ProjectDetailView.swift |
| 9 | Update PlanningView sections | PlanningView.swift |
| 10 | Update ActiveProjectsList | ActiveProjectsList.swift |
| 11 | Update sidebar navigation | PlanningView.swift |
| 12 | Final build and test | BRANCH-STATUS.md |

**Estimated commits:** 12
**Key principle:** Each task is one logical change with a commit.
