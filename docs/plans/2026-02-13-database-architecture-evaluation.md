# Database Architecture Evaluation: Vector & Graph Databases

**Created:** 2026-02-13
**Status:** Vision
**Topic:** architecture, infra

---

## Question

Does Selene need a dedicated vector database or graph database to improve note retrieval, associations, and memory?

---

## Current Architecture

### Storage Layer
- **SQLite** (better-sqlite3) — primary store for notes, threads, projects, relationships, memories
- **LanceDB** (embedded) — vector search for note embeddings (768-dim nomic-embed-text)

### What's Already Working
- `src/lib/lancedb.ts` — connection, CRUD, vector search with facet filtering
- `src/workflows/index-vectors.ts` — embeds processed notes into LanceDB
- `src/queries/related-notes.ts` — hybrid query: precomputed relationships + live vector search
- `note_relationships` table — typed edges (BT/NT/RT/TEMPORAL/SAME_THREAD/SAME_PROJECT)
- `conversation_memories` table — SeleneChat memories with embedding column (populated via OllamaService)

### Scale (as of 2026-02-13)
- 126 raw notes, 117 with embeddings, 307 associations
- <500 conversation memories
- O(n^2) pairwise computation in deprecated workflows replaced by LanceDB search

---

## Evaluation

### Vector Database

**Status: Already adopted (LanceDB)**

LanceDB is embedded, serverless, and already integrated. It replaced the O(n^2) brute-force cosine similarity in `_deprecated_compute-associations.ts` with O(log n) indexed search. No further migration needed.

**When to revisit:** If LanceDB's embedded architecture becomes a bottleneck (unlikely below 100K notes) or if multi-process concurrent writes are needed.

### Graph Database (Neo4j, etc.)

**Recommendation: Not needed.**

Selene's relationship model is already a lightweight graph stored in SQLite:
- `note_relationships` table = typed edges between notes
- `threads` / `thread_notes` = grouping structure
- `projects` / `project_notes` = another grouping axis

The queries that matter are shallow:
- "What's related to this note?" — 1-hop, already served by `getRelatedNotes()`
- "What notes share a thread/project?" — 1-hop JOIN
- "What's connected to things connected to this?" — 2-hop, achievable with:

```sql
SELECT DISTINCT nr2.note_b_id
FROM note_relationships nr1
JOIN note_relationships nr2 ON nr1.note_b_id = nr2.note_a_id
WHERE nr1.note_a_id = ?
```

A graph database would add value for:
- Deep traversals (3+ hops) — not currently needed
- Complex path-finding ("how does concept A relate to concept B through my notes?") — interesting but speculative
- Dynamic graph algorithms (PageRank, community detection) — could surface "hub" notes, but premature

**Trade-off:** Neo4j adds a server process, a query language (Cypher), and operational complexity. This directly conflicts with the ADHD design principle of reducing friction and keeping the system simple to maintain.

**When to revisit:** If the entity graph feature (Phase 3 in original memory design) becomes a priority, or if relationship traversals regularly need 3+ hops.

---

## Remaining Optimizations

These are algorithmic improvements within the current architecture, not infrastructure changes:

### 1. Binary Embedding Storage in SQLite

The deprecated `note_embeddings` table stores embeddings as JSON strings (~15KB per 768-dim vector). The `conversation_memories.embedding` column already uses binary BLOB. If any code still reads from `note_embeddings`, migrate to binary format (Float32Array buffer, ~3KB per vector).

**Impact:** 5x storage reduction, eliminates JSON.parse overhead.

### 2. Incremental Relationship Computation

`compute-relationships.ts` recomputes all temporal and structural relationships each run. Adding a "last computed" watermark would let it process only new notes.

**Impact:** Faster scheduled runs as note count grows.

### 3. SeleneChat Memory Retrieval (In Progress)

Design doc `2026-02-06-memory-embedding-retrieval-design.md` covers embedding-based memory retrieval. This replaces keyword matching with cosine similarity in Swift, using existing OllamaService. Already marked Done in INDEX.md.

---

## Decision Summary

| Component | Decision | Rationale |
|-----------|----------|-----------|
| Vector search | Keep LanceDB (already integrated) | Embedded, O(log n), no server |
| Graph queries | Keep SQLite relationships | Shallow traversals, simple ops |
| Graph database | Skip | Operational complexity vs. marginal benefit at current scale |
| Next optimization | Incremental relationship computation | Biggest remaining algorithmic win |

**Revisit triggers:**
- Note count exceeds 5,000 — benchmark LanceDB query latency
- Note count exceeds 10,000 — evaluate whether relationship queries need indexing changes
- Entity graph feature prioritized — reconsider lightweight graph (e.g., SQLite recursive CTEs before Neo4j)
