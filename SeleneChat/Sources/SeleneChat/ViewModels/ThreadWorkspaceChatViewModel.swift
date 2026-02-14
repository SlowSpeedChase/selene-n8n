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

    // MARK: - Init

    init(thread: Thread, notes: [Note], tasks: [ThreadTask]) {
        self.thread = thread
        self.notes = notes
        self.tasks = tasks
    }

    // MARK: - Send Message

    /// Send a user message and get an LLM response.
    func sendMessage(_ content: String) async {
        guard !content.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return }

        addUserMessage(content)
        isProcessing = true
        defer { isProcessing = false }

        do {
            let prompt = buildPrompt(for: content)
            let response = try await ollamaService.generate(prompt: prompt)
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
        // If no prior conversation, use initial prompt
        let priorMessages = messages.filter { $0.role != .system }
        // Only user+assistant messages before the current user message count as history
        // The current user message was just added, so check for prior assistant messages
        let hasHistory = priorMessages.contains { $0.role == .assistant }

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
}
