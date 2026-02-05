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

    // MARK: - Briefing Context Tests

    func testBuildBriefingContext() {
        let threads = [
            Thread(
                id: 1,
                name: "Event-Driven Architecture",
                why: "Testing strategies",
                summary: "Exploring event testing",
                status: "active",
                noteCount: 5,
                momentumScore: 0.8,
                lastActivityAt: Date(),
                createdAt: Date()
            ),
            Thread(
                id: 2,
                name: "Project Journey",
                why: nil,
                summary: "Early exploration",
                status: "active",
                noteCount: 3,
                momentumScore: 0.4,
                lastActivityAt: Date().addingTimeInterval(-86400 * 3),
                createdAt: Date()
            )
        ]

        let recentNotes = [
            Note(
                id: 1,
                title: "Testing thoughts",
                content: "Some content about testing",
                contentHash: "abc123",
                sourceType: "drafts",
                wordCount: 5,
                characterCount: 27,
                tags: nil,
                createdAt: Date(),
                importedAt: Date(),
                processedAt: nil,
                exportedAt: nil,
                status: "processed",
                exportedToObsidian: false,
                sourceUUID: nil,
                testRun: nil
            )
        ]

        let builder = ThinkingPartnerContextBuilder()
        let context = builder.buildBriefingContext(threads: threads, recentNotes: recentNotes)

        // Should include threads
        XCTAssertTrue(context.contains("Event-Driven Architecture"))
        XCTAssertTrue(context.contains("Project Journey"))

        // Should include momentum
        XCTAssertTrue(context.contains("Momentum"))

        // Should include recent notes section
        XCTAssertTrue(context.contains("Recent Notes"))
        XCTAssertTrue(context.contains("Testing thoughts"))
    }

    func testBriefingContextRespectsTokenBudget() {
        // Create many threads to exceed budget
        var threads: [SeleneChat.Thread] = []
        for i in 0..<20 {
            threads.append(SeleneChat.Thread(
                id: Int64(i),
                name: "Thread \(i) with a longer name to use more tokens",
                why: "Reason \(i) that is quite detailed",
                summary: "Summary \(i) with substantial content to fill up the token budget",
                status: "active",
                noteCount: i + 1,
                momentumScore: Double(i) / 20.0,
                lastActivityAt: Date(),
                createdAt: Date()
            ))
        }

        let builder = ThinkingPartnerContextBuilder()
        let context = builder.buildBriefingContext(threads: threads, recentNotes: [])

        let tokens = builder.estimateTokens(context)
        XCTAssertLessThanOrEqual(tokens, ThinkingPartnerQueryType.briefing.tokenBudget)
    }

    func testBriefingContextSortsThreadsByMomentum() {
        let threads = [
            Thread(
                id: 1,
                name: "Low Momentum Thread",
                why: nil,
                summary: nil,
                status: "active",
                noteCount: 2,
                momentumScore: 0.2,
                lastActivityAt: Date(),
                createdAt: Date()
            ),
            Thread(
                id: 2,
                name: "High Momentum Thread",
                why: nil,
                summary: nil,
                status: "active",
                noteCount: 10,
                momentumScore: 0.9,
                lastActivityAt: Date(),
                createdAt: Date()
            )
        ]

        let builder = ThinkingPartnerContextBuilder()
        let context = builder.buildBriefingContext(threads: threads, recentNotes: [])

        // High momentum should appear before low momentum
        let highIndex = context.range(of: "High Momentum Thread")!.lowerBound
        let lowIndex = context.range(of: "Low Momentum Thread")!.lowerBound
        XCTAssertLessThan(highIndex, lowIndex)
    }

    func testBriefingContextLimitsRecentNotes() {
        var notes: [Note] = []
        for i in 0..<10 {
            notes.append(Note(
                id: i,
                title: "Note \(i)",
                content: "Content \(i)",
                contentHash: "hash\(i)",
                sourceType: "drafts",
                wordCount: 2,
                characterCount: 10,
                tags: nil,
                createdAt: Date(),
                importedAt: Date(),
                processedAt: nil,
                exportedAt: nil,
                status: "processed",
                exportedToObsidian: false,
                sourceUUID: nil,
                testRun: nil
            ))
        }

        let builder = ThinkingPartnerContextBuilder()
        let context = builder.buildBriefingContext(threads: [], recentNotes: notes)

        // Should only include up to 5 notes
        XCTAssertTrue(context.contains("Note 0"))
        XCTAssertTrue(context.contains("Note 4"))
        XCTAssertFalse(context.contains("Note 5"))
        XCTAssertFalse(context.contains("Note 9"))
    }
}
