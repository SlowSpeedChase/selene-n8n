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

    private(set) var db: Connection?

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

    // discussion_threads table
    private let discussionThreads = Table("discussion_threads")
    private let threadId = Expression<Int64>("id")
    private let threadRawNoteId = Expression<Int64>("raw_note_id")
    private let threadType = Expression<String>("thread_type")
    private let threadPrompt = Expression<String>("prompt")
    private let threadStatus = Expression<String>("status")
    private let threadCreatedAt = Expression<String>("created_at")
    private let threadSurfacedAt = Expression<String?>("surfaced_at")
    private let threadCompletedAt = Expression<String?>("completed_at")
    private let threadRelatedConcepts = Expression<String?>("related_concepts")
    private let threadTestRun = Expression<String?>("test_run")

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
            #if DEBUG
            DebugLogger.shared.log(.state, "DatabaseService.connected: \(databasePath)")
            #endif

            // Run migrations
            try? createChatSessionsTable()
            try? Migration001_TaskLinks.run(db: db!)
            try? Migration002_PlanningInbox.run(db: db!)
            try? Migration003_BidirectionalThings.run(db: db!)
        } catch {
            isConnected = false
            #if DEBUG
            DebugLogger.shared.log(.error, "DatabaseService.connectionFailed: \(error)")
            #endif
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

        #if DEBUG
        DebugLogger.shared.log(.state, "DatabaseService.chatSessionsTableReady")
        #endif
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
            #if DEBUG
            DebugLogger.shared.log(.error, "DatabaseService.searchNotesError: \(error)")
            DebugLogger.shared.log(.error, "DatabaseService.searchNotesQuery: \(query)")
            #endif
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
            #if DEBUG
            DebugLogger.shared.log(.state, "DatabaseService.sessionUpdated: \(session.id)")
            #endif
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
            #if DEBUG
            DebugLogger.shared.log(.state, "DatabaseService.sessionInserted: \(session.id)")
            #endif
        }

        #if DEBUG
        DebugLogger.shared.log(.state, "DatabaseService.sessionSaved: \(session.title) (messages: \(session.messages.count))")
        #endif
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

        #if DEBUG
        DebugLogger.shared.log(.state, "DatabaseService.sessionsLoaded: \(sessions.count)")
        #endif
        return sessions
    }

    func deleteSession(_ session: ChatSession) async throws {
        guard let db = db else {
            throw DatabaseError.notConnected
        }

        let sessionToDelete = chatSessions.filter(sessionId == session.id.uuidString)
        try db.run(sessionToDelete.delete())

        #if DEBUG
        DebugLogger.shared.log(.state, "DatabaseService.sessionDeleted: \(session.id) (\(session.title))")
        #endif
    }

    func updateSessionPin(sessionId: UUID, isPinned pinnedValue: Bool) async throws {
        guard let db = db else {
            throw DatabaseError.notConnected
        }

        let sessionToUpdate = chatSessions.filter(self.sessionId == sessionId.uuidString)
        try db.run(sessionToUpdate.update(isPinned <- pinnedValue ? 1 : 0))

        #if DEBUG
        DebugLogger.shared.log(.state, "DatabaseService.sessionPinUpdated: \(sessionId) -> \(pinnedValue)")
        #endif
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

        #if DEBUG
        DebugLogger.shared.log(.state, "DatabaseService.sessionsReadyForCompression: \(sessions.count)")
        #endif
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

        #if DEBUG
        DebugLogger.shared.log(.state, "DatabaseService.sessionCompressed: \(sessionId)")
        #endif
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

        #if DEBUG
        DebugLogger.shared.log(.state, "DatabaseService.compressionStateUpdated: \(sessionId) -> \(state.rawValue)")
        #endif
    }

    // MARK: - Hybrid Note Retrieval

    /// Retrieve notes using hybrid strategy based on query type
    func retrieveNotesFor(
        queryType: QueryAnalyzer.QueryType,
        keywords: [String],
        timeScope: QueryAnalyzer.TimeScope,
        limit: Int
    ) async throws -> [Note] {
        switch queryType {
        case .pattern:
            // Pattern queries: recent notes with processed data
            return try await getRecentProcessedNotes(limit: limit, timeScope: timeScope)

        case .search:
            // Search queries: combine concept, theme, and content searches
            return try await searchNotesByKeywords(keywords: keywords, limit: limit)

        case .knowledge:
            // Knowledge queries: keyword search + recent context
            let keywordMatches = try await searchNotesByKeywords(keywords: keywords, limit: limit / 2)
            let recentContext = try await getRecentProcessedNotes(limit: limit / 3, timeScope: .recent)
            return Array(Set(keywordMatches + recentContext)).sorted { $0.createdAt > $1.createdAt }.prefix(limit).map { $0 }

        case .general:
            // General queries: recent notes with full context
            return try await getRecentProcessedNotes(limit: limit, timeScope: .recent)
        }
    }

    /// Get recent notes with processed data, filtered by time scope
    private func getRecentProcessedNotes(limit: Int, timeScope: QueryAnalyzer.TimeScope) async throws -> [Note] {
        guard let db = db else {
            throw DatabaseError.notConnected
        }

        var query = rawNotes
            .join(.inner, processedNotes, on: rawNotes[id] == processedNotes[rawNoteId])
            .order(rawNotes[createdAt].desc)

        // Apply time scope filter
        switch timeScope {
        case .recent:
            let sevenDaysAgo = Calendar.current.date(byAdding: .day, value: -7, to: Date())!
            let dateFormatter = ISO8601DateFormatter()
            query = query.filter(rawNotes[createdAt] >= dateFormatter.string(from: sevenDaysAgo))

        case .thisWeek:
            let startOfWeek = Calendar.current.dateInterval(of: .weekOfYear, for: Date())!.start
            let dateFormatter = ISO8601DateFormatter()
            query = query.filter(rawNotes[createdAt] >= dateFormatter.string(from: startOfWeek))

        case .thisMonth:
            let startOfMonth = Calendar.current.dateInterval(of: .month, for: Date())!.start
            let dateFormatter = ISO8601DateFormatter()
            query = query.filter(rawNotes[createdAt] >= dateFormatter.string(from: startOfMonth))

        case .custom(let from, let to):
            let dateFormatter = ISO8601DateFormatter()
            query = query.filter(
                rawNotes[createdAt] >= dateFormatter.string(from: from) &&
                rawNotes[createdAt] <= dateFormatter.string(from: to)
            )

        case .allTime:
            // No filter
            break
        }

        query = query.limit(limit)

        var notes: [Note] = []
        for row in try db.prepare(query) {
            let note = try parseNote(from: row)
            notes.append(note)
        }

        return notes
    }

    /// Search notes by keywords across concepts, themes, and content
    private func searchNotesByKeywords(keywords: [String], limit: Int) async throws -> [Note] {
        var allNotes: [Note] = []

        for keyword in keywords {
            // Search concepts
            let conceptNotes = try await getNoteByConcept(keyword, limit: limit / keywords.count)
            allNotes.append(contentsOf: conceptNotes)

            // Search themes
            let themeNotes = try await getNotesByTheme(keyword, limit: limit / keywords.count)
            allNotes.append(contentsOf: themeNotes)

            // Search content
            let contentNotes = try await searchNotes(query: keyword, limit: limit / keywords.count)
            allNotes.append(contentsOf: contentNotes)
        }

        // Deduplicate and sort by date
        let uniqueNotes = Array(Set(allNotes)).sorted { $0.createdAt > $1.createdAt }

        return Array(uniqueNotes.prefix(limit))
    }

    // MARK: - Discussion Threads

    func getPendingThreads() async throws -> [DiscussionThread] {
        guard let db = db else {
            throw DatabaseError.notConnected
        }

        // Check if table exists first
        let tableExists = try db.scalar(
            "SELECT COUNT(*) FROM sqlite_master WHERE type='table' AND name='discussion_threads'"
        ) as? Int64 ?? 0

        if tableExists == 0 {
            return []
        }

        let query = discussionThreads
            .join(.leftOuter, rawNotes, on: discussionThreads[threadRawNoteId] == rawNotes[id])
            .filter(discussionThreads[threadStatus] == "pending" || discussionThreads[threadStatus] == "active" || discussionThreads[threadStatus] == "review")
            .filter(discussionThreads[threadTestRun] == nil)
            .order(discussionThreads[threadCreatedAt].desc)

        var threads: [DiscussionThread] = []

        do {
            for row in try db.prepare(query) {
                let thread = try parseThread(from: row)
                threads.append(thread)
            }
        } catch {
            #if DEBUG
            DebugLogger.shared.log(.error, "DatabaseService.loadThreadsError: \(error)")
            #endif
            throw error
        }

        return threads
    }

    func getThread(byId threadIdValue: Int) async throws -> DiscussionThread? {
        guard let db = db else {
            throw DatabaseError.notConnected
        }

        // Check if table exists first
        let tableExists = try db.scalar(
            "SELECT COUNT(*) FROM sqlite_master WHERE type='table' AND name='discussion_threads'"
        ) as? Int64 ?? 0

        if tableExists == 0 {
            return nil
        }

        let query = discussionThreads
            .join(.leftOuter, rawNotes, on: discussionThreads[threadRawNoteId] == rawNotes[id])
            .filter(discussionThreads[threadId] == Int64(threadIdValue))

        guard let row = try db.pluck(query) else {
            return nil
        }

        return try parseThread(from: row)
    }

    func updateThreadStatus(_ threadIdValue: Int, status: DiscussionThread.Status) async throws {
        guard let db = db else {
            throw DatabaseError.notConnected
        }

        let dateFormatter = ISO8601DateFormatter()
        let now = dateFormatter.string(from: Date())

        let thread = discussionThreads.filter(threadId == Int64(threadIdValue))

        var updates: [Setter] = [threadStatus <- status.rawValue]

        if status == .active {
            updates.append(threadSurfacedAt <- now)
        }

        if status == .completed || status == .dismissed {
            updates.append(threadCompletedAt <- now)
        }

        try db.run(thread.update(updates))

        #if DEBUG
        DebugLogger.shared.log(.state, "DatabaseService.threadStatusUpdated: \(threadIdValue) -> \(status.rawValue)")
        #endif
    }

    private func parseThread(from row: Row) throws -> DiscussionThread {
        // Parse related concepts JSON - use qualified reference for joined query
        var conceptsArray: [String]? = nil
        if let conceptsStr = try? row.get(discussionThreads[threadRelatedConcepts]),
           let data = conceptsStr.data(using: .utf8) {
            conceptsArray = try? JSONDecoder().decode([String].self, from: data)
        }

        // Parse thread type - use qualified column references for joined query
        let typeStr = try row.get(discussionThreads[threadType])
        let threadTypeEnum = DiscussionThread.ThreadType(rawValue: typeStr) ?? .planning

        // Parse status
        let statusStr = try row.get(discussionThreads[threadStatus])
        let statusEnum = DiscussionThread.Status(rawValue: statusStr) ?? .pending

        return DiscussionThread(
            id: Int(try row.get(discussionThreads[threadId])),
            rawNoteId: Int(try row.get(discussionThreads[threadRawNoteId])),
            threadType: threadTypeEnum,
            prompt: try row.get(discussionThreads[threadPrompt]),
            status: statusEnum,
            createdAt: parseDateString(try row.get(discussionThreads[threadCreatedAt])) ?? Date(),
            surfacedAt: (try? row.get(discussionThreads[threadSurfacedAt])).flatMap { parseDateString($0) },
            completedAt: (try? row.get(discussionThreads[threadCompletedAt])).flatMap { parseDateString($0) },
            relatedConcepts: conceptsArray,
            noteTitle: try? row.get(rawNotes[title]),
            noteContent: try? row.get(rawNotes[content])
        )
    }

    /// Parse date string from SQLite format or ISO8601
    private func parseDateString(_ dateString: String) -> Date? {
        // Try SQLite format first: "YYYY-MM-DD HH:MM:SS"
        let sqliteFormatter = DateFormatter()
        sqliteFormatter.dateFormat = "yyyy-MM-dd HH:mm:ss"
        sqliteFormatter.timeZone = TimeZone(identifier: "UTC")

        if let date = sqliteFormatter.date(from: dateString) {
            return date
        }

        // Fall back to ISO8601
        let iso8601Formatter = ISO8601DateFormatter()
        return iso8601Formatter.date(from: dateString)
    }

    // MARK: - Bidirectional Things Sync

    /// Get all Things task IDs from task_links table
    func getAllTaskLinkIds() async throws -> [String] {
        guard let db = db else { throw DatabaseError.notConnected }

        var ids: [String] = []
        let query = "SELECT things_task_id FROM task_links WHERE things_task_id IS NOT NULL AND things_task_id != ''"

        for row in try db.prepare(query) {
            if let id = row[0] as? String {
                ids.append(id)
            }
        }

        return ids
    }

    /// Insert a new task link when a task is created in Things
    func insertTaskLink(thingsTaskId: String, threadId: Int, noteId: Int) async throws {
        guard let db = db else { throw DatabaseError.notConnected }

        let now = ISO8601DateFormatter().string(from: Date())

        let query = """
            INSERT INTO task_links (things_task_id, thread_id, raw_note_id, created_at, things_status)
            VALUES (?, ?, ?, ?, 'open')
        """

        try db.run(query, thingsTaskId, threadId, noteId, now)

        #if DEBUG
        print("[DatabaseService] Inserted task_link: \(thingsTaskId) -> thread \(threadId)")
        #endif
    }

    /// Update task_links with status from Things
    func updateTaskLinkStatus(
        thingsId: String,
        status: String,
        completedAt: Date?
    ) async throws {
        guard let db = db else { throw DatabaseError.notConnected }

        let now = ISO8601DateFormatter().string(from: Date())
        let completedStr: String? = completedAt.map { ISO8601DateFormatter().string(from: $0) }

        let query = """
            UPDATE task_links SET
                things_status = ?,
                things_completed_at = ?,
                last_synced_at = ?
            WHERE things_task_id = ?
        """

        try db.run(query, status, completedStr, now, thingsId)
    }

    /// Get Things task IDs for a specific thread
    func fetchTaskIdsForThread(_ threadId: Int) async throws -> [String] {
        guard let db = db else { throw DatabaseError.notConnected }

        var ids: [String] = []
        let query = "SELECT things_task_id FROM task_links WHERE discussion_thread_id = ? AND things_task_id IS NOT NULL"

        for row in try db.prepare(query, threadId) {
            if let id = row[0] as? String {
                ids.append(id)
            }
        }

        return ids
    }

    /// Update thread to review status with resurface reason
    func resurfaceThread(_ threadId: Int, reason: String) async throws {
        guard let db = db else { throw DatabaseError.notConnected }

        let now = ISO8601DateFormatter().string(from: Date())

        let query = """
            UPDATE discussion_threads SET
                status = 'review',
                resurface_reason = ?,
                last_resurfaced_at = ?
            WHERE id = ?
        """

        try db.run(query, reason, now, threadId)

        #if DEBUG
        print("[DatabaseService] Resurfaced thread \(threadId) with reason: \(reason)")
        #endif
    }

    /// Fetch threads by status, with review status threads first
    func fetchThreadsByStatus(_ statuses: [DiscussionThread.Status]) async throws -> [DiscussionThread] {
        guard let db = db else { throw DatabaseError.notConnected }

        let statusStrings = statuses.map { "'\($0.rawValue)'" }.joined(separator: ", ")

        let query = """
            SELECT dt.*, rn.title as note_title, rn.content as note_content
            FROM discussion_threads dt
            LEFT JOIN raw_notes rn ON dt.raw_note_id = rn.id
            WHERE dt.status IN (\(statusStrings))
            ORDER BY CASE WHEN dt.status = 'review' THEN 0 ELSE 1 END, dt.created_at DESC
        """

        var threads: [DiscussionThread] = []

        for row in try db.prepare(query) {
            if let thread = parseDiscussionThreadRow(row) {
                threads.append(thread)
            }
        }

        return threads
    }

    /// Parse a discussion thread row including new resurface columns
    private func parseDiscussionThreadRow(_ row: Statement.Element) -> DiscussionThread? {
        guard let id = row[0] as? Int64,
              let rawNoteId = row[1] as? Int64,
              let typeStr = row[2] as? String,
              let prompt = row[3] as? String,
              let statusStr = row[4] as? String,
              let createdAtStr = row[5] as? String else {
            return nil
        }

        let threadType = DiscussionThread.ThreadType(rawValue: typeStr) ?? .planning
        let status = DiscussionThread.Status(rawValue: statusStr) ?? .pending
        let createdAt = parseDateString(createdAtStr) ?? Date()

        // Parse optional fields
        let surfacedAt = (row[6] as? String).flatMap { parseDateString($0) }
        let completedAt = (row[7] as? String).flatMap { parseDateString($0) }
        let relatedConceptsJson = row[8] as? String
        let relatedConcepts: [String]? = relatedConceptsJson.flatMap {
            try? JSONDecoder().decode([String].self, from: $0.data(using: .utf8) ?? Data())
        }

        // New resurface columns (indexes depend on SELECT order)
        let resurfaceReasonCode = row[9] as? String
        let lastResurfacedAt = (row[10] as? String).flatMap { parseDateString($0) }

        // Note content from JOIN
        let noteTitle = row[12] as? String
        let noteContent = row[13] as? String

        return DiscussionThread(
            id: Int(id),
            rawNoteId: Int(rawNoteId),
            threadType: threadType,
            prompt: prompt,
            status: status,
            createdAt: createdAt,
            surfacedAt: surfacedAt,
            completedAt: completedAt,
            relatedConcepts: relatedConcepts,
            resurfaceReasonCode: resurfaceReasonCode,
            lastResurfacedAt: lastResurfacedAt,
            noteTitle: noteTitle,
            noteContent: noteContent
        )
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
