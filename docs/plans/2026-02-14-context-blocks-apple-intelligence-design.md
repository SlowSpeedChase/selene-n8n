# Context Blocks + Apple Intelligence Integration

**Status:** Ready
**Date:** 2026-02-14
**Problem:** Thread conversations pull all notes, truncate at 3000 tokens, and lose the specific context being discussed. Results in generic, irrelevant LLM responses.

---

## Solution

Pre-process notes into idea-level chunks with topic labels. Thread conversations retrieve only the chunks relevant to the current discussion via semantic search. Add Apple Intelligence as an LLM provider alongside Ollama, with task-type routing to use the best model for each job.

---

## 1. Chunking Service (Swift, in SeleneChat)

New `ChunkingService` in SeleneShared. Runs in background within SeleneChat.

**Hybrid chunking:**
1. **Rule-based split** — paragraphs, headers, double newlines. Merge chunks <100 tokens, split chunks >300 tokens at sentence boundaries. Target: 100-256 tokens per chunk.
2. **LLM topic labeling** — Apple Foundation Models (`contentTagging` variant) generates a 5-10 word topic label per chunk. Fast, on-device, no Ollama needed.
3. **Embed** — nomic-embed-text via Ollama generates vector embedding per chunk.
4. **Store** — `note_chunks` table + vector store.

**Processing trigger:** Background timer every 60 seconds checks for unchunked notes. Also runs on app launch.

**Schema:**
```sql
CREATE TABLE note_chunks (
    id INTEGER PRIMARY KEY,
    note_id INTEGER NOT NULL,
    chunk_index INTEGER NOT NULL,
    content TEXT NOT NULL,
    topic TEXT,
    token_count INTEGER NOT NULL,
    embedding BLOB,
    created_at TEXT NOT NULL,
    UNIQUE(note_id, chunk_index)
);
```

---

## 2. Apple Intelligence LLM Provider

New `AppleIntelligenceService` conforming to existing `LLMProvider` protocol.

**Two tiers:**
- **On-device** — Apple Foundation Models framework (~3B model). Fast, private. Optimized for summarization, classification, extraction, structured output. 4,096 token context window (fixed).
- **Private Cloud Compute** — For tasks exceeding on-device capability. End-to-end encrypted, no data retention. Larger model, more reasoning capacity.

**API surface:**
```swift
class AppleIntelligenceService: LLMProvider {
    func generate(prompt: String, model: String?) async throws -> String
    func labelTopic(chunk: String) async throws -> String
}
```

**Requires:** macOS 26+, Apple Silicon, Apple Intelligence enabled. User is on Darwin 25.3.0 (macOS 26).

---

## 3. LLM Router

New `LLMRouter` service between ViewModels and LLM providers. Routes tasks to the best model based on task type.

**Task-type defaults (research-backed):**

| Task Type | Default Provider | Reasoning |
|-----------|-----------------|-----------|
| `chunkLabeling` | Apple on-device (`contentTagging`) | Built for this. Apple 3B outperforms Mistral 7B on extraction. |
| `embedding` | nomic-embed-text (Ollama) | Higher retrieval quality (768D vs 512D). Apple NLContextualEmbedding's 256-token limit works for chunks but nomic has better benchmarks. |
| `queryAnalysis` | Apple on-device | Fast classification. On-device latency beats Ollama roundtrip. |
| `summarization` | Apple on-device | Apple's primary optimization target. Fast, good quality. |
| `threadChat` | Ollama mistral:7b | Needs 8K+ context for chunks + conversation history. Apple's 4K is too tight. |
| `briefing` | Ollama mistral:7b | Multi-note synthesis needs large context window. |
| `deepDive` | Ollama mistral:7b | Complex reasoning with rich context. |

**Defaults stored in UserDefaults, overridable in Settings.**

**Interface:**
```swift
class LLMRouter {
    enum TaskType {
        case chunkLabeling, embedding, queryAnalysis
        case threadChat, briefing, summarization, deepDive
    }
    func provider(for task: TaskType) -> LLMProvider
    func setProvider(_ provider: ProviderType, for task: TaskType)
}
```

ViewModels call `router.provider(for: .threadChat).generate(...)` instead of `ollamaService.generate(...)` directly.

---

## 4. Thread Chat Retrieval

Replaces the current "load all notes, truncate at 3000 tokens" approach.

**New flow per message:**
1. **Embed query** — nomic-embed-text generates vector for user's message.
2. **Search thread chunks** — cosine similarity against chunks belonging to current thread's notes. Return top 10-15 chunks.
3. **Relevance threshold** — if best chunk scores below 0.5, expand to global search across all note chunks.
4. **Assemble context** — chunks ordered by relevance, each prefixed with topic label and source note title. Token budget: ~8000 tokens.
5. **Include conversation history** — prior turns in prompt, same as now.
6. **Pin referenced chunks** — store which chunk IDs were included per turn. Follow-up turns always include pinned chunks + new relevant chunks.

**Ollama config change:** Pass `num_ctx: 16384` in generate options (currently using default 8192).

**Files changed:**
- `ThinkingPartnerContextBuilder.buildDeepDiveContext()` — replaced with chunk retrieval
- `ThreadWorkspaceChatViewModel` — tracks referenced chunk IDs per conversation
- `OllamaService.generate()` — passes `num_ctx: 16384` in options
- `ThreadWorkspacePromptBuilder` — formats retrieved chunks instead of raw notes

---

## 5. Migration

**One-time reprocessing of existing notes:**
1. SeleneChat detects empty `note_chunks` table on launch.
2. Queues all existing notes for background chunking via `ChunkingService`.
3. Shows progress indicator: "Indexing notes for smarter conversations... (47/312)"
4. App remains usable. Thread chat falls back to current all-notes approach until a thread's notes are fully chunked.

**Ongoing:**
- Background timer (60s) checks for unchunked notes.
- Updated notes: delete existing chunks, regenerate.
- No TypeScript pipeline changes. Chunking is entirely Swift-side.

---

## Scope Check

**In scope:**
- ChunkingService (rule-based split + Apple topic labeling)
- note_chunks table + embeddings
- AppleIntelligenceService (LLMProvider conformance)
- LLMRouter with task-type defaults
- Thread chat retrieval rewrite (chunk-based)
- Chunk pinning for conversation continuity
- Migration of existing notes
- num_ctx increase for Ollama

**Out of scope:**
- Replacing Ollama entirely
- Settings UI for provider overrides (use defaults for now, add UI later)
- iOS/SeleneMobile changes (macOS only, Apple Foundation Models are Swift-native)
- Changing the TypeScript processing pipeline

---

## ADHD Check

- **Reduces friction:** Thread chat gives relevant responses without user needing to re-explain context
- **Externalizes memory:** Chunk pinning preserves conversation context across turns
- **Visual feedback:** Migration progress indicator shows system is working
- **No new cognitive load:** Chunking is invisible to user, routing uses sensible defaults
