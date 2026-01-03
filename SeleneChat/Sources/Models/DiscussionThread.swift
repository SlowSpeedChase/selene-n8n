import Foundation

struct DiscussionThread: Identifiable, Hashable {
    let id: Int
    let rawNoteId: Int
    let threadType: ThreadType
    var projectId: Int?
    var threadName: String?
    let prompt: String
    var status: Status
    let createdAt: Date
    var surfacedAt: Date?
    var completedAt: Date?
    let relatedConcepts: [String]?
    var resurfaceReasonCode: String?      // Raw code like "progress_50", "stuck_3d"
    var lastResurfacedAt: Date?

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

    /// Parsed resurface reason from code
    var resurfaceReason: ResurfaceReason? {
        guard let code = resurfaceReasonCode else { return nil }
        return ResurfaceReason(from: code)
    }

    struct ResurfaceReason {
        let type: ReasonType
        let message: String

        enum ReasonType {
            case progress(percent: Int)
            case stuck(days: Int)
            case completion
            case deadline(days: Int)
        }

        init?(from code: String) {
            if code.starts(with: "progress_") {
                let percentStr = code.replacingOccurrences(of: "progress_", with: "")
                let percent = Int(percentStr) ?? 50
                self.type = .progress(percent: percent)
                self.message = "Good progress! Ready to plan next steps?"
            } else if code.starts(with: "stuck_") {
                let daysStr = code.replacingOccurrences(of: "stuck_", with: "").replacingOccurrences(of: "d", with: "")
                let days = Int(daysStr) ?? 3
                self.type = .stuck(days: days)
                self.message = "This seems stuck. Want to rethink the approach?"
            } else if code == "completion" {
                self.type = .completion
                self.message = "All tasks done! Want to reflect or plan what's next?"
            } else if code.starts(with: "deadline_") {
                let daysStr = code.replacingOccurrences(of: "deadline_", with: "").replacingOccurrences(of: "d", with: "")
                let days = Int(daysStr) ?? 2
                self.type = .deadline(days: days)
                self.message = "Deadline approaching! Review your tasks?"
            } else {
                return nil
            }
        }
    }

    var timeSinceCreated: String {
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .abbreviated
        return formatter.localizedString(for: createdAt, relativeTo: Date())
    }
}
