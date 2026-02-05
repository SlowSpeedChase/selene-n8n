# Conversation Context (Phase 1) Implementation Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** Enable multi-turn conversation where Selene remembers what was said earlier in the session.

**Architecture:** Create SessionContextService that builds conversation history from ChatSession.messages and includes it in each Ollama prompt. Compress older turns when context exceeds token budget.

**Tech Stack:** Swift, OllamaService, ChatViewModel

---

## Task 1: Create SessionContextService

**Files:**
- Create: `SeleneChat/Sources/Services/SessionContextService.swift`
- Test: `SeleneChat/Tests/SessionContextServiceTests.swift`

**Step 1: Write the failing test**

```swift
// SeleneChat/Tests/SessionContextServiceTests.swift
import XCTest
@testable import SeleneChat

final class SessionContextServiceTests: XCTestCase {

    func testBuildContextFromEmptySession() {
        let service = SessionContextService()
        let session = ChatSession()

        let context = service.buildConversationContext(from: session)

        XCTAssertEqual(context, "")
    }

    func testBuildContextFromSingleExchange() {
        let service = SessionContextService()
        var session = ChatSession()

        session.addMessage(Message(role: .user, content: "Hello", llmTier: .local))
        session.addMessage(Message(role: .assistant, content: "Hi there!", llmTier: .local))

        let context = service.buildConversationContext(from: session)

        XCTAssertTrue(context.contains("User: Hello"))
        XCTAssertTrue(context.contains("Selene: Hi there!"))
    }

    func testBuildContextPreservesOrder() {
        let service = SessionContextService()
        var session = ChatSession()

        session.addMessage(Message(role: .user, content: "First", llmTier: .local))
        session.addMessage(Message(role: .assistant, content: "Response 1", llmTier: .local))
        session.addMessage(Message(role: .user, content: "Second", llmTier: .local))
        session.addMessage(Message(role: .assistant, content: "Response 2", llmTier: .local))

        let context = service.buildConversationContext(from: session)

        // Verify order: First should appear before Second
        let firstIndex = context.range(of: "First")?.lowerBound
        let secondIndex = context.range(of: "Second")?.lowerBound

        XCTAssertNotNil(firstIndex)
        XCTAssertNotNil(secondIndex)
        XCTAssertTrue(firstIndex! < secondIndex!)
    }
}
```

**Step 2: Run test to verify it fails**

```bash
cd SeleneChat && swift test --filter SessionContextServiceTests
```

Expected: FAIL with "No such module 'SeleneChat'" or "SessionContextService not found"

**Step 3: Write minimal implementation**

```swift
// SeleneChat/Sources/Services/SessionContextService.swift
import Foundation

/// Builds conversation context from session history for inclusion in LLM prompts
class SessionContextService {

    // Token budget (rough: 1 token ≈ 4 characters)
    // Reserve ~2000 tokens for conversation history
    private let maxContextTokens = 2000
    private let maxContextChars: Int

    init() {
        self.maxContextChars = maxContextTokens * 4
    }

    /// Build conversation context string from session messages
    /// - Parameter session: The current chat session
    /// - Returns: Formatted conversation history string
    func buildConversationContext(from session: ChatSession) -> String {
        let messages = session.messages

        guard !messages.isEmpty else {
            return ""
        }

        var contextLines: [String] = []

        for message in messages {
            let roleName = message.role == .user ? "User" : "Selene"
            contextLines.append("\(roleName): \(message.content)")
        }

        return contextLines.joined(separator: "\n\n")
    }
}
```

**Step 4: Run test to verify it passes**

```bash
cd SeleneChat && swift test --filter SessionContextServiceTests
```

Expected: PASS (3 tests)

**Step 5: Commit**

```bash
cd SeleneChat
git add Sources/Services/SessionContextService.swift Tests/SessionContextServiceTests.swift
git commit -m "feat(selenechat): add SessionContextService for conversation memory"
```

---

## Task 2: Add Context Compression

**Files:**
- Modify: `SeleneChat/Sources/Services/SessionContextService.swift`
- Modify: `SeleneChat/Tests/SessionContextServiceTests.swift`

**Step 1: Write the failing test**

```swift
// Add to SessionContextServiceTests.swift

func testContextCompressesWhenTooLong() {
    let service = SessionContextService(maxContextTokens: 50) // ~200 chars
    var session = ChatSession()

    // Add many messages to exceed budget
    for i in 1...10 {
        session.addMessage(Message(role: .user, content: "This is message number \(i) from the user", llmTier: .local))
        session.addMessage(Message(role: .assistant, content: "This is response number \(i) from the assistant", llmTier: .local))
    }

    let context = service.buildConversationContext(from: session)

    // Context should be under budget
    XCTAssertLessThan(context.count, 250) // Some buffer

    // Most recent messages should be preserved
    XCTAssertTrue(context.contains("message number 10"))
    XCTAssertTrue(context.contains("response number 10"))
}

func testContextPreservesRecentTurns() {
    let service = SessionContextService(maxContextTokens: 100) // ~400 chars
    var session = ChatSession()

    // Add enough messages to trigger compression
    for i in 1...8 {
        session.addMessage(Message(role: .user, content: "User message \(i)", llmTier: .local))
        session.addMessage(Message(role: .assistant, content: "Assistant response \(i)", llmTier: .local))
    }

    let context = service.buildConversationContext(from: session)

    // Last 2-3 exchanges should always be verbatim
    XCTAssertTrue(context.contains("User message 8"))
    XCTAssertTrue(context.contains("Assistant response 8"))
    XCTAssertTrue(context.contains("User message 7"))
}
```

**Step 2: Run test to verify it fails**

```bash
cd SeleneChat && swift test --filter testContextCompresses
```

Expected: FAIL - context exceeds budget

**Step 3: Update implementation with compression**

```swift
// SeleneChat/Sources/Services/SessionContextService.swift
import Foundation

/// Builds conversation context from session history for inclusion in LLM prompts
class SessionContextService {

    private let maxContextTokens: Int
    private let maxContextChars: Int
    private let recentTurnsToPreserve = 4 // Keep last 4 messages verbatim

    init(maxContextTokens: Int = 2000) {
        self.maxContextTokens = maxContextTokens
        self.maxContextChars = maxContextTokens * 4
    }

    /// Build conversation context string from session messages
    /// Compresses older turns if context exceeds token budget
    func buildConversationContext(from session: ChatSession) -> String {
        let messages = session.messages

        guard !messages.isEmpty else {
            return ""
        }

        // If few messages, return all verbatim
        if messages.count <= recentTurnsToPreserve {
            return formatMessages(messages)
        }

        // Split into older and recent
        let splitIndex = messages.count - recentTurnsToPreserve
        let olderMessages = Array(messages.prefix(splitIndex))
        let recentMessages = Array(messages.suffix(recentTurnsToPreserve))

        // Format recent messages (always verbatim)
        let recentContext = formatMessages(recentMessages)

        // Calculate remaining budget for older messages
        let recentChars = recentContext.count
        let remainingBudget = maxContextChars - recentChars - 100 // Buffer for summary header

        if remainingBudget <= 0 {
            // No room for older context
            return recentContext
        }

        // Compress older messages to fit budget
        let olderContext = compressMessages(olderMessages, maxChars: remainingBudget)

        if olderContext.isEmpty {
            return recentContext
        }

        return """
        [Earlier in conversation:]
        \(olderContext)

        [Recent:]
        \(recentContext)
        """
    }

    /// Format messages as conversation context
    private func formatMessages(_ messages: [Message]) -> String {
        var lines: [String] = []

        for message in messages {
            let roleName = message.role == .user ? "User" : "Selene"
            lines.append("\(roleName): \(message.content)")
        }

        return lines.joined(separator: "\n\n")
    }

    /// Compress messages to fit within character budget
    /// Keeps most recent messages, truncates older ones
    private func compressMessages(_ messages: [Message], maxChars: Int) -> String {
        guard !messages.isEmpty else { return "" }

        var result: [String] = []
        var totalChars = 0

        // Process from newest to oldest, stop when budget exceeded
        for message in messages.reversed() {
            let roleName = message.role == .user ? "User" : "Selene"
            // Truncate long messages
            let truncatedContent = String(message.content.prefix(100))
            let suffix = message.content.count > 100 ? "..." : ""
            let line = "\(roleName): \(truncatedContent)\(suffix)"

            if totalChars + line.count + 2 > maxChars {
                break
            }

            result.insert(line, at: 0)
            totalChars += line.count + 2 // +2 for newlines
        }

        return result.joined(separator: "\n")
    }
}
```

**Step 4: Run tests to verify they pass**

```bash
cd SeleneChat && swift test --filter SessionContextServiceTests
```

Expected: PASS (5 tests)

**Step 5: Commit**

```bash
git add SeleneChat/Sources/Services/SessionContextService.swift SeleneChat/Tests/SessionContextServiceTests.swift
git commit -m "feat(selenechat): add context compression to SessionContextService"
```

---

## Task 3: Integrate into ChatViewModel

**Files:**
- Modify: `SeleneChat/Sources/Services/ChatViewModel.swift`

**Step 1: Add SessionContextService to ChatViewModel**

Add the service as a property and use it in `handleOllamaQuery`:

```swift
// In ChatViewModel.swift, add property:
private let sessionContextService = SessionContextService()
```

**Step 2: Modify handleOllamaQuery to include conversation context**

Find the `handleOllamaQuery` method and update the prompt building:

```swift
// In handleOllamaQuery, before building fullPrompt, add:
let conversationContext = sessionContextService.buildConversationContext(from: currentSession)

// Then modify fullPrompt to include conversation context:
let fullPrompt: String
if conversationContext.isEmpty {
    fullPrompt = """
    \(systemPrompt)

    Notes:
    \(noteContext)

    Question: \(query)
    """
} else {
    fullPrompt = """
    \(systemPrompt)

    Conversation so far:
    \(conversationContext)

    Notes:
    \(noteContext)

    Question: \(query)
    """
}
```

**Step 3: Build to verify compilation**

```bash
cd SeleneChat && swift build
```

Expected: Build succeeds

**Step 4: Manual test**

1. Run the app: `swift run`
2. Send a message: "My name is Chase"
3. Send follow-up: "What's my name?"
4. Verify Selene remembers the name

**Step 5: Commit**

```bash
git add SeleneChat/Sources/Services/ChatViewModel.swift
git commit -m "feat(selenechat): integrate conversation context into Ollama queries"
```

---

## Task 4: Add Conversation Context Header to System Prompt

**Files:**
- Modify: `SeleneChat/Sources/Services/ChatViewModel.swift`

**Step 1: Update system prompt to explain conversation context**

Add instruction about using conversation history:

```swift
// In buildSystemPrompt method, add after the base prompt:

basePrompt += """

CONVERSATION MEMORY:
You have access to the conversation history above. Use it to:
- Remember what the user said earlier
- Refer back to previous topics naturally
- Build on prior discussion
- Maintain continuity in your responses

If the user references something from earlier, acknowledge it. Don't ask them to repeat themselves.

"""
```

**Step 2: Build and test**

```bash
cd SeleneChat && swift build
```

**Step 3: Manual verification**

1. Run app
2. Have multi-turn conversation
3. Verify Selene references prior context naturally

**Step 4: Commit**

```bash
git add SeleneChat/Sources/Services/ChatViewModel.swift
git commit -m "feat(selenechat): update system prompt with conversation memory instructions"
```

---

## Task 5: Final Integration Test

**Files:**
- Create: `SeleneChat/Tests/ConversationMemoryIntegrationTests.swift`

**Step 1: Write integration test**

```swift
// SeleneChat/Tests/ConversationMemoryIntegrationTests.swift
import XCTest
@testable import SeleneChat

final class ConversationMemoryIntegrationTests: XCTestCase {

    func testSessionContextServiceCreatesValidContext() {
        let service = SessionContextService()
        var session = ChatSession()

        // Simulate a conversation
        session.addMessage(Message(role: .user, content: "Tell me about testing", llmTier: .local))
        session.addMessage(Message(role: .assistant, content: "Testing is important for code quality", llmTier: .local))
        session.addMessage(Message(role: .user, content: "What types exist?", llmTier: .local))
        session.addMessage(Message(role: .assistant, content: "Unit, integration, and e2e tests", llmTier: .local))

        let context = service.buildConversationContext(from: session)

        // Verify structure
        XCTAssertTrue(context.contains("User:"))
        XCTAssertTrue(context.contains("Selene:"))
        XCTAssertTrue(context.contains("testing"))
        XCTAssertTrue(context.contains("Unit, integration"))
    }

    func testLongConversationStaysWithinBudget() {
        let service = SessionContextService(maxContextTokens: 500)
        var session = ChatSession()

        // Add 20 exchanges
        for i in 1...20 {
            session.addMessage(Message(
                role: .user,
                content: "This is a longer user message number \(i) that contains some detail about a topic",
                llmTier: .local
            ))
            session.addMessage(Message(
                role: .assistant,
                content: "This is a detailed assistant response number \(i) that provides helpful information",
                llmTier: .local
            ))
        }

        let context = service.buildConversationContext(from: session)

        // Should be under 2500 chars (500 tokens * 4 + some buffer)
        XCTAssertLessThan(context.count, 2500)

        // Most recent should be present
        XCTAssertTrue(context.contains("message number 20"))
    }
}
```

**Step 2: Run all tests**

```bash
cd SeleneChat && swift test
```

Expected: All tests pass

**Step 3: Build release**

```bash
cd SeleneChat && swift build -c release
```

**Step 4: Final commit**

```bash
git add SeleneChat/Tests/ConversationMemoryIntegrationTests.swift
git commit -m "test(selenechat): add conversation memory integration tests"
```

---

## Summary

After completing all tasks, you will have:

1. **SessionContextService** - Builds conversation history from session messages
2. **Context compression** - Older turns are truncated to stay within token budget
3. **ChatViewModel integration** - Each Ollama query includes conversation context
4. **Updated system prompt** - Instructs Selene to use conversation memory
5. **Tests** - Unit and integration tests verify the behavior

**Acceptance Criteria Met:**
- [x] Multi-turn conversation where Selene remembers prior messages
- [x] Context stays within token limits (compresses after ~10 turns)
- [x] Memory clears on app restart (session-scoped)

---

## Next Steps

After Phase 1 is complete, proceed to Phase 2 (Context Builder enhancement) or Phase 3 (Morning Briefing).
