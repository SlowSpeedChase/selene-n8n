import Foundation

@MainActor
class ChatViewModel: ObservableObject {
    @Published var currentSession: ChatSession
    @Published var sessions: [ChatSession] = []
    @Published var isProcessing = false
    @Published var error: String?

    private let databaseService = DatabaseService.shared
    private let privacyRouter = PrivacyRouter.shared
    private let searchService = SearchService()
    private let ollamaService = OllamaService.shared

    init() {
        self.currentSession = ChatSession()
        Task {
            await loadSessions()
        }
    }

    func sendMessage(_ content: String) async {
        isProcessing = true
        defer { isProcessing = false }

        // Add user message
        let userMessage = Message(
            role: .user,
            content: content,
            llmTier: .onDevice
        )
        currentSession.addMessage(userMessage)

        do {
            // Determine routing
            let relatedNotes = try await findRelatedNotes(for: content)
            let routingDecision = privacyRouter.routeQuery(content, relatedNotes: relatedNotes)

            // Build context
            let context = buildContext(query: content, notes: relatedNotes)

            // Get response based on routing
            let response: String
            switch routingDecision.tier {
            case .onDevice, .privateCloud:
                // For now, we'll use a placeholder. In Phase 2, we'll integrate Apple Intelligence
                response = try await handleLocalQuery(context: context, notes: relatedNotes)

            case .external:
                // For now, we'll use a placeholder. In Phase 3, we'll integrate Claude API
                response = try await handleExternalQuery(context: context)

            case .local:
                // Use Ollama with fallback
                do {
                    response = try await handleOllamaQuery(context: context)
                } catch {
                    // Fallback to simple response if Ollama unavailable
                    print("⚠️ Falling back to simple response: \(error.localizedDescription)")
                    response = """
                    I'm having trouble connecting to the local AI service. Here are the related notes I found:

                    \(try await handleLocalQuery(context: context, notes: relatedNotes))
                    """
                }
            }

            // Add assistant message
            let assistantMessage = Message(
                role: .assistant,
                content: response,
                llmTier: routingDecision.tier,
                relatedNotes: relatedNotes.map(\.id)
            )
            currentSession.addMessage(assistantMessage)

            // Save session
            await saveSession()

        } catch {
            self.error = error.localizedDescription
            let errorMessage = Message(
                role: .assistant,
                content: "I encountered an error: \(error.localizedDescription)",
                llmTier: .onDevice
            )
            currentSession.addMessage(errorMessage)
        }
    }

    private func findRelatedNotes(for query: String) async throws -> [Note] {
        // Extract keywords from query
        let keywords = extractKeywords(from: query)

        var allNotes: [Note] = []

        // Search by keywords
        for keyword in keywords.prefix(3) { // Limit to top 3 keywords
            let notes = try await databaseService.searchNotes(query: keyword, limit: 5)
            allNotes.append(contentsOf: notes)
        }

        // Remove duplicates and sort by relevance
        let uniqueNotes = Array(Set(allNotes)).sorted { note1, note2 in
            let relevance1 = calculateRelevance(note: note1, query: query)
            let relevance2 = calculateRelevance(note: note2, query: query)
            return relevance1 > relevance2
        }

        return Array(uniqueNotes.prefix(5)) // Return top 5 most relevant
    }

    private func extractKeywords(from query: String) -> [String] {
        // Simple keyword extraction
        let stopWords = Set(["the", "a", "an", "and", "or", "but", "in", "on", "at", "to", "for",
                             "of", "with", "by", "from", "up", "about", "into", "through", "during",
                             "what", "where", "when", "why", "how", "show", "find", "get", "me", "my"])

        let words = query.lowercased()
            .components(separatedBy: .punctuationCharacters)
            .joined()
            .components(separatedBy: .whitespaces)
            .filter { !stopWords.contains($0) && $0.count > 2 }

        return words
    }

    private func calculateRelevance(note: Note, query: String) -> Int {
        var score = 0
        let queryLower = query.lowercased()
        let contentLower = note.content.lowercased()
        let titleLower = note.title.lowercased()

        // Title matches are more important
        if titleLower.contains(queryLower) {
            score += 10
        }

        // Content matches
        let words = queryLower.components(separatedBy: .whitespaces)
        for word in words where word.count > 2 {
            if titleLower.contains(word) {
                score += 5
            }
            if contentLower.contains(word) {
                score += 1
            }
        }

        return score
    }

    private func buildContext(query: String, notes: [Note]) -> String {
        var context = "User query: \(query)\n\n"

        if !notes.isEmpty {
            context += "Related notes from Selene:\n\n"
            for (index, note) in notes.enumerated() {
                context += "[\(index + 1)] \(note.title)\n"
                context += "Date: \(note.formattedDate)\n"
                if let theme = note.primaryTheme {
                    context += "Theme: \(theme)\n"
                }
                if let concepts = note.concepts {
                    context += "Concepts: \(concepts.joined(separator: ", "))\n"
                }
                if let energy = note.energyLevel {
                    context += "Energy: \(energy) \(note.energyEmoji)\n"
                }
                context += "\nContent preview:\n\(note.preview)\n"
                context += "\n---\n\n"
            }
        }

        return context
    }

    private func buildSystemPrompt() -> String {
        """
        You are Selene, a personal AI assistant helping someone with ADHD manage their thoughts and notes.

        Your role:
        - Analyze patterns in their notes (energy, mood, themes, concepts)
        - Provide actionable recommendations
        - Be conversational and supportive
        - Focus on insights that lead to action

        Guidelines:
        - Keep responses concise but insightful
        - Highlight patterns and correlations when they exist
        - Suggest concrete next steps
        - Reference specific notes when relevant
        - Be empathetic about ADHD challenges

        The user's notes contain timestamps, energy levels, sentiment, themes, and concepts extracted by AI.
        """
    }

    private func handleLocalQuery(context: String, notes: [Note]) async throws -> String {
        // Phase 1: Simple response based on notes
        // Phase 2: Will integrate Apple Intelligence

        if notes.isEmpty {
            return "I couldn't find any related notes. Try rephrasing your query or using different keywords."
        }

        var response = "I found \(notes.count) related note\(notes.count == 1 ? "" : "s"):\n\n"

        for (index, note) in notes.enumerated() {
            response += "\(index + 1). **\(note.title)** (\(note.formattedDate))\n"
            if let theme = note.primaryTheme {
                response += "   Theme: \(theme)\n"
            }
            if let concepts = note.concepts, !concepts.isEmpty {
                response += "   Concepts: \(concepts.joined(separator: ", "))\n"
            }
            if let energy = note.energyLevel {
                response += "   Energy: \(energy) \(note.energyEmoji)\n"
            }
            response += "\n"
        }

        return response
    }

    private func handleExternalQuery(context: String) async throws -> String {
        // Phase 3: Will integrate Claude API
        // For now, return a placeholder

        return """
        [External LLM Mode - Claude API]

        This query has been routed to Claude API because it appears to be a non-sensitive, general planning or technical question.

        Claude API integration will be implemented in Phase 3.

        Your query was: \(context.components(separatedBy: "\n").first ?? "")
        """
    }

    private func handleOllamaQuery(context: String) async throws -> String {
        // Check if Ollama is available
        let isOllamaAvailable = await ollamaService.isAvailable()

        guard isOllamaAvailable else {
            print("⚠️ Ollama unavailable, falling back to simple response")
            // Extract notes from context to pass to fallback
            // For now, just indicate fallback is happening
            throw OllamaError.serviceUnavailable
        }

        // Build full prompt with system instructions
        let systemPrompt = buildSystemPrompt()
        let fullPrompt = """
        \(systemPrompt)

        \(context)

        Provide an actionable, insightful response based on these notes.
        """

        do {
            let response = try await ollamaService.generate(
                prompt: fullPrompt,
                model: "mistral:7b"
            )

            return response

        } catch {
            print("⚠️ Ollama generation failed: \(error.localizedDescription)")
            throw error
        }
    }

    // Define OllamaError locally for easy throwing
    private enum OllamaError: Error, LocalizedError {
        case serviceUnavailable

        var errorDescription: String? {
            "Ollama service is unavailable"
        }
    }

    func newSession() {
        Task {
            await saveSession()
        }
        currentSession = ChatSession()
    }

    func loadSession(_ session: ChatSession) {
        Task {
            await saveSession()  // Save current session before loading new one
        }
        currentSession = session
    }

    func deleteSession(_ session: ChatSession) {
        sessions.removeAll { $0.id == session.id }

        Task {
            try? await databaseService.deleteSession(session)
        }

        if currentSession.id == session.id {
            newSession()
        }
    }

    private func saveSession() async {
        // Skip saving empty sessions (no messages)
        guard !currentSession.messages.isEmpty else { return }

        // Update in-memory sessions list
        if let index = sessions.firstIndex(where: { $0.id == currentSession.id }) {
            sessions[index] = currentSession
        } else {
            sessions.append(currentSession)
        }

        // Persist to database
        do {
            try await databaseService.saveSession(currentSession)
        } catch {
            print("⚠️ Failed to save session: \(error.localizedDescription)")
            // Don't crash - graceful degradation
        }
    }

    private func loadSessions() async {
        do {
            sessions = try await databaseService.loadSessions()
        } catch {
            print("⚠️ Failed to load sessions: \(error.localizedDescription)")
            // Fall back to empty list - graceful degradation
            sessions = []
        }
    }
}
