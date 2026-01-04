# US-041: Embedding Generation Workflow

**Status:** draft
**Priority:** critical
**Effort:** M
**Phase:** thread-system-1
**Created:** 2026-01-04
**Updated:** 2026-01-04

---

## User Story

As a **Selene system**,
I want **to generate vector embeddings for each note via Ollama**,
So that **notes can be positioned in semantic space for similarity comparison**.

---

## Context

Embeddings are the core primitive for the thread system. Each note gets a 768-dimensional vector that captures its semantic meaning. Similar notes have similar vectors (high cosine similarity).

This workflow:
1. Receives a note (from 02-LLM Processing or batch trigger)
2. Calls Ollama embedding endpoint with note content
3. Stores the vector in `note_embeddings` table

Model choice: `nomic-embed-text` via Ollama (768 dimensions, good quality/speed balance).

---

## Acceptance Criteria

- [ ] Workflow 09-Embedding-Generation created in `workflows/09-embedding-generation/`
- [ ] Ollama embedding endpoint works: `POST http://localhost:11434/api/embeddings`
- [ ] Embeddings stored in `note_embeddings` table with correct schema
- [ ] Model version tracked (`nomic-embed-text` stored in `model_version` column)
- [ ] Handles Ollama offline gracefully (note still processed, embedding skipped)
- [ ] Test script created: `workflows/09-embedding-generation/scripts/test-with-markers.sh`
- [ ] STATUS.md documents test results

---

## ADHD Design Check

- [x] **Reduces friction?** Automatic - user does nothing
- [x] **Visible?** Enables future thread visibility
- [x] **Externalizes cognition?** Positions thoughts in semantic space automatically

---

## Technical Notes

- Dependencies: US-040 (database migration)
- Affected components:
  - `workflows/09-embedding-generation/workflow.json` (new)
  - `workflows/09-embedding-generation/README.md` (new)
  - `workflows/09-embedding-generation/docs/STATUS.md` (new)
  - `workflows/09-embedding-generation/scripts/test-with-markers.sh` (new)
- Design doc: `docs/plans/2026-01-04-selene-thread-system-design.md`

**Ollama API call:**
```javascript
// POST http://host.docker.internal:11434/api/embeddings
{
  "model": "nomic-embed-text",
  "prompt": "[note content]"
}
// Returns: { "embedding": [0.123, -0.456, ...] } // 768 floats
```

---

## Links

- **Branch:** (added when active)
- **PR:** (added when complete)
