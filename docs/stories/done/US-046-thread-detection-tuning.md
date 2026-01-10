# US-046: Thread Detection Testing & Tuning

**Status:** ready
**Priority:** critical
**Effort:** M
**Phase:** thread-system-2
**Created:** 2026-01-06

---

## User Story

As a **Selene user**,
I want **the thread detection system to produce meaningful, coherent threads from my actual notes**,
So that **the threads accurately represent my lines of thinking rather than arbitrary clusters**.

---

## Context

US-045 builds the thread detection workflow. This story focuses on **validation** — running the system on real notes, evaluating output quality, and tuning parameters until threads are meaningful.

This is the "does it actually work?" checkpoint before building the living system (Phase 3).

### Expected Thread Candidates (from Phase 1 data)

Based on US-044 verification, these clusters should become threads:
- **Party/social engagement** (notes 21, 22, 208) - social skills topics
- **Selene project** (notes 59, 61, 65, 94, 126) - app development ideas
- **Dog training** (notes 41, 54, 60) - Leo-related notes

**Success looks like:** These 3 clusters become meaningful threads with names the user recognizes.

---

## Acceptance Criteria

### Testing
- [ ] Run thread detection on all embedded notes (batch)
- [ ] Generate at least 5 threads from real data
- [ ] Review each thread for semantic coherence
- [ ] Validate thread names are concise (2-5 words) and meaningful
- [ ] Validate "why" statements capture underlying motivation
- [ ] Validate summaries explain what connects the notes

### Quality Metrics
- [ ] At least 80% of detected threads are semantically coherent
- [ ] Thread names make sense without reading the notes
- [ ] Notes within each thread share clear thematic connection
- [ ] Orphan notes (not assigned to threads) are truly unrelated

### Parameter Tuning
- [ ] Test similarity thresholds: 0.6, 0.7, 0.8
- [ ] Test min cluster size: 2, 3, 5
- [ ] Test max notes per synthesis: 10, 15, 20
- [ ] Document optimal parameters in `config/thread-system-config.json`

### Documentation
- [ ] Create verification script: `scripts/verify-thread-quality.sh`
- [ ] Document test results in `workflows/12-thread-detection/docs/TUNING.md`
- [ ] Update STATUS.md with final parameter values

---

## ADHD Design Check

- [x] **Reduces friction?** Automatic tuning based on real data, not manual categorization
- [x] **Visible?** Threads make invisible thinking patterns visible
- [x] **Externalizes cognition?** System organizes thoughts without user needing to remember connections

---

## Technical Notes

**Dependencies:**
- US-045: Thread Detection Workflow (must be implemented first)

**Evaluation Questions:**
1. Do the thread names resonate? Can user recognize what they're about?
2. Are notes correctly grouped? Any obvious misplacements?
3. Are there missing threads? (notes that should cluster but don't)
4. Are there over-clustered threads? (unrelated notes forced together)

**Tuning Strategy:**
1. Start with defaults from design doc (threshold=0.7, min_size=3)
2. Run thread detection
3. Review output for quality issues
4. Adjust one parameter at a time
5. Re-run and compare
6. Document optimal values

**Sample Thread Quality Check:**
```sql
-- Get all threads with their note counts
SELECT t.id, t.name, t.why, t.summary, t.note_count, t.status
FROM threads t
ORDER BY t.note_count DESC;

-- Get notes for a specific thread
SELECT rn.id, rn.title, rn.created_at, tn.relevance_score
FROM thread_notes tn
JOIN raw_notes rn ON tn.raw_note_id = rn.id
WHERE tn.thread_id = ?
ORDER BY rn.created_at DESC;
```

**Success Pattern:**
User reads thread name → immediately recognizes the line of thinking → opens thread → sees notes and thinks "yes, these all connect"

**Failure Pattern:**
User reads thread name → confused → opens thread → notes seem random or only loosely related

---

## Test Cases

1. **Fitness thread**: Should cluster notes about exercise, health, energy
2. **Work-related threads**: Should separate work frustration from work projects
3. **Creative threads**: Writing ideas vs. art ideas should be distinct
4. **Temporal threads**: Notes about a specific event should cluster
5. **Multi-faceted topics**: Notes with multiple themes should join strongest cluster

---

## Definition of Done

- [ ] Thread detection run on full dataset
- [ ] 5+ threads created
- [ ] Parameters tuned to optimal values
- [ ] Validation report documents thread quality
- [ ] No obvious mislabeling or mis-clustering
- [ ] User can read thread names and summaries and recognize their thinking

---

## Links

- **Design:** `docs/plans/2026-01-04-selene-thread-system-design.md` (lines 562-575, 635-656)
- **Previous:** US-045 (Thread Detection Workflow)
- **Branch:** (created when promoted to active)
- **PR:** (added when complete)
