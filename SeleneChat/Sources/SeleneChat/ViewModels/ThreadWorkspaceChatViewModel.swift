import SeleneShared
import Foundation

/// Chat view model scoped to a single thread workspace.
/// Handles message pipeline, action extraction, and confirmation flow.
@MainActor
class ThreadWorkspaceChatViewModel: ObservableObject {

    // MARK: - Published State

    @Published var messages: [Message] = []
    @Published var isProcessing = false
    @Published var pendingActions: [ActionExtractor.ExtractedAction] = []

    // MARK: - Context

    let thread: Thread
    let notes: [Note]
    private(set) var tasks: [ThreadTask]

    // MARK: - Services

    private let ollamaService = OllamaService.shared
    private let actionExtractor = ActionExtractor()
    private let actionService = ActionService()
    private let promptBuilder = ThreadWorkspacePromptBuilder()
    private let databaseService = DatabaseService.shared
    private var pinnedChunkIds: Set<Int64> = []
    private let chunkRetrievalService = ChunkRetrievalService()

    // MARK: - Init

    init(thread: Thread, notes: [Note], tasks: [ThreadTask]) {
        self.thread = thread
        self.notes = notes
        self.tasks = tasks
    }

    // MARK: - Send Message

    /// Send a user message and get an LLM response using chunk-based retrieval.
    func sendMessage(_ content: String) async {
        guard !content.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return }

        addUserMessage(content)
        isProcessing = true
        defer { isProcessing = false }

        do {
            let prompt = await buildChunkBasedPrompt(for: content)
            let response = try await ollamaService.generate(prompt: prompt, numCtx: 16384)
            processResponse(response)
        } catch {
            let errorMessage = Message(
                role: .assistant,
                content: "Sorry, I couldn't process that. \(error.localizedDescription)",
                llmTier: .local
            )
            messages.append(errorMessage)
        }
    }

    // MARK: - Process Response

    /// Process an LLM response: extract actions and add cleaned message.
    func processResponse(_ response: String) {
        let actions = actionExtractor.extractActions(from: response)
        let cleanedResponse = actionExtractor.removeActionMarkers(from: response)

        let message = Message(
            role: .assistant,
            content: cleanedResponse,
            llmTier: .local
        )
        messages.append(message)

        // Replace any previous pending actions with new ones
        pendingActions = actions
    }

    // MARK: - User Message

    /// Add a user message to the conversation.
    func addUserMessage(_ content: String) {
        let message = Message(
            role: .user,
            content: content,
            llmTier: .local
        )
        messages.append(message)
    }

    // MARK: - Action Confirmation

    /// Confirm pending actions: create tasks in Things and link to thread.
    func confirmActions() async -> [String] {
        var createdIds: [String] = []

        for action in pendingActions {
            do {
                let thingsId = try await actionService.sendToThingsAndLinkThread(
                    action,
                    threadName: thread.name,
                    threadId: thread.id
                )
                createdIds.append(thingsId)
            } catch {
                print("[ThreadWorkspaceChatVM] Failed to create task: \(error)")
            }
        }

        pendingActions = []

        // Reload tasks to reflect newly created ones
        if !createdIds.isEmpty {
            do {
                tasks = try await databaseService.getTasksForThread(thread.id)
            } catch {
                print("[ThreadWorkspaceChatVM] Failed to reload tasks: \(error)")
            }
        }

        return createdIds
    }

    /// Dismiss pending actions without creating tasks.
    func dismissActions() {
        pendingActions = []
    }

    // MARK: - Update Tasks

    /// Update the task list (e.g., after external changes).
    func updateTasks(_ newTasks: [ThreadTask]) {
        tasks = newTasks
    }

    // MARK: - Prompt Building

    /// Build the appropriate prompt for the current conversation state.
    func buildPrompt(for query: String) -> String {
        // Check for "what's next" query first
        if promptBuilder.isWhatsNextQuery(query) {
            return promptBuilder.buildWhatsNextPrompt(
                thread: thread,
                notes: notes,
                tasks: tasks
            )
        }

        // Check for planning intent (first message only — follow-ups use regular flow)
        let priorMessages = messages.filter { $0.role != .system }
        let hasHistory = priorMessages.contains { $0.role == .assistant }

        if !hasHistory && promptBuilder.isPlanningQuery(query) {
            return promptBuilder.buildPlanningPrompt(
                thread: thread,
                notes: notes,
                tasks: tasks,
                userQuery: query
            )
        }

        if hasHistory {
            let history = buildConversationHistory()
            return promptBuilder.buildFollowUpPrompt(
                thread: thread,
                notes: notes,
                tasks: tasks,
                conversationHistory: history,
                currentQuery: query
            )
        } else {
            return promptBuilder.buildInitialPrompt(
                thread: thread,
                notes: notes,
                tasks: tasks
            )
        }
    }

    /// Build conversation history string from messages.
    func buildConversationHistory() -> String {
        messages.map { msg in
            let role = msg.role == .user ? "User" : "Assistant"
            return "\(role): \(msg.content)"
        }.joined(separator: "\n")
    }

    // MARK: - Chunk-Based Prompt Building

    /// Build a prompt using chunk-based retrieval instead of full notes.
    /// Falls back to old approach if no chunks are available.
    func buildChunkBasedPrompt(for query: String) async -> String {
        // Check for "what's next" query first — uses old approach
        if promptBuilder.isWhatsNextQuery(query) {
            return promptBuilder.buildWhatsNextPrompt(
                thread: thread,
                notes: notes,
                tasks: tasks
            )
        }

        // Check for planning intent (first message only)
        let priorMessages = messages.filter { $0.role != .system }
        let hasHistory = priorMessages.contains { $0.role == .assistant }

        if !hasHistory && promptBuilder.isPlanningQuery(query) {
            return promptBuilder.buildPlanningPrompt(
                thread: thread,
                notes: notes,
                tasks: tasks,
                userQuery: query
            )
        }

        // Try to retrieve relevant chunks
        let retrievedChunks = await retrieveChunksForQuery(query)

        // If no chunks available, fall back to old approach
        guard !retrievedChunks.isEmpty else {
            return buildPrompt(for: query)
        }

        // Get pinned chunks from prior turns
        let pinned = await getPinnedChunks()

        // Pin newly retrieved chunk IDs for future turns
        pinnedChunkIds.formUnion(retrievedChunks.map { $0.chunk.id })

        // Check if we have conversation history (reuses hasHistory from planning check above)
        if hasHistory {
            let history = buildConversationHistory()
            return promptBuilder.buildFollowUpPromptWithChunks(
                thread: thread,
                pinnedChunks: pinned,
                retrievedChunks: retrievedChunks,
                tasks: tasks,
                conversationHistory: history,
                currentQuery: query
            )
        } else {
            return promptBuilder.buildInitialPromptWithChunks(
                thread: thread,
                retrievedChunks: retrievedChunks,
                tasks: tasks
            )
        }
    }

    /// Retrieve the most relevant chunks for a query via embedding + cosine similarity.
    private func retrieveChunksForQuery(_ query: String) async -> [(chunk: NoteChunk, similarity: Float)] {
        do {
            let noteIds = notes.map { $0.id }
            guard !noteIds.isEmpty else { return [] }

            let queryEmbedding = try await ollamaService.embed(text: query)

            let candidates = try await databaseService.getChunksWithEmbeddings(noteIds: noteIds)
            let validCandidates: [(chunk: NoteChunk, embedding: [Float])] = candidates.compactMap { item in
                guard let embedding = item.embedding else { return nil }
                return (chunk: item.chunk, embedding: embedding)
            }

            guard !validCandidates.isEmpty else { return [] }

            let results = chunkRetrievalService.retrieveTopChunks(
                queryEmbedding: queryEmbedding,
                candidates: validCandidates,
                limit: 15,
                minSimilarity: 0.3,
                tokenBudget: 8000
            )

            // If thread-scoped results are poor, try global fallback
            if results.isEmpty || (results.first?.similarity ?? 0) < 0.5 {
                let allCandidates = try await databaseService.getAllChunksWithEmbeddings()
                let validAll: [(chunk: NoteChunk, embedding: [Float])] = allCandidates.compactMap { item in
                    guard let embedding = item.embedding else { return nil }
                    return (chunk: item.chunk, embedding: embedding)
                }
                if !validAll.isEmpty {
                    return chunkRetrievalService.retrieveTopChunks(
                        queryEmbedding: queryEmbedding,
                        candidates: validAll,
                        limit: 15,
                        minSimilarity: 0.3,
                        tokenBudget: 8000
                    )
                }
            }

            return results
        } catch {
            print("[ThreadWorkspaceChatVM] Chunk retrieval failed: \(error)")
            return []
        }
    }

    /// Get pinned chunks from prior conversation turns.
    private func getPinnedChunks() async -> [(chunk: NoteChunk, similarity: Float)] {
        guard !pinnedChunkIds.isEmpty else { return [] }

        do {
            let noteIds = notes.map { $0.id }
            guard !noteIds.isEmpty else { return [] }

            let allChunks = try await databaseService.getChunksForNotes(noteIds: noteIds)
            return allChunks
                .filter { pinnedChunkIds.contains($0.id) }
                .map { (chunk: $0, similarity: Float(1.0)) }
        } catch {
            print("[ThreadWorkspaceChatVM] Failed to load pinned chunks: \(error)")
            return []
        }
    }
}
