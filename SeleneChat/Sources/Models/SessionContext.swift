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
}
