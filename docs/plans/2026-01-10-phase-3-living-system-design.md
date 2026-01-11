# Phase 3: Living System — Design Document

**Date:** 2026-01-10
**Status:** Approved
**Scope:** Minimal viable — summary updates + momentum calculation only

---

## Overview

**Goal:** Make the thread system "living" by processing notes continuously and keeping thread summaries current.

**What we're building:**
- Adjust launchd intervals for faster processing
- Build reconsolidation workflow (summary updates + momentum)
- Schedule reconsolidation hourly

**What we're NOT building yet:**
- Thread merging
- Thread splitting
- Stale thread archiving

**End state:** A new note captured at 2pm will be embedded, associated, and part of a thread by 3pm. Thread summaries reflect the latest thinking. Momentum scores show which threads are active.

---

## Files

**New:**
- `src/workflows/reconsolidate-threads.ts`
- `launchd/com.selene.reconsolidate-threads.plist`

**Modified:**
- `launchd/com.selene.compute-embeddings.plist` (interval: 10min → 5min)
- `launchd/com.selene.compute-associations.plist` (interval: 10min → 5min)
- `launchd/com.selene.detect-threads.plist` (daily → every 30min)

**No database schema changes required.**

---

## Launchd Interval Changes

| Workflow | Current | New |
|----------|---------|-----|
| compute-embeddings | 10 min | 5 min |
| compute-associations | 10 min | 5 min |
| detect-threads | Daily 6am | Every 30 min |
| reconsolidate-threads | (new) | Hourly |

**Processing timeline for a new note:**

```
0:00  — Note captured via webhook
0:05  — Embedding generated
0:10  — Associations computed
0:30  — Thread detection runs, note joins thread
1:00  — Reconsolidation updates thread summary
```

Worst case: ~1 hour from capture to fully integrated. Typical: ~30-40 minutes.

---

## Reconsolidation Workflow Logic

**File:** `src/workflows/reconsolidate-threads.ts`

**Trigger:** Hourly via launchd

**Process:**

```
1. Find threads needing update
   SELECT threads WHERE updated_at < (
     SELECT MAX(added_at) FROM thread_notes WHERE thread_id = threads.id
   )

2. For each thread needing update:
   a. Gather all notes in thread (max 15, prioritize recent)
   b. Get previous summary and why
   c. Call Ollama to resynthesize
   d. Update thread record (summary, why, updated_at)

3. Calculate momentum for ALL active threads
   For each thread WHERE status = 'active':
     notes_7_days = COUNT notes added in last 7 days
     notes_30_days = COUNT notes added in last 30 days
     sentiment_avg = AVG sentiment intensity from thread notes

     momentum = (notes_7_days × 2) + (notes_30_days × 1) + (sentiment_avg × 0.5)

     UPDATE thread SET momentum_score = momentum

4. Log summary: "Updated N thread summaries, recalculated M momentum scores"
```

**Error handling:** If Ollama fails for one thread, log error and continue to next. Never block the whole run.

---

## Ollama Prompt for Summary Updates

```
System: You analyze threads of thinking from personal notes.

User:
Thread: [current name]
Previous summary: [current summary]
Previous "why": [current why]

Notes in this thread (newest first):
---
[2026-01-10] [note content]
---
[2026-01-08] [note content]
---
[... up to 15 notes]

Questions:
1. Has the direction of this thread shifted with the new notes?
2. What is the updated summary of this thread?
3. Has the underlying motivation become clearer or changed?

Respond in JSON only:
{
  "name": "...",
  "summary": "...",
  "why": "...",
  "direction": "exploring|emerging|clear",
  "shifted": true/false
}
```

**Notes:**
- Keep prompt under 4K tokens (15 notes is safe limit)
- Model: mistral:7b (same as other workflows)
- Parse JSON response, update thread record
- If `shifted: true`, log it for potential user notification later

---

## Momentum Formula

```
momentum = (notes_7_days × 2) + (notes_30_days × 1) + (sentiment_intensity × 0.5)
```

Simple formula from original thread system design. No recency bonus or velocity calculation for now.

---

## Implementation Order

1. Create `src/workflows/reconsolidate-threads.ts`
2. Create `launchd/com.selene.reconsolidate-threads.plist`
3. Update existing plists (intervals)
4. Test end-to-end with a test note
5. Reinstall launchd agents

**Estimated scope:** ~150 lines TypeScript, 4 plist changes.

---

## Future Enhancements (Not in Scope)

- Thread merging (combine threads with >0.85 similarity + shared notes)
- Thread splitting (break apart threads with clear sub-clusters)
- Stale archiving (mark threads inactive after 60 days)
- User notifications when thread direction shifts

---

## Success Criteria

1. New note is fully processed within 1 hour
2. Thread summaries update automatically when notes are added
3. Momentum scores reflect recent activity
4. No manual intervention required
