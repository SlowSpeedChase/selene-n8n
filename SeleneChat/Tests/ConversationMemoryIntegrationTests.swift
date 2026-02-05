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
