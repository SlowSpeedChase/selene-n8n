# iMessage Daily Digest

**Status:** Ready
**Created:** 2026-02-02
**Topic:** notifications

## Problem

Selene generates daily summaries at midnight and writes them to Obsidian, but you have to open Obsidian to see them. Summaries are multi-paragraph markdown — not suited for quick consumption. The value of daily pattern detection is lost if you don't actively check.

## Solution

Send a condensed daily digest to your phone via iMessage at 6am. The summary is already generated at midnight — a new workflow reads it, condenses it to bullet points via Ollama, and sends it via AppleScript. Zero new infrastructure: macOS + iMessage handles delivery with end-to-end encryption.

## Architecture

```
Midnight (existing)                    6am (new)
daily-summary.ts                       send-digest.ts
  ├─ Query day's notes                   ├─ Read digest text file
  ├─ Generate full summary (Ollama)      ├─ Send via osascript/iMessage
  ├─ Write Obsidian markdown             └─ Log result
  ├─ Generate condensed digest (Ollama)
  └─ Write digest text file
```

Two launchd jobs, loosely coupled via a text file on disk.

## Changes

### 1. Modify `src/workflows/daily-summary.ts`

After writing the Obsidian file, add:

- Second Ollama prompt that takes the full summary and produces 3-5 bullet points (< 300 chars total)
- Write condensed output to `data/digests/YYYY-MM-DD-digest.txt`
- Fallback: if Ollama is down, use mechanical format (`X notes. Themes: A, B, C.`)

Condensed prompt:
```
Condense this daily summary into 3-5 short bullet points for a text message.
Be brief and actionable. No headers or formatting.

{summary}
```

### 2. New file: `src/workflows/send-digest.ts`

Reads the latest digest file and sends via iMessage.

```typescript
import { execSync } from 'child_process';
import { readFileSync, existsSync } from 'fs';
import { join } from 'path';
import { createWorkflowLogger, config } from '../lib';

const log = createWorkflowLogger('send-digest');

function sendIMessage(to: string, message: string): void {
  // Escape double quotes and backslashes for AppleScript
  const escaped = message.replace(/\\/g, '\\\\').replace(/"/g, '\\"');
  execSync(`osascript -e '
    tell application "Messages"
      set targetService to 1st account whose service type = iMessage
      set targetBuddy to participant "${to}" of targetService
      send "${escaped}" to targetBuddy
    end tell
  '`);
}

export async function sendDigest(): Promise<void> {
  const to = process.env.IMESSAGE_DIGEST_TO;
  const enabled = process.env.IMESSAGE_DIGEST_ENABLED !== 'false';

  if (!enabled || !to) {
    log.info('Digest disabled or no recipient configured');
    return;
  }

  const dateStr = new Date().toISOString().split('T')[0];
  const digestPath = join(config.projectRoot, 'data', 'digests', `${dateStr}-digest.txt`);

  if (!existsSync(digestPath)) {
    log.info('No digest file found, skipping');
    return;
  }

  const message = readFileSync(digestPath, 'utf-8').trim();
  if (!message) {
    log.info('Empty digest, skipping');
    return;
  }

  try {
    sendIMessage(to, message);
    log.info({ to }, 'Digest sent via iMessage');
  } catch (err) {
    log.error({ err }, 'Failed to send iMessage');
  }
}
```

### 3. New launchd plist: `launchd/com.selene.send-digest.plist`

Runs `send-digest.ts` at 6am daily.

### 4. Configuration

Add to `.env`:
```
IMESSAGE_DIGEST_TO=+1XXXXXXXXXX
IMESSAGE_DIGEST_ENABLED=true
```

## Edge Cases

- **No notes that day** — `daily-summary.ts` already skips when no notes exist. No digest file written, no iMessage sent.
- **Ollama down** — Mechanical fallback for condensed format (note count + themes).
- **Mac asleep at 6am** — launchd runs it when Mac wakes. Digest arrives late but not lost.
- **iMessage send fails** — Log error, exit gracefully. No retry (it's a daily digest, not critical).

## ADHD Check

- **Reduces friction?** Yes — digest comes to you, zero apps to open
- **Externalizes cognition?** Yes — yesterday's patterns surfaced without effort
- **Makes info visible?** Yes — bullet points on your lock screen
- **Realistic?** Yes — no new accounts, services, or infrastructure

## Acceptance Criteria

- [ ] Daily summary generates condensed bullet-point digest file
- [ ] `send-digest.ts` sends digest via iMessage to configured number
- [ ] Launchd plist runs send-digest at 6am
- [ ] No iMessage sent on days with zero notes
- [ ] Fallback to mechanical format when Ollama is unavailable
- [ ] `IMESSAGE_DIGEST_ENABLED=false` prevents sending

## Scope Check

Three files changed/added. No new dependencies. Under a day of work.
