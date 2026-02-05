import Foundation

/// Builds conversation context from session history for inclusion in LLM prompts
class SessionContextService {
    private let maxContextTokens = 2000
    private let maxContextChars: Int

    init() {
        self.maxContextChars = maxContextTokens * 4
    }

    func buildConversationContext(from session: ChatSession) -> String {
        let messages = session.messages
        guard !messages.isEmpty else { return "" }

        var contextLines: [String] = []
        for message in messages {
            let roleName: String
            switch message.role {
            case .user: roleName = "User"
            case .assistant: roleName = "Selene"
            case .system: continue // Skip system messages in context
            }
            contextLines.append("\(roleName): \(message.content)")
        }
        return contextLines.joined(separator: "\n\n")
    }
}
