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
        let firstIndex = context.range(of: "First")?.lowerBound
        let secondIndex = context.range(of: "Second")?.lowerBound
        XCTAssertNotNil(firstIndex)
        XCTAssertNotNil(secondIndex)
        XCTAssertTrue(firstIndex! < secondIndex!)
    }

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
        XCTAssertLessThan(context.count, 250)

        // Most recent messages should be preserved
        XCTAssertTrue(context.contains("message number 10"))
        XCTAssertTrue(context.contains("response number 10"))
    }

    func testContextPreservesRecentTurns() {
        let service = SessionContextService(maxContextTokens: 100) // ~400 chars
        var session = ChatSession()

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
}
