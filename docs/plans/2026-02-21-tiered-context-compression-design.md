# Tiered Context Compression Design

**Status:** Ready
**Created:** 2026-02-21
**Updated:** 2026-02-21

---

## Problem

As note volume grows, Selene's LLM workflows face a fundamental scaling problem: every workflow injects raw note text into prompts with no context window management. Thread synthesis caps at 15 notes. Daily summaries truncate to 100 characters. The system has no way to represent 500 notes efficiently to a model with a small context window.

Library science and archival theory provide the answer: **not all information needs the same fidelity at the same time.** Ranganathan's Fifth Law ("a library is a growing organism") tells us the organizational scheme must evolve with the collection. Archival macro-appraisal theory tells us to assess value over time and re-appraise periodically. Forte's Progressive Summarization tells us to compress in layers as information ages.

The goal: a model-agnostic information compression layer that makes Selene's local LLM pipeline scale with growing note volume, regardless of which model sits behind Ollama.

---

## Solution

**Lifecycle-based fidelity tiers.** Every note progresses through compression levels as it ages, and workflows assemble context by picking the right representation per tier within a token budget.

```
Note Age / Activity          Fidelity Level    What's Sent to LLM
--------------------------------------------------------------------
Fresh (< 7 days)             FULL              Raw text + all metadata
Warm (7-90 days, active)     HIGH              Raw text + essence
Cool (90+ days, inactive)    SUMMARY           Essence + themes only
Cold (archived threads)      SKELETON           Title + primary_theme
```

Raw text is never deleted. Tiers control what goes into LLM prompts, not what's stored on disk.

---

## Design

### 1. Data Model

Additive columns only. No migrations that touch existing data.

**`processed_notes` — new columns:**

```sql
essence TEXT,                              -- 1-2 sentence distillation
essence_at DATETIME,                       -- when essence was computed
fidelity_tier TEXT DEFAULT 'full',         -- 'full'|'high'|'summary'|'skeleton'
fidelity_evaluated_at DATETIME             -- last tier evaluation
```

**`threads` — new column:**

```sql
thread_digest TEXT                         -- paragraph-length thread narrative
```

**`essence`** is the workhorse — a 1-2 sentence distillation of the note's core meaning, computed once by the LLM and reused across all workflows.

**`fidelity_tier`** is metadata that tells the context assembly layer which representation to use. It does not affect storage.

**`thread_digest`** is the thread-level equivalent of essence. A mature thread with 40 notes becomes a single paragraph, consuming the same context budget as a 3-note thread.

### 2. Workflows

#### New: `distill-essences.ts`

- **Schedule:** Every 5 minutes
- **Trigger:** `processed_notes` rows where `essence IS NULL`
- **Batch size:** 10 notes per run
- **What it does:** Sends title + content + already-extracted concepts/themes to the LLM. Prompt asks for a 1-2 sentence distillation capturing what this note means to the person who wrote it. Existing metadata guides distillation for higher quality.
- **Backfill:** Handles existing notes naturally — all have `essence IS NULL`, so it chews through the backlog at ~120/hour until caught up.

#### New: `evaluate-fidelity.ts`

- **Schedule:** Daily at 3am (after thread-lifecycle at 2am)
- **Processes:** All notes not already at `skeleton` tier
- **What it does:** Scores each note on age and activity, applies tier rules:
  - `FULL`: age < 7 days
  - `HIGH`: age < 90 days OR in active thread
  - `SUMMARY`: age >= 90 days AND thread inactive/archived
  - `SKELETON`: thread archived AND no access in 180 days
- **No LLM calls.** Pure SQL + logic. Fast and cheap.
- **Rehydration:** If a skeleton/summary note joins an active thread, it promotes back to HIGH on the next evaluation.

#### New: `compile-thread-digests.ts`

- **Schedule:** Hourly (after reconsolidate-threads)
- **Trigger:** Active threads where `note_count > 10` and digest is stale
- **What it does:** Takes thread summary + why + member essences (not full text) and asks the LLM to produce a paragraph-length narrative capturing the thread's arc, evolution, and current state.

#### Modified: `process-llm.ts`

- **Change:** After extracting concepts/themes (existing behavior), add a second LLM call to compute the essence inline.
- New notes get their essence immediately. The separate `distill-essences.ts` workflow handles backfill and retries only.

#### Updated Schedule

```
Every 5 min:   process-llm (now also computes essence)
Every 5 min:   distill-essences (backfill + retries)
Every 5 min:   extract-tasks
Every 10 min:  index-vectors
Every 10 min:  compute-relationships
Every 30 min:  detect-threads
Hourly:        reconsolidate-threads
Hourly:        compile-thread-digests (NEW)
Hourly:        export-obsidian
Daily 12am:    daily-summary
Daily 2am:     thread-lifecycle
Daily 3am:     evaluate-fidelity (NEW)
Daily 6am:     send-digest
```

### 3. Context Assembly

A shared `ContextBuilder` utility in `src/lib/` that all workflows use to assemble context within a token budget.

```typescript
class ContextBuilder {
  constructor(budgetTokens: number);
  addNotes(noteIds: number[], relevanceScores?: Map<number, number>): this;
  addThread(threadId: number): this;
  addFullText(noteIds: number[]): this;
  build(): string;
}
```

**Tier rendering rules:**

| Tier | Rendered as |
|------|------------|
| `full` | Title + full content |
| `high` | Title + essence + full content |
| `summary` | Title + essence + themes |
| `skeleton` | Title + primary_theme |

**Token estimation:** Character count / 4. No external tokenizer dependency. The goal is staying well under the limit, not hitting it precisely. Builder fills from highest relevance down and stops when budget is spent.

**Workflow integration:**

- **`detect-threads.ts`** — Uses ContextBuilder instead of raw 15-note concatenation. Can now consider more notes at lower fidelity. 30 notes as essences fits in the same budget as 15 full-text notes.
- **`reconsolidate-threads.ts`** — Becomes incremental: thread digest + new notes since last reconsolidation, instead of re-reading everything.
- **`daily-summary.ts`** — Essences replace 100-char truncations. Summary quality improves within similar token budget.
- **SeleneChat context** — Thread digests for all active threads + essences for recent notes gives the LLM a much broader picture.
- **`process-llm.ts`** and **`extract-tasks.ts`** — No change. These analyze raw content and need full text.

**Principle:** Workflows that analyze content need full text. Workflows that need context/background use tiered representations.

### 4. Error Handling

**Core contract:** If compression artifacts don't exist yet, fall back to current behavior. The system is never worse than today.

**Essence failures:**
- `essence` stays `NULL`, `fidelity_tier` stays `full`
- `distill-essences.ts` retries automatically (queries `WHERE essence IS NULL`)
- After 3 consecutive failures on the same note, skip for 24 hours

**ContextBuilder fallback chain:**
```
essence → concepts + themes → truncated raw text (150 chars)
```
Always produces something. Never sends an empty block.

**Thread digest failures:**
- `thread_digest` stays `NULL`
- ContextBuilder assembles individual member essences instead

**Fidelity tier guards:**
- Never demote a note below `full` unless it has an essence
- `full → high`: always allowed (high still includes raw text)
- `high → summary`: requires `essence IS NOT NULL`
- `summary → skeleton`: requires `essence IS NOT NULL`
- Any tier → higher tier: always allowed (rehydration)

**Backfill behavior:**
- All existing notes start at `full` tier
- At 10/run every 5 min (~120/hour), a backlog of 500 notes takes ~4 hours
- No degradation during backfill — system just hasn't improved yet for those notes

**Monitoring:**
- Pino structured logging with `workflow` field
- Health endpoint query for compression progress and tier distribution

---

## Implementation Notes

**Affected files:**
- `src/lib/db.ts` — Schema migration for new columns
- `src/lib/context-builder.ts` — New shared utility
- `src/workflows/process-llm.ts` — Add inline essence computation
- `src/workflows/distill-essences.ts` — New workflow
- `src/workflows/evaluate-fidelity.ts` — New workflow
- `src/workflows/compile-thread-digests.ts` — New workflow
- `src/workflows/detect-threads.ts` — Use ContextBuilder
- `src/workflows/reconsolidate-threads.ts` — Use ContextBuilder
- `src/workflows/daily-summary.ts` — Use ContextBuilder
- `src/server.ts` — Health endpoint additions
- `launchd/` — Three new plist files

**Dependencies:** None. Uses existing Ollama, SQLite, and Pino infrastructure.

**Theoretical foundations:**
- Ranganathan's Five Laws of Library Science (1931) — "A library is a growing organism"
- Archival macro-appraisal theory — lifecycle-based value assessment
- Forte's Progressive Summarization — compress in layers over time

---

## Ready for Implementation Checklist

Before creating a branch, all items must be checked:

- [x] **Acceptance criteria defined** - See below
- [x] **ADHD check passed** - See below
- [x] **Scope check** - 4-5 days estimated: data model (day 1), workflows (days 2-3), context builder + integration (day 4), testing + backfill (day 5)
- [x] **No blockers** - Uses existing infrastructure only

### Acceptance Criteria

- [ ] `process-llm.ts` computes essence inline for new notes
- [ ] `distill-essences.ts` backfills existing notes at ~120/hour
- [ ] `evaluate-fidelity.ts` correctly assigns tiers based on age + activity
- [ ] `compile-thread-digests.ts` produces thread narratives for threads with 10+ notes
- [ ] `ContextBuilder` renders notes at correct fidelity tier within token budget
- [ ] `detect-threads.ts` uses ContextBuilder and handles more notes per synthesis
- [ ] `reconsolidate-threads.ts` uses incremental digest + new notes approach
- [ ] `daily-summary.ts` uses essences instead of 100-char truncations
- [ ] Fallback chain works: missing essence gracefully degrades to current behavior
- [ ] Health endpoint shows tier distribution and backfill progress
- [ ] All existing workflows continue to function during backfill period

### ADHD Design Check

- [x] **Reduces friction?** — Automatic. No user action required. Background workflows handle all compression.
- [x] **Visible?** — Health endpoint shows compression progress. Better context means better LLM responses (visible in SeleneChat quality).
- [x] **Externalizes cognition?** — The entire point. System manages information density so the user (and LLM) don't have to mentally juggle what's relevant.

---

## Links

- **Branch:** (added when implementation starts)
- **PR:** (added when complete)
