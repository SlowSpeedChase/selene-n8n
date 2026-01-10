# US-045: Thread Detection Workflow

**Status:** blocked
**Blocked-On:** HTTP Request node fails silently when calling Ollama
**Priority:** critical
**Effort:** L
**Phase:** thread-system-2
**Created:** 2026-01-06

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

- [ ] Workflow 12-Thread-Detection created in `workflows/12-thread-detection/`
- [ ] Clustering algorithm identifies note groups from `note_associations` table
- [ ] Configurable parameters:
  - [ ] Minimum cluster size (default: 3 notes)
  - [ ] Similarity threshold (default: 0.7)
- [ ] For each cluster, LLM synthesis generates:
  - [ ] Thread name (2-5 words)
  - [ ] "Why" (underlying motivation)
  - [ ] Summary (what connects these notes)
  - [ ] Direction (exploring/emerging/clear)
  - [ ] Emotional tone (neutral/positive/negative/mixed)
- [ ] Thread records created in `threads` table
- [ ] Note links created in `thread_notes` table
- [ ] Handles orphan notes (associated but don't form clusters): leaves unassigned
- [ ] Idempotent: doesn't recreate existing threads
- [ ] Test script created: `workflows/12-thread-detection/scripts/test-with-markers.sh`
- [ ] STATUS.md documents test results

---

## ADHD Design Check

- [ ] **Reduces friction?** Automatic - user does nothing, threads emerge from their notes
- [ ] **Visible?** Makes invisible lines of thinking visible
- [ ] **Externalizes cognition?** System holds the thread connections so user doesn't have to

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

## Implementation Progress (2026-01-09)

### Completed
- [x] Workflow directory structure: `workflows/12-thread-detection/`
- [x] Complete workflow.json with 14 nodes
- [x] Test script created: `workflows/12-thread-detection/scripts/test-with-markers.sh`
- [x] Workflow imported to n8n (multiple times - cleanup needed)
- [x] "No clusters" path works correctly (returns valid JSON response)
- [x] All nodes work through Pre-Ollama Debug:
  - Webhook → Normalize Config → Find Unthreaded → Greedy Clustering → Split Clusters → Fetch Content → Build LLM Prompt → Pre-Ollama Debug

### Blocking Issue
The HTTP Request node (typeVersion 3) that calls Ollama fails silently.

**Evidence:**
- Ollama works perfectly when called directly with curl (tested with 6879 char prompt)
- Workflow logs show data reaches Pre-Ollama Debug correctly
- Call Ollama HTTP node produces no logs, no errors, just returns `{"message":"Error in workflow"}`
- n8n.log shows no error for this specific failure

**Attempts that failed:**
1. Function node with `fetch()` - "fetch is not defined"
2. Function node with `child_process` - "Cannot find module"
3. Function node with `http` module - "Cannot find module"
4. Code node v2 with `this.helpers.httpRequest()` - silent failure
5. HTTP Request node v3 (same pattern as 02-LLM-Processing) - silent failure

**What works in 02-LLM-Processing:**
- HTTP Request node v3 with `$env.OLLAMA_BASE_URL`
- Same expression syntax for jsonBody
- Timeout 60000ms

### Next Steps to Unblock
1. Try shorter prompt (maybe hitting size limit)
2. Try hardcoded URL instead of `$env.OLLAMA_BASE_URL`
3. Debug in n8n UI to see actual error
4. Compare exact node configuration with working 02-LLM-Processing

### Files
- Workflow JSON: `.worktrees/thread-detection/workflows/12-thread-detection/workflow.json`
- Test script: `.worktrees/thread-detection/workflows/12-thread-detection/scripts/test-with-markers.sh`
- Latest n8n workflow ID: `JYC12jnrXuTG4mBb` (20+ duplicates exist, need cleanup)
