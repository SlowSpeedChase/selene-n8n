# US-041: Embedding Generation Workflow

**Status:** active
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
1. Receives note ID via webhook
2. Fetches note content from database
3. Calls Ollama embedding endpoint
4. Stores the vector in `note_embeddings` table

Model choice: `nomic-embed-text` via Ollama (768 dimensions, good quality/speed balance).

---

## Acceptance Criteria

- [x] Workflow 10-Embedding-Generation created in `workflows/10-embedding-generation/`
- [x] Webhook endpoint: `POST /webhook/api/embed`
- [x] Accepts single note (`note_id`)
- [x] Embeddings stored in `note_embeddings` table with correct schema
- [x] Model version tracked (`nomic-embed-text` stored in `model_version` column)
- [x] Idempotent: skips notes that already have embeddings
- [x] Handles missing notes gracefully
- [x] Test script created: `workflows/10-embedding-generation/scripts/test-with-markers.sh`
- [x] STATUS.md documents test results (4/5 pass)

**Note:** Batch processing (`note_ids` array) deferred to US-042.

---

## Test Results

| Test | Result |
|------|--------|
| Single note embedding | PASS |
| Batch embedding | FAIL (deferred to US-042) |
| Idempotency | PASS |
| Not found handling | PASS |
| 768 dimensions | PASS |

---

## ADHD Design Check

- [x] **Reduces friction?** Automatic - user does nothing
- [x] **Visible?** Enables future thread visibility
- [x] **Externalizes cognition?** Positions thoughts in semantic space automatically

---

## Technical Notes

- Dependencies: US-040 (database migration) - DONE
- Prerequisite: `ollama pull nomic-embed-text` - DONE
- Workflow number changed from 09 to 10 (09 was taken by feedback-processing)

**Files created:**
- `workflows/10-embedding-generation/workflow.json`
- `workflows/10-embedding-generation/README.md`
- `workflows/10-embedding-generation/docs/STATUS.md`
- `workflows/10-embedding-generation/scripts/test-with-markers.sh`

---

## Links

- **Branch:** `US-041/embedding-workflow`
- **PR:** (added when complete)
