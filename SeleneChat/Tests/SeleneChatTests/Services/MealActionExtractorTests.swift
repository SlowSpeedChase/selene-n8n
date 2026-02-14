import XCTest
@testable import SeleneChat

final class MealActionExtractorTests: XCTestCase {

    func testExtractsMealMarker() {
        let extractor = ActionExtractor()
        let response = """
        Here's my suggestion for Monday dinner:
        [MEAL: monday | dinner | Pasta Carbonara | recipe_id: 42]
        """
        let meals = extractor.extractMealActions(from: response)

        XCTAssertEqual(meals.count, 1)
        XCTAssertEqual(meals[0].day, "monday")
        XCTAssertEqual(meals[0].meal, "dinner")
        XCTAssertEqual(meals[0].recipeTitle, "Pasta Carbonara")
        XCTAssertEqual(meals[0].recipeId, 42)
    }

    func testExtractsMultipleMealMarkers() {
        let extractor = ActionExtractor()
        let response = """
        [MEAL: monday | dinner | Pasta Carbonara | recipe_id: 42]
        [MEAL: tuesday | lunch | Chicken Stir Fry | recipe_id: 15]
        [MEAL: wednesday | dinner | Sheet Pan Salmon | recipe_id: 8]
        """
        let meals = extractor.extractMealActions(from: response)
        XCTAssertEqual(meals.count, 3)
    }

    func testExtractsShopMarker() {
        let extractor = ActionExtractor()
        let response = """
        [SHOP: spaghetti | 400 | g | pantry]
        [SHOP: guanciale | 200 | g | meat]
        """
        let items = extractor.extractShopActions(from: response)

        XCTAssertEqual(items.count, 2)
        XCTAssertEqual(items[0].ingredient, "spaghetti")
        XCTAssertEqual(items[0].amount, 400)
        XCTAssertEqual(items[0].unit, "g")
        XCTAssertEqual(items[0].category, "pantry")
    }

    func testRemovesMealAndShopMarkers() {
        let extractor = ActionExtractor()
        let response = """
        Here's Monday dinner:
        [MEAL: monday | dinner | Pasta | recipe_id: 1]
        And you'll need:
        [SHOP: pasta | 400 | g | pantry]
        Enjoy!
        """
        let cleaned = extractor.removeMealAndShopMarkers(from: response)

        XCTAssertFalse(cleaned.contains("[MEAL:"))
        XCTAssertFalse(cleaned.contains("[SHOP:"))
        XCTAssertTrue(cleaned.contains("Monday dinner"))
        XCTAssertTrue(cleaned.contains("Enjoy!"))
    }

    func testHandlesMealMarkerWithoutRecipeId() {
        let extractor = ActionExtractor()
        let response = "[MEAL: monday | dinner | Homemade something | recipe_id: 0]"
        let meals = extractor.extractMealActions(from: response)

        XCTAssertEqual(meals.count, 1)
        XCTAssertEqual(meals[0].recipeTitle, "Homemade something")
        XCTAssertNil(meals[0].recipeId)
    }
}
