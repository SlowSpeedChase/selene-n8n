import XCTest
@testable import SeleneChat
@testable import SeleneShared

final class MealPlanPromptBuilderTests: XCTestCase {

    func testBuildSystemPromptContainsActionMarkers() {
        let builder = MealPlanPromptBuilder()
        let prompt = builder.buildSystemPrompt()

        XCTAssertTrue(prompt.contains("[MEAL:"))
        XCTAssertTrue(prompt.contains("[SHOP:"))
        XCTAssertTrue(prompt.contains("ADHD"))
    }

    func testBuildPlanningPromptIncludesContext() {
        let builder = MealPlanPromptBuilder()
        let context = "## Recipe Library\n- Pasta | Italian | 30 min\n"
        let prompt = builder.buildPlanningPrompt(
            query: "plan next week's meals",
            context: context,
            conversationHistory: []
        )

        XCTAssertTrue(prompt.contains("plan next week"))
        XCTAssertTrue(prompt.contains("Recipe Library"))
    }

    func testBuildPlanningPromptIncludesHistory() {
        let builder = MealPlanPromptBuilder()
        let history = [
            (role: "user", content: "plan next week"),
            (role: "assistant", content: "Here are my suggestions...")
        ]
        let prompt = builder.buildPlanningPrompt(
            query: "swap tuesday dinner",
            context: "",
            conversationHistory: history
        )

        XCTAssertTrue(prompt.contains("swap tuesday dinner"))
        XCTAssertTrue(prompt.contains("plan next week"))
    }
}
