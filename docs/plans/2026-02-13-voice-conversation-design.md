# Voice Conversation Mode (Voice Phase 2)

**Date:** 2026-02-13
**Status:** Ready
**Author:** Chase + Claude

---

## Problem

SeleneChat has voice input (Phase 1) but it's one-directional — you speak, Selene types. Reading a response while your hands are busy or your eyes are elsewhere breaks the flow. A voice conversation should work both ways: speak to Selene, hear her reply.

---

## Solution

Add text-to-speech to SeleneChat's response pipeline. When a message originates from voice input, the response is both displayed as text and spoken aloud. Typed messages remain text-only.

No new UI surfaces, no new interaction paradigms. The existing voice input flow gains a spoken response at the end.

---

## ADHD Value

| Feature | Cognitive Benefit |
|---------|-------------------|
| Voice in = voice out | No mode-switching between speaking and reading |
| Auto-detect input method | Zero configuration — just works |
| Interrupt by speaking | Tap mic to cut Selene off, natural turn-taking |
| Text always visible | Can re-read response even after hearing it |

---

## Architecture

### New Component

```
SeleneChat/Sources/Services/
  SpeechSynthesisService.swift    # AVSpeechSynthesizer wrapper
```

`SpeechSynthesisService` — `@MainActor class: ObservableObject`:
- Wraps `AVSpeechSynthesizer` (macOS built-in, no dependencies)
- `@Published var isSpeaking: Bool`
- `speak(text:)` — strips markdown/citations, queues utterance
- `stop()` — interrupts immediately
- Uses system-configured voice (user picks in System Settings > Accessibility > Spoken Content)
- One utterance at a time, latest wins (no queue buildup)

### Modified Components

**Message.swift** — add field:
```swift
var voiceOriginated: Bool = false
```

**ChatView.swift** — track voice origin:
- Set `wasVoiceInput = true` when speech state transitions from listening → idle
- Pass flag to `chatViewModel.sendMessage()` on send
- Reset flag after send

**ChatViewModel.swift** — wire TTS:
- `sendMessage(_ content: String, voiceOriginated: Bool = false)`
- Store `voiceOriginated` on user Message
- After creating assistant message: if user was voice-originated, call `speechSynthesisService.speak(response)`
- Applies to all response paths (Ollama, thread queries, synthesis queries)

**SeleneChatApp.swift** — inject service:
- `@StateObject private var speechSynthesisService = SpeechSynthesisService()`
- `.environmentObject(speechSynthesisService)`

---

## Interaction Flow

```
User taps mic → speaks → silence timeout → text appears in field
  │
  User reviews, presses Enter
  │
  ▼
Message sent with voiceOriginated = true
Ollama processes — ThinkingIndicator shows as usual
  │
  ▼
Response appears in chat AND Selene speaks it aloud
  │
  ├─ User starts typing → speech continues
  ├─ User taps mic → speech STOPS, new listening begins
  └─ Selene finishes speaking → silence, awaits next input
```

### Edge Cases

- **Long responses**: Reads entire response. User can tap mic to interrupt.
- **Thread/synthesis queries**: Instant responses still spoken if voice-originated.
- **Errors**: Error messages displayed as text only, not spoken.
- **Rapid messages**: New response interrupts any in-progress speech.

### Explicitly Out of Scope

- No auto-listen after Selene finishes (avoids infinite loop)
- No global hotkey (separate feature)
- No voice capture mode (save as note)
- No neural TTS engine (future upgrade)

---

## Text Cleaning for TTS

Before speaking, strip:
- Markdown formatting (`**bold**` → `bold`, `_italic_` → `italic`)
- Citation markers (`[1]`, `[2]`)
- Code blocks (skip entirely or read as "code block")
- URLs (skip or say "link")
- Bullet markers (`-`, `*`, numbered lists → natural pauses)

---

## Testing

### Unit Tests — SpeechSynthesisService
- `speak()` sets `isSpeaking = true`
- `stop()` sets `isSpeaking = false`
- Speaking while already speaking stops previous utterance
- Markdown stripping: `"**bold** and [1]"` → `"bold and"`

### Unit Tests — Pipeline
- `Message` with `voiceOriginated: true` round-trips through Codable
- `sendMessage("hello", voiceOriginated: true)` flags user message correctly

### Integration Tests
- Voice-originated message triggers TTS after response
- Typed message does NOT trigger TTS

### Skip
- No testing actual audio output (hardware-dependent)
- Protocol-based injection for testability (`SpeechSynthesizing` protocol)

---

## Acceptance Criteria

- [ ] Voice-originated messages trigger spoken response
- [ ] Typed messages do not trigger spoken response
- [ ] Response text displayed simultaneously with speech
- [ ] Tapping mic button interrupts current speech
- [ ] Markdown and citations stripped before speaking
- [ ] `isSpeaking` state observable for future UI indicators
- [ ] All speech processing on-device (AVSpeechSynthesizer)
- [ ] Existing voice input behavior unchanged
- [ ] Tests pass for new service and pipeline changes

### ADHD Check

- [x] Reduces friction — hear responses without reading
- [x] No configuration — voice in automatically triggers voice out
- [x] Interruptible — tap mic to take over
- [x] Non-destructive — text always visible as fallback

### Scope Check

- [x] < 1 week: 1 new file, minor changes to 4 existing files
- [x] No new dependencies (AVFoundation is a system framework)
- [x] No database changes
- [x] No backend changes
