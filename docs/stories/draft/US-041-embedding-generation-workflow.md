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
1. Receives note ID(s) via webhook
2. Fetches note content from database
3. Calls Ollama embedding endpoint
4. Stores the vector in `note_embeddings` table

Model choice: `nomic-embed-text` via Ollama (768 dimensions, good quality/speed balance).

---

## Acceptance Criteria

- [ ] Workflow 09-Embedding-Generation created in `workflows/09-embedding-generation/`
- [ ] Webhook endpoint: `POST /webhook/api/embed`
- [ ] Accepts single note (`note_id`) or batch (`note_ids`)
- [ ] Embeddings stored in `note_embeddings` table with correct schema
- [ ] Model version tracked (`nomic-embed-text` stored in `model_version` column)
- [ ] Idempotent: skips notes that already have embeddings
- [ ] Handles Ollama offline gracefully (returns partial success)
- [ ] Test script created: `workflows/09-embedding-generation/scripts/test-with-markers.sh`
- [ ] STATUS.md documents test results

---

## Implementation Design

### Trigger

**Endpoint:** `POST /webhook/api/embed`
**Response mode:** `lastNode` (synchronous)

### Input Format

```json
// Single note
{ "note_id": 123 }

// Multiple notes (batch)
{ "note_ids": [123, 124, 125] }

// Test mode
{ "note_id": 123, "test_run": "test-run-20260104-120000" }
```

### Output Format

```json
{
  "success": true,
  "embedded": 3,
  "skipped": 0,
  "failed": 0
}
```

### Workflow Flow

```
Webhook ─▶ Normalize Input ─▶ Loop Over Note IDs
                                      │
              ┌───────────────────────┘
              ▼
    Fetch Note Content (SQL)
              │
              ▼
    Check Existing Embedding
              │
       ┌──────┴──────┐
       ▼             ▼
    Has One       No Embedding
    (Skip)            │
                      ▼
              Call Ollama API
                      │
                      ▼
              Store Embedding (SQL)
                      │
       └──────────────┘
              │
              ▼
    Aggregate Results ─▶ Return Response
```

### Key Nodes

1. **Webhook** - Receives POST with note_id(s)
2. **Normalize Input** - Convert single ID to array format
3. **Loop** - Process each note
4. **Fetch Note** - `SELECT id, content FROM raw_notes WHERE id = ?`
5. **Check Existing** - `SELECT 1 FROM note_embeddings WHERE raw_note_id = ?`
6. **Call Ollama** - `POST http://host.docker.internal:11434/api/embeddings`
7. **Store Embedding** - `INSERT INTO note_embeddings (...) VALUES (...)`
8. **Aggregate** - Count success/skip/fail
9. **Respond** - Return JSON summary

### Error Handling

- **Ollama offline:** 30s timeout, mark as failed, continue to next note
- **Note not found:** Skip, log warning
- **Embedding exists:** Skip (idempotent)
- **Partial failure:** Return `{"success": true, "embedded": 2, "failed": 1}`

### Ollama API Call

```javascript
// POST http://host.docker.internal:11434/api/embeddings
{
  "model": "nomic-embed-text",
  "prompt": "[note content]"
}
// Returns: { "embedding": [0.123, -0.456, ...] } // 768 floats
```

---

## ADHD Design Check

- [x] **Reduces friction?** Automatic - user does nothing
- [x] **Visible?** Enables future thread visibility
- [x] **Externalizes cognition?** Positions thoughts in semantic space automatically

---

## Technical Notes

- Dependencies: US-040 (database migration) - DONE
- Prerequisite: `ollama pull nomic-embed-text` - DONE
- Design doc: `docs/plans/2026-01-04-selene-thread-system-design.md`

**Files to create:**
- `workflows/09-embedding-generation/workflow.json`
- `workflows/09-embedding-generation/README.md`
- `workflows/09-embedding-generation/docs/STATUS.md`
- `workflows/09-embedding-generation/scripts/test-with-markers.sh`

---

## Links

- **Branch:** (added when active)
- **PR:** (added when complete)
