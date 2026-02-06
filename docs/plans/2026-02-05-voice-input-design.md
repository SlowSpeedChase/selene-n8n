# Selene Voice Input

**Date:** 2026-02-05
**Status:** Vision
**Author:** Chase + Claude

---

## Problem

SeleneChat is 100% keyboard-driven. For ADHD, typing creates friction -- you have to stop what you're doing, switch to SeleneChat, formulate your thought precisely, and type it out. By the time you've done all that, the thought may be gone.

Voice is the fastest way to externalize a thought. Speaking is lower friction than typing, works hands-free, and captures the natural flow of thinking.

---

## Solution

Add voice input to SeleneChat using Apple's on-device Speech framework. Three activation modes:

1. **Push-to-talk button** in SeleneChat's chat view
2. **Global hotkey** (`Cmd+Shift+Space`) from anywhere on macOS
3. **Stream Deck button** via `selene://voice` URL scheme

Voice input streams live transcription into the existing text field. No new message types -- transcribed text is just text, identical to typing once sent.

---

## ADHD Value

| Feature | Cognitive Benefit |
|---------|-------------------|
| Push-to-talk | Eliminates typing friction, captures thoughts at speed of speech |
| Global hotkey | No context-switching -- voice input from any app |
| Stream Deck button | Physical button = zero cognitive load to activate |
| Live transcription | Immediate visual feedback -- see your words as you speak |
| Review before send | Externalizes the thought first, then lets you refine it |

---

## User Experience

### In-App Push-to-Talk

```
┌─────────────────────────────────────────────────┐
│ SeleneChat - Chat                               │
│                                                 │
│ [message history...]                            │
│                                                 │
│ ┌─────────────────────────────────────┐ ┌───┐  │
│ │ search my notes about the project   │ │ 🎤│  │
│ │ planning meeting with Dave_         │ │   │  │
│ └─────────────────────────────────────┘ └───┘  │
│        ↑ live transcription streaming    ↑      │
│                                     pulsing     │
│                                     while       │
│                                     recording   │
└─────────────────────────────────────────────────┘
```

### Global Hotkey / Stream Deck

```
1. User presses Cmd+Shift+Space (or Stream Deck button)
2. SeleneChat comes to front
3. Mic activates, live transcription begins
4. Same flow as in-app push-to-talk
```

### Interaction Flow

```
Tap mic button / press hotkey / press Stream Deck
  │
  ▼
Mic activates, button pulses
Words stream into TextField as you speak
  │
  ▼
User stops speaking
2-second silence timeout starts
  │
  ▼
Silence timeout fires OR user taps mic again
Audio stops, final transcription in TextField
  │
  ▼
User reviews text
  ├─ Enter → sends to Selene (normal chat pipeline)
  ├─ Edit → type corrections, then Enter
  └─ Escape → clear and cancel
```

**Key decisions:**
- Never auto-send -- always let user review first
- Silence timeout stops recording, not sends
- Escape to bail out at zero cost

---

## Architecture

### New Components

```
SeleneChat/Sources/
  Services/
    SpeechRecognitionService.swift   # Apple Speech wrapper
    VoiceInputManager.swift          # Coordinates activation modes
  Views/
    VoiceMicButton.swift             # Push-to-talk UI component
```

### SpeechRecognitionService

Wraps Apple's `SFSpeechRecognizer` with on-device processing:

- `requiresOnDeviceRecognition = true` -- nothing leaves the Mac
- `AVAudioEngine` captures mic input
- `SFSpeechAudioBufferRecognitionRequest` processes audio buffers
- Publishes `@Published var liveText: String` for streaming transcription
- Publishes `@Published var state: VoiceState` (`.idle`, `.listening`, `.processing`)
- Configurable silence timeout (default 2 seconds)

### VoiceInputManager

Coordinates the three activation modes:

- Registers global hotkey via `NSEvent.addGlobalMonitorForEvents`
- Registers `selene://voice` URL scheme handler
- On activation: brings SeleneChat to front, starts `SpeechRecognitionService`
- Feeds `liveText` into `ChatView`'s text field binding

### VoiceMicButton

UI component next to the existing TextField in ChatView:

- Mic icon, toggles between idle/listening states
- Pulsing animation while recording
- Subtle audio level indicator

### Changes to Existing Files

- `ChatView.swift` -- add `VoiceMicButton` next to TextField, bind to live transcription
- `SeleneChatApp.swift` -- register URL scheme handler, init `VoiceInputManager`
- `Info.plist` -- declare `selene://` URL scheme
- `Package.swift` -- no new dependencies (Speech + AVFoundation are system frameworks)

---

## Privacy & Permissions

**All processing is on-device.** No audio data leaves the Mac.

### Required Permissions

```
NSMicrophoneUsageDescription: "SeleneChat uses your microphone for voice input"
NSSpeechRecognitionUsageDescription: "SeleneChat transcribes your speech on-device to text"
```

### First-Time Flow

1. User taps mic button for the first time
2. macOS prompts for microphone access
3. macOS prompts for speech recognition access
4. Permissions granted -- never asked again

### Graceful Degradation

- Permissions denied: mic button shows disabled + "Enable in System Settings" tooltip
- Speech unavailable: fall back to macOS dictation (Fn Fn)
- Mic busy: brief "Microphone busy" indicator

---

## Phasing

### Phase 1: Core Voice Input (this design)

- `SpeechRecognitionService` with on-device `SFSpeechRecognizer`
- `VoiceMicButton` in ChatView
- Live streaming transcription into TextField
- Silence timeout + manual stop
- Mic/speech permission handling
- URL scheme `selene://voice` registration

### Phase 2: Global Access

- Global hotkey (`Cmd+Shift+Space`)
- Bring SeleneChat to front + activate mic
- Stream Deck button configuration

### Phase 3: Voice-Aware Chat Modes

- Capture mode (`selene://capture`) -- voice saves as new note
- Refine mode -- Selene asks follow-up questions after voice dump
- Separate Stream Deck buttons per mode

### Phase 4: Voxtral Upgrade

- Add Mistral Voxtral Realtime (4B, Apache 2.0) as alternative engine
- Engine selection: auto or manual toggle
- Better accuracy for long-form dictation

### Phase 5: Smart TTS Responses

- macOS `AVSpeechSynthesizer` for reading responses aloud
- Auto-detect: voice input triggers voice response, typed triggers text
- Voice/volume settings

---

## Acceptance Criteria

### Phase 1

- [ ] Mic button visible in ChatView next to text input
- [ ] Tapping mic button starts on-device speech recognition
- [ ] Words stream into text field in real-time as user speaks
- [ ] 2-second silence timeout stops recording
- [ ] Tapping mic button again stops recording manually
- [ ] Transcribed text is editable before sending
- [ ] Enter sends transcribed text through normal chat pipeline
- [ ] Escape clears transcription and cancels
- [ ] `selene://voice` URL scheme opens app and activates mic
- [ ] Microphone and speech recognition permissions handled gracefully
- [ ] All speech processing is on-device (no network calls)

### ADHD Check

- [x] Reduces friction -- voice is faster than typing
- [x] Visual feedback -- live transcription provides immediate confirmation
- [x] Externalizes cognition -- speak to think, see words appear
- [x] Physical activation -- Stream Deck button is zero-thought activation
- [x] Non-destructive -- review before send, Escape to bail out

### Scope Check

- [x] Phase 1 is < 1 week: 3 new Swift files, minor changes to 3 existing files
- [x] No new dependencies
- [x] No database changes
- [x] No backend changes
