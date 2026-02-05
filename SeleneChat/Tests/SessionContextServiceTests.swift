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
}
