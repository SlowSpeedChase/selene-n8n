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
    private let chatSessions = Table("chat_sessions")

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

    // chat_sessions columns
    private let sessionId = Expression<String>("id")
    private let sessionTitle = Expression<String>("title")
    private let sessionCreatedAt = Expression<String>("created_at")
    private let sessionUpdatedAt = Expression<String>("updated_at")
    private let messageCount = Expression<Int64>("message_count")
    private let isPinned = Expression<Int64>("is_pinned")
    private let compressionState = Expression<String>("compression_state")
    private let compressedAt = Expression<String?>("compressed_at")
    private let fullMessagesJson = Expression<String?>("full_messages_json")
    private let summaryText = Expression<String?>("summary_text")

    init() {
        // Try to load saved path, otherwise use default
        let defaultPath = FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent("selene-n8n/data/selene.db")
            .path
        self.databasePath = UserDefaults.standard.string(forKey: "databasePath") ?? defaultPath
        connect()
    }

    private func connect() {
        do {
            // Open database with write access for chat sessions
            db = try Connection(databasePath)
            isConnected = true
            print("✅ Connected to database at: \(databasePath)")

            // Run migration if chat_sessions table doesn't exist
            try? createChatSessionsTable()
        } catch {
            isConnected = false
            print("❌ Failed to connect to database: \(error)")
        }
    }

    private func createChatSessionsTable() throws {
        guard let db = db else { return }

        try db.run(chatSessions.create(ifNotExists: true) { t in
            t.column(sessionId, primaryKey: true)
            t.column(sessionTitle)
            t.column(sessionCreatedAt)
            t.column(sessionUpdatedAt)
            t.column(messageCount)
            t.column(isPinned, defaultValue: 0)
            t.column(compressionState, defaultValue: "full")
            t.column(compressedAt)
            t.column(fullMessagesJson)
            t.column(summaryText)
        })

        try db.run(chatSessions.createIndex(sessionUpdatedAt, ifNotExists: true))
        // Composite index for compression queries
        try db.run("CREATE INDEX IF NOT EXISTS idx_chat_sessions_compression ON chat_sessions(compression_state, created_at)")

        print("✅ Chat sessions table ready")
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

        do {
            for row in try db.prepare(searchQuery) {
                let note = try parseNote(from: row)
                notes.append(note)
            }
        } catch {
            print("❌ Error in searchNotes query: \(error)")
            print("   Query: \(query)")
            throw DatabaseError.queryFailed("Search failed: \(error.localizedDescription)")
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

        // Parse tags JSON from raw_notes
        var tagsArray: [String]? = nil
        if let tagsStr = try? row.get(rawNotes[tags]), let data = tagsStr.data(using: .utf8) {
            tagsArray = try? JSONDecoder().decode([String].self, from: data)
        }

        // Parse concepts JSON from processed_notes (may be NULL if no processed_notes entry)
        var conceptsArray: [String]? = nil
        if let conceptsStr = try? row.get(processedNotes[concepts]), let data = conceptsStr.data(using: .utf8) {
            conceptsArray = try? JSONDecoder().decode([String].self, from: data)
        }

        // Parse concept confidence JSON from processed_notes (may be NULL)
        var conceptConfidenceDict: [String: Double]? = nil
        if let confStr = try? row.get(processedNotes[conceptConfidence]), let data = confStr.data(using: .utf8) {
            conceptConfidenceDict = try? JSONDecoder().decode([String: Double].self, from: data)
        }

        // Parse secondary themes JSON from processed_notes (may be NULL)
        var secondaryThemesArray: [String]? = nil
        if let themesStr = try? row.get(processedNotes[secondaryThemes]), let data = themesStr.data(using: .utf8) {
            secondaryThemesArray = try? JSONDecoder().decode([String].self, from: data)
        }

        return Note(
            id: Int(try row.get(rawNotes[id])),
            title: try row.get(rawNotes[title]),
            content: try row.get(rawNotes[content]),
            contentHash: try row.get(rawNotes[contentHash]),
            sourceType: try row.get(rawNotes[sourceType]),
            wordCount: Int(try row.get(rawNotes[wordCount])),
            characterCount: Int(try row.get(rawNotes[characterCount])),
            tags: tagsArray,
            createdAt: dateFormatter.date(from: try row.get(rawNotes[createdAt])) ?? Date(),
            importedAt: dateFormatter.date(from: try row.get(rawNotes[importedAt])) ?? Date(),
            processedAt: (try? row.get(rawNotes[processedAt])).flatMap { dateFormatter.date(from: $0) },
            exportedAt: (try? row.get(rawNotes[exportedAt])).flatMap { dateFormatter.date(from: $0) },
            status: try row.get(rawNotes[status]),
            exportedToObsidian: try row.get(rawNotes[exportedToObsidian]) == 1,
            sourceUUID: try? row.get(rawNotes[sourceUUID]),
            testRun: try? row.get(rawNotes[testRun]),
            concepts: conceptsArray,
            conceptConfidence: conceptConfidenceDict,
            primaryTheme: try? row.get(processedNotes[primaryTheme]),
            secondaryThemes: secondaryThemesArray,
            themeConfidence: try? row.get(processedNotes[themeConfidence]),
            overallSentiment: try? row.get(processedNotes[overallSentiment]),
            sentimentScore: try? row.get(processedNotes[sentimentScore]),
            emotionalTone: try? row.get(processedNotes[emotionalTone]),
            energyLevel: try? row.get(processedNotes[energyLevel])
        )
    }

    // MARK: - Chat Session Persistence

    func saveSession(_ session: ChatSession) async throws {
        guard let db = db else {
            throw DatabaseError.notConnected
        }

        let dateFormatter = ISO8601DateFormatter()

        // Serialize messages to JSON
        let messagesData = try JSONEncoder().encode(session.messages)
        guard let messagesJson = String(data: messagesData, encoding: .utf8) else {
            throw DatabaseError.queryFailed("Failed to encode messages")
        }

        // Check if session exists
        let existingSession = chatSessions.filter(sessionId == session.id.uuidString)
        let exists = try db.pluck(existingSession) != nil

        if exists {
            // Update existing session
            try db.run(existingSession.update(
                sessionTitle <- session.title,
                sessionUpdatedAt <- dateFormatter.string(from: session.updatedAt),
                messageCount <- Int64(session.messages.count),
                isPinned <- session.isPinned ? 1 : 0,
                compressionState <- session.compressionState.rawValue,
                compressedAt <- session.compressedAt.map { dateFormatter.string(from: $0) },
                fullMessagesJson <- (session.compressionState == .full ? messagesJson : nil),
                summaryText <- session.summaryText
            ))
        } else {
            // Insert new session
            try db.run(chatSessions.insert(
                sessionId <- session.id.uuidString,
                sessionTitle <- session.title,
                sessionCreatedAt <- dateFormatter.string(from: session.createdAt),
                sessionUpdatedAt <- dateFormatter.string(from: session.updatedAt),
                messageCount <- Int64(session.messages.count),
                isPinned <- session.isPinned ? 1 : 0,
                compressionState <- session.compressionState.rawValue,
                compressedAt <- session.compressedAt.map { dateFormatter.string(from: $0) },
                fullMessagesJson <- (session.compressionState == .full ? messagesJson : nil),
                summaryText <- session.summaryText
            ))
        }

        print("✅ Saved chat session: \(session.title)")
    }

    func loadSessions() async throws -> [ChatSession] {
        guard let db = db else {
            throw DatabaseError.notConnected
        }

        let dateFormatter = ISO8601DateFormatter()
        var sessions: [ChatSession] = []

        // Query all sessions, ordered by updated_at descending
        let query = chatSessions.order(sessionUpdatedAt.desc)

        for row in try db.prepare(query) {
            let id = UUID(uuidString: try row.get(sessionId)) ?? UUID()
            let title = try row.get(sessionTitle)
            let createdAt = dateFormatter.date(from: try row.get(sessionCreatedAt)) ?? Date()
            let updatedAt = dateFormatter.date(from: try row.get(sessionUpdatedAt)) ?? Date()
            let isPinnedValue = try row.get(isPinned) == 1
            let compressionStateValue = ChatSession.CompressionState(rawValue: try row.get(compressionState)) ?? .full
            let compressedAtValue = (try? row.get(compressedAt)).flatMap { dateFormatter.date(from: $0) }
            let summaryTextValue = try? row.get(summaryText)

            // Deserialize messages if available
            var messages: [Message] = []
            if let messagesJson = try? row.get(fullMessagesJson),
               let messagesData = messagesJson.data(using: .utf8) {
                messages = (try? JSONDecoder().decode([Message].self, from: messagesData)) ?? []
            }

            let session = ChatSession(
                id: id,
                messages: messages,
                createdAt: createdAt,
                updatedAt: updatedAt,
                title: title,
                isPinned: isPinnedValue,
                compressionState: compressionStateValue,
                compressedAt: compressedAtValue,
                summaryText: summaryTextValue
            )

            sessions.append(session)
        }

        print("✅ Loaded \(sessions.count) chat sessions")
        return sessions
    }

    func deleteSession(_ session: ChatSession) async throws {
        guard let db = db else {
            throw DatabaseError.notConnected
        }

        let sessionToDelete = chatSessions.filter(sessionId == session.id.uuidString)
        try db.run(sessionToDelete.delete())

        print("✅ Deleted chat session: \(session.title)")
    }

    func updateSessionPin(sessionId: UUID, isPinned pinnedValue: Bool) async throws {
        guard let db = db else {
            throw DatabaseError.notConnected
        }

        let sessionToUpdate = chatSessions.filter(self.sessionId == sessionId.uuidString)
        try db.run(sessionToUpdate.update(isPinned <- pinnedValue ? 1 : 0))

        print("✅ Updated pin status for session: \(sessionId)")
    }

    // MARK: - Compression Methods

    func getSessionsReadyForCompression() async throws -> [ChatSession] {
        guard let db = db else {
            throw DatabaseError.notConnected
        }

        let dateFormatter = ISO8601DateFormatter()
        let thirtyDaysAgo = Calendar.current.date(byAdding: .day, value: -30, to: Date()) ?? Date()
        let thirtyDaysAgoStr = dateFormatter.string(from: thirtyDaysAgo)

        var sessions: [ChatSession] = []

        // Query sessions that are:
        // 1. Created more than 30 days ago
        // 2. Not pinned (is_pinned = 0)
        // 3. In 'full' compression state
        let query = chatSessions
            .filter(sessionCreatedAt < thirtyDaysAgoStr)
            .filter(isPinned == 0)
            .filter(compressionState == "full")
            .order(sessionCreatedAt.asc)

        for row in try db.prepare(query) {
            let id = UUID(uuidString: try row.get(sessionId)) ?? UUID()
            let title = try row.get(sessionTitle)
            let createdAt = dateFormatter.date(from: try row.get(sessionCreatedAt)) ?? Date()
            let updatedAt = dateFormatter.date(from: try row.get(sessionUpdatedAt)) ?? Date()
            let isPinnedValue = try row.get(isPinned) == 1
            let compressionStateValue = ChatSession.CompressionState(rawValue: try row.get(compressionState)) ?? .full
            let compressedAtValue = (try? row.get(compressedAt)).flatMap { dateFormatter.date(from: $0) }
            let summaryTextValue = try? row.get(summaryText)

            // Deserialize messages if available
            var messages: [Message] = []
            if let messagesJson = try? row.get(fullMessagesJson),
               let messagesData = messagesJson.data(using: .utf8) {
                messages = (try? JSONDecoder().decode([Message].self, from: messagesData)) ?? []
            }

            let session = ChatSession(
                id: id,
                messages: messages,
                createdAt: createdAt,
                updatedAt: updatedAt,
                title: title,
                isPinned: isPinnedValue,
                compressionState: compressionStateValue,
                compressedAt: compressedAtValue,
                summaryText: summaryTextValue
            )

            sessions.append(session)
        }

        print("✅ Found \(sessions.count) sessions ready for compression")
        return sessions
    }

    func compressSession(sessionId: UUID, summary: String) async throws {
        guard let db = db else {
            throw DatabaseError.notConnected
        }

        let dateFormatter = ISO8601DateFormatter()
        let now = dateFormatter.string(from: Date())

        // Update the session to compressed state
        let sessionToCompress = chatSessions.filter(self.sessionId == sessionId.uuidString)
        try db.run(sessionToCompress.update(
            compressionState <- "compressed",
            summaryText <- summary,
            compressedAt <- now,
            fullMessagesJson <- nil  // Clear the full messages
        ))

        print("✅ Compressed session: \(sessionId)")
    }

    func updateCompressionState(sessionId: UUID, state: ChatSession.CompressionState) async throws {
        guard let db = db else {
            throw DatabaseError.notConnected
        }

        // Update only the compression state
        let sessionToUpdate = chatSessions.filter(self.sessionId == sessionId.uuidString)
        try db.run(sessionToUpdate.update(
            compressionState <- state.rawValue
        ))

        print("✅ Updated compression state to '\(state.rawValue)' for session: \(sessionId)")
    }

    // MARK: - Error Types

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
