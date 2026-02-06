import Foundation

/// Manages conversation context for LLM prompts
struct SessionContext {
    let messages: [Message]

    /// Maximum tokens to allocate for conversation history
    static let maxHistoryTokens = 2000

    /// Number of recent turns to keep verbatim (1 turn = user + assistant)
    static let recentTurnsVerbatim = 4

    /// Format messages for inclusion in LLM prompt
    var formattedHistory: String {
        guard !messages.isEmpty else { return "" }

        return messages.map { message in
            let role = message.role == .user ? "User" : "Selene"
            return "\(role): \(message.content)"
        }.joined(separator: "\n\n")
    }

    /// Rough token estimate (4 chars per token)
    var estimatedTokens: Int {
        let totalChars = formattedHistory.count
        return totalChars / 4
    }

    /// Get history truncated to fit within token limit, preserving recent messages
    func truncatedHistory(maxTokens: Int) -> String {
        guard !messages.isEmpty else { return "" }

        var result: [String] = []
        var currentTokens = 0

        // Process messages from most recent to oldest
        for message in messages.reversed() {
            let role = message.role == .user ? "User" : "Selene"
            let formatted = "\(role): \(message.content)"
            let messageTokens = formatted.count / 4

            if currentTokens + messageTokens > maxTokens {
                break
            }

            result.insert(formatted, at: 0)
            currentTokens += messageTokens
        }

        return result.joined(separator: "\n\n")
    }

    /// Get history with older messages summarized
    /// - Parameter recentTurnCount: Number of recent message pairs to keep verbatim
    func historyWithSummary(recentTurnCount: Int = SessionContext.recentTurnsVerbatim) -> String {
        guard !messages.isEmpty else { return "" }

        let recentMessageCount = recentTurnCount * 2  // user + assistant per turn

        // If we have few enough messages, just return them all
        if messages.count <= recentMessageCount {
            return formattedHistory
        }

        // Split into old and recent
        let oldMessages = Array(messages.prefix(messages.count - recentMessageCount))
        let recentMessages = Array(messages.suffix(recentMessageCount))

        // Summarize old messages (simple extraction for now - LLM summary in Phase 2)
        let oldTopics = extractTopics(from: oldMessages)
        let summary = "[Earlier in conversation: \(oldTopics)]"

        // Format recent messages verbatim
        let recentFormatted = recentMessages.map { message in
            let role = message.role == .user ? "User" : "Selene"
            return "\(role): \(message.content)"
        }.joined(separator: "\n\n")

        return "\(summary)\n\n\(recentFormatted)"
    }

    /// Extract key topics from messages (simple heuristic for now)
    private func extractTopics(from messages: [Message]) -> String {
        let userMessages = messages.filter { $0.role == .user }

        // Take first few words from each user message as topic hints
        let topics = userMessages.map { message in
            let words = message.content.split(separator: " ").prefix(5)
            return words.joined(separator: " ")
        }

        if topics.isEmpty {
            return "general discussion"
        }

        return topics.joined(separator: "; ")
    }
}
