# Phase 7.2d: AI Provider Toggle

**Status:** Design Complete
**Created:** 2025-12-31
**Author:** Chase Easterling + Claude

---

## Overview

Add the ability to toggle between local LLM (Ollama) and cloud AI (Anthropic Claude API) in SeleneChat's Planning tab, with local as the secure default.

**Why this feature:**
- **Privacy** - Sensitive notes stay on-device by default
- **Cost** - Only use paid API when you need Claude's reasoning power
- **Offline** - Planning works without internet connection

**Key Design Decision:** Local-first with explicit cloud opt-in. Users must consciously choose to send data to cloud AI.

---

## Architecture

### High-Level View

```
┌─────────────────────────────────────────────────────────────────────┐
│ PlanningConversationView                                            │
│ ┌─────────────────────────────────────────────────────────────────┐ │
│ │ Header: [Thread Title]    [🏠 Local ▾]    [⚙️ Settings]        │ │
│ └─────────────────────────────────────────────────────────────────┘ │
│                                                                     │
│ ┌─────────────────────────────────────────────────────────────────┐ │
│ │ Messages (with provider-specific styling)                       │ │
│ │  - Local messages: default style + 🏠 icon                     │ │
│ │  - Cloud messages: blue tint + ☁️ icon                         │ │
│ └─────────────────────────────────────────────────────────────────┘ │
└─────────────────────────────────────────────────────────────────────┘
                              │
                              ▼
                  ┌───────────────────────┐
                  │ AIProviderService     │
                  │ - currentProvider     │
                  │ - globalDefault       │
                  │ - sendMessage()       │
                  └───────────────────────┘
                        │           │
              ┌─────────┘           └─────────┐
              ▼                               ▼
       OllamaService                 ClaudeAPIService
       (existing)                    (existing)
```

### Design Principles

1. **Local by default** - Privacy-first, no data leaves device unless explicitly requested
2. **Per-conversation flexibility** - Global setting with conversation-level override
3. **Clear visibility** - Always know which provider is active via visual indicators
4. **Developer-friendly** - API key via environment variable, no in-app credential storage

---

## Settings & Configuration

### API Key Management

Claude API key is read from environment variable:

```bash
# In ~/.zshrc or ~/.bashrc
export ANTHROPIC_API_KEY="sk-ant-..."
```

SeleneChat reads this at launch:
```swift
let apiKey = ProcessInfo.processInfo.environment["ANTHROPIC_API_KEY"]
```

**No in-app key entry** - keeps credentials out of app storage and preferences.

### Global Default Setting

Stored in UserDefaults:
```swift
enum AIProvider: String, Codable {
    case local   // Ollama
    case cloud   // Claude API
}

// UserDefaults key
let defaultProvider = UserDefaults.standard.string(forKey: "defaultAIProvider") ?? "local"
```

Default: `local` (Ollama)

### Settings Popover

Accessed via gear icon in Planning tab header:

```
┌─────────────────────────────────────────┐
│  Planning Settings              [Done]  │
├─────────────────────────────────────────┤
│                                         │
│  Default AI Provider                    │
│  ┌───────────────────────────────────┐  │
│  │ [🏠 Local]  [☁️ Cloud]           │  │
│  └───────────────────────────────────┘  │
│                                         │
│  Provider Status                        │
│  ─────────────────────────────────────  │
│  🏠 Ollama         Connected ✓          │
│  ☁️ Claude API     API key configured ✓ │
│                                         │
└─────────────────────────────────────────┘
```

Status indicators:
- Ollama: "Connected" / "Offline"
- Claude: "API key configured ✓" / "API key not found"

---

## UI Components

### Conversation Header

Provider badge doubles as toggle (click to switch):

**Local mode (default):**
```
┌─────────────────────────────────────────────────────────────────┐
│ ← Break down quarterly goals        [🏠 Local ▾]    [⚙️]       │
└─────────────────────────────────────────────────────────────────┘
```

**Cloud mode (explicit override):**
```
┌─────────────────────────────────────────────────────────────────┐
│ ← Break down quarterly goals        [☁️ Cloud ▾]    [⚙️]       │
└─────────────────────────────────────────────────────────────────┘
```

- Dropdown arrow indicates interactive
- Neutral/gray for Local, subtle blue for Cloud

### Switching to Cloud Mid-Conversation

When toggling from Local to Cloud, prompt appears:

```
┌──────────────────────────────────────────────────────────┐
│  Switch to Cloud AI                                      │
│                                                          │
│  Include conversation history?                           │
│                                                          │
│  This will send previous messages to Claude API.         │
│                                                          │
│  [Yes, send history]     [No, fresh start]               │
└──────────────────────────────────────────────────────────┘
```

- "Yes, send history" - Claude gets full context for better responses
- "No, fresh start" - Only new messages go to Claude, preserves local privacy

### Message Bubble Styling

Each AI response shows which provider generated it:

**Local message:**
```
┌─────────────────────────────────────────────────────────┐
│ Here's how I'd break this down into smaller tasks...    │
│                                                    🏠   │
└─────────────────────────────────────────────────────────┘
```

**Cloud message:**
```
┌─────────────────────────────────────────────────────────┐
│ Let me help structure this into actionable steps...     │  ← subtle blue tint
│                                                    ☁️   │
└─────────────────────────────────────────────────────────┘
```

- Small provider icon in bottom-right of each AI message
- Cloud messages have subtle blue background tint
- User messages remain unchanged regardless of provider

### Missing API Key Handling

If cloud is selected without `ANTHROPIC_API_KEY` set:

```
┌─────────────────────────────────────────────────────────────────┐
│ ← Break down quarterly goals        [☁️ Cloud ▾]    [⚙️]       │
├─────────────────────────────────────────────────────────────────┤
│                                                                 │
│  ⚠️ API key not found                                          │
│                                                                 │
│  Set ANTHROPIC_API_KEY in your shell environment               │
│  and restart SeleneChat.                                        │
│                                                                 │
│  # Add to ~/.zshrc:                                            │
│  export ANTHROPIC_API_KEY="sk-ant-..."                         │
│                                                                 │
└─────────────────────────────────────────────────────────────────┘
```

Toggle still switches (to show intent), but inline error prevents sending messages.

---

## Data Model

### Message Model Update

Add provider tracking to messages:

```swift
enum AIProvider: String, Codable {
    case local
    case cloud
}

struct PlanningMessage: Identifiable, Codable {
    let id: UUID
    let role: MessageRole  // user, assistant
    let content: String
    let provider: AIProvider  // NEW - which AI generated this
    let timestamp: Date
}
```

### Conversation Model Update

Track per-conversation override:

```swift
struct PlanningConversation {
    let threadId: Int
    var messages: [PlanningMessage]
    var providerOverride: AIProvider?  // NEW - nil means use global default

    var effectiveProvider: AIProvider {
        providerOverride ?? UserDefaults.globalDefault
    }
}
```

### Settings Storage

| Setting | Storage | Default |
|---------|---------|---------|
| Global default | `UserDefaults["defaultAIProvider"]` | `"local"` |
| Per-conversation override | In-memory on conversation model | `nil` (use global) |
| API key | Environment variable | Required for cloud |

---

## Technical Implementation

### New Components

| File | Purpose |
|------|---------|
| `AIProviderService.swift` | Unified interface routing to Ollama or Claude |
| `AIProviderSettings.swift` | Settings popover view |
| `AIProvider.swift` | Enum and related types |

### AIProviderService

```swift
protocol AIProviderProtocol {
    func sendMessage(prompt: String, context: [PlanningMessage]) async throws -> String
}

class AIProviderService: ObservableObject {
    @Published var globalDefault: AIProvider = .local

    private let ollamaService: OllamaService
    private let claudeService: ClaudeAPIService

    var isCloudAvailable: Bool {
        ProcessInfo.processInfo.environment["ANTHROPIC_API_KEY"] != nil
    }

    var isOllamaAvailable: Bool {
        // Check Ollama connection status
    }

    func sendMessage(
        prompt: String,
        context: [PlanningMessage],
        provider: AIProvider
    ) async throws -> PlanningMessage {
        let response: String

        switch provider {
        case .local:
            response = try await ollamaService.generate(prompt: prompt, context: context)
        case .cloud:
            guard isCloudAvailable else {
                throw AIProviderError.apiKeyNotFound
            }
            response = try await claudeService.planningMessage(
                userMessage: prompt,
                context: context
            )
        }

        return PlanningMessage(
            id: UUID(),
            role: .assistant,
            content: response,
            provider: provider,
            timestamp: Date()
        )
    }
}
```

### Updates to Existing Files

**PlanningConversationView.swift:**
- Add provider badge/toggle to header
- Track `providerOverride` state
- Pass provider to message sending
- Style messages based on `message.provider`

**ClaudeAPIService.swift:**
- Add `isConfigured` computed property
- Read API key from environment at init

---

## Implementation Checklist

### Phase 7.2d-1: Core Infrastructure
- [ ] Create `AIProvider.swift` enum
- [ ] Create `AIProviderService.swift` protocol and implementation
- [ ] Update `ClaudeAPIService` to check for env var API key
- [ ] Add `provider` field to `PlanningMessage` model
- [ ] Add global default to UserDefaults

### Phase 7.2d-2: Settings UI
- [ ] Create `AIProviderSettings.swift` popover view
- [ ] Add gear icon to Planning tab/conversation header
- [ ] Show provider connection status
- [ ] Implement global default toggle

### Phase 7.2d-3: Conversation Toggle
- [ ] Add provider badge to conversation header
- [ ] Make badge interactive (toggle on click)
- [ ] Implement "Include history?" prompt when switching to cloud
- [ ] Store per-conversation provider override

### Phase 7.2d-4: Visual Indicators
- [ ] Style cloud messages with blue tint
- [ ] Add provider icons (🏠/☁️) to message bubbles
- [ ] Implement inline error display for missing API key
- [ ] Polish dropdown/toggle animations

---

## Testing Strategy

### Unit Tests
- `AIProviderService`: Route to correct provider
- `AIProviderService`: Handle missing API key gracefully
- Settings: Persist and load global default
- Message model: Encode/decode provider field

### Integration Tests
- Full conversation with provider switch mid-conversation
- History inclusion when switching to cloud
- Settings changes apply to new conversations

### Manual Testing
- Verify visual indicators are clear
- Test offline scenarios (Ollama only)
- Test without API key configured
- Verify provider choice persists correctly

---

## Success Metrics

- [ ] Local is clearly the default (no accidental cloud usage)
- [ ] Provider status visible at all times
- [ ] Switching mid-conversation works smoothly
- [ ] API key error is helpful (shows setup instructions)
- [ ] Message styling makes provider origin obvious

---

## Related Documentation

- [Phase 7.2 Design](./2025-12-31-phase-7.2-selenechat-planning-design.md)
- [Claude API Documentation](https://docs.anthropic.com/claude/reference/messages_post)
- [Ollama API Documentation](https://github.com/ollama/ollama/blob/main/docs/api.md)
