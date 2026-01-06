# US-043: Association Computation Workflow Design

**Date:** 2026-01-05
**Status:** Approved
**Story:** US-043
**Phase:** thread-system-1

---

## Overview

Compute cosine similarity between note embeddings and store the top associations. This creates the "web" of connections that thread detection will use.

**Trigger:** Real-time via n8n workflow (called after embedding generation)

**Parameters:**
- Similarity threshold: 0.7
- Max associations per note: 20

---

## Workflow Architecture

**Workflow 11-Association-Computation**

```
Webhook (/api/associate)
    ↓
Normalize Input (accept note_id or note_ids)
    ↓
Split Into Items (for batch support)
    ↓
Fetch Source Embedding
    ↓
Note Has Embedding? ──No──→ Skip (return early)
    ↓ Yes
Load All Other Embeddings
    ↓
Compute Similarities (cosine similarity, filter >0.7, top 20)
    ↓
Store Associations (INSERT OR REPLACE into note_associations)
    ↓
Return Result (count of associations created)
```

**Webhook endpoint:** `POST /webhook/api/associate`

**Input:** `{"note_id": 42}` or `{"note_ids": [42, 43, 44]}`

**Output:** `{"note_id": 42, "associations_created": 15}`

---

## Core Implementation

### Cosine Similarity Function

```javascript
function cosineSimilarity(vecA, vecB) {
  let dotProduct = 0, normA = 0, normB = 0;
  for (let i = 0; i < vecA.length; i++) {
    dotProduct += vecA[i] * vecB[i];
    normA += vecA[i] * vecA[i];
    normB += vecB[i] * vecB[i];
  }
  return dotProduct / (Math.sqrt(normA) * Math.sqrt(normB));
}
```

### Algorithm

1. Load source note's embedding (768 floats from nomic-embed-text)
2. Load all other embeddings from `note_embeddings` table
3. For each other embedding:
   - Compute cosine similarity
   - If similarity >= 0.7, add to candidates
4. Sort candidates by similarity descending
5. Take top 20

### Storage Convention

Store associations with `note_a_id < note_b_id` to prevent duplicates:

```sql
INSERT OR REPLACE INTO note_associations
  (note_a_id, note_b_id, similarity_score, updated_at)
VALUES (?, ?, ?, CURRENT_TIMESTAMP)
```

Where:
- `note_a_id = MIN(source_note_id, target_note_id)`
- `note_b_id = MAX(source_note_id, target_note_id)`

Query associations for a note:
```sql
SELECT * FROM note_associations
WHERE note_a_id = ? OR note_b_id = ?
```

---

## Triggering

### Real-time (after embedding)

Add node to end of Workflow 10-Embedding-Generation:

```javascript
// "Trigger Association Computation" node
const noteId = $json.note_id;

const response = await $http.request({
  method: 'POST',
  url: 'http://localhost:5678/webhook/api/associate',
  body: { note_id: noteId },
  json: true
});

return { json: { note_id: noteId, association_triggered: true } };
```

### Batch (for existing notes)

Script: `scripts/batch-compute-associations.sh`

```bash
# Get notes with embeddings but no associations
NOTE_IDS=$(sqlite3 "$DB_PATH" "
  SELECT DISTINCT ne.raw_note_id
  FROM note_embeddings ne
  WHERE NOT EXISTS (
    SELECT 1 FROM note_associations na
    WHERE ne.raw_note_id = na.note_a_id
       OR ne.raw_note_id = na.note_b_id
  )
")

# Call webhook for each
for NOTE_ID in $NOTE_IDS; do
  curl -s -X POST "$WEBHOOK_URL" \
    -H "Content-Type: application/json" \
    -d "{\"note_id\": $NOTE_ID}"
  sleep 0.5  # Rate limit
done
```

---

## Testing

**Test script:** `workflows/11-association-computation/scripts/test-with-markers.sh`

| Test | Description | Expected |
|------|-------------|----------|
| 1 | Single note association | Associations created, count returned |
| 2 | Note without embedding | Skip gracefully, no error |
| 3 | Threshold filtering | Only similarities >= 0.7 stored |
| 4 | Max limit | At most 20 associations per note |
| 5 | Duplicate prevention | Re-running updates, doesn't duplicate |

---

## Deliverables

| File | Purpose |
|------|---------|
| `workflows/11-association-computation/workflow.json` | Main workflow |
| `workflows/11-association-computation/README.md` | Quick start |
| `workflows/11-association-computation/docs/STATUS.md` | Test results |
| `workflows/11-association-computation/scripts/test-with-markers.sh` | Test script |
| `scripts/batch-compute-associations.sh` | Batch backfill |
| Modified: `workflows/10-embedding-generation/workflow.json` | Add trigger node |

---

## Performance Notes

- With ~100 notes: loads ~100 embeddings × 768 floats = ~300KB
- Well within memory limits
- Will scale to 1000+ notes without issue
- For very large datasets (10k+), consider chunked loading

---

## Database Schema (exists from US-040)

```sql
CREATE TABLE note_associations (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    note_a_id INTEGER NOT NULL,
    note_b_id INTEGER NOT NULL,
    similarity_score REAL NOT NULL,
    created_at TEXT DEFAULT CURRENT_TIMESTAMP,
    updated_at TEXT DEFAULT CURRENT_TIMESTAMP,
    FOREIGN KEY (note_a_id) REFERENCES raw_notes(id),
    FOREIGN KEY (note_b_id) REFERENCES raw_notes(id),
    UNIQUE(note_a_id, note_b_id)
);

CREATE INDEX idx_associations_a ON note_associations(note_a_id);
CREATE INDEX idx_associations_b ON note_associations(note_b_id);
CREATE INDEX idx_associations_score ON note_associations(similarity_score DESC);
```
