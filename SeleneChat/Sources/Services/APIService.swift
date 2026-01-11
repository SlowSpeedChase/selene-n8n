import Foundation

/// Remote API client implementing DataServiceProtocol.
/// Enables SeleneChat to connect to a remote Selene server via HTTP.
actor APIService: DataServiceProtocol, ObservableObject {
    private let baseURL: URL
    private let decoder: JSONDecoder
    private let encoder: JSONEncoder

    init(serverAddress: String) {
        self.baseURL = URL(string: "http://\(serverAddress):5678")!

        self.decoder = JSONDecoder()
        self.decoder.keyDecodingStrategy = .convertFromSnakeCase
        self.decoder.dateDecodingStrategy = .iso8601

        self.encoder = JSONEncoder()
        self.encoder.keyEncodingStrategy = .convertToSnakeCase
        self.encoder.dateEncodingStrategy = .iso8601
    }

    // MARK: - HTTP Helpers

    private func get<T: Decodable>(_ path: String) async throws -> T {
        let url = baseURL.appendingPathComponent(path)
        let (data, response) = try await URLSession.shared.data(from: url)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw APIError.invalidResponse
        }

        guard httpResponse.statusCode == 200 else {
            throw APIError.httpError(statusCode: httpResponse.statusCode)
        }

        return try decoder.decode(T.self, from: data)
    }

    private func getWithQuery<T: Decodable>(_ path: String, queryItems: [URLQueryItem]) async throws -> T {
        var components = URLComponents(url: baseURL.appendingPathComponent(path), resolvingAgainstBaseURL: false)!
        components.queryItems = queryItems

        guard let url = components.url else {
            throw APIError.invalidURL
        }

        let (data, response) = try await URLSession.shared.data(from: url)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw APIError.invalidResponse
        }

        guard httpResponse.statusCode == 200 else {
            throw APIError.httpError(statusCode: httpResponse.statusCode)
        }

        return try decoder.decode(T.self, from: data)
    }

    private func post<T: Encodable>(_ path: String, body: T) async throws {
        let url = baseURL.appendingPathComponent(path)
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try encoder.encode(body)

        let (_, response) = try await URLSession.shared.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw APIError.invalidResponse
        }

        guard (200...299).contains(httpResponse.statusCode) else {
            throw APIError.httpError(statusCode: httpResponse.statusCode)
        }
    }

    private func patch<T: Encodable>(_ path: String, body: T) async throws {
        let url = baseURL.appendingPathComponent(path)
        var request = URLRequest(url: url)
        request.httpMethod = "PATCH"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try encoder.encode(body)

        let (_, response) = try await URLSession.shared.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw APIError.invalidResponse
        }

        guard (200...299).contains(httpResponse.statusCode) else {
            throw APIError.httpError(statusCode: httpResponse.statusCode)
        }
    }

    private func delete(_ path: String) async throws {
        let url = baseURL.appendingPathComponent(path)
        var request = URLRequest(url: url)
        request.httpMethod = "DELETE"

        let (_, response) = try await URLSession.shared.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw APIError.invalidResponse
        }

        guard (200...299).contains(httpResponse.statusCode) else {
            throw APIError.httpError(statusCode: httpResponse.statusCode)
        }
    }

    // MARK: - Notes

    func getAllNotes(limit: Int) async throws -> [Note] {
        try await getWithQuery("/api/notes", queryItems: [
            URLQueryItem(name: "limit", value: String(limit))
        ])
    }

    func searchNotes(query: String, limit: Int) async throws -> [Note] {
        try await getWithQuery("/api/notes/search", queryItems: [
            URLQueryItem(name: "q", value: query),
            URLQueryItem(name: "limit", value: String(limit))
        ])
    }

    func getNote(byId noteId: Int) async throws -> Note? {
        do {
            return try await get("/api/notes/\(noteId)")
        } catch APIError.httpError(statusCode: 404) {
            return nil
        }
    }

    func getNoteByConcept(_ concept: String, limit: Int) async throws -> [Note] {
        try await getWithQuery("/api/notes/by-concept", queryItems: [
            URLQueryItem(name: "concept", value: concept),
            URLQueryItem(name: "limit", value: String(limit))
        ])
    }

    func getNotesByTheme(_ theme: String, limit: Int) async throws -> [Note] {
        try await getWithQuery("/api/notes/by-theme", queryItems: [
            URLQueryItem(name: "theme", value: theme),
            URLQueryItem(name: "limit", value: String(limit))
        ])
    }

    func getNotesByEnergy(_ energy: String, limit: Int) async throws -> [Note] {
        try await getWithQuery("/api/notes/by-energy", queryItems: [
            URLQueryItem(name: "energy", value: energy),
            URLQueryItem(name: "limit", value: String(limit))
        ])
    }

    func getNotesByDateRange(from: Date, to: Date) async throws -> [Note] {
        let dateFormatter = ISO8601DateFormatter()
        return try await getWithQuery("/api/notes/by-date", queryItems: [
            URLQueryItem(name: "from", value: dateFormatter.string(from: from)),
            URLQueryItem(name: "to", value: dateFormatter.string(from: to))
        ])
    }

    // MARK: - Chat Sessions

    func saveSession(_ session: ChatSession) async throws {
        try await post("/api/sessions", body: session)
    }

    func loadSessions() async throws -> [ChatSession] {
        try await get("/api/sessions")
    }

    func deleteSession(_ session: ChatSession) async throws {
        try await delete("/api/sessions/\(session.id.uuidString)")
    }

    func updateSessionPin(sessionId: UUID, isPinned: Bool) async throws {
        struct PinUpdate: Encodable {
            let isPinned: Bool
        }
        try await patch("/api/sessions/\(sessionId.uuidString)/pin", body: PinUpdate(isPinned: isPinned))
    }

    func compressSession(sessionId: UUID, summary: String) async throws {
        struct CompressRequest: Encodable {
            let summary: String
        }
        try await post("/api/sessions/\(sessionId.uuidString)/compress", body: CompressRequest(summary: summary))
    }

    // MARK: - Discussion Threads

    func getPendingThreads() async throws -> [DiscussionThread] {
        try await get("/api/threads")
    }

    func getThread(byId threadId: Int) async throws -> DiscussionThread? {
        do {
            return try await get("/api/threads/\(threadId)")
        } catch APIError.httpError(statusCode: 404) {
            return nil
        }
    }

    func updateThreadStatus(_ threadId: Int, status: DiscussionThread.Status) async throws {
        struct StatusUpdate: Encodable {
            let status: String
        }
        try await patch("/api/threads/\(threadId)/status", body: StatusUpdate(status: status.rawValue))
    }

    // MARK: - Error Types

    enum APIError: Error, LocalizedError {
        case invalidURL
        case invalidResponse
        case httpError(statusCode: Int)
        case decodingError(Error)

        var errorDescription: String? {
            switch self {
            case .invalidURL:
                return "Invalid URL"
            case .invalidResponse:
                return "Invalid response from server"
            case .httpError(let statusCode):
                return "HTTP error: \(statusCode)"
            case .decodingError(let error):
                return "Decoding error: \(error.localizedDescription)"
            }
        }
    }
}
