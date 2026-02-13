# Voice Conversation Mode Implementation Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** When a message originates from voice input, Selene speaks the response aloud via macOS TTS.

**Architecture:** New `SpeechSynthesisService` wraps `AVSpeechSynthesizer`. A `voiceOriginated` flag on `Message` tracks input method. `ChatViewModel` triggers TTS after creating assistant messages when the user message was voice-originated. Protocol-based injection for testability.

**Tech Stack:** Swift 5.9, AVFoundation (AVSpeechSynthesizer), SwiftUI, XCTest

---

### Task 1: SpeechSynthesizing Protocol + Text Cleaning

**Files:**
- Create: `SeleneChat/Sources/Services/SpeechSynthesisService.swift`
- Test: `SeleneChat/Tests/SeleneChatTests/Services/SpeechSynthesisServiceTests.swift`

**Step 1: Write the failing tests for text cleaning**

```swift
import XCTest
@testable import SeleneChat

final class SpeechSynthesisServiceTests: XCTestCase {

    // MARK: - Text Cleaning

    @MainActor
    func testStripsBoldMarkdown() {
        let service = SpeechSynthesisService()
        let cleaned = service.cleanTextForSpeech("This is **bold** text")
        XCTAssertEqual(cleaned, "This is bold text")
    }

    @MainActor
    func testStripsItalicMarkdown() {
        let service = SpeechSynthesisService()
        let cleaned = service.cleanTextForSpeech("This is _italic_ text")
        XCTAssertEqual(cleaned, "This is italic text")
    }

    @MainActor
    func testStripsCitationMarkers() {
        let service = SpeechSynthesisService()
        let cleaned = service.cleanTextForSpeech("As mentioned [1] and also [2]")
        XCTAssertEqual(cleaned, "As mentioned and also")
    }

    @MainActor
    func testStripsNoteStyleCitations() {
        let service = SpeechSynthesisService()
        let cleaned = service.cleanTextForSpeech("You wrote about this [Note: 'Morning Routine' - Nov 14]")
        XCTAssertEqual(cleaned, "You wrote about this")
    }

    @MainActor
    func testStripsCodeBlocks() {
        let service = SpeechSynthesisService()
        let cleaned = service.cleanTextForSpeech("Here is code:\n```swift\nlet x = 1\n```\nAnd more text")
        XCTAssertEqual(cleaned, "Here is code:\n\nAnd more text")
    }

    @MainActor
    func testStripsInlineCode() {
        let service = SpeechSynthesisService()
        let cleaned = service.cleanTextForSpeech("Use the `print` function")
        XCTAssertEqual(cleaned, "Use the print function")
    }

    @MainActor
    func testStripsURLs() {
        let service = SpeechSynthesisService()
        let cleaned = service.cleanTextForSpeech("Visit https://example.com for more")
        XCTAssertEqual(cleaned, "Visit for more")
    }

    @MainActor
    func testStripsBulletMarkers() {
        let service = SpeechSynthesisService()
        let cleaned = service.cleanTextForSpeech("- First item\n- Second item")
        XCTAssertEqual(cleaned, "First item\nSecond item")
    }

    @MainActor
    func testStripsNumberedListMarkers() {
        let service = SpeechSynthesisService()
        let cleaned = service.cleanTextForSpeech("1. First\n2. Second")
        XCTAssertEqual(cleaned, "First\nSecond")
    }

    @MainActor
    func testStripsHeadingMarkers() {
        let service = SpeechSynthesisService()
        let cleaned = service.cleanTextForSpeech("## Active Threads\n\nHere are your threads")
        XCTAssertEqual(cleaned, "Active Threads\n\nHere are your threads")
    }

    @MainActor
    func testCollapsesExtraWhitespace() {
        let service = SpeechSynthesisService()
        let cleaned = service.cleanTextForSpeech("word   word")
        XCTAssertEqual(cleaned, "word word")
    }

    @MainActor
    func testCombinedMarkdownStripping() {
        let service = SpeechSynthesisService()
        let cleaned = service.cleanTextForSpeech("**Active Threads** [1]\n\n- _First item_\n- Second [2]")
        XCTAssertEqual(cleaned, "Active Threads\n\nFirst item\nSecond")
    }
}
```

**Step 2: Run tests to verify they fail**

Run: `cd SeleneChat && swift test --filter SpeechSynthesisServiceTests 2>&1 | tail -5`
Expected: Compilation error — SpeechSynthesisService doesn't exist yet.

**Step 3: Write the protocol and service with text cleaning**

```swift
import Foundation
import AVFoundation

/// Protocol for text-to-speech, enabling test injection.
@MainActor
protocol SpeechSynthesizing: AnyObject {
    var isSpeaking: Bool { get }
    func speak(text: String)
    func stop()
}

/// Wraps AVSpeechSynthesizer for on-device text-to-speech.
/// Uses system-configured voice from System Settings > Accessibility > Spoken Content.
@MainActor
class SpeechSynthesisService: NSObject, ObservableObject, SpeechSynthesizing {
    @Published var isSpeaking: Bool = false

    private let synthesizer = AVSpeechSynthesizer()

    override init() {
        super.init()
        synthesizer.delegate = self
    }

    func speak(text: String) {
        // Stop any in-progress speech first
        if synthesizer.isSpeaking {
            synthesizer.stopSpeaking(at: .immediate)
        }

        let cleaned = cleanTextForSpeech(text)
        guard !cleaned.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return }

        let utterance = AVSpeechUtterance(string: cleaned)
        utterance.rate = AVSpeechUtteranceDefaultSpeechRate
        utterance.pitchMultiplier = 1.0
        utterance.volume = 1.0

        isSpeaking = true
        synthesizer.speak(utterance)
    }

    func stop() {
        synthesizer.stopSpeaking(at: .immediate)
        isSpeaking = false
    }

    /// Strip markdown, citations, code blocks, and URLs for natural speech.
    func cleanTextForSpeech(_ text: String) -> String {
        var result = text

        // Remove code blocks (```...```)
        result = result.replacingOccurrences(
            of: "```[\\s\\S]*?```",
            with: "",
            options: .regularExpression
        )

        // Remove inline code (`...`)
        result = result.replacingOccurrences(
            of: "`([^`]+)`",
            with: "$1",
            options: .regularExpression
        )

        // Remove Note-style citations [Note: 'Title' - Date]
        result = result.replacingOccurrences(
            of: "\\[Note:[^\\]]*\\]",
            with: "",
            options: .regularExpression
        )

        // Remove numeric citations [1], [2], etc.
        result = result.replacingOccurrences(
            of: "\\[\\d+\\]",
            with: "",
            options: .regularExpression
        )

        // Remove URLs
        result = result.replacingOccurrences(
            of: "https?://\\S+",
            with: "",
            options: .regularExpression
        )

        // Remove heading markers (## ...)
        result = result.replacingOccurrences(
            of: "(?m)^#{1,6}\\s+",
            with: "",
            options: .regularExpression
        )

        // Remove bold (**text** or __text__)
        result = result.replacingOccurrences(
            of: "\\*\\*([^*]+)\\*\\*",
            with: "$1",
            options: .regularExpression
        )
        result = result.replacingOccurrences(
            of: "__([^_]+)__",
            with: "$1",
            options: .regularExpression
        )

        // Remove italic (_text_ or *text*) — single markers
        result = result.replacingOccurrences(
            of: "(?<![\\w*])\\*([^*]+)\\*(?![\\w*])",
            with: "$1",
            options: .regularExpression
        )
        result = result.replacingOccurrences(
            of: "(?<![\\w_])_([^_]+)_(?![\\w_])",
            with: "$1",
            options: .regularExpression
        )

        // Remove bullet markers (- or * at start of line)
        result = result.replacingOccurrences(
            of: "(?m)^[\\-\\*]\\s+",
            with: "",
            options: .regularExpression
        )

        // Remove numbered list markers (1. 2. etc.)
        result = result.replacingOccurrences(
            of: "(?m)^\\d+\\.\\s+",
            with: "",
            options: .regularExpression
        )

        // Collapse multiple spaces into one
        result = result.replacingOccurrences(
            of: " {2,}",
            with: " ",
            options: .regularExpression
        )

        // Trim lines
        result = result
            .components(separatedBy: "\n")
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .joined(separator: "\n")

        // Collapse 3+ newlines to 2
        result = result.replacingOccurrences(
            of: "\n{3,}",
            with: "\n\n",
            options: .regularExpression
        )

        return result.trimmingCharacters(in: .whitespacesAndNewlines)
    }
}

// MARK: - AVSpeechSynthesizerDelegate

extension SpeechSynthesisService: AVSpeechSynthesizerDelegate {
    nonisolated func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer, didFinish utterance: AVSpeechUtterance) {
        Task { @MainActor in
            self.isSpeaking = false
        }
    }

    nonisolated func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer, didCancel utterance: AVSpeechUtterance) {
        Task { @MainActor in
            self.isSpeaking = false
        }
    }
}
```

**Step 4: Run tests to verify they pass**

Run: `cd SeleneChat && swift test --filter SpeechSynthesisServiceTests 2>&1 | tail -20`
Expected: All 13 tests PASS.

**Step 5: Commit**

```bash
cd SeleneChat && git add Sources/Services/SpeechSynthesisService.swift Tests/SeleneChatTests/Services/SpeechSynthesisServiceTests.swift
git commit -m "feat(voice): add SpeechSynthesisService with text cleaning"
```

---

### Task 2: SpeechSynthesisService State Tests

**Files:**
- Modify: `SeleneChat/Tests/SeleneChatTests/Services/SpeechSynthesisServiceTests.swift`

**Step 1: Add state management tests**

Append to the existing test file:

```swift
    // MARK: - State Management

    @MainActor
    func testInitialStateIsNotSpeaking() {
        let service = SpeechSynthesisService()
        XCTAssertFalse(service.isSpeaking)
    }

    @MainActor
    func testSpeakSetsIsSpeakingTrue() {
        let service = SpeechSynthesisService()
        service.speak(text: "Hello world")
        XCTAssertTrue(service.isSpeaking)
    }

    @MainActor
    func testStopSetsIsSpeakingFalse() {
        let service = SpeechSynthesisService()
        service.speak(text: "Hello world")
        service.stop()
        XCTAssertFalse(service.isSpeaking)
    }

    @MainActor
    func testSpeakWithEmptyTextDoesNotSetSpeaking() {
        let service = SpeechSynthesisService()
        service.speak(text: "")
        XCTAssertFalse(service.isSpeaking)
    }

    @MainActor
    func testSpeakWithOnlyMarkdownDoesNotSetSpeaking() {
        let service = SpeechSynthesisService()
        service.speak(text: "**  **")
        // After cleaning, this is empty
        XCTAssertFalse(service.isSpeaking)
    }
```

**Step 2: Run tests to verify they pass**

Run: `cd SeleneChat && swift test --filter SpeechSynthesisServiceTests 2>&1 | tail -20`
Expected: All 18 tests PASS.

**Step 3: Commit**

```bash
cd SeleneChat && git add Tests/SeleneChatTests/Services/SpeechSynthesisServiceTests.swift
git commit -m "test(voice): add SpeechSynthesisService state tests"
```

---

### Task 3: Message Model — voiceOriginated Field

**Files:**
- Modify: `SeleneChat/Sources/Models/Message.swift:4-94`
- Test: `SeleneChat/Tests/SeleneChatTests/Models/MessageTests.swift` (find or create)

**Step 1: Write failing tests**

Find existing MessageTests or create new file:

```swift
import XCTest
@testable import SeleneChat

final class MessageVoiceTests: XCTestCase {

    func testVoiceOriginatedDefaultsFalse() {
        let message = Message(role: .user, content: "hello", llmTier: .onDevice)
        XCTAssertFalse(message.voiceOriginated)
    }

    func testVoiceOriginatedCanBeSetTrue() {
        let message = Message(role: .user, content: "hello", llmTier: .onDevice, voiceOriginated: true)
        XCTAssertTrue(message.voiceOriginated)
    }

    func testVoiceOriginatedRoundTripsCodable() throws {
        let original = Message(role: .user, content: "hello", llmTier: .onDevice, voiceOriginated: true)
        let data = try JSONEncoder().encode(original)
        let decoded = try JSONDecoder().decode(Message.self, from: data)
        XCTAssertTrue(decoded.voiceOriginated)
    }

    func testVoiceOriginatedFalseRoundTripsCodable() throws {
        let original = Message(role: .user, content: "hello", llmTier: .onDevice, voiceOriginated: false)
        let data = try JSONEncoder().encode(original)
        let decoded = try JSONDecoder().decode(Message.self, from: data)
        XCTAssertFalse(decoded.voiceOriginated)
    }

    func testOldMessagesWithoutVoiceFieldDecodeSafely() throws {
        // Simulate old JSON without voiceOriginated field
        let json = """
        {"id":"00000000-0000-0000-0000-000000000000","role":"user","content":"hello","timestamp":0,"llmTier":"On-Device (Apple Intelligence)"}
        """
        let data = json.data(using: .utf8)!
        let decoded = try JSONDecoder().decode(Message.self, from: data)
        XCTAssertFalse(decoded.voiceOriginated)
    }
}
```

**Step 2: Run tests to verify they fail**

Run: `cd SeleneChat && swift test --filter MessageVoiceTests 2>&1 | tail -5`
Expected: Compilation error — `voiceOriginated` doesn't exist on Message.

**Step 3: Add voiceOriginated to Message**

In `Message.swift`, make these changes:

1. Add property after `queryType` (line 15):
```swift
var voiceOriginated: Bool
```

2. Add to init parameters (after `queryType: String? = nil`):
```swift
voiceOriginated: Bool = false
```

3. Add to init body (after `self.queryType = queryType`):
```swift
self.voiceOriginated = voiceOriginated
```

4. Add to `CodingKeys` enum:
```swift
case id, role, content, timestamp, llmTier, relatedNotes, queryType, voiceOriginated
```

5. Add custom `init(from decoder:)` for backward compatibility with old sessions that don't have the field:
```swift
init(from decoder: Decoder) throws {
    let container = try decoder.container(keyedBy: CodingKeys.self)
    id = try container.decode(UUID.self, forKey: .id)
    role = try container.decode(Role.self, forKey: .role)
    content = try container.decode(String.self, forKey: .content)
    timestamp = try container.decode(Date.self, forKey: .timestamp)
    llmTier = try container.decode(LLMTier.self, forKey: .llmTier)
    relatedNotes = try container.decodeIfPresent([Int].self, forKey: .relatedNotes)
    queryType = try container.decodeIfPresent(String.self, forKey: .queryType)
    voiceOriginated = try container.decodeIfPresent(Bool.self, forKey: .voiceOriginated) ?? false
}
```

**Step 4: Run tests to verify they pass**

Run: `cd SeleneChat && swift test --filter MessageVoiceTests 2>&1 | tail -20`
Expected: All 5 tests PASS.

**Step 5: Run full test suite to check for regressions**

Run: `cd SeleneChat && swift test 2>&1 | tail -5`
Expected: All tests pass (no regressions from adding the field with default value).

**Step 6: Commit**

```bash
cd SeleneChat && git add Sources/Models/Message.swift Tests/SeleneChatTests/Models/MessageVoiceTests.swift
git commit -m "feat(voice): add voiceOriginated field to Message model"
```

---

### Task 4: ChatView — Track Voice Origin

**Files:**
- Modify: `SeleneChat/Sources/Views/ChatView.swift:1-202`

**Step 1: Add state variable and voice tracking**

In `ChatView`, add a state variable after `isInputFocused` (line 10):

```swift
@State private var wasVoiceInput = false
```

**Step 2: Set flag when speech stops**

In the `.onChange(of: speechService.state)` handler (lines 159-166), add the voice tracking:

Change from:
```swift
.onChange(of: speechService.state) { _, newState in
    // When listening stops, transfer liveText to messageText for editing
    if newState == .idle && !speechService.liveText.isEmpty {
        messageText = speechService.liveText
        speechService.liveText = ""
        isInputFocused = true
    }
}
```

To:
```swift
.onChange(of: speechService.state) { _, newState in
    // When listening stops, transfer liveText to messageText for editing
    if newState == .idle && !speechService.liveText.isEmpty {
        messageText = speechService.liveText
        speechService.liveText = ""
        isInputFocused = true
        wasVoiceInput = true
    }
}
```

**Step 3: Pass flag in sendMessage and reset**

Change `sendMessage()` (lines 192-201) from:
```swift
private func sendMessage() {
    guard !messageText.isEmpty else { return }

    let message = messageText
    messageText = ""

    Task {
        await chatViewModel.sendMessage(message)
    }
}
```

To:
```swift
private func sendMessage() {
    guard !messageText.isEmpty else { return }

    let message = messageText
    let voiceOriginated = wasVoiceInput
    messageText = ""
    wasVoiceInput = false

    Task {
        await chatViewModel.sendMessage(message, voiceOriginated: voiceOriginated)
    }
}
```

**Step 4: Add SpeechSynthesisService environment object**

Add after the `speechService` EnvironmentObject (line 6):
```swift
@EnvironmentObject var speechSynthesisService: SpeechSynthesisService
```

**Step 5: Stop TTS when mic activated**

In the `VoiceMicButton` section, the mic button already calls `speechService.startListening()` via toggle. We need to stop TTS when the user taps mic. In the `.onChange(of: speechService.state)` handler, add a stop call when listening starts:

Change the handler to:
```swift
.onChange(of: speechService.state) { _, newState in
    if newState == .listening {
        // Stop any in-progress TTS when user starts speaking
        speechSynthesisService.stop()
    }
    // When listening stops, transfer liveText to messageText for editing
    if newState == .idle && !speechService.liveText.isEmpty {
        messageText = speechService.liveText
        speechService.liveText = ""
        isInputFocused = true
        wasVoiceInput = true
    }
}
```

**Step 6: Verify build compiles**

Run: `cd SeleneChat && swift build 2>&1 | tail -5`
Expected: Build will fail until ChatViewModel.sendMessage signature is updated (Task 5). That's OK — this task is intentionally incomplete until Task 5.

**Step 7: Commit (WIP)**

```bash
cd SeleneChat && git add Sources/Views/ChatView.swift
git commit -m "feat(voice): track voice origin in ChatView and stop TTS on mic tap"
```

---

### Task 5: ChatViewModel — Wire TTS

**Files:**
- Modify: `SeleneChat/Sources/Services/ChatViewModel.swift:1-953`

**Step 1: Add SpeechSynthesisService dependency**

Add property after `briefingContextBuilder` (line 24):
```swift
var speechSynthesisService: SpeechSynthesizing?
```

Using optional protocol type so:
- Tests don't need to provide it
- Existing code doesn't break
- Can be injected from SeleneChatApp

**Step 2: Update sendMessage signature**

Change `sendMessage` (line 36) from:
```swift
func sendMessage(_ content: String) async {
```

To:
```swift
func sendMessage(_ content: String, voiceOriginated: Bool = false) async {
```

**Step 3: Store voiceOriginated on user message**

Change the user message creation (lines 41-45) from:
```swift
let userMessage = Message(
    role: .user,
    content: content,
    llmTier: .onDevice
)
```

To:
```swift
let userMessage = Message(
    role: .user,
    content: content,
    llmTier: .onDevice,
    voiceOriginated: voiceOriginated
)
```

**Step 4: Add TTS helper method**

Add at the end of the class (before the `#if DEBUG` extension):

```swift
// MARK: - Voice Response

/// Speak the response aloud if the user's message was voice-originated.
private func speakIfVoiceOriginated(_ response: String, voiceOriginated: Bool) {
    guard voiceOriginated, let tts = speechSynthesisService else { return }
    tts.speak(text: response)
}
```

**Step 5: Wire TTS into all response paths**

There are 6 places where assistant messages are created. Add `speakIfVoiceOriginated` after each `currentSession.addMessage(assistantMessage)`:

1. **Thread query response** (after line 58):
```swift
speakIfVoiceOriginated(response, voiceOriginated: voiceOriginated)
```

2. **Synthesis query response** (after line 74):
```swift
speakIfVoiceOriginated(response, voiceOriginated: voiceOriginated)
```

3. **Deep-dive query response** (after line 93):
```swift
speakIfVoiceOriginated(response, voiceOriginated: voiceOriginated)
```

4. **Ollama (local tier) response** (after line 131):
```swift
speakIfVoiceOriginated(response, voiceOriginated: voiceOriginated)
```

5. **Non-local tier response** (after line 150):
```swift
speakIfVoiceOriginated(response, voiceOriginated: voiceOriginated)
```

6. **Error messages** (line 157-162): Do NOT add TTS — errors should be text-only per the design.

**Step 6: Verify build compiles**

Run: `cd SeleneChat && swift build 2>&1 | tail -5`
Expected: Build succeeds.

**Step 7: Commit**

```bash
cd SeleneChat && git add Sources/Services/ChatViewModel.swift
git commit -m "feat(voice): wire TTS into ChatViewModel response pipeline"
```

---

### Task 6: SeleneChatApp — Inject Service

**Files:**
- Modify: `SeleneChat/Sources/App/SeleneChatApp.swift:1-146`

**Step 1: Create StateObject**

Add after the `scheduler` StateObject (line 14):
```swift
@StateObject private var speechSynthesisService = SpeechSynthesisService()
```

**Step 2: Inject as environment object**

Add `.environmentObject(speechSynthesisService)` after the existing environment objects (after line 65):
```swift
.environmentObject(speechSynthesisService)
```

**Step 3: Wire into ChatViewModel**

In the `.task` modifier, after the scheduler enable block (around line 82), add:
```swift
chatViewModel.speechSynthesisService = speechSynthesisService
```

**Step 4: Stop TTS on voice URL scheme activation**

In the `.onOpenURL` handler (lines 110-119), add a stop call before starting listening:

Change from:
```swift
.onOpenURL { url in
    let action = VoiceInputManager.parseURL(url)
    if action == .activateVoice {
        NSApplication.shared.activate(ignoringOtherApps: true)
        Task {
            try? await Task.sleep(for: .milliseconds(200))
            await speechService.startListening()
        }
    }
}
```

To:
```swift
.onOpenURL { url in
    let action = VoiceInputManager.parseURL(url)
    if action == .activateVoice {
        speechSynthesisService.stop()
        NSApplication.shared.activate(ignoringOtherApps: true)
        Task {
            try? await Task.sleep(for: .milliseconds(200))
            await speechService.startListening()
        }
    }
}
```

**Step 5: Verify build compiles**

Run: `cd SeleneChat && swift build 2>&1 | tail -5`
Expected: Build succeeds.

**Step 6: Commit**

```bash
cd SeleneChat && git add Sources/App/SeleneChatApp.swift
git commit -m "feat(voice): inject SpeechSynthesisService into app and view model"
```

---

### Task 7: Integration Tests

**Files:**
- Create: `SeleneChat/Tests/SeleneChatTests/Integration/VoiceConversationIntegrationTests.swift`

**Step 1: Write integration tests**

```swift
import XCTest
@testable import SeleneChat

/// Mock TTS that records speak/stop calls without producing audio.
@MainActor
final class MockSpeechSynthesisService: SpeechSynthesizing {
    var isSpeaking: Bool = false
    var lastSpokenText: String?
    var speakCallCount: Int = 0
    var stopCallCount: Int = 0

    func speak(text: String) {
        lastSpokenText = text
        speakCallCount += 1
        isSpeaking = true
    }

    func stop() {
        stopCallCount += 1
        isSpeaking = false
    }
}

final class VoiceConversationIntegrationTests: XCTestCase {

    @MainActor
    func testVoiceOriginatedMessageFlaggedCorrectly() async {
        let viewModel = ChatViewModel()
        let mockTTS = MockSpeechSynthesisService()
        viewModel.speechSynthesisService = mockTTS

        // Send a voice-originated message
        // (Will fail to reach Ollama in test, but we can check the user message)
        await viewModel.sendMessage("test voice", voiceOriginated: true)

        let userMessage = viewModel.currentSession.messages.first { $0.role == .user }
        XCTAssertNotNil(userMessage)
        XCTAssertTrue(userMessage!.voiceOriginated)
    }

    @MainActor
    func testTypedMessageNotFlagged() async {
        let viewModel = ChatViewModel()
        let mockTTS = MockSpeechSynthesisService()
        viewModel.speechSynthesisService = mockTTS

        await viewModel.sendMessage("test typed", voiceOriginated: false)

        let userMessage = viewModel.currentSession.messages.first { $0.role == .user }
        XCTAssertNotNil(userMessage)
        XCTAssertFalse(userMessage!.voiceOriginated)
    }

    @MainActor
    func testTypedMessageDoesNotTriggerTTS() async {
        let viewModel = ChatViewModel()
        let mockTTS = MockSpeechSynthesisService()
        viewModel.speechSynthesisService = mockTTS

        await viewModel.sendMessage("test typed", voiceOriginated: false)

        XCTAssertEqual(mockTTS.speakCallCount, 0)
    }

    @MainActor
    func testDefaultVoiceOriginatedIsFalse() async {
        let viewModel = ChatViewModel()

        // No voiceOriginated param = defaults to false
        await viewModel.sendMessage("test default")

        let userMessage = viewModel.currentSession.messages.first { $0.role == .user }
        XCTAssertNotNil(userMessage)
        XCTAssertFalse(userMessage!.voiceOriginated)
    }

    @MainActor
    func testMockTTSStopResetsState() {
        let mockTTS = MockSpeechSynthesisService()
        mockTTS.speak(text: "hello")
        XCTAssertTrue(mockTTS.isSpeaking)
        mockTTS.stop()
        XCTAssertFalse(mockTTS.isSpeaking)
        XCTAssertEqual(mockTTS.stopCallCount, 1)
    }
}
```

**Step 2: Run tests to verify they pass**

Run: `cd SeleneChat && swift test --filter VoiceConversationIntegrationTests 2>&1 | tail -20`
Expected: All 5 tests PASS.

**Step 3: Run full test suite**

Run: `cd SeleneChat && swift test 2>&1 | tail -5`
Expected: All tests pass (270+ existing + ~23 new).

**Step 4: Commit**

```bash
cd SeleneChat && git add Tests/SeleneChatTests/Integration/VoiceConversationIntegrationTests.swift
git commit -m "test(voice): add voice conversation integration tests with mock TTS"
```

---

### Task 8: Build, Install, and Verify

**Files:** None (verification only)

**Step 1: Build the app bundle**

Run: `cd SeleneChat && ./build-app.sh 2>&1 | tail -5`
Expected: Build succeeds.

**Step 2: Install to Applications**

Run: `cp -R SeleneChat/.build/release/SeleneChat.app /Applications/`
Expected: App installs.

**Step 3: Run full test suite one final time**

Run: `cd SeleneChat && swift test 2>&1 | tail -10`
Expected: All tests pass.

**Step 4: Final commit**

Squash or create a final summary commit if needed. Otherwise, the per-task commits are sufficient.

---

### Acceptance Criteria Checklist

After all tasks complete, verify:

- [ ] Voice-originated messages trigger spoken response (Task 5 + 6)
- [ ] Typed messages do not trigger spoken response (Task 5 — default false)
- [ ] Response text displayed simultaneously with speech (Task 5 — TTS fires after addMessage)
- [ ] Tapping mic button interrupts current speech (Task 4 — onChange stops TTS)
- [ ] Markdown and citations stripped before speaking (Task 1)
- [ ] `isSpeaking` state observable (Task 1 — @Published)
- [ ] All speech processing on-device (AVSpeechSynthesizer)
- [ ] Existing voice input behavior unchanged (Task 4 — additive changes only)
- [ ] Tests pass for new service and pipeline changes (Task 7 + 8)
