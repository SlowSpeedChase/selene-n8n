import XCTest
@testable import SeleneChat

@MainActor
final class BriefingViewModelTests: XCTestCase {

    // MARK: - Initial State Tests

    func testInitialStateIsNotLoaded() {
        let viewModel = BriefingViewModel()

        // State should start as notLoaded
        XCTAssertEqual(viewModel.state.status, .notLoaded)
        // isDismissed should be false
        XCTAssertFalse(viewModel.isDismissed)
    }

    // MARK: - Dismiss Tests

    func testDismissBriefingClearsState() async {
        let viewModel = BriefingViewModel()

        // Dismiss the briefing
        await viewModel.dismiss()

        // isDismissed should be true
        XCTAssertTrue(viewModel.isDismissed)
    }

    // MARK: - Dig In Tests

    func testDigInReturnsSuggestedThreadQuery() async {
        let viewModel = BriefingViewModel()

        // Manually set state to loaded with a whatChanged card containing a thread
        let card = BriefingCard.whatChanged(
            noteTitle: "Test Note",
            noteId: 1,
            threadName: "Event-Driven Architecture",
            threadId: 1,
            date: Date(),
            primaryTheme: nil,
            energyLevel: nil
        )
        let briefing = StructuredBriefing(
            intro: "Test briefing content",
            whatChanged: [card],
            needsAttention: [],
            connections: [],
            generatedAt: Date()
        )
        viewModel.state.status = .loaded(briefing)

        // Call digIn
        let query = await viewModel.digIn()

        // Should return thread-specific query
        XCTAssertTrue(query.contains("Event-Driven Architecture"), "Query should contain the suggested thread name")
        XCTAssertTrue(query.lowercased().contains("dig") || query.lowercased().contains("let's"), "Query should be conversational")
    }

    func testDigInWithNoThreadReturnsGenericQuery() async {
        let viewModel = BriefingViewModel()

        // Manually set state to loaded without any whatChanged cards
        let briefing = StructuredBriefing(
            intro: "Test briefing content",
            whatChanged: [],
            needsAttention: [],
            connections: [],
            generatedAt: Date()
        )
        viewModel.state.status = .loaded(briefing)

        // Call digIn
        let query = await viewModel.digIn()

        // Should return generic query
        XCTAssertTrue(query.lowercased().contains("focus"), "Query should mention focus when no thread suggested")
    }

    func testDigInWithNotLoadedStateReturnsGenericQuery() async {
        let viewModel = BriefingViewModel()

        // State is still notLoaded
        let query = await viewModel.digIn()

        // Should return generic query
        XCTAssertTrue(query.lowercased().contains("focus"), "Query should mention focus when state not loaded")
    }

    // MARK: - Show Something Else Tests

    func testShowSomethingElseReturnsExplorationQuery() async {
        let viewModel = BriefingViewModel()

        // Call showSomethingElse
        let query = await viewModel.showSomethingElse()

        // Should return exploration query about notes
        XCTAssertTrue(query.lowercased().contains("notes") || query.lowercased().contains("else"), "Query should be about exploring notes")
    }
}
