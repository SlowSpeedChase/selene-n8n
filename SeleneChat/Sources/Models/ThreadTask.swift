import Foundation

/// A task linked to a semantic thread
struct ThreadTask: Identifiable, Hashable {
    let id: Int64
    let threadId: Int64
    let thingsTaskId: String
    let createdAt: Date
    let completedAt: Date?

    /// Title fetched from Things (not stored in Selene)
    var title: String?

    /// Whether the task is completed
    var isCompleted: Bool {
        completedAt != nil
    }

    var completedDisplay: String {
        guard let date = completedAt else { return "" }
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .abbreviated
        return "Done \(formatter.localizedString(for: date, relativeTo: Date()))"
    }
}

#if DEBUG
extension ThreadTask {
    static func mock(
        id: Int64 = 1,
        threadId: Int64 = 1,
        thingsTaskId: String = "ABC123",
        title: String? = "Sample Task",
        createdAt: Date = Date(),
        completedAt: Date? = nil
    ) -> ThreadTask {
        var task = ThreadTask(
            id: id,
            threadId: threadId,
            thingsTaskId: thingsTaskId,
            createdAt: createdAt,
            completedAt: completedAt
        )
        task.title = title
        return task
    }
}
#endif
