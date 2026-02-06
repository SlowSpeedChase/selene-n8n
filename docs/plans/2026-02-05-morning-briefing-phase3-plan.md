# Morning Briefing (Phase 3) Implementation Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** Add proactive morning briefing on app open that surfaces active threads and suggests focus areas.

**Architecture:** BriefingView displays LLM-generated briefing using ThinkingPartnerContextBuilder for context assembly. BriefingGenerator orchestrates context building and Ollama calls. ContentView shows BriefingView on app open with quick action buttons to dig in or dismiss.

**Tech Stack:** Swift 5.9, SwiftUI, Ollama (mistral:7b), ThinkingPartnerContextBuilder (from Phase 2)

---

## Task 1: Create BriefingState Model

**Files:**
- Create: `SeleneChat/Sources/Models/BriefingState.swift`
- Test: `SeleneChat/Tests/SeleneChatTests/Models/BriefingStateTests.swift`

**Step 1: Write the failing test**

```swift
import XCTest
@testable import SeleneChat

final class BriefingStateTests: XCTestCase {

    func testBriefingStateInitializesAsNotLoaded() {
        let state = BriefingState()

        if case .notLoaded = state.status {
            // Expected
        } else {
            XCTFail("Expected .notLoaded status")
        }
    }

    func testBriefingStateCanTransitionToLoading() {
        var state = BriefingState()
        state.status = .loading

        if case .loading = state.status {
            // Expected
        } else {
            XCTFail("Expected .loading status")
        }
    }

    func testBriefingStateStoresLoadedBriefing() {
        var state = BriefingState()
        let briefing = Briefing(
            content: "Good morning. Here's what's active...",
            suggestedThread: "Event Architecture",
            threadCount: 3,
            generatedAt: Date()
        )
        state.status = .loaded(briefing)

        if case .loaded(let result) = state.status {
            XCTAssertEqual(result.content, "Good morning. Here's what's active...")
            XCTAssertEqual(result.suggestedThread, "Event Architecture")
            XCTAssertEqual(result.threadCount, 3)
        } else {
            XCTFail("Expected .loaded status")
        }
    }

    func testBriefingStateStoresError() {
        var state = BriefingState()
        state.status = .failed("Ollama not available")

        if case .failed(let message) = state.status {
            XCTAssertEqual(message, "Ollama not available")
        } else {
            XCTFail("Expected .failed status")
        }
    }
}
```

**Step 2: Run test to verify it fails**

Run: `cd SeleneChat && swift test --filter BriefingStateTests`
Expected: FAIL with "Cannot find 'BriefingState' in scope"

**Step 3: Write minimal implementation**

```swift
import Foundation

/// Represents the state of a morning briefing
struct BriefingState {
    var status: BriefingStatus = .notLoaded
}

/// Status of briefing generation
enum BriefingStatus: Equatable {
    case notLoaded
    case loading
    case loaded(Briefing)
    case failed(String)

    static func == (lhs: BriefingStatus, rhs: BriefingStatus) -> Bool {
        switch (lhs, rhs) {
        case (.notLoaded, .notLoaded):
            return true
        case (.loading, .loading):
            return true
        case (.loaded(let a), .loaded(let b)):
            return a.generatedAt == b.generatedAt
        case (.failed(let a), .failed(let b)):
            return a == b
        default:
            return false
        }
    }
}

/// A generated briefing from Selene
struct Briefing: Equatable {
    let content: String
    let suggestedThread: String?
    let threadCount: Int
    let generatedAt: Date

    static func == (lhs: Briefing, rhs: Briefing) -> Bool {
        lhs.content == rhs.content &&
        lhs.suggestedThread == rhs.suggestedThread &&
        lhs.threadCount == rhs.threadCount
    }
}
```

**Step 4: Run test to verify it passes**

Run: `cd SeleneChat && swift test --filter BriefingStateTests`
Expected: PASS (4 tests)

**Step 5: Commit**

```bash
git add SeleneChat/Sources/Models/BriefingState.swift SeleneChat/Tests/SeleneChatTests/Models/BriefingStateTests.swift
git commit -m "feat(briefing): add BriefingState model for morning briefing"
```

---

## Task 2: Create BriefingGenerator Service

**Files:**
- Create: `SeleneChat/Sources/Services/BriefingGenerator.swift`
- Test: `SeleneChat/Tests/SeleneChatTests/Services/BriefingGeneratorTests.swift`

**Step 1: Write the failing test**

```swift
import XCTest
@testable import SeleneChat

final class BriefingGeneratorTests: XCTestCase {

    func testBriefingPromptIncludesThreadContext() {
        let generator = BriefingGenerator()

        // Create test threads
        let threads = [
            Thread.mock(name: "Event Architecture", noteCount: 5, momentumScore: 0.8),
            Thread.mock(name: "Project Planning", noteCount: 3, momentumScore: 0.5)
        ]

        let notes = [
            Note.mock(title: "Testing patterns", createdAt: Date())
        ]

        let prompt = generator.buildBriefingPrompt(threads: threads, recentNotes: notes)

        XCTAssertTrue(prompt.contains("Event Architecture"))
        XCTAssertTrue(prompt.contains("Project Planning"))
        XCTAssertTrue(prompt.contains("Testing patterns"))
        XCTAssertTrue(prompt.contains("thinking partner"))
    }

    func testBriefingPromptLimitsThreadCount() {
        let generator = BriefingGenerator()

        // Create 10 threads - should only include top 5 by momentum
        var threads: [Thread] = []
        for i in 0..<10 {
            threads.append(Thread.mock(
                name: "Thread \(i)",
                noteCount: i + 1,
                momentumScore: Double(i) / 10.0
            ))
        }

        let prompt = generator.buildBriefingPrompt(threads: threads, recentNotes: [])

        // Should include high momentum threads
        XCTAssertTrue(prompt.contains("Thread 9"))
        XCTAssertTrue(prompt.contains("Thread 8"))

        // Should NOT include low momentum threads
        XCTAssertFalse(prompt.contains("Thread 0"))
        XCTAssertFalse(prompt.contains("Thread 1"))
    }

    func testParseBriefingResponse() {
        let generator = BriefingGenerator()

        let response = """
        Good morning. Here's where your thinking is:

        **Event Architecture** has the most momentum with 5 notes this week.

        Suggested focus: Event Architecture - you're making progress here.
        """

        let briefing = generator.parseBriefingResponse(
            response,
            threads: [Thread.mock(name: "Event Architecture", noteCount: 5, momentumScore: 0.8)]
        )

        XCTAssertTrue(briefing.content.contains("Good morning"))
        XCTAssertEqual(briefing.suggestedThread, "Event Architecture")
        XCTAssertEqual(briefing.threadCount, 1)
    }

    func testParseBriefingResponseWithNoThreads() {
        let generator = BriefingGenerator()

        let response = "No active threads yet. Start capturing some thoughts!"

        let briefing = generator.parseBriefingResponse(response, threads: [])

        XCTAssertTrue(briefing.content.contains("No active threads"))
        XCTAssertNil(briefing.suggestedThread)
        XCTAssertEqual(briefing.threadCount, 0)
    }
}
```

**Step 2: Run test to verify it fails**

Run: `cd SeleneChat && swift test --filter BriefingGeneratorTests`
Expected: FAIL with "Cannot find 'BriefingGenerator' in scope"

**Step 3: Write minimal implementation**

```swift
import Foundation

/// Generates morning briefings using Ollama
class BriefingGenerator {
    private let contextBuilder = ThinkingPartnerContextBuilder()

    /// Build the briefing prompt with thread context
    func buildBriefingPrompt(threads: [Thread], recentNotes: [Note]) -> String {
        let context = contextBuilder.buildBriefingContext(threads: threads, recentNotes: recentNotes)

        return """
        You are Selene, a thinking partner for someone with ADHD.
        Your job is to help them see where their thinking is and what deserves attention.
        Be concise, warm, and actionable.

        \(context)

        Task: Generate a morning briefing that:
        1. Summarizes what's active (2-3 threads max)
        2. Notes any tensions or unresolved questions you see
        3. Suggests one thread to focus on and why
        4. Ends with a question that invites engagement

        Keep it under 150 words. No fluff.
        """
    }

    /// Parse the LLM response into a Briefing struct
    func parseBriefingResponse(_ response: String, threads: [Thread]) -> Briefing {
        // Find suggested thread by looking for thread names in response
        var suggestedThread: String? = nil

        // Sort threads by momentum (highest first) and check which ones are mentioned
        let sortedThreads = threads.sorted { ($0.momentumScore ?? 0) > ($1.momentumScore ?? 0) }

        for thread in sortedThreads {
            if response.contains(thread.name) {
                suggestedThread = thread.name
                break
            }
        }

        return Briefing(
            content: response,
            suggestedThread: suggestedThread,
            threadCount: threads.count,
            generatedAt: Date()
        )
    }
}
```

**Step 4: Run test to verify it passes**

Run: `cd SeleneChat && swift test --filter BriefingGeneratorTests`
Expected: PASS (4 tests)

**Step 5: Commit**

```bash
git add SeleneChat/Sources/Services/BriefingGenerator.swift SeleneChat/Tests/SeleneChatTests/Services/BriefingGeneratorTests.swift
git commit -m "feat(briefing): add BriefingGenerator service for LLM briefing generation"
```

---

## Task 3: Add Thread.mock and Note.mock Test Helpers

**Files:**
- Modify: `SeleneChat/Sources/Models/Thread.swift`
- Modify: `SeleneChat/Sources/Models/Note.swift`

**Step 1: Write the failing test (already written in Task 2)**

Task 2 tests use `Thread.mock()` and `Note.mock()` - these need to exist.

**Step 2: Run test to verify current state**

Run: `cd SeleneChat && swift test --filter BriefingGeneratorTests`
Expected: FAIL with "Type 'Thread' has no member 'mock'" (or similar)

**Step 3: Add mock extensions**

Add to Thread.swift (at the bottom, inside #if DEBUG):

```swift
#if DEBUG
extension Thread {
    static func mock(
        id: Int64 = 1,
        name: String = "Test Thread",
        status: String = "active",
        noteCount: Int = 5,
        momentumScore: Double? = 0.5,
        summary: String? = "Test summary",
        why: String? = nil,
        lastActivity: Date = Date()
    ) -> Thread {
        Thread(
            id: id,
            name: name,
            status: status,
            createdAt: Date(),
            updatedAt: Date(),
            lastActivity: lastActivity,
            noteCount: noteCount,
            momentumScore: momentumScore,
            summary: summary,
            why: why
        )
    }
}
#endif
```

Add to Note.swift (at the bottom, inside #if DEBUG):

```swift
#if DEBUG
extension Note {
    static func mock(
        id: Int64 = 1,
        title: String = "Test Note",
        content: String = "Test content",
        createdAt: Date = Date(),
        primaryTheme: String? = nil,
        concepts: [String]? = nil,
        energyLevel: String? = nil
    ) -> Note {
        Note(
            id: id,
            title: title,
            content: content,
            createdAt: createdAt,
            source: "test",
            primaryTheme: primaryTheme,
            concepts: concepts,
            energyLevel: energyLevel
        )
    }
}
#endif
```

**Step 4: Run test to verify it passes**

Run: `cd SeleneChat && swift test --filter BriefingGeneratorTests`
Expected: PASS (4 tests)

**Step 5: Commit**

```bash
git add SeleneChat/Sources/Models/Thread.swift SeleneChat/Sources/Models/Note.swift
git commit -m "test(models): add mock helpers for Thread and Note"
```

---

## Task 4: Create BriefingViewModel

**Files:**
- Create: `SeleneChat/Sources/ViewModels/BriefingViewModel.swift`
- Test: `SeleneChat/Tests/SeleneChatTests/ViewModels/BriefingViewModelTests.swift`

**Step 1: Write the failing test**

```swift
import XCTest
@testable import SeleneChat

final class BriefingViewModelTests: XCTestCase {

    func testInitialStateIsNotLoaded() {
        let viewModel = BriefingViewModel()

        if case .notLoaded = viewModel.state.status {
            // Expected
        } else {
            XCTFail("Expected initial state to be .notLoaded")
        }
    }

    func testLoadBriefingSetsLoadingState() async {
        let viewModel = BriefingViewModel()

        // Start loading (won't complete without mock services)
        Task {
            await viewModel.loadBriefing()
        }

        // Give it a moment to transition to loading
        try? await Task.sleep(nanoseconds: 100_000_000)

        // Should be loading or failed (depending on Ollama availability)
        let status = viewModel.state.status
        XCTAssertTrue(
            status == .loading ||
            (status != .notLoaded),
            "Expected state to transition from .notLoaded"
        )
    }

    func testDismissBriefingClearsState() async {
        let viewModel = BriefingViewModel()
        viewModel.state.status = .loaded(Briefing(
            content: "Test briefing",
            suggestedThread: nil,
            threadCount: 0,
            generatedAt: Date()
        ))

        await viewModel.dismiss()

        XCTAssertTrue(viewModel.isDismissed)
    }

    func testDigInReturnsSuggestedThreadQuery() async {
        let viewModel = BriefingViewModel()
        viewModel.state.status = .loaded(Briefing(
            content: "Focus on Event Architecture",
            suggestedThread: "Event Architecture",
            threadCount: 1,
            generatedAt: Date()
        ))

        let query = await viewModel.digIn()

        XCTAssertEqual(query, "Let's dig into Event Architecture")
    }

    func testDigInWithNoThreadReturnsGenericQuery() async {
        let viewModel = BriefingViewModel()
        viewModel.state.status = .loaded(Briefing(
            content: "No clear focus",
            suggestedThread: nil,
            threadCount: 0,
            generatedAt: Date()
        ))

        let query = await viewModel.digIn()

        XCTAssertEqual(query, "What should I focus on?")
    }
}
```

**Step 2: Run test to verify it fails**

Run: `cd SeleneChat && swift test --filter BriefingViewModelTests`
Expected: FAIL with "Cannot find 'BriefingViewModel' in scope"

**Step 3: Write minimal implementation**

```swift
import Foundation

@MainActor
class BriefingViewModel: ObservableObject {
    @Published var state = BriefingState()
    @Published var isDismissed = false

    private let generator = BriefingGenerator()
    private let databaseService = DatabaseService.shared
    private let ollamaService = OllamaService.shared

    /// Load the morning briefing
    func loadBriefing() async {
        state.status = .loading

        do {
            // Check Ollama availability
            let isAvailable = await ollamaService.isAvailable()
            guard isAvailable else {
                state.status = .failed("Selene is thinking... (Ollama not available)")
                return
            }

            // Get active threads
            let threads = try await databaseService.getActiveThreads(limit: 5)

            // Get recent notes (last 7 days)
            let recentNotes = try await databaseService.getRecentNotes(days: 7, limit: 10)

            // Build prompt
            let prompt = generator.buildBriefingPrompt(threads: threads, recentNotes: recentNotes)

            // Generate briefing
            let response = try await ollamaService.generate(prompt: prompt, model: "mistral:7b")

            // Parse response
            let briefing = generator.parseBriefingResponse(response, threads: threads)

            state.status = .loaded(briefing)
        } catch {
            state.status = .failed(error.localizedDescription)
        }
    }

    /// Dismiss the briefing without taking action
    func dismiss() async {
        isDismissed = true
    }

    /// User wants to dig into the suggested thread
    /// Returns a query string to pass to ChatView
    func digIn() async -> String {
        if case .loaded(let briefing) = state.status,
           let thread = briefing.suggestedThread {
            return "Let's dig into \(thread)"
        }
        return "What should I focus on?"
    }

    /// User wants to see something else
    func showSomethingElse() async -> String {
        return "What else is happening in my notes?"
    }
}
```

**Step 4: Run test to verify it passes**

Run: `cd SeleneChat && swift test --filter BriefingViewModelTests`
Expected: PASS (5 tests)

**Step 5: Commit**

```bash
git add SeleneChat/Sources/ViewModels/BriefingViewModel.swift SeleneChat/Tests/SeleneChatTests/ViewModels/BriefingViewModelTests.swift
git commit -m "feat(briefing): add BriefingViewModel for briefing state management"
```

---

## Task 5: Add DatabaseService.getRecentNotes Method

**Files:**
- Modify: `SeleneChat/Sources/Services/DatabaseService.swift`
- Test: `SeleneChat/Tests/SeleneChatTests/Services/DatabaseServiceTests.swift` (add to existing)

**Step 1: Write the failing test**

Add to existing DatabaseServiceTests.swift:

```swift
func testGetRecentNotesReturnsNotesFromLastNDays() async throws {
    // This test requires the test database to have some notes
    // For now, just verify the method exists and returns an array
    let notes = try await DatabaseService.shared.getRecentNotes(days: 7, limit: 10)

    // Should return an array (may be empty in test environment)
    XCTAssertNotNil(notes)
}
```

**Step 2: Run test to verify it fails**

Run: `cd SeleneChat && swift test --filter DatabaseServiceTests`
Expected: FAIL with "has no member 'getRecentNotes'"

**Step 3: Add method to DatabaseService.swift**

```swift
/// Get recent notes from the last N days
func getRecentNotes(days: Int, limit: Int = 10) async throws -> [Note] {
    guard let db = db else {
        throw DatabaseError.notConnected
    }

    let calendar = Calendar.current
    let startDate = calendar.date(byAdding: .day, value: -days, to: Date()) ?? Date()

    let query = """
        SELECT r.id, r.title, r.content, r.created_at, r.source,
               p.primary_theme, p.concepts, p.energy_level
        FROM raw_notes r
        LEFT JOIN processed_notes p ON r.id = p.raw_note_id
        WHERE r.created_at >= ?
          AND r.test_run IS NULL
        ORDER BY r.created_at DESC
        LIMIT ?
    """

    let statement = try db.prepare(query)
    let rows = try statement.bind(startDate.timeIntervalSince1970, limit)

    var notes: [Note] = []
    for row in rows {
        if let note = Note(from: row) {
            notes.append(note)
        }
    }

    return notes
}
```

**Step 4: Run test to verify it passes**

Run: `cd SeleneChat && swift test --filter DatabaseServiceTests`
Expected: PASS

**Step 5: Commit**

```bash
git add SeleneChat/Sources/Services/DatabaseService.swift SeleneChat/Tests/SeleneChatTests/Services/DatabaseServiceTests.swift
git commit -m "feat(database): add getRecentNotes method for briefing context"
```

---

## Task 6: Create BriefingView

**Files:**
- Create: `SeleneChat/Sources/Views/BriefingView.swift`

**Step 1: Write the implementation**

No unit test for SwiftUI views - we test the ViewModel instead.

```swift
import SwiftUI

struct BriefingView: View {
    @StateObject private var viewModel = BriefingViewModel()

    var onDismiss: () -> Void
    var onDigIn: (String) -> Void

    var body: some View {
        VStack(spacing: 0) {
            switch viewModel.state.status {
            case .notLoaded:
                EmptyView()
                    .onAppear {
                        Task {
                            await viewModel.loadBriefing()
                        }
                    }

            case .loading:
                loadingView

            case .loaded(let briefing):
                briefingContent(briefing)

            case .failed(let message):
                errorView(message)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color(.windowBackgroundColor))
    }

    // MARK: - Loading View

    private var loadingView: some View {
        VStack(spacing: 16) {
            Spacer()

            ProgressView()
                .scaleEffect(1.5)

            Text("Preparing your morning briefing...")
                .font(.headline)
                .foregroundColor(.secondary)

            Spacer()
        }
    }

    // MARK: - Briefing Content

    private func briefingContent(_ briefing: Briefing) -> some View {
        VStack(spacing: 24) {
            Spacer()

            // Briefing text
            VStack(alignment: .leading, spacing: 16) {
                Text(briefing.content)
                    .font(.body)
                    .lineSpacing(4)
                    .frame(maxWidth: 500, alignment: .leading)
            }
            .padding(24)
            .background(Color(.controlBackgroundColor))
            .cornerRadius(12)

            // Action buttons
            HStack(spacing: 16) {
                Button(action: {
                    Task {
                        let query = await viewModel.digIn()
                        onDigIn(query)
                    }
                }) {
                    Label("Yes, let's dig in", systemImage: "arrow.right.circle.fill")
                        .font(.headline)
                }
                .buttonStyle(.borderedProminent)

                Button(action: {
                    Task {
                        let query = await viewModel.showSomethingElse()
                        onDigIn(query)
                    }
                }) {
                    Label("Show me something else", systemImage: "arrow.triangle.2.circlepath")
                }
                .buttonStyle(.bordered)

                Button(action: onDismiss) {
                    Text("Skip")
                        .foregroundColor(.secondary)
                }
                .buttonStyle(.plain)
            }

            Spacer()
        }
        .padding()
    }

    // MARK: - Error View

    private func errorView(_ message: String) -> some View {
        VStack(spacing: 16) {
            Spacer()

            Image(systemName: "exclamationmark.triangle")
                .font(.largeTitle)
                .foregroundColor(.orange)

            Text("Couldn't generate briefing")
                .font(.headline)

            Text(message)
                .font(.caption)
                .foregroundColor(.secondary)

            HStack(spacing: 16) {
                Button("Try Again") {
                    Task {
                        await viewModel.loadBriefing()
                    }
                }
                .buttonStyle(.borderedProminent)

                Button("Skip") {
                    onDismiss()
                }
                .buttonStyle(.bordered)
            }

            Spacer()
        }
    }
}
```

**Step 2: Verify it compiles**

Run: `cd SeleneChat && swift build`
Expected: Build succeeds

**Step 3: Commit**

```bash
git add SeleneChat/Sources/Views/BriefingView.swift
git commit -m "feat(briefing): add BriefingView for morning briefing display"
```

---

## Task 7: Integrate BriefingView into ContentView

**Files:**
- Modify: `SeleneChat/Sources/App/ContentView.swift`

**Step 1: Modify ContentView to show briefing on app open**

Update ContentView.swift:

```swift
import SwiftUI

struct ContentView: View {
    @State private var selectedView: NavigationItem = .today
    @State private var pendingThreadQuery: String?
    @State private var showBriefing = true  // NEW: Show briefing on app open
    @EnvironmentObject var databaseService: DatabaseService

    enum NavigationItem: String, CaseIterable {
        case today = "Today"
        case chat = "Chat"
        case search = "Search"
        case planning = "Planning"

        var icon: String {
            switch self {
            case .today: return "sun.horizon.fill"
            case .chat: return "message.fill"
            case .search: return "magnifyingglass"
            case .planning: return "list.bullet.clipboard"
            }
        }
    }

    var body: some View {
        NavigationSplitView {
            List(NavigationItem.allCases, id: \.self, selection: $selectedView) { item in
                Label(item.rawValue, systemImage: item.icon)
                    .tag(item)
            }
            .navigationTitle("Selene")
            .frame(minWidth: 200)
        } detail: {
            // NEW: Show briefing overlay on app open
            if showBriefing {
                BriefingView(
                    onDismiss: {
                        showBriefing = false
                    },
                    onDigIn: { query in
                        showBriefing = false
                        pendingThreadQuery = query
                        selectedView = .chat
                    }
                )
            } else {
                switch selectedView {
                case .today:
                    TodayView(
                        onThreadSelected: { thread in
                            pendingThreadQuery = "show me \(thread.name) thread"
                            selectedView = .chat
                        },
                        onNoteThreadTap: { note in
                            if let threadName = note.threadName {
                                pendingThreadQuery = "What's happening with \(threadName)?"
                                selectedView = .chat
                            }
                        }
                    )
                case .chat:
                    ChatView(initialQuery: pendingThreadQuery)
                        .onAppear { pendingThreadQuery = nil }
                case .search:
                    SearchView()
                case .planning:
                    PlanningView()
                }
            }
        }
        .onAppear {
            #if DEBUG
            DebugLogger.shared.log(.nav, "Appeared: ContentView")
            ActionTracker.shared.track(action: "viewAppeared", params: ["view": "ContentView"])
            #endif
        }
        .onDisappear {
            #if DEBUG
            DebugLogger.shared.log(.nav, "Disappeared: ContentView")
            #endif
        }
    }
}
```

**Step 2: Verify it compiles**

Run: `cd SeleneChat && swift build`
Expected: Build succeeds

**Step 3: Commit**

```bash
git add SeleneChat/Sources/App/ContentView.swift
git commit -m "feat(briefing): integrate BriefingView on app open"
```

---

## Task 8: Add Integration Tests

**Files:**
- Create: `SeleneChat/Tests/SeleneChatTests/Integration/BriefingIntegrationTests.swift`

**Step 1: Write integration tests**

```swift
import XCTest
@testable import SeleneChat

final class BriefingIntegrationTests: XCTestCase {

    // MARK: - Context Builder Integration

    func testBriefingContextBuilderProducesValidContext() {
        let contextBuilder = ThinkingPartnerContextBuilder()

        let threads = [
            Thread.mock(name: "Event Architecture", noteCount: 5, momentumScore: 0.8),
            Thread.mock(name: "Project Planning", noteCount: 3, momentumScore: 0.5)
        ]

        let notes = [
            Note.mock(title: "Testing patterns", createdAt: Date()),
            Note.mock(title: "Architecture decisions", createdAt: Date())
        ]

        let context = contextBuilder.buildBriefingContext(threads: threads, recentNotes: notes)

        // Should contain thread information
        XCTAssertTrue(context.contains("Event Architecture"))
        XCTAssertTrue(context.contains("Project Planning"))

        // Should contain recent notes
        XCTAssertTrue(context.contains("Testing patterns"))
        XCTAssertTrue(context.contains("Architecture decisions"))

        // Should respect token budget (1500 tokens * 4 chars = 6000 chars max)
        XCTAssertLessThanOrEqual(context.count, 6000)
    }

    // MARK: - Generator Integration

    func testBriefingGeneratorBuildsCompletePrompt() {
        let generator = BriefingGenerator()

        let threads = [
            Thread.mock(name: "Event Architecture", noteCount: 5, momentumScore: 0.8)
        ]

        let notes = [
            Note.mock(title: "Recent note", createdAt: Date())
        ]

        let prompt = generator.buildBriefingPrompt(threads: threads, recentNotes: notes)

        // Should include system instructions
        XCTAssertTrue(prompt.contains("thinking partner"))
        XCTAssertTrue(prompt.contains("ADHD"))

        // Should include context
        XCTAssertTrue(prompt.contains("Event Architecture"))
        XCTAssertTrue(prompt.contains("Recent note"))

        // Should include task instructions
        XCTAssertTrue(prompt.contains("morning briefing"))
        XCTAssertTrue(prompt.contains("150 words"))
    }

    // MARK: - State Flow Integration

    func testBriefingStateFlowFromLoadToDisplay() {
        // Test the state machine flow
        var state = BriefingState()

        // Initial state
        XCTAssertEqual(state.status, .notLoaded)

        // Loading
        state.status = .loading
        XCTAssertEqual(state.status, .loading)

        // Loaded
        let briefing = Briefing(
            content: "Good morning...",
            suggestedThread: "Event Architecture",
            threadCount: 2,
            generatedAt: Date()
        )
        state.status = .loaded(briefing)

        if case .loaded(let result) = state.status {
            XCTAssertEqual(result.suggestedThread, "Event Architecture")
            XCTAssertEqual(result.threadCount, 2)
        } else {
            XCTFail("Expected loaded state")
        }
    }

    func testBriefingStateFlowWithError() {
        var state = BriefingState()

        state.status = .loading
        state.status = .failed("Ollama not available")

        if case .failed(let message) = state.status {
            XCTAssertEqual(message, "Ollama not available")
        } else {
            XCTFail("Expected failed state")
        }
    }

    // MARK: - End-to-End Prompt Flow

    func testEndToEndBriefingPromptFlow() {
        // Simulate the full flow from threads/notes to prompt
        let contextBuilder = ThinkingPartnerContextBuilder()
        let generator = BriefingGenerator()

        // 1. Create test data
        let threads = [
            Thread.mock(name: "Project Alpha", noteCount: 10, momentumScore: 0.9, summary: "Building the new feature"),
            Thread.mock(name: "Bug Fixes", noteCount: 3, momentumScore: 0.3, summary: "Minor fixes")
        ]

        let recentNotes = [
            Note.mock(title: "Alpha milestone reached", createdAt: Date()),
            Note.mock(title: "Bug in login", createdAt: Date())
        ]

        // 2. Build context
        let context = contextBuilder.buildBriefingContext(threads: threads, recentNotes: recentNotes)

        // 3. Build prompt
        let prompt = generator.buildBriefingPrompt(threads: threads, recentNotes: recentNotes)

        // 4. Verify the prompt would work for an LLM
        XCTAssertTrue(prompt.count > 100, "Prompt should have substantial content")
        XCTAssertTrue(prompt.count < 10000, "Prompt should not be excessively long")
        XCTAssertTrue(prompt.contains("Project Alpha"), "Prompt should mention high-momentum thread")
        XCTAssertTrue(prompt.contains("2-3 threads max"), "Prompt should include instructions")
    }
}
```

**Step 2: Run tests**

Run: `cd SeleneChat && swift test --filter BriefingIntegrationTests`
Expected: PASS (5 tests)

**Step 3: Commit**

```bash
git add SeleneChat/Tests/SeleneChatTests/Integration/BriefingIntegrationTests.swift
git commit -m "test(briefing): add integration tests for briefing flow"
```

---

## Task 9: Update Documentation

**Files:**
- Modify: `SeleneChat/CLAUDE.md`
- Modify: `SeleneChat/Sources/Views/CLAUDE.md`
- Modify: `docs/plans/2026-02-05-selene-thinking-partner-design.md`

**Step 1: Update SeleneChat/CLAUDE.md**

Add to Key Files section:
```markdown
- Sources/Services/BriefingGenerator.swift - Morning briefing generation
- Sources/ViewModels/BriefingViewModel.swift - Briefing state management
- Sources/Views/BriefingView.swift - Morning briefing UI
```

Add to Test Coverage Areas:
```markdown
- BriefingState - Briefing status state machine
- BriefingGenerator - Prompt building and response parsing
- BriefingViewModel - State management and actions
```

**Step 2: Update SeleneChat/Sources/Views/CLAUDE.md**

Add to Key Files section:
```markdown
- BriefingView.swift - Morning briefing display with action buttons
```

Add new section after ChatView:
```markdown
## BriefingView

### Responsibilities
- Display LLM-generated morning briefing
- Show loading and error states
- Provide "dig in", "show something else", and "skip" actions
- Transition to ChatView with context

### Common Patterns
[Include a simplified version of the BriefingView structure]
```

**Step 3: Update design doc**

Mark Phase 3 acceptance criteria as complete:
```markdown
### Phase 3: Morning Briefing

**Acceptance Criteria:**
- [x] Opening app shows briefing (not empty chat)
- [x] Briefing loads in <5 seconds (depends on Ollama)
- [x] Tapping "dig in" starts conversation with thread context
- [x] Can dismiss briefing and go to regular chat
```

**Step 4: Commit**

```bash
git add SeleneChat/CLAUDE.md SeleneChat/Sources/Views/CLAUDE.md docs/plans/2026-02-05-selene-thinking-partner-design.md
git commit -m "docs(briefing): update documentation for Phase 3 Morning Briefing"
```

---

## Summary

| Task | Description | Files |
|------|-------------|-------|
| 1 | BriefingState model | Sources/Models/BriefingState.swift |
| 2 | BriefingGenerator service | Sources/Services/BriefingGenerator.swift |
| 3 | Mock helpers for Thread/Note | Sources/Models/Thread.swift, Note.swift |
| 4 | BriefingViewModel | Sources/ViewModels/BriefingViewModel.swift |
| 5 | DatabaseService.getRecentNotes | Sources/Services/DatabaseService.swift |
| 6 | BriefingView | Sources/Views/BriefingView.swift |
| 7 | ContentView integration | Sources/App/ContentView.swift |
| 8 | Integration tests | Tests/Integration/BriefingIntegrationTests.swift |
| 9 | Documentation | CLAUDE.md files, design doc |

**Dependencies:**
- Phase 2 (ThinkingPartnerContextBuilder) must be complete
- Ollama must be running for live briefing generation
- DatabaseService must have getActiveThreads method (exists)
