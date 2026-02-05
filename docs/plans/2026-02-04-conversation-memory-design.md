# Conversation Memory System Design

**Created:** 2026-02-04
**Status:** Vision
**Topic:** selenechat

---

## Problem Statement

SeleneChat currently has three pain points:

1. **Starts fresh every time** - Each conversation has no memory of past chats; user repeats context constantly
2. **Inconsistent responses** - Ollama gives different quality answers to similar questions
3. **No learning over time** - The AI doesn't get better at understanding user patterns, projects, or preferences

Selene already has pattern-learning at the note level (threads, associations, embeddings), but **conversations are ephemeral** - they don't feed back into the system.

---

## Solution Overview

Build a native conversation memory system that:
- Stores conversation history in SQLite (local-first)
- Extracts "memories" (facts, preferences, patterns) from conversations
- Consolidates memories intelligently (ADD/UPDATE/DELETE/NOOP)
- Retrieves relevant memories and injects them into conversation context
- Optionally tracks entity relationships for deeper pattern learning

**Architecture inspiration:** [mem0](https://github.com/mem0ai/mem0) patterns adapted for Selene's TypeScript/SQLite stack.

---

## Design Constraints

- **Data stays local** - All storage in SQLite, no external services
- **LLM swappable** - Works with Ollama now, can switch to Claude API later
- **Memory approach evolvable** - We own the schema, can change it
- **ADHD-optimized** - Prevents digital hoarding, keeps memories consolidated

---

## Database Schema

### conversations
Stores raw chat history.

```sql
CREATE TABLE conversations (
    id INTEGER PRIMARY KEY,
    session_id TEXT NOT NULL,        -- Groups messages in a session
    role TEXT NOT NULL,              -- 'user' or 'assistant'
    content TEXT NOT NULL,
    created_at DATETIME DEFAULT CURRENT_TIMESTAMP
);

CREATE INDEX idx_conversations_session ON conversations(session_id);
CREATE INDEX idx_conversations_created ON conversations(created_at);
```

### conversation_memories
Extracted facts from conversations.

```sql
CREATE TABLE conversation_memories (
    id INTEGER PRIMARY KEY,
    content TEXT NOT NULL,           -- The fact itself
    source_session_id TEXT,          -- Which conversation it came from
    embedding BLOB,                  -- For similarity search
    memory_type TEXT,                -- 'preference', 'fact', 'pattern', 'context'
    confidence REAL DEFAULT 1.0,     -- Decays over time if not reinforced
    last_accessed DATETIME,          -- For relevance tracking
    created_at DATETIME DEFAULT CURRENT_TIMESTAMP,
    updated_at DATETIME DEFAULT CURRENT_TIMESTAMP
);

CREATE INDEX idx_memories_type ON conversation_memories(memory_type);
CREATE INDEX idx_memories_confidence ON conversation_memories(confidence);
```

### memory_entities (Optional)
Entities extracted from memories for graph relationships.

```sql
CREATE TABLE memory_entities (
    id INTEGER PRIMARY KEY,
    name TEXT NOT NULL UNIQUE,       -- "Claude Code", "ADHD", "Selene"
    entity_type TEXT,                -- 'person', 'project', 'concept', 'tool'
    embedding BLOB,
    created_at DATETIME DEFAULT CURRENT_TIMESTAMP
);

CREATE INDEX idx_entities_type ON memory_entities(entity_type);
```

### memory_relationships (Optional)
Relationships between entities.

```sql
CREATE TABLE memory_relationships (
    id INTEGER PRIMARY KEY,
    source_entity_id INTEGER REFERENCES memory_entities(id),
    target_entity_id INTEGER REFERENCES memory_entities(id),
    relationship TEXT,               -- "uses", "struggles_with", "prefers"
    valid BOOLEAN DEFAULT TRUE,      -- Mark invalid instead of delete
    created_at DATETIME DEFAULT CURRENT_TIMESTAMP
);

CREATE INDEX idx_relationships_source ON memory_relationships(source_entity_id);
CREATE INDEX idx_relationships_target ON memory_relationships(target_entity_id);
```

---

## Memory Extraction Flow

When a chat message is exchanged in SeleneChat:

```
User sends message
       ↓
SeleneChat stores message in `conversations` table
       ↓
Assistant responds
       ↓
SeleneChat stores response in `conversations` table
       ↓
Extract memories (can be async):
  - Last 10 messages (local context)
  - Conversation summary (global context, if exists)
  - Current exchange
       ↓
Ollama returns candidate facts as JSON:
  [
    {"fact": "User prefers local-first architecture", "type": "preference"},
    {"fact": "User is building Selene for ADHD management", "type": "context"}
  ]
       ↓
For each candidate fact:
  - Generate embedding
  - Vector search existing memories (top 10)
  - Call Ollama to decide: ADD / UPDATE / DELETE / NOOP
       ↓
Execute operations on `conversation_memories` table
```

### Extraction Prompt

```
You are a memory extraction system for Selene, an ADHD-focused assistant.

Given this conversation context and the latest exchange, extract any facts
worth remembering about the user - their preferences, patterns, projects,
or important context.

RECENT MESSAGES:
{recent_messages}

CONVERSATION SUMMARY:
{summary}

CURRENT EXCHANGE:
User: {user_message}
Assistant: {assistant_response}

Return JSON array of facts. Only extract what's genuinely useful for future
conversations. Be selective, not exhaustive.

OUTPUT FORMAT (strict JSON):
{
  "facts": [
    {"fact": "...", "type": "preference|fact|pattern|context", "confidence": 0.0-1.0}
  ]
}
```

---

## Consolidation Logic

For each candidate fact, decide whether to ADD, UPDATE, DELETE, or NOOP.

### Consolidation Prompt

```
You are managing a memory system. Given a new fact and existing similar
memories, decide what to do.

NEW FACT: "{candidate_fact}"

EXISTING SIMILAR MEMORIES:
{similar_memories}

Respond with JSON:
- {"action": "ADD"} - New information, nothing equivalent exists
- {"action": "UPDATE", "memoryId": N, "merged": "combined fact"} - Augment existing
- {"action": "DELETE", "memoryId": N, "reason": "..."} - New fact contradicts this
- {"action": "NOOP", "reason": "..."} - Already known or not worth storing

Consider:
- Is this genuinely new information?
- Does it contradict or update something we know?
- Is it worth remembering long-term?
```

### Pseudocode

```typescript
async function consolidateMemory(
  candidateFact: string,
  factType: string,
  confidence: number
): Promise<void> {
  // 1. Generate embedding for candidate
  const embedding = await ollama.embed(candidateFact);

  // 2. Find similar existing memories
  const similar = await vectorSearch('conversation_memories', embedding, {
    limit: 10,
    threshold: 0.6
  });

  // 3. If no similar memories, just ADD
  if (similar.length === 0) {
    await insertMemory(candidateFact, factType, confidence, embedding);
    return;
  }

  // 4. Ask LLM to decide
  const decision = await ollama.generate(consolidationPrompt(candidateFact, similar));

  // 5. Execute decision
  switch (decision.action) {
    case 'ADD':
      await insertMemory(candidateFact, factType, confidence, embedding);
      break;
    case 'UPDATE':
      await updateMemory(decision.memoryId, decision.merged);
      break;
    case 'DELETE':
      await deleteMemory(decision.memoryId);
      break;
    case 'NOOP':
      // Do nothing
      break;
  }
}
```

---

## Memory Retrieval & Context Injection

When SeleneChat receives a message, retrieve relevant memories to inject into context.

### Retrieval Logic

```typescript
async function getRelevantMemories(userMessage: string): Promise<Memory[]> {
  // 1. Embed the user's message
  const queryEmbedding = await ollama.embed(userMessage);

  // 2. Vector search conversation_memories
  const memories = await vectorSearch('conversation_memories', queryEmbedding, {
    limit: 10,
    threshold: 0.7
  });

  // 3. Rank by confidence and recency
  const ranked = memories.sort((a, b) => {
    const recencyA = daysSince(a.last_accessed);
    const recencyB = daysSince(b.last_accessed);
    return (b.confidence - recencyB * 0.01) - (a.confidence - recencyA * 0.01);
  });

  // 4. Update last_accessed for retrieved memories (reinforcement)
  await touchMemories(ranked.map(m => m.id));

  return ranked.slice(0, 5);
}
```

### System Prompt Injection

```typescript
const memories = await getRelevantMemories(userMessage);

const systemPrompt = `
You are Selene, an ADHD-focused assistant.

## What you remember about this user:
${memories.length > 0
  ? memories.map(m => `- ${m.content}`).join('\n')
  : '(No specific memories yet)'}

## Relevant notes:
${await getRelevantNotes(userMessage)}
`;
```

---

## Entity Graph (Optional Enhancement)

For deeper pattern learning, extract entities and relationships.

### Entity Extraction Prompt

```
Given this message and extracted facts, identify entities and relationships.

MESSAGE: "{message}"
FACTS: {facts}

Return JSON:
{
  "entities": [
    {"name": "Selene", "type": "project"},
    {"name": "ADHD", "type": "condition"}
  ],
  "relationships": [
    {"source": "Selene", "target": "ADHD", "relationship": "designed_for"},
    {"source": "User", "target": "local-first", "relationship": "prefers"}
  ]
}
```

### Relationship Accumulation

Over time, relationships build a graph of the user's world:

```
(User) --builds--> (Selene)
(Selene) --designed_for--> (ADHD)
(User) --prefers--> (local-first)
(User) --admires--> (Linear)
(Linear) --has_good--> (keyboard shortcuts)
```

Obsolete relationships are marked `valid=false` rather than deleted, preserving history.

---

## Background Workflows

### New TypeScript Workflows

| Workflow | Schedule | Purpose |
|----------|----------|---------|
| `refresh-conversation-summaries.ts` | Every 30 min | Update global conversation summaries |
| `decay-memories.ts` | Daily 3am | Reduce confidence on unused memories |
| `update-memory-graph.ts` | Every 30 min | Extract entities from recent memories |

### Memory Decay Logic

```typescript
// decay-memories.ts
async function decayMemories(): Promise<void> {
  // Reduce confidence for memories not accessed in 30+ days
  await db.run(`
    UPDATE conversation_memories
    SET confidence = confidence * 0.95,
        updated_at = CURRENT_TIMESTAMP
    WHERE last_accessed < datetime('now', '-30 days')
      AND confidence > 0.1
  `);

  // Archive very low confidence memories
  await db.run(`
    DELETE FROM conversation_memories
    WHERE confidence < 0.1
      AND last_accessed < datetime('now', '-90 days')
  `);
}
```

---

## SeleneChat Integration

### Swift Changes Required

1. **DatabaseService** - Add methods:
   - `saveConversationMessage(sessionId:, role:, content:)`
   - `getRecentMessages(sessionId:, limit:) -> [Message]`
   - `searchMemories(embedding:, limit:) -> [Memory]`
   - `insertMemory(content:, type:, confidence:, embedding:)`
   - `updateMemoryAccess(ids:)`

2. **OllamaService** - Modify:
   - Inject relevant memories into system prompt
   - Add `extractMemories(messages:) -> [CandidateFact]`
   - Add `consolidateMemory(fact:, similar:) -> Decision`

3. **ChatView** - Modify:
   - Store messages after each exchange
   - Trigger memory extraction (can be async/background)

### Session Management

Each SeleneChat window gets a `session_id` (UUID). Messages within that session are grouped. When the window closes, the session ends but history persists.

---

## Structured Output Validation

For reliable LLM outputs, enforce structure:

```typescript
interface ExtractionResult {
  facts: Array<{
    fact: string;
    type: 'preference' | 'fact' | 'pattern' | 'context';
    confidence: number;
  }>;
}

function validateExtraction(response: string): ExtractionResult | null {
  try {
    const parsed = JSON.parse(response);
    if (!Array.isArray(parsed.facts)) return null;
    for (const fact of parsed.facts) {
      if (typeof fact.fact !== 'string') return null;
      if (!['preference', 'fact', 'pattern', 'context'].includes(fact.type)) return null;
      if (typeof fact.confidence !== 'number') return null;
    }
    return parsed;
  } catch {
    return null;
  }
}

async function extractWithRetry(prompt: string, maxRetries = 2): Promise<ExtractionResult> {
  for (let i = 0; i < maxRetries; i++) {
    const response = await ollama.generate(prompt);
    const validated = validateExtraction(response);
    if (validated) return validated;
    // Retry with stricter instructions
  }
  return { facts: [] }; // Safe fallback
}
```

---

## Implementation Phases

### Phase 1: Core Memory (MVP)
- [ ] Database migration (conversations, conversation_memories)
- [ ] Store conversations in SeleneChat
- [ ] Memory extraction on each exchange
- [ ] Simple ADD-only consolidation (no UPDATE/DELETE yet)
- [ ] Memory retrieval and injection

### Phase 2: Smart Consolidation
- [ ] Full ADD/UPDATE/DELETE/NOOP logic
- [ ] Confidence scoring
- [ ] Memory decay workflow

### Phase 3: Entity Graph
- [ ] Entity extraction
- [ ] Relationship tracking
- [ ] Graph-based queries ("what tools do I like?")

### Phase 4: Refinement
- [ ] Conversation summary generation
- [ ] Tune extraction prompts based on real usage
- [ ] Performance optimization

---

## Acceptance Criteria

- [ ] SeleneChat remembers facts from previous conversations
- [ ] Relevant memories appear in AI responses naturally
- [ ] Memories consolidate (no duplicate facts)
- [ ] Unused memories decay over time
- [ ] All data stays in local SQLite
- [ ] Works with current Ollama setup
- [ ] Can swap LLM provider without schema changes

---

## ADHD Check

| Principle | How This Helps |
|-----------|----------------|
| Externalize working memory | AI remembers so you don't have to |
| Reduce friction | No need to repeat context every session |
| Visual over mental | Memories surface automatically, not recalled mentally |
| Prevent hoarding | Consolidation keeps memories lean, not sprawling |

---

## Scope Check

**Estimated effort:** ~1 week focused work for Phase 1 (MVP)

**Breakdown:**
- Database migration: 1 hour
- Swift DatabaseService methods: 4 hours
- Memory extraction flow: 4 hours
- Memory retrieval/injection: 2 hours
- Testing and iteration: 4 hours

Phase 2-4 are follow-on work after MVP is validated.

---

## References

- [mem0 GitHub](https://github.com/mem0ai/mem0) - Architecture inspiration
- [mem0 Graph Memory Docs](https://docs.mem0.ai/open-source/features/graph-memory)
- [mem0 Research Paper](https://arxiv.org/abs/2504.19413) - Technical details
- [DSPy](https://github.com/stanfordnlp/dspy) - Structured prompt patterns
- [How to Build Your Own Custom LLM Memory Layer](https://towardsdatascience.com/how-to-build-your-own-custom-llm-memory-layer-from-scratch/) - Implementation guide

---

## Open Questions

1. Should memory extraction be synchronous (slower but immediate) or async (faster but delayed)?
2. What's the right threshold for "similar enough" in consolidation?
3. Should the entity graph be mandatory or optional?
4. How to handle conflicting memories gracefully?
