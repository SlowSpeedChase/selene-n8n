import Foundation

/// Builds specialized prompts for cross-thread synthesis and prioritization queries
class SynthesisPromptBuilder {
    private let contextBuilder = ThinkingPartnerContextBuilder()

    // MARK: - Public Methods

    /// Build a synthesis prompt for cross-thread prioritization
    /// - Parameters:
    ///   - threads: Active threads to consider for prioritization
    ///   - notesPerThread: Recent notes organized by thread ID
    /// - Returns: A complete prompt for the LLM
    func buildSynthesisPrompt(threads: [Thread], notesPerThread: [Int64: [Note]]) -> String {
        let context = contextBuilder.buildSynthesisContext(threads: threads, notesPerThread: notesPerThread)

        return buildPromptWithContext(context: context, conversationHistory: nil, currentQuery: nil)
    }

    /// Build a synthesis prompt with conversation history for follow-up queries
    /// - Parameters:
    ///   - threads: Active threads to consider for prioritization
    ///   - notesPerThread: Recent notes organized by thread ID
    ///   - conversationHistory: Previous conversation turns
    ///   - currentQuery: The user's current question
    /// - Returns: A complete prompt for the LLM
    func buildSynthesisPromptWithHistory(
        threads: [Thread],
        notesPerThread: [Int64: [Note]],
        conversationHistory: String,
        currentQuery: String
    ) -> String {
        let context = contextBuilder.buildSynthesisContext(threads: threads, notesPerThread: notesPerThread)

        return buildPromptWithContext(context: context, conversationHistory: conversationHistory, currentQuery: currentQuery)
    }

    // MARK: - Private Methods

    private func buildPromptWithContext(context: String, conversationHistory: String?, currentQuery: String?) -> String {
        var prompt = """
        You are a thinking partner for someone with ADHD. Your role is to help them make decisions about where to focus their energy.

        \(context)

        ## Your Task

        Based on these threads, help prioritize where to focus:

        1. **Identify momentum** - Which threads have energy and recent activity?
        2. **Note tensions** - Any threads pulling in different directions?
        3. **Find connections** - How might threads relate to each other?
        4. **Suggest focus** - Make a concrete recommendation
        5. **Offer to go deeper** - Ask if they want to explore any thread further

        ## Response Format

        End your response with a clear recommendation:

        **Recommended Focus:** [Thread Name]
        **Why:** [1-2 sentence reason]

        ## Guidelines

        - Be direct. Avoid "it depends." Make a specific recommendation.
        - Consider thread momentum, urgency, and cognitive load
        - Keep your response under 200 words

        """

        // Add conversation history if present
        if let history = conversationHistory, !history.isEmpty {
            prompt += """

            ## Conversation History

            \(history)

            """
        }

        // Add current query if present
        if let query = currentQuery, !query.isEmpty {
            prompt += """

            ## Current Question

            \(query)
            """
        }

        return prompt
    }
}
