import Foundation
import AppKit

class ThingsURLService {
    static let shared = ThingsURLService()

    private var authToken: String? {
        ProcessInfo.processInfo.environment["THINGS_AUTH_TOKEN"]
    }

    private init() {}

    enum ThingsError: Error, LocalizedError {
        case invalidURL
        case missingAuthToken
        case openFailed

        var errorDescription: String? {
            switch self {
            case .invalidURL:
                return "Failed to build Things URL"
            case .missingAuthToken:
                return "THINGS_AUTH_TOKEN environment variable not set"
            case .openFailed:
                return "Failed to open Things"
            }
        }
    }

    // MARK: - Public Methods

    /// Build URL for adding a task to Things
    func buildAddTaskURL(
        title: String,
        notes: String? = nil,
        tags: [String] = [],
        sourceNoteId: Int? = nil,
        threadId: Int? = nil,
        deadline: Date? = nil
    ) -> URL? {
        var components = URLComponents(string: "things:///add")
        var queryItems: [URLQueryItem] = []

        // Required: title
        queryItems.append(URLQueryItem(name: "title", value: title))

        // Optional: notes with selene metadata
        var notesContent = notes ?? ""
        if let noteId = sourceNoteId, let tid = threadId {
            if !notesContent.isEmpty {
                notesContent += "\n\n"
            }
            notesContent += "[selene:note-\(noteId):thread-\(tid)]"
        }
        if !notesContent.isEmpty {
            queryItems.append(URLQueryItem(name: "notes", value: notesContent))
        }

        // Tags - always include "selene" tag
        var allTags = tags
        if !allTags.contains("selene") {
            allTags.append("selene")
        }
        queryItems.append(URLQueryItem(name: "tags", value: allTags.joined(separator: ",")))

        // Deadline
        if let deadline = deadline {
            let formatter = DateFormatter()
            formatter.dateFormat = "yyyy-MM-dd"
            queryItems.append(URLQueryItem(name: "deadline", value: formatter.string(from: deadline)))
        }

        // Auth token for modifications
        if let token = authToken {
            queryItems.append(URLQueryItem(name: "auth-token", value: token))
        }

        // Don't show quick entry
        queryItems.append(URLQueryItem(name: "show-quick-entry", value: "false"))

        components?.queryItems = queryItems
        return components?.url
    }

    /// Create a task in Things and return success
    func createTask(
        title: String,
        notes: String? = nil,
        tags: [String] = [],
        energy: String? = nil,
        sourceNoteId: Int? = nil,
        threadId: Int? = nil
    ) async throws {
        // Build energy tag if provided
        var allTags = tags
        if let energy = energy {
            allTags.append("\(energy)-energy")
        }

        guard let url = buildAddTaskURL(
            title: title,
            notes: notes,
            tags: allTags,
            sourceNoteId: sourceNoteId,
            threadId: threadId
        ) else {
            throw ThingsError.invalidURL
        }

        // Open Things URL
        let success = await MainActor.run {
            NSWorkspace.shared.open(url)
        }

        if !success {
            throw ThingsError.openFailed
        }

        print("Created task in Things: \(title)")
    }

    /// Open Things to show a specific item
    func showTask(thingsId: String) async throws {
        guard let url = URL(string: "things:///show?id=\(thingsId)") else {
            throw ThingsError.invalidURL
        }

        let success = await MainActor.run {
            NSWorkspace.shared.open(url)
        }

        if !success {
            throw ThingsError.openFailed
        }
    }

    /// Check if Things is installed
    func isThingsInstalled() -> Bool {
        let url = URL(string: "things:///")!
        return NSWorkspace.shared.urlForApplication(toOpen: url) != nil
    }
}
