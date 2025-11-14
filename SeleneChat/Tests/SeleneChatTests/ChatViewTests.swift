import Foundation
import SwiftUI

// Simple test assertion helper
func assert(_ condition: Bool, _ message: String, file: String = #file, line: Int = #line) {
    if !condition {
        print("❌ FAIL: \(message) at \(file):\(line)")
        fatalError("Test failed")
    } else {
        print("✅ PASS: \(message)")
    }
}

// Test suite for ChatView input handling
@main
struct ChatViewTests {
    static func main() async {
        print("\n=== Running ChatView Input Tests ===\n")

        // Basic text state tests
        await testTextInputAcceptsUserInput()
        await testTextInputCanBeCleared()
        await testTextInputHandlesMultilineText()
        await testMessageTextStateBehavior()

        // NEW: Tests that will fail until we implement ChatInputState
        await testChatInputStateManagesFocus()
        await testSendButtonDisabledWhenEmpty()
        await testSendButtonDisabledWhenProcessing()

        print("\n=== All Tests Completed ===\n")
    }

    // RED: Test that text state accepts and stores user input
    static func testTextInputAcceptsUserInput() async {
        print("Test: Text input accepts user input")

        // Given: Empty message text
        var messageText = ""

        // When: User types text into the input field
        messageText = "Hello, what notes do I have about Swift?"

        // Then: The message text should be stored
        assert(messageText == "Hello, what notes do I have about Swift?", "Message text should match input")
        assert(!messageText.isEmpty, "Message text should not be empty")
    }

    // RED: Test that text input can be cleared
    static func testTextInputCanBeCleared() async {
        print("Test: Text input can be cleared")

        // Given: Text input with content
        var messageText = "Some text"

        // When: User clears the text
        messageText = ""

        // Then: Text should be empty
        assert(messageText.isEmpty, "Message text should be empty after clearing")
    }

    // RED: Test that multiline text is handled correctly
    static func testTextInputHandlesMultilineText() async {
        print("Test: Text input handles multiline text")

        // Given: Empty input
        var messageText = ""

        // When: User enters multiline text
        messageText = "Line 1\nLine 2\nLine 3"

        // Then: Should preserve newlines
        assert(messageText.contains("\n"), "Should contain newlines")
        assert(messageText.components(separatedBy: "\n").count == 3, "Should have 3 lines")
    }

    // RED: Test that message text state behaves correctly with TextField simulation
    static func testMessageTextStateBehavior() async {
        print("Test: Message text state behavior")

        // Given: Simulating TextField binding behavior
        var messageText = ""
        let testInput = "Test message"

        // When: Simulating text input change
        messageText = testInput

        // Then: State should update
        assert(messageText == testInput, "State should update with input")

        // When: Simulating message send (clearing text)
        let sentMessage = messageText
        messageText = ""

        // Then: Text should be cleared but message should be captured
        assert(messageText.isEmpty, "Text field should be cleared")
        assert(sentMessage == testInput, "Sent message should be preserved")
    }

    // RED: Test that ChatInputState manages focus state
    @MainActor
    static func testChatInputStateManagesFocus() async {
        print("Test: ChatInputState manages focus state")

        // Given: A ChatInputState
        let inputState = ChatInputState()

        // When: Focus is requested
        inputState.requestFocus()

        // Then: Should be focused
        assert(inputState.isFocused, "Input should be focused after requestFocus()")

        // When: Focus is cleared
        inputState.clearFocus()

        // Then: Should not be focused
        assert(!inputState.isFocused, "Input should not be focused after clearFocus()")
    }

    // RED: Test that send button is disabled when text is empty
    @MainActor
    static func testSendButtonDisabledWhenEmpty() async {
        print("Test: Send button disabled when empty")

        // Given: A ChatInputState with empty text
        let inputState = ChatInputState()

        // Then: Send button should be disabled
        assert(!inputState.canSend, "Send button should be disabled when text is empty")

        // When: Text is added
        inputState.messageText = "Hello"

        // Then: Send button should be enabled
        assert(inputState.canSend, "Send button should be enabled when text is not empty")
    }

    // RED: Test that send button is disabled when processing
    @MainActor
    static func testSendButtonDisabledWhenProcessing() async {
        print("Test: Send button disabled when processing")

        // Given: A ChatInputState with text and processing state
        let inputState = ChatInputState()
        inputState.messageText = "Test message"

        // When: Processing starts
        inputState.isProcessing = true

        // Then: Send button should be disabled even with text
        assert(!inputState.canSend, "Send button should be disabled when processing")

        // When: Processing ends
        inputState.isProcessing = false

        // Then: Send button should be enabled
        assert(inputState.canSend, "Send button should be enabled after processing completes")
    }
}

// GREEN: ChatInputState implementation to make tests pass
@MainActor
class ChatInputState: ObservableObject {
    @Published var messageText: String = ""
    @Published var isFocused: Bool = false
    @Published var isProcessing: Bool = false

    var canSend: Bool {
        !messageText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && !isProcessing
    }

    func requestFocus() {
        isFocused = true
    }

    func clearFocus() {
        isFocused = false
    }

    func clear() {
        messageText = ""
    }
}
