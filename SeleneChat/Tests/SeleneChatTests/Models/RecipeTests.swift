import XCTest
@testable import SeleneChat

final class RecipeTests: XCTestCase {

    func testRecipeInitialization() {
        let recipe = Recipe(
            id: 1,
            title: "Pasta Carbonara",
            filePath: "Recipes/Pasta Carbonara.md",
            servings: 4,
            prepTimeMinutes: 10,
            cookTimeMinutes: 20,
            difficulty: "medium",
            cuisine: "Italian",
            protein: "pork",
            dishType: "pasta",
            mealOccasions: ["weeknight-dinner"],
            dietary: ["contains-gluten"],
            ingredients: [
                Recipe.Ingredient(amount: "400", unit: "g", item: "spaghetti"),
                Recipe.Ingredient(amount: "200", unit: "g", item: "guanciale")
            ],
            calories: 580
        )

        XCTAssertEqual(recipe.id, 1)
        XCTAssertEqual(recipe.title, "Pasta Carbonara")
        XCTAssertEqual(recipe.servings, 4)
        XCTAssertEqual(recipe.totalTimeMinutes, 30)
        XCTAssertEqual(recipe.ingredients.count, 2)
    }

    func testTotalTimeWithNilValues() {
        let recipe = Recipe(
            id: 1, title: "Test", filePath: "test.md",
            servings: nil, prepTimeMinutes: nil, cookTimeMinutes: 15,
            difficulty: nil, cuisine: nil, protein: nil, dishType: nil,
            mealOccasions: [], dietary: [], ingredients: [], calories: nil
        )
        XCTAssertEqual(recipe.totalTimeMinutes, 15)
    }

    func testCompactDescription() {
        let recipe = Recipe(
            id: 1, title: "Quick Stir Fry", filePath: "test.md",
            servings: 2, prepTimeMinutes: 5, cookTimeMinutes: 10,
            difficulty: "easy", cuisine: "Asian", protein: "chicken",
            dishType: "stir-fry",
            mealOccasions: ["weeknight-dinner", "meal-prep"],
            dietary: [], ingredients: [], calories: 350
        )
        let desc = recipe.compactDescription
        XCTAssertTrue(desc.contains("Quick Stir Fry"))
        XCTAssertTrue(desc.contains("15 min"))
        XCTAssertTrue(desc.contains("Asian"))
        XCTAssertTrue(desc.contains("chicken"))
    }

    func testMockFactory() {
        let recipe = Recipe.mock()
        XCTAssertEqual(recipe.id, 1)
        XCTAssertFalse(recipe.title.isEmpty)
    }
}
