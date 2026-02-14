import Foundation

struct SubprojectSuggestion: Identifiable {
    let id: Int
    let sourceProjectId: String
    let suggestedConcept: String
    var suggestedName: String?
    let taskCount: Int
    let taskIds: [String]
    var status: Status
    var createdProjectId: String?
    let detectedAt: Date
    var actionedAt: Date?
    var sourceProjectName: String?

    enum Status: String {
        case pending
        case approved
        case dismissed
    }

    var suggestionText: String {
        let name = suggestedName ?? suggestedConcept.capitalized
        return "Spin off '\(name)' as its own project?"
    }

    var detailText: String {
        "\(taskCount) tasks share the '\(suggestedConcept)' concept"
    }
}
