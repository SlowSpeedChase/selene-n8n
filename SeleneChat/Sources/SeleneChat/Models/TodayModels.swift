import Foundation

/// A note with optional thread connection for Today view
struct NoteWithThread: Identifiable {
    let id: Int64
    let title: String
    let preview: String
    let createdAt: Date
    let threadName: String?
    let threadId: Int64?

    var relativeTime: String {
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .abbreviated
        return formatter.localizedString(for: createdAt, relativeTo: Date())
    }
}

/// Thread summary for Heating Up column
struct ThreadSummary: Identifiable {
    let id: Int64
    let name: String
    let summary: String
    let noteCount: Int
    let momentumScore: Double
    let recentNoteTitles: [String]

    var summaryPreview: String {
        String(summary.prefix(100))
    }
}
