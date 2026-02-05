import Foundation

/// A memory extracted from conversations
struct ConversationMemory: Identifiable, Codable, Hashable {
    let id: Int64
    let content: String
    let sourceSessionId: String?
    let memoryType: MemoryType
    var confidence: Double
    var lastAccessed: Date?
    let createdAt: Date
    var updatedAt: Date

    enum MemoryType: String, Codable, CaseIterable {
        case preference
        case fact
        case pattern
        case context
    }

    init(
        id: Int64,
        content: String,
        sourceSessionId: String? = nil,
        memoryType: MemoryType,
        confidence: Double = 1.0,
        lastAccessed: Date? = nil,
        createdAt: Date = Date(),
        updatedAt: Date = Date()
    ) {
        self.id = id
        self.content = content
        self.sourceSessionId = sourceSessionId
        self.memoryType = memoryType
        self.confidence = confidence
        self.lastAccessed = lastAccessed
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }
}
