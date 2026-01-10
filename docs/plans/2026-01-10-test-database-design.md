# Test Database Design for Thread Detection

**Status:** Ready for Implementation
**Created:** 2026-01-10
**Story:** US-046

---

## Problem

The dev database contains Claude's simple test notes which don't represent realistic thinking patterns. To properly validate thread detection quality, we need a curated fake database that:

- Covers realistic life/work domains
- Forms natural semantic clusters
- Includes edge cases (orphans, multi-topic notes)
- Can be reset and rerun for parameter tuning

---

## Design Decisions

| Aspect | Decision | Rationale |
|--------|----------|-----------|
| Domains | Mixed work + life | Real thinking spans both |
| Size | 60 notes | Enough for 8 clusters + edge cases |
| Balance | 80/20 clear/edge | Validate happy path first |
| Style | Voice-captured, informal | Matches real Drafts input |

---

## Thread Clusters (8 total)

| # | Thread Name | Domain | Notes | Description |
|---|-------------|--------|-------|-------------|
| 1 | Fitness Journey | Life | 6 | Exercise, energy, motivation |
| 2 | Side Project Ideas | Work | 7 | App concepts, feature brainstorms |
| 3 | Sleep Struggles | Life | 5 | Insomnia, sleep hygiene, tiredness |
| 4 | Meeting Frustrations | Work | 6 | Pointless meetings, interruptions |
| 5 | Learning Rust | Work | 5 | New programming language journey |
| 6 | Kitchen Experiments | Life | 5 | Cooking, recipes, meal planning |
| 7 | Friend Group Dynamics | Life | 6 | Social events, relationships |
| 8 | Home Office Setup | Mixed | 5 | Desk, equipment, environment |

**Subtotal:** 45 clustered notes

---

## Edge Cases (15 notes)

### Orphan Notes (10-12)
Random thoughts that shouldn't cluster:
- Weather observations
- Random memories
- One-off tasks
- Philosophical musings

### Multi-Topic Notes (3-4)
Notes spanning multiple clusters:
- "Exhausted from bad sleep, skipped gym, sat through meeting" (Sleep + Fitness + Meetings)
- "Learning Rust for my side project" (Learning + Side Project)
- "Standing desk helping my back during long coding sessions" (Office + Fitness)

### Borderline Notes (3-4)
Thematically adjacent but shouldn't merge:
- "Energy drinks not helping" (Sleep vs Fitness?)
- "Need focus music for deep work" (Office vs Meetings?)

---

## Note Content Style

### Characteristics
- **Length:** 1-3 sentences to 2-3 paragraphs
- **Tone:** Informal, contractions, expressions like "ugh", "honestly"
- **ADHD patterns:** Tangents, incomplete thoughts, emotional reactions
- **Grammar:** Run-ons, fragments, stream of consciousness

### Example: Meeting Frustrations Cluster

```
Title: "Another 2 hour sync"
Content: Why do we need everyone in the room for status updates that could be a
Slack message. I lost my whole morning and now I'm behind on the actual work.

Title: "Context switching is killing me"
Content: Third interruption today. Was finally in flow on the API refactor and
now I have to sit through a "quick sync" that's definitely not going to be quick.

Title: "Calendar audit needed"
Content: Looked at next week - 23 hours of meetings. When am I supposed to do
my job? Need to start declining more aggressively.
```

---

## File Structure

```
data/
  test-notes.json         # All 60 notes with metadata

scripts/
  seed-test-data.ts       # Insert notes into database
  reset-test-data.ts      # Wipe threads + reseed notes
  verify-thread-quality.ts # Compare detected vs expected
```

---

## test-notes.json Schema

```json
{
  "notes": [
    {
      "title": "Note title",
      "content": "Note content...",
      "created_at": "2025-10-15T09:30:00Z",
      "expected_cluster": "fitness-journey",
      "tags": ["exercise", "motivation"]
    }
  ],
  "clusters": {
    "fitness-journey": {
      "expected_thread_name": "Fitness Journey",
      "description": "Exercise, energy levels, motivation"
    }
  }
}
```

---

## Scripts

### seed-test-data.ts
1. Read `data/test-notes.json`
2. Clear existing test data from `raw_notes` (where test_run = 'seed-test')
3. Insert all notes with `test_run = 'seed-test'`
4. Clear `threads`, `thread_notes`, `thread_history` tables
5. Clear `note_embeddings`, `note_associations` for reprocessing

### reset-test-data.ts
1. Call seed-test-data logic
2. Run compute-embeddings workflow
3. Run compute-associations workflow
4. Report: "Ready for thread detection"

### verify-thread-quality.ts
1. Load expected clusters from `test-notes.json`
2. Query detected threads and their notes
3. Match detected threads to expected clusters
4. Calculate metrics:
   - Precision: % of notes in thread that belong there
   - Recall: % of cluster notes that were found
   - Orphan accuracy: % of orphans that stayed unthreaded
5. Output quality report

---

## Test Cycle

```bash
# Full reset and reprocess
npx ts-node scripts/reset-test-data.ts

# Run thread detection with threshold
npx ts-node src/workflows/detect-threads.ts 0.7

# Check quality
npx ts-node scripts/verify-thread-quality.ts

# Adjust threshold and repeat
npx ts-node src/workflows/detect-threads.ts 0.6
npx ts-node scripts/verify-thread-quality.ts
```

---

## Success Criteria

- [ ] 8 expected clusters detected as 8 threads
- [ ] Thread names semantically match intended topics
- [ ] 80%+ of clustered notes correctly assigned
- [ ] 80%+ of orphans remain unthreaded
- [ ] Multi-topic notes join sensible clusters
- [ ] No unexpected cluster merging

---

## Tuning Parameters

After validation, document optimal values in workflow:

| Parameter | Default | Tested Range | Optimal |
|-----------|---------|--------------|---------|
| Similarity threshold | 0.7 | 0.6 - 0.8 | TBD |
| Min cluster size | 3 | 2 - 5 | TBD |
| Max notes per synthesis | 15 | 10 - 20 | TBD |

---

## Implementation Order

1. Create `data/test-notes.json` with all 60 notes
2. Create `scripts/seed-test-data.ts`
3. Create `scripts/reset-test-data.ts`
4. Create `scripts/verify-thread-quality.ts`
5. Run test cycle, tune parameters
6. Document results
