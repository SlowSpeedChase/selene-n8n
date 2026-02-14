import Foundation

struct Recipe: Identifiable, Hashable {
    let id: Int64
    let title: String
    let filePath: String
    let servings: Int?
    let prepTimeMinutes: Int?
    let cookTimeMinutes: Int?
    let difficulty: String?
    let cuisine: String?
    let protein: String?
    let dishType: String?
    let mealOccasions: [String]
    let dietary: [String]
    let ingredients: [Ingredient]
    let calories: Int?

    struct Ingredient: Hashable, Codable {
        let amount: String?
        let unit: String?
        let item: String
    }

    var totalTimeMinutes: Int? {
        switch (prepTimeMinutes, cookTimeMinutes) {
        case let (prep?, cook?): return prep + cook
        case let (prep?, nil): return prep
        case let (nil, cook?): return cook
        case (nil, nil): return nil
        }
    }

    /// Compact one-line description for LLM context (low token cost)
    var compactDescription: String {
        var parts: [String] = [title]
        if let time = totalTimeMinutes { parts.append("\(time) min") }
        if let cuisine = cuisine { parts.append(cuisine) }
        if let protein = protein { parts.append(protein) }
        if let servings = servings { parts.append("\(servings) servings") }
        if let calories = calories { parts.append("\(calories) cal") }
        if !mealOccasions.isEmpty { parts.append(mealOccasions.joined(separator: ", ")) }
        return parts.joined(separator: " | ")
    }
}

#if DEBUG
extension Recipe {
    static func mock(
        id: Int64 = 1,
        title: String = "Test Recipe",
        filePath: String = "Recipes/Test.md",
        servings: Int? = 4,
        prepTimeMinutes: Int? = 10,
        cookTimeMinutes: Int? = 20,
        cuisine: String? = "Italian",
        protein: String? = "chicken",
        ingredients: [Ingredient] = [Ingredient(amount: "1", unit: "cup", item: "rice")]
    ) -> Recipe {
        Recipe(
            id: id, title: title, filePath: filePath,
            servings: servings, prepTimeMinutes: prepTimeMinutes,
            cookTimeMinutes: cookTimeMinutes, difficulty: "easy",
            cuisine: cuisine, protein: protein, dishType: "main",
            mealOccasions: ["weeknight-dinner"], dietary: [],
            ingredients: ingredients, calories: 400
        )
    }
}
#endif
