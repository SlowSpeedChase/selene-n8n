import Foundation

struct Thread: Identifiable, Hashable {
    let id: Int64
    let name: String
    let why: String?
    let summary: String?
    let status: String
    let noteCount: Int
    let momentumScore: Double?
    let lastActivityAt: Date?
    let createdAt: Date

    var momentumDisplay: String {
        guard let score = momentumScore else { return "—" }
        return String(format: "%.1f", score)
    }

    var lastActivityDisplay: String {
        guard let date = lastActivityAt else { return "No activity" }
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .abbreviated
        return formatter.localizedString(for: date, relativeTo: Date())
    }

    var statusEmoji: String {
        switch status {
        case "active": return "🔥"
        case "paused": return "⏸️"
        case "completed": return "✅"
        case "abandoned": return "💤"
        default: return "📌"
        }
    }
}

#if DEBUG
extension Thread {
    static func mock(
        id: Int64 = 1,
        name: String = "Test Thread",
        why: String? = nil,
        summary: String? = "Test summary",
        status: String = "active",
        noteCount: Int = 5,
        momentumScore: Double? = 0.5,
        lastActivityAt: Date? = Date(),
        createdAt: Date = Date()
    ) -> Thread {
        Thread(
            id: id,
            name: name,
            why: why,
            summary: summary,
            status: status,
            noteCount: noteCount,
            momentumScore: momentumScore,
            lastActivityAt: lastActivityAt,
            createdAt: createdAt
        )
    }
}
#endif
