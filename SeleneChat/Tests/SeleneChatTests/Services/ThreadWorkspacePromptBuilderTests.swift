import XCTest
@testable import SeleneChat

final class ThreadWorkspacePromptBuilderTests: XCTestCase {

    // MARK: - Initial Prompt Tests

    func testBuildInitialPromptIncludesThreadContext() {
        let thread = Thread.mock(
            name: "Voice Input Feature",
            why: "Reduce friction for captures",
            summary: "Phase 1 push-to-talk complete"
        )

        let notes = [
            Note.mock(id: 1, title: "Speech recognition research", content: "Explored SFSpeechRecognizer API."),
            Note.mock(id: 2, title: "UX for voice", content: "Push-to-talk feels more natural than always-on.")
        ]

        let tasks = [
            ThreadTask.mock(thingsTaskId: "VOICE-001", title: "Add global hotkey"),
            ThreadTask.mock(thingsTaskId: "VOICE-002", title: "Test on external mic", completedAt: Date())
        ]

        let builder = ThreadWorkspacePromptBuilder()
        let prompt = builder.buildInitialPrompt(thread: thread, notes: notes, tasks: tasks)

        // Should include thread name
        XCTAssertTrue(prompt.contains("Voice Input Feature"), "Prompt should include thread name")

        // Should include note content
        XCTAssertTrue(prompt.contains("Speech recognition research"), "Prompt should include note titles")
        XCTAssertTrue(prompt.contains("SFSpeechRecognizer"), "Prompt should include note content")
    }

    func testBuildInitialPromptIncludesTaskState() {
        let thread = Thread.mock(name: "Test Thread")
        let notes = [Note.mock()]

        let openTask = ThreadTask.mock(thingsTaskId: "T-001", title: "Open task")
        let doneTask = ThreadTask.mock(thingsTaskId: "T-002", title: "Done task", completedAt: Date())
        let tasks = [openTask, doneTask]

        let builder = ThreadWorkspacePromptBuilder()
        let prompt = builder.buildInitialPrompt(thread: thread, notes: notes, tasks: tasks)

        // Should include task summary
        XCTAssertTrue(prompt.contains("1 open"), "Prompt should mention open task count")
        XCTAssertTrue(prompt.contains("1 completed"), "Prompt should mention completed task count")
    }

    func testBuildInitialPromptIncludesTaskTitles() {
        let thread = Thread.mock(name: "Test Thread")
        let notes = [Note.mock()]

        let tasks = [
            ThreadTask.mock(thingsTaskId: "T-001", title: "Research API options"),
            ThreadTask.mock(thingsTaskId: "T-002", title: "Write integration test")
        ]

        let builder = ThreadWorkspacePromptBuilder()
        let prompt = builder.buildInitialPrompt(thread: thread, notes: notes, tasks: tasks)

        XCTAssertTrue(prompt.contains("Research API options"), "Prompt should include task titles")
        XCTAssertTrue(prompt.contains("Write integration test"), "Prompt should include task titles")
    }

    func testBuildInitialPromptIncludesADHDFraming() {
        let thread = Thread.mock(name: "Test Thread")
        let builder = ThreadWorkspacePromptBuilder()
        let prompt = builder.buildInitialPrompt(thread: thread, notes: [Note.mock()], tasks: [])

        XCTAssertTrue(prompt.lowercased().contains("adhd"), "Prompt should mention ADHD")
        XCTAssertTrue(prompt.lowercased().contains("thinking partner"), "Prompt should include thinking partner framing")
    }

    func testBuildInitialPromptIncludesActionMarkers() {
        let thread = Thread.mock(name: "Test Thread")
        let builder = ThreadWorkspacePromptBuilder()
        let prompt = builder.buildInitialPrompt(thread: thread, notes: [Note.mock()], tasks: [])

        XCTAssertTrue(prompt.contains("[ACTION:"), "Prompt should include action marker format")
        XCTAssertTrue(prompt.contains("ENERGY:"), "Prompt should include energy level")
        XCTAssertTrue(prompt.contains("TIMEFRAME:"), "Prompt should include timeframe")
    }

    func testBuildInitialPromptWithNoTasks() {
        let thread = Thread.mock(name: "Fresh Thread")
        let builder = ThreadWorkspacePromptBuilder()
        let prompt = builder.buildInitialPrompt(thread: thread, notes: [Note.mock()], tasks: [])

        XCTAssertTrue(prompt.contains("No tasks"), "Prompt should indicate no tasks exist yet")
    }

    // MARK: - Follow-Up Prompt Tests

    func testBuildFollowUpPromptIncludesConversationHistory() {
        let thread = Thread.mock(name: "Test Thread")
        let conversationHistory = """
        User: What should I focus on next?
        Assistant: Based on your notes, the API integration seems most urgent.
        """

        let builder = ThreadWorkspacePromptBuilder()
        let prompt = builder.buildFollowUpPrompt(
            thread: thread,
            notes: [Note.mock()],
            tasks: [],
            conversationHistory: conversationHistory,
            currentQuery: "Break that down into tasks"
        )

        XCTAssertTrue(prompt.contains("What should I focus on next?"), "Prompt should include conversation history")
        XCTAssertTrue(prompt.contains("API integration seems most urgent"), "Prompt should include assistant response")
    }

    func testBuildFollowUpPromptIncludesCurrentQuery() {
        let thread = Thread.mock(name: "Test Thread")
        let builder = ThreadWorkspacePromptBuilder()
        let prompt = builder.buildFollowUpPrompt(
            thread: thread,
            notes: [Note.mock()],
            tasks: [],
            conversationHistory: "User: Q\nAssistant: A",
            currentQuery: "What are the next steps?"
        )

        XCTAssertTrue(prompt.contains("What are the next steps?"), "Prompt should include current query")
    }

    func testBuildFollowUpPromptIncludesTaskState() {
        let thread = Thread.mock(name: "Test Thread")
        let tasks = [
            ThreadTask.mock(thingsTaskId: "T-001", title: "Open task"),
            ThreadTask.mock(thingsTaskId: "T-002", title: "Done task", completedAt: Date())
        ]

        let builder = ThreadWorkspacePromptBuilder()
        let prompt = builder.buildFollowUpPrompt(
            thread: thread,
            notes: [Note.mock()],
            tasks: tasks,
            conversationHistory: "User: Q\nAssistant: A",
            currentQuery: "Next?"
        )

        XCTAssertTrue(prompt.contains("1 open"), "Follow-up should include current task state")
    }

    func testBuildFollowUpPromptIncludesActionMarkers() {
        let thread = Thread.mock(name: "Test Thread")
        let builder = ThreadWorkspacePromptBuilder()
        let prompt = builder.buildFollowUpPrompt(
            thread: thread,
            notes: [Note.mock()],
            tasks: [],
            conversationHistory: "User: Q\nAssistant: A",
            currentQuery: "Next?"
        )

        XCTAssertTrue(prompt.contains("[ACTION:"), "Follow-up prompt should include action marker format")
    }

    func testActionMarkersAreConditional() {
        let thread = Thread.mock(name: "Test Thread")
        let builder = ThreadWorkspacePromptBuilder()
        let prompt = builder.buildInitialPrompt(thread: thread, notes: [Note.mock()], tasks: [])

        XCTAssertTrue(prompt.contains("Only use action markers"), "Action markers should be conditional, not always applied")
    }

    func testFollowUpActionMarkersAreConditional() {
        let thread = Thread.mock(name: "Test Thread")
        let builder = ThreadWorkspacePromptBuilder()
        let prompt = builder.buildFollowUpPrompt(
            thread: thread,
            notes: [Note.mock()],
            tasks: [],
            conversationHistory: "User: Q\nAssistant: A",
            currentQuery: "Next?"
        )

        XCTAssertTrue(prompt.contains("Only use action markers"), "Follow-up action markers should be conditional")
    }

    func testBuildFollowUpPromptIncludesThreadContext() {
        let thread = Thread.mock(name: "Architecture Decisions")
        let builder = ThreadWorkspacePromptBuilder()
        let prompt = builder.buildFollowUpPrompt(
            thread: thread,
            notes: [Note.mock()],
            tasks: [],
            conversationHistory: "User: Q\nAssistant: A",
            currentQuery: "Next?"
        )

        XCTAssertTrue(prompt.contains("Architecture Decisions"), "Follow-up should include thread name")
    }
}
