import Foundation
import SeleneShared

/// Builds LLM context for meal planning queries by combining recipe library,
/// recent meal history, and nutrition targets into a structured context string.
class MealPlanContextBuilder {

    private let tokenBudget = 2500

    // MARK: - Token Estimation

    private func estimateTokens(_ text: String) -> Int {
        text.count / 4
    }

    // MARK: - Recipe Library Context

    /// Build context listing available recipes with compact descriptions.
    /// Truncates when exceeding token budget to keep prompt size manageable.
    func buildRecipeLibraryContext(recipes: [Recipe]) -> String {
        var context = "## Recipe Library (\(recipes.count) recipes)\n\n"
        var currentTokens = estimateTokens(context)

        for (index, recipe) in recipes.enumerated() {
            let line = "- \(recipe.compactDescription)\n"
            let lineTokens = estimateTokens(line)
            if currentTokens + lineTokens > tokenBudget {
                let remaining = recipes.count - index
                context += "\n[... \(remaining) more recipes truncated]\n"
                break
            }
            context += line
            currentTokens += lineTokens
        }

        return context
    }

    // MARK: - Recent Meals Context

    /// Build context showing recent meal plans to help the LLM avoid repetition.
    func buildRecentMealsContext(recentMeals: [(week: String, items: [(day: String, meal: String, recipeTitle: String)])]) -> String {
        guard !recentMeals.isEmpty else { return "" }

        var context = "## Recent Meals (avoid repetition)\n\n"
        for plan in recentMeals {
            context += "### \(plan.week)\n"
            for item in plan.items {
                context += "- \(item.day) \(item.meal): \(item.recipeTitle)\n"
            }
            context += "\n"
        }
        return context
    }

    // MARK: - Full Context

    /// Build complete meal planning context combining recipe library,
    /// recent meals, and optional nutrition targets.
    func buildFullContext(
        recipes: [Recipe],
        recentMeals: [(week: String, items: [(day: String, meal: String, recipeTitle: String)])],
        nutritionTargets: (calories: Int, protein: Int, carbs: Int, fat: Int)?
    ) -> String {
        var context = ""

        context += buildRecipeLibraryContext(recipes: recipes)
        context += "\n"
        context += buildRecentMealsContext(recentMeals: recentMeals)

        if let targets = nutritionTargets {
            context += "## Nutrition Targets (daily)\n"
            context += "- Calories: \(targets.calories)\n"
            context += "- Protein: \(targets.protein)g\n"
            context += "- Carbs: \(targets.carbs)g\n"
            context += "- Fat: \(targets.fat)g\n\n"
        }

        return context
    }
}
