import XCTest
@testable import SeleneChat

final class BriefingStateTests: XCTestCase {

    func testBriefingStateInitializesAsNotLoaded() {
        let state = BriefingState()
        XCTAssertEqual(state.status, .notLoaded)
    }

    func testBriefingStateCanTransitionToLoading() {
        var state = BriefingState()
        state.status = .loading
        XCTAssertEqual(state.status, .loading)
    }

    func testBriefingStateStoresLoadedBriefing() {
        var state = BriefingState()
        let briefing = Briefing(
            content: "Good morning! You have 3 active threads.",
            suggestedThread: "Project Planning",
            threadCount: 3,
            generatedAt: Date()
        )
        state.status = .loaded(briefing)

        if case .loaded(let storedBriefing) = state.status {
            XCTAssertEqual(storedBriefing.content, "Good morning! You have 3 active threads.")
            XCTAssertEqual(storedBriefing.suggestedThread, "Project Planning")
            XCTAssertEqual(storedBriefing.threadCount, 3)
        } else {
            XCTFail("Expected .loaded status")
        }
    }

    func testBriefingStateStoresError() {
        var state = BriefingState()
        state.status = .failed("Network connection lost")

        if case .failed(let errorMessage) = state.status {
            XCTAssertEqual(errorMessage, "Network connection lost")
        } else {
            XCTFail("Expected .failed status")
        }
    }

    // MARK: - Equatable Tests

    func testBriefingStatusEquatable() {
        XCTAssertEqual(BriefingStatus.notLoaded, BriefingStatus.notLoaded)
        XCTAssertEqual(BriefingStatus.loading, BriefingStatus.loading)
        XCTAssertNotEqual(BriefingStatus.notLoaded, BriefingStatus.loading)

        let briefing1 = Briefing(
            content: "Test",
            suggestedThread: nil,
            threadCount: 1,
            generatedAt: Date(timeIntervalSince1970: 1000)
        )
        let briefing2 = Briefing(
            content: "Test",
            suggestedThread: nil,
            threadCount: 1,
            generatedAt: Date(timeIntervalSince1970: 1000)
        )
        XCTAssertEqual(BriefingStatus.loaded(briefing1), BriefingStatus.loaded(briefing2))

        XCTAssertEqual(BriefingStatus.failed("error"), BriefingStatus.failed("error"))
        XCTAssertNotEqual(BriefingStatus.failed("error1"), BriefingStatus.failed("error2"))
    }

    func testBriefingEquatable() {
        let date = Date()
        let briefing1 = Briefing(
            content: "Hello",
            suggestedThread: "Thread A",
            threadCount: 5,
            generatedAt: date
        )
        let briefing2 = Briefing(
            content: "Hello",
            suggestedThread: "Thread A",
            threadCount: 5,
            generatedAt: date
        )
        XCTAssertEqual(briefing1, briefing2)

        let briefing3 = Briefing(
            content: "Different",
            suggestedThread: "Thread A",
            threadCount: 5,
            generatedAt: date
        )
        XCTAssertNotEqual(briefing1, briefing3)
    }

    func testBriefingWithNilSuggestedThread() {
        let briefing = Briefing(
            content: "No suggestions today",
            suggestedThread: nil,
            threadCount: 0,
            generatedAt: Date()
        )
        XCTAssertNil(briefing.suggestedThread)
        XCTAssertEqual(briefing.threadCount, 0)
    }
}
