# Thinking Partner Phase 1: Prompt Rewrite Implementation Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** Rewrite thread workspace system prompts so the thinking partner asks clarifying questions, proposes options, and knows it can create Things tasks — instead of producing generic summaries.

**Architecture:** All changes are in `ThreadWorkspacePromptBuilder.swift` (prompt text) and its test file. No infrastructure, no new services, no new files. The view model call sites don't change — only the strings returned by the builder change. We also add a new `isPlanningQuery` detection method + a `buildPlanningPrompt` method, parallel to how `isWhatsNextQuery`/`buildWhatsNextPrompt` already work.

**Tech Stack:** Swift 5.9, XCTest, SeleneShared target (public prompt builder)

---

### Task 1: Update tests for new system identity and capability awareness

**Files:**
- Modify: `SeleneChat/Tests/SeleneChatTests/Services/ThreadWorkspacePromptBuilderTests.swift`

**Step 1: Write failing tests for the new prompt identity**

Add these tests to the existing `ThreadWorkspacePromptBuilderTests` class:

```swift
// MARK: - Interactive Identity Tests

func testInitialPromptHasInteractiveIdentity() {
    let builder = ThreadWorkspacePromptBuilder()
    let prompt = builder.buildInitialPrompt(
        thread: Thread.mock(name: "Test"),
        notes: [Note.mock()],
        tasks: []
    )

    XCTAssertTrue(
        prompt.contains("interactive thinking partner"),
        "Prompt should use interactive thinking partner identity"
    )
    XCTAssertFalse(
        prompt.contains("Respond naturally to whatever"),
        "Prompt should NOT use old generic instruction"
    )
}

func testInitialPromptDescribesThingsCapability() {
    let builder = ThreadWorkspacePromptBuilder()
    let prompt = builder.buildInitialPrompt(
        thread: Thread.mock(name: "Test"),
        notes: [Note.mock()],
        tasks: []
    )

    XCTAssertTrue(
        prompt.contains("Things"),
        "Prompt should mention Things task manager by name"
    )
    XCTAssertTrue(
        prompt.lowercased().contains("capability") || prompt.lowercased().contains("capabilities"),
        "Prompt should frame action markers as a capability"
    )
}

func testInitialPromptHasNoBriefWordLimit() {
    let builder = ThreadWorkspacePromptBuilder()
    let prompt = builder.buildInitialPrompt(
        thread: Thread.mock(name: "Test"),
        notes: [Note.mock()],
        tasks: []
    )

    XCTAssertFalse(
        prompt.contains("under 200 words"),
        "Prompt should NOT have 200-word limit"
    )
    XCTAssertFalse(
        prompt.contains("under 150 words"),
        "Prompt should NOT have 150-word limit"
    )
    XCTAssertFalse(
        prompt.contains("under 100 words"),
        "Prompt should NOT have 100-word limit"
    )
}

func testInitialPromptCoachesAgainstSummarizing() {
    let builder = ThreadWorkspacePromptBuilder()
    let prompt = builder.buildInitialPrompt(
        thread: Thread.mock(name: "Test"),
        notes: [Note.mock()],
        tasks: []
    )

    XCTAssertTrue(
        prompt.lowercased().contains("not summarize") || prompt.lowercased().contains("not a summarizer"),
        "Prompt should explicitly discourage summarizing"
    )
}

func testChunkBasedInitialPromptHasInteractiveIdentity() {
    let builder = ThreadWorkspacePromptBuilder()
    let chunks = [(chunk: NoteChunk.mock(id: 1, content: "Test chunk"), similarity: Float(0.8))]
    let prompt = builder.buildInitialPromptWithChunks(
        thread: Thread.mock(name: "Test"),
        retrievedChunks: chunks,
        tasks: []
    )

    XCTAssertTrue(
        prompt.contains("interactive thinking partner"),
        "Chunk-based prompt should also use interactive identity"
    )
    XCTAssertFalse(
        prompt.contains("under 200 words"),
        "Chunk-based prompt should NOT have 200-word limit"
    )
}

func testFollowUpPromptHasNoBriefWordLimit() {
    let builder = ThreadWorkspacePromptBuilder()
    let prompt = builder.buildFollowUpPrompt(
        thread: Thread.mock(name: "Test"),
        notes: [Note.mock()],
        tasks: [],
        conversationHistory: "User: Q\nAssistant: A",
        currentQuery: "Next?"
    )

    XCTAssertFalse(
        prompt.contains("under 150 words"),
        "Follow-up should NOT have 150-word limit"
    )
}
```

**Step 2: Run tests to verify they fail**

Run: `cd SeleneChat && swift test --filter ThreadWorkspacePromptBuilderTests 2>&1 | tail -30`

Expected: Multiple failures — current prompts say "Respond naturally", have word limits, don't mention Things as a capability.

**Step 3: Commit failing tests**

```bash
git add SeleneChat/Tests/SeleneChatTests/Services/ThreadWorkspacePromptBuilderTests.swift
git commit -m "test: add failing tests for interactive thinking partner identity"
```

---

### Task 2: Rewrite system identity and action marker format

**Files:**
- Modify: `SeleneChat/Sources/SeleneShared/Services/ThreadWorkspacePromptBuilder.swift:9-14` (actionMarkerFormat)
- Modify: `SeleneChat/Sources/SeleneShared/Services/ThreadWorkspacePromptBuilder.swift:28-45` (buildInitialPrompt)
- Modify: `SeleneChat/Sources/SeleneShared/Services/ThreadWorkspacePromptBuilder.swift:57-86` (buildFollowUpPrompt)
- Modify: `SeleneChat/Sources/SeleneShared/Services/ThreadWorkspacePromptBuilder.swift:121-142` (buildInitialPromptWithChunks)
- Modify: `SeleneChat/Sources/SeleneShared/Services/ThreadWorkspacePromptBuilder.swift:153-183` (buildFollowUpPromptWithChunks)

**Step 1: Replace `actionMarkerFormat` property (line 11-14)**

Replace:
```swift
private let actionMarkerFormat = """
    Only use action markers when the user asks for task breakdown, next steps, or actionable items. When you do, use this format:
    [ACTION: Brief action description | ENERGY: high/medium/low | TIMEFRAME: today/this-week/someday]
    """
```

With:
```swift
private let systemIdentity = """
    You are an interactive thinking partner for someone with ADHD. Your job is to help the user make progress on this thread — not summarize it back to them.

    CAPABILITIES:
    - You can create tasks in Things (the user's task manager). When you and the user have collaboratively identified concrete next steps, suggest them using action markers:
      [ACTION: Brief action description | ENERGY: high/medium/low | TIMEFRAME: today/this-week/someday]
    - You have full context of the user's notes, thread history, and existing tasks

    BEHAVIOR:
    - When the user asks for planning help: Ask 1-2 clarifying questions about their priorities or constraints first, then break the problem into concrete steps
    - When the user asks "what's next": Propose 2-3 possible directions with trade-offs, ask which resonates
    - When you identify actionable steps: Suggest creating them as tasks in Things
    - Default: Be a collaborator, not a summarizer. Ask before assuming.

    Be concise but thorough. Prefer asking a good question over giving a generic answer. Never summarize the thread back to the user unless they specifically ask for a summary.
    """
```

**Step 2: Rewrite `buildInitialPrompt` (line 28-45)**

Replace the return statement body with:
```swift
return """
    \(systemIdentity)

    ## Thread: "\(thread.name)"

    \(threadContext)

    \(taskContext)
    """
```

**Step 3: Rewrite `buildFollowUpPrompt` (line 57-86)**

Replace the return statement body with:
```swift
return """
    \(systemIdentity)

    ## Thread: "\(thread.name)"

    \(threadContext)

    \(taskContext)

    ## Conversation So Far
    \(conversationHistory)

    ## Current Question
    \(currentQuery)
    """
```

**Step 4: Rewrite `buildInitialPromptWithChunks` (line 121-142)**

Replace the return statement body with:
```swift
return """
    \(systemIdentity)

    \(chunkContext)

    \(taskContext)
    """
```

**Step 5: Rewrite `buildFollowUpPromptWithChunks` (line 153-183)**

Replace the return statement body with:
```swift
return """
    \(systemIdentity)

    \(chunkContext)

    \(taskContext)

    ## Conversation So Far
    \(conversationHistory)

    ## Current Question
    \(currentQuery)
    """
```

**Step 6: Run tests to verify Task 1 tests pass**

Run: `cd SeleneChat && swift test --filter ThreadWorkspacePromptBuilderTests 2>&1 | tail -40`

Expected: All tests pass. The old tests for thread context, task state, conversation history, and action markers should still pass because:
- Thread name is still in the prompt (from threadContext / chunkContext)
- Task state is still included
- Conversation history and current query are still included
- `[ACTION:`, `ENERGY:`, `TIMEFRAME:` are all in the new `systemIdentity`
- `testBuildInitialPromptIncludesADHDFraming` still passes (contains "adhd" and "thinking partner")
- `testActionMarkersAreConditional` — **this test will fail** because the old prompt says "Only use action markers" and the new prompt doesn't use that exact phrase. Update this test (see step 7).

**Step 7: Fix the `testActionMarkersAreConditional` and `testFollowUpActionMarkersAreConditional` tests**

These tests assert `prompt.contains("Only use action markers")`. The new prompt replaces that with "When you and the user have collaboratively identified concrete next steps." Update:

```swift
func testActionMarkersAreConditional() {
    let thread = Thread.mock(name: "Test Thread")
    let builder = ThreadWorkspacePromptBuilder()
    let prompt = builder.buildInitialPrompt(thread: thread, notes: [Note.mock()], tasks: [])

    XCTAssertTrue(
        prompt.contains("collaboratively identified"),
        "Action markers should be tied to collaborative identification of steps"
    )
}

func testFollowUpActionMarkersAreConditional() {
    let thread = Thread.mock(name: "Test Thread")
    let builder = ThreadWorkspacePromptBuilder()
    let prompt = builder.buildFollowUpPrompt(
        thread: thread,
        notes: [Note.mock()],
        tasks: [],
        conversationHistory: "User: Q\nAssistant: A",
        currentQuery: "Next?"
    )

    XCTAssertTrue(
        prompt.contains("collaboratively identified"),
        "Follow-up action markers should be tied to collaborative identification"
    )
}
```

**Step 8: Run full test suite to verify all pass**

Run: `cd SeleneChat && swift test --filter ThreadWorkspacePromptBuilderTests 2>&1 | tail -40`

Expected: All pass.

**Step 9: Commit**

```bash
git add SeleneChat/Sources/SeleneShared/Services/ThreadWorkspacePromptBuilder.swift \
       SeleneChat/Tests/SeleneChatTests/Services/ThreadWorkspacePromptBuilderTests.swift
git commit -m "feat: rewrite thinking partner prompts for interactive planning behavior"
```

---

### Task 3: Add planning intent detection

**Files:**
- Modify: `SeleneChat/Sources/SeleneShared/Services/ThreadWorkspacePromptBuilder.swift`
- Modify: `SeleneChat/Tests/SeleneChatTests/Services/ThreadWorkspacePromptBuilderTests.swift`

**Step 1: Write failing tests for `isPlanningQuery`**

Add to the test file:

```swift
// MARK: - Planning Detection Tests

func testIsPlanningQueryDetectsCommonPatterns() {
    let builder = ThreadWorkspacePromptBuilder()

    // Should detect planning intent
    XCTAssertTrue(builder.isPlanningQuery("help me make a plan"))
    XCTAssertTrue(builder.isPlanningQuery("Help me figure out next steps"))
    XCTAssertTrue(builder.isPlanningQuery("break this down"))
    XCTAssertTrue(builder.isPlanningQuery("how should I approach this?"))
    XCTAssertTrue(builder.isPlanningQuery("what are my options"))
    XCTAssertTrue(builder.isPlanningQuery("help me think through this"))
    XCTAssertTrue(builder.isPlanningQuery("can you help me prioritize"))
    XCTAssertTrue(builder.isPlanningQuery("I need to figure out what to do"))
    XCTAssertTrue(builder.isPlanningQuery("help me work through this"))
    XCTAssertTrue(builder.isPlanningQuery("what should my next move be"))
}

func testIsPlanningQueryRejectsNonPlanningQueries() {
    let builder = ThreadWorkspacePromptBuilder()

    // Should NOT detect planning intent
    XCTAssertFalse(builder.isPlanningQuery("tell me about this thread"))
    XCTAssertFalse(builder.isPlanningQuery("summarize my notes"))
    XCTAssertFalse(builder.isPlanningQuery("what is this thread about"))
    XCTAssertFalse(builder.isPlanningQuery("when did I last update this"))
}

func testIsPlanningQueryHasAtLeast20Patterns() {
    // Verify the pattern list is comprehensive enough
    let builder = ThreadWorkspacePromptBuilder()

    // Test a broad set of natural planning phrases
    let planningPhrases = [
        "help me make a plan",
        "break this down",
        "how should I approach",
        "what are my options",
        "figure out",
        "think through",
        "work through",
        "prioritize",
        "decide between",
        "next move",
        "help me plan",
        "make a plan",
        "create a plan",
        "come up with a plan",
        "what should I do about",
        "how do I tackle",
        "where do I start",
        "help me decide",
        "map this out",
        "lay out the steps",
    ]

    var detected = 0
    for phrase in planningPhrases {
        if builder.isPlanningQuery(phrase) {
            detected += 1
        }
    }

    XCTAssertGreaterThanOrEqual(
        detected, 20,
        "Should detect at least 20 planning patterns, got \(detected)"
    )
}
```

**Step 2: Run tests to verify they fail**

Run: `cd SeleneChat && swift test --filter testIsPlanningQuery 2>&1 | tail -20`

Expected: Compilation failure — `isPlanningQuery` doesn't exist yet.

**Step 3: Implement `isPlanningQuery` in ThreadWorkspacePromptBuilder**

Add after the `isWhatsNextQuery` method (after line 231):

```swift
// MARK: - Planning Intent Detection

/// Patterns that indicate a planning/help intent (broader than "what's next")
private let planningPatterns: [String] = [
    // Help requests
    "help me", "can you help",
    // Planning language
    "make a plan", "create a plan", "come up with a plan",
    "help me plan", "build a plan",
    // Breakdown language
    "break this down", "break it down",
    "lay out the steps", "map this out", "map out",
    // Approach language
    "how should i approach", "how do i tackle",
    "where do i start", "where should i start",
    // Decision language
    "what are my options", "decide between", "help me decide",
    "what should i do about", "which should i",
    // Thinking language
    "think through", "work through", "figure out",
    "think about this", "reason through",
    // Priority language
    "prioritize", "what matters most", "most important",
    // Next action language
    "next move", "what to tackle",
]

/// Detect if a query has planning/help intent (distinct from "what's next").
/// Planning queries get a prompt that coaches multi-turn clarifying dialogue.
public func isPlanningQuery(_ query: String) -> Bool {
    let lowered = query.lowercased()
        .replacingOccurrences(of: "?", with: "")
        .trimmingCharacters(in: .whitespaces)
    return planningPatterns.contains { lowered.contains($0) }
}
```

**Step 4: Run tests to verify they pass**

Run: `cd SeleneChat && swift test --filter testIsPlanningQuery 2>&1 | tail -20`

Expected: All 3 planning detection tests pass.

**Step 5: Commit**

```bash
git add SeleneChat/Sources/SeleneShared/Services/ThreadWorkspacePromptBuilder.swift \
       SeleneChat/Tests/SeleneChatTests/Services/ThreadWorkspacePromptBuilderTests.swift
git commit -m "feat: add planning intent detection with 25+ patterns"
```

---

### Task 4: Add planning-specific prompt builder method

**Files:**
- Modify: `SeleneChat/Sources/SeleneShared/Services/ThreadWorkspacePromptBuilder.swift`
- Modify: `SeleneChat/Tests/SeleneChatTests/Services/ThreadWorkspacePromptBuilderTests.swift`

**Step 1: Write failing tests for `buildPlanningPrompt`**

```swift
// MARK: - Planning Prompt Tests

func testBuildPlanningPromptCoachesClarifyingQuestions() {
    let thread = Thread.mock(name: "Dog Training", why: "Train the dog")
    let notes = [Note.mock(id: 1, title: "Leash training", content: "Positive reinforcement works best")]
    let builder = ThreadWorkspacePromptBuilder()

    let prompt = builder.buildPlanningPrompt(
        thread: thread,
        notes: notes,
        tasks: [],
        userQuery: "help me make a plan for this"
    )

    XCTAssertTrue(
        prompt.lowercased().contains("clarifying question") || prompt.lowercased().contains("ask"),
        "Planning prompt should coach asking clarifying questions"
    )
}

func testBuildPlanningPromptIncludesUserQuery() {
    let builder = ThreadWorkspacePromptBuilder()

    let prompt = builder.buildPlanningPrompt(
        thread: Thread.mock(name: "Test"),
        notes: [Note.mock()],
        tasks: [],
        userQuery: "help me break down the API integration"
    )

    XCTAssertTrue(
        prompt.contains("help me break down the API integration"),
        "Planning prompt should include the user's query"
    )
}

func testBuildPlanningPromptIncludesThreadContext() {
    let builder = ThreadWorkspacePromptBuilder()

    let prompt = builder.buildPlanningPrompt(
        thread: Thread.mock(name: "Voice Features"),
        notes: [Note.mock(id: 1, title: "TTS Research", content: "AVSpeechSynthesizer works offline")],
        tasks: [],
        userQuery: "help me plan"
    )

    XCTAssertTrue(prompt.contains("Voice Features"), "Planning prompt should include thread name")
    XCTAssertTrue(prompt.contains("TTS Research"), "Planning prompt should include note context")
}

func testBuildPlanningPromptIncludesTaskState() {
    let builder = ThreadWorkspacePromptBuilder()
    let tasks = [
        ThreadTask.mock(thingsTaskId: "T-001", title: "Research APIs"),
        ThreadTask.mock(thingsTaskId: "T-002", title: "Write tests", completedAt: Date())
    ]

    let prompt = builder.buildPlanningPrompt(
        thread: Thread.mock(name: "Test"),
        notes: [Note.mock()],
        tasks: tasks,
        userQuery: "help me plan"
    )

    XCTAssertTrue(prompt.contains("Research APIs"), "Planning prompt should include task state")
}

func testBuildPlanningPromptMentionsThingsCapability() {
    let builder = ThreadWorkspacePromptBuilder()

    let prompt = builder.buildPlanningPrompt(
        thread: Thread.mock(name: "Test"),
        notes: [Note.mock()],
        tasks: [],
        userQuery: "help me plan"
    )

    XCTAssertTrue(
        prompt.contains("Things"),
        "Planning prompt should mention Things task creation capability"
    )
}
```

**Step 2: Run tests to verify they fail**

Run: `cd SeleneChat && swift test --filter testBuildPlanningPrompt 2>&1 | tail -20`

Expected: Compilation failure — `buildPlanningPrompt` doesn't exist yet.

**Step 3: Implement `buildPlanningPrompt`**

Add to `ThreadWorkspacePromptBuilder`, after the `isPlanningQuery` method:

```swift
/// Build a planning-specific prompt that coaches multi-turn clarifying dialogue.
/// Used when `isPlanningQuery` returns true.
public func buildPlanningPrompt(
    thread: Thread,
    notes: [Note],
    tasks: [ThreadTask],
    userQuery: String
) -> String {
    let threadContext = contextBuilder.buildDeepDiveContext(thread: thread, notes: notes)
    let taskContext = buildTaskContext(tasks)

    return """
    You are an interactive thinking partner for someone with ADHD, helping them plan their next steps on "\(thread.name)".

    \(threadContext)

    \(taskContext)

    ## User's Request
    \(userQuery)

    INSTRUCTIONS:
    Start by asking 1-2 short clarifying questions about the user's priorities, constraints, or what success looks like. Do NOT jump to a full plan yet.

    After the user answers, you will:
    1. Identify 2-3 possible directions with trade-offs
    2. Ask which resonates
    3. Break the chosen direction into concrete steps
    4. Suggest creating tasks in Things using action markers:
       [ACTION: Brief description | ENERGY: high/medium/low | TIMEFRAME: today/this-week/someday]

    CAPABILITIES:
    - You can create tasks in Things (the user's task manager) via action markers
    - You have the user's full note history and existing tasks for this thread

    Keep your questions specific to the thread context. Do not ask generic questions.
    """
}
```

**Step 4: Run tests to verify they pass**

Run: `cd SeleneChat && swift test --filter testBuildPlanningPrompt 2>&1 | tail -20`

Expected: All 5 planning prompt tests pass.

**Step 5: Commit**

```bash
git add SeleneChat/Sources/SeleneShared/Services/ThreadWorkspacePromptBuilder.swift \
       SeleneChat/Tests/SeleneChatTests/Services/ThreadWorkspacePromptBuilderTests.swift
git commit -m "feat: add planning-specific prompt with clarifying question coaching"
```

---

### Task 5: Wire planning detection into the view model

**Files:**
- Modify: `SeleneChat/Sources/SeleneChat/ViewModels/ThreadWorkspaceChatViewModel.swift:141-171` (buildPrompt)
- Modify: `SeleneChat/Sources/SeleneChat/ViewModels/ThreadWorkspaceChatViewModel.swift:185-230` (buildChunkBasedPrompt)
- Modify: `SeleneChat/Tests/SeleneChatTests/ViewModels/ThreadWorkspaceChatViewModelTests.swift`

**Step 1: Write a failing test**

Read the existing `ThreadWorkspaceChatViewModelTests.swift` first to understand the test patterns, then add:

```swift
func testBuildPromptUsesPlanningPromptForPlanningQueries() {
    let thread = Thread.mock(name: "Test Thread")
    let notes = [Note.mock()]
    let vm = ThreadWorkspaceChatViewModel(thread: thread, notes: notes, tasks: [])

    let prompt = vm.buildPrompt(for: "help me make a plan for this")

    XCTAssertTrue(
        prompt.contains("clarifying question") || prompt.contains("clarifying"),
        "Planning queries should use the planning prompt"
    )
}

func testBuildPromptUsesRegularPromptForNonPlanningQueries() {
    let thread = Thread.mock(name: "Test Thread")
    let notes = [Note.mock()]
    let vm = ThreadWorkspaceChatViewModel(thread: thread, notes: notes, tasks: [])

    let prompt = vm.buildPrompt(for: "tell me about this thread")

    XCTAssertFalse(
        prompt.contains("clarifying question"),
        "Non-planning queries should NOT use the planning prompt"
    )
}
```

**Step 2: Run tests to verify they fail**

Run: `cd SeleneChat && swift test --filter testBuildPromptUsesPlanningPrompt 2>&1 | tail -20`

Expected: First test fails (planning query doesn't route to planning prompt yet).

**Step 3: Wire planning detection into `buildPrompt`**

In `ThreadWorkspaceChatViewModel.swift`, modify `buildPrompt(for:)` (line 141):

```swift
func buildPrompt(for query: String) -> String {
    // Check for "what's next" query first
    if promptBuilder.isWhatsNextQuery(query) {
        return promptBuilder.buildWhatsNextPrompt(
            thread: thread,
            notes: notes,
            tasks: tasks
        )
    }

    // Check for planning intent (first message only — follow-ups use regular flow)
    let priorMessages = messages.filter { $0.role != .system }
    let hasHistory = priorMessages.contains { $0.role == .assistant }

    if !hasHistory && promptBuilder.isPlanningQuery(query) {
        return promptBuilder.buildPlanningPrompt(
            thread: thread,
            notes: notes,
            tasks: tasks,
            userQuery: query
        )
    }

    if hasHistory {
        let history = buildConversationHistory()
        return promptBuilder.buildFollowUpPrompt(
            thread: thread,
            notes: notes,
            tasks: tasks,
            conversationHistory: history,
            currentQuery: query
        )
    } else {
        return promptBuilder.buildInitialPrompt(
            thread: thread,
            notes: notes,
            tasks: tasks
        )
    }
}
```

**Step 4: Wire planning detection into `buildChunkBasedPrompt`**

In `ThreadWorkspaceChatViewModel.swift`, modify `buildChunkBasedPrompt(for:)` (line 185):

Add planning check after the "what's next" check (line 187-193):

```swift
// Check for planning intent (first message only)
let priorMessages = messages.filter { $0.role != .system }
let hasHistory = priorMessages.contains { $0.role == .assistant }

if !hasHistory && promptBuilder.isPlanningQuery(query) {
    return promptBuilder.buildPlanningPrompt(
        thread: thread,
        notes: notes,
        tasks: tasks,
        userQuery: query
    )
}
```

Note: This goes right after the `isWhatsNextQuery` block and before the chunk retrieval. Planning prompts use full notes (not chunks) because the user needs complete context for planning.

**Step 5: Run tests to verify they pass**

Run: `cd SeleneChat && swift test --filter ThreadWorkspaceChatViewModelTests 2>&1 | tail -30`

Expected: All tests pass.

**Step 6: Commit**

```bash
git add SeleneChat/Sources/SeleneChat/ViewModels/ThreadWorkspaceChatViewModel.swift \
       SeleneChat/Tests/SeleneChatTests/ViewModels/ThreadWorkspaceChatViewModelTests.swift
git commit -m "feat: wire planning detection into thread workspace chat flow"
```

---

### Task 6: Rewrite the "What's Next" prompt

**Files:**
- Modify: `SeleneChat/Sources/SeleneShared/Services/ThreadWorkspacePromptBuilder.swift:234-268` (buildWhatsNextPrompt)
- Modify: `SeleneChat/Tests/SeleneChatTests/Services/ThreadWorkspacePromptBuilderTests.swift`

**Step 1: Write failing test for upgraded What's Next behavior**

```swift
func testBuildWhatsNextPromptProposesMultipleOptions() {
    let thread = Thread.mock(name: "Project X", why: "Ship the feature")
    let notes = [Note.mock(id: 1, title: "Research", content: "Found three approaches")]
    let tasks = [ThreadTask.mock(thingsTaskId: "T-001", title: "Open task")]

    let builder = ThreadWorkspacePromptBuilder()
    let prompt = builder.buildWhatsNextPrompt(thread: thread, notes: notes, tasks: tasks)

    XCTAssertTrue(
        prompt.contains("2-3") || prompt.contains("two or three") || prompt.contains("multiple"),
        "What's Next prompt should ask LLM to propose multiple options"
    )
    XCTAssertFalse(
        prompt.contains("recommend ONE"),
        "What's Next prompt should NOT limit to one recommendation"
    )
    XCTAssertFalse(
        prompt.contains("under 100 words"),
        "What's Next prompt should NOT have 100-word limit"
    )
}

func testBuildWhatsNextPromptAsksWhichResonates() {
    let thread = Thread.mock(name: "Test")
    let builder = ThreadWorkspacePromptBuilder()
    let prompt = builder.buildWhatsNextPrompt(thread: thread, notes: [Note.mock()], tasks: [])

    XCTAssertTrue(
        prompt.lowercased().contains("resonat") || prompt.lowercased().contains("which"),
        "What's Next prompt should ask user which option resonates"
    )
}
```

**Step 2: Run tests to verify they fail**

Run: `cd SeleneChat && swift test --filter testBuildWhatsNextPrompt 2>&1 | tail -20`

Expected: Fails — current prompt says "recommend ONE" and "under 100 words."

**Step 3: Rewrite `buildWhatsNextPrompt`**

Replace the return statement (line 256-268):

```swift
return """
    You are an interactive thinking partner for someone with ADHD, helping them decide what to work on next in their "\(thread.name)" thread.

    \(threadContext)

    ## Task State
    \(taskList.isEmpty ? "No tasks linked to this thread yet." : taskList)

    Based on the thread context, open tasks, and what's been completed:

    1. Propose 2-3 possible directions to go next, each with a brief trade-off (energy required, impact, dependencies)
    2. Ask which resonates with the user right now
    3. Do NOT pick for them — present options and let them choose

    If there are no open tasks, suggest what the logical next actions would be based on the thread's current state.

    CAPABILITY: You can create tasks in Things using action markers after the user picks a direction:
    [ACTION: Brief description | ENERGY: high/medium/low | TIMEFRAME: today/this-week/someday]
    """
```

**Step 4: Update the existing `testBuildWhatsNextPromptIncludesTaskState` test**

The existing test asserts `prompt.contains("recommend")` which no longer matches. Update:

```swift
func testBuildWhatsNextPromptIncludesTaskState() {
    let thread = Thread.mock(
        name: "ADHD System",
        why: "Build tools for executive function",
        summary: "Phase 1 complete"
    )

    let openTask = ThreadTask.mock(thingsTaskId: "T1", title: "Research time-blocking")
    let completedTask = ThreadTask.mock(thingsTaskId: "T2", title: "Write principles doc", completedAt: Date())

    let notes = [
        Note.mock(id: 1, title: "ADHD Research", content: "Focus on externalization")
    ]

    let builder = ThreadWorkspacePromptBuilder()
    let prompt = builder.buildWhatsNextPrompt(thread: thread, notes: notes, tasks: [openTask, completedTask])

    XCTAssertTrue(prompt.contains("Research time-blocking"), "Should include open task")
    XCTAssertTrue(prompt.contains("Write principles doc"), "Should include completed task")
    XCTAssertTrue(prompt.contains("2-3"), "Should propose multiple options")
}
```

**Step 5: Run tests to verify they pass**

Run: `cd SeleneChat && swift test --filter ThreadWorkspacePromptBuilderTests 2>&1 | tail -30`

Expected: All pass.

**Step 6: Commit**

```bash
git add SeleneChat/Sources/SeleneShared/Services/ThreadWorkspacePromptBuilder.swift \
       SeleneChat/Tests/SeleneChatTests/Services/ThreadWorkspacePromptBuilderTests.swift
git commit -m "feat: upgrade what's-next prompt to propose multiple options with trade-offs"
```

---

### Task 7: Run full test suite and build app

**Step 1: Run all SeleneChat tests**

Run: `cd SeleneChat && swift test 2>&1 | tail -40`

Expected: All 270+ tests pass. No regressions.

**Step 2: Build the app**

Run: `cd SeleneChat && ./build-app.sh 2>&1 | tail -20`

Expected: Build succeeds.

**Step 3: Install to Applications**

Run: `cp -R SeleneChat/.build/release/SeleneChat.app /Applications/`

**Step 4: Commit any remaining changes**

If there are any uncommitted changes from test fixes:

```bash
git add -A SeleneChat/
git commit -m "fix: test adjustments for thinking partner prompt rewrite"
```

---

### Task 8: Manual verification with production app

**Step 1: Open SeleneChat from Applications**

Launch the freshly installed SeleneChat.app.

**Step 2: Open a thread workspace**

Pick a thread with notes and tasks.

**Step 3: Test planning query**

Type: "help me figure out the next steps for this"

Expected behavior:
- Selene asks 1-2 clarifying questions about priorities/constraints
- Does NOT dump a generic summary of all notes
- Mentions it can create tasks in Things

**Step 4: Test what's-next query**

Type: "what's next"

Expected behavior:
- Selene proposes 2-3 possible directions
- Asks which resonates
- Does NOT recommend ONE task in 100 words

**Step 5: Investigate double-response bug**

Send a message and watch for two responses appearing. If reproducible:
- Check `/tmp/selenechat-debug.log` for clues
- Note exact behavior for Phase 2 investigation

---

## Summary of all commits

1. `test: add failing tests for interactive thinking partner identity`
2. `feat: rewrite thinking partner prompts for interactive planning behavior`
3. `feat: add planning intent detection with 25+ patterns`
4. `feat: add planning-specific prompt with clarifying question coaching`
5. `feat: wire planning detection into thread workspace chat flow`
6. `feat: upgrade what's-next prompt to propose multiple options with trade-offs`
7. (if needed) `fix: test adjustments for thinking partner prompt rewrite`
