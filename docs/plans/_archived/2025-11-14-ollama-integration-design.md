# Ollama Integration Design - SeleneChat Phase 2

**Date:** 2025-11-14
**Status:** Approved for Implementation
**Goal:** Enable conversational AI responses in SeleneChat using local Ollama LLM for maximum insight and actionable guidance

---

## Overview

Integrate Ollama (running Mistral 7B at localhost:11434) into SeleneChat to provide intelligent, conversational responses that analyze user notes and provide actionable recommendations. All processing stays local for privacy.

### Design Principles

1. **Local-first:** All queries processed locally via Ollama (no external APIs for now)
2. **Maximum insight:** Prioritize deep analysis and actionable guidance over speed
3. **Graceful degradation:** Fallback to simple note listing if Ollama unavailable
4. **Simple routing:** Everything goes to Ollama - no complex routing logic yet
5. **Conversational:** Natural multi-turn dialogue with context memory

---

## Architecture

### Components

#### 1. OllamaService (New)
**Purpose:** HTTP client for Ollama API at localhost:11434

**Key Methods:**
- `isAvailable() async -> Bool` - Health check (GET /api/tags)
- `generate(prompt: String, model: String) async throws -> String` - Generate response

**API Endpoints:**
- `POST /api/generate` - Generate completion from prompt
- `GET /api/tags` - List available models (health check)

**Request Format:**
```json
{
  "model": "mistral:7b",
  "prompt": "[system prompt + user query + context]",
  "stream": false
}
```

**Error Handling:**
- Connection refused → Ollama not running (fallback)
- Timeout (>30s) → Query too complex (error message)
- Invalid model → Use default mistral:7b

#### 2. PrivacyRouter (Updated)
**Simplified Routing:** Everything routes to `.local` (Ollama)

```swift
func routeQuery(_ query: String, relatedNotes: [Note] = []) -> RoutingDecision {
    return RoutingDecision(
        tier: .local,
        reason: "Local LLM processing with Ollama"
    )
}
```

**Future:** Add complex routing when Claude API integration is needed (Phase 3)

#### 3. ChatViewModel (Updated)
**Changes to `handleOllamaQuery()`:**
1. Check Ollama availability
2. Build system prompt + context
3. Call OllamaService.generate()
4. On error: fallback to `handleLocalQuery()`

**Changes to `sendMessage()`:**
- Query always routes to `.local`
- Error handling with graceful fallback

---

## Prompt Engineering

### System Prompt
```
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
```

### Context Format
```
User Query: [user's question]

Related Notes (found in database):

[1] "Title of Note 1"
Date: 2025-11-10
Theme: productivity
Concepts: focus, planning, deadlines
Energy: Low 🔋
Sentiment: Negative (-0.6)

Content: [first 200 chars of note content]...

---

[2] "Title of Note 2"
...

Provide an actionable, insightful response based on these notes.
```

### Response Expectations
- Conversational tone (not robotic)
- Pattern identification when multiple notes exist
- Specific, actionable recommendations
- Reference note titles/dates when relevant

---

## Flow Diagram

```
User Query
    ↓
Find Related Notes (database search)
    ↓
Build Context (query + system prompt + notes)
    ↓
Check Ollama Availability
    ↓
    ├─ Available → Generate Response (1-8s)
    │                    ↓
    │              Return Conversational Response
    │
    └─ Unavailable → Fallback to Simple Note Listing
                          ↓
                    Return Basic Response (<1s)
    ↓
Save Message to Session (database)
```

---

## Error Handling

### Scenarios

| Error | User Message | Behavior |
|-------|-------------|----------|
| Ollama not running | "I'm having trouble connecting to the local AI service. Here are the notes I found instead: [list]" | Fallback to handleLocalQuery() |
| Generation timeout (>30s) | "That query is taking too long. Let me show you the related notes: [list]" | Cancel request, show notes |
| Invalid model | "AI service configuration issue. Showing notes: [list]" | Fallback to handleLocalQuery() |
| Network error | "Connection error with AI service. Showing notes: [list]" | Fallback to handleLocalQuery() |

### Health Check
- Check Ollama availability on app launch (non-blocking)
- Don't prevent app from starting if Ollama is down
- Re-check on each query (cached for 60s to avoid overhead)

---

## Performance Expectations

| Scenario | Expected Time | Notes |
|----------|---------------|-------|
| First query (cold start) | 2-5 seconds | Model loading + inference |
| Subsequent queries | 1-3 seconds | Model warm, faster inference |
| Complex analysis (5+ notes) | 5-8 seconds | More tokens to process |
| Fallback (Ollama down) | <1 second | Database query only |

**Not a concern:** User prioritizes insight over speed

---

## Testing Strategy

### Unit Tests
- OllamaService.isAvailable() with mock responses
- OllamaService.generate() with mock API
- Prompt building correctness

### Integration Tests
- End-to-end query with real Ollama
- Multi-turn conversation with context
- Fallback when Ollama stopped

### Manual Testing Scenarios
1. Simple query (e.g., "show my focus notes")
2. Complex analysis (e.g., "analyze my anxiety patterns")
3. Multi-turn conversation (follow-up questions)
4. No related notes found
5. Ollama service down (test fallback)
6. Ollama timeout scenario

---

## Future Enhancements (Not in Scope)

- ❌ Apple Intelligence integration (Phase 2.5)
- ❌ Claude API for non-sensitive queries (Phase 3)
- ❌ Streaming responses for real-time UI updates
- ❌ Complex routing logic (sensitive vs general)
- ❌ Model selection UI (always use mistral:7b for now)
- ❌ Context window management (>8k tokens)

---

## Implementation Checklist

- [ ] Create OllamaService.swift with HTTP client
- [ ] Implement isAvailable() health check
- [ ] Implement generate() method
- [ ] Update PrivacyRouter with simplified routing
- [ ] Update ChatViewModel.handleOllamaQuery()
- [ ] Add system prompt building
- [ ] Add error handling and fallbacks
- [ ] Write unit tests for OllamaService
- [ ] Write integration tests
- [ ] Manual testing with various query types
- [ ] Performance testing (response times)
- [ ] Update documentation

---

## Success Criteria

1. ✅ User can ask questions and receive conversational responses
2. ✅ Ollama analyzes note patterns and provides actionable insights
3. ✅ Multi-turn conversations maintain context
4. ✅ Graceful fallback when Ollama unavailable
5. ✅ All processing stays local (privacy maintained)
6. ✅ Response quality prioritized over speed

---

## Files to Modify/Create

### New Files
- `SeleneChat/Sources/Services/OllamaService.swift`

### Modified Files
- `SeleneChat/Sources/Services/ChatViewModel.swift`
- `SeleneChat/Sources/Services/PrivacyRouter.swift`

### Test Files
- `SeleneChat/Tests/OllamaServiceTests.swift` (new)
- `SeleneChat/Tests/ChatViewModelTests.swift` (update)

---

## Dependencies

- Ollama running at localhost:11434
- Mistral 7B model installed (`mistral:7b`)
- Swift 5.9+
- macOS 14.0+ (for async/await)

---

## Notes

- Ollama is already running and tested in n8n workflows
- Database chat session persistence already implemented (2025-11-14)
- Privacy router architecture already exists
- This completes Phase 2: Local Intelligence from roadmap
