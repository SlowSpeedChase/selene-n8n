import Foundation
import SwiftUI

struct Message: Identifiable, Codable, Hashable {
    let id: UUID
    let role: Role
    let content: String
    let timestamp: Date
    let llmTier: LLMTier
    let relatedNotes: [Int]? // Note IDs

    // NEW: Citation support
    var citedNotes: [Note]? // Notes that were cited in the response
    var contextNotes: [Note]? // All notes used to build context
    var queryType: String? // For debugging/analytics
    var voiceOriginated: Bool

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
        relatedNotes: [Int]? = nil,
        citedNotes: [Note]? = nil,
        contextNotes: [Note]? = nil,
        queryType: String? = nil,
        voiceOriginated: Bool = false
    ) {
        self.id = id
        self.role = role
        self.content = content
        self.timestamp = timestamp
        self.llmTier = llmTier
        self.relatedNotes = relatedNotes
        self.citedNotes = citedNotes
        self.contextNotes = contextNotes
        self.queryType = queryType
        self.voiceOriginated = voiceOriginated
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(UUID.self, forKey: .id)
        role = try container.decode(Role.self, forKey: .role)
        content = try container.decode(String.self, forKey: .content)
        timestamp = try container.decode(Date.self, forKey: .timestamp)
        llmTier = try container.decode(LLMTier.self, forKey: .llmTier)
        relatedNotes = try container.decodeIfPresent([Int].self, forKey: .relatedNotes)
        queryType = try container.decodeIfPresent(String.self, forKey: .queryType)
        voiceOriginated = try container.decodeIfPresent(Bool.self, forKey: .voiceOriginated) ?? false
    }

    var formattedTime: String {
        let formatter = DateFormatter()
        formatter.timeStyle = .short
        return formatter.string(from: timestamp)
    }

    // NEW: Computed property for attributed content with citations
    var attributedContent: AttributedString? {
        guard !isUser, let cited = citedNotes, !cited.isEmpty else {
            return nil
        }

        let parseResult = CitationParser.parse(content)
        return parseResult.attributedText
    }

    var isUser: Bool {
        role == .user
    }

    // Custom coding keys to exclude non-codable properties
    enum CodingKeys: String, CodingKey {
        case id, role, content, timestamp, llmTier, relatedNotes, queryType, voiceOriginated
    }
}
