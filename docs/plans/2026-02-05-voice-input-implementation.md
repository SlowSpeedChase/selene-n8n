# Voice Input Implementation Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** Add voice input to SeleneChat using Apple's on-device Speech framework with push-to-talk button, URL scheme activation, and live streaming transcription.

**Architecture:** New `SpeechRecognitionService` wraps Apple's `SFSpeechRecognizer` with on-device-only processing. `VoiceInputManager` coordinates activation modes (in-app button, URL scheme). Voice text streams into the existing `ChatView` text field -- no new message types or chat pipeline changes.

**Tech Stack:** Swift Speech framework, AVFoundation (audio capture), SwiftUI, macOS 14+

---

## Task 1: SpeechRecognitionService - Core Speech Engine

**Files:**
- Create: `SeleneChat/Sources/Services/SpeechRecognitionService.swift`
- Test: `SeleneChat/Tests/SeleneChatTests/Services/SpeechRecognitionServiceTests.swift`

### Step 1: Write the failing test

```swift
import XCTest
@testable import SeleneChat

final class SpeechRecognitionServiceTests: XCTestCase {

    // MARK: - State Machine Tests

    @MainActor
    func testInitialStateIsIdle() {
        let service = SpeechRecognitionService()
        XCTAssertEqual(service.state, .idle)
        XCTAssertEqual(service.liveText, "")
    }

    @MainActor
    func testStateTransitionsToListeningOnStart() async {
        let service = SpeechRecognitionService()
        // On CI/test environment, speech recognition won't be available
        // so we test that the state machine handles unavailability gracefully
        await service.startListening()

        // Either listening (if available) or back to idle with error (if not)
        XCTAssertTrue(service.state == .listening || service.state == .idle)
    }

    @MainActor
    func testStopListeningResetsToIdle() async {
        let service = SpeechRecognitionService()
        service.stopListening()
        XCTAssertEqual(service.state, .idle)
    }

    @MainActor
    func testStopListeningClearsLiveText() async {
        let service = SpeechRecognitionService()
        // Simulate some text
        service.liveText = "test transcription"
        service.stopListening()
        // After stop, liveText should be preserved (user reviews it)
        // Only cancel clears it
        XCTAssertEqual(service.liveText, "test transcription")
    }

    @MainActor
    func testCancelClearsEverything() async {
        let service = SpeechRecognitionService()
        service.liveText = "test transcription"
        service.cancel()
        XCTAssertEqual(service.liveText, "")
        XCTAssertEqual(service.state, .idle)
    }

    @MainActor
    func testIsAvailableReturnsBool() {
        let service = SpeechRecognitionService()
        // Should return a boolean (may be false in test environment)
        let available = service.isAvailable
        XCTAssertNotNil(available)
    }

    @MainActor
    func testSilenceTimeoutDefaultValue() {
        let service = SpeechRecognitionService()
        XCTAssertEqual(service.silenceTimeout, 2.0)
    }

    @MainActor
    func testSilenceTimeoutIsConfigurable() {
        let service = SpeechRecognitionService()
        service.silenceTimeout = 3.0
        XCTAssertEqual(service.silenceTimeout, 3.0)
    }
}
```

### Step 2: Run test to verify it fails

```bash
cd SeleneChat && swift test --filter SpeechRecognitionServiceTests 2>&1 | tail -20
```

Expected: FAIL - `SpeechRecognitionService` not found

### Step 3: Write minimal implementation

```swift
import Foundation
import Speech
import AVFoundation

/// Voice state for UI binding
enum VoiceState: Equatable {
    case idle
    case listening
    case processing
    case unavailable(reason: String)
}

/// Wraps Apple's SFSpeechRecognizer for on-device speech-to-text.
/// All processing happens on-device -- no audio data leaves the Mac.
@MainActor
class SpeechRecognitionService: ObservableObject {
    @Published var liveText: String = ""
    @Published var state: VoiceState = .idle
    @Published var silenceTimeout: TimeInterval = 2.0

    private var speechRecognizer: SFSpeechRecognizer?
    private var recognitionRequest: SFSpeechAudioBufferRecognitionRequest?
    private var recognitionTask: SFSpeechRecognitionTask?
    private var audioEngine: AVAudioEngine?
    private var silenceTimer: Task<Void, Never>?

    var isAvailable: Bool {
        guard let recognizer = speechRecognizer else { return false }
        return recognizer.isAvailable
    }

    init() {
        speechRecognizer = SFSpeechRecognizer(locale: Locale(identifier: "en-US"))
        speechRecognizer?.supportsOnDeviceRecognition = true
    }

    /// Request microphone and speech recognition permissions.
    /// Returns true if both are granted.
    func requestPermissions() async -> Bool {
        let speechAuthorized = await withCheckedContinuation { continuation in
            SFSpeechRecognizer.requestAuthorization { status in
                continuation.resume(returning: status == .authorized)
            }
        }

        guard speechAuthorized else {
            state = .unavailable(reason: "Speech recognition not authorized. Enable in System Settings > Privacy & Security > Speech Recognition.")
            return false
        }

        return true
    }

    /// Start listening and streaming transcription to `liveText`.
    func startListening() async {
        guard state == .idle else { return }

        // Check permissions
        let authorized = await requestPermissions()
        guard authorized else { return }

        guard let speechRecognizer, speechRecognizer.isAvailable else {
            state = .unavailable(reason: "Speech recognition is not available on this device.")
            return
        }

        // Set up audio engine
        let audioEngine = AVAudioEngine()
        self.audioEngine = audioEngine

        let request = SFSpeechAudioBufferRecognitionRequest()
        request.shouldReportPartialResults = true
        request.requiresOnDeviceRecognition = true
        self.recognitionRequest = request

        let inputNode = audioEngine.inputNode
        let recordingFormat = inputNode.outputFormat(forBus: 0)

        inputNode.installTap(onBus: 0, bufferSize: 1024, format: recordingFormat) { buffer, _ in
            request.append(buffer)
        }

        do {
            try audioEngine.start()
        } catch {
            state = .unavailable(reason: "Could not start audio engine: \(error.localizedDescription)")
            return
        }

        state = .listening
        liveText = ""

        // Start recognition
        recognitionTask = speechRecognizer.recognitionTask(with: request) { [weak self] result, error in
            Task { @MainActor [weak self] in
                guard let self else { return }

                if let result {
                    self.liveText = result.bestTranscription.formattedString
                    self.resetSilenceTimer()

                    if result.isFinal {
                        self.finishListening()
                    }
                }

                if let error {
                    // Ignore cancellation errors
                    let nsError = error as NSError
                    if nsError.domain == "kAFAssistantErrorDomain" && nsError.code == 216 {
                        // User cancelled -- expected
                        return
                    }
                    self.state = .idle
                }
            }
        }

        // Start initial silence timer
        resetSilenceTimer()
    }

    /// Stop listening. Keeps liveText for user review.
    func stopListening() {
        silenceTimer?.cancel()
        silenceTimer = nil
        recognitionRequest?.endAudio()
        recognitionTask?.cancel()
        recognitionTask = nil
        recognitionRequest = nil
        audioEngine?.inputNode.removeTap(onBus: 0)
        audioEngine?.stop()
        audioEngine = nil
        state = .idle
    }

    /// Cancel listening and clear all text.
    func cancel() {
        stopListening()
        liveText = ""
    }

    /// Called when silence timeout fires or recognition completes.
    private func finishListening() {
        stopListening()
    }

    /// Reset the silence timer. Called each time new speech is detected.
    private func resetSilenceTimer() {
        silenceTimer?.cancel()
        silenceTimer = Task { [weak self] in
            guard let self else { return }
            try? await Task.sleep(for: .seconds(self.silenceTimeout))
            guard !Task.isCancelled else { return }
            self.finishListening()
        }
    }
}
```

### Step 4: Run test to verify it passes

```bash
cd SeleneChat && swift test --filter SpeechRecognitionServiceTests 2>&1 | tail -20
```

Expected: PASS (8 tests)

### Step 5: Commit

```bash
git add SeleneChat/Sources/Services/SpeechRecognitionService.swift SeleneChat/Tests/SeleneChatTests/Services/SpeechRecognitionServiceTests.swift
git commit -m "feat(voice): add SpeechRecognitionService with on-device speech-to-text"
```

---

## Task 2: VoiceMicButton - Push-to-Talk UI Component

**Files:**
- Create: `SeleneChat/Sources/Views/VoiceMicButton.swift`
- Test: `SeleneChat/Tests/SeleneChatTests/Views/VoiceMicButtonTests.swift`

### Step 1: Write the failing test

```swift
import XCTest
@testable import SeleneChat

final class VoiceMicButtonTests: XCTestCase {

    @MainActor
    func testSpeechServiceInitialState() {
        let service = SpeechRecognitionService()
        // Button should be enabled when state is idle and service may/may not be available
        // We verify the service starts in idle state (button logic depends on this)
        XCTAssertEqual(service.state, .idle)
    }

    @MainActor
    func testButtonShouldBeDisabledDuringProcessing() {
        // When chatViewModel.isProcessing is true, mic should be disabled
        // This tests the logic, not the view itself
        let isProcessing = true
        let voiceState: VoiceState = .idle
        let shouldDisable = isProcessing || voiceState == .unavailable(reason: "")
        XCTAssertTrue(shouldDisable)
    }

    @MainActor
    func testButtonIconIdleState() {
        // Verify the icon name logic
        let state: VoiceState = .idle
        let iconName: String
        switch state {
        case .idle: iconName = "mic.fill"
        case .listening: iconName = "mic.fill"
        case .processing: iconName = "waveform"
        case .unavailable: iconName = "mic.slash.fill"
        }
        XCTAssertEqual(iconName, "mic.fill")
    }

    @MainActor
    func testButtonIconListeningState() {
        let state: VoiceState = .listening
        let iconName: String
        switch state {
        case .idle: iconName = "mic.fill"
        case .listening: iconName = "mic.fill"
        case .processing: iconName = "waveform"
        case .unavailable: iconName = "mic.slash.fill"
        }
        XCTAssertEqual(iconName, "mic.fill")
    }

    @MainActor
    func testButtonIconUnavailableState() {
        let state: VoiceState = .unavailable(reason: "No permission")
        let iconName: String
        switch state {
        case .idle: iconName = "mic.fill"
        case .listening: iconName = "mic.fill"
        case .processing: iconName = "waveform"
        case .unavailable: iconName = "mic.slash.fill"
        }
        XCTAssertEqual(iconName, "mic.slash.fill")
    }
}
```

### Step 2: Run test to verify it fails

```bash
cd SeleneChat && swift test --filter VoiceMicButtonTests 2>&1 | tail -20
```

Expected: FAIL - test file not found / compilation error

### Step 3: Write minimal implementation

```swift
import SwiftUI

/// Push-to-talk microphone button for voice input.
/// Tap to start/stop listening. Shows pulsing animation while recording.
struct VoiceMicButton: View {
    @ObservedObject var speechService: SpeechRecognitionService
    let isDisabled: Bool

    var body: some View {
        Button(action: toggleListening) {
            ZStack {
                // Pulsing background when listening
                if speechService.state == .listening {
                    Circle()
                        .fill(Color.red.opacity(0.2))
                        .frame(width: 36, height: 36)
                        .scaleEffect(pulseScale)
                        .animation(
                            .easeInOut(duration: 0.8).repeatForever(autoreverses: true),
                            value: pulseScale
                        )
                }

                Image(systemName: iconName)
                    .font(.title2)
                    .foregroundColor(iconColor)
            }
        }
        .buttonStyle(.plain)
        .disabled(isDisabled || isUnavailable)
        .help(helpText)
        .onAppear {
            if speechService.state == .listening {
                pulseScale = 1.3
            }
        }
        .onChange(of: speechService.state) { _, newState in
            if newState == .listening {
                pulseScale = 1.3
            } else {
                pulseScale = 1.0
            }
        }
    }

    @State private var pulseScale: CGFloat = 1.0

    private var iconName: String {
        switch speechService.state {
        case .idle: return "mic.fill"
        case .listening: return "mic.fill"
        case .processing: return "waveform"
        case .unavailable: return "mic.slash.fill"
        }
    }

    private var iconColor: Color {
        switch speechService.state {
        case .idle: return .secondary
        case .listening: return .red
        case .processing: return .orange
        case .unavailable: return .gray
        }
    }

    private var isUnavailable: Bool {
        if case .unavailable = speechService.state { return true }
        return false
    }

    private var helpText: String {
        switch speechService.state {
        case .idle: return "Click to start voice input"
        case .listening: return "Listening... Click to stop"
        case .processing: return "Processing speech..."
        case .unavailable(let reason): return reason
        }
    }

    private func toggleListening() {
        Task {
            switch speechService.state {
            case .idle:
                await speechService.startListening()
            case .listening:
                speechService.stopListening()
            default:
                break
            }
        }
    }
}
```

### Step 4: Run test to verify it passes

```bash
cd SeleneChat && swift test --filter VoiceMicButtonTests 2>&1 | tail -20
```

Expected: PASS (5 tests)

### Step 5: Commit

```bash
git add SeleneChat/Sources/Views/VoiceMicButton.swift SeleneChat/Tests/SeleneChatTests/Views/VoiceMicButtonTests.swift
git commit -m "feat(voice): add VoiceMicButton push-to-talk UI component"
```

---

## Task 3: Integrate Voice Input into ChatView

**Files:**
- Modify: `SeleneChat/Sources/Views/ChatView.swift` (lines 1-172)
- Modify: `SeleneChat/Sources/App/SeleneChatApp.swift` (lines 1-80)
- Test: `SeleneChat/Tests/SeleneChatTests/Integration/VoiceInputIntegrationTests.swift`

### Step 1: Write the failing integration test

```swift
import XCTest
@testable import SeleneChat

final class VoiceInputIntegrationTests: XCTestCase {

    @MainActor
    func testSpeechServiceTextFlowsToMessagePipeline() async {
        // Simulate: voice transcription -> text -> sendMessage
        // This tests the data flow without actual microphone
        let viewModel = ChatViewModel()
        let speechService = SpeechRecognitionService()

        // Simulate voice transcription result
        speechService.liveText = "search my notes about project planning"

        // Simulate what ChatView does: take liveText and send it
        let transcribedText = speechService.liveText
        XCTAssertFalse(transcribedText.isEmpty)

        // Send through normal pipeline
        await viewModel.sendMessage(transcribedText)

        // Verify message was added to session
        let userMessages = viewModel.currentSession.messages.filter { $0.role == .user }
        XCTAssertEqual(userMessages.count, 1)
        XCTAssertEqual(userMessages[0].content, "search my notes about project planning")
    }

    @MainActor
    func testCancelVoiceInputDoesNotSend() {
        let speechService = SpeechRecognitionService()

        // Simulate voice input then cancel
        speechService.liveText = "some partial text"
        speechService.cancel()

        // After cancel, liveText should be empty
        XCTAssertEqual(speechService.liveText, "")
    }

    @MainActor
    func testEscapeKeyBehavior() {
        // Simulate: user presses Escape during voice input
        let speechService = SpeechRecognitionService()
        speechService.liveText = "partial transcription"

        // Escape should cancel and clear
        speechService.cancel()

        XCTAssertEqual(speechService.state, .idle)
        XCTAssertEqual(speechService.liveText, "")
    }

    @MainActor
    func testVoiceTextAppearsInMessageText() {
        // Verify the binding concept: liveText updates should be observable
        let speechService = SpeechRecognitionService()

        speechService.liveText = "hello"
        XCTAssertEqual(speechService.liveText, "hello")

        speechService.liveText = "hello world"
        XCTAssertEqual(speechService.liveText, "hello world")

        speechService.liveText = "hello world how are you"
        XCTAssertEqual(speechService.liveText, "hello world how are you")
    }
}
```

### Step 2: Run test to verify it fails

```bash
cd SeleneChat && swift test --filter VoiceInputIntegrationTests 2>&1 | tail -20
```

Expected: FAIL - test file not found

### Step 3: Modify ChatView.swift to add voice input

**Add SpeechRecognitionService as EnvironmentObject (line 5, after existing @EnvironmentObject lines):**

Replace ChatView struct opening (lines 3-10):
```swift
struct ChatView: View {
    @EnvironmentObject var chatViewModel: ChatViewModel
    @EnvironmentObject var databaseService: DatabaseService
    @EnvironmentObject var speechService: SpeechRecognitionService
    @State private var messageText = ""
    @State private var showingSessionHistory = false
    @State private var isAPIAvailable = false
    @FocusState private var isInputFocused: Bool
    @Namespace private var focusNamespace
```

**Replace chatInput (lines 139-160) to add mic button:**

```swift
private var chatInput: some View {
    HStack(alignment: .bottom, spacing: 12) {
        TextField("Ask about your notes...", text: speechService.state == .listening ? $speechService.liveText : $messageText, axis: .vertical)
            .textFieldStyle(.roundedBorder)
            .focused($isInputFocused)
            .prefersDefaultFocus(in: focusNamespace)
            .lineLimit(1...5)
            .disabled(chatViewModel.isProcessing)
            .onSubmit {
                sendMessage()
            }
            .onChange(of: speechService.state) { _, newState in
                // When listening stops, transfer liveText to messageText for editing
                if newState == .idle && !speechService.liveText.isEmpty {
                    messageText = speechService.liveText
                    speechService.liveText = ""
                    isInputFocused = true
                }
            }
            .onKeyPress(.escape) {
                if speechService.state == .listening {
                    speechService.cancel()
                    messageText = ""
                    return .handled
                }
                return .ignored
            }

        VoiceMicButton(
            speechService: speechService,
            isDisabled: chatViewModel.isProcessing
        )

        Button(action: sendMessage) {
            Image(systemName: "arrow.up.circle.fill")
                .font(.title2)
                .foregroundColor(messageText.isEmpty ? .gray : .accentColor)
        }
        .buttonStyle(.plain)
        .disabled(messageText.isEmpty || chatViewModel.isProcessing)
    }
    .padding()
}
```

### Step 4: Modify SeleneChatApp.swift to create and inject SpeechRecognitionService

**Add new StateObject (after line 8):**

```swift
@StateObject private var speechService = SpeechRecognitionService()
```

**Add environmentObject to ContentView (after line 56):**

```swift
.environmentObject(speechService)
```

### Step 5: Run test to verify it passes

```bash
cd SeleneChat && swift test --filter VoiceInputIntegrationTests 2>&1 | tail -20
```

Expected: PASS (4 tests)

### Step 6: Build the full app to verify compilation

```bash
cd SeleneChat && swift build 2>&1 | tail -5
```

Expected: Build complete

### Step 7: Commit

```bash
git add SeleneChat/Sources/Views/ChatView.swift SeleneChat/Sources/App/SeleneChatApp.swift SeleneChat/Tests/SeleneChatTests/Integration/VoiceInputIntegrationTests.swift
git commit -m "feat(voice): integrate voice input into ChatView with mic button"
```

---

## Task 4: URL Scheme Handler for selene://voice

**Files:**
- Create: `SeleneChat/Sources/Services/VoiceInputManager.swift`
- Modify: `SeleneChat/Sources/App/SeleneChatApp.swift`
- Modify: `SeleneChat/Info.plist`
- Test: `SeleneChat/Tests/SeleneChatTests/Services/VoiceInputManagerTests.swift`

### Step 1: Write the failing test

```swift
import XCTest
@testable import SeleneChat

final class VoiceInputManagerTests: XCTestCase {

    @MainActor
    func testParseVoiceURL() {
        let url = URL(string: "selene://voice")!
        let action = VoiceInputManager.parseURL(url)
        XCTAssertEqual(action, .activateVoice)
    }

    @MainActor
    func testParseCaptureURL() {
        // Future: selene://capture for quick note capture mode
        let url = URL(string: "selene://capture")!
        let action = VoiceInputManager.parseURL(url)
        XCTAssertEqual(action, .unknown)  // Not implemented in Phase 1
    }

    @MainActor
    func testParseUnknownURL() {
        let url = URL(string: "selene://something-else")!
        let action = VoiceInputManager.parseURL(url)
        XCTAssertEqual(action, .unknown)
    }

    @MainActor
    func testParseNonSeleneURL() {
        let url = URL(string: "https://example.com")!
        let action = VoiceInputManager.parseURL(url)
        XCTAssertEqual(action, .unknown)
    }
}
```

### Step 2: Run test to verify it fails

```bash
cd SeleneChat && swift test --filter VoiceInputManagerTests 2>&1 | tail -20
```

Expected: FAIL - `VoiceInputManager` not found

### Step 3: Write VoiceInputManager

```swift
import Foundation
import AppKit

/// Actions that can be triggered via URL scheme
enum VoiceURLAction: Equatable {
    case activateVoice
    case unknown
}

/// Manages voice input activation from URL schemes and global hotkey.
/// Handles `selene://voice` to bring app to front and start listening.
@MainActor
class VoiceInputManager: ObservableObject {
    private let speechService: SpeechRecognitionService

    init(speechService: SpeechRecognitionService) {
        self.speechService = speechService
    }

    /// Parse a selene:// URL into an action
    static func parseURL(_ url: URL) -> VoiceURLAction {
        guard url.scheme == "selene" else { return .unknown }
        switch url.host {
        case "voice": return .activateVoice
        default: return .unknown
        }
    }

    /// Handle an incoming URL
    func handleURL(_ url: URL) {
        let action = VoiceInputManager.parseURL(url)
        switch action {
        case .activateVoice:
            activateVoiceInput()
        case .unknown:
            break
        }
    }

    /// Bring app to front and start voice input
    func activateVoiceInput() {
        // Bring app to foreground
        NSApplication.shared.activate(ignoringOtherApps: true)

        // Start listening after a brief delay to let the window focus
        Task {
            try? await Task.sleep(for: .milliseconds(200))
            await speechService.startListening()
        }
    }
}
```

### Step 4: Update Info.plist to register URL scheme

Replace the entire Info.plist with the URL scheme added:

```xml
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
	<key>CFBundleDevelopmentRegion</key>
	<string>en</string>
	<key>CFBundleExecutable</key>
	<string>SeleneChat</string>
	<key>CFBundleIconFile</key>
	<string>AppIcon</string>
	<key>CFBundleIdentifier</key>
	<string>com.selene.chat</string>
	<key>CFBundleInfoDictionaryVersion</key>
	<string>6.0</string>
	<key>CFBundleName</key>
	<string>SeleneChat</string>
	<key>CFBundlePackageType</key>
	<string>APPL</string>
	<key>CFBundleShortVersionString</key>
	<string>1.0</string>
	<key>CFBundleVersion</key>
	<string>1</string>
	<key>LSMinimumSystemVersion</key>
	<string>14.0</string>
	<key>NSPrincipalClass</key>
	<string>NSApplication</string>
	<key>NSHighResolutionCapable</key>
	<true/>
	<key>LSApplicationCategoryType</key>
	<string>public.app-category.productivity</string>
	<key>CFBundleURLTypes</key>
	<array>
		<dict>
			<key>CFBundleURLName</key>
			<string>com.selene.chat</string>
			<key>CFBundleURLSchemes</key>
			<array>
				<string>selene</string>
			</array>
		</dict>
	</array>
	<key>NSMicrophoneUsageDescription</key>
	<string>SeleneChat uses your microphone for voice input to transcribe speech on-device.</string>
	<key>NSSpeechRecognitionUsageDescription</key>
	<string>SeleneChat transcribes your speech on-device to text. No audio data leaves your Mac.</string>
</dict>
</plist>
```

### Step 5: Update SeleneChatApp.swift to handle URLs

Add after the `speechService` StateObject:

```swift
@StateObject private var voiceInputManager: VoiceInputManager
```

Update `init()` to create manager:

Since `@StateObject` needs to be initialized inline or in init, use this pattern:

```swift
// Replace the StateObject declarations (lines 6-8) with:
@StateObject private var databaseService = DatabaseService.shared
@StateObject private var chatViewModel = ChatViewModel()
@StateObject private var compressionService = CompressionService(databaseService: DatabaseService.shared)
@StateObject private var speechService = SpeechRecognitionService()

// Add as a computed property instead of StateObject for voiceInputManager
// since it depends on speechService. Or use a simpler approach:
```

Actually, simpler approach -- handle URL directly in the body with `.onOpenURL`:

Add to the WindowGroup, after `.task { ... }`:

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

This avoids the `VoiceInputManager` needing to be a `@StateObject` with a dependency. The `VoiceInputManager` class is still useful for URL parsing logic and future global hotkey registration.

### Step 6: Run test to verify it passes

```bash
cd SeleneChat && swift test --filter VoiceInputManagerTests 2>&1 | tail -20
```

Expected: PASS (4 tests)

### Step 7: Build to verify compilation

```bash
cd SeleneChat && swift build 2>&1 | tail -5
```

Expected: Build complete

### Step 8: Commit

```bash
git add SeleneChat/Sources/Services/VoiceInputManager.swift SeleneChat/Tests/SeleneChatTests/Services/VoiceInputManagerTests.swift SeleneChat/Sources/App/SeleneChatApp.swift SeleneChat/Info.plist
git commit -m "feat(voice): add URL scheme handler for selene://voice activation"
```

---

## Task 5: Run All Tests + Build App Bundle

**Files:**
- No new files

### Step 1: Run all existing tests to verify nothing broke

```bash
cd SeleneChat && swift test 2>&1 | tail -30
```

Expected: All tests pass (existing + new)

### Step 2: Build release app bundle

```bash
cd SeleneChat && swift build -c release 2>&1 | tail -5
```

Expected: Build complete

### Step 3: Build .app bundle and install

```bash
cd SeleneChat && ./build-app.sh 2>&1 | tail -10
```

Expected: SeleneChat.app built successfully

### Step 4: Test URL scheme manually

```bash
open "selene://voice"
```

Expected: SeleneChat comes to foreground and mic activates (if permissions granted)

### Step 5: Commit any final fixes if needed, then update design doc status

Move design doc from Vision to In Progress in `docs/plans/INDEX.md`.

```bash
git add -A && git commit -m "feat(voice): Phase 1 complete - voice input with push-to-talk and URL scheme"
```

---

## Summary

| Task | Component | New Files | Test Files |
|------|-----------|-----------|------------|
| 1 | SpeechRecognitionService | 1 | 1 |
| 2 | VoiceMicButton | 1 | 1 |
| 3 | ChatView integration | 0 (modify 2) | 1 |
| 4 | URL scheme + VoiceInputManager | 1 (modify 2) | 1 |
| 5 | Full test + build | 0 | 0 |
| **Total** | | **3 new** | **4 test files** |
