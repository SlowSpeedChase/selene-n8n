# US-045: Thread Detection Workflow

**Status:** done
**Priority:** critical
**Effort:** L
**Phase:** thread-system-2
**Created:** 2026-01-06
**Completed:** 2026-01-10

---

## User Story

As a **Selene system**,
I want **to detect threads (clusters of semantically related notes) from note associations**,
So that **the user's lines of thinking become visible as named, summarized threads**.

---

## Context

Phase 1 created the foundation: every note has an embedding and similarity associations. Phase 2 uses those associations to find **threads** — clusters of notes that represent a line of thinking.

### Starting State (from Phase 1)

| Metric | Value |
|--------|-------|
| Production notes | 65 |
| Notes with embeddings | 64 (98%) |
| Associations computed | 21 |
| Notes with 3+ associations | 4 (thread candidates) |
| Similarity threshold | 0.7 |

**Key insight from US-044:** Clusters are forming naturally. Party engagement notes cluster together. Selene project notes cluster together. Dog training notes cluster together.

This workflow:
1. Identifies clusters of associated notes (no LLM, just graph traversal)
2. For each cluster, calls LLM to synthesize thread name, summary, and "why"
3. Creates thread records in database
4. Links notes to threads

**Key principle:** Small context, many operations. Never feed more than 10-15 notes to the LLM at once.

---

## Acceptance Criteria

- [x] TypeScript workflow created: `src/workflows/detect-threads.ts`
- [x] Clustering algorithm identifies note groups from `note_associations` table (BFS graph traversal)
- [x] Configurable parameters:
  - [x] Minimum cluster size (default: 3 notes)
  - [x] Similarity threshold (default: 0.7, CLI arg supported)
- [x] For each cluster, LLM synthesis generates:
  - [x] Thread name (2-5 words)
  - [x] "Why" (underlying motivation)
  - [x] Summary (what connects these notes)
  - [x] Direction (exploring/emerging/clear)
  - [x] Emotional tone (neutral/positive/negative/mixed)
- [x] Thread records created in `threads` table
- [x] Note links created in `thread_notes` table
- [x] Handles orphan notes (associated but don't form clusters): leaves unassigned
- [x] Idempotent: filters already-threaded notes
- [x] Launchd plist created: `launchd/com.selene.detect-threads.plist` (every 2 hours)

---

## ADHD Design Check

- [x] **Reduces friction?** Automatic - user does nothing, threads emerge from their notes
- [x] **Visible?** Makes invisible lines of thinking visible
- [x] **Externalizes cognition?** System holds the thread connections so user doesn't have to

---

## Technical Notes

**Dependencies:**
- US-040: Thread system database migration (DONE)
- US-043: Association computation workflow (DONE)

**Clustering Algorithm (Step 1):**
```
For each note without a thread:
    Get its associations (similarity > threshold)
    If associated notes share a thread:
        Candidate: add note to that thread
    Else if associated notes form a cluster (3+ notes):
        Candidate: new thread from cluster
    Else:
        Leave as orphan for now
```

**LLM Synthesis Prompt (Step 2):**
```
These notes were written over time by the same person. They cluster together based on semantic similarity.

Notes:
---
[Note 1 - Date]
[content]
---
[Note 2 - Date]
[content]
---
[... up to 10-15 notes]

Questions:
1. What thread of thinking connects these notes?
2. What is the underlying want, need, or motivation?
3. Is there a clear direction or is this still exploring?
4. Suggest a short name for this thread (2-5 words)

Respond in JSON:
{
    "name": "...",
    "why": "...",
    "summary": "...",
    "direction": "exploring|emerging|clear",
    "emotional_tone": "neutral|positive|negative|mixed"
}
```

**Model:** Ollama mistral:7b (consistent with existing workflows)

**Tunable Parameters (config/thread-system-config.json):**
- `clustering.min_cluster_size`: 3
- `clustering.thread_merge_threshold`: 0.85
- `associations.similarity_threshold`: 0.7
- `reconsolidation.max_notes_per_synthesis`: 15

---

## Test Cases

1. **Simple cluster**: 5 notes about "fitness" with high association scores → creates thread
2. **Below threshold**: 2 notes associated → remain orphans (below min_cluster_size)
3. **Multiple clusters**: Notes form 2 distinct groups → creates 2 threads
4. **Existing thread**: New note associated with existing thread → adds to existing
5. **Orphan notes**: Single note with no strong associations → leaves unassigned

---

## Definition of Done

- [ ] Workflow deployed to n8n
- [ ] Test suite passing (4/5 minimum)
- [ ] At least 3 threads detected from real notes
- [ ] Thread summaries are coherent and meaningful
- [ ] Documentation complete (README, STATUS)
- [ ] Parameters tuned based on test results

---

## Links

- **Design:** `docs/plans/2026-01-04-selene-thread-system-design.md` (lines 258-313, 562-575)
- **Branch:** (created when promoted to active)
- **PR:** (added when complete)

---

## Implementation Progress

### 2026-01-10: TypeScript Implementation (COMPLETE)

The n8n blocking issue was bypassed by implementing thread detection as a TypeScript workflow, following the new architecture pattern established after the n8n-to-TypeScript migration.

**Files Created:**
- `src/workflows/detect-threads.ts` - Main workflow
- `launchd/com.selene.detect-threads.plist` - Scheduled job (every 2 hours)

**Algorithm:**
1. Load all associations from `note_associations` table
2. Build adjacency list from associations above threshold
3. Find connected components using BFS
4. Filter to clusters ≥ 3 notes
5. For each cluster, call Ollama mistral:7b to synthesize thread
6. Create thread record and link notes

**Test Results (2026-01-10):**
- 15 production notes, 64 associations (threshold 0.5)
- 2 threads detected:
  1. "Event-Driven Architecture Testing" (11 notes) - technical test notes
  2. "Project Journey" (3 notes) - emotional journey (excited → frustrated → breakthrough)
- LLM correctly identified semantic clusters

**Why TypeScript instead of n8n:**
- No silent HTTP failures
- Direct Ollama library integration
- Better error handling and logging
- Consistent with new architecture (Fastify + launchd)

### 2026-01-09: n8n Implementation (ABANDONED)

Previous n8n-based implementation was blocked by HTTP Request node silently failing when calling Ollama. Multiple workarounds attempted without success. Issue became moot after project migrated from n8n to TypeScript backend.
