import Foundation

/// Builds prompts for thread workspace chat conversations.
/// Similar to DeepDivePromptBuilder but includes task state context.
class ThreadWorkspacePromptBuilder {

    private let contextBuilder = ThinkingPartnerContextBuilder()

    // MARK: - Action Marker Format

    private let actionMarkerFormat = """
    When suggesting actions, use this format:
    [ACTION: Brief action description | ENERGY: high/medium/low | TIMEFRAME: today/this-week/someday]
    """

    // MARK: - Initial Prompt

    /// Build the initial prompt for a workspace chat session.
    /// - Parameters:
    ///   - thread: The thread being worked on
    ///   - notes: Notes belonging to this thread
    ///   - tasks: Current tasks linked to this thread
    /// - Returns: A formatted prompt string for the LLM
    func buildInitialPrompt(thread: Thread, notes: [Note], tasks: [ThreadTask]) -> String {
        let threadContext = contextBuilder.buildDeepDiveContext(thread: thread, notes: notes)
        let taskContext = buildTaskContext(tasks)

        return """
        You are a thinking partner for someone with ADHD, helping them plan and break down work for "\(thread.name)".

        \(threadContext)

        \(taskContext)

        Your task:
        1. Understand what's already been explored in the notes
        2. Consider what tasks already exist and what gaps remain
        3. Help break down next steps into concrete, actionable tasks
        4. Ask 1-2 clarifying questions if the direction isn't clear

        \(actionMarkerFormat)

        Keep your response under 200 words. Focus on actionable next steps, not summary.
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
    func buildFollowUpPrompt(
        thread: Thread,
        notes: [Note],
        tasks: [ThreadTask],
        conversationHistory: String,
        currentQuery: String
    ) -> String {
        let threadContext = contextBuilder.buildDeepDiveContext(thread: thread, notes: notes)
        let taskContext = buildTaskContext(tasks)

        return """
        You are a thinking partner for someone with ADHD, continuing a planning session for "\(thread.name)".

        \(threadContext)

        \(taskContext)

        ## Conversation So Far
        \(conversationHistory)

        ## Current Question
        \(currentQuery)

        \(actionMarkerFormat)

        Keep your response under 150 words. Be direct and specific.
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
}
