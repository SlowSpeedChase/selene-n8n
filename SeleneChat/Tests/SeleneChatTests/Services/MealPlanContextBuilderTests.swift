import XCTest
@testable import SeleneChat

final class MealPlanContextBuilderTests: XCTestCase {

    func testBuildsRecipeLibraryContext() {
        let builder = MealPlanContextBuilder()
        let recipes = [
            Recipe.mock(id: 1, title: "Pasta Carbonara", cuisine: "Italian", protein: "pork"),
            Recipe.mock(id: 2, title: "Chicken Stir Fry", cuisine: "Asian", protein: "chicken"),
        ]
        let context = builder.buildRecipeLibraryContext(recipes: recipes)

        XCTAssertTrue(context.contains("Pasta Carbonara"))
        XCTAssertTrue(context.contains("Chicken Stir Fry"))
        XCTAssertTrue(context.contains("Italian"))
    }

    func testBuildsRecentMealsContext() {
        let builder = MealPlanContextBuilder()
        let recentMeals: [(week: String, items: [(day: String, meal: String, recipeTitle: String)])] = [
            (week: "2026-W06", items: [
                (day: "monday", meal: "dinner", recipeTitle: "Pasta Carbonara"),
                (day: "tuesday", meal: "lunch", recipeTitle: "Chicken Stir Fry"),
            ])
        ]
        let context = builder.buildRecentMealsContext(recentMeals: recentMeals)

        XCTAssertTrue(context.contains("Pasta Carbonara"))
        XCTAssertTrue(context.contains("2026-W06"))
    }

    func testRespectsTokenBudget() {
        let builder = MealPlanContextBuilder()
        // Generate 100 recipes to exceed token budget
        let recipes = (1...100).map { i in
            Recipe.mock(id: Int64(i), title: "Recipe Number \(i) With A Very Long Name That Takes Up Tokens")
        }
        let context = builder.buildRecipeLibraryContext(recipes: recipes)

        // Should be truncated (2500 token budget = ~10000 chars)
        XCTAssertTrue(context.count < 12000)
    }

    func testBuildFullContextCombinesAll() {
        let builder = MealPlanContextBuilder()
        let recipes = [Recipe.mock()]
        let recentMeals: [(week: String, items: [(day: String, meal: String, recipeTitle: String)])] = []

        let context = builder.buildFullContext(
            recipes: recipes,
            recentMeals: recentMeals,
            nutritionTargets: (calories: 2000, protein: 150, carbs: 250, fat: 65)
        )

        XCTAssertTrue(context.contains("Recipe Library"))
        XCTAssertTrue(context.contains("Nutrition Targets"))
        XCTAssertTrue(context.contains("2000"))
    }
}
