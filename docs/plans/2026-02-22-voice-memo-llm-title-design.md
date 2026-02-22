# Voice Memo LLM Title Generation Design

**Status:** Ready
**Created:** 2026-02-22
**Updated:** 2026-02-22

---

## Problem

Voice memos arrive in Drafts with generic titles like "Voice Memo 2026-02-22 15:30". This tells you nothing about what you actually said. For someone with ADHD, scanning a list of identically-formatted titles requires opening each one to remember the content — the opposite of externalizing memory.

---

## Solution

After whisper.cpp transcribes a voice memo, call Ollama to generate a short descriptive title (5-8 words) from the transcription text. Use this title when sending to Drafts instead of the timestamp-based title. Falls back to the timestamp title if Ollama is unavailable.

---

## Design

### Flow

```
Current:  transcribe -> title = "Voice Memo 2026-02-22 15:30" -> send to Drafts
Proposed: transcribe -> LLM generates title -> send to Drafts
                         | (on failure)
                         v
                       title = "Voice Memo 2026-02-22 15:30" -> send to Drafts
```

### LLM Prompt

```
Summarize this voice memo transcription as a short, descriptive title (5-8 words).
Return ONLY the title, no quotes or punctuation at the end.

Transcription:
<first ~500 chars of transcription>
```

Input is capped at ~500 characters to keep the prompt small and fast. Voice memo topics are typically established in the opening sentences.

### Fallback Behavior

- Ollama unreachable or errors: use timestamp title
- Empty transcription: use timestamp title
- LLM returns empty or malformed response: use timestamp title

### Files Touched

1. `src/workflows/transcribe-voice-memos.ts` — add import for `generate` from `../lib/ollama`, add local `generateMemoTitle()` function, call it in `processMemo()` after transcription (between current Step 2 and Step 3)

No other files change. The existing `ollama.generate()` API supports everything needed.

---

## Implementation Notes

- The `generate()` function in `src/lib/ollama.ts` already supports `temperature` and `maxTokens` options. Use low temperature (~0.3) for consistent titles and cap tokens (~20) to prevent runaway generation.
- The title generation adds ~5-10 seconds per memo. Since whisper.cpp transcription already takes minutes, this is negligible.
- The markdown transcript file retains the timestamp-based title (unchanged) since it serves as a reference record, not a glanceable inbox item.

---

## Ready for Implementation Checklist

Before creating a branch, all items must be checked:

- [x] **Acceptance criteria defined** - How do we know it's done?
- [x] **ADHD check passed** - See below
- [x] **Scope check** - Can ship in < 1 week of focused work? (< 1 hour)
- [x] **No blockers** - Ollama and whisper.cpp already working

### Acceptance Criteria

- [ ] Voice memo sent to Drafts has an LLM-generated descriptive title instead of "Voice Memo YYYY-MM-DD HH:MM"
- [ ] If Ollama is unavailable, the memo still processes with the timestamp fallback title
- [ ] If transcription is empty, the timestamp fallback title is used

### ADHD Design Check

- [x] **Reduces friction?** No extra steps — title is generated automatically during existing pipeline
- [x] **Visible?** Meaningful titles make voice memo content scannable at a glance in Drafts
- [x] **Externalizes cognition?** The system names your thoughts so you don't have to remember what each memo was about

---

## Links

- **Branch:** (added when implementation starts)
- **PR:** (added when complete)
