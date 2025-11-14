# Ollama Integration Implementation Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** Integrate Ollama (Mistral 7B) into SeleneChat to provide conversational AI responses with actionable insights from user notes.

**Architecture:** Create OllamaService for HTTP communication with localhost:11434, simplify PrivacyRouter to route all queries to `.local`, update ChatViewModel to use OllamaService with graceful fallback to simple note listing if Ollama unavailable.

**Tech Stack:** Swift 5.9+, URLSession for HTTP, async/await, Ollama API (localhost:11434), Mistral 7B model

---

## Task 1: Create OllamaService with Health Check

**Goal:** Create service to communicate with Ollama API and verify it's running

**Files:**
- Create: `SeleneChat/Sources/Services/OllamaService.swift`

**Step 1: Create OllamaService file with basic structure**

Create the file `SeleneChat/Sources/Services/OllamaService.swift`:

```swift
import Foundation

class OllamaService {
    static let shared = OllamaService()

    private let baseURL = "http://localhost:11434"
    private let session = URLSession.shared

    private init() {}

    enum OllamaError: Error, LocalizedError {
        case serviceUnavailable
        case invalidResponse
        case decodingError
        case networkError(Error)

        var errorDescription: String? {
            switch self {
            case .serviceUnavailable:
                return "Ollama service is not running at localhost:11434"
            case .invalidResponse:
                return "Invalid response from Ollama service"
            case .decodingError:
                return "Failed to decode response from Ollama"
            case .networkError(let error):
                return "Network error: \(error.localizedDescription)"
            }
        }
    }
}
```

**Step 2: Add isAvailable() health check method**

Add to `OllamaService.swift`:

```swift
    /// Check if Ollama service is running and available
    func isAvailable() async -> Bool {
        guard let url = URL(string: "\(baseURL)/api/tags") else {
            return false
        }

        do {
            let (data, response) = try await session.data(from: url)

            guard let httpResponse = response as? HTTPURLResponse,
                  httpResponse.statusCode == 200 else {
                return false
            }

            // Try to decode response to verify it's valid JSON
            _ = try JSONSerialization.jsonObject(with: data)
            return true

        } catch {
            print("⚠️ Ollama health check failed: \(error.localizedDescription)")
            return false
        }
    }
```

**Step 3: Test health check manually**

Run in Terminal:

```bash
# First, verify Ollama is running
curl http://localhost:11434/api/tags

# Build the project to check for compilation errors
cd SeleneChat
swift build
```

Expected output from curl: JSON with `{"models":[...]}`
Expected build: Success with no errors

**Step 4: Commit**

```bash
git add SeleneChat/Sources/Services/OllamaService.swift
git commit -m "feat: Add OllamaService with health check

- Create OllamaService singleton
- Implement isAvailable() to check Ollama at localhost:11434
- Add OllamaError enum for error handling

🤖 Generated with [Claude Code](https://claude.com/claude-code)

Co-Authored-By: Claude <noreply@anthropic.com>"
```

---

## Task 2: Add OllamaService Generate Method

**Goal:** Implement LLM text generation via Ollama API

**Files:**
- Modify: `SeleneChat/Sources/Services/OllamaService.swift`

**Step 1: Add response model structures**

Add to `OllamaService.swift` before the class definition:

```swift
// MARK: - Request/Response Models

private struct GenerateRequest: Codable {
    let model: String
    let prompt: String
    let stream: Bool
}

private struct GenerateResponse: Codable {
    let model: String
    let response: String
    let done: Bool
}
```

**Step 2: Implement generate() method**

Add to `OllamaService` class:

```swift
    /// Generate text completion from Ollama
    /// - Parameters:
    ///   - prompt: The full prompt including system instructions and context
    ///   - model: The model to use (default: mistral:7b)
    /// - Returns: Generated text response
    func generate(prompt: String, model: String = "mistral:7b") async throws -> String {
        guard let url = URL(string: "\(baseURL)/api/generate") else {
            throw OllamaError.invalidResponse
        }

        // Build request body
        let requestBody = GenerateRequest(
            model: model,
            prompt: prompt,
            stream: false
        )

        // Create URLRequest
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try JSONEncoder().encode(requestBody)
        request.timeoutInterval = 30.0  // 30 second timeout

        do {
            let (data, response) = try await session.data(for: request)

            guard let httpResponse = response as? HTTPURLResponse else {
                throw OllamaError.invalidResponse
            }

            guard httpResponse.statusCode == 200 else {
                print("⚠️ Ollama returned status \(httpResponse.statusCode)")
                throw OllamaError.serviceUnavailable
            }

            // Decode response
            let generateResponse = try JSONDecoder().decode(GenerateResponse.self, from: data)

            return generateResponse.response

        } catch let error as OllamaError {
            throw error
        } catch {
            print("⚠️ Ollama generate error: \(error.localizedDescription)")
            throw OllamaError.networkError(error)
        }
    }
```

**Step 3: Test generate() manually**

Test with curl first to verify API works:

```bash
# Test Ollama API directly
curl http://localhost:11434/api/generate -d '{
  "model": "mistral:7b",
  "prompt": "Say hello in one sentence.",
  "stream": false
}'

# Build to check for errors
cd SeleneChat
swift build
```

Expected: JSON response with `{"model":"mistral:7b","response":"Hello!...","done":true}`

**Step 4: Commit**

```bash
git add SeleneChat/Sources/Services/OllamaService.swift
git commit -m "feat: Add Ollama text generation method

- Add GenerateRequest/Response models
- Implement generate() with 30s timeout
- Add comprehensive error handling
- Support custom model selection

🤖 Generated with [Claude Code](https://claude.com/claude-code)

Co-Authored-By: Claude <noreply@anthropic.com>"
```

---

## Task 3: Update PrivacyRouter for Local-Only Routing

**Goal:** Simplify routing logic to send all queries to Ollama (.local tier)

**Files:**
- Modify: `SeleneChat/Sources/Services/PrivacyRouter.swift:34-53`

**Step 1: Add .local case to RoutingDecision**

In `PrivacyRouter.swift`, update the `RoutingDecision` enum (around line 34):

```swift
    enum RoutingDecision {
        case onDevice(reason: String)
        case privateCloud(reason: String)
        case external(reason: String)
        case local(reason: String)  // ADD THIS LINE

        var tier: Message.LLMTier {
            switch self {
            case .onDevice: return .onDevice
            case .privateCloud: return .privateCloud
            case .external: return .external
            case .local: return .local  // ADD THIS LINE
            }
        }

        var reason: String {
            switch self {
            case .onDevice(let r), .privateCloud(let r), .external(let r), .local(let r):  // UPDATE THIS LINE
                return r
            }
        }
    }
```

**Step 2: Simplify routeQuery() to always return .local**

Replace the `routeQuery()` method (lines 55-100) with:

```swift
    func routeQuery(_ query: String, relatedNotes: [Note] = []) -> RoutingDecision {
        // Phase 2: All queries route to local Ollama for maximum insight
        // Future: Add complex routing when Claude API integration is needed
        return .local(reason: "Local LLM processing with Ollama for actionable insights")
    }
```

**Step 3: Build to verify changes compile**

```bash
cd SeleneChat
swift build
```

Expected: Success with no errors

**Step 4: Commit**

```bash
git add SeleneChat/Sources/Services/PrivacyRouter.swift
git commit -m "feat: Simplify PrivacyRouter to route all queries to Ollama

- Add .local case to RoutingDecision enum
- Update routeQuery() to always return .local
- Remove complex routing logic (deferred to future)

This enables Phase 2: all queries processed locally by Ollama
for maximum insight and actionable guidance.

🤖 Generated with [Claude Code](https://claude.com/claude-code)

Co-Authored-By: Claude <noreply@anthropic.com>"
```

---

## Task 4: Update ChatViewModel to Use OllamaService

**Goal:** Integrate OllamaService into chat flow with system prompt and fallback handling

**Files:**
- Modify: `SeleneChat/Sources/Services/ChatViewModel.swift`

**Step 1: Add OllamaService instance**

In `ChatViewModel.swift`, add after line 12 (after searchService):

```swift
    private let ollamaService = OllamaService.shared
```

**Step 2: Add system prompt builder**

Add this method to `ChatViewModel` class (after buildContext() method around line 165):

```swift
    private func buildSystemPrompt() -> String {
        """
        You are Selene, a personal AI assistant helping someone with ADHD manage their thoughts and notes.

        Your role:
        - Analyze patterns in their notes (energy, mood, themes, concepts)
        - Provide actionable recommendations
        - Be conversational and supportive
        - Focus on insights that lead to action

        Guidelines:
        - Keep responses concise but insightful
        - Highlight patterns and correlations when they exist
        - Suggest concrete next steps
        - Reference specific notes when relevant
        - Be empathetic about ADHD challenges

        The user's notes contain timestamps, energy levels, sentiment, themes, and concepts extracted by AI.
        """
    }
```

**Step 3: Implement handleOllamaQuery() method**

Replace the `handleOllamaQuery()` method (around line 209) with:

```swift
    private func handleOllamaQuery(context: String) async throws -> String {
        // Check if Ollama is available
        let isOllamaAvailable = await ollamaService.isAvailable()

        guard isOllamaAvailable else {
            print("⚠️ Ollama unavailable, falling back to simple response")
            // Extract notes from context to pass to fallback
            // For now, just indicate fallback is happening
            throw OllamaError.serviceUnavailable
        }

        // Build full prompt with system instructions
        let systemPrompt = buildSystemPrompt()
        let fullPrompt = """
        \(systemPrompt)

        \(context)

        Provide an actionable, insightful response based on these notes.
        """

        do {
            let response = try await ollamaService.generate(
                prompt: fullPrompt,
                model: "mistral:7b"
            )

            return response

        } catch {
            print("⚠️ Ollama generation failed: \(error.localizedDescription)")
            throw error
        }
    }

    // Define OllamaError locally for easy throwing
    private enum OllamaError: Error, LocalizedError {
        case serviceUnavailable

        var errorDescription: String? {
            "Ollama service is unavailable"
        }
    }
```

**Step 4: Update sendMessage() to handle Ollama fallback**

In `sendMessage()` method, update the switch statement (around line 43-55) to handle fallback:

```swift
            // Get response based on routing
            let response: String
            switch routingDecision.tier {
            case .onDevice, .privateCloud:
                // For now, we'll use a placeholder. In Phase 2, we'll integrate Apple Intelligence
                response = try await handleLocalQuery(context: context, notes: relatedNotes)

            case .external:
                // For now, we'll use a placeholder. In Phase 3, we'll integrate Claude API
                response = try await handleExternalQuery(context: context)

            case .local:
                // Use Ollama with fallback
                do {
                    response = try await handleOllamaQuery(context: context)
                } catch {
                    // Fallback to simple response if Ollama unavailable
                    print("⚠️ Falling back to simple response: \(error.localizedDescription)")
                    response = """
                    I'm having trouble connecting to the local AI service. Here are the related notes I found:

                    \(try await handleLocalQuery(context: context, notes: relatedNotes))
                    """
                }
            }
```

**Step 5: Build to verify changes**

```bash
cd SeleneChat
swift build
```

Expected: Success with no errors

**Step 6: Commit**

```bash
git add SeleneChat/Sources/Services/ChatViewModel.swift
git commit -m "feat: Integrate OllamaService into ChatViewModel

- Add OllamaService instance to ChatViewModel
- Implement buildSystemPrompt() with ADHD-focused instructions
- Update handleOllamaQuery() to use OllamaService
- Add graceful fallback if Ollama unavailable
- Update sendMessage() to handle .local tier with fallback

Users now get conversational AI responses from Ollama
with automatic fallback to simple note listing if service down.

🤖 Generated with [Claude Code](https://claude.com/claude-code)

Co-Authored-By: Claude <noreply@anthropic.com>"
```

---

## Task 5: Manual Integration Testing

**Goal:** Verify end-to-end Ollama integration works with various scenarios

**Files:**
- No file changes, testing only

**Step 1: Test Ollama availability check**

```bash
# Ensure Ollama is running
curl http://localhost:11434/api/tags

# If not running, start it:
# ollama serve
```

Expected: JSON response with models list

**Step 2: Build and run the app**

```bash
cd SeleneChat
swift build
./build-app.sh  # Or open in Xcode and run
```

Expected: App launches without errors

**Step 3: Test simple query**

In the app:
1. Type: "Show me my notes about focus"
2. Send message
3. Wait for response (1-5 seconds)

Expected:
- Message shows as "Local (Ollama)" tier (purple 💻 icon)
- Response is conversational (not just a list)
- Response references specific notes if found

**Step 4: Test complex analysis query**

In the app:
1. Type: "What patterns do you see in my energy levels?"
2. Send message
3. Wait for response (5-10 seconds with multiple notes)

Expected:
- Longer, more detailed response
- Pattern identification if multiple notes exist
- Actionable recommendations

**Step 5: Test Ollama unavailable scenario**

```bash
# Stop Ollama service
# (If running via `ollama serve`, press Ctrl+C)
# Or: pkill ollama
```

In the app:
1. Type: "Test fallback"
2. Send message

Expected:
- Response within 1 second
- Message: "I'm having trouble connecting to the local AI service..."
- Falls back to simple note listing
- No app crash

**Step 6: Restart Ollama and verify recovery**

```bash
# Restart Ollama
ollama serve &
```

In the app:
1. Type: "Test recovery"
2. Send message

Expected:
- Ollama responses working again
- Conversational response

**Step 7: Check session persistence**

1. Quit and relaunch app
2. Check chat history

Expected:
- Previous messages preserved
- Session loads correctly
- LLM tier icons correct

**Step 8: Document any issues**

Create file `SeleneChat/TESTING_NOTES.md` with findings:

```markdown
# Ollama Integration Testing - 2025-11-14

## Test Results

### ✅ Passing
- [ ] Ollama health check works
- [ ] Simple queries get conversational responses
- [ ] Complex queries provide pattern analysis
- [ ] Fallback works when Ollama down
- [ ] Session persistence maintained
- [ ] LLM tier indicators correct

### ⚠️ Issues Found
(Document any problems here)

### 📊 Performance
- First query: ___ seconds
- Subsequent queries: ___ seconds
- Complex analysis: ___ seconds

### 💡 Observations
(Document UX notes, surprising behaviors, etc.)
```

**Step 9: Commit testing notes if any issues found**

```bash
# Only if you created TESTING_NOTES.md or fixed bugs
git add SeleneChat/TESTING_NOTES.md
git commit -m "docs: Add Ollama integration testing notes

Testing results for Phase 2 Ollama integration.

🤖 Generated with [Claude Code](https://claude.com/claude-code)

Co-Authored-By: Claude <noreply@anthropic.com>"
```

---

## Task 6: Performance Optimization (Optional)

**Goal:** Cache Ollama availability to reduce health check overhead

**Files:**
- Modify: `SeleneChat/Sources/Services/OllamaService.swift`

**Step 1: Add availability cache**

Add to `OllamaService` class after `session` property:

```swift
    private var lastAvailabilityCheck: Date?
    private var cachedAvailability: Bool = false
    private let cacheTimeout: TimeInterval = 60  // Cache for 60 seconds
```

**Step 2: Update isAvailable() to use cache**

Replace `isAvailable()` method:

```swift
    /// Check if Ollama service is running and available (cached for 60s)
    func isAvailable() async -> Bool {
        // Return cached result if fresh
        if let lastCheck = lastAvailabilityCheck,
           Date().timeIntervalSince(lastCheck) < cacheTimeout {
            return cachedAvailability
        }

        // Perform actual health check
        guard let url = URL(string: "\(baseURL)/api/tags") else {
            return false
        }

        do {
            let (data, response) = try await session.data(from: url)

            guard let httpResponse = response as? HTTPURLResponse,
                  httpResponse.statusCode == 200 else {
                cachedAvailability = false
                lastAvailabilityCheck = Date()
                return false
            }

            // Try to decode response to verify it's valid JSON
            _ = try JSONSerialization.jsonObject(with: data)

            cachedAvailability = true
            lastAvailabilityCheck = Date()
            return true

        } catch {
            print("⚠️ Ollama health check failed: \(error.localizedDescription)")
            cachedAvailability = false
            lastAvailabilityCheck = Date()
            return false
        }
    }
```

**Step 3: Build and test**

```bash
cd SeleneChat
swift build

# Test rapid queries don't hammer health check
# Open app, send 3 queries quickly
```

Expected: Only one health check log message for multiple queries within 60s

**Step 4: Commit**

```bash
git add SeleneChat/Sources/Services/OllamaService.swift
git commit -m "perf: Cache Ollama availability check for 60 seconds

Reduces overhead of health checks on every query.
Cache invalidates after 60s to detect service restarts.

🤖 Generated with [Claude Code](https://claude.com/claude-code)

Co-Authored-By: Claude <noreply@anthropic.com>"
```

---

## Success Criteria

Implementation complete when:

- ✅ OllamaService can check health and generate text
- ✅ PrivacyRouter routes all queries to `.local` tier
- ✅ ChatViewModel uses Ollama for responses
- ✅ System prompt provides ADHD-focused guidance
- ✅ Graceful fallback when Ollama unavailable
- ✅ Session persistence still works
- ✅ Manual testing passes all scenarios
- ✅ No regressions in existing functionality

---

## Files Modified Summary

**Created:**
- `SeleneChat/Sources/Services/OllamaService.swift` - HTTP client for Ollama API

**Modified:**
- `SeleneChat/Sources/Services/PrivacyRouter.swift` - Simplified routing to .local
- `SeleneChat/Sources/Services/ChatViewModel.swift` - Ollama integration with fallback

**Optional:**
- `SeleneChat/TESTING_NOTES.md` - Manual testing documentation

---

## Commands Reference

```bash
# Health check Ollama
curl http://localhost:11434/api/tags

# Build project
cd SeleneChat && swift build

# Run tests (when added)
cd SeleneChat && swift test

# Build app bundle
cd SeleneChat && ./build-app.sh

# Check git status
git status

# View changes
git diff

# Commit with message
git add <files> && git commit -m "message"
```

---

## Troubleshooting

**Ollama not responding:**
```bash
# Check if Ollama is running
curl http://localhost:11434/api/tags

# If not, start it
ollama serve

# Verify mistral model installed
ollama list
```

**Build errors:**
```bash
# Clean build
cd SeleneChat
rm -rf .build
swift build
```

**URLSession timeout:**
- Default timeout is 30s
- Large queries with many notes may take 10-15s
- Adjust `request.timeoutInterval` in `generate()` if needed

**Database issues:**
- Verify database path in Settings
- Check database has notes to query
- Use SeleneChat's search feature to verify notes exist
