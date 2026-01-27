# US-044: Verify Note Clusters Forming

**Status:** draft
**Priority:** high
**Effort:** S
**Phase:** thread-system-1
**Created:** 2026-01-04
**Updated:** 2026-01-04

---

## User Story

As a **Selene developer**,
I want **to query and visualize note clusters from the association data**,
So that **I can verify the foundation works before building thread detection**.

---

## Context

Phase 1 checkpoint: Before building thread detection (Phase 2), we need to verify that:
1. Embeddings are being generated correctly
2. Associations are capturing meaningful relationships
3. Clusters are forming naturally in the data

This story creates verification tools - queries, scripts, maybe a simple visualization.

**Key question to answer:** "Given a note, what similar notes does the system find?"

---

## Acceptance Criteria

- [ ] Query script created: `scripts/query-similar-notes.sh <note_id>`
- [ ] Script returns top N similar notes with similarity scores
- [ ] Manual verification: results make semantic sense
- [ ] Cluster stats query: "How many notes have 3+ associations?"
- [ ] Documentation of verification results in Phase 1 completion notes
- [ ] At least 10 sample queries verified manually

---

## ADHD Design Check

- [x] **Reduces friction?** Quick command to explore data
- [x] **Visible?** Makes the invisible embedding space visible
- [x] **Externalizes cognition?** Shows connections that exist in user's thinking

---

## Technical Notes

- Dependencies: US-040, US-041, US-042, US-043 (all prior Phase 1 stories)
- Affected components:
  - `scripts/query-similar-notes.sh` (new)
  - `scripts/cluster-stats.sh` (new)
  - `scripts/CLAUDE.md` (update)
- Design doc: `docs/plans/2026-01-04-selene-thread-system-design.md`

**Sample queries:**
```sql
-- Find similar notes to note ID 123
SELECT
    rn.id,
    rn.title,
    SUBSTR(rn.content, 1, 100) as preview,
    na.similarity_score
FROM note_associations na
JOIN raw_notes rn ON rn.id = na.note_b_id
WHERE na.note_a_id = 123
ORDER BY na.similarity_score DESC
LIMIT 10;

-- Cluster stats
SELECT
    COUNT(*) as notes_with_associations,
    AVG(assoc_count) as avg_associations
FROM (
    SELECT note_a_id, COUNT(*) as assoc_count
    FROM note_associations
    GROUP BY note_a_id
) sub;
```

---

## Phase 1 Completion Criteria

When this story is done, Phase 1 is complete. Checkpoint:
- [ ] All notes have embeddings
- [ ] Associations computed for all embedded notes
- [ ] Can query "similar notes" and get meaningful results
- [ ] Ready to proceed to Phase 2 (Thread Detection)

---

## Links

- **Branch:** (added when active)
- **PR:** (added when complete)
