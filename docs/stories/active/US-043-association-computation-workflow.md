# US-043: Association Computation Workflow

**Status:** active
**Priority:** critical
**Effort:** M
**Phase:** thread-system-1
**Created:** 2026-01-04
**Updated:** 2026-01-05

---

## User Story

As a **Selene system**,
I want **to compute similarity between notes and store associations**,
So that **related notes are linked and can form threads**.

---

## Context

Once notes have embeddings, we need to compare them. This workflow:
1. Takes a newly embedded note
2. Computes cosine similarity against all other note embeddings
3. Stores top N associations where similarity > threshold

This creates the "web" of connections that thread detection will use.

**Parameters (tunable):**
- Similarity threshold: 0.7 (only store meaningful connections)
- Max associations per note: 20 (prevent explosion)

---

## Acceptance Criteria

- [ ] Workflow 11-Association-Computation created in `workflows/11-association-computation/`
- [ ] Cosine similarity function implemented correctly
- [ ] Associations stored in `note_associations` table
- [ ] Only stores associations above threshold (0.7 default)
- [ ] Limits to top N associations per note (20 default)
- [ ] Handles batch mode (compute all associations for existing notes)
- [ ] Test script created: `workflows/11-association-computation/scripts/test-with-markers.sh`
- [ ] STATUS.md documents test results
- [ ] Workflow 10-Embedding-Generation updated to trigger associations

---

## ADHD Design Check

- [x] **Reduces friction?** Automatic - user does nothing
- [x] **Visible?** Enables thread visibility later
- [x] **Externalizes cognition?** System discovers connections user wouldn't find manually

---

## Technical Notes

- Dependencies: US-040 (migration), US-041/US-042 (notes must have embeddings)
- Affected components:
  - `workflows/11-association-computation/workflow.json` (new)
  - `workflows/11-association-computation/README.md` (new)
  - `workflows/11-association-computation/docs/STATUS.md` (new)
  - `workflows/11-association-computation/scripts/test-with-markers.sh` (new)
  - `scripts/batch-compute-associations.sh` (new)
  - `workflows/10-embedding-generation/workflow.json` (modified - add trigger)
- Design doc: `docs/plans/2026-01-05-association-computation-design.md`

**Storage convention:** `note_a_id < note_b_id` to prevent duplicates

---

## Links

- **Branch:** `US-043/association-computation`
- **Design:** `docs/plans/2026-01-05-association-computation-design.md`
- **PR:** (added when complete)
