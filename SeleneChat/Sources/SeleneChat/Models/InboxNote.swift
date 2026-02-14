import Foundation

struct InboxNote: Identifiable, Hashable, Codable {
    let id: Int
    let title: String
    let content: String
    let createdAt: Date

    // Inbox-specific
    var inboxStatus: InboxStatus
    var suggestedType: NoteType?
    var suggestedProjectId: Int?
    var suggestedProjectName: String?

    // From processed_notes
    var concepts: [String]?
    var primaryTheme: String?
    var energyLevel: String?

    enum InboxStatus: String, Codable {
        case pending
        case triaged
        case archived
    }

    var preview: String {
        String(content.prefix(150))
    }

    var formattedDate: String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        return formatter.string(from: createdAt)
    }
}
