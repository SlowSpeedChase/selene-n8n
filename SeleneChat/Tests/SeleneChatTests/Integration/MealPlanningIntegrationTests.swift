import XCTest
@testable import SeleneChat
@testable import SeleneShared

final class MealPlanningIntegrationTests: XCTestCase {

    func testMealPlanContextBuilderIntegration() {
        let contextBuilder = MealPlanContextBuilder()
        let promptBuilder = MealPlanPromptBuilder()

        let recipes = [
            Recipe.mock(id: 1, title: "Pasta Carbonara", cuisine: "Italian"),
            Recipe.mock(id: 2, title: "Chicken Stir Fry", cuisine: "Asian"),
        ]

        let context = contextBuilder.buildFullContext(
            recipes: recipes,
            recentMeals: [],
            nutritionTargets: (calories: 2000, protein: 150, carbs: 250, fat: 65)
        )

        let prompt = promptBuilder.buildPlanningPrompt(
            query: "plan next week",
            context: context,
            conversationHistory: []
        )

        XCTAssertTrue(prompt.contains("Pasta Carbonara"))
        XCTAssertTrue(prompt.contains("Chicken Stir Fry"))
        XCTAssertTrue(prompt.contains("2000"))
        XCTAssertTrue(prompt.contains("plan next week"))
    }

    func testMealActionExtractionFromFullResponse() {
        let extractor = ActionExtractor()
        let response = """
        Here's your meal plan for next week:

        **Monday:**
        [MEAL: monday | breakfast | Overnight Oats | recipe_id: 5]
        [MEAL: monday | lunch | Chicken Stir Fry | recipe_id: 2]
        [MEAL: monday | dinner | Pasta Carbonara | recipe_id: 1]

        **Shopping list:**
        [SHOP: spaghetti | 400 | g | pantry]
        [SHOP: eggs | 4 | count | dairy]
        [SHOP: chicken breast | 500 | g | meat]

        This plan keeps Monday light with quick meals and saves the heavier cooking for when you have energy.
        """

        let meals = extractor.extractMealActions(from: response)
        XCTAssertEqual(meals.count, 3)
        XCTAssertEqual(meals[0].day, "monday")
        XCTAssertEqual(meals[0].meal, "breakfast")

        let items = extractor.extractShopActions(from: response)
        XCTAssertEqual(items.count, 3)

        let cleaned = extractor.removeMealAndShopMarkers(from: response)
        XCTAssertFalse(cleaned.contains("[MEAL:"))
        XCTAssertTrue(cleaned.contains("Monday"))
        XCTAssertTrue(cleaned.contains("energy"))
    }

    func testMealPlanningQueryDetection() {
        let analyzer = QueryAnalyzer()
        XCTAssertEqual(analyzer.analyze("help me plan next week's meals").queryType, .mealPlanning)
        XCTAssertEqual(analyzer.analyze("what should I cook tonight").queryType, .mealPlanning)
        XCTAssertNotEqual(analyzer.analyze("how am I doing today").queryType, .mealPlanning)
    }
}
