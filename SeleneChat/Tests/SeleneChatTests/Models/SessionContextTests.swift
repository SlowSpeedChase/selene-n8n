import SeleneShared
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

        XCTAssertGreaterThan(context.estimatedTokens, 0)
        XCTAssertLessThan(context.estimatedTokens, 100)
    }

    // MARK: - Truncation Tests

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

    func testTruncationEmptyMessages() {
        let context = SessionContext(messages: [])
        let truncated = context.truncatedHistory(maxTokens: 500)

        XCTAssertEqual(truncated, "")
    }

    func testTruncationAllMessagesFit() {
        let messages = [
            Message(role: .user, content: "Hello", llmTier: .local),
            Message(role: .assistant, content: "Hi", llmTier: .local)
        ]

        let context = SessionContext(messages: messages)
        let truncated = context.truncatedHistory(maxTokens: 1000)

        // All messages should be included when they fit
        XCTAssertTrue(truncated.contains("Hello"))
        XCTAssertTrue(truncated.contains("Hi"))
    }

    // MARK: - Summary Tests

    func testSummarizedHistory() {
        // 12 messages - first 4 should be summarized, last 8 verbatim (4 turns)
        var messages: [Message] = []
        for i in 0..<6 {
            messages.append(Message(role: .user, content: "Topic \(i): discussion about subject \(i)", llmTier: .local))
            messages.append(Message(role: .assistant, content: "Response about topic \(i)", llmTier: .local))
        }

        let context = SessionContext(messages: messages)
        let result = context.historyWithSummary(recentTurnCount: 4)

        // Should have summary marker for old messages
        XCTAssertTrue(result.contains("[Earlier in conversation:"))

        // Most recent 4 turns (8 messages) should be verbatim
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

    func testSummaryDefaultTurnCount() {
        // Verify the default parameter uses recentTurnsVerbatim constant
        XCTAssertEqual(SessionContext.recentTurnsVerbatim, 4)
    }

    func testSummaryExtractsTopicsFromUserMessages() {
        var messages: [Message] = []
        // Create 10 messages (5 turns) so we have something to summarize with default of 4 turns
        for i in 0..<5 {
            messages.append(Message(role: .user, content: "Question about Swift programming topic \(i)", llmTier: .local))
            messages.append(Message(role: .assistant, content: "Here's the answer for topic \(i)", llmTier: .local))
        }

        let context = SessionContext(messages: messages)
        let result = context.historyWithSummary(recentTurnCount: 4)

        // Should extract topics from first turn's user message
        XCTAssertTrue(result.contains("[Earlier in conversation:"))
        XCTAssertTrue(result.contains("Question about Swift programming"))
    }

    func testSummaryEmptyMessages() {
        let context = SessionContext(messages: [])
        let result = context.historyWithSummary()

        XCTAssertEqual(result, "")
    }
}
