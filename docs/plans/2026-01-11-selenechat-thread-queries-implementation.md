# SeleneChat Thread Queries Implementation Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** Add "what's emerging" and "show me [thread]" queries to SeleneChat for browsing semantic threads.

**Architecture:** Extend QueryAnalyzer with `.thread` query type, add Thread model and database methods, intercept thread queries in ChatViewModel to format responses directly (bypassing Ollama for speed).

**Tech Stack:** Swift 5.9+, SQLite.swift, SwiftUI

---

## Task 1: Add Thread Model

**Files:**
- Create: `SeleneChat/Sources/Models/Thread.swift`

**Step 1: Create the Thread model file**

```swift
import Foundation

struct Thread: Identifiable, Hashable {
    let id: Int64
    let name: String
    let why: String?
    let summary: String?
    let status: String
    let noteCount: Int
    let momentumScore: Double?
    let lastActivityAt: Date?
    let createdAt: Date

    var momentumDisplay: String {
        guard let score = momentumScore else { return "—" }
        return String(format: "%.1f", score)
    }

    var lastActivityDisplay: String {
        guard let date = lastActivityAt else { return "No activity" }
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .abbreviated
        return formatter.localizedString(for: date, relativeTo: Date())
    }

    var statusEmoji: String {
        switch status {
        case "active": return "🔥"
        case "paused": return "⏸️"
        case "completed": return "✅"
        case "abandoned": return "💤"
        default: return "📌"
        }
    }
}
```

**Step 2: Verify it compiles**

Run: `cd SeleneChat && swift build 2>&1 | head -20`
Expected: Build succeeds or shows unrelated warnings

**Step 3: Commit**

```bash
git add SeleneChat/Sources/Models/Thread.swift
git commit -m "feat(selenechat): add Thread model for semantic threads"
```

---

## Task 2: Add ThreadQueryIntent to QueryAnalyzer

**Files:**
- Modify: `SeleneChat/Sources/Services/QueryAnalyzer.swift`

**Step 1: Add thread query type and intent enum**

Add after existing `QueryType` enum (around line 8):

```swift
enum QueryType {
    case pattern
    case search
    case knowledge
    case general
    case thread      // NEW
}

// NEW: Add after QueryType enum
enum ThreadQueryIntent {
    case listActive           // "what's emerging"
    case showSpecific(String) // "show me X thread"
}
```

**Step 2: Add thread indicators**

Add after `knowledgeIndicators` (around line 44):

```swift
private let threadListIndicators = [
    "what's emerging", "whats emerging", "emerging threads",
    "active threads", "my threads", "show threads",
    "what threads", "thread overview"
]

private let threadShowIndicators = [
    "show me", "tell me about", "what's the", "whats the",
    "details on", "more about"
]
```

**Step 3: Add thread detection method**

Add after `detectTimeScope` method (around line 147):

```swift
/// Detect if query is thread-related and extract intent
func detectThreadIntent(_ query: String) -> ThreadQueryIntent? {
    let lowercased = query.lowercased()

    // Check for list queries first
    for indicator in threadListIndicators {
        if lowercased.contains(indicator) {
            return .listActive
        }
    }

    // Check for specific thread queries
    // Pattern: "show me X thread" or "X thread"
    if lowercased.contains("thread") {
        // Try to extract thread name
        if let name = extractThreadName(from: lowercased) {
            return .showSpecific(name)
        }
    }

    return nil
}

private func extractThreadName(from query: String) -> String? {
    // Pattern 1: "show me [name] thread"
    let showPattern = #"(?:show me|tell me about|what's the|whats the|details on|more about)\s+(?:the\s+)?(.+?)\s+thread"#
    if let regex = try? NSRegularExpression(pattern: showPattern, options: .caseInsensitive),
       let match = regex.firstMatch(in: query, range: NSRange(query.startIndex..., in: query)),
       let range = Range(match.range(at: 1), in: query) {
        return String(query[range]).trimmingCharacters(in: .whitespaces)
    }

    // Pattern 2: "[name] thread" at end of query
    let endPattern = #"(.+?)\s+thread\s*$"#
    if let regex = try? NSRegularExpression(pattern: endPattern, options: .caseInsensitive),
       let match = regex.firstMatch(in: query, range: NSRange(query.startIndex..., in: query)),
       let range = Range(match.range(at: 1), in: query) {
        let name = String(query[range]).trimmingCharacters(in: .whitespaces)
        // Filter out common false positives
        let falsePositives = ["the", "a", "my", "this", "that", "any"]
        if !falsePositives.contains(name.lowercased()) {
            return name
        }
    }

    return nil
}
```

**Step 4: Update detectQueryType to include thread**

Modify `detectQueryType` method to check threads first:

```swift
private func detectQueryType(_ query: String) -> QueryType {
    // Check thread queries first (most specific)
    if detectThreadIntent(query) != nil {
        return .thread
    }

    // Check pattern indicators
    for indicator in patternIndicators {
        // ... rest unchanged
```

**Step 5: Verify it compiles**

Run: `cd SeleneChat && swift build 2>&1 | head -20`
Expected: Build succeeds

**Step 6: Commit**

```bash
git add SeleneChat/Sources/Services/QueryAnalyzer.swift
git commit -m "feat(selenechat): add thread query detection to QueryAnalyzer"
```

---

## Task 3: Add Thread Database Methods

**Files:**
- Modify: `SeleneChat/Sources/Services/DatabaseService.swift`

**Step 1: Add threads table reference and columns**

Add after existing table/column definitions (around line 97):

```swift
// threads table
private let threadsTable = Table("threads")
private let threadIdCol = Expression<Int64>("id")
private let threadName = Expression<String>("name")
private let threadWhy = Expression<String?>("why")
private let threadSummary = Expression<String?>("summary")
private let threadStatus = Expression<String>("status")
private let threadNoteCount = Expression<Int64>("note_count")
private let threadMomentumScore = Expression<Double?>("momentum_score")
private let threadLastActivityAt = Expression<String?>("last_activity_at")
private let threadCreatedAt = Expression<String>("created_at")

// thread_notes table
private let threadNotesTable = Table("thread_notes")
private let threadNoteThreadId = Expression<Int64>("thread_id")
private let threadNoteRawNoteId = Expression<Int64>("raw_note_id")
```

**Step 2: Add getActiveThreads method**

Add after existing query methods:

```swift
/// Get active threads sorted by momentum
func getActiveThreads(limit: Int = 10) async throws -> [Thread] {
    guard let db = db else {
        throw DatabaseError.notConnected
    }

    let query = threadsTable
        .filter(threadStatus == "active")
        .order(threadMomentumScore.desc)
        .limit(limit)

    var threads: [Thread] = []

    for row in try db.prepare(query) {
        let thread = Thread(
            id: row[threadIdCol],
            name: row[threadName],
            why: row[threadWhy],
            summary: row[threadSummary],
            status: row[threadStatus],
            noteCount: Int(row[threadNoteCount]),
            momentumScore: row[threadMomentumScore],
            lastActivityAt: parseDate(row[threadLastActivityAt]),
            createdAt: parseDate(row[threadCreatedAt]) ?? Date()
        )
        threads.append(thread)
    }

    return threads
}

/// Get thread by fuzzy name match with its linked notes
func getThreadByName(_ name: String) async throws -> (Thread, [Note])? {
    guard let db = db else {
        throw DatabaseError.notConnected
    }

    // Find thread by fuzzy name match
    let threadQuery = threadsTable
        .filter(threadName.like("%\(name)%"))
        .filter(threadStatus == "active")
        .limit(1)

    guard let row = try db.pluck(threadQuery) else {
        return nil
    }

    let thread = Thread(
        id: row[threadIdCol],
        name: row[threadName],
        why: row[threadWhy],
        summary: row[threadSummary],
        status: row[threadStatus],
        noteCount: Int(row[threadNoteCount]),
        momentumScore: row[threadMomentumScore],
        lastActivityAt: parseDate(row[threadLastActivityAt]),
        createdAt: parseDate(row[threadCreatedAt]) ?? Date()
    )

    // Get linked notes
    let notesQuery = rawNotes
        .join(.inner, threadNotesTable, on: rawNotes[id] == threadNotesTable[threadNoteRawNoteId])
        .join(.leftOuter, processedNotes, on: rawNotes[id] == processedNotes[rawNoteId])
        .filter(threadNotesTable[threadNoteThreadId] == thread.id)
        .order(rawNotes[createdAt].desc)

    var notes: [Note] = []
    for noteRow in try db.prepare(notesQuery) {
        let note = try parseNote(from: noteRow)
        notes.append(note)
    }

    return (thread, notes)
}

private func parseDate(_ dateString: String?) -> Date? {
    guard let dateString = dateString else { return nil }
    let formatter = ISO8601DateFormatter()
    formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
    if let date = formatter.date(from: dateString) {
        return date
    }
    // Try without fractional seconds
    formatter.formatOptions = [.withInternetDateTime]
    return formatter.date(from: dateString)
}
```

**Step 3: Verify it compiles**

Run: `cd SeleneChat && swift build 2>&1 | head -20`
Expected: Build succeeds

**Step 4: Commit**

```bash
git add SeleneChat/Sources/Services/DatabaseService.swift
git commit -m "feat(selenechat): add thread database queries"
```

---

## Task 4: Handle Thread Queries in ChatViewModel

**Files:**
- Modify: `SeleneChat/Sources/Services/ChatViewModel.swift`

**Step 1: Add thread query handling method**

Add after `handleOllamaQuery` method:

```swift
/// Handle thread queries directly without LLM
private func handleThreadQuery(intent: ThreadQueryIntent) async throws -> String {
    switch intent {
    case .listActive:
        return try await formatActiveThreads()
    case .showSpecific(let name):
        return try await formatThreadDetails(name: name)
    }
}

private func formatActiveThreads() async throws -> String {
    let threads = try await databaseService.getActiveThreads(limit: 10)

    guard !threads.isEmpty else {
        return """
        No active threads yet.

        Threads emerge when 3+ related notes cluster together based on semantic similarity. Keep capturing notes and threads will form automatically!
        """
    }

    var response = "📊 **Active Threads** (by momentum)\n\n"

    for (index, thread) in threads.enumerated() {
        let momentum = thread.momentumDisplay
        let noteCount = thread.noteCount
        let lastActivity = thread.lastActivityDisplay
        let summary = thread.summary ?? "No summary yet"

        response += "\(index + 1). **\(thread.name)** (momentum: \(momentum))\n"
        response += "   → \(noteCount) notes | Last activity: \(lastActivity)\n"
        response += "   \"\(summary.prefix(100))\(summary.count > 100 ? "..." : "")\"\n\n"
    }

    response += "_Ask \"show me [thread name] thread\" for details._"

    return response
}

private func formatThreadDetails(name: String) async throws -> String {
    guard let (thread, notes) = try await databaseService.getThreadByName(name) else {
        return """
        I couldn't find a thread matching "\(name)".

        Try "what's emerging" to see your active threads.
        """
    }

    var response = "🧵 **\(thread.name)**\n\n"

    if let why = thread.why, !why.isEmpty {
        response += "**Why:** \(why)\n\n"
    }

    if let summary = thread.summary, !summary.isEmpty {
        response += "**Summary:** \(summary)\n\n"
    }

    response += "**Status:** \(thread.status) \(thread.statusEmoji)\n"
    response += "**Momentum:** \(thread.momentumDisplay)\n"
    response += "**Last Activity:** \(thread.lastActivityDisplay)\n\n"

    response += "---\n\n"
    response += "**Linked Notes (\(notes.count)):**\n\n"

    for (index, note) in notes.prefix(10).enumerated() {
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "MMM d"
        let dateStr = dateFormatter.string(from: note.createdAt)

        response += "• [\(index + 1)] \"\(note.title)\" - \(dateStr)\n"
    }

    if notes.count > 10 {
        response += "\n_...and \(notes.count - 10) more notes_"
    }

    return response
}
```

**Step 2: Modify sendMessage to intercept thread queries**

Update `sendMessage` method to check for thread queries early. Add after the user message is added (around line 36):

```swift
func sendMessage(_ content: String) async {
    isProcessing = true
    defer { isProcessing = false }

    // Add user message
    let userMessage = Message(
        role: .user,
        content: content,
        llmTier: .onDevice
    )
    currentSession.addMessage(userMessage)

    do {
        // NEW: Check for thread queries first (bypass LLM for speed)
        if let threadIntent = queryAnalyzer.detectThreadIntent(content) {
            let response = try await handleThreadQuery(intent: threadIntent)
            let assistantMessage = Message(
                role: .assistant,
                content: response,
                llmTier: .onDevice,  // Thread queries are local
                queryType: "thread"
            )
            currentSession.addMessage(assistantMessage)
            await saveSession()
            return
        }

        // Determine routing (existing code continues...)
        let relatedNotes = try await findRelatedNotes(for: content)
        // ... rest unchanged
```

**Step 3: Verify it compiles**

Run: `cd SeleneChat && swift build 2>&1 | head -20`
Expected: Build succeeds

**Step 4: Commit**

```bash
git add SeleneChat/Sources/Services/ChatViewModel.swift
git commit -m "feat(selenechat): handle thread queries in ChatViewModel"
```

---

## Task 5: Test Thread Queries

**Step 1: Build the app**

Run: `cd SeleneChat && swift build -c release`
Expected: Build succeeds

**Step 2: Run the app and test queries**

Run: `cd SeleneChat && swift run`

Test these queries in the chat:
1. Type: "what's emerging"
   Expected: See list of active threads with momentum scores

2. Type: "show me event thread"
   Expected: See thread details for "Event-Driven Architecture Testing"

**Step 3: Commit final changes if any fixes needed**

```bash
git add -A
git commit -m "feat(selenechat): complete thread query support

- Add Thread model
- Add thread detection to QueryAnalyzer
- Add getActiveThreads/getThreadByName to DatabaseService
- Handle thread queries in ChatViewModel (bypasses LLM)"
```

---

## Summary

| Task | Files | Description |
|------|-------|-------------|
| 1 | Thread.swift (new) | Thread model with display helpers |
| 2 | QueryAnalyzer.swift | Add .thread type, ThreadQueryIntent, detection |
| 3 | DatabaseService.swift | Add getActiveThreads, getThreadByName |
| 4 | ChatViewModel.swift | Intercept thread queries, format responses |
| 5 | — | Build and test |

**Total: 5 tasks, ~4 files changed**
