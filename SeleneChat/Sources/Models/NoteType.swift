import Foundation

enum NoteType: String, CaseIterable, Codable {
    case quickTask = "quick_task"
    case relatesToProject = "relates_to_project"
    case newProject = "new_project"
    case reflection = "reflection"

    var displayName: String {
        switch self {
        case .quickTask: return "Quick task"
        case .relatesToProject: return "Relates to project"
        case .newProject: return "New project idea"
        case .reflection: return "Reflection"
        }
    }

    var icon: String {
        switch self {
        case .quickTask: return "checklist"
        case .relatesToProject: return "link"
        case .newProject: return "plus.rectangle.on.folder"
        case .reflection: return "bubble.left.and.text.bubble.right"
        }
    }

    var emoji: String {
        switch self {
        case .quickTask: return "📋"
        case .relatesToProject: return "🔗"
        case .newProject: return "🆕"
        case .reflection: return "💭"
        }
    }
}
