# Voice Memo Transcription Pipeline

**Date:** 2026-02-12
**Status:** Ready
**Topic:** automation, voice-capture

---

## Problem

Voice Memos is the lowest-friction capture tool on Apple devices — one tap to record a thought. But recordings sit in the Voice Memos app unprocessed. For someone with ADHD, an unprocessed voice memo is a lost thought. The audio never gets revisited because it requires active effort to listen back and extract meaning.

## Solution

A background automation that watches for new Voice Memos, transcribes them locally via whisper.cpp, saves markdown transcripts, and feeds them into Selene's pipeline for concept extraction, embeddings, and thread detection.

Zero interaction required after setup. Record a thought, forget about it — Selene handles the rest.

## Architecture

### Data Flow

```
~/Library/Group Containers/group.com.apple.VoiceMemos.shared/Recordings/
    |  (launchd WatchPaths detects change)
    v
src/workflows/transcribe-voice-memos.ts
    |
    +-- 1. Scan dir for .m4a files
    +-- 2. Check ~/VoiceMemos/.processed.json -- skip known files
    +-- 3. For each new file:
    |     a. ffmpeg: convert .m4a -> WAV 16kHz mono (temp file)
    |     b. whisper.cpp: transcribe WAV -> text
    |     c. Copy .m4a to ~/VoiceMemos/archive/{date}-{name}.m4a
    |     d. Write markdown to ~/VoiceMemos/transcripts/{date}-{name}.md
    |     e. POST to http://localhost:5678/webhook/api/drafts
    |     f. Update .processed.json
    |     g. Clean up temp WAV
    |
    +-- 4. Retry any previously failed Selene ingestions
    +-- 5. On error: macOS notification via osascript
```

The workflow is idempotent. `.processed.json` is updated only after each file completes all steps. If the process crashes mid-run, it picks up where it left off.

### New Files

```
src/workflows/transcribe-voice-memos.ts          # Main workflow
scripts/setup-whisper.sh                          # Install whisper.cpp + model + dirs + launchd
launchd/com.selene.transcribe-voice-memos.plist   # File watcher agent
```

### Output Structure

```
~/VoiceMemos/
  archive/          # Original .m4a files (preserved)
  transcripts/      # Markdown notes
  .processed.json   # Tracking manifest
```

### Manifest Format

```json
{
  "files": {
    "20260212 153045.m4a": {
      "transcribedAt": "2026-02-12T15:31:02Z",
      "archivedTo": "~/VoiceMemos/archive/2026-02-12-153045.m4a",
      "markdownPath": "~/VoiceMemos/transcripts/2026-02-12-153045.md",
      "ingestedToSelene": true
    }
  }
}
```

## Whisper.cpp Integration

**Installation path:** `~/.local/whisper.cpp/`
**Model:** `ggml-medium.bin` (~1.5GB) — best accuracy/speed tradeoff for casual speech and ADHD brain dumps.
**Metal acceleration:** Enabled by default on Apple Silicon via `WHISPER_METAL=ON` cmake flag.

**CLI invocation:**

```bash
~/.local/whisper.cpp/main \
  -m ~/.local/whisper.cpp/models/ggml-medium.bin \
  -f /tmp/recording.wav \
  --output-txt \
  --no-timestamps \
  --language en \
  --threads 6
```

**Format conversion:** Voice Memos saves `.m4a` (AAC). Whisper.cpp requires WAV 16kHz mono.

```bash
ffmpeg -i input.m4a -ar 16000 -ac 1 -c:a pcm_s16le /tmp/output.wav
```

**Performance:** ~60-90 seconds for a 30-minute recording on M-series with medium model.
**Timeout:** 10 minutes per file as a safety net.

## Markdown Output

```markdown
# Voice Memo: {friendly-name} -- {date}

**Recorded:** {timestamp}
**Duration:** {duration from ffprobe}
**Audio:** [Original recording](~/VoiceMemos/archive/{filename}.m4a)

---

{full transcription text}
```

## Selene Integration

POST to existing webhook after transcription:

```json
{
  "title": "Voice Memo: {friendly-name} -- {date}",
  "content": "{full transcription text}",
  "tags": ["voice-memo"],
  "source": "voice-memos"
}
```

This feeds memos into the full Selene pipeline:
- Concept extraction via Ollama
- Embedding generation
- Association computation
- Thread detection
- Daily summary inclusion

The `voice-memo` tag enables filtering in SeleneChat.

**Retry logic:** If the webhook POST fails (server down), the markdown and archive are still saved. The manifest marks `ingestedToSelene: false`. On subsequent runs, the workflow retries failed ingestions.

## launchd Agent

**Trigger:** `WatchPaths` on the Voice Memos recordings directory.
**Throttle:** 10 seconds (debounce rapid file writes during recording).

**Skip in-progress recordings:**
1. Skip files smaller than 1KB
2. Skip files modified within the last 5 seconds

### Error Handling

| Scenario | Behavior |
|----------|----------|
| whisper.cpp not installed | Log error, send notification, exit |
| ffmpeg not found | Log error, send notification, exit |
| Conversion fails | Log, notify, skip file, continue |
| Transcription fails/times out | Log, notify, skip file, continue |
| Webhook POST fails | Save markdown + archive, mark for retry |
| Disk full | Log, notify, exit |

Notifications are macOS-native via `osascript -e 'display notification'`. Only sent on errors.

## Setup Script

`scripts/setup-whisper.sh` — single command from zero to working:

1. **Check prerequisites** — Apple Silicon, ffmpeg (prompt brew install if missing), Xcode CLI tools
2. **Install whisper.cpp** — clone to `~/.local/whisper.cpp/`, build with Metal
3. **Download model** — `ggml-medium.bin` with checksum verification
4. **Create directories** — `~/VoiceMemos/{archive,transcripts}`, initialize `.processed.json`
5. **Install launchd agent** — copy plist, `launchctl load`
6. **Smoke test** — transcribe a silent WAV to verify the pipeline works

## ADHD Check

- **Reduces friction?** Yes — zero interaction after setup. Record and forget.
- **Externalizes cognition?** Yes — spoken thoughts become searchable text, join threads automatically.
- **Makes information visible?** Yes — voice memos become part of daily summaries and thread context.

## Acceptance Criteria

1. New .m4a files in Voice Memos directory are automatically detected and transcribed
2. Transcription produces readable text from casual speech (whisper.cpp medium model)
3. Markdown note is saved to `~/VoiceMemos/transcripts/` with metadata and audio link
4. Original .m4a is archived to `~/VoiceMemos/archive/`
5. Transcription is POSTed to Selene webhook and appears in pipeline
6. Already-processed files are never transcribed twice
7. In-progress recordings are not picked up prematurely
8. Failed Selene ingestions are retried on subsequent runs
9. Errors produce macOS notifications
10. `setup-whisper.sh` installs everything from scratch on a clean Apple Silicon Mac

## Scope Check

Estimated < 1 week:
- Workflow script: ~200-300 lines TypeScript
- Setup script: ~100 lines bash
- launchd plist: ~20 lines XML
- Testing: manual end-to-end (record memo, verify transcript + Selene ingestion)

## Dependencies

- **whisper.cpp** — installed by setup script
- **ffmpeg** — checked by setup script, installed via Homebrew if missing
- **Existing Selene infra** — logger, config, webhook server (all in place)
- No new npm packages required
