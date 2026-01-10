# Workflow 11: Association Computation

Computes cosine similarity between note embeddings and stores top associations.

## Quick Start

```bash
# Test single note
curl -X POST http://localhost:5678/webhook/api/associate \
  -H "Content-Type: application/json" \
  -d '{"note_id": 42}'

# Test multiple notes
curl -X POST http://localhost:5678/webhook/api/associate \
  -H "Content-Type: application/json" \
  -d '{"note_ids": [1, 2, 3]}'
```

## Parameters

- **Similarity Threshold:** 0.7 (only associations above this are stored)
- **Max Associations:** 20 per note

## Storage Convention

Associations are stored with `note_a_id < note_b_id` to prevent duplicates.

Query associations for a note:
```sql
SELECT * FROM note_associations
WHERE note_a_id = ? OR note_b_id = ?
ORDER BY similarity_score DESC;
```

## Workflow

```
Webhook (/api/associate)
    ↓
Normalize Input
    ↓
Split Into Items
    ↓
Fetch Source Embedding
    ↓
Has Embedding? ──No──→ Skip
    ↓ Yes
Compute Similarities
    ↓
Store Associations
    ↓
Aggregate Results
```

## Testing

```bash
./workflows/11-association-computation/scripts/test-with-markers.sh
```

## Related

- **Workflow 10:** Embedding Generation (creates embeddings this workflow uses)
- **US-043:** Story for this workflow
- **Design:** `docs/plans/2026-01-05-association-computation-design.md`
