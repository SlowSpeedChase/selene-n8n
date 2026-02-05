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
}
