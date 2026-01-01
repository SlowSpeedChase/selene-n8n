# AI Provider Toggle Implementation Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** Add ability to toggle between local LLM (Ollama) and cloud AI (Claude API) in SeleneChat's Planning tab, with local as the secure default.

**Architecture:** Unified AIProviderService routes requests to either OllamaService or ClaudeAPIService based on user preference. Global default stored in UserDefaults with per-conversation override. Visual indicators show which provider generated each message.

**Tech Stack:** Swift 5.9+, SwiftUI, UserDefaults, existing OllamaService and ClaudeAPIService

---

## Existing Code Reference

**Services (already exist):**
- `SeleneChat/Sources/Services/ClaudeAPIService.swift` - Has `isAvailable()` checking for API key
- `SeleneChat/Sources/Services/OllamaService.swift` - Has `isAvailable()` checking Ollama connection

**Views to modify:**
- `SeleneChat/Sources/Views/PlanningView.swift` - Contains PlanningConversationView (lines 171-507)

**Models:**
- `PlanningMessage` struct at line 449 in PlanningView.swift - needs provider field

---

## Task 1: Create AIProvider Enum

**Files:**
- Create: `SeleneChat/Sources/Models/AIProvider.swift`

**Step 1: Create the enum file**

```swift
// SeleneChat/Sources/Models/AIProvider.swift
import Foundation

enum AIProvider: String, Codable, CaseIterable {
    case local   // Ollama
    case cloud   // Claude API

    var displayName: String {
        switch self {
        case .local: return "Local"
        case .cloud: return "Cloud"
        }
    }

    var icon: String {
        switch self {
        case .local: return "🏠"
        case .cloud: return "☁️"
        }
    }

    var systemImage: String {
        switch self {
        case .local: return "house.fill"
        case .cloud: return "cloud.fill"
        }
    }
}
```

**Step 2: Verify it compiles**

Run: `cd SeleneChat && swift build 2>&1 | tail -5`
Expected: Build succeeded

**Step 3: Commit**

```bash
git add SeleneChat/Sources/Models/AIProvider.swift
git commit -m "feat(models): add AIProvider enum for local/cloud switching"
```

---

## Task 2: Create AIProviderService

**Files:**
- Create: `SeleneChat/Sources/Services/AIProviderService.swift`

**Step 1: Create the service file**

```swift
// SeleneChat/Sources/Services/AIProviderService.swift
import Foundation
import SwiftUI

@MainActor
class AIProviderService: ObservableObject {
    static let shared = AIProviderService()

    private let userDefaultsKey = "defaultAIProvider"

    @Published var globalDefault: AIProvider {
        didSet {
            UserDefaults.standard.set(globalDefault.rawValue, forKey: userDefaultsKey)
        }
    }

    private let ollamaService = OllamaService.shared
    private let claudeService = ClaudeAPIService.shared

    private init() {
        // Load saved preference or default to local
        if let saved = UserDefaults.standard.string(forKey: userDefaultsKey),
           let provider = AIProvider(rawValue: saved) {
            self.globalDefault = provider
        } else {
            self.globalDefault = .local
        }
    }

    // MARK: - Availability Checks

    func isCloudAvailable() async -> Bool {
        await claudeService.isAvailable()
    }

    func isLocalAvailable() async -> Bool {
        await ollamaService.isAvailable()
    }

    // MARK: - Planning Messages

    /// Send a planning message using the specified provider
    func sendPlanningMessage(
        userMessage: String,
        conversationHistory: [[String: String]],
        systemPrompt: String,
        provider: AIProvider
    ) async throws -> PlanningResponse {
        switch provider {
        case .cloud:
            return try await claudeService.sendPlanningMessage(
                userMessage: userMessage,
                conversationHistory: conversationHistory,
                systemPrompt: systemPrompt
            )
        case .local:
            return try await sendLocalPlanningMessage(
                userMessage: userMessage,
                conversationHistory: conversationHistory,
                systemPrompt: systemPrompt
            )
        }
    }

    /// Convert Ollama response to PlanningResponse format
    private func sendLocalPlanningMessage(
        userMessage: String,
        conversationHistory: [[String: String]],
        systemPrompt: String
    ) async throws -> PlanningResponse {
        // Build prompt with context
        var fullPrompt = systemPrompt + "\n\n"

        for message in conversationHistory {
            if let role = message["role"], let content = message["content"] {
                fullPrompt += "\(role.capitalized): \(content)\n\n"
            }
        }

        fullPrompt += "User: \(userMessage)\n\nAssistant:"

        let response = try await ollamaService.generate(prompt: fullPrompt)

        // Extract tasks using same pattern as ClaudeAPIService
        let extractedTasks = extractTasks(from: response)
        let cleanMessage = removeTaskMarkers(from: response)

        return PlanningResponse(
            message: response,
            extractedTasks: extractedTasks,
            cleanMessage: cleanMessage
        )
    }

    /// Extract tasks from response using [TASK: ...] markers
    private func extractTasks(from response: String) -> [ExtractedTask] {
        var tasks: [ExtractedTask] = []
        let pattern = #"\[TASK:\s*([^|]+)\s*\|\s*energy:\s*(low|medium|high)\s*\|\s*minutes:\s*(\d+)\]"#

        guard let regex = try? NSRegularExpression(pattern: pattern, options: .caseInsensitive) else {
            return tasks
        }

        let range = NSRange(response.startIndex..., in: response)
        let matches = regex.matches(in: response, options: [], range: range)

        for match in matches {
            if let titleRange = Range(match.range(at: 1), in: response),
               let energyRange = Range(match.range(at: 2), in: response),
               let minutesRange = Range(match.range(at: 3), in: response) {

                let title = String(response[titleRange]).trimmingCharacters(in: .whitespaces)
                let energy = String(response[energyRange]).lowercased()
                let minutes = Int(response[minutesRange]) ?? 30

                tasks.append(ExtractedTask(title: title, energy: energy, minutes: minutes))
            }
        }

        return tasks
    }

    /// Remove task markers from response
    private func removeTaskMarkers(from response: String) -> String {
        let pattern = #"\[TASK:[^\]]+\]"#

        guard let regex = try? NSRegularExpression(pattern: pattern, options: .caseInsensitive) else {
            return response
        }

        let range = NSRange(response.startIndex..., in: response)
        return regex.stringByReplacingMatches(
            in: response,
            options: [],
            range: range,
            withTemplate: ""
        ).trimmingCharacters(in: .whitespacesAndNewlines)
    }
}
```

**Step 2: Verify it compiles**

Run: `cd SeleneChat && swift build 2>&1 | tail -5`
Expected: Build succeeded

**Step 3: Commit**

```bash
git add SeleneChat/Sources/Services/AIProviderService.swift
git commit -m "feat(services): add AIProviderService for unified AI routing"
```

---

## Task 3: Update PlanningMessage with Provider Field

**Files:**
- Modify: `SeleneChat/Sources/Views/PlanningView.swift:449-461`

**Step 1: Update PlanningMessage struct**

Find the PlanningMessage struct (around line 449) and update it:

```swift
// MARK: - Planning Message Model

struct PlanningMessage: Identifiable {
    let id = UUID()
    let role: Role
    let content: String
    let timestamp = Date()
    let provider: AIProvider  // NEW: Track which AI generated this

    enum Role {
        case user
        case assistant
        case system
        case taskCreated
    }

    init(role: Role, content: String, provider: AIProvider = .local) {
        self.role = role
        self.content = content
        self.provider = provider
    }
}
```

**Step 2: Verify it compiles**

Run: `cd SeleneChat && swift build 2>&1 | tail -10`
Expected: Build succeeded (may have warnings about unused provider, that's OK)

**Step 3: Commit**

```bash
git add SeleneChat/Sources/Views/PlanningView.swift
git commit -m "feat(models): add provider field to PlanningMessage"
```

---

## Task 4: Create AIProviderSettings Popover View

**Files:**
- Create: `SeleneChat/Sources/Views/AIProviderSettings.swift`

**Step 1: Create the settings popover**

```swift
// SeleneChat/Sources/Views/AIProviderSettings.swift
import SwiftUI

struct AIProviderSettings: View {
    @ObservedObject var providerService: AIProviderService
    @State private var ollamaStatus: Bool?
    @State private var claudeStatus: Bool?
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            // Header
            HStack {
                Text("Planning Settings")
                    .font(.headline)
                Spacer()
                Button("Done") { dismiss() }
                    .buttonStyle(.plain)
            }

            Divider()

            // Default Provider Toggle
            VStack(alignment: .leading, spacing: 8) {
                Text("Default AI Provider")
                    .font(.subheadline)
                    .foregroundColor(.secondary)

                Picker("Provider", selection: $providerService.globalDefault) {
                    Label("Local (Ollama)", systemImage: "house.fill")
                        .tag(AIProvider.local)
                    Label("Cloud (Claude)", systemImage: "cloud.fill")
                        .tag(AIProvider.cloud)
                }
                .pickerStyle(.segmented)
            }

            Divider()

            // Provider Status
            VStack(alignment: .leading, spacing: 8) {
                Text("Provider Status")
                    .font(.subheadline)
                    .foregroundColor(.secondary)

                HStack {
                    Label("Ollama", systemImage: "house.fill")
                    Spacer()
                    statusIndicator(for: ollamaStatus, label: "Connected", errorLabel: "Offline")
                }

                HStack {
                    Label("Claude API", systemImage: "cloud.fill")
                    Spacer()
                    statusIndicator(for: claudeStatus, label: "API key configured", errorLabel: "API key not found")
                }
            }
        }
        .padding()
        .frame(width: 300)
        .task {
            await checkStatus()
        }
    }

    @ViewBuilder
    private func statusIndicator(for status: Bool?, label: String, errorLabel: String) -> some View {
        if let status = status {
            if status {
                HStack(spacing: 4) {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundColor(.green)
                    Text(label)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            } else {
                HStack(spacing: 4) {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundColor(.red)
                    Text(errorLabel)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
        } else {
            ProgressView()
                .scaleEffect(0.7)
        }
    }

    private func checkStatus() async {
        ollamaStatus = await providerService.isLocalAvailable()
        claudeStatus = await providerService.isCloudAvailable()
    }
}
```

**Step 2: Verify it compiles**

Run: `cd SeleneChat && swift build 2>&1 | tail -5`
Expected: Build succeeded

**Step 3: Commit**

```bash
git add SeleneChat/Sources/Views/AIProviderSettings.swift
git commit -m "feat(views): add AIProviderSettings popover"
```

---

## Task 5: Add Provider Toggle to Conversation Header

**Files:**
- Modify: `SeleneChat/Sources/Views/PlanningView.swift:171-265` (PlanningConversationView)

**Step 1: Add state properties for provider**

Add these new @State properties to PlanningConversationView (after line 181):

```swift
    @State private var currentProvider: AIProvider = .local
    @State private var showProviderSettings = false
    @State private var showHistoryPrompt = false
    @StateObject private var providerService = AIProviderService.shared
```

**Step 2: Update conversationHeader**

Replace the conversationHeader computed property (around line 239-265):

```swift
    private var conversationHeader: some View {
        HStack {
            Button(action: onBack) {
                Label("Back", systemImage: "chevron.left")
            }
            .buttonStyle(.plain)

            Spacer()

            // Provider toggle badge
            providerBadge

            if !tasksCreated.isEmpty {
                HStack(spacing: 4) {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundColor(.green)
                    Text("\(tasksCreated.count) tasks")
                        .font(.caption)
                }
            }

            Spacer()

            // Settings gear
            Button(action: { showProviderSettings = true }) {
                Image(systemName: "gearshape")
            }
            .buttonStyle(.plain)
            .popover(isPresented: $showProviderSettings) {
                AIProviderSettings(providerService: providerService)
            }

            Button("Complete") {
                Task { await completeThread() }
            }
            .disabled(isProcessing)
        }
        .padding()
        .alert("Switch to Cloud AI", isPresented: $showHistoryPrompt) {
            Button("Yes, send history") {
                currentProvider = .cloud
            }
            Button("No, fresh start") {
                currentProvider = .cloud
                conversationHistory = []
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("Include conversation history? This will send previous messages to Claude API.")
        }
    }

    private var providerBadge: some View {
        Button(action: toggleProvider) {
            HStack(spacing: 4) {
                Text(currentProvider.icon)
                Text(currentProvider.displayName)
                    .font(.caption)
                Image(systemName: "chevron.down")
                    .font(.caption2)
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(currentProvider == .cloud ? Color.blue.opacity(0.1) : Color.gray.opacity(0.1))
            .cornerRadius(6)
        }
        .buttonStyle(.plain)
    }

    private func toggleProvider() {
        if currentProvider == .local {
            // Switching to cloud - ask about history
            showHistoryPrompt = true
        } else {
            // Switching to local - no prompt needed
            currentProvider = .local
        }
    }
```

**Step 3: Verify it compiles**

Run: `cd SeleneChat && swift build 2>&1 | tail -10`
Expected: Build succeeded

**Step 4: Commit**

```bash
git add SeleneChat/Sources/Views/PlanningView.swift
git commit -m "feat(views): add provider toggle badge to conversation header"
```

---

## Task 6: Update Message Sending to Use Current Provider

**Files:**
- Modify: `SeleneChat/Sources/Views/PlanningView.swift:308-384` (startConversation and sendMessage)

**Step 1: Update startConversation to use providerService and track provider**

Replace the startConversation function (around line 308):

```swift
    private func startConversation() async {
        // Set initial provider from global default
        currentProvider = providerService.globalDefault

        // Mark thread as active
        try? await databaseService.updateThreadStatus(thread.id, status: .active)

        let systemPrompt = buildSystemPrompt()

        isProcessing = true

        do {
            let response = try await providerService.sendPlanningMessage(
                userMessage: "Start the planning session.",
                conversationHistory: [],
                systemPrompt: systemPrompt,
                provider: currentProvider
            )

            conversationHistory.append(["role": "user", "content": "Start the planning session."])
            conversationHistory.append(["role": "assistant", "content": response.message])

            messages.append(PlanningMessage(
                role: .assistant,
                content: response.cleanMessage,
                provider: currentProvider
            ))

            await handleExtractedTasks(response.extractedTasks)

        } catch {
            messages.append(PlanningMessage(
                role: .system,
                content: "Failed to start conversation: \(error.localizedDescription)",
                provider: currentProvider
            ))
        }

        isProcessing = false
    }
```

**Step 2: Update sendMessage to use providerService and track provider**

Replace the sendMessage function (around line 345):

```swift
    private func sendMessage() {
        guard !inputText.isEmpty else { return }

        let userInput = inputText
        inputText = ""

        // Add user message (no provider tracking for user messages)
        messages.append(PlanningMessage(role: .user, content: userInput))
        conversationHistory.append(["role": "user", "content": userInput])

        isProcessing = true

        Task {
            do {
                let response = try await providerService.sendPlanningMessage(
                    userMessage: userInput,
                    conversationHistory: conversationHistory,
                    systemPrompt: buildSystemPrompt(),
                    provider: currentProvider
                )

                conversationHistory.append(["role": "assistant", "content": response.message])

                messages.append(PlanningMessage(
                    role: .assistant,
                    content: response.cleanMessage,
                    provider: currentProvider
                ))

                await handleExtractedTasks(response.extractedTasks)

            } catch {
                messages.append(PlanningMessage(
                    role: .system,
                    content: "Error: \(error.localizedDescription)",
                    provider: currentProvider
                ))
            }

            isProcessing = false
        }
    }
```

**Step 3: Remove old claudeService property**

Remove this line (around line 183):
```swift
    private let claudeService = ClaudeAPIService.shared
```

**Step 4: Verify it compiles**

Run: `cd SeleneChat && swift build 2>&1 | tail -10`
Expected: Build succeeded

**Step 5: Commit**

```bash
git add SeleneChat/Sources/Views/PlanningView.swift
git commit -m "feat(views): use AIProviderService for message sending"
```

---

## Task 7: Add Visual Indicators to Message Bubbles

**Files:**
- Modify: `SeleneChat/Sources/Views/PlanningView.swift:463-507` (PlanningMessageBubble)

**Step 1: Update PlanningMessageBubble with provider styling**

Replace the PlanningMessageBubble struct:

```swift
struct PlanningMessageBubble: View {
    let message: PlanningMessage

    var body: some View {
        HStack {
            if message.role == .user { Spacer() }

            VStack(alignment: message.role == .user ? .trailing : .leading, spacing: 4) {
                content
                    .padding(12)
                    .background(backgroundColor)
                    .foregroundColor(textColor)
                    .cornerRadius(12)

                // Provider indicator for assistant messages
                if message.role == .assistant {
                    HStack(spacing: 4) {
                        Text(message.provider.icon)
                            .font(.caption2)
                        Text(message.provider.displayName)
                            .font(.caption2)
                            .foregroundColor(.secondary)
                    }
                }
            }

            if message.role != .user { Spacer() }
        }
    }

    @ViewBuilder
    private var content: some View {
        switch message.role {
        case .taskCreated:
            HStack(spacing: 8) {
                Image(systemName: "checkmark.circle.fill")
                    .foregroundColor(.green)
                Text("Task created: \(message.content)")
            }
            .font(.callout)
        default:
            Text(message.content)
        }
    }

    private var backgroundColor: Color {
        switch message.role {
        case .user:
            return Color.accentColor
        case .assistant:
            // Cloud messages get blue tint
            return message.provider == .cloud
                ? Color.blue.opacity(0.1)
                : Color(NSColor.controlBackgroundColor)
        case .system:
            return Color.orange.opacity(0.2)
        case .taskCreated:
            return Color.green.opacity(0.1)
        }
    }

    private var textColor: Color {
        message.role == .user ? .white : .primary
    }
}
```

**Step 2: Verify it compiles**

Run: `cd SeleneChat && swift build 2>&1 | tail -5`
Expected: Build succeeded

**Step 3: Commit**

```bash
git add SeleneChat/Sources/Views/PlanningView.swift
git commit -m "feat(views): add provider visual indicators to message bubbles"
```

---

## Task 8: Handle Missing API Key Error

**Files:**
- Modify: `SeleneChat/Sources/Views/PlanningView.swift`

**Step 1: Add API key error state**

Add a new @State property after the other states (around line 178):

```swift
    @State private var apiKeyMissing = false
```

**Step 2: Add API key check when switching to cloud**

Update the toggleProvider function:

```swift
    private func toggleProvider() {
        if currentProvider == .local {
            // Check if cloud is available before switching
            Task {
                let available = await providerService.isCloudAvailable()
                if available {
                    showHistoryPrompt = true
                } else {
                    apiKeyMissing = true
                }
            }
        } else {
            // Switching to local - no check needed
            currentProvider = .local
        }
    }
```

**Step 3: Add API key error view**

Add this view after the input area in the body (around line 232):

```swift
            // API key error message
            if apiKeyMissing && currentProvider == .cloud {
                apiKeyErrorView
            }
```

And add the view definition:

```swift
    private var apiKeyErrorView: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Image(systemName: "exclamationmark.triangle.fill")
                    .foregroundColor(.orange)
                Text("API key not found")
                    .font(.headline)
                Spacer()
                Button(action: { apiKeyMissing = false; currentProvider = .local }) {
                    Image(systemName: "xmark")
                }
                .buttonStyle(.plain)
            }

            Text("Set ANTHROPIC_API_KEY in your shell environment and restart SeleneChat.")
                .font(.subheadline)
                .foregroundColor(.secondary)

            Text("# Add to ~/.zshrc:\nexport ANTHROPIC_API_KEY=\"sk-ant-...\"")
                .font(.system(.caption, design: .monospaced))
                .padding(8)
                .background(Color.black.opacity(0.05))
                .cornerRadius(4)
        }
        .padding()
        .background(Color.orange.opacity(0.1))
        .cornerRadius(8)
        .padding(.horizontal)
    }
```

**Step 4: Verify it compiles**

Run: `cd SeleneChat && swift build 2>&1 | tail -5`
Expected: Build succeeded

**Step 5: Commit**

```bash
git add SeleneChat/Sources/Views/PlanningView.swift
git commit -m "feat(views): add API key missing error handling"
```

---

## Task 9: Initialize Provider from Global Default

**Files:**
- Modify: `SeleneChat/Sources/Views/PlanningView.swift`

**Step 1: Update .task to set provider**

The startConversation function already sets currentProvider from globalDefault. Verify this is working by checking the .task modifier calls startConversation.

**Step 2: Run full build and test**

Run: `cd SeleneChat && swift build 2>&1 | tail -20`
Expected: Build complete!

**Step 3: Commit final integration**

```bash
git add -A
git commit -m "feat: complete AI provider toggle implementation"
```

---

## Task 10: Add Tests

**Files:**
- Create: `SeleneChat/Tests/AIProviderTests.swift`

**Step 1: Create test file**

```swift
// SeleneChat/Tests/AIProviderTests.swift
import XCTest
@testable import SeleneChat

final class AIProviderTests: XCTestCase {

    func testAIProviderDefaults() {
        XCTAssertEqual(AIProvider.local.displayName, "Local")
        XCTAssertEqual(AIProvider.cloud.displayName, "Cloud")
        XCTAssertEqual(AIProvider.local.icon, "🏠")
        XCTAssertEqual(AIProvider.cloud.icon, "☁️")
    }

    func testAIProviderCodable() throws {
        let encoder = JSONEncoder()
        let decoder = JSONDecoder()

        let localData = try encoder.encode(AIProvider.local)
        let decoded = try decoder.decode(AIProvider.self, from: localData)

        XCTAssertEqual(decoded, AIProvider.local)
    }

    func testPlanningMessageWithProvider() {
        let localMessage = PlanningMessage(role: .assistant, content: "Test", provider: .local)
        let cloudMessage = PlanningMessage(role: .assistant, content: "Test", provider: .cloud)

        XCTAssertEqual(localMessage.provider, .local)
        XCTAssertEqual(cloudMessage.provider, .cloud)
    }
}
```

**Step 2: Run tests**

Run: `cd SeleneChat && swift test 2>&1 | tail -20`
Expected: Tests pass

**Step 3: Commit**

```bash
git add SeleneChat/Tests/AIProviderTests.swift
git commit -m "test: add AIProvider unit tests"
```

---

## Task 11: Create BRANCH-STATUS.md

**Files:**
- Create: `BRANCH-STATUS.md`

**Step 1: Create branch status file**

```markdown
# Branch: phase-7.2d/ai-provider-toggle

## Status: dev

## Checklist

### Planning
- [x] Design document: `docs/plans/2025-12-31-ai-provider-toggle-design.md`
- [x] Implementation plan: `docs/plans/2025-12-31-ai-provider-toggle-implementation.md`

### Development
- [ ] AIProvider enum created
- [ ] AIProviderService created
- [ ] PlanningMessage updated with provider field
- [ ] Settings popover created
- [ ] Provider toggle in header
- [ ] Message sending uses provider
- [ ] Visual indicators on messages
- [ ] API key error handling

### Testing
- [ ] Unit tests for AIProvider
- [ ] Manual testing of toggle flow
- [ ] Test local-only mode
- [ ] Test cloud mode with API key
- [ ] Test missing API key error

### Documentation
- [ ] Update SeleneChat README if needed
- [ ] Update CLAUDE.md context files if needed

### Review
- [ ] Code review complete
- [ ] All tests passing

## Files Changed
- `SeleneChat/Sources/Models/AIProvider.swift` (new)
- `SeleneChat/Sources/Services/AIProviderService.swift` (new)
- `SeleneChat/Sources/Views/AIProviderSettings.swift` (new)
- `SeleneChat/Sources/Views/PlanningView.swift` (modified)
- `SeleneChat/Tests/AIProviderTests.swift` (new)
```

**Step 2: Commit**

```bash
git add BRANCH-STATUS.md
git commit -m "docs: add BRANCH-STATUS.md for phase-7.2d"
```

---

## Summary

| Task | Files | Description |
|------|-------|-------------|
| 1 | `Models/AIProvider.swift` | Create AIProvider enum |
| 2 | `Services/AIProviderService.swift` | Create unified routing service |
| 3 | `Views/PlanningView.swift` | Add provider field to PlanningMessage |
| 4 | `Views/AIProviderSettings.swift` | Create settings popover |
| 5 | `Views/PlanningView.swift` | Add provider toggle to header |
| 6 | `Views/PlanningView.swift` | Update message sending |
| 7 | `Views/PlanningView.swift` | Add visual indicators |
| 8 | `Views/PlanningView.swift` | Handle missing API key |
| 9 | `Views/PlanningView.swift` | Initialize from global default |
| 10 | `Tests/AIProviderTests.swift` | Add unit tests |
| 11 | `BRANCH-STATUS.md` | Create branch status file |

**Total commits:** 11
**Estimated time:** 45-60 minutes

---

## Post-Implementation

After completing all tasks:

1. Run full test suite: `cd SeleneChat && swift test`
2. Build release: `cd SeleneChat && swift build -c release`
3. Manual test the toggle flow
4. Update BRANCH-STATUS.md to "ready"
5. Create PR with `gh pr create`
