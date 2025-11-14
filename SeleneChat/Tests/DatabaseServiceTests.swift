import XCTest
import Foundation
@testable import SeleneChatLib

final class ChatSessionPersistenceTests: XCTestCase {
    var databaseService: DatabaseService!
    var testDatabasePath: String!

    override func setUp() async throws {
        try await super.setUp()

        // Create a temporary database for testing
        let tempDir = FileManager.default.temporaryDirectory
        testDatabasePath = tempDir.appendingPathComponent("test_selene_\(UUID().uuidString).db").path

        // Initialize database service with test path
        databaseService = DatabaseService()
        databaseService.databasePath = testDatabasePath
    }

    override func tearDown() async throws {
        // Clean up test database
        try? FileManager.default.removeItem(atPath: testDatabasePath)
        databaseService = nil
        try await super.tearDown()
    }

    // MARK: - Core CRUD Operations

    func testSaveAndLoadSession() async throws {
        // Create a test session with messages
        var session = ChatSession(
            id: UUID(),
            messages: [
                Message(
                    id: UUID(),
                    role: .user,
                    content: "Hello, what can you help me with?",
                    timestamp: Date(),
                    llmTier: .onDevice,
                    relatedNotes: nil
                ),
                Message(
                    id: UUID(),
                    role: .assistant,
                    content: "I can help you search your notes and answer questions about them.",
                    timestamp: Date(),
                    llmTier: .onDevice,
                    relatedNotes: nil
                )
            ],
            createdAt: Date(),
            updatedAt: Date(),
            title: "Test Session"
        )

        // Save the session
        try await databaseService.saveSession(session)

        // Load all sessions
        let loadedSessions = try await databaseService.loadSessions()

        // Verify the session was saved and loaded correctly
        XCTAssertEqual(loadedSessions.count, 1, "Should have exactly one session")

        guard let loadedSession = loadedSessions.first else {
            XCTFail("Failed to load session")
            return
        }

        XCTAssertEqual(loadedSession.id, session.id, "Session ID should match")
        XCTAssertEqual(loadedSession.title, session.title, "Session title should match")
        XCTAssertEqual(loadedSession.messages.count, session.messages.count, "Message count should match")
        XCTAssertEqual(loadedSession.isPinned, false, "Default isPinned should be false")
        XCTAssertEqual(loadedSession.compressionState, .full, "Default compression state should be full")

        // Verify messages
        XCTAssertEqual(loadedSession.messages[0].content, "Hello, what can you help me with?")
        XCTAssertEqual(loadedSession.messages[1].content, "I can help you search your notes and answer questions about them.")
    }
}
