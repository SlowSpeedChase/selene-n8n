import XCTest
@testable import SeleneChat

final class BriefingIntegrationTests: XCTestCase {

    // MARK: - Test 1: Context Builder Produces Valid Context

    /// Test that ThinkingPartnerContextBuilder produces valid context from test data
    func testBriefingContextBuilderProducesValidContext() {
        let contextBuilder = ThinkingPartnerContextBuilder()

        // Create test threads with different momentum scores
        let threads = [
            Thread.mock(
                id: 1,
                name: "Project Architecture",
                summary: "Designing the new system architecture",
                status: "active",
                noteCount: 8,
                momentumScore: 0.85
            ),
            Thread.mock(
                id: 2,
                name: "Health Goals",
                summary: "Tracking fitness and wellness",
                status: "active",
                noteCount: 5,
                momentumScore: 0.6
            ),
            Thread.mock(
                id: 3,
                name: "Learning Swift",
                summary: "SwiftUI and iOS development learning path",
                status: "active",
                noteCount: 3,
                momentumScore: 0.3
            )
        ]

        // Create test notes
        let notes = [
            Note.mock(id: 1, title: "Architecture Decision", content: "Decided on microservices approach"),
            Note.mock(id: 2, title: "Morning Run", content: "Ran 5km today, feeling good"),
            Note.mock(id: 3, title: "Swift Concurrency", content: "Learning about async/await patterns")
        ]

        // Build context
        let context = contextBuilder.buildBriefingContext(threads: threads, recentNotes: notes)

        // Assert context contains thread names
        XCTAssertTrue(context.contains("Project Architecture"), "Context should contain thread name 'Project Architecture'")
        XCTAssertTrue(context.contains("Health Goals"), "Context should contain thread name 'Health Goals'")
        XCTAssertTrue(context.contains("Learning Swift"), "Context should contain thread name 'Learning Swift'")

        // Assert context contains note titles
        XCTAssertTrue(context.contains("Architecture Decision"), "Context should contain note title")
        XCTAssertTrue(context.contains("Morning Run"), "Context should contain note title")

        // Assert context respects token budget (< 6000 chars for 1500 token budget)
        // Token budget for briefing is 1500 tokens, at ~4 chars/token = 6000 chars
        let maxCharsForBriefing = ThinkingPartnerQueryType.briefing.tokenBudget * 4
        XCTAssertLessThan(context.count, maxCharsForBriefing, "Context should respect token budget")
    }

    // MARK: - Test 2: Briefing Generator Builds Complete Prompt

    /// Test that BriefingGenerator builds a complete prompt with required elements
    func testBriefingGeneratorBuildsCompletePrompt() {
        let generator = BriefingGenerator()

        // Create test threads with momentum
        let threads = [
            Thread.mock(
                id: 1,
                name: "High Momentum Thread",
                why: "Important for career growth",
                summary: "Career development planning",
                status: "active",
                noteCount: 10,
                momentumScore: 0.9
            ),
            Thread.mock(
                id: 2,
                name: "Medium Momentum Thread",
                summary: "Side project exploration",
                status: "active",
                noteCount: 4,
                momentumScore: 0.5
            )
        ]

        // Create test notes
        let notes = [
            Note.mock(id: 1, title: "Career Goals", content: "Set quarterly objectives"),
            Note.mock(id: 2, title: "Project Ideas", content: "Brainstorming new features")
        ]

        // Build prompt
        let prompt = generator.buildBriefingPrompt(threads: threads, recentNotes: notes)

        // Assert prompt contains key elements
        XCTAssertTrue(prompt.contains("thinking partner"), "Prompt should mention 'thinking partner' role")
        XCTAssertTrue(prompt.contains("ADHD"), "Prompt should reference ADHD design principles")
        XCTAssertTrue(prompt.contains("High Momentum Thread"), "Prompt should contain thread names")
        XCTAssertTrue(prompt.contains("150 words"), "Prompt should specify word limit guideline")

        // Verify prompt contains briefing instructions
        XCTAssertTrue(prompt.contains("morning briefing") || prompt.contains("briefing"), "Prompt should mention briefing")
        XCTAssertTrue(prompt.contains("2-3 threads"), "Prompt should limit threads to highlight")
    }

    // MARK: - Test 3: Briefing State Flow from Load to Display

    /// Test state machine: notLoaded -> loading -> loaded
    func testBriefingStateFlowFromLoadToDisplay() {
        // Create initial state
        var state = BriefingState()

        // Verify initial state is notLoaded
        XCTAssertEqual(state.status, .notLoaded, "Initial status should be .notLoaded")

        // Transition to loading
        state.status = .loading
        XCTAssertEqual(state.status, .loading, "Status should transition to .loading")

        // Transition to loaded with briefing data
        let briefing = Briefing(
            content: "Good morning! Your highest momentum thread is Project Architecture. Consider focusing there today.",
            suggestedThread: "Project Architecture",
            threadCount: 3,
            generatedAt: Date()
        )
        state.status = .loaded(briefing)

        // Verify loaded state
        if case .loaded(let loadedBriefing) = state.status {
            XCTAssertEqual(loadedBriefing.content, briefing.content, "Briefing content should match")
            XCTAssertEqual(loadedBriefing.suggestedThread, "Project Architecture", "Suggested thread should match")
            XCTAssertEqual(loadedBriefing.threadCount, 3, "Thread count should match")
        } else {
            XCTFail("Status should be .loaded with briefing data")
        }
    }

    // MARK: - Test 4: Briefing State Flow with Error

    /// Test error state: loading -> failed
    func testBriefingStateFlowWithError() {
        var state = BriefingState()

        // Start loading
        state.status = .loading
        XCTAssertEqual(state.status, .loading, "Status should be .loading")

        // Simulate error
        let errorMessage = "Failed to connect to Ollama: Connection refused"
        state.status = .failed(errorMessage)

        // Verify error state
        if case .failed(let message) = state.status {
            XCTAssertEqual(message, errorMessage, "Error message should be stored")
            XCTAssertTrue(message.contains("Ollama"), "Error should contain service name")
        } else {
            XCTFail("Status should be .failed with error message")
        }
    }

    // MARK: - Test 5: End-to-End Briefing Prompt Flow

    /// Simulate full flow from test data to prompt
    func testEndToEndBriefingPromptFlow() {
        let contextBuilder = ThinkingPartnerContextBuilder()
        let generator = BriefingGenerator()

        // Create diverse test threads with varying momentum
        let threads = [
            Thread.mock(
                id: 1,
                name: "High Momentum Project",
                why: "Core business initiative",
                summary: "Building the next version of the product",
                status: "active",
                noteCount: 15,
                momentumScore: 0.95
            ),
            Thread.mock(
                id: 2,
                name: "Medium Momentum Research",
                summary: "Exploring new technologies",
                status: "active",
                noteCount: 7,
                momentumScore: 0.6
            ),
            Thread.mock(
                id: 3,
                name: "Low Momentum Backlog",
                summary: "Items for later",
                status: "active",
                noteCount: 2,
                momentumScore: 0.1
            ),
            Thread.mock(
                id: 4,
                name: "Paused Thread",
                summary: "On hold for now",
                status: "paused",
                noteCount: 3,
                momentumScore: 0.0
            )
        ]

        // Create recent notes
        let notes = [
            Note.mock(
                id: 1,
                title: "Product Roadmap Update",
                content: "Defined Q1 milestones for the product",
                primaryTheme: "planning"
            ),
            Note.mock(
                id: 2,
                title: "Tech Stack Decision",
                content: "Evaluated Swift vs Kotlin for mobile",
                primaryTheme: "technical"
            ),
            Note.mock(
                id: 3,
                title: "Team Meeting Notes",
                content: "Discussed sprint priorities with the team",
                primaryTheme: "collaboration"
            )
        ]

        // Step 1: Build context
        let context = contextBuilder.buildBriefingContext(threads: threads, recentNotes: notes)
        XCTAssertFalse(context.isEmpty, "Context should not be empty")

        // Step 2: Build prompt using generator
        let prompt = generator.buildBriefingPrompt(threads: threads, recentNotes: notes)

        // Verify prompt is reasonable size (100 < length < 10000)
        XCTAssertGreaterThan(prompt.count, 100, "Prompt should have substantial content")
        XCTAssertLessThan(prompt.count, 10000, "Prompt should not exceed reasonable size")

        // Verify prompt mentions high-momentum threads
        XCTAssertTrue(prompt.contains("High Momentum Project"), "Prompt should include high-momentum thread")

        // Verify prompt structure
        XCTAssertTrue(prompt.contains("Active Threads") || prompt.contains("threads"), "Prompt should reference threads")
        XCTAssertTrue(prompt.contains("Notes") || prompt.contains("Recent"), "Prompt should reference notes")

        // Verify the prompt can be used to generate a response
        // (In real integration, this would call OllamaService)
        // For now, verify the prompt is well-formed
        let promptLines = prompt.split(separator: "\n")
        XCTAssertGreaterThan(promptLines.count, 5, "Prompt should have multiple sections")
    }

    // MARK: - Additional Integration Tests

    /// Test that BriefingGenerator correctly parses response and identifies suggested thread
    func testBriefingGeneratorParsesResponse() {
        let generator = BriefingGenerator()

        let threads = [
            Thread.mock(id: 1, name: "Project Alpha", momentumScore: 0.9),
            Thread.mock(id: 2, name: "Project Beta", momentumScore: 0.5)
        ]

        let mockResponse = """
        Good morning! Based on your recent activity, I'd recommend focusing on Project Alpha today.
        It has high momentum and several recent notes. Consider tackling the architecture decisions first.
        """

        let briefing = generator.parseBriefingResponse(mockResponse, threads: threads)

        XCTAssertEqual(briefing.content, mockResponse, "Briefing content should match response")
        XCTAssertEqual(briefing.suggestedThread, "Project Alpha", "Should identify suggested thread from response")
        XCTAssertEqual(briefing.threadCount, 2, "Thread count should match input")
        XCTAssertNotNil(briefing.generatedAt, "Generated date should be set")
    }

    /// Test briefing with empty threads handles gracefully
    func testBriefingWithEmptyThreads() {
        let generator = BriefingGenerator()
        let contextBuilder = ThinkingPartnerContextBuilder()

        let emptyThreads: [SeleneChat.Thread] = []
        let notes = [Note.mock(id: 1, title: "Standalone Note", content: "No thread context")]

        // Context builder should handle empty threads
        let context = contextBuilder.buildBriefingContext(threads: emptyThreads, recentNotes: notes)
        XCTAssertTrue(context.contains("Active Threads"), "Should still have section header")

        // Generator should handle empty threads
        let prompt = generator.buildBriefingPrompt(threads: emptyThreads, recentNotes: notes)
        XCTAssertFalse(prompt.isEmpty, "Prompt should still be generated")
        XCTAssertTrue(prompt.contains("thinking partner"), "Prompt should maintain core structure")
    }

    /// Test BriefingStatus equality for state comparisons
    func testBriefingStatusEquality() {
        let briefing1 = Briefing(
            content: "Test content",
            suggestedThread: "Thread A",
            threadCount: 2,
            generatedAt: Date(timeIntervalSince1970: 0)
        )
        let briefing2 = Briefing(
            content: "Test content",
            suggestedThread: "Thread A",
            threadCount: 2,
            generatedAt: Date(timeIntervalSince1970: 0)
        )

        // Test equality of BriefingStatus enum
        XCTAssertEqual(BriefingStatus.notLoaded, BriefingStatus.notLoaded)
        XCTAssertEqual(BriefingStatus.loading, BriefingStatus.loading)
        XCTAssertEqual(BriefingStatus.loaded(briefing1), BriefingStatus.loaded(briefing2))
        XCTAssertEqual(BriefingStatus.failed("error"), BriefingStatus.failed("error"))

        // Test inequality
        XCTAssertNotEqual(BriefingStatus.notLoaded, BriefingStatus.loading)
        XCTAssertNotEqual(BriefingStatus.failed("error1"), BriefingStatus.failed("error2"))
    }
}
