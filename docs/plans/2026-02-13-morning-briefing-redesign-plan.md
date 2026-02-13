# Morning Briefing Redesign — Implementation Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** Replace the vague LLM-generated morning briefing with structured, data-driven cards that point to specific notes and threads, with progressive disclosure and context-aware chat.

**Architecture:** Hybrid approach — "What Changed" and "Needs Attention" sections use pure database queries (fast, reliable). "Connections" uses embedding similarity + LLM to explain cross-thread links. Each card expands inline and offers "Discuss this with Selene" which opens ChatView with deep context pre-loaded.

**Tech Stack:** Swift 5.9+, SwiftUI, SQLite.swift, Ollama (mistral:7b), XCTest

**Design Doc:** `docs/plans/2026-02-13-morning-briefing-redesign.md`

---

## Task 1: New BriefingState Model

Replace the old `Briefing` struct (which holds a single `content: String`) with structured card data.

**Files:**
- Modify: `SeleneChat/Sources/Models/BriefingState.swift`
- Test: `SeleneChat/Tests/SeleneChatTests/Models/BriefingStateTests.swift`

**Step 1: Write the failing test**

In `BriefingStateTests.swift`, add tests for the new model types:

```swift
func testBriefingCardTypes() {
    let changedCard = BriefingCard.whatChanged(
        noteTitle: "Planning Deep Work",
        noteId: 1,
        threadName: "Focus Systems",
        threadId: 5,
        date: Date(),
        primaryTheme: "productivity",
        energyLevel: "high"
    )

    XCTAssertEqual(changedCard.cardType, .whatChanged)
    XCTAssertEqual(changedCard.noteTitle, "Planning Deep Work")
    XCTAssertEqual(changedCard.threadName, "Focus Systems")
}

func testNeedsAttentionCard() {
    let attentionCard = BriefingCard.needsAttention(
        threadName: "Focus Systems",
        threadId: 5,
        reason: "No new notes in 6 days",
        noteCount: 8,
        openTaskCount: 3
    )

    XCTAssertEqual(attentionCard.cardType, .needsAttention)
    XCTAssertEqual(attentionCard.reason, "No new notes in 6 days")
    XCTAssertEqual(attentionCard.openTaskCount, 3)
}

func testConnectionCard() {
    let connectionCard = BriefingCard.connection(
        noteATitle: "Planning Deep Work",
        noteAId: 1,
        threadAName: "Focus Systems",
        noteBTitle: "Morning Routine Experiment",
        noteBId: 7,
        threadBName: "Daily Habits",
        explanation: "Both explore structuring time around energy levels"
    )

    XCTAssertEqual(connectionCard.cardType, .connection)
    XCTAssertEqual(connectionCard.explanation, "Both explore structuring time around energy levels")
}

func testStructuredBriefing() {
    let briefing = StructuredBriefing(
        intro: "Busy day yesterday, 4 notes across 2 threads.",
        whatChanged: [],
        needsAttention: [],
        connections: [],
        generatedAt: Date()
    )

    XCTAssertTrue(briefing.whatChanged.isEmpty)
    XCTAssertFalse(briefing.intro.isEmpty)
}

func testStructuredBriefingStatus() {
    let briefing = StructuredBriefing(
        intro: "Test",
        whatChanged: [],
        needsAttention: [],
        connections: [],
        generatedAt: Date()
    )
    let status = BriefingStatus.loaded(briefing)

    if case .loaded(let b) = status {
        XCTAssertEqual(b.intro, "Test")
    } else {
        XCTFail("Expected loaded status")
    }
}
```

**Step 2: Run test to verify it fails**

Run: `cd SeleneChat && swift test --filter BriefingStateTests 2>&1 | tail -20`
Expected: FAIL — types don't exist yet

**Step 3: Write minimal implementation**

Replace the contents of `BriefingState.swift`:

```swift
import Foundation

/// Types of briefing cards
enum BriefingCardType: Equatable {
    case whatChanged
    case needsAttention
    case connection
}

/// A single briefing card with data for one insight
struct BriefingCard: Identifiable, Equatable {
    let id = UUID()
    let cardType: BriefingCardType

    // What Changed fields
    var noteTitle: String?
    var noteId: Int?
    var threadName: String?
    var threadId: Int64?
    var date: Date?
    var primaryTheme: String?
    var energyLevel: String?

    // Needs Attention fields
    var reason: String?
    var noteCount: Int?
    var openTaskCount: Int?

    // Connection fields
    var noteATitle: String?
    var noteAId: Int?
    var threadAName: String?
    var noteBTitle: String?
    var noteBId: Int?
    var threadBName: String?
    var explanation: String?

    // Preview content (loaded on expand)
    var notePreview: String?
    var threadSummary: String?
    var threadWhy: String?

    var energyEmoji: String {
        switch energyLevel?.lowercased() {
        case "high": return "⚡"
        case "medium": return "🔋"
        case "low": return "🪫"
        default: return ""
        }
    }

    // MARK: - Factory Methods

    static func whatChanged(
        noteTitle: String,
        noteId: Int,
        threadName: String?,
        threadId: Int64?,
        date: Date,
        primaryTheme: String?,
        energyLevel: String?
    ) -> BriefingCard {
        BriefingCard(
            cardType: .whatChanged,
            noteTitle: noteTitle,
            noteId: noteId,
            threadName: threadName,
            threadId: threadId,
            date: date,
            primaryTheme: primaryTheme,
            energyLevel: energyLevel
        )
    }

    static func needsAttention(
        threadName: String,
        threadId: Int64,
        reason: String,
        noteCount: Int,
        openTaskCount: Int
    ) -> BriefingCard {
        BriefingCard(
            cardType: .needsAttention,
            threadName: threadName,
            threadId: threadId,
            reason: reason,
            noteCount: noteCount,
            openTaskCount: openTaskCount
        )
    }

    static func connection(
        noteATitle: String,
        noteAId: Int,
        threadAName: String,
        noteBTitle: String,
        noteBId: Int,
        threadBName: String,
        explanation: String
    ) -> BriefingCard {
        BriefingCard(
            cardType: .connection,
            noteATitle: noteATitle,
            noteAId: noteAId,
            threadAName: threadAName,
            noteBTitle: noteBTitle,
            noteBId: noteBId,
            threadBName: threadBName,
            explanation: explanation
        )
    }

    // Equatable (ignore UUID id)
    static func == (lhs: BriefingCard, rhs: BriefingCard) -> Bool {
        lhs.cardType == rhs.cardType &&
        lhs.noteTitle == rhs.noteTitle &&
        lhs.noteId == rhs.noteId &&
        lhs.threadName == rhs.threadName
    }
}

/// Structured briefing with sections
struct StructuredBriefing: Equatable {
    let intro: String
    let whatChanged: [BriefingCard]
    let needsAttention: [BriefingCard]
    let connections: [BriefingCard]
    let generatedAt: Date

    var isEmpty: Bool {
        whatChanged.isEmpty && needsAttention.isEmpty && connections.isEmpty
    }
}

/// Loading status for the morning briefing
enum BriefingStatus: Equatable {
    case notLoaded
    case loading
    case loaded(StructuredBriefing)
    case failed(String)
}

/// State container for the morning briefing feature
struct BriefingState {
    var status: BriefingStatus = .notLoaded
}
```

**Step 4: Run test to verify it passes**

Run: `cd SeleneChat && swift test --filter BriefingStateTests 2>&1 | tail -20`
Expected: PASS

**Step 5: Commit**

```bash
git add SeleneChat/Sources/Models/BriefingState.swift SeleneChat/Tests/SeleneChatTests/Models/BriefingStateTests.swift
git commit -m "feat(briefing): replace Briefing model with structured BriefingCard types"
```

---

## Task 2: New Database Queries for Briefing Data

Add queries to DatabaseService for the three briefing sections: notes since last open, stalled threads, and cross-thread associations.

**Files:**
- Modify: `SeleneChat/Sources/Services/DatabaseService.swift`
- Test: `SeleneChat/Tests/SeleneChatTests/Services/BriefingDatabaseTests.swift` (create)

**Step 1: Write the failing tests**

Create `SeleneChat/Tests/SeleneChatTests/Services/BriefingDatabaseTests.swift`:

```swift
import XCTest
@testable import SeleneChat

final class BriefingDatabaseTests: XCTestCase {

    // MARK: - Notes Since Date

    func testGetNotesSinceDateQuery() {
        // Verify the method signature exists and returns the right type
        // This tests the query builder, not actual DB execution
        let service = DatabaseService.shared
        let since = Calendar.current.date(byAdding: .day, value: -1, to: Date())!

        // Method should exist and be callable
        Task {
            let notes = try await service.getNotesSince(since, limit: 10)
            // Just verify it returns [Note] (may be empty in test DB)
            XCTAssertTrue(notes is [Note])
        }
    }

    // MARK: - Notes Grouped By Thread

    func testGroupNotesByThread() {
        let notes = [
            Note.mock(id: 1, title: "Note A"),
            Note.mock(id: 2, title: "Note B"),
            Note.mock(id: 3, title: "Note C")
        ]

        let threadMap: [Int: (threadName: String, threadId: Int64)] = [
            1: ("Focus Systems", 5),
            2: ("Focus Systems", 5),
            3: ("Daily Habits", 8)
        ]

        let grouped = BriefingDataService.groupNotesByThread(notes, threadMap: threadMap)

        XCTAssertEqual(grouped.count, 2)  // 2 threads
        XCTAssertEqual(grouped["Focus Systems"]?.count, 2)
        XCTAssertEqual(grouped["Daily Habits"]?.count, 1)
    }

    // MARK: - Stalled Threads

    func testIdentifyStalledThreads() {
        let now = Date()
        let sixDaysAgo = Calendar.current.date(byAdding: .day, value: -6, to: now)!
        let yesterday = Calendar.current.date(byAdding: .day, value: -1, to: now)!

        let threads = [
            Thread.mock(id: 1, name: "Stalled", lastActivityAt: sixDaysAgo),
            Thread.mock(id: 2, name: "Active", lastActivityAt: yesterday)
        ]

        let stalled = BriefingDataService.identifyStalledThreads(threads, staleDays: 5)

        XCTAssertEqual(stalled.count, 1)
        XCTAssertEqual(stalled.first?.name, "Stalled")
    }

    // MARK: - Cross-Thread Associations

    func testCrossThreadAssociationFiltering() {
        // Pairs where both notes are in the SAME thread should be excluded
        let pairs: [(noteAId: Int, noteBId: Int, similarity: Double)] = [
            (1, 2, 0.85),  // cross-thread
            (3, 4, 0.90),  // same thread
            (5, 6, 0.75),  // cross-thread
        ]

        let noteThreadMap: [Int: Int64] = [
            1: 10, 2: 20,  // different threads
            3: 10, 4: 10,  // same thread
            5: 20, 6: 30   // different threads
        ]

        let crossThread = BriefingDataService.filterCrossThreadPairs(pairs, noteThreadMap: noteThreadMap)

        XCTAssertEqual(crossThread.count, 2)
    }
}
```

**Step 2: Run test to verify it fails**

Run: `cd SeleneChat && swift test --filter BriefingDatabaseTests 2>&1 | tail -20`
Expected: FAIL — `BriefingDataService` doesn't exist, `getNotesSince` doesn't exist

**Step 3: Write minimal implementation**

Add to `DatabaseService.swift` (after existing `getRecentNotes` method around line 394):

```swift
/// Get notes created since a specific date
/// Used by morning briefing to show "What Changed"
func getNotesSince(_ date: Date, limit: Int = 20) async throws -> [Note] {
    guard let db = db else {
        throw DatabaseError.notConnected
    }

    let dateStr = iso8601Formatter.string(from: date)
    let query = rawNotes
        .join(.leftOuter, processedNotes, on: rawNotes[id] == processedNotes[rawNoteId])
        .filter(rawNotes[createdAt] >= dateStr)
        .filter(rawNotes[testRunCol] == nil as String?)
        .order(rawNotes[createdAt].desc)
        .limit(limit)

    return try buildNotesFromQuery(db: db, query: query)
}

/// Get thread assignment for a list of note IDs
/// Returns [noteId: (threadName, threadId)]
func getThreadAssignmentsForNotes(_ noteIds: [Int]) async throws -> [Int: (threadName: String, threadId: Int64)] {
    guard let db = db else {
        throw DatabaseError.notConnected
    }

    var result: [Int: (threadName: String, threadId: Int64)] = [:]

    let query = """
        SELECT tn.raw_note_id, t.id as thread_id, t.name as thread_name
        FROM thread_notes tn
        JOIN threads t ON tn.thread_id = t.id
        WHERE tn.raw_note_id IN (\(noteIds.map { String($0) }.joined(separator: ",")))
        AND t.status = 'active'
    """

    guard !noteIds.isEmpty else { return result }

    for row in try db.prepare(query) {
        let noteId = Int(row[0] as! Int64)
        let threadId = row[1] as! Int64
        let threadName = row[2] as! String
        result[noteId] = (threadName, threadId)
    }

    return result
}

/// Get cross-thread note association pairs with high similarity
/// Returns pairs where notes belong to different threads, sorted by similarity
func getCrossThreadAssociations(minSimilarity: Double = 0.7, recentDays: Int = 7, limit: Int = 10) async throws -> [(noteAId: Int, noteBId: Int, similarity: Double)] {
    guard let db = db else {
        throw DatabaseError.notConnected
    }

    let cutoffDate = Calendar.current.date(byAdding: .day, value: -recentDays, to: Date())!
    let dateStr = iso8601Formatter.string(from: cutoffDate)

    let query = """
        SELECT na.note_id_a, na.note_id_b, na.similarity_score
        FROM note_associations na
        JOIN raw_notes rn_a ON na.note_id_a = rn_a.id
        JOIN raw_notes rn_b ON na.note_id_b = rn_b.id
        JOIN thread_notes tn_a ON na.note_id_a = tn_a.raw_note_id
        JOIN thread_notes tn_b ON na.note_id_b = tn_b.raw_note_id
        WHERE na.similarity_score >= ?
        AND tn_a.thread_id != tn_b.thread_id
        AND (rn_a.created_at >= ? OR rn_b.created_at >= ?)
        ORDER BY na.similarity_score DESC
        LIMIT ?
    """

    var pairs: [(noteAId: Int, noteBId: Int, similarity: Double)] = []
    let stmt = try db.prepare(query)
    for row in stmt.bind(minSimilarity, dateStr, dateStr, limit) {
        let noteAId = Int(row[0] as! Int64)
        let noteBId = Int(row[1] as! Int64)
        let similarity = row[2] as! Double
        pairs.append((noteAId, noteBId, similarity))
    }

    return pairs
}
```

Create `SeleneChat/Sources/Services/BriefingDataService.swift`:

```swift
import Foundation

/// Pure functions for briefing data processing (no DB dependency, testable)
enum BriefingDataService {

    /// Group notes by their thread assignment
    static func groupNotesByThread(
        _ notes: [Note],
        threadMap: [Int: (threadName: String, threadId: Int64)]
    ) -> [String: [(note: Note, threadId: Int64)]] {
        var grouped: [String: [(note: Note, threadId: Int64)]] = [:]

        for note in notes {
            if let assignment = threadMap[note.id] {
                grouped[assignment.threadName, default: []].append((note, assignment.threadId))
            } else {
                grouped["Unthreaded", default: []].append((note, -1))
            }
        }

        return grouped
    }

    /// Identify threads that haven't had activity in N days
    static func identifyStalledThreads(_ threads: [Thread], staleDays: Int = 5) -> [Thread] {
        let cutoff = Calendar.current.date(byAdding: .day, value: -staleDays, to: Date())!

        return threads.filter { thread in
            guard let lastActivity = thread.lastActivityAt else { return true }
            return lastActivity < cutoff
        }
    }

    /// Filter association pairs to only cross-thread pairs
    static func filterCrossThreadPairs(
        _ pairs: [(noteAId: Int, noteBId: Int, similarity: Double)],
        noteThreadMap: [Int: Int64]
    ) -> [(noteAId: Int, noteBId: Int, similarity: Double)] {
        pairs.filter { pair in
            guard let threadA = noteThreadMap[pair.noteAId],
                  let threadB = noteThreadMap[pair.noteBId] else {
                return false
            }
            return threadA != threadB
        }
    }
}
```

**Step 4: Run test to verify it passes**

Run: `cd SeleneChat && swift test --filter BriefingDatabaseTests 2>&1 | tail -20`
Expected: PASS

**Step 5: Commit**

```bash
git add SeleneChat/Sources/Services/DatabaseService.swift SeleneChat/Sources/Services/BriefingDataService.swift SeleneChat/Tests/SeleneChatTests/Services/BriefingDatabaseTests.swift
git commit -m "feat(briefing): add DB queries and data service for structured briefing"
```

---

## Task 3: BriefingContextBuilder — Deep Context Assembly

Build the service that assembles rich context for "Discuss this" chat sessions.

**Files:**
- Create: `SeleneChat/Sources/Services/BriefingContextBuilder.swift`
- Test: `SeleneChat/Tests/SeleneChatTests/Services/BriefingContextBuilderTests.swift` (create)

**Step 1: Write the failing tests**

Create `SeleneChat/Tests/SeleneChatTests/Services/BriefingContextBuilderTests.swift`:

```swift
import XCTest
@testable import SeleneChat

final class BriefingContextBuilderTests: XCTestCase {

    let builder = BriefingContextBuilder()

    // MARK: - What Changed Context

    func testWhatChangedContextIncludesNoteContent() {
        let note = Note.mock(id: 1, title: "Deep Work Planning", content: "I want to block mornings for creative work")
        let thread = Thread.mock(id: 5, name: "Focus Systems", summary: "Strategies for sustained attention")

        let context = builder.buildWhatChangedContext(note: note, thread: thread, relatedNotes: [], tasks: [], memories: [])

        XCTAssertTrue(context.contains("Deep Work Planning"))
        XCTAssertTrue(context.contains("I want to block mornings"))
        XCTAssertTrue(context.contains("Focus Systems"))
        XCTAssertTrue(context.contains("Strategies for sustained attention"))
    }

    func testWhatChangedContextIncludesRelatedNotes() {
        let note = Note.mock(id: 1, title: "Main Note")
        let thread = Thread.mock(id: 5, name: "Thread")
        let related = [
            Note.mock(id: 2, title: "Related Note A", content: "Content A"),
            Note.mock(id: 3, title: "Related Note B", content: "Content B")
        ]

        let context = builder.buildWhatChangedContext(note: note, thread: thread, relatedNotes: related, tasks: [], memories: [])

        XCTAssertTrue(context.contains("Related Note A"))
        XCTAssertTrue(context.contains("Related Note B"))
    }

    // MARK: - Needs Attention Context

    func testNeedsAttentionContextIncludesThreadHistory() {
        let thread = Thread.mock(id: 5, name: "Stalled Thread", why: "Understanding focus patterns")
        let recentNotes = [
            Note.mock(id: 1, title: "Last Note", content: "Was working on X"),
            Note.mock(id: 2, title: "Earlier Note", content: "Started exploring Y")
        ]

        let context = builder.buildNeedsAttentionContext(thread: thread, recentNotes: recentNotes, tasks: [], memories: [])

        XCTAssertTrue(context.contains("Stalled Thread"))
        XCTAssertTrue(context.contains("Understanding focus patterns"))
        XCTAssertTrue(context.contains("Last Note"))
    }

    func testNeedsAttentionContextIncludesTasks() {
        let thread = Thread.mock(id: 5, name: "Thread")
        let tasks = [
            ThreadTask.mock(id: 1, threadId: 5, title: "Review notes"),
            ThreadTask.mock(id: 2, threadId: 5, title: "Write summary", completedAt: Date())
        ]

        let context = builder.buildNeedsAttentionContext(thread: thread, recentNotes: [], tasks: tasks, memories: [])

        XCTAssertTrue(context.contains("Review notes"))
    }

    // MARK: - Connection Context

    func testConnectionContextIncludesBothNotes() {
        let noteA = Note.mock(id: 1, title: "Note A", content: "Content about energy")
        let noteB = Note.mock(id: 7, title: "Note B", content: "Content about routines")
        let threadA = Thread.mock(id: 5, name: "Focus Systems")
        let threadB = Thread.mock(id: 8, name: "Daily Habits")

        let context = builder.buildConnectionContext(
            noteA: noteA, threadA: threadA,
            noteB: noteB, threadB: threadB,
            relatedToA: [], relatedToB: [],
            tasks: [], memories: []
        )

        XCTAssertTrue(context.contains("Note A"))
        XCTAssertTrue(context.contains("Note B"))
        XCTAssertTrue(context.contains("Focus Systems"))
        XCTAssertTrue(context.contains("Daily Habits"))
        XCTAssertTrue(context.contains("Content about energy"))
        XCTAssertTrue(context.contains("Content about routines"))
    }

    // MARK: - System Prompt

    func testSystemPromptIncludesContextType() {
        let prompt = builder.buildSystemPrompt(for: .whatChanged)

        XCTAssertTrue(prompt.contains("Selene"))
        XCTAssertTrue(prompt.contains("morning briefing"))
        XCTAssertTrue(prompt.contains("Don't summarize"))
    }
}
```

**Step 2: Run test to verify it fails**

Run: `cd SeleneChat && swift test --filter BriefingContextBuilderTests 2>&1 | tail -20`
Expected: FAIL — `BriefingContextBuilder` doesn't exist

**Step 3: Write minimal implementation**

Create `SeleneChat/Sources/Services/BriefingContextBuilder.swift`:

```swift
import Foundation

/// Assembles deep context for "Discuss this" chat sessions from briefing cards
class BriefingContextBuilder {

    /// Context types matching card types
    enum ContextType {
        case whatChanged
        case needsAttention
        case connection
    }

    // MARK: - What Changed Context

    /// Build context for discussing a specific new note
    func buildWhatChangedContext(
        note: Note,
        thread: Thread?,
        relatedNotes: [Note],
        tasks: [ThreadTask],
        memories: [ConversationMemory]
    ) -> String {
        var context = "## Specific Note\n\n"
        context += "### \(note.title) (\(formatDate(note.createdAt)))\n"
        context += "\(note.content)\n\n"

        if let concepts = note.concepts, !concepts.isEmpty {
            context += "Concepts: \(concepts.joined(separator: ", "))\n"
        }
        if let theme = note.primaryTheme {
            context += "Theme: \(theme)\n"
        }
        if let energy = note.energyLevel {
            context += "Energy: \(energy)\n"
        }

        if let thread = thread {
            context += "\n## Parent Thread: \(thread.name)\n"
            if let summary = thread.summary { context += "Summary: \(summary)\n" }
            if let why = thread.why { context += "Why: \(why)\n" }
            context += "Notes: \(thread.noteCount) | Momentum: \(thread.momentumDisplay)\n"
        }

        if !relatedNotes.isEmpty {
            context += "\n## Related Notes (by semantic similarity)\n\n"
            for related in relatedNotes.prefix(3) {
                context += "### \(related.title) (\(formatDate(related.createdAt)))\n"
                context += "\(String(related.content.prefix(300)))\n\n"
            }
        }

        context += formatTasks(tasks)
        context += formatMemories(memories)

        return context
    }

    // MARK: - Needs Attention Context

    /// Build context for discussing a stalled thread
    func buildNeedsAttentionContext(
        thread: Thread,
        recentNotes: [Note],
        tasks: [ThreadTask],
        memories: [ConversationMemory]
    ) -> String {
        var context = "## Thread: \(thread.name)\n\n"
        context += "Status: \(thread.status) \(thread.statusEmoji)\n"
        context += "Notes: \(thread.noteCount) | Momentum: \(thread.momentumDisplay)\n"
        context += "Last activity: \(thread.lastActivityDisplay)\n"

        if let why = thread.why { context += "Why this emerged: \(why)\n" }
        if let summary = thread.summary { context += "Summary: \(summary)\n" }

        if !recentNotes.isEmpty {
            context += "\n## Recent Notes in This Thread\n\n"
            for note in recentNotes.prefix(3) {
                context += "### \(note.title) (\(formatDate(note.createdAt)))\n"
                context += "\(String(note.content.prefix(300)))\n\n"
            }
        }

        context += formatTasks(tasks)
        context += formatMemories(memories)

        return context
    }

    // MARK: - Connection Context

    /// Build context for discussing a connection between two notes
    func buildConnectionContext(
        noteA: Note, threadA: Thread?,
        noteB: Note, threadB: Thread?,
        relatedToA: [Note], relatedToB: [Note],
        tasks: [ThreadTask],
        memories: [ConversationMemory]
    ) -> String {
        var context = "## Note A: \(noteA.title)\n"
        context += "Thread: \(threadA?.name ?? "Unthreaded")\n\n"
        context += "\(noteA.content)\n\n"

        if let concepts = noteA.concepts, !concepts.isEmpty {
            context += "Concepts: \(concepts.joined(separator: ", "))\n"
        }

        context += "\n## Note B: \(noteB.title)\n"
        context += "Thread: \(threadB?.name ?? "Unthreaded")\n\n"
        context += "\(noteB.content)\n\n"

        if let concepts = noteB.concepts, !concepts.isEmpty {
            context += "Concepts: \(concepts.joined(separator: ", "))\n"
        }

        if let threadA = threadA {
            context += "\n## Thread: \(threadA.name)\n"
            if let summary = threadA.summary { context += "Summary: \(summary)\n" }
        }

        if let threadB = threadB {
            context += "\n## Thread: \(threadB.name)\n"
            if let summary = threadB.summary { context += "Summary: \(summary)\n" }
        }

        if !relatedToA.isEmpty {
            context += "\n## Notes Related to \(noteA.title)\n\n"
            for note in relatedToA.prefix(3) {
                context += "- \(note.title): \(String(note.content.prefix(150)))\n"
            }
        }

        if !relatedToB.isEmpty {
            context += "\n## Notes Related to \(noteB.title)\n\n"
            for note in relatedToB.prefix(3) {
                context += "- \(note.title): \(String(note.content.prefix(150)))\n"
            }
        }

        context += formatTasks(tasks)
        context += formatMemories(memories)

        return context
    }

    // MARK: - System Prompt

    /// Build system prompt for discuss-this chat sessions
    func buildSystemPrompt(for contextType: ContextType) -> String {
        let typeGuidance: String
        switch contextType {
        case .whatChanged:
            typeGuidance = "The user wants to discuss a specific note they recently wrote."
        case .needsAttention:
            typeGuidance = "The user wants to revisit a thread that has stalled or needs attention."
        case .connection:
            typeGuidance = "The user wants to explore a connection between two notes from different threads."
        }

        return """
        You are Selene, a thinking partner for someone with ADHD. The user wants to discuss \
        something from their morning briefing.

        \(typeGuidance)

        You already know the material provided below. Don't summarize it back to them. \
        Start by asking a specific question or making a specific observation that helps \
        the user think deeper about this topic. Be concrete — reference specific details \
        from their notes.
        """
    }

    // MARK: - Helpers

    private func formatTasks(_ tasks: [ThreadTask]) -> String {
        let openTasks = tasks.filter { !$0.isCompleted }
        guard !openTasks.isEmpty else { return "" }

        var result = "\n## Open Tasks\n\n"
        for task in openTasks {
            result += "- \(task.title ?? task.thingsTaskId)\n"
        }
        return result
    }

    private func formatMemories(_ memories: [ConversationMemory]) -> String {
        guard !memories.isEmpty else { return "" }

        var result = "\n## Conversation Memory\n\n"
        for memory in memories.prefix(5) {
            result += "- [\(memory.memoryType.rawValue)] \(memory.content)\n"
        }
        return result
    }

    private func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .none
        return formatter.string(from: date)
    }
}
```

**Step 4: Run test to verify it passes**

Run: `cd SeleneChat && swift test --filter BriefingContextBuilderTests 2>&1 | tail -20`
Expected: PASS

**Step 5: Commit**

```bash
git add SeleneChat/Sources/Services/BriefingContextBuilder.swift SeleneChat/Tests/SeleneChatTests/Services/BriefingContextBuilderTests.swift
git commit -m "feat(briefing): add BriefingContextBuilder for deep context chat assembly"
```

---

## Task 4: Rewrite BriefingViewModel

Replace the old ViewModel that generated one LLM paragraph with a new one that orchestrates three data tracks in parallel.

**Files:**
- Modify: `SeleneChat/Sources/ViewModels/BriefingViewModel.swift`
- Modify: `SeleneChat/Tests/SeleneChatTests/ViewModels/BriefingViewModelTests.swift`

**Step 1: Write the failing tests**

Replace `BriefingViewModelTests.swift`:

```swift
import XCTest
@testable import SeleneChat

@MainActor
final class BriefingViewModelTests: XCTestCase {

    func testInitialState() {
        let viewModel = BriefingViewModel()

        if case .notLoaded = viewModel.state.status {
            // Expected
        } else {
            XCTFail("Expected notLoaded state")
        }
        XCTAssertFalse(viewModel.isDismissed)
    }

    func testDismiss() async {
        let viewModel = BriefingViewModel()
        await viewModel.dismiss()
        XCTAssertTrue(viewModel.isDismissed)
    }

    func testBuildWhatChangedCards() {
        let viewModel = BriefingViewModel()

        let notes = [
            Note.mock(id: 1, title: "Note A", primaryTheme: "focus", energyLevel: "high"),
            Note.mock(id: 2, title: "Note B", primaryTheme: "habits", energyLevel: "low")
        ]

        let threadMap: [Int: (threadName: String, threadId: Int64)] = [
            1: ("Focus Systems", 5),
            2: ("Daily Habits", 8)
        ]

        let cards = viewModel.buildWhatChangedCards(notes: notes, threadMap: threadMap)

        XCTAssertEqual(cards.count, 2)
        XCTAssertEqual(cards[0].noteTitle, "Note A")
        XCTAssertEqual(cards[0].threadName, "Focus Systems")
        XCTAssertEqual(cards[0].energyLevel, "high")
        XCTAssertEqual(cards[1].noteTitle, "Note B")
        XCTAssertEqual(cards[1].threadName, "Daily Habits")
    }

    func testBuildNeedsAttentionCards() {
        let viewModel = BriefingViewModel()
        let sixDaysAgo = Calendar.current.date(byAdding: .day, value: -6, to: Date())!

        let stalledThreads = [
            Thread.mock(id: 5, name: "Stalled Thread", noteCount: 8, lastActivityAt: sixDaysAgo)
        ]

        let taskCounts: [Int64: Int] = [5: 3]

        let cards = viewModel.buildNeedsAttentionCards(threads: stalledThreads, openTaskCounts: taskCounts)

        XCTAssertEqual(cards.count, 1)
        XCTAssertEqual(cards[0].threadName, "Stalled Thread")
        XCTAssertEqual(cards[0].openTaskCount, 3)
        XCTAssertTrue(cards[0].reason?.contains("6 days") == true || cards[0].reason?.contains("days") == true)
    }

    func testBuildConnectionCards() {
        let viewModel = BriefingViewModel()

        let noteA = Note.mock(id: 1, title: "Note A")
        let noteB = Note.mock(id: 7, title: "Note B")

        let connections: [(noteA: Note, noteB: Note, threadAName: String, threadBName: String, explanation: String)] = [
            (noteA, noteB, "Focus Systems", "Daily Habits", "Both about energy management")
        ]

        let cards = viewModel.buildConnectionCards(connections: connections)

        XCTAssertEqual(cards.count, 1)
        XCTAssertEqual(cards[0].noteATitle, "Note A")
        XCTAssertEqual(cards[0].noteBTitle, "Note B")
        XCTAssertEqual(cards[0].explanation, "Both about energy management")
    }

    func testBuildIntroText() {
        let viewModel = BriefingViewModel()

        let intro = viewModel.buildFallbackIntro(changedCount: 3, attentionCount: 1, connectionCount: 2)

        XCTAssertTrue(intro.contains("3"))
        XCTAssertTrue(intro.contains("note"))
    }
}
```

**Step 2: Run test to verify it fails**

Run: `cd SeleneChat && swift test --filter BriefingViewModelTests 2>&1 | tail -20`
Expected: FAIL — new methods don't exist

**Step 3: Write minimal implementation**

Replace `BriefingViewModel.swift`:

```swift
import Foundation

/// ViewModel for managing morning briefing state and orchestrating data-driven briefing generation
@MainActor
class BriefingViewModel: ObservableObject {
    @Published var state = BriefingState()
    @Published var isDismissed = false

    private let databaseService = DatabaseService.shared
    private let ollamaService = OllamaService.shared
    private let contextBuilder = BriefingContextBuilder()

    private static let lastOpenKey = "briefing_last_open_date"

    // MARK: - Load Briefing

    func loadBriefing() async {
        state.status = .loading

        do {
            // Track 1: What Changed (pure DB)
            let lastOpen = UserDefaults.standard.object(forKey: Self.lastOpenKey) as? Date
                ?? Calendar.current.date(byAdding: .day, value: -1, to: Date())!

            let recentNotes = try await databaseService.getNotesSince(lastOpen, limit: 20)
            let noteIds = recentNotes.map { $0.id }
            let threadMap = try await databaseService.getThreadAssignmentsForNotes(noteIds)
            let whatChangedCards = buildWhatChangedCards(notes: recentNotes, threadMap: threadMap)

            // Track 2: Needs Attention (pure DB)
            let activeThreads = try await databaseService.getActiveThreads(limit: 20)
            let stalledThreads = BriefingDataService.identifyStalledThreads(activeThreads, staleDays: 5)

            var openTaskCounts: [Int64: Int] = [:]
            for thread in stalledThreads {
                let tasks = try await databaseService.getTasksForThread(thread.id)
                openTaskCounts[thread.id] = tasks.filter { !$0.isCompleted }.count
            }
            let needsAttentionCards = buildNeedsAttentionCards(threads: stalledThreads, openTaskCounts: openTaskCounts)

            // Track 3: Connections (embeddings + LLM)
            var connectionCards: [BriefingCard] = []
            let pairs = try await databaseService.getCrossThreadAssociations(minSimilarity: 0.7, recentDays: 7, limit: 3)

            if !pairs.isEmpty {
                connectionCards = await buildConnectionCardsFromPairs(pairs)
            }

            // Track 4: LLM Intro (or fallback)
            let intro = await generateIntro(
                changedCount: whatChangedCards.count,
                attentionCount: needsAttentionCards.count,
                connectionCount: connectionCards.count
            )

            let briefing = StructuredBriefing(
                intro: intro,
                whatChanged: whatChangedCards,
                needsAttention: needsAttentionCards,
                connections: connectionCards,
                generatedAt: Date()
            )

            state.status = .loaded(briefing)

            // Store last open time
            UserDefaults.standard.set(Date(), forKey: Self.lastOpenKey)

        } catch {
            state.status = .failed(error.localizedDescription)
        }
    }

    func dismiss() async {
        isDismissed = true
    }

    // MARK: - Card Builders

    func buildWhatChangedCards(notes: [Note], threadMap: [Int: (threadName: String, threadId: Int64)]) -> [BriefingCard] {
        notes.map { note in
            let assignment = threadMap[note.id]
            return BriefingCard.whatChanged(
                noteTitle: note.title,
                noteId: note.id,
                threadName: assignment?.threadName,
                threadId: assignment?.threadId,
                date: note.createdAt,
                primaryTheme: note.primaryTheme,
                energyLevel: note.energyLevel
            )
        }
    }

    func buildNeedsAttentionCards(threads: [Thread], openTaskCounts: [Int64: Int]) -> [BriefingCard] {
        threads.map { thread in
            let taskCount = openTaskCounts[thread.id] ?? 0
            let daysSince = daysSinceLastActivity(thread)

            var reasons: [String] = []
            if daysSince >= 5 {
                reasons.append("no activity in \(daysSince) days")
            }
            if taskCount > 0 {
                reasons.append("\(taskCount) open task\(taskCount == 1 ? "" : "s")")
            }

            return BriefingCard.needsAttention(
                threadName: thread.name,
                threadId: thread.id,
                reason: reasons.joined(separator: ", "),
                noteCount: thread.noteCount,
                openTaskCount: taskCount
            )
        }
    }

    func buildConnectionCards(connections: [(noteA: Note, noteB: Note, threadAName: String, threadBName: String, explanation: String)]) -> [BriefingCard] {
        connections.map { conn in
            BriefingCard.connection(
                noteATitle: conn.noteA.title,
                noteAId: conn.noteA.id,
                threadAName: conn.threadAName,
                noteBTitle: conn.noteB.title,
                noteBId: conn.noteB.id,
                threadBName: conn.threadBName,
                explanation: conn.explanation
            )
        }
    }

    func buildFallbackIntro(changedCount: Int, attentionCount: Int, connectionCount: Int) -> String {
        var parts: [String] = []

        if changedCount > 0 {
            parts.append("\(changedCount) new note\(changedCount == 1 ? "" : "s") since last time")
        }
        if attentionCount > 0 {
            parts.append("\(attentionCount) thread\(attentionCount == 1 ? "" : "s") need\(attentionCount == 1 ? "s" : "") attention")
        }
        if connectionCount > 0 {
            parts.append("\(connectionCount) connection\(connectionCount == 1 ? "" : "s") found")
        }

        if parts.isEmpty {
            return "Nothing new since last time."
        }

        return parts.joined(separator: ". ") + "."
    }

    // MARK: - Private Helpers

    private func daysSinceLastActivity(_ thread: Thread) -> Int {
        guard let lastActivity = thread.lastActivityAt else { return 999 }
        return Calendar.current.dateComponents([.day], from: lastActivity, to: Date()).day ?? 0
    }

    private func buildConnectionCardsFromPairs(_ pairs: [(noteAId: Int, noteBId: Int, similarity: Double)]) async -> [BriefingCard] {
        var cards: [BriefingCard] = []

        for pair in pairs.prefix(3) {
            do {
                guard let noteA = try await databaseService.getNoteById(pair.noteAId),
                      let noteB = try await databaseService.getNoteById(pair.noteBId) else { continue }

                let threadMapA = try await databaseService.getThreadAssignmentsForNotes([pair.noteAId])
                let threadMapB = try await databaseService.getThreadAssignmentsForNotes([pair.noteBId])

                let threadAName = threadMapA[pair.noteAId]?.threadName ?? "Unthreaded"
                let threadBName = threadMapB[pair.noteBId]?.threadName ?? "Unthreaded"

                // Try LLM explanation, fall back to concepts
                let explanation = await generateConnectionExplanation(noteA: noteA, noteB: noteB)

                cards.append(BriefingCard.connection(
                    noteATitle: noteA.title,
                    noteAId: noteA.id,
                    threadAName: threadAName,
                    noteBTitle: noteB.title,
                    noteBId: noteB.id,
                    threadBName: threadBName,
                    explanation: explanation
                ))
            } catch {
                continue
            }
        }

        return cards
    }

    private func generateConnectionExplanation(noteA: Note, noteB: Note) async -> String {
        let isAvailable = await ollamaService.isAvailable()
        guard isAvailable else {
            return fallbackConnectionExplanation(noteA: noteA, noteB: noteB)
        }

        let prompt = """
        You are analyzing two notes from different thinking threads. Explain in ONE sentence \
        what connects them conceptually. Be specific, not generic.

        Note A: "\(noteA.title)"
        \(String(noteA.content.prefix(300)))

        Note B: "\(noteB.title)"
        \(String(noteB.content.prefix(300)))

        Connection (one sentence):
        """

        do {
            let response = try await ollamaService.generate(prompt: prompt, model: "mistral:7b")
            let trimmed = response.trimmingCharacters(in: .whitespacesAndNewlines)
            // Take first sentence only
            if let firstSentence = trimmed.components(separatedBy: ".").first, !firstSentence.isEmpty {
                return firstSentence.trimmingCharacters(in: .whitespaces) + "."
            }
            return trimmed
        } catch {
            return fallbackConnectionExplanation(noteA: noteA, noteB: noteB)
        }
    }

    private func fallbackConnectionExplanation(noteA: Note, noteB: Note) -> String {
        let conceptsA = Set(noteA.concepts ?? [])
        let conceptsB = Set(noteB.concepts ?? [])
        let shared = conceptsA.intersection(conceptsB)

        if !shared.isEmpty {
            return "Shared concepts: \(shared.joined(separator: ", "))"
        }

        return "High semantic similarity"
    }

    private func generateIntro(changedCount: Int, attentionCount: Int, connectionCount: Int) async -> String {
        let isAvailable = await ollamaService.isAvailable()
        guard isAvailable else {
            return buildFallbackIntro(changedCount: changedCount, attentionCount: attentionCount, connectionCount: connectionCount)
        }

        let prompt = """
        Write a 1-2 sentence morning greeting for someone with ADHD opening their thinking app. \
        Be warm but concise. Here's what's happening:
        - \(changedCount) new notes captured
        - \(attentionCount) threads need attention
        - \(connectionCount) interesting connections found

        Keep it under 30 words. Don't use bullet points. Just a natural greeting.
        """

        do {
            let response = try await ollamaService.generate(prompt: prompt, model: "mistral:7b")
            return response.trimmingCharacters(in: .whitespacesAndNewlines)
        } catch {
            return buildFallbackIntro(changedCount: changedCount, attentionCount: attentionCount, connectionCount: connectionCount)
        }
    }
}
```

**Step 4: Run test to verify it passes**

Run: `cd SeleneChat && swift test --filter BriefingViewModelTests 2>&1 | tail -20`
Expected: PASS

**Step 5: Commit**

```bash
git add SeleneChat/Sources/ViewModels/BriefingViewModel.swift SeleneChat/Tests/SeleneChatTests/ViewModels/BriefingViewModelTests.swift
git commit -m "feat(briefing): rewrite BriefingViewModel with structured card data tracks"
```

---

## Task 5: BriefingCardView — Expandable Card Component

Build the reusable card view with collapsed/expanded states.

**Files:**
- Create: `SeleneChat/Sources/Views/BriefingCardView.swift`

**Step 1: Write the view**

Note: SwiftUI views are tested via integration and preview, not unit tests. Skip TDD for this step.

Create `SeleneChat/Sources/Views/BriefingCardView.swift`:

```swift
import SwiftUI

/// Expandable card for a single briefing insight
struct BriefingCardView: View {
    let card: BriefingCard
    let onDiscuss: (BriefingCard) -> Void

    @State private var isExpanded = false
    @EnvironmentObject var databaseService: DatabaseService

    // Loaded on expand
    @State private var notePreview: String?
    @State private var threadSummary: String?
    @State private var threadWhy: String?
    @State private var recentNoteTitles: [String] = []
    @State private var openTaskTitles: [String] = []

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Collapsed row (always visible)
            collapsedContent
                .contentShape(Rectangle())
                .onTapGesture {
                    withAnimation(.easeInOut(duration: 0.2)) {
                        isExpanded.toggle()
                    }
                    if isExpanded {
                        Task { await loadExpandedContent() }
                    }
                }

            // Expanded content
            if isExpanded {
                expandedContent
                    .transition(.opacity.combined(with: .move(edge: .top)))
            }
        }
        .padding(12)
        .background(Color(.controlBackgroundColor))
        .cornerRadius(10)
    }

    // MARK: - Collapsed Content

    @ViewBuilder
    private var collapsedContent: some View {
        switch card.cardType {
        case .whatChanged:
            HStack(spacing: 8) {
                Text(card.noteTitle ?? "")
                    .font(.body)
                    .fontWeight(.medium)
                    .lineLimit(1)

                if let threadName = card.threadName {
                    Text("·")
                        .foregroundColor(.secondary)
                    Text(threadName)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }

                Spacer()

                if let date = card.date {
                    Text(relativeDate(date))
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }

                if !card.energyEmoji.isEmpty {
                    Text(card.energyEmoji)
                        .font(.caption)
                }

                expandChevron
            }

        case .needsAttention:
            HStack(spacing: 8) {
                Text(card.threadName ?? "")
                    .font(.body)
                    .fontWeight(.medium)
                    .lineLimit(1)

                Spacer()

                Text(card.reason ?? "")
                    .font(.caption)
                    .foregroundColor(.orange)

                expandChevron
            }

        case .connection:
            HStack(spacing: 8) {
                Text(card.noteATitle ?? "")
                    .font(.caption)
                    .fontWeight(.medium)
                    .lineLimit(1)

                Image(systemName: "arrow.left.arrow.right")
                    .font(.caption2)
                    .foregroundColor(.secondary)

                Text(card.noteBTitle ?? "")
                    .font(.caption)
                    .fontWeight(.medium)
                    .lineLimit(1)

                Spacer()

                expandChevron
            }
        }
    }

    private var expandChevron: some View {
        Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
            .font(.caption2)
            .foregroundColor(.secondary)
    }

    // MARK: - Expanded Content

    @ViewBuilder
    private var expandedContent: some View {
        VStack(alignment: .leading, spacing: 12) {
            Divider()
                .padding(.vertical, 4)

            switch card.cardType {
            case .whatChanged:
                if let preview = notePreview {
                    Text(preview)
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .lineLimit(5)
                }

                if let concepts = conceptTags {
                    FlowLayout(spacing: 4) {
                        ForEach(concepts, id: \.self) { concept in
                            Text(concept)
                                .font(.caption2)
                                .padding(.horizontal, 6)
                                .padding(.vertical, 2)
                                .background(Color.accentColor.opacity(0.1))
                                .cornerRadius(4)
                        }
                    }
                }

                if let summary = threadSummary {
                    Text("Thread: \(summary)")
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .italic()
                }

            case .needsAttention:
                if let why = threadWhy {
                    Text("Why: \(why)")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }

                if let summary = threadSummary {
                    Text(summary)
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .lineLimit(3)
                }

                if !recentNoteTitles.isEmpty {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Recent notes:")
                            .font(.caption2)
                            .foregroundColor(.secondary)
                        ForEach(recentNoteTitles, id: \.self) { title in
                            Text("  \(title)")
                                .font(.caption)
                        }
                    }
                }

                if !openTaskTitles.isEmpty {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Open tasks:")
                            .font(.caption2)
                            .foregroundColor(.secondary)
                        ForEach(openTaskTitles, id: \.self) { title in
                            Text("  \(title)")
                                .font(.caption)
                        }
                    }
                }

            case .connection:
                if let explanation = card.explanation {
                    Text(explanation)
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .italic()
                }

                if let previewA = notePreview {
                    Text(previewA)
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .lineLimit(3)
                }
            }

            // Discuss button
            Button(action: { onDiscuss(card) }) {
                Label("Discuss this with Selene", systemImage: "message")
                    .font(.caption)
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.bordered)
            .controlSize(.small)
        }
    }

    // MARK: - Data Loading

    private func loadExpandedContent() async {
        switch card.cardType {
        case .whatChanged:
            if let noteId = card.noteId {
                if let note = try? await databaseService.getNoteById(noteId) {
                    notePreview = String(note.content.prefix(200))
                }
            }
            if let threadId = card.threadId {
                if let thread = try? await databaseService.getThreadById(threadId) {
                    threadSummary = thread.summary
                }
            }

        case .needsAttention:
            if let threadId = card.threadId {
                if let thread = try? await databaseService.getThreadById(threadId) {
                    threadSummary = thread.summary
                    threadWhy = thread.why
                }
                if let (_, notes) = try? await databaseService.getThreadByName(card.threadName ?? "") {
                    recentNoteTitles = notes.prefix(3).map { $0.title }
                }
                let tasks = (try? await databaseService.getTasksForThread(threadId)) ?? []
                openTaskTitles = tasks.filter { !$0.isCompleted }.prefix(5).map { $0.title ?? $0.thingsTaskId }
            }

        case .connection:
            if let noteId = card.noteAId {
                if let note = try? await databaseService.getNoteById(noteId) {
                    notePreview = String(note.content.prefix(200))
                }
            }
        }
    }

    private var conceptTags: [String]? {
        // Would need to load from note - for now return nil
        nil
    }

    private func relativeDate(_ date: Date) -> String {
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .abbreviated
        return formatter.localizedString(for: date, relativeTo: Date())
    }
}

/// Simple flow layout for concept tags
struct FlowLayout: Layout {
    var spacing: CGFloat = 4

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let result = layout(proposal: proposal, subviews: subviews)
        return result.size
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        let result = layout(proposal: proposal, subviews: subviews)
        for (index, position) in result.positions.enumerated() {
            subviews[index].place(at: CGPoint(x: bounds.minX + position.x, y: bounds.minY + position.y), proposal: .unspecified)
        }
    }

    private func layout(proposal: ProposedViewSize, subviews: Subviews) -> (size: CGSize, positions: [CGPoint]) {
        let maxWidth = proposal.width ?? .infinity
        var positions: [CGPoint] = []
        var x: CGFloat = 0
        var y: CGFloat = 0
        var rowHeight: CGFloat = 0

        for subview in subviews {
            let size = subview.sizeThatFits(.unspecified)
            if x + size.width > maxWidth && x > 0 {
                x = 0
                y += rowHeight + spacing
                rowHeight = 0
            }
            positions.append(CGPoint(x: x, y: y))
            rowHeight = max(rowHeight, size.height)
            x += size.width + spacing
        }

        return (CGSize(width: maxWidth, height: y + rowHeight), positions)
    }
}
```

**Step 2: Run build to verify it compiles**

Run: `cd SeleneChat && swift build 2>&1 | tail -20`
Expected: BUILD SUCCEEDED

**Step 3: Commit**

```bash
git add SeleneChat/Sources/Views/BriefingCardView.swift
git commit -m "feat(briefing): add BriefingCardView with expandable card interaction"
```

---

## Task 6: Rewrite BriefingView

Replace the single-paragraph view with structured sections and card layout.

**Files:**
- Modify: `SeleneChat/Sources/Views/BriefingView.swift`
- Modify: `SeleneChat/Sources/App/ContentView.swift` (update callback signature)

**Step 1: Rewrite BriefingView.swift**

Replace the full contents of `BriefingView.swift`:

```swift
import SwiftUI

struct BriefingView: View {
    @StateObject private var viewModel = BriefingViewModel()
    @EnvironmentObject var databaseService: DatabaseService

    var onDismiss: () -> Void
    var onDiscussCard: (BriefingCard) -> Void

    var body: some View {
        ZStack {
            Color(.windowBackgroundColor)
                .ignoresSafeArea()

            content
        }
        .onAppear {
            if case .notLoaded = viewModel.state.status {
                Task {
                    await viewModel.loadBriefing()
                }
            }
        }
    }

    @ViewBuilder
    private var content: some View {
        switch viewModel.state.status {
        case .notLoaded:
            EmptyView()

        case .loading:
            loadingView

        case .loaded(let briefing):
            loadedView(briefing)

        case .failed(let message):
            errorView(message)
        }
    }

    // MARK: - Loading State

    private var loadingView: some View {
        VStack(spacing: 16) {
            ProgressView()
                .scaleEffect(1.2)

            Text("Preparing your morning briefing...")
                .font(.headline)
                .foregroundColor(.secondary)
        }
    }

    // MARK: - Loaded State

    private func loadedView(_ briefing: StructuredBriefing) -> some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                // Intro
                Text(briefing.intro)
                    .font(.title3)
                    .padding(.top, 32)
                    .padding(.horizontal, 24)

                // What Changed section
                if !briefing.whatChanged.isEmpty {
                    briefingSection(
                        title: "What Changed",
                        icon: "doc.text",
                        cards: briefing.whatChanged
                    )
                }

                // Needs Attention section
                if !briefing.needsAttention.isEmpty {
                    briefingSection(
                        title: "Needs Attention",
                        icon: "exclamationmark.circle",
                        cards: briefing.needsAttention
                    )
                }

                // Connections section
                if !briefing.connections.isEmpty {
                    briefingSection(
                        title: "Connections",
                        icon: "arrow.triangle.branch",
                        cards: briefing.connections
                    )
                }

                // Empty state
                if briefing.isEmpty {
                    emptyState
                }

                // Done button at bottom
                HStack {
                    Spacer()
                    Button("Done") {
                        onDismiss()
                    }
                    .buttonStyle(.plain)
                    .foregroundColor(.secondary)
                    .padding(.bottom, 24)
                    Spacer()
                }
            }
            .frame(maxWidth: 550)
            .frame(maxWidth: .infinity)
        }
    }

    private func briefingSection(title: String, icon: String, cards: [BriefingCard]) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Label(title, systemImage: icon)
                .font(.headline)
                .foregroundColor(.secondary)
                .padding(.horizontal, 24)

            VStack(spacing: 6) {
                ForEach(cards) { card in
                    BriefingCardView(card: card, onDiscuss: { card in
                        onDiscussCard(card)
                    })
                    .environmentObject(databaseService)
                }
            }
            .padding(.horizontal, 16)
        }
    }

    private var emptyState: some View {
        VStack(spacing: 12) {
            Text("Nothing new since last time.")
                .font(.body)
                .foregroundColor(.secondary)

            Text("Want to start writing?")
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 32)
    }

    // MARK: - Error State

    private func errorView(_ message: String) -> some View {
        VStack(spacing: 16) {
            Spacer()

            Image(systemName: "exclamationmark.triangle")
                .font(.system(size: 48))
                .foregroundColor(.orange)

            Text("Couldn't generate briefing")
                .font(.headline)

            Text(message)
                .font(.caption)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .frame(maxWidth: 300)

            VStack(spacing: 12) {
                Button("Try Again") {
                    Task {
                        await viewModel.loadBriefing()
                    }
                }
                .buttonStyle(.borderedProminent)

                Button("Skip") {
                    onDismiss()
                }
                .buttonStyle(.plain)
                .foregroundColor(.secondary)
            }
            .padding(.top, 8)

            Spacer()
        }
        .padding()
    }
}
```

**Step 2: Update ContentView.swift**

In `ContentView.swift`, change the BriefingView integration to use the new callback:

Replace lines 41-51 (the `BriefingView` block):

```swift
            } else if showBriefing {
                BriefingView(
                    onDismiss: {
                        showBriefing = false
                    },
                    onDiscussCard: { card in
                        showBriefing = false
                        pendingBriefingCard = card
                        selectedView = .chat
                    }
                )
                .environmentObject(databaseService)
```

Add a new state variable near line 5-7:

```swift
    @State private var pendingBriefingCard: BriefingCard?
```

Update the ChatView call (around line 73):

```swift
                case .chat:
                    ChatView(initialQuery: pendingThreadQuery, briefingCard: pendingBriefingCard)
                        .onAppear {
                            pendingThreadQuery = nil
                            pendingBriefingCard = nil
                        }
```

**Step 3: Run build to verify it compiles**

Note: ChatView doesn't accept `briefingCard` yet — this will be fixed in Task 7. For now, verify the BriefingView and ContentView compile by checking for non-ChatView errors:

Run: `cd SeleneChat && swift build 2>&1 | tail -30`

If there are compile errors only about `ChatView(initialQuery:briefingCard:)`, that's expected and will be fixed in Task 7.

**Step 4: Commit**

```bash
git add SeleneChat/Sources/Views/BriefingView.swift SeleneChat/Sources/App/ContentView.swift
git commit -m "feat(briefing): rewrite BriefingView with structured sections and card layout"
```

---

## Task 7: ChatView Deep Context Integration

Wire up the "Discuss this" flow — ChatView accepts a BriefingCard, assembles deep context, and starts a context-aware conversation.

**Files:**
- Modify: `SeleneChat/Sources/Views/ChatView.swift` (add `briefingCard` parameter)
- Modify: `SeleneChat/Sources/Services/ChatViewModel.swift` (add `startBriefingDiscussion` method)
- Test: `SeleneChat/Tests/SeleneChatTests/Integration/BriefingChatIntegrationTests.swift` (create)

**Step 1: Write the failing test**

Create `SeleneChat/Tests/SeleneChatTests/Integration/BriefingChatIntegrationTests.swift`:

```swift
import XCTest
@testable import SeleneChat

final class BriefingChatIntegrationTests: XCTestCase {

    func testBriefingContextBuilderProducesValidContext() {
        let builder = BriefingContextBuilder()
        let note = Note.mock(id: 1, title: "Test Note", content: "Some interesting content about focus", concepts: ["focus", "productivity"])
        let thread = Thread.mock(id: 5, name: "Focus Systems", summary: "Strategies for deep work", why: "Need better concentration")

        let context = builder.buildWhatChangedContext(
            note: note,
            thread: thread,
            relatedNotes: [Note.mock(id: 2, title: "Related")],
            tasks: [ThreadTask.mock(id: 1, threadId: 5, title: "Review notes")],
            memories: []
        )

        // Context should include all provided data
        XCTAssertTrue(context.contains("Test Note"))
        XCTAssertTrue(context.contains("Some interesting content"))
        XCTAssertTrue(context.contains("Focus Systems"))
        XCTAssertTrue(context.contains("Strategies for deep work"))
        XCTAssertTrue(context.contains("Related"))
        XCTAssertTrue(context.contains("Review notes"))
        XCTAssertTrue(context.contains("focus"))
    }

    func testSystemPromptForWhatChanged() {
        let builder = BriefingContextBuilder()
        let prompt = builder.buildSystemPrompt(for: .whatChanged)

        XCTAssertTrue(prompt.contains("Selene"))
        XCTAssertTrue(prompt.contains("morning briefing"))
        XCTAssertTrue(prompt.contains("Don't summarize"))
        XCTAssertTrue(prompt.contains("specific"))
    }

    func testSystemPromptForNeedsAttention() {
        let builder = BriefingContextBuilder()
        let prompt = builder.buildSystemPrompt(for: .needsAttention)

        XCTAssertTrue(prompt.contains("stalled"))
    }

    func testSystemPromptForConnection() {
        let builder = BriefingContextBuilder()
        let prompt = builder.buildSystemPrompt(for: .connection)

        XCTAssertTrue(prompt.contains("connection"))
    }

    func testNeedsAttentionContextIncludesStallInfo() {
        let builder = BriefingContextBuilder()
        let thread = Thread.mock(id: 5, name: "Stalled Thread", why: "Important reason", summary: "Thread summary here")
        let notes = [Note.mock(id: 1, title: "Last Note")]
        let tasks = [ThreadTask.mock(id: 1, threadId: 5, title: "Open Task")]

        let context = builder.buildNeedsAttentionContext(thread: thread, recentNotes: notes, tasks: tasks, memories: [])

        XCTAssertTrue(context.contains("Stalled Thread"))
        XCTAssertTrue(context.contains("Important reason"))
        XCTAssertTrue(context.contains("Last Note"))
        XCTAssertTrue(context.contains("Open Task"))
    }

    func testConnectionContextIncludesBothThreads() {
        let builder = BriefingContextBuilder()
        let noteA = Note.mock(id: 1, title: "Note A", content: "Content A")
        let noteB = Note.mock(id: 2, title: "Note B", content: "Content B")
        let threadA = Thread.mock(id: 5, name: "Thread A")
        let threadB = Thread.mock(id: 8, name: "Thread B")

        let context = builder.buildConnectionContext(
            noteA: noteA, threadA: threadA,
            noteB: noteB, threadB: threadB,
            relatedToA: [], relatedToB: [],
            tasks: [], memories: []
        )

        XCTAssertTrue(context.contains("Note A"))
        XCTAssertTrue(context.contains("Note B"))
        XCTAssertTrue(context.contains("Thread A"))
        XCTAssertTrue(context.contains("Thread B"))
    }
}
```

**Step 2: Run test to verify it passes** (context builder already exists from Task 3)

Run: `cd SeleneChat && swift test --filter BriefingChatIntegrationTests 2>&1 | tail -20`
Expected: PASS

**Step 3: Add briefingCard to ChatView**

In `ChatView.swift`, add property near line 13:

```swift
    var briefingCard: BriefingCard?
```

Add to the `.onAppear` block (after the existing `initialQuery` handling, around line 89):

```swift
            // Handle briefing card discussion
            if let card = briefingCard {
                Task {
                    await chatViewModel.startBriefingDiscussion(card: card)
                }
            }
```

**Step 4: Add startBriefingDiscussion to ChatViewModel**

In `ChatViewModel.swift`, add method:

```swift
    /// Start a discussion from a briefing card with deep context pre-loaded
    func startBriefingDiscussion(card: BriefingCard) async {
        isProcessing = true
        defer { isProcessing = false }

        let contextBuilder = BriefingContextBuilder()
        let db = DatabaseService.shared

        do {
            let context: String
            let contextType: BriefingContextBuilder.ContextType

            switch card.cardType {
            case .whatChanged:
                contextType = .whatChanged
                let note = card.noteId.flatMap { try? await db.getNoteById($0) } ?? nil
                let thread: Thread? = card.threadId.flatMap { try? await db.getThreadById($0) } ?? nil
                let related = note != nil ? (await db.getRelatedNotes(for: note!.id)).map { $0.note } : []
                let tasks = card.threadId.flatMap { try? await db.getTasksForThread($0) } ?? []
                let memories = (try? await db.getAllMemories(limit: 10)) ?? []

                context = contextBuilder.buildWhatChangedContext(
                    note: note ?? Note.mock(title: card.noteTitle ?? "Unknown"),
                    thread: thread,
                    relatedNotes: related,
                    tasks: tasks,
                    memories: memories
                )

            case .needsAttention:
                contextType = .needsAttention
                let thread = card.threadId.flatMap { try? await db.getThreadById($0) } ?? Thread.mock(name: card.threadName ?? "Unknown")
                let threadNotes: [Note]
                if let name = card.threadName, let result = try? await db.getThreadByName(name) {
                    threadNotes = result.1
                } else {
                    threadNotes = []
                }
                let tasks = card.threadId.flatMap { try? await db.getTasksForThread($0) } ?? []
                let memories = (try? await db.getAllMemories(limit: 10)) ?? []

                context = contextBuilder.buildNeedsAttentionContext(
                    thread: thread,
                    recentNotes: Array(threadNotes.prefix(3)),
                    tasks: tasks,
                    memories: memories
                )

            case .connection:
                contextType = .connection
                let noteA = card.noteAId.flatMap { try? await db.getNoteById($0) } ?? nil
                let noteB = card.noteBId.flatMap { try? await db.getNoteById($0) } ?? nil

                // Get threads for both notes
                let threadMapA = card.noteAId.flatMap { try? await db.getThreadAssignmentsForNotes([$0]) } ?? [:]
                let threadMapB = card.noteBId.flatMap { try? await db.getThreadAssignmentsForNotes([$0]) } ?? [:]

                let threadA: Thread?
                if let threadId = threadMapA.values.first?.threadId {
                    threadA = try? await db.getThreadById(threadId)
                } else { threadA = nil }

                let threadB: Thread?
                if let threadId = threadMapB.values.first?.threadId {
                    threadB = try? await db.getThreadById(threadId)
                } else { threadB = nil }

                let relatedA = noteA != nil ? (await db.getRelatedNotes(for: noteA!.id)).map { $0.note } : []
                let relatedB = noteB != nil ? (await db.getRelatedNotes(for: noteB!.id)).map { $0.note } : []
                let tasks = (try? await db.getTasksForThread(threadA?.id ?? 0)) ?? [] + ((try? await db.getTasksForThread(threadB?.id ?? 0)) ?? [])
                let memories = (try? await db.getAllMemories(limit: 10)) ?? []

                context = contextBuilder.buildConnectionContext(
                    noteA: noteA ?? Note.mock(title: card.noteATitle ?? "Unknown"),
                    threadA: threadA,
                    noteB: noteB ?? Note.mock(title: card.noteBTitle ?? "Unknown"),
                    threadB: threadB,
                    relatedToA: relatedA,
                    relatedToB: relatedB,
                    tasks: tasks,
                    memories: memories
                )
            }

            let systemPrompt = contextBuilder.buildSystemPrompt(for: contextType)

            let fullPrompt = """
            \(systemPrompt)

            \(context)
            """

            let response = try await OllamaService.shared.generate(prompt: fullPrompt, model: "mistral:7b")

            // Add the assistant's opening message
            let assistantMessage = Message(
                role: .assistant,
                content: response,
                timestamp: Date(),
                llmTier: .local
            )
            currentSession.addMessage(assistantMessage)

            await saveSession()

        } catch {
            self.error = "Couldn't start discussion: \(error.localizedDescription)"
        }
    }
```

**Step 5: Run build to verify it compiles**

Run: `cd SeleneChat && swift build 2>&1 | tail -30`
Expected: BUILD SUCCEEDED

**Step 6: Commit**

```bash
git add SeleneChat/Sources/Views/ChatView.swift SeleneChat/Sources/Services/ChatViewModel.swift SeleneChat/Tests/SeleneChatTests/Integration/BriefingChatIntegrationTests.swift
git commit -m "feat(briefing): wire up deep context chat from briefing cards"
```

---

## Task 8: Update Existing Tests

Update old briefing tests that reference the removed `Briefing` struct and old methods.

**Files:**
- Modify: `SeleneChat/Tests/SeleneChatTests/Services/BriefingGeneratorTests.swift`
- Modify: `SeleneChat/Tests/SeleneChatTests/Integration/BriefingIntegrationTests.swift`

**Step 1: Update BriefingGeneratorTests**

The `BriefingGenerator` class is no longer needed (replaced by `BriefingDataService` + `BriefingContextBuilder`). Update tests to test the new code instead. If `BriefingGenerator` is still referenced elsewhere, keep it but update. Otherwise, delete the file and repurpose the test file:

Check: `cd SeleneChat && grep -r "BriefingGenerator" Sources/ --include="*.swift" -l`

If only `BriefingGenerator.swift` references itself, delete it and redirect tests to `BriefingDataService` and `BriefingContextBuilder`.

If it's still referenced, update the tests to work with the new `StructuredBriefing` type.

**Step 2: Update BriefingIntegrationTests**

Update integration tests to test the new end-to-end flow: data queries → card building → context assembly. Remove references to old `Briefing` struct and `parseBriefingResponse`.

**Step 3: Run all briefing tests**

Run: `cd SeleneChat && swift test --filter Briefing 2>&1 | tail -30`
Expected: ALL PASS

**Step 4: Run full test suite**

Run: `cd SeleneChat && swift test 2>&1 | tail -30`
Expected: ALL PASS

**Step 5: Commit**

```bash
git add SeleneChat/Tests/
git commit -m "test(briefing): update tests for structured briefing redesign"
```

---

## Task 9: Clean Up Old Code

Remove the old `BriefingGenerator.swift` (if no longer needed) and clean up unused references.

**Files:**
- Delete (if unused): `SeleneChat/Sources/Services/BriefingGenerator.swift`
- Modify: `SeleneChat/Sources/Services/ThinkingPartnerContextBuilder.swift` (keep — still used by synthesis/deep-dive)

**Step 1: Check for remaining references**

Run: `cd SeleneChat && grep -r "BriefingGenerator\|old Briefing struct\|digIn\|showSomethingElse" Sources/ --include="*.swift"`

**Step 2: Delete unreferenced files**

If `BriefingGenerator` is not referenced by any other file in `Sources/`, delete it.

**Step 3: Run full test suite**

Run: `cd SeleneChat && swift test 2>&1 | tail -30`
Expected: ALL PASS

**Step 4: Commit**

```bash
git add -A SeleneChat/
git commit -m "refactor(briefing): remove old BriefingGenerator and unused code"
```

---

## Task 10: Integration Verification

End-to-end verification that the full flow works.

**Step 1: Build the app**

Run: `cd SeleneChat && swift build 2>&1 | tail -10`
Expected: BUILD SUCCEEDED

**Step 2: Run full test suite**

Run: `cd SeleneChat && swift test 2>&1 | tail -30`
Expected: ALL PASS, no regressions

**Step 3: Verify no compile warnings about unused code**

Run: `cd SeleneChat && swift build 2>&1 | grep -i warning | head -10`

**Step 4: Build the .app bundle**

Run: `cd SeleneChat && ./build-app.sh 2>&1 | tail -10`
Expected: BUILD SUCCEEDED

**Step 5: Commit**

If any fixes were needed, commit them:

```bash
git add -A SeleneChat/
git commit -m "fix(briefing): resolve build issues from integration verification"
```

---

## Summary

| Task | What | Test? | Files |
|------|------|-------|-------|
| 1 | BriefingState model with card types | Yes | BriefingState.swift |
| 2 | DB queries for briefing data | Yes | DatabaseService.swift, BriefingDataService.swift |
| 3 | BriefingContextBuilder for deep context | Yes | BriefingContextBuilder.swift |
| 4 | Rewrite BriefingViewModel | Yes | BriefingViewModel.swift |
| 5 | BriefingCardView expandable card | Build | BriefingCardView.swift |
| 6 | Rewrite BriefingView | Build | BriefingView.swift, ContentView.swift |
| 7 | ChatView deep context integration | Yes | ChatView.swift, ChatViewModel.swift |
| 8 | Update existing tests | Yes | Test files |
| 9 | Clean up old code | Yes | BriefingGenerator.swift |
| 10 | Integration verification | Build + Test | All |
