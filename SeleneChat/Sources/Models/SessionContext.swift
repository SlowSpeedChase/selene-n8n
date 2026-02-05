import Foundation

/// Manages conversation context for LLM prompts
struct SessionContext {
    let messages: [Message]

    /// Maximum tokens to allocate for conversation history
    static let maxHistoryTokens = 2000

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
}
