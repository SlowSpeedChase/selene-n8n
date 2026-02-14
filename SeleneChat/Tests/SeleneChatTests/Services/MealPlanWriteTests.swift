import XCTest
@testable import SeleneChat
@testable import SeleneShared

final class MealPlanWriteTests: XCTestCase {

    private func uniqueWeek() -> String {
        "test-\(UUID().uuidString.prefix(8))"
    }

    @MainActor
    func testCreateMealPlanReturnsId() async throws {
        let db = DatabaseService.shared
        let id = try await db.createMealPlan(week: uniqueWeek())
        XCTAssertGreaterThan(id, 0)
        try await db.deleteMealPlan(id: id)
    }

    @MainActor
    func testInsertMealPlanItem() async throws {
        let db = DatabaseService.shared
        let week = uniqueWeek()
        let planId = try await db.createMealPlan(week: week)

        try await db.insertMealPlanItem(
            planId: planId,
            day: "monday",
            meal: "dinner",
            recipeId: nil,
            recipeTitle: "Test Recipe"
        )

        let items = try await db.getMealPlanForWeek(week)
        XCTAssertEqual(items.count, 1)
        XCTAssertEqual(items[0].recipeTitle, "Test Recipe")

        try await db.deleteMealPlan(id: planId)
    }

    @MainActor
    func testInsertShoppingItem() async throws {
        let db = DatabaseService.shared
        let planId = try await db.createMealPlan(week: uniqueWeek())

        try await db.insertShoppingItem(
            planId: planId,
            ingredient: "spaghetti",
            amount: 400,
            unit: "g",
            category: "pantry"
        )

        try await db.deleteMealPlan(id: planId)
    }

    @MainActor
    func testUpdateMealPlanStatus() async throws {
        let db = DatabaseService.shared
        let planId = try await db.createMealPlan(week: uniqueWeek())

        try await db.updateMealPlanStatus(id: planId, status: "active")

        try await db.deleteMealPlan(id: planId)
    }
}
