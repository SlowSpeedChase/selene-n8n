import Foundation

/// Protocol defining data operations for both local and remote modes.
/// DatabaseService (local SQLite) and APIService (remote HTTP) will both implement this protocol,
/// enabling SeleneChat to switch between local and remote modes seamlessly.
protocol DataServiceProtocol {
    // MARK: - Notes

    /// Fetch all notes, ordered by creation date descending
    func getAllNotes(limit: Int) async throws -> [Note]

    /// Search notes by query string (searches title and content)
    func searchNotes(query: String, limit: Int) async throws -> [Note]

    /// Fetch a single note by its ID
    func getNote(byId noteId: Int) async throws -> Note?

    /// Find notes containing a specific concept
    func getNoteByConcept(_ concept: String, limit: Int) async throws -> [Note]

    /// Find notes with a specific theme (primary or secondary)
    func getNotesByTheme(_ theme: String, limit: Int) async throws -> [Note]

    /// Find notes with a specific energy level (high, medium, low)
    func getNotesByEnergy(_ energy: String, limit: Int) async throws -> [Note]

    /// Find notes created within a date range
    func getNotesByDateRange(from: Date, to: Date) async throws -> [Note]

    // MARK: - Chat Sessions

    /// Save a chat session (insert or update)
    func saveSession(_ session: ChatSession) async throws

    /// Load all chat sessions, ordered by updatedAt descending
    func loadSessions() async throws -> [ChatSession]

    /// Delete a chat session
    func deleteSession(_ session: ChatSession) async throws

    /// Update the pinned status of a session
    func updateSessionPin(sessionId: UUID, isPinned: Bool) async throws

    /// Compress a session by replacing full messages with a summary
    func compressSession(sessionId: UUID, summary: String) async throws

    // MARK: - Discussion Threads

    /// Get all pending/active/review threads (excludes test runs)
    func getPendingThreads() async throws -> [DiscussionThread]

    /// Fetch a single thread by its ID
    func getThread(byId threadId: Int) async throws -> DiscussionThread?

    /// Update the status of a discussion thread
    func updateThreadStatus(_ threadId: Int, status: DiscussionThread.Status) async throws
}
