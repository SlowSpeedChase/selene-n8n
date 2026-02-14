import XCTest
@testable import SeleneChat
@testable import SeleneShared

final class MealPlanningQueryTests: XCTestCase {

    func testDetectsMealPlanQuery() {
        let analyzer = QueryAnalyzer()
        let result = analyzer.analyze("help me plan next week's meals")
        XCTAssertEqual(result.queryType, .mealPlanning)
    }

    func testDetectsWhatShouldICook() {
        let analyzer = QueryAnalyzer()
        let result = analyzer.analyze("what should I cook tonight")
        XCTAssertEqual(result.queryType, .mealPlanning)
    }

    func testDetectsGroceryList() {
        let analyzer = QueryAnalyzer()
        let result = analyzer.analyze("what do I need for my grocery list")
        XCTAssertEqual(result.queryType, .mealPlanning)
    }

    func testDetectsDinnerIdeas() {
        let analyzer = QueryAnalyzer()
        let result = analyzer.analyze("give me some dinner ideas for the week")
        XCTAssertEqual(result.queryType, .mealPlanning)
    }

    func testDetectsMealPrep() {
        let analyzer = QueryAnalyzer()
        let result = analyzer.analyze("what should I meal prep this sunday")
        XCTAssertEqual(result.queryType, .mealPlanning)
    }

    func testDoesNotFalsePositiveOnFood() {
        let analyzer = QueryAnalyzer()
        let result = analyzer.analyze("show me notes about food")
        XCTAssertNotEqual(result.queryType, .mealPlanning)
    }

    func testDoesNotFalsePositiveOnGeneral() {
        let analyzer = QueryAnalyzer()
        let result = analyzer.analyze("how am I doing today")
        XCTAssertNotEqual(result.queryType, .mealPlanning)
    }
}
