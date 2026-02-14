import SeleneShared
import Foundation

/// Builds prompts for thread workspace chat conversations.
/// Similar to DeepDivePromptBuilder but includes task state context.
class ThreadWorkspacePromptBuilder {

    private let contextBuilder = ThinkingPartnerContextBuilder()

    // MARK: - Action Marker Format

    private let actionMarkerFormat = """
    Only use action markers when the user asks for task breakdown, next steps, or actionable items. When you do, use this format:
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
        You are a thinking partner for someone with ADHD, grounded in the context of their "\(thread.name)" thread.

        \(threadContext)

        \(taskContext)

        Respond naturally to whatever the user asks. Use the thread context and notes above to give informed, specific answers. You can help with planning, brainstorming, answering questions, giving advice, or anything else related to this thread.

        \(actionMarkerFormat)

        Keep your response under 200 words. Be direct and specific.
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
        You are a thinking partner for someone with ADHD, continuing a conversation about "\(thread.name)".

        \(threadContext)

        \(taskContext)

        ## Conversation So Far
        \(conversationHistory)

        ## Current Question
        \(currentQuery)

        Respond naturally to the user's question. Use the thread context to give informed, specific answers.

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
