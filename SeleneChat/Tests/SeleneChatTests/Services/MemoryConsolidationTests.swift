import XCTest
@testable import SeleneChat

final class MemoryConsolidationTests: XCTestCase {

    func testConsolidateStoresEmbeddingOnAdd() async throws {
        let ollamaService = OllamaService.shared
        let isAvailable = await ollamaService.isAvailable()
        try XCTSkipUnless(isAvailable, "Ollama not running - skipping integration test")

        let databaseService = DatabaseService.shared
        let memoryService = MemoryService.shared
        let sessionId = UUID()

        let fact = MemoryService.CandidateFact(
            fact: "User prefers dark mode interfaces",
            type: "preference",
            confidence: 0.9
        )

        try await memoryService.consolidateMemory(
            candidateFact: fact,
            sessionId: sessionId
        )

        let results = try await databaseService.getAllMemoriesWithEmbeddings()
        XCTAssertGreaterThanOrEqual(results.count, 1)

        // Find the memory we just inserted
        let matched = results.filter { $0.memory.content.contains("dark mode") }
        XCTAssertFalse(matched.isEmpty, "Should find the dark mode memory")
        if let first = matched.first {
            XCTAssertNotNil(first.embedding, "Memory should have embedding")
            if let emb = first.embedding {
                XCTAssertEqual(emb.count, 768, "Embedding should be 768-dim")
            }
        }
    }

    func testConsolidateWithoutSimilarMemoriesParam() async throws {
        let ollamaService = OllamaService.shared
        let isAvailable = await ollamaService.isAvailable()
        try XCTSkipUnless(isAvailable, "Ollama not running - skipping integration test")

        let databaseService = DatabaseService.shared
        let memoryService = MemoryService.shared
        let sessionId = UUID()

        let emb1 = try await ollamaService.embed(text: "User likes dark mode")
        _ = try await databaseService.insertMemory(
            content: "User likes dark mode",
            type: .preference,
            confidence: 0.8,
            sourceSessionId: sessionId,
            embedding: emb1
        )

        let fact = MemoryService.CandidateFact(
            fact: "User prefers dark themes in all apps",
            type: "preference",
            confidence: 0.9
        )

        try await memoryService.consolidateMemory(
            candidateFact: fact,
            sessionId: sessionId
        )

        let results = try await databaseService.getAllMemoriesWithEmbeddings()
        XCTAssertGreaterThan(results.count, 0, "Should have at least one memory")
    }
}
