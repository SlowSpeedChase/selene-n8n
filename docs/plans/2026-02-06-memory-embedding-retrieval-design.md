# Memory Embedding Retrieval Design

**Created:** 2026-02-06
**Status:** Ready
**Topic:** selenechat

---

## Problem Statement

MemoryService retrieval uses keyword matching: it loads 50 memories, splits them into words, and counts overlap with the query. This means "I prefer local-first architecture" never matches a query like "should we use cloud services?" even though they're semantically related.

The `conversation_memories` table has an `embedding BLOB` column that is never populated. `OllamaService.embed()` already exists. The wiring isn't connected.

The same weakness affects consolidation - finding "similar" memories to decide ADD/UPDATE/DELETE/NOOP also needs semantic matching.

---

## Solution Overview

Add embedding-based vector search to MemoryService for both retrieval and consolidation. All computation happens in Swift using the existing OllamaService. No backend changes.

---

## Architecture

```
Memory Creation:
  extract fact → OllamaService.embed(fact) → store fact + embedding in SQLite

Retrieval (for system prompt):
  user message → OllamaService.embed(message) → cosine similarity vs all memory embeddings → top 5

Consolidation (for ADD/UPDATE/DELETE):
  candidate fact → OllamaService.embed(fact) → cosine similarity vs all memory embeddings → top 10 similar → LLM decides
```

Storage format: 768 floats serialized as a JSON string in the existing `embedding BLOB` column. Same format the `note_embeddings` table uses. Simple to debug, small enough for <500 memories.

Existing memories without embeddings get backfilled on first app launch after the upgrade.

---

## Components

### 1. VectorUtility.swift (new)

Pure utility, no dependencies:

```swift
/// Compute cosine similarity between two vectors. Returns -1.0 to 1.0.
func cosineSimilarity(_ a: [Float], _ b: [Float]) -> Float

/// Serialize [Float] to JSON string for SQLite BLOB storage.
func serializeEmbedding(_ embedding: [Float]) -> Data

/// Deserialize JSON string from SQLite BLOB to [Float].
func deserializeEmbedding(_ data: Data) -> [Float]?
```

### 2. MemoryService.consolidateMemory() (modified)

Instead of receiving pre-found `similarMemories` from the caller:
- Embeds the candidate fact via `OllamaService.embed()`
- Loads all memory embeddings, computes cosine similarity (threshold 0.7)
- Passes top 10 similar memories to the LLM for ADD/UPDATE/DELETE/NOOP
- Stores the embedding alongside the new memory on ADD

### 3. MemoryService.getRelevantMemories() (modified)

Replaces keyword matching:
- Embeds the user query via `OllamaService.embed()`
- Cosine similarity against all memory embeddings
- Ranks by `similarity * confidence`
- Returns top 5 above threshold (0.5)
- Touches `last_accessed` for reinforcement
- Falls back to keyword matching if Ollama unavailable

### 4. DatabaseService (modified)

New methods:
- `getAllMemoriesWithEmbeddings() -> [(ConversationMemory, [Float]?)]` - Returns memories with parsed embeddings
- `saveMemoryEmbedding(id:, embedding:)` - Updates embedding column

### 5. Backfill (on app launch)

Check for memories with NULL embeddings. Embed each via Ollama, save. Runs once, idempotent. Called from app startup path.

---

## Edge Cases

**Ollama unavailable:**
- Memory creation: Store without embedding (NULL). Backfilled next launch.
- Retrieval: Fall back to keyword matching.
- Consolidation: Skip similarity search, default to ADD. Duplicates consolidate later.

The system degrades gracefully - never blocks chat because embedding failed.

---

## Thresholds

| Context | Threshold | Rationale |
|---------|-----------|-----------|
| Consolidation | 0.7 | High bar - only merge genuinely similar memories |
| Retrieval | 0.5 | Lower bar - cast wider net for relevant context |

Tunable. Start conservative, adjust based on real usage.

---

## Performance

| Operation | Cost | Notes |
|-----------|------|-------|
| Embed call | ~100ms | nomic-embed-text is fast |
| Cosine similarity (500 memories) | <1ms | Just dot products in Swift |
| Backfill (50 memories) | ~5s | One-time on first launch |
| Impact on chat latency | +~100ms | One embed call per query |

---

## Not In Scope

- Memory decay (separate feature, already designed)
- Entity graph (Phase 3 in original memory design)
- Memory visibility UI (viewing/editing memories)

---

## Acceptance Criteria

- [ ] Memories are embedded on creation using nomic-embed-text (768-dim)
- [ ] Retrieval uses cosine similarity instead of keyword matching
- [ ] Consolidation uses cosine similarity to find similar memories
- [ ] Existing memories without embeddings are backfilled on launch
- [ ] Graceful degradation when Ollama is unavailable (keyword fallback)
- [ ] All data stays in local SQLite
- [ ] Existing tests continue to pass
- [ ] New tests cover vector utility, embedding retrieval, and consolidation

---

## ADHD Check

| Principle | How This Helps |
|-----------|----------------|
| Externalize working memory | Selene actually finds relevant memories now, not just keyword matches |
| Reduce friction | No need to repeat context - semantic matching catches related topics |
| Prevent hoarding | Better consolidation means fewer duplicate memories |

---

## Scope Check

**Estimated effort:** 2-3 days focused work

- VectorUtility + tests: 2 hours
- DatabaseService embedding methods + tests: 2 hours
- MemoryService retrieval upgrade + tests: 3 hours
- MemoryService consolidation upgrade + tests: 3 hours
- Backfill logic + tests: 2 hours
- Integration testing: 2 hours
