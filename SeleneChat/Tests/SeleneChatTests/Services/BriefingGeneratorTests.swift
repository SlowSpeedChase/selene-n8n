import XCTest
@testable import SeleneChat

final class BriefingGeneratorTests: XCTestCase {

    // MARK: - buildBriefingPrompt Tests

    func testBriefingPromptIncludesThreadContext() {
        let threads = [
            Thread.mock(
                id: 1,
                name: "Event-Driven Architecture",
                summary: "Exploring event testing approaches",
                status: "active",
                noteCount: 5,
                momentumScore: 0.8
            ),
            Thread.mock(
                id: 2,
                name: "Project Journey",
                summary: "Early exploration",
                status: "active",
                noteCount: 3,
                momentumScore: 0.4
            )
        ]

        let recentNotes = [
            Note.mock(
                id: 1,
                title: "Testing thoughts",
                content: "Some content about testing"
            ),
            Note.mock(
                id: 2,
                title: "Architecture ideas",
                content: "Some architecture content"
            )
        ]

        let generator = BriefingGenerator()
        let prompt = generator.buildBriefingPrompt(threads: threads, recentNotes: recentNotes)

        // Should include thread names
        XCTAssertTrue(prompt.contains("Event-Driven Architecture"), "Prompt should include thread name")
        XCTAssertTrue(prompt.contains("Project Journey"), "Prompt should include thread name")

        // Should include note titles
        XCTAssertTrue(prompt.contains("Testing thoughts"), "Prompt should include note title")
        XCTAssertTrue(prompt.contains("Architecture ideas"), "Prompt should include note title")

        // Should include system prompt about ADHD thinking partner
        XCTAssertTrue(prompt.lowercased().contains("adhd"), "Prompt should mention ADHD")
        XCTAssertTrue(prompt.lowercased().contains("thinking partner"), "Prompt should mention thinking partner")

        // Should include briefing instructions
        XCTAssertTrue(prompt.lowercased().contains("morning") || prompt.lowercased().contains("briefing"), "Prompt should mention briefing")
        XCTAssertTrue(prompt.contains("150"), "Prompt should mention 150 word limit")
    }

    func testBriefingPromptLimitsThreadCount() {
        // Create 10 threads with varying momentum scores
        var threads: [SeleneChat.Thread] = []
        for i in 0..<10 {
            threads.append(SeleneChat.Thread.mock(
                id: Int64(i),
                name: "Thread \(i)",
                summary: "Summary for thread \(i)",
                status: "active",
                noteCount: i + 1,
                momentumScore: Double(i) / 10.0  // 0.0, 0.1, 0.2, ... 0.9
            ))
        }

        let generator = BriefingGenerator()
        let prompt = generator.buildBriefingPrompt(threads: threads, recentNotes: [])

        // Should include high momentum threads (top 5)
        XCTAssertTrue(prompt.contains("Thread 9"), "Prompt should include highest momentum thread")
        XCTAssertTrue(prompt.contains("Thread 8"), "Prompt should include second highest momentum thread")
        XCTAssertTrue(prompt.contains("Thread 7"), "Prompt should include third highest momentum thread")
        XCTAssertTrue(prompt.contains("Thread 6"), "Prompt should include fourth highest momentum thread")
        XCTAssertTrue(prompt.contains("Thread 5"), "Prompt should include fifth highest momentum thread")

        // Should NOT include low momentum threads (bottom 5)
        XCTAssertFalse(prompt.contains("Thread 0"), "Prompt should exclude lowest momentum thread")
        XCTAssertFalse(prompt.contains("Thread 1"), "Prompt should exclude second lowest momentum thread")
        XCTAssertFalse(prompt.contains("Thread 2"), "Prompt should exclude third lowest momentum thread")
        XCTAssertFalse(prompt.contains("Thread 3"), "Prompt should exclude fourth lowest momentum thread")
        XCTAssertFalse(prompt.contains("Thread 4"), "Prompt should exclude fifth lowest momentum thread")
    }

    // MARK: - parseBriefingResponse Tests

    func testParseBriefingResponse() {
        let threads = [
            Thread.mock(
                id: 1,
                name: "Event-Driven Architecture",
                status: "active",
                momentumScore: 0.9
            ),
            Thread.mock(
                id: 2,
                name: "Project Journey",
                status: "active",
                momentumScore: 0.4
            )
        ]

        let response = """
        Good morning! You have 2 active threads. The Event-Driven Architecture thread has high momentum -
        consider continuing there today. You might want to explore the tension between testing approaches.

        What aspect of event-driven testing feels most pressing right now?
        """

        let generator = BriefingGenerator()
        let briefing = generator.parseBriefingResponse(response, threads: threads)

        // Should set content to the response
        XCTAssertEqual(briefing.content, response)

        // Should find suggested thread (highest momentum that appears in response)
        XCTAssertEqual(briefing.suggestedThread, "Event-Driven Architecture")

        // Should set thread count
        XCTAssertEqual(briefing.threadCount, 2)

        // Should set generatedAt (within the last second)
        let timeDiff = abs(briefing.generatedAt.timeIntervalSinceNow)
        XCTAssertLessThan(timeDiff, 1.0, "generatedAt should be recent")
    }

    func testParseBriefingResponseWithNoThreads() {
        let threads: [SeleneChat.Thread] = []

        let response = """
        Good morning! You don't have any active threads yet. Consider capturing some thoughts
        to get started with your knowledge system.
        """

        let generator = BriefingGenerator()
        let briefing = generator.parseBriefingResponse(response, threads: threads)

        // Should set content to the response
        XCTAssertEqual(briefing.content, response)

        // Should have no suggested thread
        XCTAssertNil(briefing.suggestedThread)

        // Should set thread count to 0
        XCTAssertEqual(briefing.threadCount, 0)

        // Should set generatedAt
        let timeDiff = abs(briefing.generatedAt.timeIntervalSinceNow)
        XCTAssertLessThan(timeDiff, 1.0, "generatedAt should be recent")
    }

    func testParseBriefingResponseSuggestsHighestMomentumMatch() {
        let threads = [
            Thread.mock(
                id: 1,
                name: "Low Priority Thread",
                status: "active",
                momentumScore: 0.2
            ),
            Thread.mock(
                id: 2,
                name: "High Priority Thread",
                status: "active",
                momentumScore: 0.9
            ),
            Thread.mock(
                id: 3,
                name: "Medium Priority Thread",
                status: "active",
                momentumScore: 0.5
            )
        ]

        // Response mentions both Low and High priority threads
        let response = """
        Today you could work on Low Priority Thread or High Priority Thread.
        Both have interesting developments.
        """

        let generator = BriefingGenerator()
        let briefing = generator.parseBriefingResponse(response, threads: threads)

        // Should suggest the highest momentum thread that appears in response
        XCTAssertEqual(briefing.suggestedThread, "High Priority Thread")
    }
}
