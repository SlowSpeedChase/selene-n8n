# US-042: Batch Embed Existing Notes

**Status:** active
**Priority:** high
**Effort:** M
**Phase:** thread-system-1
**Created:** 2026-01-04
**Updated:** 2026-01-05

---

## User Story

As a **Selene user**,
I want **all my existing notes to have embeddings generated**,
So that **threads can form from my historical thinking, not just new notes**.

---

## Context

The embedding workflow (US-041) handles new notes going forward. But there are existing notes in the database that need embeddings too. This story creates a batch process to backfill embeddings for all processed notes.

This is a one-time operation (or repeated if model changes), not a continuous workflow.

Key considerations:
- Rate limiting (don't overwhelm Ollama)
- Progress tracking (resume if interrupted)
- Skip notes that already have embeddings

---

## Acceptance Criteria

- [ ] Batch script created: `scripts/batch-embed-notes.sh`
- [ ] Script queries `processed_notes` that lack embeddings
- [ ] Calls Ollama for each note with rate limiting (e.g., 1 req/sec)
- [ ] Progress logged to console and/or file
- [ ] Can resume from interruption (skips already-embedded notes)
- [ ] All existing processed notes have embeddings after completion
- [ ] Script documented in `scripts/CLAUDE.md`

---

## ADHD Design Check

- [x] **Reduces friction?** One command backfills everything
- [x] **Visible?** Progress shown during execution
- [x] **Externalizes cognition?** Historical thoughts now positioned in semantic space

---

## Technical Notes

- Dependencies: US-040 (migration), US-041 (embedding workflow exists for reference)
- Affected components:
  - `scripts/batch-embed-notes.sh` (new)
  - `scripts/CLAUDE.md` (update)
- Design doc: `docs/plans/2026-01-04-selene-thread-system-design.md`

**Approach:**
```bash
# Pseudocode
for each note in (SELECT id, content FROM processed_notes WHERE id NOT IN (SELECT raw_note_id FROM note_embeddings)):
    curl Ollama embedding endpoint
    INSERT INTO note_embeddings
    sleep 1  # rate limit
```

**Estimated time:** If 500 notes × 1 sec each = ~8 minutes

---

## Links

- **Branch:** `US-042/batch-embed-notes`
- **Design:** `docs/plans/2026-01-05-batch-embed-notes-design.md`
- **PR:** (added when complete)
