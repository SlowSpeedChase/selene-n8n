import Foundation

struct ChatSession: Identifiable, Codable {
    let id: UUID
    var messages: [Message]
    var createdAt: Date
    var updatedAt: Date
    var title: String

    // Persistence tracking
    var isPinned: Bool
    var compressionState: CompressionState
    var compressedAt: Date?
    var summaryText: String?

    init(
        id: UUID = UUID(),
        messages: [Message] = [],
        createdAt: Date = Date(),
        updatedAt: Date = Date(),
        title: String = "New Chat",
        isPinned: Bool = false,
        compressionState: CompressionState = .full,
        compressedAt: Date? = nil,
        summaryText: String? = nil
    ) {
        self.id = id
        self.messages = messages
        self.createdAt = createdAt
        self.updatedAt = updatedAt
        self.title = title
        self.isPinned = isPinned
        self.compressionState = compressionState
        self.compressedAt = compressedAt
        self.summaryText = summaryText
    }

    enum CompressionState: String, Codable {
        case full          // Full messages available
        case processing    // Compression in progress
        case compressed    // Only summary available
    }

    mutating func addMessage(_ message: Message) {
        messages.append(message)
        updatedAt = Date()

        // Auto-generate title from first user message if still "New Chat"
        if title == "New Chat", message.role == .user, !message.content.isEmpty {
            title = String(message.content.prefix(50))
        }
    }

    var lastMessage: Message? {
        messages.last
    }

    var formattedDate: String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        return formatter.string(from: updatedAt)
    }
}
