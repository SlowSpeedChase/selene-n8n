import XCTest
@testable import SeleneChat

final class RecipeQueryTests: XCTestCase {

    @MainActor
    func testGetAllRecipesReturnsArray() async throws {
        let db = DatabaseService.shared
        let recipes = try await db.getAllRecipes()
        // May or may not be empty depending on DB state
        // Just verify it doesn't crash and returns [Recipe]
        XCTAssertNotNil(recipes)
    }

    @MainActor
    func testGetRecipesByProteinReturnsArray() async throws {
        let db = DatabaseService.shared
        let recipes = try await db.getRecipesByProtein("chicken")
        XCTAssertNotNil(recipes)
    }

    @MainActor
    func testGetRecipesByCuisineReturnsArray() async throws {
        let db = DatabaseService.shared
        let recipes = try await db.getRecipesByCuisine("Italian")
        XCTAssertNotNil(recipes)
    }

    @MainActor
    func testSearchRecipesReturnsArray() async throws {
        let db = DatabaseService.shared
        let recipes = try await db.searchRecipes(query: "pasta")
        XCTAssertNotNil(recipes)
    }

    @MainActor
    func testGetRecipeByIdReturnsNilForMissing() async throws {
        let db = DatabaseService.shared
        let recipe = try await db.getRecipeById(99999)
        XCTAssertNil(recipe)
    }

    @MainActor
    func testGetRecentMealPlansReturnsArray() async throws {
        let db = DatabaseService.shared
        let plans = try await db.getRecentMealPlans(weeks: 3)
        XCTAssertNotNil(plans)
    }

    @MainActor
    func testGetMealPlanForWeekReturnsArray() async throws {
        let db = DatabaseService.shared
        let items = try await db.getMealPlanForWeek("2026-W07")
        XCTAssertNotNil(items)
    }
}
