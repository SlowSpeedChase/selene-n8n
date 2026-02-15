import Foundation

/// Builds prompts for thread workspace chat conversations.
/// Similar to DeepDivePromptBuilder but includes task state context.
public class ThreadWorkspacePromptBuilder {

    private let contextBuilder = ThinkingPartnerContextBuilder()

    // MARK: - System Identity

    private let systemIdentity = """
    You are an interactive thinking partner for someone with ADHD. Your job is to help the user make progress on this thread — not summarize it back to them.

    CAPABILITIES:
    - You can create tasks in Things (the user's task manager). When you and the user have collaboratively identified concrete next steps, suggest them using action markers:
      [ACTION: Brief action description | ENERGY: high/medium/low | TIMEFRAME: today/this-week/someday]
    - You have full context of the user's notes, thread history, and existing tasks

    BEHAVIOR:
    - When the user asks for planning help: Ask 1-2 clarifying questions about their priorities or constraints first, then break the problem into concrete steps
    - When the user asks "what's next": Propose 2-3 possible directions with trade-offs, ask which resonates
    - When you identify actionable steps: Suggest creating them as tasks in Things
    - Default: Be a collaborator, not a summarizer. Ask before assuming.

    Be concise but thorough. Prefer asking a good question over giving a generic answer. Never summarize the thread back to the user unless they specifically ask for a summary.
    """

    // MARK: - Init

    public init() {}

    // MARK: - Initial Prompt

    /// Build the initial prompt for a workspace chat session.
    /// - Parameters:
    ///   - thread: The thread being worked on
    ///   - notes: Notes belonging to this thread
    ///   - tasks: Current tasks linked to this thread
    /// - Returns: A formatted prompt string for the LLM
    public func buildInitialPrompt(thread: Thread, notes: [Note], tasks: [ThreadTask]) -> String {
        let threadContext = contextBuilder.buildDeepDiveContext(thread: thread, notes: notes)
        let taskContext = buildTaskContext(tasks)

        return """
        \(systemIdentity)

        ## Thread: "\(thread.name)"

        \(threadContext)

        \(taskContext)
        """
    }

    // MARK: - Follow-Up Prompt

    /// Build a follow-up prompt that includes conversation history and current task state.
    /// - Parameters:
    ///   - thread: The thread being worked on
    ///   - notes: Notes belonging to this thread
    ///   - tasks: Current tasks linked to this thread
    ///   - conversationHistory: Previous exchanges in this session
    ///   - currentQuery: The user's current question
    /// - Returns: A formatted prompt string for the LLM
    public func buildFollowUpPrompt(
        thread: Thread,
        notes: [Note],
        tasks: [ThreadTask],
        conversationHistory: String,
        currentQuery: String
    ) -> String {
        let threadContext = contextBuilder.buildDeepDiveContext(thread: thread, notes: notes)
        let taskContext = buildTaskContext(tasks)

        return """
        \(systemIdentity)

        ## Thread: "\(thread.name)"

        \(threadContext)

        \(taskContext)

        ## Conversation So Far
        \(conversationHistory)

        ## Current Question
        \(currentQuery)
        """
    }

    // MARK: - Task Context

    private func buildTaskContext(_ tasks: [ThreadTask]) -> String {
        guard !tasks.isEmpty else {
            return "## Current Tasks\nNo tasks linked to this thread yet."
        }

        let openTasks = tasks.filter { !$0.isCompleted }
        let completedTasks = tasks.filter { $0.isCompleted }

        var context = "## Current Tasks (\(openTasks.count) open, \(completedTasks.count) completed)\n"

        for task in openTasks {
            let title = task.title ?? task.thingsTaskId
            context += "- [ ] \(title)\n"
        }

        for task in completedTasks {
            let title = task.title ?? task.thingsTaskId
            context += "- [x] \(title)\n"
        }

        return context
    }

    // MARK: - Chunk-Based Prompts

    /// Build the initial prompt using retrieved chunks instead of full notes.
    /// - Parameters:
    ///   - thread: The thread being worked on
    ///   - retrievedChunks: Semantically relevant chunks with similarity scores
    ///   - tasks: Current tasks linked to this thread
    /// - Returns: A formatted prompt string for the LLM
    public func buildInitialPromptWithChunks(
        thread: Thread,
        retrievedChunks: [(chunk: NoteChunk, similarity: Float)],
        tasks: [ThreadTask]
    ) -> String {
        let chunkContext = formatChunkContext(thread: thread, chunks: retrievedChunks)
        let taskContext = buildTaskContext(tasks)

        return """
        \(systemIdentity)

        \(chunkContext)

        \(taskContext)
        """
    }

    /// Build a follow-up prompt with pinned chunks from prior turns and newly retrieved chunks.
    /// - Parameters:
    ///   - thread: The thread being worked on
    ///   - pinnedChunks: Chunks referenced in prior conversation turns (preserves context)
    ///   - retrievedChunks: Newly retrieved chunks for the current query
    ///   - tasks: Current tasks linked to this thread
    ///   - conversationHistory: Previous exchanges in this session
    ///   - currentQuery: The user's current question
    /// - Returns: A formatted prompt string for the LLM
    public func buildFollowUpPromptWithChunks(
        thread: Thread,
        pinnedChunks: [(chunk: NoteChunk, similarity: Float)],
        retrievedChunks: [(chunk: NoteChunk, similarity: Float)],
        tasks: [ThreadTask],
        conversationHistory: String,
        currentQuery: String
    ) -> String {
        let chunkContext = formatChunkContext(thread: thread, chunks: pinnedChunks + retrievedChunks)
        let taskContext = buildTaskContext(tasks)

        return """
        \(systemIdentity)

        \(chunkContext)

        \(taskContext)

        ## Conversation So Far
        \(conversationHistory)

        ## Current Question
        \(currentQuery)
        """
    }

    /// Format retrieved chunks into context for the prompt, deduplicating by chunk ID.
    private func formatChunkContext(thread: Thread, chunks: [(chunk: NoteChunk, similarity: Float)]) -> String {
        var context = "## Thread: \(thread.name)\n"
        context += "Status: \(thread.status) \(thread.statusEmoji) | Notes: \(thread.noteCount)\n"

        if let why = thread.why, !why.isEmpty {
            context += "Why: \(why)\n"
        }

        context += "\n## Relevant Context\n\n"

        var seen = Set<Int64>()
        for item in chunks {
            guard !seen.contains(item.chunk.id) else { continue }
            seen.insert(item.chunk.id)

            if let topic = item.chunk.topic {
                context += "**[\(topic)]**\n"
            }
            context += "\(item.chunk.content)\n\n"
        }

        return context
    }

    // MARK: - What's Next

    /// Patterns that indicate a "what's next" query
    private let whatsNextPatterns: [String] = [
        "what's next",
        "whats next",
        "what should i do",
        "what should i work on",
        "what do i do",
        "what to do next",
        "what now",
        "next step",
        "next steps",
    ]

    /// Detect if a query is asking "what's next"
    public func isWhatsNextQuery(_ query: String) -> Bool {
        let lowered = query.lowercased()
            .replacingOccurrences(of: "?", with: "")
            .trimmingCharacters(in: .whitespaces)
        return whatsNextPatterns.contains { lowered.contains($0) }
    }

    // MARK: - Planning Intent Detection

    /// Patterns that indicate a planning/help intent (broader than "what's next")
    private let planningPatterns: [String] = [
        "help me", "can you help",
        "make a plan", "create a plan", "come up with a plan",
        "help me plan", "build a plan",
        "break this down", "break it down",
        "lay out the steps", "map this out", "map out",
        "how should i approach", "how do i tackle",
        "where do i start", "where should i start",
        "what are my options", "decide between", "help me decide",
        "what should i do about", "which should i",
        "think through", "work through", "figure out",
        "think about this", "reason through",
        "prioritize", "what matters most", "most important",
        "next move", "what to tackle",
    ]

    /// Detect if a query has planning/help intent (distinct from "what's next").
    public func isPlanningQuery(_ query: String) -> Bool {
        let lowered = query.lowercased()
            .replacingOccurrences(of: "?", with: "")
            .trimmingCharacters(in: .whitespaces)
        return planningPatterns.contains { lowered.contains($0) }
    }

    /// Build a planning-specific prompt that coaches multi-turn clarifying dialogue.
    /// Used when `isPlanningQuery` returns true.
    public func buildPlanningPrompt(
        thread: Thread,
        notes: [Note],
        tasks: [ThreadTask],
        userQuery: String
    ) -> String {
        let threadContext = contextBuilder.buildDeepDiveContext(thread: thread, notes: notes)
        let taskContext = buildTaskContext(tasks)

        return """
        You are an interactive thinking partner for someone with ADHD, helping them plan their next steps on "\(thread.name)".

        \(threadContext)

        \(taskContext)

        ## User's Request
        \(userQuery)

        INSTRUCTIONS:
        Start by asking 1-2 short clarifying questions about the user's priorities, constraints, or what success looks like. Do NOT jump to a full plan yet.

        After the user answers, you will:
        1. Identify 2-3 possible directions with trade-offs
        2. Ask which resonates
        3. Break the chosen direction into concrete steps
        4. Suggest creating tasks in Things using action markers:
           [ACTION: Brief description | ENERGY: high/medium/low | TIMEFRAME: today/this-week/someday]

        CAPABILITIES:
        - You can create tasks in Things (the user's task manager) via action markers
        - You have the user's full note history and existing tasks for this thread

        Keep your questions specific to the thread context. Do not ask generic questions.
        """
    }

    /// Build a specialized prompt for "what's next" recommendations
    public func buildWhatsNextPrompt(thread: Thread, notes: [Note], tasks: [ThreadTask]) -> String {
        let threadContext = contextBuilder.buildDeepDiveContext(thread: thread, notes: notes)
        let openTasks = tasks.filter { !$0.isCompleted }
        let completedTasks = tasks.filter { $0.isCompleted }

        var taskList = ""
        if !openTasks.isEmpty {
            taskList += "Open tasks:\n"
            for task in openTasks {
                let title = task.title ?? task.thingsTaskId
                let age = Calendar.current.dateComponents([.day], from: task.createdAt, to: Date()).day ?? 0
                taskList += "- \(title) (created \(age) days ago)\n"
            }
        }
        if !completedTasks.isEmpty {
            taskList += "\nRecently completed:\n"
            for task in completedTasks.prefix(5) {
                let title = task.title ?? task.thingsTaskId
                taskList += "- \(title) (done)\n"
            }
        }

        return """
        You are an interactive thinking partner for someone with ADHD, helping them decide what to work on next in their "\(thread.name)" thread.

        \(threadContext)

        ## Task State
        \(taskList.isEmpty ? "No tasks linked to this thread yet." : taskList)

        Based on the thread context, open tasks, and what's been completed:

        1. Propose 2-3 possible directions to go next, each with a brief trade-off (energy required, impact, dependencies)
        2. Ask which resonates with the user right now
        3. Do NOT pick for them — present options and let them choose

        If there are no open tasks, suggest what the logical next actions would be based on the thread's current state.

        CAPABILITY: You can create tasks in Things using action markers after the user picks a direction:
        [ACTION: Brief description | ENERGY: high/medium/low | TIMEFRAME: today/this-week/someday]
        """
    }
}
