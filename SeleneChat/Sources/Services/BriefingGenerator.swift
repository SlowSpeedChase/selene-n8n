import Foundation

/// Generates morning briefing prompts and parses LLM responses
class BriefingGenerator {
    private let contextBuilder = ThinkingPartnerContextBuilder()

    /// Maximum number of threads to include in briefing context
    private let maxThreadsInBriefing = 5

    /// Build the briefing prompt with thread context
    /// - Parameters:
    ///   - threads: Active threads to include in context
    ///   - recentNotes: Recent notes to include in context
    /// - Returns: A complete prompt for the LLM to generate a morning briefing
    func buildBriefingPrompt(threads: [Thread], recentNotes: [Note]) -> String {
        // Sort threads by momentum (highest first) and take top 5
        let sortedThreads = threads.sorted { ($0.momentumScore ?? 0) > ($1.momentumScore ?? 0) }
        let topThreads = Array(sortedThreads.prefix(maxThreadsInBriefing))

        // Build context using ThinkingPartnerContextBuilder
        let context = contextBuilder.buildBriefingContext(threads: topThreads, recentNotes: recentNotes)

        // Build the complete prompt
        let systemPrompt = """
        You are a thinking partner for someone with ADHD. Your role is to help externalize working memory \
        and make information visible and accessible.
        """

        let instructions = """
        Generate a morning briefing based on the context below. Guidelines:
        - Highlight 2-3 threads maximum (don't overwhelm)
        - Note any tensions or interesting connections between threads
        - Suggest a focus area for today based on momentum
        - End with an open question to spark engagement
        - Keep the briefing under 150 words
        """

        return """
        \(systemPrompt)

        \(instructions)

        ---

        \(context)
        """
    }

    /// Parse the LLM response into a Briefing struct
    /// - Parameters:
    ///   - response: The raw LLM response text
    ///   - threads: The threads that were included in the prompt context
    /// - Returns: A Briefing struct with parsed content and metadata
    func parseBriefingResponse(_ response: String, threads: [Thread]) -> Briefing {
        // Find suggested thread: check which thread names appear in response
        // Sort by momentum (highest first) and return first match
        let sortedThreads = threads.sorted { ($0.momentumScore ?? 0) > ($1.momentumScore ?? 0) }

        var suggestedThread: String?
        for thread in sortedThreads {
            if response.contains(thread.name) {
                suggestedThread = thread.name
                break
            }
        }

        return Briefing(
            content: response,
            suggestedThread: suggestedThread,
            threadCount: threads.count,
            generatedAt: Date()
        )
    }
}
