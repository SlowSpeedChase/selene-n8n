import Foundation

public struct Recipe: Identifiable, Hashable {
    public let id: Int64
    public let title: String
    public let filePath: String
    public let servings: Int?
    public let prepTimeMinutes: Int?
    public let cookTimeMinutes: Int?
    public let difficulty: String?
    public let cuisine: String?
    public let protein: String?
    public let dishType: String?
    public let mealOccasions: [String]
    public let dietary: [String]
    public let ingredients: [Ingredient]
    public let calories: Int?

    public init(id: Int64, title: String, filePath: String, servings: Int?,
                prepTimeMinutes: Int?, cookTimeMinutes: Int?, difficulty: String?,
                cuisine: String?, protein: String?, dishType: String?,
                mealOccasions: [String], dietary: [String],
                ingredients: [Ingredient], calories: Int?) {
        self.id = id
        self.title = title
        self.filePath = filePath
        self.servings = servings
        self.prepTimeMinutes = prepTimeMinutes
        self.cookTimeMinutes = cookTimeMinutes
        self.difficulty = difficulty
        self.cuisine = cuisine
        self.protein = protein
        self.dishType = dishType
        self.mealOccasions = mealOccasions
        self.dietary = dietary
        self.ingredients = ingredients
        self.calories = calories
    }

    public struct Ingredient: Hashable, Codable {
        public let amount: String?
        public let unit: String?
        public let item: String

        public init(amount: String?, unit: String?, item: String) {
            self.amount = amount
            self.unit = unit
            self.item = item
        }
    }

    public var totalTimeMinutes: Int? {
        switch (prepTimeMinutes, cookTimeMinutes) {
        case let (prep?, cook?): return prep + cook
        case let (prep?, nil): return prep
        case let (nil, cook?): return cook
        case (nil, nil): return nil
        }
    }

    /// Compact one-line description for LLM context (low token cost)
    public var compactDescription: String {
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
    public static func mock(
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
