import Foundation

/// Service for extracting and consolidating conversation memories
actor MemoryService {
    static let shared = MemoryService()

    private let ollamaService = OllamaService.shared
    private let databaseService = DatabaseService.shared

    private init() {}

    // MARK: - Types

    struct CandidateFact: Codable {
        let fact: String
        let type: String
        let confidence: Double
    }

    struct ExtractionResult: Codable {
        let facts: [CandidateFact]
    }

    enum ConsolidationAction: String, Codable {
        case ADD
        case UPDATE
        case DELETE
        case NOOP
    }

    struct ConsolidationDecision: Codable {
        let action: ConsolidationAction
        let memoryId: Int64?
        let merged: String?
        let reason: String?
    }

    // MARK: - Extraction

    /// Extract memories from a conversation exchange
    func extractMemories(
        userMessage: String,
        assistantResponse: String,
        recentMessages: [(role: String, content: String, createdAt: Date)]
    ) async throws -> [CandidateFact] {
        // Format recent messages
        let recentContext = recentMessages.map { "\($0.role): \($0.content)" }.joined(separator: "\n")

        let prompt = """
        You are a memory extraction system for Selene, an ADHD-focused assistant.

        Given this conversation context and the latest exchange, extract any facts
        worth remembering about the user - their preferences, patterns, projects,
        or important context.

        RECENT MESSAGES:
        \(recentContext)

        CURRENT EXCHANGE:
        User: \(userMessage)
        Assistant: \(assistantResponse)

        Return ONLY valid JSON matching this exact format (no other text):
        {
          "facts": [
            {"fact": "description of fact", "type": "preference|fact|pattern|context", "confidence": 0.8}
          ]
        }

        Only extract facts that are genuinely useful for future conversations.
        Be selective, not exhaustive. If nothing worth remembering, return {"facts": []}.
        """

        let response = try await ollamaService.generate(prompt: prompt)

        // Parse JSON response - try to extract JSON from response
        guard let jsonData = extractJSON(from: response)?.data(using: .utf8) else {
            #if DEBUG
            DebugLogger.shared.log(.error, "MemoryService.extractMemories: no valid JSON found in response")
            #endif
            return []
        }

        do {
            let result = try JSONDecoder().decode(ExtractionResult.self, from: jsonData)
            #if DEBUG
            DebugLogger.shared.log(.state, "MemoryService.extractMemories: extracted \(result.facts.count) facts")
            #endif
            return result.facts
        } catch {
            #if DEBUG
            DebugLogger.shared.log(.error, "MemoryService.extractMemories: JSON parse failed - \(error)")
            #endif
            return []
        }
    }

    /// Try to extract JSON object from a string that may contain extra text
    private func extractJSON(from text: String) -> String? {
        // Find the first { and last }
        guard let start = text.firstIndex(of: "{"),
              let end = text.lastIndex(of: "}") else {
            return nil
        }
        return String(text[start...end])
    }

    // MARK: - Consolidation

    /// Consolidate a candidate fact with existing memories
    func consolidateMemory(
        candidateFact: CandidateFact,
        similarMemories: [ConversationMemory],
        sessionId: UUID
    ) async throws {
        // If no similar memories, just ADD
        if similarMemories.isEmpty {
            let memoryType = ConversationMemory.MemoryType(rawValue: candidateFact.type) ?? .fact
            _ = try await databaseService.insertMemory(
                content: candidateFact.fact,
                type: memoryType,
                confidence: candidateFact.confidence,
                sourceSessionId: sessionId
            )
            #if DEBUG
            DebugLogger.shared.log(.state, "MemoryService.consolidate: ADD (no similar)")
            #endif
            return
        }

        // Ask LLM to decide
        let similarStr = similarMemories.enumerated().map { (i, m) in
            "\(i + 1). [id=\(m.id)] \(m.content)"
        }.joined(separator: "\n")

        let prompt = """
        You are managing a memory system. Given a new fact and existing similar
        memories, decide what to do.

        NEW FACT: "\(candidateFact.fact)"

        EXISTING SIMILAR MEMORIES:
        \(similarStr)

        Return ONLY valid JSON matching one of these formats (no other text):
        - {"action": "ADD"} - New information, nothing equivalent exists
        - {"action": "UPDATE", "memoryId": N, "merged": "combined fact text"} - Augment existing
        - {"action": "DELETE", "memoryId": N, "reason": "why"} - New fact contradicts this
        - {"action": "NOOP", "reason": "why"} - Already known or not worth storing

        Consider: Is this genuinely new? Does it contradict something? Is it worth remembering?
        """

        let response = try await ollamaService.generate(prompt: prompt)

        guard let jsonData = extractJSON(from: response)?.data(using: .utf8) else {
            #if DEBUG
            DebugLogger.shared.log(.error, "MemoryService.consolidate: no valid JSON in response")
            #endif
            // Default to ADD if parsing fails
            let memoryType = ConversationMemory.MemoryType(rawValue: candidateFact.type) ?? .fact
            _ = try await databaseService.insertMemory(
                content: candidateFact.fact,
                type: memoryType,
                confidence: candidateFact.confidence,
                sourceSessionId: sessionId
            )
            return
        }

        do {
            let decision = try JSONDecoder().decode(ConsolidationDecision.self, from: jsonData)

            switch decision.action {
            case .ADD:
                let memoryType = ConversationMemory.MemoryType(rawValue: candidateFact.type) ?? .fact
                _ = try await databaseService.insertMemory(
                    content: candidateFact.fact,
                    type: memoryType,
                    confidence: candidateFact.confidence,
                    sourceSessionId: sessionId
                )
                #if DEBUG
                DebugLogger.shared.log(.state, "MemoryService.consolidate: ADD")
                #endif

            case .UPDATE:
                if let memoryId = decision.memoryId, let merged = decision.merged {
                    try await databaseService.updateMemory(id: memoryId, content: merged)
                    #if DEBUG
                    DebugLogger.shared.log(.state, "MemoryService.consolidate: UPDATE \(memoryId)")
                    #endif
                }

            case .DELETE:
                if let memoryId = decision.memoryId {
                    try await databaseService.deleteMemory(id: memoryId)
                    #if DEBUG
                    DebugLogger.shared.log(.state, "MemoryService.consolidate: DELETE \(memoryId)")
                    #endif
                }

            case .NOOP:
                #if DEBUG
                DebugLogger.shared.log(.state, "MemoryService.consolidate: NOOP - \(decision.reason ?? "no reason")")
                #endif
            }

        } catch {
            // If JSON parsing fails, default to ADD
            #if DEBUG
            DebugLogger.shared.log(.error, "MemoryService.consolidate: JSON parse failed, defaulting to ADD")
            #endif
            let memoryType = ConversationMemory.MemoryType(rawValue: candidateFact.type) ?? .fact
            _ = try await databaseService.insertMemory(
                content: candidateFact.fact,
                type: memoryType,
                confidence: candidateFact.confidence,
                sourceSessionId: sessionId
            )
        }
    }

    // MARK: - Retrieval

    /// Get relevant memories for a query (simple keyword match for MVP)
    func getRelevantMemories(for query: String, limit: Int = 5) async throws -> [ConversationMemory] {
        let allMemories = try await databaseService.getAllMemories(limit: 50)

        // Simple keyword matching for MVP
        let queryWords = Set(query.lowercased().split(separator: " ").map(String.init))

        let scored = allMemories.map { memory -> (memory: ConversationMemory, score: Double) in
            let contentWords = Set(memory.content.lowercased().split(separator: " ").map(String.init))
            let overlap = queryWords.intersection(contentWords).count
            let score = Double(overlap) * memory.confidence
            return (memory: memory, score: score)
        }

        let relevant = scored
            .filter { $0.score > 0 }
            .sorted { $0.score > $1.score }
            .prefix(limit)
            .map { $0.memory }

        // Touch accessed memories
        if !relevant.isEmpty {
            try await databaseService.touchMemories(ids: relevant.map { $0.id })
        }

        #if DEBUG
        DebugLogger.shared.log(.state, "MemoryService.getRelevant: \(relevant.count) memories for query")
        #endif

        return relevant
    }
}
