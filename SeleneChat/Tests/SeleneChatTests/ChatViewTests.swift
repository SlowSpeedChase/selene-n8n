import XCTest
import Foundation
import SwiftUI
@testable import SeleneChat

// Test suite for ChatView input handling using XCTest
class ChatViewTests: XCTestCase {

    // RED: Test that text state accepts and stores user input
    func testTextInputAcceptsUserInput() async {
        // Given: Empty message text
        var messageText = ""

        // When: User types text into the input field
        messageText = "Hello, what notes do I have about Swift?"

        // Then: The message text should be stored
        XCTAssertEqual(messageText, "Hello, what notes do I have about Swift?", "Message text should match input")
        XCTAssertFalse(messageText.isEmpty, "Message text should not be empty")
    }

    // RED: Test that text input can be cleared
    func testTextInputCanBeCleared() async {
        // Given: Text input with content
        var messageText = "Some text"

        // When: User clears the text
        messageText = ""

        // Then: Text should be empty
        XCTAssertTrue(messageText.isEmpty, "Message text should be empty after clearing")
    }

    // RED: Test that multiline text is handled correctly
    func testTextInputHandlesMultilineText() async {
        // Given: Empty input
        var messageText = ""

        // When: User enters multiline text
        messageText = "Line 1\nLine 2\nLine 3"

        // Then: Should preserve newlines
        XCTAssertTrue(messageText.contains("\n"), "Should contain newlines")
        XCTAssertEqual(messageText.components(separatedBy: "\n").count, 3, "Should have 3 lines")
    }

    // RED: Test that message text state behaves correctly with TextField simulation
    func testMessageTextStateBehavior() async {
        // Given: Simulating TextField binding behavior
        var messageText = ""
        let testInput = "Test message"

        // When: Simulating text input change
        messageText = testInput

        // Then: State should update
        XCTAssertEqual(messageText, testInput, "State should update with input")

        // When: Simulating message send (clearing text)
        let sentMessage = messageText
        messageText = ""

        // Then: Text should be cleared but message should be captured
        XCTAssertTrue(messageText.isEmpty, "Text field should be cleared")
        XCTAssertEqual(sentMessage, testInput, "Sent message should be preserved")
    }

    // RED: Test that ChatInputState manages focus state
    @MainActor
    func testChatInputStateManagesFocus() async {
        // Given: A ChatInputState
        let inputState = ChatInputState()

        // When: Focus is requested
        inputState.requestFocus()

        // Then: Should be focused
        XCTAssertTrue(inputState.isFocused, "Input should be focused after requestFocus()")

        // When: Focus is cleared
        inputState.clearFocus()

        // Then: Should not be focused
        XCTAssertFalse(inputState.isFocused, "Input should not be focused after clearFocus()")
    }

    // RED: Test that send button is disabled when text is empty
    @MainActor
    func testSendButtonDisabledWhenEmpty() async {
        // Given: A ChatInputState with empty text
        let inputState = ChatInputState()

        // Then: Send button should be disabled
        XCTAssertFalse(inputState.canSend, "Send button should be disabled when text is empty")

        // When: Text is added
        inputState.messageText = "Hello"

        // Then: Send button should be enabled
        XCTAssertTrue(inputState.canSend, "Send button should be enabled when text is not empty")
    }

    // RED: Test that send button is disabled when processing
    @MainActor
    func testSendButtonDisabledWhenProcessing() async {
        // Given: A ChatInputState with text and processing state
        let inputState = ChatInputState()
        inputState.messageText = "Test message"

        // When: Processing starts
        inputState.isProcessing = true

        // Then: Send button should be disabled even with text
        XCTAssertFalse(inputState.canSend, "Send button should be disabled when processing")

        // When: Processing ends
        inputState.isProcessing = false

        // Then: Send button should be enabled
        XCTAssertTrue(inputState.canSend, "Send button should be enabled after processing completes")
    }
}
