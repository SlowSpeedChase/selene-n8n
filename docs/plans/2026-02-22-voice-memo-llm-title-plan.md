# Voice Memo LLM Title Generation — Implementation Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** Replace generic "Voice Memo YYYY-MM-DD HH:MM" Drafts titles with LLM-generated descriptive titles.

**Architecture:** After whisper.cpp transcription completes, call `ollama.generate()` with a title-summarization prompt. Use the result as the Drafts title. Fall back to the timestamp title on any failure. Single-file change.

**Tech Stack:** TypeScript, Ollama (mistral:7b), existing `generate()` from `src/lib/ollama.ts`

**Design doc:** `docs/plans/2026-02-22-voice-memo-llm-title-design.md`

---

### Task 1: Add Ollama import

**Files:**
- Modify: `src/workflows/transcribe-voice-memos.ts:1-6` (imports block)

**Step 1: Add the import**

Add `generate` from the Ollama client alongside the existing imports:

```typescript
import { generate } from '../lib/ollama';
```

Add this after line 5 (`import { config } from '../lib/config';`), before the types import.

**Step 2: Verify it compiles**

Run: `npx tsc --noEmit src/workflows/transcribe-voice-memos.ts`
Expected: No errors (generate is exported from ollama.ts and unused imports are allowed)

**Step 3: Commit**

```bash
git add src/workflows/transcribe-voice-memos.ts
git commit -m "chore: add ollama import to voice memo workflow"
```

---

### Task 2: Add generateMemoTitle() function

**Files:**
- Modify: `src/workflows/transcribe-voice-memos.ts` — add new function after the `getAudioDuration()` function (after line 234)

**Step 1: Write the function**

Insert this function between `getAudioDuration()` (ends line 234) and `sendToDrafts()` (starts line 240):

```typescript
// ---------------------------------------------------------------------------
// LLM title generation
// ---------------------------------------------------------------------------

const TITLE_PROMPT_TEMPLATE = `Summarize this voice memo transcription as a short, descriptive title (5-8 words).
Return ONLY the title, no quotes or punctuation at the end.

Transcription:
`;

const MAX_TRANSCRIPTION_CHARS = 500;

async function generateMemoTitle(transcription: string, fallbackTitle: string): Promise<string> {
  if (!transcription.trim()) {
    log.info('Empty transcription, using fallback title');
    return fallbackTitle;
  }

  try {
    const truncated = transcription.slice(0, MAX_TRANSCRIPTION_CHARS);
    const prompt = TITLE_PROMPT_TEMPLATE + truncated;

    const result = await generate(prompt, {
      temperature: 0.3,
      maxTokens: 20,
      timeoutMs: 15000,
    });

    const title = result.trim().replace(/[."']+$/g, '');

    if (!title || title.length < 3) {
      log.warn({ result }, 'LLM returned empty/short title, using fallback');
      return fallbackTitle;
    }

    log.info({ generatedTitle: title }, 'Generated LLM title for voice memo');
    return title;
  } catch (err) {
    const error = err as Error;
    log.warn({ err: error }, 'Failed to generate LLM title, using fallback');
    return fallbackTitle;
  }
}
```

**Key decisions in this code:**
- `temperature: 0.3` — low creativity for consistent, factual titles
- `maxTokens: 20` — prevents runaway generation (5-8 words is ~10-15 tokens)
- `timeoutMs: 15000` — 15 second timeout (generous but won't block forever)
- `slice(0, 500)` — caps input to keep prompt small and fast
- Trailing punctuation stripped with regex (LLMs often add quotes/periods)
- Returns `fallbackTitle` on ANY failure — never throws

**Step 2: Verify it compiles**

Run: `npx tsc --noEmit src/workflows/transcribe-voice-memos.ts`
Expected: No errors

**Step 3: Commit**

```bash
git add src/workflows/transcribe-voice-memos.ts
git commit -m "feat: add generateMemoTitle function for LLM voice memo titles"
```

---

### Task 3: Wire generateMemoTitle into processMemo()

**Files:**
- Modify: `src/workflows/transcribe-voice-memos.ts:317-318` (inside `processMemo()`, the title assignment)

**Step 1: Replace the hardcoded title**

Find this code in `processMemo()` (currently line 317-318):

```typescript
    // Step 6: Send to Drafts for review
    const title = `Voice Memo ${parsed.friendlyName}`;
```

Replace with:

```typescript
    // Step 6: Generate title and send to Drafts for review
    const fallbackTitle = `Voice Memo ${parsed.friendlyName}`;
    const title = await generateMemoTitle(transcription, fallbackTitle);
```

**Step 2: Verify it compiles**

Run: `npx tsc --noEmit src/workflows/transcribe-voice-memos.ts`
Expected: No errors

**Step 3: Commit**

```bash
git add src/workflows/transcribe-voice-memos.ts
git commit -m "feat: use LLM-generated titles for voice memos in Drafts"
```

---

### Task 4: Manual integration test

**Step 1: Ensure Ollama is running**

Run: `curl -s http://localhost:11434/api/tags | head -c 200`
Expected: JSON with model list including `mistral`

**Step 2: Test the title generation in isolation**

Run a quick Node REPL test to verify the prompt works:

```bash
npx ts-node -e "
import { generate } from './src/lib/ollama';
const prompt = \`Summarize this voice memo transcription as a short, descriptive title (5-8 words).
Return ONLY the title, no quotes or punctuation at the end.

Transcription:
I was thinking about meal prep for next week. I want to try making that Thai basil chicken recipe again, and maybe do some rice bowls. Also need to pick up groceries on Saturday.\`;
generate(prompt, { temperature: 0.3, maxTokens: 20, timeoutMs: 15000 }).then(r => console.log('Title:', r.trim()));
"
```

Expected: A short title like "Weekend Meal Prep Planning" or similar (5-8 words, descriptive)

**Step 3: Test fallback by stopping Ollama**

Run: `launchctl stop com.selene.ollama` (or however Ollama is managed)
Then test that the function gracefully falls back — this will be verified naturally the next time a voice memo is recorded while Ollama is down.

**Step 4: Final commit with any adjustments**

If the prompt needed tweaking based on test output:

```bash
git add src/workflows/transcribe-voice-memos.ts
git commit -m "fix: adjust voice memo title prompt based on testing"
```

---

### Done Checklist

- [ ] `generate` imported from `../lib/ollama`
- [ ] `generateMemoTitle()` function handles: empty transcription, LLM failure, empty LLM response
- [ ] `processMemo()` calls `generateMemoTitle()` and passes result to `sendToDrafts()`
- [ ] Manual test produces reasonable 5-8 word titles
- [ ] Fallback to timestamp title works when Ollama is unavailable
