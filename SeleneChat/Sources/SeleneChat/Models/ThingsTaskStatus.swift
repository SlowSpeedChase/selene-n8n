// ThingsTaskStatus.swift
// SeleneChat
//
// Phase 7.2e: Bidirectional Things Flow
// Model for task status returned from Things 3 via AppleScript

import Foundation

struct ThingsTaskStatus: Codable {
    let id: String
    let status: String        // "open", "completed", "canceled"
    let name: String
    let completionDate: Date?
    let modificationDate: Date
    let creationDate: Date
    let project: String?
    let area: String?
    let tags: [String]

    var isCompleted: Bool {
        status == "completed"
    }

    var isOpen: Bool {
        status == "open"
    }

    var isCanceled: Bool {
        status == "canceled"
    }

    enum CodingKeys: String, CodingKey {
        case id, status, name, project, area, tags
        case completionDate = "completion_date"
        case modificationDate = "modification_date"
        case creationDate = "creation_date"
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)

        id = try container.decode(String.self, forKey: .id)
        status = try container.decode(String.self, forKey: .status)
        name = try container.decode(String.self, forKey: .name)
        project = try container.decodeIfPresent(String.self, forKey: .project)
        area = try container.decodeIfPresent(String.self, forKey: .area)
        tags = try container.decodeIfPresent([String].self, forKey: .tags) ?? []

        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy-MM-dd"

        if let dateStr = try container.decodeIfPresent(String.self, forKey: .completionDate) {
            completionDate = dateFormatter.date(from: dateStr)
        } else {
            completionDate = nil
        }

        let modStr = try container.decode(String.self, forKey: .modificationDate)
        modificationDate = dateFormatter.date(from: modStr) ?? Date()

        let createStr = try container.decode(String.self, forKey: .creationDate)
        creationDate = dateFormatter.date(from: createStr) ?? Date()
    }

    // For creating test instances
    init(
        id: String,
        status: String,
        name: String,
        completionDate: Date? = nil,
        modificationDate: Date = Date(),
        creationDate: Date = Date(),
        project: String? = nil,
        area: String? = nil,
        tags: [String] = []
    ) {
        self.id = id
        self.status = status
        self.name = name
        self.completionDate = completionDate
        self.modificationDate = modificationDate
        self.creationDate = creationDate
        self.project = project
        self.area = area
        self.tags = tags
    }
}

// MARK: - Sync Result

struct SyncResult {
    let total: Int
    let synced: Int
    let newlyCompleted: Int
    let errors: Int

    var hasErrors: Bool { errors > 0 }
    var allSynced: Bool { synced == total }
}

// MARK: - Things Status Errors

enum ThingsStatusError: Error, LocalizedError {
    case scriptNotFound
    case executionFailed(String)
    case invalidResponse
    case taskNotFound(String)

    var errorDescription: String? {
        switch self {
        case .scriptNotFound:
            return "get-task-status.scpt not found"
        case .executionFailed(let msg):
            return "AppleScript failed: \(msg)"
        case .invalidResponse:
            return "Invalid JSON response from Things"
        case .taskNotFound(let id):
            return "Task not found: \(id)"
        }
    }
}
