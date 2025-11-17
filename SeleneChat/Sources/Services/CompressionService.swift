import Foundation

@MainActor
class CompressionService: ObservableObject {
    private let databaseService: DatabaseService

    init(databaseService: DatabaseService) {
        self.databaseService = databaseService
    }

    // Called during app idle time or on launch
    func checkAndCompressSessions() async {
        let sessions = try? await databaseService.getSessionsReadyForCompression()

        guard let sessions = sessions, !sessions.isEmpty else { return }

        for session in sessions {
            await compressSession(session)
        }
    }

    private func compressSession(_ session: ChatSession) async {
        // Mark as processing
        try? await databaseService.updateCompressionState(
            sessionId: session.id,
            state: .processing
        )

        // Generate summary
        let summary = await generateSummary(for: session)

        // Save compressed version
        try? await databaseService.compressSession(
            sessionId: session.id,
            summary: summary
        )
    }

    func generateSummary(for session: ChatSession) async -> String {
        // Extract user queries from messages
        let userQueries = session.messages
            .filter { $0.role == .user }
            .map { $0.content }

        let summary = """
        Session: \(session.title)
        Date: \(session.formattedDate)
        Questions asked: \(userQueries.count)

        Key queries:
        \(userQueries.prefix(5).map { "- \($0)" }.joined(separator: "\n"))
        """

        return summary
    }
}
