# Conversation Memory (Phase 1) Implementation Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** Enable multi-turn conversations where Selene remembers what was said earlier in the session.

**Architecture:** Add a `SessionContext` service that formats conversation history for LLM prompts, with compression for older turns to stay within token limits. Integrate into existing `ChatViewModel.handleOllamaQuery()` flow.

**Tech Stack:** Swift 5.9, SwiftUI, Ollama API (mistral:7b)

---

## Overview

Currently, each query to Ollama is independent - Selene doesn't know what was said 2 messages ago. This plan adds session-scoped conversation memory by:

1. Creating a `SessionContext` service to format conversation history
2. Integrating history into the Ollama prompt
3. Compressing older turns when approaching token limits

**Key Design Decisions:**
- Session-scoped (resets on new session, not app restart)
- Recent turns verbatim, older turns summarized
- ~10 turns before compression kicks in
- No database changes needed (messages already in `ChatSession`)

---

## Task 1: Create SessionContext Model

**Files:**
- Create: `SeleneChat/Sources/Models/SessionContext.swift`
- Test: `SeleneChat/Tests/SeleneChatTests/Models/SessionContextTests.swift`

**Step 1: Write the failing test**

```swift
// SessionContextTests.swift
import XCTest
@testable import SeleneChat

final class SessionContextTests: XCTestCase {

    func testFormatMessagesEmpty() {
        let context = SessionContext(messages: [])
        XCTAssertEqual(context.formattedHistory, "")
    }

    func testFormatMessagesSingleTurn() {
        let messages = [
            Message(role: .user, content: "Hello", llmTier: .local),
            Message(role: .assistant, content: "Hi there!", llmTier: .local)
        ]
        let context = SessionContext(messages: messages)

        XCTAssertTrue(context.formattedHistory.contains("User: Hello"))
        XCTAssertTrue(context.formattedHistory.contains("Selene: Hi there!"))
    }

    func testEstimatedTokenCount() {
        let messages = [
            Message(role: .user, content: "Hello world", llmTier: .local)
        ]
        let context = SessionContext(messages: messages)

        // Rough estimate: ~4 chars per token
        XCTAssertGreaterThan(context.estimatedTokens, 0)
        XCTAssertLessThan(context.estimatedTokens, 100)
    }
}
```

**Step 2: Run test to verify it fails**

Run: `cd SeleneChat && swift test --filter SessionContextTests`
Expected: FAIL - "no such module 'SeleneChat'" or "SessionContext not found"

**Step 3: Write minimal implementation**

```swift
// SessionContext.swift
import Foundation

/// Manages conversation context for LLM prompts
struct SessionContext {
    let messages: [Message]

    /// Maximum tokens to allocate for conversation history
    static let maxHistoryTokens = 2000

    /// Format messages for inclusion in LLM prompt
    var formattedHistory: String {
        guard !messages.isEmpty else { return "" }

        return messages.map { message in
            let role = message.role == .user ? "User" : "Selene"
            return "\(role): \(message.content)"
        }.joined(separator: "\n\n")
    }

    /// Rough token estimate (4 chars per token)
    var estimatedTokens: Int {
        let totalChars = formattedHistory.count
        return totalChars / 4
    }
}
```

**Step 4: Run test to verify it passes**

Run: `cd SeleneChat && swift test --filter SessionContextTests`
Expected: PASS

**Step 5: Commit**

```bash
git add SeleneChat/Sources/Models/SessionContext.swift SeleneChat/Tests/SeleneChatTests/Models/SessionContextTests.swift
git commit -m "$(cat <<'EOF'
feat(selenechat): add SessionContext model for conversation history

Part of Thinking Partner Phase 1 - Conversation Memory

Co-Authored-By: Claude Opus 4.5 <noreply@anthropic.com>
EOF
)"
```

---

## Task 2: Add History Truncation

**Files:**
- Modify: `SeleneChat/Sources/Models/SessionContext.swift`
- Modify: `SeleneChat/Tests/SeleneChatTests/Models/SessionContextTests.swift`

**Step 1: Write the failing test**

```swift
// Add to SessionContextTests.swift
func testTruncateToFitLimit() {
    // Create many messages that exceed token limit
    var messages: [Message] = []
    for i in 0..<20 {
        messages.append(Message(role: .user, content: "This is message number \(i) with some content", llmTier: .local))
        messages.append(Message(role: .assistant, content: "Response to message \(i) with details", llmTier: .local))
    }

    let context = SessionContext(messages: messages)
    let truncated = context.truncatedHistory(maxTokens: 500)

    // Should be under the limit
    let truncatedTokens = truncated.count / 4
    XCTAssertLessThanOrEqual(truncatedTokens, 500)

    // Should preserve most recent messages
    XCTAssertTrue(truncated.contains("message number 19"))
}

func testTruncationPreservesRecentMessages() {
    let messages = [
        Message(role: .user, content: "Old message", llmTier: .local),
        Message(role: .assistant, content: "Old response", llmTier: .local),
        Message(role: .user, content: "Recent message", llmTier: .local),
        Message(role: .assistant, content: "Recent response", llmTier: .local)
    ]

    let context = SessionContext(messages: messages)
    let truncated = context.truncatedHistory(maxTokens: 50)

    // Most recent should always be included
    XCTAssertTrue(truncated.contains("Recent"))
}
```

**Step 2: Run test to verify it fails**

Run: `cd SeleneChat && swift test --filter SessionContextTests`
Expected: FAIL - "truncatedHistory method not found"

**Step 3: Write minimal implementation**

```swift
// Add to SessionContext.swift

/// Get history truncated to fit within token limit, preserving recent messages
func truncatedHistory(maxTokens: Int) -> String {
    guard !messages.isEmpty else { return "" }

    var result: [String] = []
    var currentTokens = 0

    // Process messages from most recent to oldest
    for message in messages.reversed() {
        let role = message.role == .user ? "User" : "Selene"
        let formatted = "\(role): \(message.content)"
        let messageTokens = formatted.count / 4

        if currentTokens + messageTokens > maxTokens {
            break
        }

        result.insert(formatted, at: 0)
        currentTokens += messageTokens
    }

    return result.joined(separator: "\n\n")
}
```

**Step 4: Run test to verify it passes**

Run: `cd SeleneChat && swift test --filter SessionContextTests`
Expected: PASS

**Step 5: Commit**

```bash
git add SeleneChat/Sources/Models/SessionContext.swift SeleneChat/Tests/SeleneChatTests/Models/SessionContextTests.swift
git commit -m "$(cat <<'EOF'
feat(selenechat): add history truncation to SessionContext

Preserves most recent messages when history exceeds token limit.
Part of Thinking Partner Phase 1.

Co-Authored-By: Claude Opus 4.5 <noreply@anthropic.com>
EOF
)"
```

---

## Task 3: Add Conversation Summary for Old Messages

**Files:**
- Modify: `SeleneChat/Sources/Models/SessionContext.swift`
- Modify: `SeleneChat/Tests/SeleneChatTests/Models/SessionContextTests.swift`

**Step 1: Write the failing test**

```swift
// Add to SessionContextTests.swift
func testSummarizedHistory() {
    // 12 messages - first 8 should be summarized, last 4 verbatim
    var messages: [Message] = []
    for i in 0..<6 {
        messages.append(Message(role: .user, content: "Topic \(i): discussion about subject \(i)", llmTier: .local))
        messages.append(Message(role: .assistant, content: "Response about topic \(i)", llmTier: .local))
    }

    let context = SessionContext(messages: messages)
    let result = context.historyWithSummary(recentTurnCount: 4)

    // Should have summary marker for old messages
    XCTAssertTrue(result.contains("[Earlier in conversation:"))

    // Most recent 4 messages should be verbatim
    XCTAssertTrue(result.contains("Topic 5"))
    XCTAssertTrue(result.contains("Topic 4"))
}

func testNoSummaryWhenFewMessages() {
    let messages = [
        Message(role: .user, content: "Hello", llmTier: .local),
        Message(role: .assistant, content: "Hi!", llmTier: .local)
    ]

    let context = SessionContext(messages: messages)
    let result = context.historyWithSummary(recentTurnCount: 4)

    // No summary needed for few messages
    XCTAssertFalse(result.contains("[Earlier"))
    XCTAssertTrue(result.contains("Hello"))
}
```

**Step 2: Run test to verify it fails**

Run: `cd SeleneChat && swift test --filter SessionContextTests`
Expected: FAIL - "historyWithSummary method not found"

**Step 3: Write minimal implementation**

```swift
// Add to SessionContext.swift

/// Number of recent turns to keep verbatim (1 turn = user + assistant)
static let recentTurnsVerbatim = 4

/// Get history with older messages summarized
/// - Parameter recentTurnCount: Number of recent message pairs to keep verbatim
func historyWithSummary(recentTurnCount: Int = SessionContext.recentTurnsVerbatim) -> String {
    guard !messages.isEmpty else { return "" }

    let recentMessageCount = recentTurnCount * 2  // user + assistant per turn

    // If we have few enough messages, just return them all
    if messages.count <= recentMessageCount {
        return formattedHistory
    }

    // Split into old and recent
    let oldMessages = Array(messages.prefix(messages.count - recentMessageCount))
    let recentMessages = Array(messages.suffix(recentMessageCount))

    // Summarize old messages (simple extraction for now - LLM summary in Phase 2)
    let oldTopics = extractTopics(from: oldMessages)
    let summary = "[Earlier in conversation: \(oldTopics)]"

    // Format recent messages verbatim
    let recentFormatted = recentMessages.map { message in
        let role = message.role == .user ? "User" : "Selene"
        return "\(role): \(message.content)"
    }.joined(separator: "\n\n")

    return "\(summary)\n\n\(recentFormatted)"
}

/// Extract key topics from messages (simple heuristic for now)
private func extractTopics(from messages: [Message]) -> String {
    let userMessages = messages.filter { $0.role == .user }

    // Take first few words from each user message as topic hints
    let topics = userMessages.map { message in
        let words = message.content.split(separator: " ").prefix(5)
        return words.joined(separator: " ")
    }

    if topics.isEmpty {
        return "general discussion"
    }

    return topics.joined(separator: "; ")
}
```

**Step 4: Run test to verify it passes**

Run: `cd SeleneChat && swift test --filter SessionContextTests`
Expected: PASS

**Step 5: Commit**

```bash
git add SeleneChat/Sources/Models/SessionContext.swift SeleneChat/Tests/SeleneChatTests/Models/SessionContextTests.swift
git commit -m "$(cat <<'EOF'
feat(selenechat): add conversation summary for older messages

Keeps recent messages verbatim, summarizes older ones to save tokens.
Part of Thinking Partner Phase 1.

Co-Authored-By: Claude Opus 4.5 <noreply@anthropic.com>
EOF
)"
```

---

## Task 4: Integrate SessionContext into ChatViewModel

**Files:**
- Modify: `SeleneChat/Sources/Services/ChatViewModel.swift`

**Step 1: Identify integration point**

The integration happens in `handleOllamaQuery()` where the prompt is built. We need to:
1. Create SessionContext from current session messages (excluding the current query)
2. Add formatted history to the prompt

**Step 2: Modify handleOllamaQuery**

Find this section in `handleOllamaQuery()`:

```swift
// Build full prompt
let fullPrompt = """
\(systemPrompt)

Notes:
\(noteContext)

Question: \(context)
"""
```

Replace with:

```swift
// Build conversation history (excluding current message which is in context)
let priorMessages = Array(currentSession.messages.dropLast())  // Remove current user message
let sessionContext = SessionContext(messages: priorMessages)
let historySection: String
if priorMessages.isEmpty {
    historySection = ""
} else {
    historySection = """

    ## Conversation so far:
    \(sessionContext.historyWithSummary())

    """
}

// Build full prompt
let fullPrompt = """
\(systemPrompt)
\(historySection)
Notes:
\(noteContext)

Question: \(context)
"""
```

**Step 3: Test manually**

Build the app:
```bash
cd SeleneChat && swift build
```

Run the app and test multi-turn conversation:
1. Ask: "What notes do I have about projects?"
2. Follow up: "Tell me more about the first one"
3. Selene should reference the previous context

**Step 4: Commit**

```bash
git add SeleneChat/Sources/Services/ChatViewModel.swift
git commit -m "$(cat <<'EOF'
feat(selenechat): integrate conversation history into Ollama prompts

Selene now remembers prior messages in the session. Recent turns are
verbatim, older turns are summarized to fit token limits.

Part of Thinking Partner Phase 1.

Co-Authored-By: Claude Opus 4.5 <noreply@anthropic.com>
EOF
)"
```

---

## Task 5: Add Conversation History Toggle

**Files:**
- Modify: `SeleneChat/Sources/Services/ChatViewModel.swift`

**Step 1: Add toggle property**

Add after the existing `@Published` properties:

```swift
/// Whether to include conversation history in prompts
@Published var useConversationHistory = true
```

**Step 2: Make history conditional**

In the code added in Task 4, wrap the history section:

```swift
// Build conversation history (excluding current message)
let historySection: String
if useConversationHistory {
    let priorMessages = Array(currentSession.messages.dropLast())
    let sessionContext = SessionContext(messages: priorMessages)
    if priorMessages.isEmpty {
        historySection = ""
    } else {
        historySection = """

        ## Conversation so far:
        \(sessionContext.historyWithSummary())

        """
    }
} else {
    historySection = ""
}
```

**Step 3: Commit**

```bash
git add SeleneChat/Sources/Services/ChatViewModel.swift
git commit -m "$(cat <<'EOF'
feat(selenechat): add toggle for conversation history in prompts

Allows disabling history injection for debugging or when fresh
context is desired.

Co-Authored-By: Claude Opus 4.5 <noreply@anthropic.com>
EOF
)"
```

---

## Task 6: Integration Test - Multi-Turn Conversation

**Files:**
- Create: `SeleneChat/Tests/SeleneChatTests/Integration/ConversationMemoryIntegrationTests.swift`

**Step 1: Write integration test**

```swift
// ConversationMemoryIntegrationTests.swift
import XCTest
@testable import SeleneChat

final class ConversationMemoryIntegrationTests: XCTestCase {

    func testSessionContextBuildsFromChatSession() {
        // Create a chat session with messages
        var session = ChatSession()
        session.addMessage(Message(role: .user, content: "What are my active threads?", llmTier: .local))
        session.addMessage(Message(role: .assistant, content: "You have 2 active threads: Project Planning and Health Goals.", llmTier: .local))
        session.addMessage(Message(role: .user, content: "Tell me about the first one", llmTier: .local))

        // Build context from session (excluding last message - the current query)
        let priorMessages = Array(session.messages.dropLast())
        let context = SessionContext(messages: priorMessages)

        // History should include the first exchange
        XCTAssertTrue(context.formattedHistory.contains("active threads"))
        XCTAssertTrue(context.formattedHistory.contains("Project Planning"))

        // Should NOT include the current query
        XCTAssertFalse(context.formattedHistory.contains("first one"))
    }

    func testHistoryTokenEstimation() {
        var session = ChatSession()

        // Add multiple turns
        for i in 0..<10 {
            session.addMessage(Message(role: .user, content: "Question \(i) about topic", llmTier: .local))
            session.addMessage(Message(role: .assistant, content: "Answer \(i) with explanation", llmTier: .local))
        }

        let context = SessionContext(messages: session.messages)

        // Should estimate tokens reasonably
        XCTAssertGreaterThan(context.estimatedTokens, 50)
        XCTAssertLessThan(context.estimatedTokens, 1000)
    }

    func testSummaryKicksInAfterThreshold() {
        var session = ChatSession()

        // Add 12 messages (6 turns) - should trigger summary for first 4
        for i in 0..<6 {
            session.addMessage(Message(role: .user, content: "Topic \(i): detailed question", llmTier: .local))
            session.addMessage(Message(role: .assistant, content: "Response \(i): detailed answer", llmTier: .local))
        }

        let context = SessionContext(messages: session.messages)
        let result = context.historyWithSummary(recentTurnCount: 4)

        // Should have summary section
        XCTAssertTrue(result.contains("[Earlier in conversation:"))

        // Recent 4 turns (8 messages) should be verbatim
        XCTAssertTrue(result.contains("Topic 4"))
        XCTAssertTrue(result.contains("Topic 5"))
        XCTAssertTrue(result.contains("Response 4"))
        XCTAssertTrue(result.contains("Response 5"))
    }
}
```

**Step 2: Run tests**

Run: `cd SeleneChat && swift test --filter ConversationMemoryIntegrationTests`
Expected: PASS

**Step 3: Commit**

```bash
git add SeleneChat/Tests/SeleneChatTests/Integration/ConversationMemoryIntegrationTests.swift
git commit -m "$(cat <<'EOF'
test(selenechat): add conversation memory integration tests

Verifies SessionContext works correctly with ChatSession.

Co-Authored-By: Claude Opus 4.5 <noreply@anthropic.com>
EOF
)"
```

---

## Task 7: Manual End-to-End Verification

**Files:** None (manual testing)

**Step 1: Build and install**

```bash
cd SeleneChat
./build-app.sh
cp -R .build/release/SeleneChat.app /Applications/
```

**Step 2: Test scenarios**

Open SeleneChat and test these scenarios:

1. **Basic memory test:**
   - Ask: "What are my active threads?"
   - Follow up: "Tell me more about the first one"
   - Expected: Selene references the thread from the first response

2. **Topic continuity:**
   - Ask: "Show me notes about ADHD"
   - Ask: "How do those relate to productivity?"
   - Expected: Selene maintains context about ADHD notes

3. **Long conversation:**
   - Have 10+ exchanges
   - Ask: "What have we been talking about?"
   - Expected: Selene summarizes the conversation topics

4. **New session clears memory:**
   - Start new session (Cmd+N or click New Chat)
   - Ask: "What did we just discuss?"
   - Expected: Selene doesn't know - new session

**Step 3: Document any issues**

If issues found, create bug tasks. Otherwise, proceed to completion.

---

## Task 8: Update Documentation

**Files:**
- Modify: `docs/plans/2026-02-05-selene-thinking-partner-design.md`
- Modify: `.claude/PROJECT-STATUS.md`

**Step 1: Update design doc**

Update the Phase 1 acceptance criteria in the design doc:

```markdown
### Phase 1: Conversation Memory (Foundation) ✅ COMPLETE

**Components:**
- `SessionContext` model - stores turns, provides formatted history
- Token-aware truncation - keeps recent turns verbatim
- Summary generation for older turns (simple heuristic)
- Integration with `ChatViewModel`

**Acceptance Criteria:**
- [x] Can have multi-turn conversation where Selene remembers prior messages
- [x] Context stays within token limits (compress after ~10 turns)
- [x] Memory clears on new session (not app restart)
```

**Step 2: Update PROJECT-STATUS.md**

Add to Recent Achievements:

```markdown
### 2026-02-05
- **Thinking Partner Phase 1 Complete** - Conversation Memory
  - `SessionContext` model for formatting conversation history
  - Token-aware truncation preserves recent messages
  - Simple summary for older turns
  - Integrated into `ChatViewModel.handleOllamaQuery()`
  - Multi-turn conversations now work
```

**Step 3: Commit**

```bash
git add docs/plans/2026-02-05-selene-thinking-partner-design.md .claude/PROJECT-STATUS.md
git commit -m "$(cat <<'EOF'
docs: mark Thinking Partner Phase 1 complete

- SessionContext model with truncation and summary
- Integrated into ChatViewModel
- Multi-turn conversations working

Co-Authored-By: Claude Opus 4.5 <noreply@anthropic.com>
EOF
)"
```

---

## Acceptance Criteria Verification

After completing all tasks, verify:

- [x] **Can have multi-turn conversation where Selene remembers prior messages**
  - Test: Ask follow-up questions that reference previous answers
  - Verified in: Task 7 manual testing

- [x] **Context stays within token limits (compress after ~10 turns)**
  - Test: Have 15+ exchanges, check prompt doesn't explode
  - Verified in: Task 2, Task 6 tests

- [x] **Memory clears on new session**
  - Test: Start new session, prior context should be gone
  - Verified in: Task 7 manual testing (new session clears `currentSession.messages`)

---

## Summary

**Files Created:**
- `SeleneChat/Sources/Models/SessionContext.swift`
- `SeleneChat/Tests/SeleneChatTests/Models/SessionContextTests.swift`
- `SeleneChat/Tests/SeleneChatTests/Integration/ConversationMemoryIntegrationTests.swift`

**Files Modified:**
- `SeleneChat/Sources/Services/ChatViewModel.swift`
- `docs/plans/2026-02-05-selene-thinking-partner-design.md`
- `.claude/PROJECT-STATUS.md`

**Total Commits:** 8
