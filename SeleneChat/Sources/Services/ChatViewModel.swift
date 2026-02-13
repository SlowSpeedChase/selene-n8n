import Foundation

@MainActor
class ChatViewModel: ObservableObject {
    @Published var currentSession: ChatSession
    @Published var sessions: [ChatSession] = []
    @Published var isProcessing = false
    @Published var error: String?

    /// Whether to include conversation history in prompts
    @Published var useConversationHistory = true

    private let databaseService = DatabaseService.shared
    private let privacyRouter = PrivacyRouter.shared
    private let searchService = SearchService()
    private let ollamaService = OllamaService.shared
    private let queryAnalyzer = QueryAnalyzer()
    private let contextBuilder = ContextBuilder()
    private let memoryService = MemoryService.shared
    private let deepDivePromptBuilder = DeepDivePromptBuilder()
    private let synthesisPromptBuilder = SynthesisPromptBuilder()
    private let actionExtractor = ActionExtractor()
    private let actionService = ActionService()
    private let briefingContextBuilder = BriefingContextBuilder()

    /// Currently active deep-dive thread (if in deep-dive mode)
    @Published var activeDeepDiveThread: Thread?

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
            // Check for thread queries first (bypass LLM for speed)
            if let threadIntent = queryAnalyzer.detectThreadIntent(content) {
                let response = try await handleThreadQuery(intent: threadIntent)
                let assistantMessage = Message(
                    role: .assistant,
                    content: response,
                    llmTier: .onDevice,
                    queryType: "thread"
                )
                currentSession.addMessage(assistantMessage)
                await saveSession()
                return
            }

            // Check for synthesis queries (cross-thread prioritization)
            if queryAnalyzer.detectSynthesisIntent(content) {
                let (response, citedNotes, contextNotes, queryType) = try await handleSynthesisQuery(query: content)
                let assistantMessage = Message(
                    role: .assistant,
                    content: response,
                    llmTier: .local,
                    citedNotes: citedNotes,
                    contextNotes: contextNotes,
                    queryType: queryType
                )
                currentSession.addMessage(assistantMessage)
                await saveSession()
                return
            }

            // Check for deep-dive queries
            if let deepDiveIntent = queryAnalyzer.detectDeepDiveIntent(content) {
                let (response, citedNotes, contextNotes, queryType) = try await handleDeepDiveQuery(
                    threadName: deepDiveIntent.threadName,
                    query: content
                )
                let assistantMessage = Message(
                    role: .assistant,
                    content: response,
                    llmTier: .local,
                    citedNotes: citedNotes,
                    contextNotes: contextNotes,
                    queryType: queryType
                )
                currentSession.addMessage(assistantMessage)
                await saveSession()
                return
            }

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
                // Use Ollama
                let (ollamaResponse, citedNotes, contextNotes, queryType) = try await handleOllamaQuery(query: content, context: context)
                response = ollamaResponse

                // Add assistant message with citation data
                let assistantMessage = Message(
                    role: .assistant,
                    content: response,
                    llmTier: routingDecision.tier,
                    relatedNotes: relatedNotes.map(\.id),
                    citedNotes: citedNotes,
                    contextNotes: contextNotes,
                    queryType: queryType
                )
                currentSession.addMessage(assistantMessage)

                // Save session
                await saveSession()

                // Save conversation and extract memories
                saveConversationMessages(userMessage: content, assistantResponse: response)
                extractMemoriesFromExchange(userMessage: content, assistantResponse: response)

                return // Early return for local tier
            }

            // Add assistant message (for non-local tiers)
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

    // Legacy method for compatibility - routes to local tier
    private func buildSystemPrompt() -> String {
        return buildSystemPrompt(for: .general)
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

    private func handleOllamaQuery(query: String, context: String) async throws -> (response: String, citedNotes: [Note], contextNotes: [Note], queryType: String) {
        // Check Ollama availability
        let isAvailable = await ollamaService.isAvailable()

        guard isAvailable else {
            // Fallback to local query if Ollama not available
            let notes = try await findRelatedNotes(for: query)
            let fallbackResponse = try await handleLocalQuery(context: context, notes: notes)
            return (fallbackResponse, notes, notes, "fallback")
        }

        // Use QueryAnalyzer to determine query type
        // IMPORTANT: Analyze the user's query, NOT the full context (which includes note metadata)
        let analysis = queryAnalyzer.analyze(query)

        // Determine if semantic search should be used
        let useSemantic = queryAnalyzer.shouldUseSemanticSearch(query)
        let limit = limitFor(queryType: analysis.queryType)

        // Retrieve notes - semantic or traditional based on query type
        let notes: [Note]
        if useSemantic {
            notes = await databaseService.searchNotesSemantically(
                query: query,
                limit: limit
            )
        } else {
            notes = try await databaseService.retrieveNotesFor(
                queryType: analysis.queryType,
                keywords: analysis.keywords,
                timeScope: analysis.timeScope,
                limit: limit
            )
        }

        guard !notes.isEmpty else {
            let emptyResponse = "I don't have any notes matching that query yet. Try asking about something else or capture more notes first."
            return (emptyResponse, [], [], String(describing: analysis.queryType))
        }

        // Build adaptive context
        let noteContext = contextBuilder.buildContext(notes: notes, queryType: analysis.queryType)

        // Build system prompt with citation instructions and memories
        let systemPrompt = await buildSystemPromptWithMemories(for: analysis.queryType, query: query)

        // Build conversation history (excluding current message which is in context)
        let historySection: String
        if useConversationHistory {
            let priorMessages = Array(currentSession.messages.dropLast())  // Remove current user message
            let sessionContext = SessionContext(messages: priorMessages)
            if priorMessages.isEmpty {
                historySection = ""
            } else {
                historySection = """

## Conversation so far:
\(sessionContext.historyWithSummary())

"""
            }
        } else {
            historySection = ""
        }

        // Build full prompt
        let fullPrompt = """
        \(systemPrompt)
        \(historySection)
        Notes:
        \(noteContext)

        Question: \(context)
        """

        do {
            let response = try await ollamaService.generate(
                prompt: fullPrompt,
                model: "mistral:7b"
            )
            // Return response with citation data
            return (response, notes, notes, String(describing: analysis.queryType))
        } catch {
            // On error, fall back to simple local query
            let fallbackResponse = try await handleLocalQuery(context: context, notes: notes)
            return (fallbackResponse, notes, notes, "error-fallback")
        }
    }

    // MARK: - Briefing Discussion

    /// Start a discussion about a briefing card.
    /// Assembles deep context via BriefingContextBuilder, sends to Ollama,
    /// and adds the response as Selene's opening message.
    func startBriefingDiscussion(card: BriefingCard) async {
        isProcessing = true
        defer { isProcessing = false }

        do {
            // Fetch memories (shared across all card types)
            let memories = (try? await databaseService.getAllMemories(limit: 10)) ?? []

            // Build context and determine context type based on card type
            let context: String
            let contextType: BriefingContextBuilder.ContextType

            switch card.cardType {
            case .whatChanged:
                contextType = .whatChanged
                guard let noteId = card.noteId,
                      let note = try await databaseService.getNote(byId: noteId) else {
                    addErrorMessage("Could not load the note for this briefing card.")
                    return
                }
                let thread: Thread? = if let threadId = card.threadId {
                    try await databaseService.getThreadById(threadId)
                } else {
                    nil
                }
                let relatedTuples = await databaseService.getRelatedNotes(for: noteId)
                let relatedNotes = relatedTuples.map { $0.note }
                let tasks: [ThreadTask] = if let threadId = card.threadId {
                    (try? await databaseService.getTasksForThread(threadId)) ?? []
                } else {
                    []
                }
                context = briefingContextBuilder.buildWhatChangedContext(
                    note: note, thread: thread, relatedNotes: relatedNotes,
                    tasks: tasks, memories: memories
                )

            case .needsAttention:
                contextType = .needsAttention
                guard let threadId = card.threadId,
                      let thread = try await databaseService.getThreadById(threadId) else {
                    addErrorMessage("Could not load the thread for this briefing card.")
                    return
                }
                // Get recent notes for the thread
                let threadNotes: [Note]
                if let name = card.threadName,
                   let result = try await databaseService.getThreadByName(name) {
                    threadNotes = result.1
                } else {
                    threadNotes = []
                }
                let tasks = (try? await databaseService.getTasksForThread(threadId)) ?? []
                context = briefingContextBuilder.buildNeedsAttentionContext(
                    thread: thread, recentNotes: threadNotes,
                    tasks: tasks, memories: memories
                )

            case .connection:
                contextType = .connection
                guard let noteAId = card.noteAId,
                      let noteBId = card.noteBId,
                      let noteA = try await databaseService.getNote(byId: noteAId),
                      let noteB = try await databaseService.getNote(byId: noteBId) else {
                    addErrorMessage("Could not load the notes for this connection card.")
                    return
                }
                // Look up threads by name
                let threadA: Thread? = if let name = card.threadAName,
                      let result = try? await databaseService.getThreadByName(name) {
                    result.0
                } else {
                    nil
                }
                let threadB: Thread? = if let name = card.threadBName,
                      let result = try? await databaseService.getThreadByName(name) {
                    result.0
                } else {
                    nil
                }
                let relatedToA = await databaseService.getRelatedNotes(for: noteAId).map { $0.note }
                let relatedToB = await databaseService.getRelatedNotes(for: noteBId).map { $0.note }
                // Gather tasks from both threads
                var allTasks: [ThreadTask] = []
                if let threadA = threadA {
                    allTasks += (try? await databaseService.getTasksForThread(threadA.id)) ?? []
                }
                if let threadB = threadB {
                    allTasks += (try? await databaseService.getTasksForThread(threadB.id)) ?? []
                }
                context = briefingContextBuilder.buildConnectionContext(
                    noteA: noteA, threadA: threadA,
                    noteB: noteB, threadB: threadB,
                    relatedToA: relatedToA, relatedToB: relatedToB,
                    tasks: allTasks, memories: memories
                )
            }

            // Build system prompt and full LLM prompt
            let systemPrompt = briefingContextBuilder.buildSystemPrompt(for: contextType)
            let fullPrompt = "\(systemPrompt)\n\n\(context)"

            // Send to Ollama
            let response = try await ollamaService.generate(
                prompt: fullPrompt,
                model: "mistral:7b"
            )

            // Add as assistant message
            let assistantMessage = Message(
                role: .assistant,
                content: response,
                llmTier: .local,
                queryType: "briefing-\(contextType)"
            )
            currentSession.addMessage(assistantMessage)
            await saveSession()

        } catch {
            addErrorMessage("I had trouble preparing the discussion: \(error.localizedDescription)")
        }
    }

    /// Add an error message to the current chat session
    private func addErrorMessage(_ text: String) {
        self.error = text
        let errorMessage = Message(
            role: .assistant,
            content: text,
            llmTier: .onDevice
        )
        currentSession.addMessage(errorMessage)
    }

    // MARK: - Thread Query Handling

    /// Handle thread queries directly without LLM
    private func handleThreadQuery(intent: QueryAnalyzer.ThreadQueryIntent) async throws -> String {
        switch intent {
        case .listActive:
            return try await formatActiveThreads()
        case .showSpecific(let name):
            return try await formatThreadDetails(name: name)
        }
    }

    private func formatActiveThreads() async throws -> String {
        let threads = try await databaseService.getActiveThreads(limit: 10)

        guard !threads.isEmpty else {
            return """
            No active threads yet.

            Threads emerge when 3+ related notes cluster together based on semantic similarity. Keep capturing notes and threads will form automatically!
            """
        }

        var response = "**Active Threads** (by momentum)\n\n"

        for (index, thread) in threads.enumerated() {
            let momentum = thread.momentumDisplay
            let noteCount = thread.noteCount
            let lastActivity = thread.lastActivityDisplay
            let summary = thread.summary ?? "No summary yet"

            response += "\(index + 1). **\(thread.name)** (momentum: \(momentum))\n"
            response += "   -> \(noteCount) notes | Last activity: \(lastActivity)\n"
            response += "   \"\(summary.prefix(100))\(summary.count > 100 ? "..." : "")\"\n\n"
        }

        response += "_Ask \"show me [thread name] thread\" for details._"

        return response
    }

    private func formatThreadDetails(name: String) async throws -> String {
        guard let (thread, notes) = try await databaseService.getThreadByName(name) else {
            return """
            I couldn't find a thread matching "\(name)".

            Try "what's emerging" to see your active threads.
            """
        }

        var response = "**\(thread.name)**\n\n"

        if let why = thread.why, !why.isEmpty {
            response += "**Why:** \(why)\n\n"
        }

        if let summary = thread.summary, !summary.isEmpty {
            response += "**Summary:** \(summary)\n\n"
        }

        response += "**Status:** \(thread.status) \(thread.statusEmoji)\n"
        response += "**Momentum:** \(thread.momentumDisplay)\n"
        response += "**Last Activity:** \(thread.lastActivityDisplay)\n\n"

        response += "---\n\n"
        response += "**Linked Notes (\(notes.count)):**\n\n"

        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "MMM d"

        for (index, note) in notes.prefix(10).enumerated() {
            let dateStr = dateFormatter.string(from: note.createdAt)

            response += "- [\(index + 1)] \"\(note.title)\" - \(dateStr)\n"
        }

        if notes.count > 10 {
            response += "\n_...and \(notes.count - 10) more notes_"
        }

        return response
    }

    // MARK: - Deep-Dive Query Handling

    /// Handle deep-dive queries into specific threads
    private func handleDeepDiveQuery(threadName: String, query: String) async throws -> (response: String, citedNotes: [Note], contextNotes: [Note], queryType: String) {
        // 1. Find thread by name
        guard let (thread, notes) = try await databaseService.getThreadByName(threadName) else {
            let notFound = "I couldn't find a thread matching \"\(threadName)\". Try \"what's emerging\" to see your active threads."
            return (notFound, [], [], "deep-dive-not-found")
        }

        // 2. Set active thread
        activeDeepDiveThread = thread

        // 3. Build prompt (initial or follow-up based on history)
        let prompt: String
        if useConversationHistory {
            let priorMessages = Array(currentSession.messages.dropLast())
            let sessionContext = SessionContext(messages: priorMessages)

            if priorMessages.isEmpty {
                prompt = deepDivePromptBuilder.buildInitialPrompt(thread: thread, notes: notes)
            } else {
                prompt = deepDivePromptBuilder.buildFollowUpPrompt(
                    thread: thread,
                    notes: notes,
                    conversationHistory: sessionContext.historyWithSummary(),
                    currentQuery: query
                )
            }
        } else {
            prompt = deepDivePromptBuilder.buildInitialPrompt(thread: thread, notes: notes)
        }

        // 4. Generate response
        let response = try await ollamaService.generate(prompt: prompt, model: "mistral:7b")

        // 5. Extract and capture actions
        let actions = actionExtractor.extractActions(from: response)
        for action in actions {
            await actionService.capture(action, threadName: thread.name)
        }

        // 6. Clean response for display
        let cleanResponse = actionExtractor.removeActionMarkers(from: response)

        return (cleanResponse, notes, notes, "deep-dive")
    }

    // MARK: - Synthesis Query Handling

    /// Handle synthesis queries (cross-thread prioritization)
    private func handleSynthesisQuery(query: String) async throws -> (response: String, citedNotes: [Note], contextNotes: [Note], queryType: String) {
        // 1. Get all active threads
        let threads = try await databaseService.getActiveThreads(limit: 10)

        guard !threads.isEmpty else {
            let noThreads = "You don't have any active threads yet. Keep capturing notes and threads will emerge as related ideas cluster together."
            return (noThreads, [], [], "synthesis-empty")
        }

        // 2. Get recent notes for each thread (3 notes each)
        var notesPerThread: [Int64: [Note]] = [:]
        for thread in threads {
            if let (_, notes) = try await databaseService.getThreadByName(thread.name) {
                notesPerThread[thread.id] = Array(notes.prefix(3))
            }
        }

        // 3. Build prompt (with or without history)
        let prompt: String
        if useConversationHistory {
            let priorMessages = Array(currentSession.messages.dropLast())
            let sessionContext = SessionContext(messages: priorMessages)

            if priorMessages.isEmpty {
                prompt = synthesisPromptBuilder.buildSynthesisPrompt(threads: threads, notesPerThread: notesPerThread)
            } else {
                prompt = synthesisPromptBuilder.buildSynthesisPromptWithHistory(
                    threads: threads,
                    notesPerThread: notesPerThread,
                    conversationHistory: sessionContext.historyWithSummary(),
                    currentQuery: query
                )
            }
        } else {
            prompt = synthesisPromptBuilder.buildSynthesisPrompt(threads: threads, notesPerThread: notesPerThread)
        }

        // 4. Generate response
        let response = try await ollamaService.generate(prompt: prompt, model: "mistral:7b")

        // 5. Collect all notes for citation
        let allNotes = notesPerThread.values.flatMap { $0 }

        return (response, allNotes, allNotes, "synthesis")
    }

    private func limitFor(queryType: QueryAnalyzer.QueryType) -> Int {
        switch queryType {
        case .pattern: return 100
        case .search: return 50
        case .knowledge: return 15
        case .general: return 30
        case .thread: return 50  // Thread queries need moderate context
        case .semantic: return 20  // Semantic queries return focused, conceptually related notes
        case .deepDive: return 50  // Deep-dive needs thread context
        case .synthesis: return 50  // Synthesis needs cross-thread context
        }
    }

    private func buildSystemPrompt(for queryType: QueryAnalyzer.QueryType) -> String {
        var basePrompt = """
        You are Selene, a personal AI assistant helping someone with ADHD manage their thoughts and notes.

        Your role:
        - Analyze patterns in their notes (energy, mood, themes, concepts)
        - Provide actionable recommendations
        - Be conversational and supportive
        - Focus on insights that lead to action

        """

        // Memories will be injected here asynchronously in the caller

        basePrompt += """
        IMPORTANT - Citations:
        - When referencing specific notes, ALWAYS cite them as: [Note: 'Title' - Date]
        - Example: "You mentioned feeling productive in the morning [Note: 'Morning Routine' - Nov 14]"
        - Place citations immediately after the relevant statement
        - Use exact note titles and dates provided in the context

        Guidelines:
        - Keep responses concise but insightful
        - Highlight patterns and correlations when they exist
        - Suggest concrete next steps
        - Be empathetic about ADHD challenges

        The user's notes contain timestamps, energy levels, sentiment, themes, and concepts extracted by AI.
        """

        // Add query-specific instructions
        let querySpecific: String
        switch queryType {
        case .pattern:
            querySpecific = "\n\nAnalyze these notes for trends and patterns. Look for patterns in energy, themes, sentiment, and timing. Be specific and cite notes as evidence."
        case .search:
            querySpecific = "\n\nSummarize what these notes say about the topic. Highlight key points and cite relevant notes."
        case .knowledge:
            querySpecific = "\n\nAnswer this question based on the note content. Cite specific notes that contain the answer."
        case .general:
            querySpecific = "\n\nProvide insights based on recent notes. Highlight interesting patterns and cite specific examples."
        case .thread:
            querySpecific = "\n\nThis is a thread-related query. Show emerging threads and patterns in the notes. Group related ideas and cite specific notes."
        case .semantic:
            querySpecific = "\n\nThese notes are conceptually related to the query. Explore the connections and themes. Highlight how ideas relate to each other and cite specific notes."
        case .deepDive:
            querySpecific = "\n\nThis is a deep-dive into a specific thread. Analyze the thread's evolution, key insights, tensions, and suggest next actions. Use [ACTION: description | ENERGY: level | TIMEFRAME: time] markers for actionable items."
        case .synthesis:
            querySpecific = "\n\nThis is a synthesis/prioritization request. Analyze active threads and help prioritize where to focus energy. Consider thread momentum, urgency, and the user's current energy state."
        }

        return basePrompt + querySpecific
    }

    /// Build system prompt with relevant memories injected
    private func buildSystemPromptWithMemories(for queryType: QueryAnalyzer.QueryType, query: String) async -> String {
        var prompt = buildSystemPrompt(for: queryType)

        // Get relevant memories
        do {
            let memories = try await memoryService.getRelevantMemories(for: query, limit: 5)
            if !memories.isEmpty {
                var memorySection = "\n## What you remember about this user:\n"
                for memory in memories {
                    memorySection += "- \(memory.content)\n"
                }
                memorySection += "\n"
                // Insert after the base prompt intro
                prompt = prompt.replacingOccurrences(
                    of: "IMPORTANT - Citations:",
                    with: memorySection + "IMPORTANT - Citations:"
                )
            }
        } catch {
            #if DEBUG
            DebugLogger.shared.log(.error, "ChatViewModel.buildSystemPromptWithMemories: memory retrieval failed - \(error)")
            #endif
        }

        return prompt
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

    func togglePin(_ session: ChatSession) {
        // Update in-memory session
        if let index = sessions.firstIndex(where: { $0.id == session.id }) {
            sessions[index].isPinned.toggle()

            // If this is the current session, update it too
            if currentSession.id == session.id {
                currentSession.isPinned = sessions[index].isPinned
            }

            Task {
                do {
                    try await databaseService.updateSessionPin(sessionId: session.id, isPinned: sessions[index].isPinned)
                } catch {
                    print("⚠️ Failed to update pin status: \(error.localizedDescription)")
                }
            }
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

    // MARK: - Conversation Memory

    /// Save conversation messages to database
    private func saveConversationMessages(userMessage: String, assistantResponse: String) {
        Task {
            do {
                try await databaseService.saveConversationMessage(
                    sessionId: currentSession.id,
                    role: "user",
                    content: userMessage
                )
                try await databaseService.saveConversationMessage(
                    sessionId: currentSession.id,
                    role: "assistant",
                    content: assistantResponse
                )
            } catch {
                #if DEBUG
                DebugLogger.shared.log(.error, "ChatViewModel.saveConversation: failed - \(error)")
                #endif
            }
        }
    }

    /// Extract memories from the exchange (runs in background)
    private func extractMemoriesFromExchange(userMessage: String, assistantResponse: String) {
        Task {
            do {
                // Get recent messages for context
                let recentMessages = try await databaseService.getRecentMessages(
                    sessionId: currentSession.id,
                    limit: 10
                )

                // Extract candidate facts
                let facts = try await memoryService.extractMemories(
                    userMessage: userMessage,
                    assistantResponse: assistantResponse,
                    recentMessages: recentMessages
                )

                // Consolidate each fact
                for fact in facts {
                    try await memoryService.consolidateMemory(
                        candidateFact: fact,
                        sessionId: currentSession.id
                    )
                }

                #if DEBUG
                DebugLogger.shared.log(.state, "ChatViewModel.extractMemories: processed \(facts.count) facts")
                #endif
            } catch {
                #if DEBUG
                DebugLogger.shared.log(.error, "ChatViewModel.extractMemories: failed - \(error)")
                #endif
            }
        }
    }
}

#if DEBUG
@MainActor
extension ChatViewModel: @MainActor DebugSnapshotProvider {
    func debugSnapshot() -> [String: Any] {
        return [
            "messagesCount": currentSession.messages.count,
            "isLoading": isProcessing,
            "currentSessionId": currentSession.id.uuidString,
            "error": error ?? "none"
        ]
    }
}
#endif
