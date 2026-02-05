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
}
