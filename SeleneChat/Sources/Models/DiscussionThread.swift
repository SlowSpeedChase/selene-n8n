import Foundation

struct DiscussionThread: Identifiable, Hashable {
    let id: Int
    let rawNoteId: Int
    let threadType: ThreadType
    let prompt: String
    var status: Status
    let createdAt: Date
    var surfacedAt: Date?
    var completedAt: Date?
    let relatedConcepts: [String]?
    var resurfaceReason: ResurfaceReason?

    // Associated note content (loaded separately)
    var noteTitle: String?
    var noteContent: String?

    enum ThreadType: String, CaseIterable {
        case planning
        case followup
        case question

        var displayName: String {
            switch self {
            case .planning: return "Planning"
            case .followup: return "Follow-up"
            case .question: return "Question"
            }
        }

        var icon: String {
            switch self {
            case .planning: return "list.bullet.clipboard"
            case .followup: return "arrow.uturn.forward"
            case .question: return "questionmark.circle"
            }
        }
    }

    enum Status: String, CaseIterable {
        case pending
        case active
        case completed
        case dismissed
        case review

        var icon: String {
            switch self {
            case .pending: return "clock"
            case .active: return "play.circle"
            case .completed: return "checkmark.circle"
            case .dismissed: return "xmark.circle"
            case .review: return "arrow.triangle.2.circlepath"
            }
        }

        var color: String {
            switch self {
            case .pending: return "gray"
            case .active: return "blue"
            case .completed: return "green"
            case .dismissed: return "secondary"
            case .review: return "orange"
            }
        }
    }

    enum ResurfaceReason: String {
        case progress = "progress"
        case stuck = "stuck"
        case completion = "completion"

        var message: String {
            switch self {
            case .progress: return "Good progress! Ready to plan next steps?"
            case .stuck: return "This seems stuck. Want to rethink the approach?"
            case .completion: return "All tasks done! Want to reflect or plan what's next?"
            }
        }
    }

    var timeSinceCreated: String {
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .abbreviated
        return formatter.localizedString(for: createdAt, relativeTo: Date())
    }
}
