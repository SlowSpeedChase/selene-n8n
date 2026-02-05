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

        // Add 12 messages (6 turns) - should trigger summary for first 2 turns
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
