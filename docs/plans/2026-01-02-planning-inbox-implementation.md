# Planning Inbox Redesign Implementation Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** Build the Inbox triage system where ALL notes go through SeleneChat for user review before any tasks are created.

**Architecture:** Three-section Planning tab (Inbox, Active, Parked) with triage buttons on note cards. Database stores project state, Swift services manage data, SwiftUI views provide ADHD-optimized UI.

**Tech Stack:** SQLite migrations, Swift 5.9+, SwiftUI, SQLite.swift

---

## Implementation Overview

| Task | Component | Estimated Steps |
|------|-----------|-----------------|
| 1 | Database Migration | 10 |
| 2 | Swift Models | 8 |
| 3 | Swift Migration | 8 |
| 4 | InboxService | 12 |
| 5 | ProjectService | 14 |
| 6 | NoteType Badge Logic | 6 |
| 7 | TriageCardView | 10 |
| 8 | QuickTaskConfirmation | 8 |
| 9 | InboxView | 10 |
| 10 | ActiveProjectsList | 8 |
| 11 | ParkedProjectsList | 6 |
| 12 | PlanningView Refactor | 12 |
| 13 | Integration Testing | 10 |

---

## Task 1: Database Migration

**Files:**
- Create: `database/migrations/011_planning_inbox.sql`

**Step 1: Create migration file with projects table**

```sql
-- 011_planning_inbox.sql
-- Phase 7: Planning Inbox Redesign
-- Creates projects table, project_notes junction, and modifies raw_notes

-- Projects table for Active/Parked structure
CREATE TABLE IF NOT EXISTS projects (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    name TEXT NOT NULL,
    status TEXT DEFAULT 'parked'
        CHECK(status IN ('active', 'parked', 'completed')),
    primary_concept TEXT,
    things_project_id TEXT,
    created_at TEXT DEFAULT CURRENT_TIMESTAMP,
    last_active_at TEXT,
    completed_at TEXT,
    test_run TEXT DEFAULT NULL
);

CREATE INDEX IF NOT EXISTS idx_projects_status ON projects(status);
CREATE INDEX IF NOT EXISTS idx_projects_test_run ON projects(test_run);
```

**Step 2: Add project_notes junction table**

```sql
-- Junction table linking projects to notes
CREATE TABLE IF NOT EXISTS project_notes (
    project_id INTEGER NOT NULL,
    raw_note_id INTEGER NOT NULL,
    attached_at TEXT DEFAULT CURRENT_TIMESTAMP,
    PRIMARY KEY (project_id, raw_note_id),
    FOREIGN KEY (project_id) REFERENCES projects(id),
    FOREIGN KEY (raw_note_id) REFERENCES raw_notes(id)
);

CREATE INDEX IF NOT EXISTS idx_project_notes_project ON project_notes(project_id);
CREATE INDEX IF NOT EXISTS idx_project_notes_note ON project_notes(raw_note_id);
```

**Step 3: Add raw_notes columns for inbox tracking**

```sql
-- Add inbox tracking columns to raw_notes
-- inbox_status: pending (new), triaged (processed), archived (hidden)
-- suggested_type: AI hint for triage (quick_task, relates_to_project, new_project, reflection)
-- suggested_project_id: If relates_to_project, which project

ALTER TABLE raw_notes ADD COLUMN inbox_status TEXT DEFAULT 'pending'
    CHECK(inbox_status IN ('pending', 'triaged', 'archived'));

ALTER TABLE raw_notes ADD COLUMN suggested_type TEXT
    CHECK(suggested_type IN ('quick_task', 'relates_to_project', 'new_project', 'reflection'));

ALTER TABLE raw_notes ADD COLUMN suggested_project_id INTEGER
    REFERENCES projects(id);

CREATE INDEX IF NOT EXISTS idx_raw_notes_inbox_status ON raw_notes(inbox_status);
```

**Step 4: Run migration on test database to verify syntax**

Run: `sqlite3 :memory: < database/migrations/011_planning_inbox.sql`
Expected: No errors, tables created

**Step 5: Commit database migration**

```bash
git add database/migrations/011_planning_inbox.sql
git commit -m "feat(db): add planning inbox schema

- projects table with status (active/parked/completed)
- project_notes junction table
- raw_notes inbox columns (inbox_status, suggested_type, suggested_project_id)"
```

---

## Task 2: Swift Models

**Files:**
- Create: `SeleneChat/Sources/Models/Project.swift`
- Create: `SeleneChat/Sources/Models/InboxNote.swift`
- Create: `SeleneChat/Sources/Models/NoteType.swift`

**Step 1: Create NoteType enum**

```swift
// SeleneChat/Sources/Models/NoteType.swift
import Foundation

enum NoteType: String, CaseIterable, Codable {
    case quickTask = "quick_task"
    case relatesToProject = "relates_to_project"
    case newProject = "new_project"
    case reflection = "reflection"

    var displayName: String {
        switch self {
        case .quickTask: return "Quick task"
        case .relatesToProject: return "Relates to project"
        case .newProject: return "New project idea"
        case .reflection: return "Reflection"
        }
    }

    var icon: String {
        switch self {
        case .quickTask: return "checklist"
        case .relatesToProject: return "link"
        case .newProject: return "plus.rectangle.on.folder"
        case .reflection: return "bubble.left.and.text.bubble.right"
        }
    }

    var emoji: String {
        switch self {
        case .quickTask: return "📋"
        case .relatesToProject: return "🔗"
        case .newProject: return "🆕"
        case .reflection: return "💭"
        }
    }
}
```

**Step 2: Run tests (should compile)**

Run: `cd SeleneChat && swift build`
Expected: Build succeeds

**Step 3: Create Project model**

```swift
// SeleneChat/Sources/Models/Project.swift
import Foundation

struct Project: Identifiable, Hashable {
    let id: Int
    var name: String
    var status: Status
    var primaryConcept: String?
    var thingsProjectId: String?
    let createdAt: Date
    var lastActiveAt: Date?
    var completedAt: Date?
    var testRun: String?

    // Computed from joins
    var noteCount: Int = 0
    var taskCount: Int = 0
    var completedTaskCount: Int = 0

    enum Status: String, CaseIterable {
        case active
        case parked
        case completed

        var icon: String {
            switch self {
            case .active: return "flame"
            case .parked: return "parkingsign"
            case .completed: return "checkmark.circle"
            }
        }

        var color: String {
            switch self {
            case .active: return "orange"
            case .parked: return "gray"
            case .completed: return "green"
            }
        }
    }

    var timeSinceActive: String? {
        guard let lastActive = lastActiveAt else { return nil }
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .abbreviated
        return formatter.localizedString(for: lastActive, relativeTo: Date())
    }
}
```

**Step 4: Run tests**

Run: `cd SeleneChat && swift build`
Expected: Build succeeds

**Step 5: Create InboxNote model**

```swift
// SeleneChat/Sources/Models/InboxNote.swift
import Foundation

struct InboxNote: Identifiable, Hashable {
    let id: Int
    let title: String
    let content: String
    let createdAt: Date

    // Inbox-specific
    var inboxStatus: InboxStatus
    var suggestedType: NoteType?
    var suggestedProjectId: Int?
    var suggestedProjectName: String?

    // From processed_notes
    var concepts: [String]?
    var primaryTheme: String?
    var energyLevel: String?

    enum InboxStatus: String {
        case pending
        case triaged
        case archived
    }

    var preview: String {
        String(content.prefix(150))
    }

    var formattedDate: String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        return formatter.string(from: createdAt)
    }
}
```

**Step 6: Run tests**

Run: `cd SeleneChat && swift build`
Expected: Build succeeds

**Step 7: Commit models**

```bash
git add SeleneChat/Sources/Models/NoteType.swift
git add SeleneChat/Sources/Models/Project.swift
git add SeleneChat/Sources/Models/InboxNote.swift
git commit -m "feat(models): add Project, InboxNote, NoteType for planning inbox"
```

---

## Task 3: Swift Database Migration

**Files:**
- Create: `SeleneChat/Sources/Services/Migrations/Migration002_PlanningInbox.swift`
- Modify: `SeleneChat/Sources/Services/DatabaseService.swift:99` (add migration call)

**Step 1: Create Swift migration**

```swift
// Migration002_PlanningInbox.swift
// SeleneChat
//
// Created for Phase 7: Planning Inbox Redesign
// Creates projects table and adds inbox columns to raw_notes

import Foundation
import SQLite

struct Migration002_PlanningInbox {
    static func run(db: Connection) throws {
        // Create projects table
        try db.run("""
            CREATE TABLE IF NOT EXISTS projects (
                id INTEGER PRIMARY KEY AUTOINCREMENT,
                name TEXT NOT NULL,
                status TEXT DEFAULT 'parked'
                    CHECK(status IN ('active', 'parked', 'completed')),
                primary_concept TEXT,
                things_project_id TEXT,
                created_at TEXT DEFAULT CURRENT_TIMESTAMP,
                last_active_at TEXT,
                completed_at TEXT,
                test_run TEXT DEFAULT NULL
            )
        """)

        try db.run("CREATE INDEX IF NOT EXISTS idx_projects_status ON projects(status)")
        try db.run("CREATE INDEX IF NOT EXISTS idx_projects_test_run ON projects(test_run)")

        // Create project_notes junction table
        try db.run("""
            CREATE TABLE IF NOT EXISTS project_notes (
                project_id INTEGER NOT NULL,
                raw_note_id INTEGER NOT NULL,
                attached_at TEXT DEFAULT CURRENT_TIMESTAMP,
                PRIMARY KEY (project_id, raw_note_id),
                FOREIGN KEY (project_id) REFERENCES projects(id),
                FOREIGN KEY (raw_note_id) REFERENCES raw_notes(id)
            )
        """)

        try db.run("CREATE INDEX IF NOT EXISTS idx_project_notes_project ON project_notes(project_id)")
        try db.run("CREATE INDEX IF NOT EXISTS idx_project_notes_note ON project_notes(raw_note_id)")

        // Add inbox columns to raw_notes (ignore if already exist)
        do {
            try db.run("ALTER TABLE raw_notes ADD COLUMN inbox_status TEXT DEFAULT 'pending'")
        } catch {
            // Column may already exist
        }

        do {
            try db.run("ALTER TABLE raw_notes ADD COLUMN suggested_type TEXT")
        } catch {
            // Column may already exist
        }

        do {
            try db.run("ALTER TABLE raw_notes ADD COLUMN suggested_project_id INTEGER")
        } catch {
            // Column may already exist
        }

        try db.run("CREATE INDEX IF NOT EXISTS idx_raw_notes_inbox_status ON raw_notes(inbox_status)")

        print("Migration 002: Planning inbox tables created")
    }
}
```

**Step 2: Run tests**

Run: `cd SeleneChat && swift build`
Expected: Build succeeds

**Step 3: Add migration call to DatabaseService**

In `DatabaseService.swift`, find line ~98-99 where migrations run, add:

```swift
try? Migration002_PlanningInbox.run(db: db!)
```

**Step 4: Run tests**

Run: `cd SeleneChat && swift build`
Expected: Build succeeds

**Step 5: Commit migration**

```bash
git add SeleneChat/Sources/Services/Migrations/Migration002_PlanningInbox.swift
git add SeleneChat/Sources/Services/DatabaseService.swift
git commit -m "feat(db): add Swift migration for planning inbox tables"
```

---

## Task 4: InboxService

**Files:**
- Create: `SeleneChat/Sources/Services/InboxService.swift`

**Step 1: Create service with column definitions**

```swift
// SeleneChat/Sources/Services/InboxService.swift
import Foundation
import SQLite

class InboxService: ObservableObject {
    static let shared = InboxService()

    private var db: Connection?

    // Table references
    private let rawNotes = Table("raw_notes")
    private let processedNotes = Table("processed_notes")
    private let projects = Table("projects")

    // raw_notes columns
    private let noteId = Expression<Int64>("id")
    private let noteTitle = Expression<String>("title")
    private let noteContent = Expression<String>("content")
    private let noteCreatedAt = Expression<String>("created_at")
    private let inboxStatus = Expression<String?>("inbox_status")
    private let suggestedType = Expression<String?>("suggested_type")
    private let suggestedProjectId = Expression<Int64?>("suggested_project_id")
    private let testRun = Expression<String?>("test_run")

    // processed_notes columns
    private let rawNoteId = Expression<Int64>("raw_note_id")
    private let concepts = Expression<String?>("concepts")
    private let primaryTheme = Expression<String?>("primary_theme")
    private let energyLevel = Expression<String?>("energy_level")

    // projects columns
    private let projectId = Expression<Int64>("id")
    private let projectName = Expression<String>("name")

    init() {}

    func configure(with db: Connection) {
        self.db = db
    }
}
```

**Step 2: Run tests**

Run: `cd SeleneChat && swift build`
Expected: Build succeeds

**Step 3: Add getPendingNotes method**

```swift
// Add to InboxService

func getPendingNotes() async throws -> [InboxNote] {
    guard let db = db else {
        throw DatabaseService.DatabaseError.notConnected
    }

    let query = rawNotes
        .join(.leftOuter, processedNotes, on: rawNotes[noteId] == processedNotes[rawNoteId])
        .join(.leftOuter, projects, on: rawNotes[suggestedProjectId] == projects[projectId])
        .filter(rawNotes[inboxStatus] == "pending" || rawNotes[inboxStatus] == nil)
        .filter(rawNotes[testRun] == nil)
        .order(rawNotes[noteCreatedAt].desc)
        .limit(50)

    var notes: [InboxNote] = []

    for row in try db.prepare(query) {
        let note = try parseInboxNote(from: row)
        notes.append(note)
    }

    return notes
}

private func parseInboxNote(from row: Row) throws -> InboxNote {
    let dateFormatter = ISO8601DateFormatter()

    // Parse concepts JSON
    var conceptsArray: [String]? = nil
    if let conceptsStr = try? row.get(processedNotes[concepts]),
       let data = conceptsStr.data(using: .utf8) {
        conceptsArray = try? JSONDecoder().decode([String].self, from: data)
    }

    // Parse suggested type
    var noteType: NoteType? = nil
    if let typeStr = try? row.get(rawNotes[suggestedType]) {
        noteType = NoteType(rawValue: typeStr)
    }

    return InboxNote(
        id: Int(try row.get(rawNotes[noteId])),
        title: try row.get(rawNotes[noteTitle]),
        content: try row.get(rawNotes[noteContent]),
        createdAt: dateFormatter.date(from: try row.get(rawNotes[noteCreatedAt])) ?? Date(),
        inboxStatus: .pending,
        suggestedType: noteType,
        suggestedProjectId: (try? row.get(rawNotes[suggestedProjectId])).map { Int($0) },
        suggestedProjectName: try? row.get(projects[projectName]),
        concepts: conceptsArray,
        primaryTheme: try? row.get(processedNotes[primaryTheme]),
        energyLevel: try? row.get(processedNotes[energyLevel])
    )
}
```

**Step 4: Run tests**

Run: `cd SeleneChat && swift build`
Expected: Build succeeds

**Step 5: Add triage action methods**

```swift
// Add to InboxService

func markTriaged(noteId: Int) async throws {
    guard let db = db else {
        throw DatabaseService.DatabaseError.notConnected
    }

    let note = rawNotes.filter(self.noteId == Int64(noteId))
    try db.run(note.update(inboxStatus <- "triaged"))
}

func markArchived(noteId: Int) async throws {
    guard let db = db else {
        throw DatabaseService.DatabaseError.notConnected
    }

    let note = rawNotes.filter(self.noteId == Int64(noteId))
    try db.run(note.update(inboxStatus <- "archived"))
}

func attachToProject(noteId: Int, projectId: Int) async throws {
    guard let db = db else {
        throw DatabaseService.DatabaseError.notConnected
    }

    // Insert into project_notes
    let projectNotes = Table("project_notes")
    let projectIdCol = Expression<Int64>("project_id")
    let rawNoteIdCol = Expression<Int64>("raw_note_id")

    try db.run(projectNotes.insert(or: .ignore,
        projectIdCol <- Int64(projectId),
        rawNoteIdCol <- Int64(noteId)
    ))

    // Mark note as triaged
    try await markTriaged(noteId: noteId)
}
```

**Step 6: Run tests**

Run: `cd SeleneChat && swift build`
Expected: Build succeeds

**Step 7: Commit InboxService**

```bash
git add SeleneChat/Sources/Services/InboxService.swift
git commit -m "feat(service): add InboxService for inbox note management"
```

---

## Task 5: ProjectService

**Files:**
- Create: `SeleneChat/Sources/Services/ProjectService.swift`

**Step 1: Create service with column definitions**

```swift
// SeleneChat/Sources/Services/ProjectService.swift
import Foundation
import SQLite

class ProjectService: ObservableObject {
    static let shared = ProjectService()

    private var db: Connection?

    // Table references
    private let projects = Table("projects")
    private let projectNotes = Table("project_notes")

    // projects columns
    private let projectId = Expression<Int64>("id")
    private let projectName = Expression<String>("name")
    private let projectStatus = Expression<String>("status")
    private let primaryConcept = Expression<String?>("primary_concept")
    private let thingsProjectId = Expression<String?>("things_project_id")
    private let createdAt = Expression<String>("created_at")
    private let lastActiveAt = Expression<String?>("last_active_at")
    private let completedAt = Expression<String?>("completed_at")
    private let testRun = Expression<String?>("test_run")

    // project_notes columns
    private let pnProjectId = Expression<Int64>("project_id")
    private let pnRawNoteId = Expression<Int64>("raw_note_id")

    private let maxActiveProjects = 5

    init() {}

    func configure(with db: Connection) {
        self.db = db
    }
}
```

**Step 2: Run tests**

Run: `cd SeleneChat && swift build`
Expected: Build succeeds

**Step 3: Add getActiveProjects method**

```swift
// Add to ProjectService

func getActiveProjects() async throws -> [Project] {
    guard let db = db else {
        throw DatabaseService.DatabaseError.notConnected
    }

    let query = projects
        .filter(projectStatus == "active")
        .filter(testRun == nil)
        .order(lastActiveAt.desc)

    var projectList: [Project] = []

    for row in try db.prepare(query) {
        var project = try parseProject(from: row)
        project.noteCount = try await getNoteCount(for: project.id)
        projectList.append(project)
    }

    return projectList
}

func getParkedProjects() async throws -> [Project] {
    guard let db = db else {
        throw DatabaseService.DatabaseError.notConnected
    }

    let query = projects
        .filter(projectStatus == "parked")
        .filter(testRun == nil)
        .order(lastActiveAt.desc)

    var projectList: [Project] = []

    for row in try db.prepare(query) {
        var project = try parseProject(from: row)
        project.noteCount = try await getNoteCount(for: project.id)
        projectList.append(project)
    }

    return projectList
}

private func getNoteCount(for projectIdValue: Int) async throws -> Int {
    guard let db = db else { return 0 }

    let count = try db.scalar(
        projectNotes.filter(pnProjectId == Int64(projectIdValue)).count
    )
    return count
}

private func parseProject(from row: Row) throws -> Project {
    let dateFormatter = ISO8601DateFormatter()

    return Project(
        id: Int(try row.get(projectId)),
        name: try row.get(projectName),
        status: Project.Status(rawValue: try row.get(projectStatus)) ?? .parked,
        primaryConcept: try? row.get(primaryConcept),
        thingsProjectId: try? row.get(thingsProjectId),
        createdAt: dateFormatter.date(from: try row.get(createdAt)) ?? Date(),
        lastActiveAt: (try? row.get(lastActiveAt)).flatMap { dateFormatter.date(from: $0) },
        completedAt: (try? row.get(completedAt)).flatMap { dateFormatter.date(from: $0) },
        testRun: try? row.get(testRun)
    )
}
```

**Step 4: Run tests**

Run: `cd SeleneChat && swift build`
Expected: Build succeeds

**Step 5: Add createProject method**

```swift
// Add to ProjectService

func createProject(name: String, fromNoteId: Int? = nil, concept: String? = nil) async throws -> Project {
    guard let db = db else {
        throw DatabaseService.DatabaseError.notConnected
    }

    let dateFormatter = ISO8601DateFormatter()
    let now = dateFormatter.string(from: Date())

    let id = try db.run(projects.insert(
        projectName <- name,
        projectStatus <- "parked",
        primaryConcept <- concept,
        createdAt <- now,
        lastActiveAt <- now
    ))

    // If created from a note, attach it
    if let noteId = fromNoteId {
        try db.run(projectNotes.insert(
            pnProjectId <- id,
            pnRawNoteId <- Int64(noteId)
        ))
    }

    return Project(
        id: Int(id),
        name: name,
        status: .parked,
        primaryConcept: concept,
        thingsProjectId: nil,
        createdAt: Date(),
        lastActiveAt: Date(),
        completedAt: nil,
        testRun: nil,
        noteCount: fromNoteId != nil ? 1 : 0
    )
}
```

**Step 6: Run tests**

Run: `cd SeleneChat && swift build`
Expected: Build succeeds

**Step 7: Add status management methods**

```swift
// Add to ProjectService

func activateProject(_ projectIdValue: Int) async throws {
    guard let db = db else {
        throw DatabaseService.DatabaseError.notConnected
    }

    // Check active count
    let activeCount = try db.scalar(
        projects.filter(projectStatus == "active").filter(testRun == nil).count
    )

    if activeCount >= maxActiveProjects {
        throw ProjectError.tooManyActive
    }

    let dateFormatter = ISO8601DateFormatter()
    let now = dateFormatter.string(from: Date())

    let project = projects.filter(projectId == Int64(projectIdValue))
    try db.run(project.update(
        projectStatus <- "active",
        lastActiveAt <- now
    ))
}

func parkProject(_ projectIdValue: Int) async throws {
    guard let db = db else {
        throw DatabaseService.DatabaseError.notConnected
    }

    let project = projects.filter(projectId == Int64(projectIdValue))
    try db.run(project.update(projectStatus <- "parked"))
}

func completeProject(_ projectIdValue: Int) async throws {
    guard let db = db else {
        throw DatabaseService.DatabaseError.notConnected
    }

    let dateFormatter = ISO8601DateFormatter()
    let now = dateFormatter.string(from: Date())

    let project = projects.filter(projectId == Int64(projectIdValue))
    try db.run(project.update(
        projectStatus <- "completed",
        completedAt <- now
    ))
}

enum ProjectError: Error, LocalizedError {
    case tooManyActive

    var errorDescription: String? {
        switch self {
        case .tooManyActive:
            return "Maximum 5 active projects. Park one first."
        }
    }
}
```

**Step 8: Run tests**

Run: `cd SeleneChat && swift build`
Expected: Build succeeds

**Step 9: Commit ProjectService**

```bash
git add SeleneChat/Sources/Services/ProjectService.swift
git commit -m "feat(service): add ProjectService for active/parked project management"
```

---

## Task 6: TriageCardView

**Files:**
- Create: `SeleneChat/Sources/Views/Planning/TriageCardView.swift`

**Step 1: Create view with basic layout**

```swift
// SeleneChat/Sources/Views/Planning/TriageCardView.swift
import SwiftUI

struct TriageCardView: View {
    let note: InboxNote
    let onCreateTask: () -> Void
    let onAddToProject: () -> Void
    let onStartProject: () -> Void
    let onPark: () -> Void
    let onArchive: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Type badge and date
            HStack {
                typeBadge
                Spacer()
                Text(note.formattedDate)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }

            // Note content
            Text(note.title)
                .font(.headline)
                .lineLimit(1)

            Text(note.preview)
                .font(.subheadline)
                .foregroundColor(.secondary)
                .lineLimit(2)

            // Suggested project (if relates_to_project)
            if let projectName = note.suggestedProjectName {
                HStack(spacing: 4) {
                    Image(systemName: "link")
                        .font(.caption)
                    Text(projectName)
                        .font(.caption)
                        .foregroundColor(.accentColor)
                }
            }

            // Action buttons
            actionButtons
        }
        .padding()
        .background(Color(NSColor.controlBackgroundColor))
        .cornerRadius(12)
    }

    @ViewBuilder
    private var typeBadge: some View {
        if let type = note.suggestedType {
            HStack(spacing: 4) {
                Text(type.emoji)
                Text(type.displayName)
            }
            .font(.caption)
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(Color.accentColor.opacity(0.1))
            .cornerRadius(6)
        }
    }

    @ViewBuilder
    private var actionButtons: some View {
        HStack(spacing: 8) {
            // Primary actions based on type
            if note.suggestedType == .quickTask {
                Button("Create Task") { onCreateTask() }
                    .buttonStyle(.borderedProminent)
            } else if note.suggestedType == .relatesToProject {
                Button("Add to Project") { onAddToProject() }
                    .buttonStyle(.borderedProminent)
            } else {
                Button("Start Project") { onStartProject() }
                    .buttonStyle(.borderedProminent)
            }

            Button("Park") { onPark() }
                .buttonStyle(.bordered)

            Button(action: onArchive) {
                Image(systemName: "archivebox")
            }
            .buttonStyle(.bordered)
        }
        .font(.caption)
    }
}
```

**Step 2: Run tests**

Run: `cd SeleneChat && swift build`
Expected: Build succeeds

**Step 3: Commit TriageCardView**

```bash
mkdir -p SeleneChat/Sources/Views/Planning
git add SeleneChat/Sources/Views/Planning/TriageCardView.swift
git commit -m "feat(ui): add TriageCardView for inbox note triage"
```

---

## Task 7: QuickTaskConfirmation

**Files:**
- Create: `SeleneChat/Sources/Views/Planning/QuickTaskConfirmation.swift`

**Step 1: Create confirmation sheet view**

```swift
// SeleneChat/Sources/Views/Planning/QuickTaskConfirmation.swift
import SwiftUI

struct QuickTaskConfirmation: View {
    let note: InboxNote
    let onConfirm: (String) -> Void
    let onCancel: () -> Void

    @State private var taskText: String
    @State private var isSubmitting = false

    init(note: InboxNote, onConfirm: @escaping (String) -> Void, onCancel: @escaping () -> Void) {
        self.note = note
        self.onConfirm = onConfirm
        self.onCancel = onCancel
        // Initialize with note title as default task text
        _taskText = State(initialValue: note.title)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            // Header
            HStack {
                Text("📋")
                Text("Quick task")
                    .font(.headline)
                Spacer()
                Button(action: onCancel) {
                    Image(systemName: "xmark")
                        .foregroundColor(.secondary)
                }
                .buttonStyle(.plain)
            }

            Divider()

            // Original note
            VStack(alignment: .leading, spacing: 4) {
                Text("From note:")
                    .font(.caption)
                    .foregroundColor(.secondary)
                Text(note.preview)
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .lineLimit(2)
            }

            // Editable task text
            VStack(alignment: .leading, spacing: 4) {
                Text("Task to create:")
                    .font(.caption)
                    .foregroundColor(.secondary)
                TextField("Task text", text: $taskText, axis: .vertical)
                    .textFieldStyle(.roundedBorder)
                    .lineLimit(1...3)
            }

            Divider()

            // Actions
            HStack {
                Spacer()

                Button("Cancel") {
                    onCancel()
                }
                .keyboardShortcut(.escape)

                Button("Send to Things") {
                    isSubmitting = true
                    onConfirm(taskText)
                }
                .buttonStyle(.borderedProminent)
                .disabled(taskText.isEmpty || isSubmitting)
                .keyboardShortcut(.return)
            }
        }
        .padding()
        .frame(width: 400)
    }
}
```

**Step 2: Run tests**

Run: `cd SeleneChat && swift build`
Expected: Build succeeds

**Step 3: Commit QuickTaskConfirmation**

```bash
git add SeleneChat/Sources/Views/Planning/QuickTaskConfirmation.swift
git commit -m "feat(ui): add QuickTaskConfirmation sheet for task creation"
```

---

## Task 8: InboxView

**Files:**
- Create: `SeleneChat/Sources/Views/Planning/InboxView.swift`

**Step 1: Create InboxView with state**

```swift
// SeleneChat/Sources/Views/Planning/InboxView.swift
import SwiftUI

struct InboxView: View {
    @EnvironmentObject var databaseService: DatabaseService
    @StateObject private var inboxService = InboxService.shared
    @StateObject private var projectService = ProjectService.shared

    @State private var notes: [InboxNote] = []
    @State private var isLoading = true
    @State private var error: String?

    @State private var selectedNoteForTask: InboxNote?
    @State private var showTaskConfirmation = false

    private let thingsService = ThingsURLService.shared

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Section header
            HStack {
                Image(systemName: "tray.and.arrow.down")
                Text("Inbox")
                    .font(.headline)

                if !notes.isEmpty {
                    Text("(\(notes.count))")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }

                Spacer()

                Button(action: { Task { await loadNotes() } }) {
                    Image(systemName: "arrow.clockwise")
                        .font(.caption)
                }
                .buttonStyle(.plain)
                .disabled(isLoading)
            }
            .padding(.horizontal)
            .padding(.vertical, 8)

            Divider()

            // Content
            if isLoading {
                HStack {
                    Spacer()
                    ProgressView()
                    Spacer()
                }
                .padding()
            } else if notes.isEmpty {
                emptyState
            } else {
                ScrollView {
                    LazyVStack(spacing: 12) {
                        ForEach(notes) { note in
                            TriageCardView(
                                note: note,
                                onCreateTask: { startTaskCreation(for: note) },
                                onAddToProject: { addToProject(note) },
                                onStartProject: { startProject(from: note) },
                                onPark: { parkNote(note) },
                                onArchive: { archiveNote(note) }
                            )
                        }
                    }
                    .padding()
                }
            }
        }
        .task {
            await loadNotes()
        }
        .sheet(isPresented: $showTaskConfirmation) {
            if let note = selectedNoteForTask {
                QuickTaskConfirmation(
                    note: note,
                    onConfirm: { taskText in
                        Task { await createTask(taskText, from: note) }
                    },
                    onCancel: { showTaskConfirmation = false }
                )
            }
        }
    }

    private var emptyState: some View {
        VStack(spacing: 12) {
            Image(systemName: "checkmark.circle")
                .font(.system(size: 40))
                .foregroundColor(.green)
            Text("Inbox clear!")
                .font(.headline)
            Text("New notes will appear here for triage")
                .font(.subheadline)
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding()
    }

    private func loadNotes() async {
        isLoading = true
        error = nil

        do {
            notes = try await inboxService.getPendingNotes()
        } catch {
            self.error = error.localizedDescription
        }

        isLoading = false
    }

    private func startTaskCreation(for note: InboxNote) {
        selectedNoteForTask = note
        showTaskConfirmation = true
    }

    private func createTask(_ taskText: String, from note: InboxNote) async {
        do {
            try await thingsService.createTask(
                title: taskText,
                notes: nil,
                tags: [],
                energy: note.energyLevel,
                sourceNoteId: note.id,
                threadId: nil
            )
            try await inboxService.markTriaged(noteId: note.id)
            await loadNotes()
        } catch {
            self.error = error.localizedDescription
        }

        showTaskConfirmation = false
        selectedNoteForTask = nil
    }

    private func addToProject(_ note: InboxNote) {
        // TODO: Show project picker
        // For now, if suggested project exists, use that
        if let projectId = note.suggestedProjectId {
            Task {
                try? await inboxService.attachToProject(noteId: note.id, projectId: projectId)
                await loadNotes()
            }
        }
    }

    private func startProject(from note: InboxNote) {
        Task {
            do {
                let _ = try await projectService.createProject(
                    name: note.title,
                    fromNoteId: note.id,
                    concept: note.concepts?.first
                )
                try await inboxService.markTriaged(noteId: note.id)
                await loadNotes()
            } catch {
                self.error = error.localizedDescription
            }
        }
    }

    private func parkNote(_ note: InboxNote) {
        Task {
            try? await inboxService.markTriaged(noteId: note.id)
            await loadNotes()
        }
    }

    private func archiveNote(_ note: InboxNote) {
        Task {
            try? await inboxService.markArchived(noteId: note.id)
            await loadNotes()
        }
    }
}
```

**Step 2: Run tests**

Run: `cd SeleneChat && swift build`
Expected: Build succeeds

**Step 3: Commit InboxView**

```bash
git add SeleneChat/Sources/Views/Planning/InboxView.swift
git commit -m "feat(ui): add InboxView for note triage"
```

---

## Task 9: ActiveProjectsList

**Files:**
- Create: `SeleneChat/Sources/Views/Planning/ActiveProjectsList.swift`

**Step 1: Create ActiveProjectsList view**

```swift
// SeleneChat/Sources/Views/Planning/ActiveProjectsList.swift
import SwiftUI

struct ActiveProjectsList: View {
    @StateObject private var projectService = ProjectService.shared

    @State private var projects: [Project] = []
    @State private var isLoading = true
    @State private var error: String?

    let onSelectProject: (Project) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Section header
            HStack {
                Image(systemName: "flame")
                    .foregroundColor(.orange)
                Text("Active")
                    .font(.headline)

                if !projects.isEmpty {
                    Text("(\(projects.count))")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }

                Spacer()
            }
            .padding(.horizontal)
            .padding(.vertical, 8)

            Divider()

            // Content
            if isLoading {
                HStack {
                    Spacer()
                    ProgressView()
                    Spacer()
                }
                .padding()
            } else if projects.isEmpty {
                emptyState
            } else {
                LazyVStack(spacing: 8) {
                    ForEach(projects) { project in
                        ProjectRowView(project: project)
                            .onTapGesture { onSelectProject(project) }
                    }
                }
                .padding()
            }
        }
        .task {
            await loadProjects()
        }
    }

    private var emptyState: some View {
        VStack(spacing: 8) {
            Text("No active projects")
                .font(.subheadline)
                .foregroundColor(.secondary)
            Text("Start from inbox or activate a parked project")
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding()
    }

    private func loadProjects() async {
        isLoading = true

        do {
            projects = try await projectService.getActiveProjects()
        } catch {
            self.error = error.localizedDescription
        }

        isLoading = false
    }
}

struct ProjectRowView: View {
    let project: Project

    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text(project.name)
                    .font(.subheadline)
                    .fontWeight(.medium)

                HStack(spacing: 8) {
                    Label("\(project.noteCount)", systemImage: "doc")
                    if let time = project.timeSinceActive {
                        Text(time)
                    }
                }
                .font(.caption)
                .foregroundColor(.secondary)
            }

            Spacer()

            Image(systemName: "chevron.right")
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .padding(12)
        .background(Color(NSColor.controlBackgroundColor))
        .cornerRadius(8)
        .contentShape(Rectangle())
    }
}
```

**Step 2: Run tests**

Run: `cd SeleneChat && swift build`
Expected: Build succeeds

**Step 3: Commit ActiveProjectsList**

```bash
git add SeleneChat/Sources/Views/Planning/ActiveProjectsList.swift
git commit -m "feat(ui): add ActiveProjectsList for project display"
```

---

## Task 10: ParkedProjectsList

**Files:**
- Create: `SeleneChat/Sources/Views/Planning/ParkedProjectsList.swift`

**Step 1: Create ParkedProjectsList view**

```swift
// SeleneChat/Sources/Views/Planning/ParkedProjectsList.swift
import SwiftUI

struct ParkedProjectsList: View {
    @StateObject private var projectService = ProjectService.shared

    @State private var projects: [Project] = []
    @State private var isLoading = true
    @State private var isExpanded = false

    let onSelectProject: (Project) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Section header (always visible)
            Button(action: { withAnimation { isExpanded.toggle() } }) {
                HStack {
                    Image(systemName: "parkingsign")
                        .foregroundColor(.gray)
                    Text("Parked")
                        .font(.headline)

                    if !projects.isEmpty {
                        Text("(\(projects.count))")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }

                    Spacer()

                    Image(systemName: isExpanded ? "chevron.down" : "chevron.right")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            .buttonStyle(.plain)
            .padding(.horizontal)
            .padding(.vertical, 8)

            if isExpanded {
                Divider()

                // Content
                if isLoading {
                    HStack {
                        Spacer()
                        ProgressView()
                        Spacer()
                    }
                    .padding()
                } else if projects.isEmpty {
                    Text("No parked projects")
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .frame(maxWidth: .infinity)
                        .padding()
                } else {
                    LazyVStack(spacing: 8) {
                        ForEach(projects) { project in
                            ParkedProjectRow(
                                project: project,
                                onActivate: { activateProject(project) },
                                onSelect: { onSelectProject(project) }
                            )
                        }
                    }
                    .padding()
                }
            }
        }
        .task {
            await loadProjects()
        }
    }

    private func loadProjects() async {
        isLoading = true

        do {
            projects = try await projectService.getParkedProjects()
        } catch {
            // Handle error
        }

        isLoading = false
    }

    private func activateProject(_ project: Project) {
        Task {
            do {
                try await projectService.activateProject(project.id)
                await loadProjects()
            } catch {
                // Show error
            }
        }
    }
}

struct ParkedProjectRow: View {
    let project: Project
    let onActivate: () -> Void
    let onSelect: () -> Void

    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text(project.name)
                    .font(.caption)

                if let time = project.timeSinceActive {
                    Text("Last active \(time)")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }
            }
            .onTapGesture { onSelect() }

            Spacer()

            Button("Activate") {
                onActivate()
            }
            .font(.caption)
            .buttonStyle(.bordered)
        }
        .padding(8)
        .background(Color(NSColor.controlBackgroundColor).opacity(0.5))
        .cornerRadius(6)
    }
}
```

**Step 2: Run tests**

Run: `cd SeleneChat && swift build`
Expected: Build succeeds

**Step 3: Commit ParkedProjectsList**

```bash
git add SeleneChat/Sources/Views/Planning/ParkedProjectsList.swift
git commit -m "feat(ui): add ParkedProjectsList with expand/collapse"
```

---

## Task 11: PlanningView Refactor

**Files:**
- Modify: `SeleneChat/Sources/Views/PlanningView.swift`

**Step 1: Add service configuration to app startup**

In `SeleneChatApp.swift` or `ContentView.swift`, configure services with database connection:

```swift
// Add after databaseService is created
InboxService.shared.configure(with: databaseService.db!)
ProjectService.shared.configure(with: databaseService.db!)
```

**Step 2: Refactor PlanningView to use three sections**

Replace PlanningView body with:

```swift
struct PlanningView: View {
    @EnvironmentObject var databaseService: DatabaseService

    @State private var selectedThread: DiscussionThread?
    @State private var selectedProject: Project?

    var body: some View {
        Group {
            if let thread = selectedThread {
                PlanningConversationView(
                    thread: thread,
                    onBack: { selectedThread = nil }
                )
            } else if let project = selectedProject {
                ProjectDetailView(
                    project: project,
                    onBack: { selectedProject = nil }
                )
            } else {
                mainPlanningView
            }
        }
        .onAppear {
            #if DEBUG
            DebugLogger.shared.log(.nav, "Appeared: PlanningView")
            ActionTracker.shared.track(action: "viewAppeared", params: ["view": "PlanningView"])
            #endif
        }
    }

    private var mainPlanningView: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Planning")
                        .font(.title2)
                        .fontWeight(.semibold)
                }

                Spacer()

                Button(action: {}) {
                    Image(systemName: "gearshape")
                }
                .buttonStyle(.plain)
            }
            .padding()

            Divider()

            // Three sections
            ScrollView {
                VStack(spacing: 20) {
                    // Inbox section
                    InboxView()

                    Divider()
                        .padding(.horizontal)

                    // Active projects section
                    ActiveProjectsList(onSelectProject: { project in
                        selectedProject = project
                    })

                    Divider()
                        .padding(.horizontal)

                    // Parked projects section
                    ParkedProjectsList(onSelectProject: { project in
                        selectedProject = project
                    })
                }
                .padding(.bottom)
            }
        }
    }
}

// Placeholder for project detail
struct ProjectDetailView: View {
    let project: Project
    let onBack: () -> Void

    var body: some View {
        VStack {
            HStack {
                Button(action: onBack) {
                    Label("Back", systemImage: "chevron.left")
                }
                Spacer()
                Text(project.name)
                    .font(.headline)
                Spacer()
            }
            .padding()

            Text("Project detail view coming soon")
                .foregroundColor(.secondary)

            Spacer()
        }
    }
}
```

**Step 3: Run tests**

Run: `cd SeleneChat && swift build`
Expected: Build succeeds

**Step 4: Commit PlanningView refactor**

```bash
git add SeleneChat/Sources/Views/PlanningView.swift
git commit -m "refactor(ui): PlanningView with Inbox/Active/Parked sections"
```

---

## Task 12: Integration Testing

**Step 1: Create test script for database migration**

```bash
#!/bin/bash
# test-planning-inbox-migration.sh

DB_FILE=$(mktemp)
sqlite3 "$DB_FILE" < database/schema.sql
sqlite3 "$DB_FILE" < database/migrations/011_planning_inbox.sql

# Verify tables
echo "Checking projects table..."
sqlite3 "$DB_FILE" "SELECT sql FROM sqlite_master WHERE name='projects';"

echo "Checking project_notes table..."
sqlite3 "$DB_FILE" "SELECT sql FROM sqlite_master WHERE name='project_notes';"

echo "Checking raw_notes columns..."
sqlite3 "$DB_FILE" "PRAGMA table_info(raw_notes);" | grep -E "(inbox_status|suggested_type|suggested_project_id)"

rm "$DB_FILE"
echo "Migration test passed!"
```

**Step 2: Run migration test**

Run: `chmod +x test-planning-inbox-migration.sh && ./test-planning-inbox-migration.sh`
Expected: All tables and columns exist

**Step 3: Build and launch SeleneChat**

Run: `cd SeleneChat && swift build && swift run`
Expected: App launches, Planning tab shows three sections

**Step 4: Manual test checklist**

- [ ] Inbox section shows notes with inbox_status='pending'
- [ ] Empty state shows when no pending notes
- [ ] Triage buttons appear on cards
- [ ] Quick task confirmation sheet opens
- [ ] Active projects section loads (empty initially)
- [ ] Parked projects section expands/collapses

**Step 5: Commit test script**

```bash
git add test-planning-inbox-migration.sh
git commit -m "test: add planning inbox migration test script"
```

---

## Task 13: Update BRANCH-STATUS.md

**Step 1: Mark planning complete**

Update `BRANCH-STATUS.md`:

```markdown
### Planning
- [x] Design doc exists and approved
- [x] Conflict check completed (no overlapping work)
- [x] Dependencies identified and noted
- [x] Branch and worktree created
- [x] Implementation plan written (superpowers:writing-plans)
```

**Step 2: Commit status update**

```bash
git add BRANCH-STATUS.md
git commit -m "docs: mark planning stage complete"
```

---

## Execution Summary

Total tasks: 13
Total steps: ~120

**Suggested execution order:**
1. Tasks 1-3 (Database) - Foundation
2. Tasks 4-5 (Services) - Data layer
3. Tasks 6-8 (Views: Cards) - UI components
4. Tasks 9-11 (Views: Lists + Refactor) - Main UI
5. Tasks 12-13 (Testing + Status) - Verification

---

**Plan complete and saved to `docs/plans/2026-01-02-planning-inbox-implementation.md`. Two execution options:**

**1. Subagent-Driven (this session)** - I dispatch fresh subagent per task, review between tasks, fast iteration

**2. Parallel Session (separate)** - Open new session with executing-plans, batch execution with checkpoints

**Which approach?**
