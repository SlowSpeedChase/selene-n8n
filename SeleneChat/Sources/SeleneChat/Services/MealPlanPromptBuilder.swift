import Foundation

/// Builds specialized prompts for meal planning conversations.
/// Uses ADHD-friendly framing and includes [MEAL:] and [SHOP:] action markers
/// for structured extraction by ActionExtractor.
class MealPlanPromptBuilder {

    // MARK: - System Prompt

    /// Build the system prompt that instructs the LLM how to behave as a meal planning assistant.
    /// Includes ADHD-aware guidelines and action marker format for [MEAL:] and [SHOP:] tags.
    /// - Returns: A system prompt string for the LLM
    func buildSystemPrompt() -> String {
        """
        You are a meal planning assistant for someone with ADHD. Your job is to suggest \
        concrete meals from their recipe library — not generic ideas.

        Guidelines:
        - Suggest recipes the user already has. Reference them by exact title.
        - Keep plans realistic: max 2 complex meals per week, rest should be quick/easy.
        - Consider variety: don't repeat proteins or cuisines on consecutive days.
        - Factor in leftovers: suggest cooking extra on Sunday for Monday lunch, etc.
        - If the user has nutrition targets, try to roughly align suggestions.

        When suggesting a full meal plan, use these markers (one per meal slot):
        [MEAL: day | meal | Recipe Title | recipe_id: N]

        Example:
        [MEAL: monday | dinner | Pasta Carbonara | recipe_id: 42]
        [MEAL: tuesday | lunch | leftover Pasta Carbonara | recipe_id: 42]

        When the user confirms the plan, also suggest shopping items:
        [SHOP: ingredient | amount | unit | category]

        Categories: produce, dairy, meat, pantry, frozen, bakery, other

        Example:
        [SHOP: spaghetti | 400 | g | pantry]
        [SHOP: guanciale | 200 | g | meat]

        Only include [MEAL:] and [SHOP:] markers when making concrete suggestions. \
        During discussion, just talk normally.
        """
    }

    // MARK: - Planning Prompt

    /// Build a user-facing prompt that includes recipe context and conversation history.
    /// - Parameters:
    ///   - query: The user's current meal planning question
    ///   - context: Formatted recipe library and dietary context from MealPlanContextBuilder
    ///   - conversationHistory: Previous conversation turns as (role, content) tuples
    /// - Returns: A formatted prompt string for the LLM
    func buildPlanningPrompt(
        query: String,
        context: String,
        conversationHistory: [(role: String, content: String)]
    ) -> String {
        var prompt = ""

        if !context.isEmpty {
            prompt += context + "\n\n"
        }

        if !conversationHistory.isEmpty {
            prompt += "## Conversation So Far\n\n"
            for turn in conversationHistory.suffix(6) {
                let label = turn.role == "user" ? "User" : "Assistant"
                prompt += "**\(label):** \(turn.content)\n\n"
            }
        }

        prompt += "**User:** \(query)"

        return prompt
    }
}
