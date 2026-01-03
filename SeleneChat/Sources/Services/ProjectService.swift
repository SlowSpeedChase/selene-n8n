// ProjectService.swift
// SeleneChat
//
// Created for Phase 7: Planning Inbox Redesign
// Manages Active/Parked project structure with ADHD-optimized limits

import Foundation
import SQLite

class ProjectService: ObservableObject {
    static let shared = ProjectService()

    // Publish when projects change so views can refresh
    @Published var lastUpdated = Date()

    private var db: Connection?

    // Table references
    private let projects = Table("projects")
    private let projectNotes = Table("project_notes")

    // projects columns
    private let projectId = Expression<Int64>("id")
    private let projectName = Expression<String>("name")
    private let projectStatus = Expression<String>("status")
    private let primaryConcept = Expression<String?>("primary_concept")
    private let thingsProjectId = Expression<String?>("things_project_id")
    private let createdAt = Expression<String>("created_at")
    private let lastActiveAt = Expression<String?>("last_active_at")
    private let completedAt = Expression<String?>("completed_at")
    private let testRun = Expression<String?>("test_run")

    // project_notes columns
    private let pnProjectId = Expression<Int64>("project_id")
    private let pnRawNoteId = Expression<Int64>("raw_note_id")

    // ADHD-optimized limit: prevents overwhelm from too many active projects
    private let maxActiveProjects = 5

    init() {}

    func configure(with db: Connection) {
        self.db = db
    }

    // MARK: - Fetch Projects

    func getActiveProjects() async throws -> [Project] {
        guard let db = db else {
            throw DatabaseService.DatabaseError.notConnected
        }

        let query = projects
            .filter(projectStatus == "active")
            .filter(testRun == nil)
            .order(lastActiveAt.desc)

        var projectList: [Project] = []

        for row in try db.prepare(query) {
            var project = try parseProject(from: row)
            project.noteCount = try await getNoteCount(for: project.id)
            projectList.append(project)
        }

        return projectList
    }

    func getParkedProjects() async throws -> [Project] {
        guard let db = db else {
            throw DatabaseService.DatabaseError.notConnected
        }

        let query = projects
            .filter(projectStatus == "parked")
            .filter(testRun == nil)
            .order(lastActiveAt.desc)

        var projectList: [Project] = []

        for row in try db.prepare(query) {
            var project = try parseProject(from: row)
            project.noteCount = try await getNoteCount(for: project.id)
            projectList.append(project)
        }

        return projectList
    }

    private func getNoteCount(for projectIdValue: Int) async throws -> Int {
        guard let db = db else { return 0 }

        let count = try db.scalar(
            projectNotes.filter(pnProjectId == Int64(projectIdValue)).count
        )
        return count
    }

    private func parseProject(from row: Row) throws -> Project {
        let dateFormatter = ISO8601DateFormatter()

        return Project(
            id: Int(try row.get(projectId)),
            name: try row.get(projectName),
            status: Project.Status(rawValue: try row.get(projectStatus)) ?? .parked,
            primaryConcept: try? row.get(primaryConcept),
            thingsProjectId: try? row.get(thingsProjectId),
            createdAt: dateFormatter.date(from: try row.get(createdAt)) ?? Date(),
            lastActiveAt: (try? row.get(lastActiveAt)).flatMap { dateFormatter.date(from: $0) },
            completedAt: (try? row.get(completedAt)).flatMap { dateFormatter.date(from: $0) },
            testRun: try? row.get(testRun)
        )
    }

    // MARK: - Create Project

    func createProject(name: String, fromNoteId: Int? = nil, concept: String? = nil) async throws -> Project {
        guard let db = db else {
            throw DatabaseService.DatabaseError.notConnected
        }

        let dateFormatter = ISO8601DateFormatter()
        let now = dateFormatter.string(from: Date())

        let id = try db.run(projects.insert(
            projectName <- name,
            projectStatus <- "parked",
            primaryConcept <- concept,
            createdAt <- now,
            lastActiveAt <- now
        ))

        // If created from a note, attach it
        if let noteId = fromNoteId {
            try db.run(projectNotes.insert(
                pnProjectId <- id,
                pnRawNoteId <- Int64(noteId)
            ))
        }

        // Notify observers that projects changed
        await MainActor.run { lastUpdated = Date() }

        return Project(
            id: Int(id),
            name: name,
            status: .parked,
            primaryConcept: concept,
            thingsProjectId: nil,
            createdAt: Date(),
            lastActiveAt: Date(),
            completedAt: nil,
            testRun: nil,
            noteCount: fromNoteId != nil ? 1 : 0
        )
    }

    // MARK: - Status Management

    func activateProject(_ projectIdValue: Int) async throws {
        guard let db = db else {
            throw DatabaseService.DatabaseError.notConnected
        }

        // Check active count before allowing activation
        let activeCount = try db.scalar(
            projects.filter(projectStatus == "active").filter(testRun == nil).count
        )

        if activeCount >= maxActiveProjects {
            throw ProjectError.tooManyActive
        }

        let dateFormatter = ISO8601DateFormatter()
        let now = dateFormatter.string(from: Date())

        let project = projects.filter(projectId == Int64(projectIdValue))
        try db.run(project.update(
            projectStatus <- "active",
            lastActiveAt <- now
        ))

        // Notify observers that projects changed
        await MainActor.run { lastUpdated = Date() }
    }

    func parkProject(_ projectIdValue: Int) async throws {
        guard let db = db else {
            throw DatabaseService.DatabaseError.notConnected
        }

        let project = projects.filter(projectId == Int64(projectIdValue))
        try db.run(project.update(projectStatus <- "parked"))

        // Notify observers that projects changed
        await MainActor.run { lastUpdated = Date() }
    }

    func completeProject(_ projectIdValue: Int) async throws {
        guard let db = db else {
            throw DatabaseService.DatabaseError.notConnected
        }

        let dateFormatter = ISO8601DateFormatter()
        let now = dateFormatter.string(from: Date())

        let project = projects.filter(projectId == Int64(projectIdValue))
        try db.run(project.update(
            projectStatus <- "completed",
            completedAt <- now
        ))

        // Notify observers that projects changed
        await MainActor.run { lastUpdated = Date() }
    }

    // MARK: - Error Types

    enum ProjectError: Error, LocalizedError {
        case tooManyActive

        var errorDescription: String? {
            switch self {
            case .tooManyActive:
                return "Maximum 5 active projects. Park one first."
            }
        }
    }
}
