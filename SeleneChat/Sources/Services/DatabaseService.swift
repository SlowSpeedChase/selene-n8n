import Foundation
import SQLite

class DatabaseService: ObservableObject {
    static let shared = DatabaseService()

    @Published var isConnected = false
    @Published var databasePath: String {
        didSet {
            UserDefaults.standard.set(databasePath, forKey: "databasePath")
            connect()
        }
    }

    private var db: Connection?

    // Table references
    private let rawNotes = Table("raw_notes")
    private let processedNotes = Table("processed_notes")
    private let sentimentHistory = Table("sentiment_history")

    // raw_notes columns
    private let id = Expression<Int64>("id")
    private let title = Expression<String>("title")
    private let content = Expression<String>("content")
    private let contentHash = Expression<String>("content_hash")
    private let sourceType = Expression<String>("source_type")
    private let wordCount = Expression<Int64>("word_count")
    private let characterCount = Expression<Int64>("character_count")
    private let tags = Expression<String?>("tags")
    private let createdAt = Expression<String>("created_at")
    private let importedAt = Expression<String>("imported_at")
    private let processedAt = Expression<String?>("processed_at")
    private let exportedAt = Expression<String?>("exported_at")
    private let status = Expression<String>("status")
    private let exportedToObsidian = Expression<Int64>("exported_to_obsidian")
    private let sourceUUID = Expression<String?>("source_uuid")
    private let testRun = Expression<String?>("test_run")

    // processed_notes columns
    private let rawNoteId = Expression<Int64>("raw_note_id")
    private let concepts = Expression<String?>("concepts")
    private let conceptConfidence = Expression<String?>("concept_confidence")
    private let primaryTheme = Expression<String?>("primary_theme")
    private let secondaryThemes = Expression<String?>("secondary_themes")
    private let themeConfidence = Expression<Double?>("theme_confidence")
    private let overallSentiment = Expression<String?>("overall_sentiment")
    private let sentimentScore = Expression<Double?>("sentiment_score")
    private let emotionalTone = Expression<String?>("emotional_tone")
    private let energyLevel = Expression<String?>("energy_level")

    init() {
        // Try to load saved path, otherwise use default
        let defaultPath = "/Users/chaseeasterling/selene-n8n/data/selene.db"
        self.databasePath = UserDefaults.standard.string(forKey: "databasePath") ?? defaultPath
        connect()
    }

    private func connect() {
        do {
            db = try Connection(databasePath, readonly: true)
            isConnected = true
            print("✅ Connected to database at: \(databasePath)")
        } catch {
            isConnected = false
            print("❌ Failed to connect to database: \(error)")
        }
    }

    func getAllNotes(limit: Int = 100) async throws -> [Note] {
        guard let db = db else {
            throw DatabaseError.notConnected
        }

        let query = rawNotes
            .join(.leftOuter, processedNotes, on: rawNotes[id] == processedNotes[rawNoteId])
            .order(rawNotes[createdAt].desc)
            .limit(limit)

        var notes: [Note] = []

        for row in try db.prepare(query) {
            let note = try parseNote(from: row)
            notes.append(note)
        }

        return notes
    }

    func searchNotes(query: String, limit: Int = 50) async throws -> [Note] {
        guard let db = db else {
            throw DatabaseError.notConnected
        }

        let searchQuery = rawNotes
            .join(.leftOuter, processedNotes, on: rawNotes[id] == processedNotes[rawNoteId])
            .filter(rawNotes[content].like("%\(query)%") || rawNotes[title].like("%\(query)%"))
            .order(rawNotes[createdAt].desc)
            .limit(limit)

        var notes: [Note] = []

        for row in try db.prepare(searchQuery) {
            let note = try parseNote(from: row)
            notes.append(note)
        }

        return notes
    }

    func getNoteByConcept(_ concept: String, limit: Int = 50) async throws -> [Note] {
        guard let db = db else {
            throw DatabaseError.notConnected
        }

        let query = rawNotes
            .join(.inner, processedNotes, on: rawNotes[id] == processedNotes[rawNoteId])
            .filter(processedNotes[concepts].like("%\(concept)%"))
            .order(rawNotes[createdAt].desc)
            .limit(limit)

        var notes: [Note] = []

        for row in try db.prepare(query) {
            let note = try parseNote(from: row)
            notes.append(note)
        }

        return notes
    }

    func getNotesByTheme(_ theme: String, limit: Int = 50) async throws -> [Note] {
        guard let db = db else {
            throw DatabaseError.notConnected
        }

        let query = rawNotes
            .join(.inner, processedNotes, on: rawNotes[id] == processedNotes[rawNoteId])
            .filter(processedNotes[primaryTheme] == theme || processedNotes[secondaryThemes].like("%\(theme)%"))
            .order(rawNotes[createdAt].desc)
            .limit(limit)

        var notes: [Note] = []

        for row in try db.prepare(query) {
            let note = try parseNote(from: row)
            notes.append(note)
        }

        return notes
    }

    func getNotesByEnergy(_ energy: String, limit: Int = 50) async throws -> [Note] {
        guard let db = db else {
            throw DatabaseError.notConnected
        }

        let query = rawNotes
            .join(.inner, processedNotes, on: rawNotes[id] == processedNotes[rawNoteId])
            .filter(processedNotes[energyLevel] == energy)
            .order(rawNotes[createdAt].desc)
            .limit(limit)

        var notes: [Note] = []

        for row in try db.prepare(query) {
            let note = try parseNote(from: row)
            notes.append(note)
        }

        return notes
    }

    func getNotesByDateRange(from: Date, to: Date) async throws -> [Note] {
        guard let db = db else {
            throw DatabaseError.notConnected
        }

        let dateFormatter = ISO8601DateFormatter()
        let fromStr = dateFormatter.string(from: from)
        let toStr = dateFormatter.string(from: to)

        let query = rawNotes
            .join(.leftOuter, processedNotes, on: rawNotes[id] == processedNotes[rawNoteId])
            .filter(rawNotes[createdAt] >= fromStr && rawNotes[createdAt] <= toStr)
            .order(rawNotes[createdAt].desc)

        var notes: [Note] = []

        for row in try db.prepare(query) {
            let note = try parseNote(from: row)
            notes.append(note)
        }

        return notes
    }

    func getNote(byId noteId: Int) async throws -> Note? {
        guard let db = db else {
            throw DatabaseError.notConnected
        }

        let query = rawNotes
            .join(.leftOuter, processedNotes, on: rawNotes[id] == processedNotes[rawNoteId])
            .filter(rawNotes[id] == Int64(noteId))

        guard let row = try db.pluck(query) else {
            return nil
        }

        return try parseNote(from: row)
    }

    private func parseNote(from row: Row) throws -> Note {
        let dateFormatter = ISO8601DateFormatter()

        // Parse tags JSON
        var tagsArray: [String]? = nil
        if let tagsStr = try? row.get(tags), let data = tagsStr.data(using: .utf8) {
            tagsArray = try? JSONDecoder().decode([String].self, from: data)
        }

        // Parse concepts JSON
        var conceptsArray: [String]? = nil
        if let conceptsStr = try? row.get(concepts), let data = conceptsStr.data(using: .utf8) {
            conceptsArray = try? JSONDecoder().decode([String].self, from: data)
        }

        // Parse concept confidence JSON
        var conceptConfidenceDict: [String: Double]? = nil
        if let confStr = try? row.get(conceptConfidence), let data = confStr.data(using: .utf8) {
            conceptConfidenceDict = try? JSONDecoder().decode([String: Double].self, from: data)
        }

        // Parse secondary themes JSON
        var secondaryThemesArray: [String]? = nil
        if let themesStr = try? row.get(secondaryThemes), let data = themesStr.data(using: .utf8) {
            secondaryThemesArray = try? JSONDecoder().decode([String].self, from: data)
        }

        return Note(
            id: Int(try row.get(id)),
            title: try row.get(title),
            content: try row.get(content),
            contentHash: try row.get(contentHash),
            sourceType: try row.get(sourceType),
            wordCount: Int(try row.get(wordCount)),
            characterCount: Int(try row.get(characterCount)),
            tags: tagsArray,
            createdAt: dateFormatter.date(from: try row.get(createdAt)) ?? Date(),
            importedAt: dateFormatter.date(from: try row.get(importedAt)) ?? Date(),
            processedAt: (try? row.get(processedAt)).flatMap { dateFormatter.date(from: $0) },
            exportedAt: (try? row.get(exportedAt)).flatMap { dateFormatter.date(from: $0) },
            status: try row.get(status),
            exportedToObsidian: try row.get(exportedToObsidian) == 1,
            sourceUUID: try? row.get(sourceUUID),
            testRun: try? row.get(testRun),
            concepts: conceptsArray,
            conceptConfidence: conceptConfidenceDict,
            primaryTheme: try? row.get(primaryTheme),
            secondaryThemes: secondaryThemesArray,
            themeConfidence: try? row.get(themeConfidence),
            overallSentiment: try? row.get(overallSentiment),
            sentimentScore: try? row.get(sentimentScore),
            emotionalTone: try? row.get(emotionalTone),
            energyLevel: try? row.get(energyLevel)
        )
    }

    enum DatabaseError: Error, LocalizedError {
        case notConnected
        case queryFailed(String)

        var errorDescription: String? {
            switch self {
            case .notConnected:
                return "Database not connected"
            case .queryFailed(let message):
                return "Query failed: \(message)"
            }
        }
    }
}
