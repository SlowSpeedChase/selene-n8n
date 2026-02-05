import Foundation

/// Builds conversation context from session history for inclusion in LLM prompts
class SessionContextService {
    private let maxContextTokens: Int
    private let maxContextChars: Int
    private let recentTurnsToPreserve = 4

    init(maxContextTokens: Int = 2000) {
        self.maxContextTokens = maxContextTokens
        self.maxContextChars = maxContextTokens * 4
    }

    func buildConversationContext(from session: ChatSession) -> String {
        let messages = session.messages.filter { $0.role != .system }
        guard !messages.isEmpty else { return "" }

        // If few messages, return all verbatim
        if messages.count <= recentTurnsToPreserve {
            return formatMessages(messages)
        }

        // Split into older and recent messages
        let recentStartIndex = max(0, messages.count - recentTurnsToPreserve)
        let olderMessages = Array(messages[0..<recentStartIndex])
        let recentMessages = Array(messages[recentStartIndex...])

        // Format recent messages verbatim
        let recentFormatted = formatMessages(recentMessages)

        // Calculate remaining budget for older messages
        let headerOverhead = 40 // "[Earlier in conversation:]\n\n" + "[Recent:]\n\n"
        let remainingBudget = maxContextChars - recentFormatted.count - headerOverhead

        // If no budget for older messages, return only recent
        if remainingBudget <= 0 || olderMessages.isEmpty {
            return recentFormatted
        }

        // Compress older messages to fit budget
        let olderCompressed = compressMessages(olderMessages, maxChars: remainingBudget)

        // Combine with headers
        if olderCompressed.isEmpty {
            return recentFormatted
        }

        return "[Earlier in conversation:]\n\n\(olderCompressed)\n\n[Recent:]\n\n\(recentFormatted)"
    }

    // MARK: - Private Helpers

    private func formatMessages(_ messages: [Message]) -> String {
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

    private func compressMessages(_ messages: [Message], maxChars: Int) -> String {
        guard !messages.isEmpty else { return "" }

        // Truncate each message content to fit within budget
        let maxCharsPerMessage = 100
        var compressedLines: [String] = []
        var totalChars = 0

        for message in messages {
            let roleName: String
            switch message.role {
            case .user: roleName = "User"
            case .assistant: roleName = "Selene"
            case .system: continue
            }

            // Truncate content
            var truncatedContent = message.content
            if truncatedContent.count > maxCharsPerMessage {
                truncatedContent = String(truncatedContent.prefix(maxCharsPerMessage - 3)) + "..."
            }

            let line = "\(roleName): \(truncatedContent)"
            let lineChars = line.count + 2 // +2 for "\n\n" separator

            // Check if adding this line would exceed budget
            if totalChars + lineChars > maxChars {
                break
            }

            compressedLines.append(line)
            totalChars += lineChars
        }

        return compressedLines.joined(separator: "\n\n")
    }
}
