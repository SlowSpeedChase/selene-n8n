import Foundation
import Combine

/// Manages switching between local (DatabaseService) and remote (APIService) data sources.
/// Acts as a facade that delegates to the appropriate service based on ConnectionSettings.
@MainActor
class DataServiceManager: ObservableObject {
    static let shared = DataServiceManager()

    @Published private(set) var isRemoteMode: Bool = false
    @Published private(set) var isConnected: Bool = false
    @Published private(set) var connectionError: String?

    private var localService: DatabaseService { DatabaseService.shared }
    private var remoteService: APIService?
    private var cancellables = Set<AnyCancellable>()

    private init() {
        // Observe connection settings changes
        ConnectionSettings.shared.$connectionMode
            .receive(on: DispatchQueue.main)
            .sink { [weak self] (mode: ConnectionSettings.ConnectionMode) in
                self?.updateConnectionMode(mode)
            }
            .store(in: &cancellables)

        ConnectionSettings.shared.$serverAddress
            .receive(on: DispatchQueue.main)
            .sink { [weak self] (_: String) in
                guard ConnectionSettings.shared.connectionMode == .remote else { return }
                self?.recreateRemoteService()
            }
            .store(in: &cancellables)

        // Initialize based on current settings
        updateConnectionMode(ConnectionSettings.shared.connectionMode)
    }

    private func updateConnectionMode(_ mode: ConnectionSettings.ConnectionMode) {
        isRemoteMode = (mode == .remote)

        if isRemoteMode {
            recreateRemoteService()
        } else {
            // Local mode - use DatabaseService connection status
            isConnected = localService.isConnected
            connectionError = nil
        }
    }

    private func recreateRemoteService() {
        guard !ConnectionSettings.shared.serverAddress.isEmpty else {
            isConnected = false
            connectionError = "No server address configured"
            return
        }

        remoteService = APIService(serverAddress: ConnectionSettings.shared.serverAddress)
        // Note: Connection status will be updated when we actually try to use the service
        isConnected = true // Optimistic - will fail on first call if not reachable
        connectionError = nil
    }

    /// Get the active data service based on current connection mode
    var activeService: any DataServiceProtocol {
        if isRemoteMode, let remote = remoteService {
            return remote
        }
        return localService
    }

    // MARK: - DataServiceProtocol Forwarding Methods

    func getAllNotes(limit: Int = 100) async throws -> [Note] {
        try await activeService.getAllNotes(limit: limit)
    }

    func searchNotes(query: String, limit: Int = 50) async throws -> [Note] {
        try await activeService.searchNotes(query: query, limit: limit)
    }

    func getNote(byId noteId: Int) async throws -> Note? {
        try await activeService.getNote(byId: noteId)
    }

    func getNoteByConcept(_ concept: String, limit: Int = 50) async throws -> [Note] {
        try await activeService.getNoteByConcept(concept, limit: limit)
    }

    func getNotesByTheme(_ theme: String, limit: Int = 50) async throws -> [Note] {
        try await activeService.getNotesByTheme(theme, limit: limit)
    }

    func getNotesByEnergy(_ energy: String, limit: Int = 50) async throws -> [Note] {
        try await activeService.getNotesByEnergy(energy, limit: limit)
    }

    func getNotesByDateRange(from: Date, to: Date) async throws -> [Note] {
        try await activeService.getNotesByDateRange(from: from, to: to)
    }

    func saveSession(_ session: ChatSession) async throws {
        try await activeService.saveSession(session)
    }

    func loadSessions() async throws -> [ChatSession] {
        try await activeService.loadSessions()
    }

    func deleteSession(_ session: ChatSession) async throws {
        try await activeService.deleteSession(session)
    }

    func updateSessionPin(sessionId: UUID, isPinned: Bool) async throws {
        try await activeService.updateSessionPin(sessionId: sessionId, isPinned: isPinned)
    }

    func compressSession(sessionId: UUID, summary: String) async throws {
        try await activeService.compressSession(sessionId: sessionId, summary: summary)
    }

    func getPendingThreads() async throws -> [DiscussionThread] {
        try await activeService.getPendingThreads()
    }

    func getThread(byId threadId: Int) async throws -> DiscussionThread? {
        try await activeService.getThread(byId: threadId)
    }

    func updateThreadStatus(_ threadId: Int, status: DiscussionThread.Status) async throws {
        try await activeService.updateThreadStatus(threadId, status: status)
    }

    // MARK: - Hybrid Note Retrieval

    /// Retrieve notes using hybrid strategy based on query type.
    /// In local mode, uses DatabaseService's sophisticated retrieval.
    /// In remote mode, uses simplified API-based retrieval.
    func retrieveNotesFor(
        queryType: QueryAnalyzer.QueryType,
        keywords: [String],
        timeScope: QueryAnalyzer.TimeScope,
        limit: Int
    ) async throws -> [Note] {
        if !isRemoteMode {
            // Local mode: use DatabaseService's sophisticated retrieval
            return try await localService.retrieveNotesFor(
                queryType: queryType,
                keywords: keywords,
                timeScope: timeScope,
                limit: limit
            )
        }

        // Remote mode: simplified retrieval via API
        switch queryType {
        case .pattern, .general:
            // Get recent notes
            return try await getAllNotes(limit: limit)

        case .search:
            // Search by keywords
            var allNotes: [Note] = []
            for keyword in keywords.prefix(3) {
                let notes = try await searchNotes(query: keyword, limit: limit / 3)
                allNotes.append(contentsOf: notes)
            }
            // Dedupe and limit
            let unique = Array(Set(allNotes))
            return Array(unique.prefix(limit))

        case .knowledge:
            // Combine search with recent notes
            var allNotes: [Note] = []
            for keyword in keywords.prefix(2) {
                let notes = try await searchNotes(query: keyword, limit: limit / 4)
                allNotes.append(contentsOf: notes)
            }
            let recentNotes = try await getAllNotes(limit: limit / 3)
            allNotes.append(contentsOf: recentNotes)
            // Dedupe and limit
            let unique = Array(Set(allNotes))
            return Array(unique.prefix(limit))
        }
    }

    // MARK: - Local-Only Operations (DatabaseService specific)

    /// These operations are only available in local mode
    var localDatabaseService: DatabaseService? {
        isRemoteMode ? nil : localService
    }
}
