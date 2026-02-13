# Thread Lifecycle: Split, Merge & Archive

**Date:** 2026-02-13
**Status:** Ready
**Topic:** thread-system

---

## Purpose

Threads are chains of thought — linked memories forming a line of thinking. Over time, threads grow stale, diverge into sub-topics, or converge with other threads. The system should handle this automatically so the user never has to manage thread lifecycle manually.

Three operations:
- **Archive** — threads inactive 60+ days fade away silently
- **Split** — a broad thread that has forked into distinct sub-clusters breaks apart
- **Merge** — two threads that converged on the same topic combine into one

All fully automatic. History preserved for every change. Archived threads reactivate if new related notes appear.

---

## ADHD Check

- **Reduces friction?** Yes — no manual thread management. Stale threads disappear, active thinking self-organizes.
- **Makes things visible?** Yes — splits create focused threads with clear names instead of one vague blob. Archive removes noise.
- **Externalizes cognition?** Yes — the system tracks when thinking lines fork or merge. The user doesn't have to notice.

---

## Architecture

### Single Workflow: `thread-lifecycle.ts`

Runs daily at 2am via launchd. Three phases in sequence:

```
Phase 1: ARCHIVE
  Query active threads where last_activity_at < 60 days ago
  Set status = 'archived'
  Record thread_history

Phase 2: SPLIT
  For each active thread with 6+ notes:
    Build intra-thread association graph (threshold 0.65)
    BFS to find connected components
    If 2+ components with 3+ notes each:
      Largest component keeps original thread
      New thread(s) created for other components
      LLM synthesizes name/why/summary for each
      Record thread_history (split)

Phase 3: MERGE
  Compute centroid (average embedding) for each active thread
  For each pair within merge distance threshold:
    LLM confirms: "Are these fundamentally the same line of thinking?"
    If yes: absorb smaller into larger
    Resynthesize merged thread
    Record thread_history (merged)
```

**Order matters:** Archive first clears dead weight. Split then merge operates only on living threads.

---

## Split Detection

```
splitThread(thread):
  notes = getNotesForThread(thread.id)
  if notes.length < 6: skip

  # Build intra-thread similarity graph
  for each pair of notes in thread:
    similarity = lookupAssociation(noteA, noteB)
    if similarity >= 0.65: addEdge(noteA, noteB)

  # Find connected components via BFS
  components = findConnectedComponents(graph)
  components = components.filter(c => c.length >= 3)

  if components.length < 2: skip  # still cohesive

  # Largest component keeps the original thread
  sort components by size DESC
  originalNotes = components[0]
  newClusters = components[1:]

  for each cluster in newClusters:
    { name, why, summary } = synthesizeThread(cluster)
    newThread = createThread(name, why, summary)
    moveNotes(cluster, from=thread, to=newThread)
    recordHistory(thread, 'split')
    recordHistory(newThread, 'created')

  resynthesizeThread(thread)  # update the now-smaller original
```

**Minimum 6 notes** ensures both resulting threads have at least 3 notes (the existing MIN_CLUSTER_SIZE).

---

## Merge Detection

```
findMergeCandidates(activeThreads):
  # Compute centroid for each thread
  for each thread:
    noteVectors = getEmbeddings(thread.noteIds)
    thread.centroid = average(noteVectors)

  # Compare all pairs
  candidates = []
  for each pair (threadA, threadB):
    distance = l2Distance(threadA.centroid, threadB.centroid)
    if distance < MERGE_DISTANCE_THRESHOLD:
      candidates.push({ threadA, threadB, distance })

  sort candidates by distance ASC

  for each candidate:
    if either thread already merged this cycle: skip

    # LLM confirmation to avoid false positives
    response = llm("""
      Thread A: "{threadA.name}" - {threadA.summary}
      Thread B: "{threadB.name}" - {threadB.summary}
      Are these fundamentally about the same line of thinking?
      Reply JSON: { "should_merge": true/false, "reason": "..." }
    """)

    if response.should_merge:
      mergeThreads(larger, smaller)

mergeThreads(keeper, absorbed):
  moveAllNotes(from=absorbed, to=keeper)
  setStatus(absorbed, 'merged')
  resynthesizeThread(keeper)
  recordHistory(keeper, 'merged')
  recordHistory(absorbed, 'merged', "Merged into: keeper.name")
```

**Key decisions:**
- One merge per thread per cycle (prevents chain merges A->B->C)
- Larger thread (by note count) is always the keeper
- `status = 'merged'` preserves history (not deleted)
- LLM confirmation prevents false positives from embedding proximity alone

---

## Archive & Reactivation

```
archiveStaleThreads():
  staleDate = now() - 60 days
  stale = threads WHERE status = 'active' AND last_activity_at < staleDate
  for each: set status = 'archived', record history
```

**Reactivation:** When `detect-threads.ts` assigns a new note to an archived thread, it flips status back to `active` and records a `reactivated` history entry. The chain reconnects.

**Obsidian:** Archived threads move to `vault/Selene/Threads/Archive/` during reconsolidation.

---

## Schema Impact

No migrations needed. Thread status and history change_type are both text columns:
- New status values: `archived`, `merged`
- New history change_types: `archived`, `reactivated`

---

## Deliverables

1. `src/workflows/thread-lifecycle.ts` — archive, split, merge in one workflow
2. `launchd/com.selene.thread-lifecycle.plist` — daily at 2am
3. Edit `detect-threads.ts` — reactivate archived threads on new note assignment
4. Edit `reconsolidate-threads.ts` — move archived threads to Obsidian `Archive/` subfolder

---

## Acceptance Criteria

- [ ] Threads inactive 60+ days are archived automatically
- [ ] Archived threads reactivate when new related notes are assigned
- [ ] Threads with 6+ notes that form 2+ disconnected sub-clusters are split
- [ ] Split threads get LLM-synthesized names and summaries
- [ ] Threads with close centroids and LLM-confirmed overlap are merged
- [ ] Merged thread preserves all notes and history from both sources
- [ ] All lifecycle changes recorded in thread_history
- [ ] Archived threads moved to Archive/ in Obsidian export
- [ ] Existing thread detection, reconsolidation, and SeleneChat queries unaffected

---

## Scope Check

- 4 files to create/edit
- Core algorithms reuse existing BFS clustering and LLM synthesis
- No new UI needed (archived/merged filtered by existing status queries)
- Estimated: < 1 week
