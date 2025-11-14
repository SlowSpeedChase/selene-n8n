import Foundation

struct Message: Identifiable, Codable, Hashable {
    let id: UUID
    let role: Role
    let content: String
    let timestamp: Date
    let llmTier: LLMTier
    let relatedNotes: [Int]? // Note IDs

    enum Role: String, Codable {
        case user
        case assistant
        case system
    }

    enum LLMTier: String, Codable {
        case onDevice = "On-Device (Apple Intelligence)"
        case privateCloud = "Private Cloud (Apple)"
        case external = "External (Claude)"
        case local = "Local (Ollama)"

        var icon: String {
            switch self {
            case .onDevice: return "🔒"
            case .privateCloud: return "🔐"
            case .external: return "🌐"
            case .local: return "💻"
            }
        }

        var color: String {
            switch self {
            case .onDevice: return "green"
            case .privateCloud: return "blue"
            case .external: return "orange"
            case .local: return "purple"
            }
        }
    }

    init(
        id: UUID = UUID(),
        role: Role,
        content: String,
        timestamp: Date = Date(),
        llmTier: LLMTier,
        relatedNotes: [Int]? = nil
    ) {
        self.id = id
        self.role = role
        self.content = content
        self.timestamp = timestamp
        self.llmTier = llmTier
        self.relatedNotes = relatedNotes
    }

    var formattedTime: String {
        let formatter = DateFormatter()
        formatter.timeStyle = .short
        return formatter.string(from: timestamp)
    }
}
