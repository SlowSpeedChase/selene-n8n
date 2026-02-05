import XCTest
@testable import SeleneChat

final class ThinkingPartnerContextBuilderTests: XCTestCase {

    func testFormatThreadForContext() {
        let thread = Thread(
            id: 1,
            name: "Event-Driven Architecture",
            why: "Exploring testing strategies",
            summary: "Notes about event testing approaches",
            status: "active",
            noteCount: 5,
            momentumScore: 0.8,
            lastActivityAt: Date(),
            createdAt: Date()
        )

        let builder = ThinkingPartnerContextBuilder()
        let formatted = builder.formatThread(thread)

        XCTAssertTrue(formatted.contains("Event-Driven Architecture"))
        XCTAssertTrue(formatted.contains("active"))
        XCTAssertTrue(formatted.contains("5 notes"))
        XCTAssertTrue(formatted.contains("0.8"))
    }

    func testEstimateTokens() {
        let builder = ThinkingPartnerContextBuilder()
        let text = "Hello world this is a test"  // 26 chars
        let tokens = builder.estimateTokens(text)

        XCTAssertEqual(tokens, 6)  // 26 / 4 = 6
    }

    func testTruncateToFit() {
        let builder = ThinkingPartnerContextBuilder()
        let longText = String(repeating: "a", count: 100)  // 100 chars = 25 tokens

        let truncated = builder.truncateToFit(longText, maxTokens: 10)  // 10 tokens = 40 chars
        // 40 chars + "\n[Truncated for token limit]" (28 chars) = 68 chars max
        XCTAssertLessThanOrEqual(truncated.count, 70)
        XCTAssertTrue(truncated.contains("[Truncated for token limit]"))
    }
}
