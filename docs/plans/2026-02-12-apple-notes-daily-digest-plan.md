# Apple Notes Daily Digest Implementation Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** Replace iMessage digest delivery with a pinned Apple Notes note updated daily at 6am.

**Architecture:** Modify `send-digest.ts` to use AppleScript targeting Apple Notes instead of Messages.app. The digest generation pipeline (daily-summary.ts) and launchd scheduling are unchanged. Config cleanup removes iMessage-specific properties.

**Tech Stack:** TypeScript, AppleScript (osascript), Apple Notes, launchd

---

### Task 1: Add `digestToHtml()` helper and `updateAppleNote()` function

**Files:**
- Modify: `src/workflows/send-digest.ts` (replace `sendIMessage` with new functions)

**Step 1: Write `digestToHtml()` — converts plain text digest to Apple Notes HTML**

Replace the `sendIMessage` function (lines 8-31) with these two new functions:

```typescript
function digestToHtml(digestText: string, date: string): string {
  const lines = digestText.split('\n').filter((l) => l.trim());
  const bodyHtml = lines.map((line) => `<p>${line}</p>`).join('\n');

  return `<h1>Selene Daily</h1>
<p style="color: #888; font-size: 14px;">Updated: ${date}</p>
<hr>
${bodyHtml}`;
}

function updateAppleNote(noteName: string, htmlBody: string): void {
  // Escape for AppleScript: backslashes, double quotes, backslash-n for newlines
  const escaped = htmlBody
    .replace(/\\/g, '\\\\')
    .replace(/"/g, '\\"')
    .replace(/\n/g, '\\n');

  const script = `osascript -e 'tell application "Notes"' \
    -e 'set noteName to "Selene Daily"' \
    -e 'set noteBody to "${escaped}"' \
    -e 'try' \
    -e 'set targetNote to first note whose name is noteName' \
    -e 'set body of targetNote to noteBody' \
    -e 'on error' \
    -e 'make new note with properties {name:noteName, body:noteBody}' \
    -e 'end try' \
    -e 'end tell'`;

  execSync(script, { timeout: 15000, stdio: 'pipe' });
}
```

**Step 2: Verify the file compiles**

Run: `npx tsc --noEmit src/workflows/send-digest.ts`
Expected: No errors (the new functions aren't called yet, old ones removed)

**Step 3: Commit**

```bash
git add src/workflows/send-digest.ts
git commit -m "feat(digest): add Apple Notes HTML helper and update function"
```

---

### Task 2: Rewire `sendDigest()` to use Apple Notes

**Files:**
- Modify: `src/workflows/send-digest.ts` (the `sendDigest` export function)

**Step 1: Replace iMessage logic with Apple Notes call**

Replace the body of `sendDigest()` (lines 33-79) with:

```typescript
export async function sendDigest(): Promise<{ sent: boolean; writtenToFile?: string }> {
  log.info({ env: config.env }, 'Starting send-digest');

  // In test mode, write to file instead of posting to Apple Notes
  if (config.isTestEnv) {
    return sendDigestToFile();
  }

  // Look for today's digest, fall back to yesterday's
  const today = new Date().toISOString().split('T')[0];
  const yesterday = new Date(Date.now() - 86400000).toISOString().split('T')[0];

  let digestPath = join(config.digestsPath, `${today}-digest.txt`);
  if (!existsSync(digestPath)) {
    digestPath = join(config.digestsPath, `${yesterday}-digest.txt`);
  }

  if (!existsSync(digestPath)) {
    log.info('No digest file found, skipping');
    return { sent: false };
  }

  const message = readFileSync(digestPath, 'utf-8').trim();
  if (!message) {
    log.info('Empty digest, skipping');
    return { sent: false };
  }

  try {
    const dateStr = new Date().toLocaleDateString('en-US', {
      weekday: 'long',
      year: 'numeric',
      month: 'long',
      day: 'numeric',
    });
    const html = digestToHtml(message, dateStr);
    updateAppleNote('Selene Daily', html);
    log.info('Digest posted to Apple Notes');
    return { sent: true };
  } catch (err) {
    log.error({ err }, 'Failed to post digest to Apple Notes');
    return { sent: false };
  }
}
```

**Step 2: Update the test-mode log message in `sendDigestToFile`**

In `sendDigestToFile()`, change the log message from:
```typescript
log.info('Test mode: writing digest to file instead of iMessage');
```
to:
```typescript
log.info('Test mode: writing digest to file instead of Apple Notes');
```

**Step 3: Verify it compiles**

Run: `npx tsc --noEmit src/workflows/send-digest.ts`
Expected: No errors

**Step 4: Commit**

```bash
git add src/workflows/send-digest.ts
git commit -m "feat(digest): rewire sendDigest to post to Apple Notes"
```

---

### Task 3: Clean up iMessage config

**Files:**
- Modify: `src/lib/config.ts:85-87` (remove iMessage properties)
- Modify: `src/workflows/daily-summary.ts:145` (update comment)

**Step 1: Remove iMessage config properties**

In `src/lib/config.ts`, replace lines 85-87:

```typescript
  // iMessage digest - disabled in test mode
  imessageDigestTo: process.env.IMESSAGE_DIGEST_TO || '',
  imessageDigestEnabled: !isTestEnv && process.env.IMESSAGE_DIGEST_ENABLED !== 'false',
```

with:

```typescript
  // Apple Notes digest - disabled in test mode
  appleNotesDigestEnabled: !isTestEnv && process.env.APPLE_NOTES_DIGEST_ENABLED !== 'false',
```

**Step 2: Update comment in daily-summary.ts**

In `src/workflows/daily-summary.ts`, line 145, change:
```typescript
  // Generate condensed digest for iMessage
```
to:
```typescript
  // Generate condensed digest for Apple Notes
```

**Step 3: Verify full project compiles**

Run: `npx tsc --noEmit`
Expected: No errors

**Step 4: Commit**

```bash
git add src/lib/config.ts src/workflows/daily-summary.ts
git commit -m "chore: clean up iMessage config, replace with Apple Notes"
```

---

### Task 4: Manual smoke test

**Step 1: Create a test digest file**

```bash
mkdir -p data/digests
echo "Your week had 12 captured notes across 3 themes: productivity systems, ADHD management, and project planning. The strongest thread was around building better capture habits." > data/digests/$(date +%Y-%m-%d)-digest.txt
```

**Step 2: Run send-digest manually**

```bash
npx ts-node src/workflows/send-digest.ts
```

Expected: Output says "Digest posted to Apple Notes". Apple Notes app opens/shows a note called "Selene Daily" with formatted content.

**Step 3: Verify the note exists in Apple Notes**

Open Apple Notes. You should see a note called "Selene Daily" with:
- Title "Selene Daily"
- Date line with today's date
- The digest text as paragraphs

**Step 4: Pin the note (one-time setup)**

Right-click the "Selene Daily" note in Apple Notes and select "Pin Note".

**Step 5: Run again to verify overwrite works**

```bash
echo "Updated content - this should replace the previous note." > data/digests/$(date +%Y-%m-%d)-digest.txt
npx ts-node src/workflows/send-digest.ts
```

Expected: Same note, new content. Still pinned.

**Step 6: Clean up test digest**

```bash
rm data/digests/$(date +%Y-%m-%d)-digest.txt
```

**Step 7: Commit final state**

```bash
git add -A
git commit -m "feat: Apple Notes daily digest - replaces iMessage delivery

Selene Daily note in Apple Notes gets overwritten each morning at 6am
with the processed daily summary. Pin once, always visible."
```

---

### Task 5: Verify launchd schedule unchanged

**Step 1: Confirm the send-digest plist is correct**

```bash
cat launchd/com.selene.send-digest.plist
```

Expected: Still shows `StartCalendarInterval` at hour 6. No changes needed since we only modified the TypeScript, not the scheduler.

**Step 2: Verify the agent is loaded**

```bash
launchctl list | grep send-digest
```

Expected: Shows the loaded agent.

Done. The daily summary still generates at midnight. At 6am, launchd fires `send-digest.ts` which now posts to Apple Notes instead of iMessage.
