import Foundation

/// Builds context for Thinking Partner queries (briefing, synthesis, deep-dive)
class ThinkingPartnerContextBuilder {

    // MARK: - Thread Formatting

    /// Format a single thread for context
    func formatThread(_ thread: Thread) -> String {
        var result = "**\(thread.name)** (\(thread.status) \(thread.statusEmoji))\n"
        result += "- \(thread.noteCount) notes | Momentum: \(thread.momentumDisplay)\n"
        result += "- Last activity: \(thread.lastActivityDisplay)\n"

        if let why = thread.why, !why.isEmpty {
            result += "- Why: \(why)\n"
        }

        if let summary = thread.summary, !summary.isEmpty {
            let truncatedSummary = String(summary.prefix(150))
            result += "- Summary: \(truncatedSummary)\(summary.count > 150 ? "..." : "")\n"
        }

        return result
    }

    // MARK: - Token Management

    /// Estimate token count (4 chars per token)
    func estimateTokens(_ text: String) -> Int {
        return text.count / 4
    }

    /// Truncate text to fit within token budget
    func truncateToFit(_ text: String, maxTokens: Int) -> String {
        let maxChars = maxTokens * 4
        if text.count <= maxChars {
            return text
        }
        return String(text.prefix(maxChars)) + "\n[Truncated for token limit]"
    }

    // MARK: - Briefing Context

    /// Build context for morning briefing
    /// Includes: active threads with momentum, recent notes
    func buildBriefingContext(threads: [Thread], recentNotes: [Note]) -> String {
        let tokenBudget = ThinkingPartnerQueryType.briefing.tokenBudget
        var context = "## Active Threads\n\n"
        var currentTokens = estimateTokens(context)

        // Add threads (sorted by momentum, highest first)
        let sortedThreads = threads.sorted { ($0.momentumScore ?? 0) > ($1.momentumScore ?? 0) }

        for thread in sortedThreads {
            let threadText = formatThread(thread) + "\n"
            let threadTokens = estimateTokens(threadText)

            if currentTokens + threadTokens > tokenBudget - 200 {  // Reserve 200 for notes
                break
            }

            context += threadText
            currentTokens += threadTokens
        }

        // Add recent notes section
        if !recentNotes.isEmpty {
            context += "\n## Recent Notes\n\n"

            for note in recentNotes.prefix(5) {
                let noteText = "- \"\(note.title)\" (\(formatDate(note.createdAt)))\n"
                let noteTokens = estimateTokens(noteText)

                if currentTokens + noteTokens > tokenBudget {
                    break
                }

                context += noteText
                currentTokens += noteTokens
            }
        }

        return context
    }

    // MARK: - Helpers

    private func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .none
        return formatter.string(from: date)
    }
}
