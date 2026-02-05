import Foundation

/// ViewModel for managing morning briefing state and orchestrating briefing generation
@MainActor
class BriefingViewModel: ObservableObject {
    /// Current briefing state
    @Published var state = BriefingState()

    /// Whether the briefing has been dismissed
    @Published var isDismissed = false

    /// Briefing generator service
    private let generator = BriefingGenerator()

    /// Database service for fetching threads and notes
    private let databaseService = DatabaseService.shared

    /// Ollama service for LLM generation
    private let ollamaService = OllamaService.shared

    // MARK: - Public Methods

    /// Load the morning briefing
    /// - Checks Ollama availability
    /// - Fetches active threads and recent notes
    /// - Generates briefing via LLM
    func loadBriefing() async {
        state.status = .loading

        // Check if Ollama is available
        let isAvailable = await ollamaService.isAvailable()
        guard isAvailable else {
            state.status = .failed("Selene is thinking... (Ollama not available)")
            return
        }

        do {
            // Fetch active threads (top 5 by momentum)
            let threads = try await databaseService.getActiveThreads(limit: 5)

            // Fetch recent notes (last 7 days, up to 10)
            let recentNotes = try await databaseService.getRecentNotes(days: 7, limit: 10)

            // Build the briefing prompt
            let prompt = generator.buildBriefingPrompt(threads: threads, recentNotes: recentNotes)

            // Generate briefing via Ollama
            let response = try await ollamaService.generate(prompt: prompt, model: "mistral:7b")

            // Parse the response into a Briefing struct
            let briefing = generator.parseBriefingResponse(response, threads: threads)

            // Update state to loaded
            state.status = .loaded(briefing)

        } catch {
            state.status = .failed(error.localizedDescription)
        }
    }

    /// Dismiss the briefing
    func dismiss() async {
        isDismissed = true
    }

    /// Get a query to dig into the suggested thread
    /// - Returns: A query string to start exploring the suggested thread
    func digIn() async -> String {
        if case .loaded(let briefing) = state.status,
           let thread = briefing.suggestedThread {
            return "Let's dig into \(thread)"
        }
        return "What should I focus on?"
    }

    /// Get a query to explore something else
    /// - Returns: A query string to explore other notes
    func showSomethingElse() async -> String {
        return "What else is happening in my notes?"
    }
}
