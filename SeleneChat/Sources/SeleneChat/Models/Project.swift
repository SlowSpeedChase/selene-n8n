import Foundation

struct Project: Identifiable, Hashable, Codable {
    let id: Int
    var name: String
    var status: Status
    var primaryConcept: String?
    var thingsProjectId: String?
    let createdAt: Date
    var lastActiveAt: Date?
    var completedAt: Date?
    var testRun: String?
    var isSystem: Bool = false

    // Computed from joins
    var noteCount: Int = 0
    var taskCount: Int = 0
    var completedTaskCount: Int = 0
    var threadCount: Int = 0
    var hasReviewBadge: Bool = false

    enum Status: String, CaseIterable, Codable {
        case active
        case parked
        case completed

        var icon: String {
            switch self {
            case .active: return "flame"
            case .parked: return "parkingsign"
            case .completed: return "checkmark.circle"
            }
        }

        var color: String {
            switch self {
            case .active: return "orange"
            case .parked: return "gray"
            case .completed: return "green"
            }
        }
    }

    var timeSinceActive: String? {
        guard let lastActive = lastActiveAt else { return nil }
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .abbreviated
        return formatter.localizedString(for: lastActive, relativeTo: Date())
    }
}
