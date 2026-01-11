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
