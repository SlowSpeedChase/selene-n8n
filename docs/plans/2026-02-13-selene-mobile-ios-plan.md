# Selene Mobile (iOS) Implementation Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** Native iOS app with full SeleneChat parity, communicating with the Mac over Tailscale via an expanded Fastify REST API.

**Architecture:** Three-target Swift package (SeleneShared library + macOS app + iOS app) with protocol-based data layer. Fastify server expanded with ~30 REST endpoints + Ollama proxy + APNs. iPhone connects to Mac's Tailscale IP on port 5678.

**Tech Stack:** Swift 5.9+, SwiftUI, SPM, Fastify/TypeScript, better-sqlite3, Ollama, APNs, ActivityKit, Tailscale

**Design Doc:** `docs/plans/2026-02-13-selene-mobile-ios-design.md`

---

## Phase 1: Server API (TypeScript)

Expand the Fastify server with REST endpoints, auth middleware, and Ollama proxy. The iOS app will call these exclusively.

### Task 1: Auth Middleware

**Files:**
- Create: `src/lib/auth.ts`
- Modify: `src/server.ts`
- Modify: `src/lib/config.ts`
- Create: `.env.example` (update)

**Step 1: Add API token to config**

In `src/lib/config.ts`, add to the config object:

```typescript
// API authentication
apiToken: process.env.SELENE_API_TOKEN || '',
```

**Step 2: Create auth middleware**

Create `src/lib/auth.ts`:

```typescript
import { FastifyRequest, FastifyReply } from 'fastify';
import { config } from './config';

export async function requireAuth(request: FastifyRequest, reply: FastifyReply) {
  // Skip auth if no token configured (local-only mode)
  if (!config.apiToken) return;

  const header = request.headers.authorization;
  if (!header || !header.startsWith('Bearer ')) {
    reply.status(401).send({ error: 'Missing or invalid Authorization header' });
    return;
  }

  const token = header.slice(7);
  if (token !== config.apiToken) {
    reply.status(403).send({ error: 'Invalid API token' });
    return;
  }
}
```

**Step 3: Register auth hook on /api/* routes in server.ts**

Add to `src/server.ts` after server creation:

```typescript
import { requireAuth } from './lib/auth';

// Auth middleware for all /api/* routes
server.addHook('onRequest', async (request, reply) => {
  if (request.url.startsWith('/api/')) {
    await requireAuth(request, reply);
  }
});
```

**Step 4: Test manually**

Set `SELENE_API_TOKEN=test-token-123` in `.env`, restart server.

```bash
# Should fail with 401
curl -s http://localhost:5678/api/search -X POST -H "Content-Type: application/json" -d '{"query":"test"}' | jq .

# Should succeed
curl -s http://localhost:5678/api/search -X POST -H "Content-Type: application/json" -H "Authorization: Bearer test-token-123" -d '{"query":"test"}' | jq .

# Health should still work without auth
curl -s http://localhost:5678/health | jq .
```

**Step 5: Commit**

```bash
git add src/lib/auth.ts src/lib/config.ts src/server.ts
git commit -m "feat(api): add bearer token auth middleware for remote access"
```

---

### Task 2: Notes API Endpoints

**Files:**
- Create: `src/routes/notes.ts`
- Modify: `src/server.ts`
- Modify: `src/lib/db.ts` (add query functions)

**Step 1: Add note query functions to db.ts**

Add to `src/lib/db.ts`:

```typescript
export function getAllNotes(limit = 100): RawNote[] {
  const stmt = db.prepare(`
    SELECT r.*, p.concepts, p.concept_confidence, p.primary_theme,
           p.secondary_themes, p.overall_sentiment, p.sentiment_score,
           p.emotional_tone, p.energy_level, p.note_type, p.actionability
    FROM raw_notes r
    LEFT JOIN processed_notes p ON r.id = p.note_id
    WHERE r.test_run IS NULL
    ORDER BY r.created_at DESC
    LIMIT ?
  `);
  return stmt.all(limit) as RawNote[];
}

export function getNoteById(id: number): RawNote | undefined {
  const stmt = db.prepare(`
    SELECT r.*, p.concepts, p.concept_confidence, p.primary_theme,
           p.secondary_themes, p.overall_sentiment, p.sentiment_score,
           p.emotional_tone, p.energy_level, p.note_type, p.actionability
    FROM raw_notes r
    LEFT JOIN processed_notes p ON r.id = p.note_id
    WHERE r.id = ? AND r.test_run IS NULL
  `);
  return stmt.get(id) as RawNote | undefined;
}

export function searchNotesKeyword(query: string, limit = 50): RawNote[] {
  const stmt = db.prepare(`
    SELECT r.*, p.concepts, p.concept_confidence, p.primary_theme,
           p.secondary_themes, p.overall_sentiment, p.sentiment_score,
           p.emotional_tone, p.energy_level, p.note_type, p.actionability
    FROM raw_notes r
    LEFT JOIN processed_notes p ON r.id = p.note_id
    WHERE r.test_run IS NULL
      AND (r.content LIKE ? OR r.title LIKE ?)
    ORDER BY r.created_at DESC
    LIMIT ?
  `);
  const pattern = `%${query}%`;
  return stmt.all(pattern, pattern, limit) as RawNote[];
}

export function getRecentNotes(days: number, limit = 10): RawNote[] {
  const stmt = db.prepare(`
    SELECT r.*, p.concepts, p.concept_confidence, p.primary_theme,
           p.secondary_themes, p.overall_sentiment, p.sentiment_score,
           p.emotional_tone, p.energy_level, p.note_type, p.actionability
    FROM raw_notes r
    LEFT JOIN processed_notes p ON r.id = p.note_id
    WHERE r.test_run IS NULL
      AND r.created_at >= datetime('now', '-' || ? || ' days')
    ORDER BY r.created_at DESC
    LIMIT ?
  `);
  return stmt.all(days, limit) as RawNote[];
}

export function getNotesSince(date: string, limit = 20): RawNote[] {
  const stmt = db.prepare(`
    SELECT r.*, p.concepts, p.concept_confidence, p.primary_theme,
           p.secondary_themes, p.overall_sentiment, p.sentiment_score,
           p.emotional_tone, p.energy_level, p.note_type, p.actionability
    FROM raw_notes r
    LEFT JOIN processed_notes p ON r.id = p.note_id
    WHERE r.test_run IS NULL
      AND r.created_at >= ?
    ORDER BY r.created_at DESC
    LIMIT ?
  `);
  return stmt.all(date, limit) as RawNote[];
}

export function getThreadAssignmentsForNotes(noteIds: number[]): Array<{ noteId: number; threadName: string; threadId: number }> {
  if (noteIds.length === 0) return [];
  const placeholders = noteIds.map(() => '?').join(',');
  const stmt = db.prepare(`
    SELECT tn.note_id as noteId, t.name as threadName, t.id as threadId
    FROM thread_notes tn
    JOIN threads t ON tn.thread_id = t.id
    WHERE tn.note_id IN (${placeholders})
  `);
  return stmt.all(...noteIds) as Array<{ noteId: number; threadName: string; threadId: number }>;
}
```

**Step 2: Create notes route file**

Create `src/routes/notes.ts`:

```typescript
import { FastifyInstance } from 'fastify';
import { getAllNotes, getNoteById, searchNotesKeyword, getRecentNotes, getNotesSince, getThreadAssignmentsForNotes } from '../lib/db';
import { getRelatedNotes, searchNotes } from '../queries/related-notes';
import { logger } from '../lib';

export async function notesRoutes(server: FastifyInstance) {
  // GET /api/notes?limit=100
  server.get<{ Querystring: { limit?: number } }>('/api/notes', async (request) => {
    const { limit = 100 } = request.query;
    const notes = getAllNotes(limit);
    return { count: notes.length, notes };
  });

  // GET /api/notes/:id
  server.get<{ Params: { id: string } }>('/api/notes/:id', async (request, reply) => {
    const id = parseInt(request.params.id, 10);
    if (isNaN(id)) {
      reply.status(400);
      return { error: 'Invalid note ID' };
    }
    const note = getNoteById(id);
    if (!note) {
      reply.status(404);
      return { error: 'Note not found' };
    }
    return note;
  });

  // POST /api/notes/search  (keyword search)
  server.post<{ Body: { query: string; limit?: number } }>('/api/notes/search', async (request, reply) => {
    const { query, limit = 50 } = request.body || {};
    if (!query) {
      reply.status(400);
      return { error: 'query is required' };
    }
    const notes = searchNotesKeyword(query, limit);
    return { query, count: notes.length, notes };
  });

  // GET /api/notes/recent?days=7&limit=10
  server.get<{ Querystring: { days?: number; limit?: number } }>('/api/notes/recent', async (request) => {
    const { days = 7, limit = 10 } = request.query;
    const notes = getRecentNotes(days, limit);
    return { days, count: notes.length, notes };
  });

  // GET /api/notes/since/:date?limit=20
  server.get<{ Params: { date: string }; Querystring: { limit?: number } }>('/api/notes/since/:date', async (request) => {
    const { date } = request.params;
    const { limit = 20 } = request.query;
    const notes = getNotesSince(date, limit);
    return { since: date, count: notes.length, notes };
  });

  // GET /api/notes/:id/related?limit=10
  server.get<{ Params: { id: string }; Querystring: { limit?: number } }>('/api/notes/:id/related', async (request, reply) => {
    const id = parseInt(request.params.id, 10);
    if (isNaN(id)) {
      reply.status(400);
      return { error: 'Invalid note ID' };
    }
    try {
      const results = await getRelatedNotes(id, { limit: request.query.limit || 10 });
      return { noteId: id, count: results.length, results };
    } catch (err) {
      const error = err as Error;
      logger.error({ err: error, noteId: id }, 'Related notes query failed');
      reply.status(500);
      return { error: error.message };
    }
  });

  // POST /api/notes/thread-assignments
  server.post<{ Body: { noteIds: number[] } }>('/api/notes/thread-assignments', async (request, reply) => {
    const { noteIds } = request.body || {};
    if (!noteIds || !Array.isArray(noteIds)) {
      reply.status(400);
      return { error: 'noteIds array is required' };
    }
    const assignments = getThreadAssignmentsForNotes(noteIds);
    return { count: assignments.length, assignments };
  });

  // POST /api/notes/retrieve (hybrid retrieval for ChatViewModel)
  server.post<{ Body: { query: string; limit?: number; noteType?: string; actionability?: string } }>('/api/notes/retrieve', async (request, reply) => {
    const { query, limit = 10, noteType, actionability } = request.body || {};
    if (!query) {
      reply.status(400);
      return { error: 'query is required' };
    }
    try {
      // Try semantic search first, fall back to keyword
      const results = await searchNotes(query, { limit, noteType, actionability });
      return { query, count: results.length, results };
    } catch (err) {
      // Fallback to keyword search
      const notes = searchNotesKeyword(query, limit);
      return { query, count: notes.length, results: notes, source: 'keyword_fallback' };
    }
  });
}
```

**Step 3: Register routes in server.ts**

Add to `src/server.ts`:

```typescript
import { notesRoutes } from './routes/notes';

// Register route modules
await notesRoutes(server);
```

Move this into the `start()` function before `server.listen()`, or register before starting.

**Step 4: Test endpoints**

```bash
# Get all notes
curl -s http://localhost:5678/api/notes?limit=5 | jq '.count'

# Get note by ID
curl -s http://localhost:5678/api/notes/1 | jq '.title'

# Search notes
curl -s http://localhost:5678/api/notes/search -X POST -H "Content-Type: application/json" -d '{"query":"ADHD","limit":3}' | jq '.count'

# Recent notes
curl -s "http://localhost:5678/api/notes/recent?days=7&limit=5" | jq '.count'
```

**Step 5: Commit**

```bash
git add src/routes/notes.ts src/lib/db.ts src/server.ts
git commit -m "feat(api): add notes REST endpoints for remote access"
```

---

### Task 3: Threads API Endpoints

**Files:**
- Create: `src/routes/threads.ts`
- Modify: `src/lib/db.ts` (add thread queries)
- Modify: `src/server.ts`

**Step 1: Add thread query functions to db.ts**

```typescript
export function getActiveThreads(limit = 10): any[] {
  const stmt = db.prepare(`
    SELECT t.*,
      (SELECT COUNT(*) FROM thread_notes tn WHERE tn.thread_id = t.id) as note_count
    FROM threads t
    WHERE t.status = 'active'
    ORDER BY t.momentum_score DESC NULLS LAST, t.last_activity_at DESC
    LIMIT ?
  `);
  return stmt.all(limit);
}

export function getThreadById(id: number): any | undefined {
  const stmt = db.prepare(`
    SELECT t.*,
      (SELECT COUNT(*) FROM thread_notes tn WHERE tn.thread_id = t.id) as note_count
    FROM threads t
    WHERE t.id = ?
  `);
  return stmt.get(id);
}

export function searchThreadByName(name: string): any | undefined {
  // Fuzzy match: case-insensitive LIKE
  const stmt = db.prepare(`
    SELECT t.*,
      (SELECT COUNT(*) FROM thread_notes tn WHERE tn.thread_id = t.id) as note_count
    FROM threads t
    WHERE LOWER(t.name) LIKE LOWER(?)
    ORDER BY t.momentum_score DESC NULLS LAST
    LIMIT 1
  `);
  return stmt.get(`%${name}%`);
}

export function getThreadNotes(threadId: number, limit = 20): RawNote[] {
  const stmt = db.prepare(`
    SELECT r.*, p.concepts, p.concept_confidence, p.primary_theme,
           p.secondary_themes, p.overall_sentiment, p.sentiment_score,
           p.emotional_tone, p.energy_level
    FROM thread_notes tn
    JOIN raw_notes r ON tn.note_id = r.id
    LEFT JOIN processed_notes p ON r.id = p.note_id
    WHERE tn.thread_id = ?
    ORDER BY r.created_at DESC
    LIMIT ?
  `);
  return stmt.all(threadId, limit) as RawNote[];
}

export function getTasksForThread(threadId: number): any[] {
  const stmt = db.prepare(`
    SELECT * FROM thread_tasks
    WHERE thread_id = ?
    ORDER BY created_at DESC
  `);
  return stmt.all(threadId);
}
```

**Step 2: Create threads route file**

Create `src/routes/threads.ts`:

```typescript
import { FastifyInstance } from 'fastify';
import { getActiveThreads, getThreadById, searchThreadByName, getThreadNotes, getTasksForThread } from '../lib/db';

export async function threadsRoutes(server: FastifyInstance) {
  // GET /api/threads?limit=10
  server.get<{ Querystring: { limit?: number } }>('/api/threads', async (request) => {
    const { limit = 10 } = request.query;
    const threads = getActiveThreads(limit);
    return { count: threads.length, threads };
  });

  // GET /api/threads/:id
  server.get<{ Params: { id: string } }>('/api/threads/:id', async (request, reply) => {
    const id = parseInt(request.params.id, 10);
    if (isNaN(id)) {
      reply.status(400);
      return { error: 'Invalid thread ID' };
    }
    const thread = getThreadById(id);
    if (!thread) {
      reply.status(404);
      return { error: 'Thread not found' };
    }
    // Include notes
    const notes = getThreadNotes(id);
    return { ...thread, notes };
  });

  // GET /api/threads/search/:name
  server.get<{ Params: { name: string } }>('/api/threads/search/:name', async (request, reply) => {
    const thread = searchThreadByName(request.params.name);
    if (!thread) {
      reply.status(404);
      return { error: 'Thread not found' };
    }
    const notes = getThreadNotes(thread.id);
    return { ...thread, notes };
  });

  // GET /api/threads/:id/tasks
  server.get<{ Params: { id: string } }>('/api/threads/:id/tasks', async (request, reply) => {
    const id = parseInt(request.params.id, 10);
    if (isNaN(id)) {
      reply.status(400);
      return { error: 'Invalid thread ID' };
    }
    const tasks = getTasksForThread(id);
    return { threadId: id, count: tasks.length, tasks };
  });
}
```

**Step 3: Register in server.ts**

```typescript
import { threadsRoutes } from './routes/threads';
await threadsRoutes(server);
```

**Step 4: Test**

```bash
curl -s http://localhost:5678/api/threads | jq '.count'
curl -s http://localhost:5678/api/threads/1 | jq '.name'
```

**Step 5: Commit**

```bash
git add src/routes/threads.ts src/lib/db.ts src/server.ts
git commit -m "feat(api): add threads REST endpoints"
```

---

### Task 4: Sessions API Endpoints

**Files:**
- Create: `src/routes/sessions.ts`
- Modify: `src/lib/db.ts`
- Modify: `src/server.ts`

**Step 1: Add session query functions to db.ts**

```typescript
export function loadSessions(): any[] {
  const stmt = db.prepare(`
    SELECT * FROM chat_sessions
    ORDER BY updated_at DESC
  `);
  return stmt.all();
}

export function saveSession(session: {
  id: string;
  messages_json: string;
  title: string;
  is_pinned: number;
  compression_state: string;
  compressed_at?: string;
  summary_text?: string;
  created_at: string;
  updated_at: string;
}): void {
  const stmt = db.prepare(`
    INSERT OR REPLACE INTO chat_sessions
    (id, messages_json, title, is_pinned, compression_state, compressed_at, summary_text, created_at, updated_at)
    VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?)
  `);
  stmt.run(
    session.id, session.messages_json, session.title,
    session.is_pinned, session.compression_state,
    session.compressed_at || null, session.summary_text || null,
    session.created_at, session.updated_at
  );
}

export function deleteSession(id: string): void {
  db.prepare('DELETE FROM chat_sessions WHERE id = ?').run(id);
  db.prepare('DELETE FROM conversations WHERE session_id = ?').run(id);
}

export function updateSessionPin(id: string, isPinned: boolean): void {
  db.prepare('UPDATE chat_sessions SET is_pinned = ? WHERE id = ?').run(isPinned ? 1 : 0, id);
}

export function getSessionMessages(sessionId: string, limit = 10): any[] {
  const stmt = db.prepare(`
    SELECT role, content, created_at
    FROM conversations
    WHERE session_id = ?
    ORDER BY created_at ASC
    LIMIT ?
  `);
  return stmt.all(sessionId, limit);
}

export function saveConversationMessage(sessionId: string, role: string, content: string): void {
  const stmt = db.prepare(`
    INSERT INTO conversations (session_id, role, content, created_at)
    VALUES (?, ?, ?, datetime('now'))
  `);
  stmt.run(sessionId, role, content);
}
```

**Step 2: Create sessions route file**

Create `src/routes/sessions.ts`:

```typescript
import { FastifyInstance } from 'fastify';
import { loadSessions, saveSession, deleteSession, updateSessionPin, getSessionMessages, saveConversationMessage } from '../lib/db';

export async function sessionsRoutes(server: FastifyInstance) {
  server.get('/api/sessions', async () => {
    const sessions = loadSessions();
    return { count: sessions.length, sessions };
  });

  server.put<{ Params: { id: string }; Body: any }>('/api/sessions/:id', async (request) => {
    const session = { ...request.body, id: request.params.id };
    saveSession(session);
    return { status: 'saved', id: request.params.id };
  });

  server.delete<{ Params: { id: string } }>('/api/sessions/:id', async (request) => {
    deleteSession(request.params.id);
    return { status: 'deleted', id: request.params.id };
  });

  server.patch<{ Params: { id: string }; Body: { isPinned: boolean } }>('/api/sessions/:id/pin', async (request) => {
    updateSessionPin(request.params.id, request.body.isPinned);
    return { status: 'updated', id: request.params.id, isPinned: request.body.isPinned };
  });

  server.get<{ Params: { id: string }; Querystring: { limit?: number } }>('/api/sessions/:id/messages', async (request) => {
    const { limit = 10 } = request.query;
    const messages = getSessionMessages(request.params.id, limit);
    return { sessionId: request.params.id, count: messages.length, messages };
  });

  server.post<{ Params: { id: string }; Body: { role: string; content: string } }>('/api/sessions/:id/messages', async (request) => {
    const { role, content } = request.body;
    saveConversationMessage(request.params.id, role, content);
    return { status: 'saved', sessionId: request.params.id };
  });
}
```

**Step 3: Register and test**

```bash
curl -s http://localhost:5678/api/sessions | jq '.count'
```

**Step 4: Commit**

```bash
git add src/routes/sessions.ts src/lib/db.ts src/server.ts
git commit -m "feat(api): add sessions REST endpoints"
```

---

### Task 5: Memories API Endpoints

**Files:**
- Create: `src/routes/memories.ts`
- Modify: `src/lib/db.ts`
- Modify: `src/server.ts`

**Step 1: Add memory query functions to db.ts**

```typescript
export function getAllMemories(limit = 50): any[] {
  const stmt = db.prepare(`
    SELECT * FROM conversation_memories
    ORDER BY confidence DESC, last_accessed_at DESC
    LIMIT ?
  `);
  return stmt.all(limit);
}

export function insertMemory(memory: {
  content: string;
  type: string;
  confidence: number;
  source_session_id?: string;
  embedding?: string; // JSON-encoded float array
}): number {
  const stmt = db.prepare(`
    INSERT INTO conversation_memories (content, type, confidence, source_session_id, embedding, created_at, last_accessed_at)
    VALUES (?, ?, ?, ?, ?, datetime('now'), datetime('now'))
  `);
  const result = stmt.run(memory.content, memory.type, memory.confidence, memory.source_session_id || null, memory.embedding || null);
  return result.lastInsertRowid as number;
}

export function updateMemory(id: number, updates: { content?: string; confidence?: number; embedding?: string }): void {
  const parts: string[] = [];
  const values: any[] = [];
  if (updates.content !== undefined) { parts.push('content = ?'); values.push(updates.content); }
  if (updates.confidence !== undefined) { parts.push('confidence = ?'); values.push(updates.confidence); }
  if (updates.embedding !== undefined) { parts.push('embedding = ?'); values.push(updates.embedding); }
  if (parts.length === 0) return;
  values.push(id);
  db.prepare(`UPDATE conversation_memories SET ${parts.join(', ')} WHERE id = ?`).run(...values);
}

export function deleteMemory(id: number): void {
  db.prepare('DELETE FROM conversation_memories WHERE id = ?').run(id);
}

export function touchMemories(ids: number[]): void {
  if (ids.length === 0) return;
  const placeholders = ids.map(() => '?').join(',');
  db.prepare(`UPDATE conversation_memories SET last_accessed_at = datetime('now') WHERE id IN (${placeholders})`).run(...ids);
}
```

**Step 2: Create memories route file**

Create `src/routes/memories.ts`:

```typescript
import { FastifyInstance } from 'fastify';
import { getAllMemories, insertMemory, updateMemory, deleteMemory, touchMemories } from '../lib/db';

export async function memoriesRoutes(server: FastifyInstance) {
  server.get<{ Querystring: { limit?: number } }>('/api/memories', async (request) => {
    const { limit = 50 } = request.query;
    const memories = getAllMemories(limit);
    return { count: memories.length, memories };
  });

  server.post<{ Body: { content: string; type: string; confidence: number; sourceSessionId?: string; embedding?: number[] } }>('/api/memories', async (request) => {
    const { content, type, confidence, sourceSessionId, embedding } = request.body;
    const id = insertMemory({
      content, type, confidence,
      source_session_id: sourceSessionId,
      embedding: embedding ? JSON.stringify(embedding) : undefined,
    });
    return { status: 'created', id };
  });

  server.put<{ Params: { id: string }; Body: { content?: string; confidence?: number; embedding?: number[] } }>('/api/memories/:id', async (request) => {
    const id = parseInt(request.params.id, 10);
    const { content, confidence, embedding } = request.body;
    updateMemory(id, {
      content,
      confidence,
      embedding: embedding ? JSON.stringify(embedding) : undefined,
    });
    return { status: 'updated', id };
  });

  server.delete<{ Params: { id: string } }>('/api/memories/:id', async (request) => {
    const id = parseInt(request.params.id, 10);
    deleteMemory(id);
    return { status: 'deleted', id };
  });

  server.post<{ Body: { ids: number[] } }>('/api/memories/touch', async (request) => {
    const { ids } = request.body;
    touchMemories(ids);
    return { status: 'touched', count: ids.length };
  });
}
```

**Step 3: Register, test, commit**

```bash
git add src/routes/memories.ts src/lib/db.ts src/server.ts
git commit -m "feat(api): add memories REST endpoints"
```

---

### Task 6: Briefing & LLM Proxy Endpoints

**Files:**
- Create: `src/routes/llm.ts`
- Create: `src/routes/briefing.ts`
- Modify: `src/lib/db.ts`
- Modify: `src/server.ts`

**Step 1: Add briefing query to db.ts**

```typescript
export function getCrossThreadAssociations(minSimilarity = 0.7, recentDays = 7, limit = 10): any[] {
  const stmt = db.prepare(`
    SELECT na.note_a_id as noteAId, na.note_b_id as noteBId, na.similarity
    FROM note_associations na
    JOIN raw_notes ra ON na.note_a_id = ra.id
    JOIN raw_notes rb ON na.note_b_id = rb.id
    JOIN thread_notes tna ON na.note_a_id = tna.note_id
    JOIN thread_notes tnb ON na.note_b_id = tnb.note_id
    WHERE na.similarity >= ?
      AND ra.created_at >= datetime('now', '-' || ? || ' days')
      AND tna.thread_id != tnb.thread_id
    ORDER BY na.similarity DESC
    LIMIT ?
  `);
  return stmt.all(minSimilarity, recentDays, limit);
}
```

**Step 2: Create LLM proxy route**

Create `src/routes/llm.ts`:

```typescript
import { FastifyInstance } from 'fastify';
import { generate, embed, isAvailable } from '../lib/ollama';

export async function llmRoutes(server: FastifyInstance) {
  server.get('/api/llm/health', async () => {
    const available = await isAvailable();
    return { available };
  });

  server.post<{ Body: { prompt: string; model?: string; temperature?: number } }>('/api/llm/generate', async (request, reply) => {
    const { prompt, model, temperature } = request.body;
    if (!prompt) {
      reply.status(400);
      return { error: 'prompt is required' };
    }
    try {
      const response = await generate(prompt, { model, temperature });
      return { response };
    } catch (err) {
      const error = err as Error;
      reply.status(502);
      return { error: 'LLM generation failed', message: error.message };
    }
  });

  server.post<{ Body: { text: string; model?: string } }>('/api/llm/embed', async (request, reply) => {
    const { text, model } = request.body;
    if (!text) {
      reply.status(400);
      return { error: 'text is required' };
    }
    try {
      const embedding = await embed(text, model);
      return { embedding };
    } catch (err) {
      const error = err as Error;
      reply.status(502);
      return { error: 'Embedding failed', message: error.message };
    }
  });
}
```

**Step 3: Create briefing route**

Create `src/routes/briefing.ts`:

```typescript
import { FastifyInstance } from 'fastify';
import { getCrossThreadAssociations } from '../lib/db';

export async function briefingRoutes(server: FastifyInstance) {
  server.get<{
    Querystring: { minSimilarity?: number; recentDays?: number; limit?: number };
  }>('/api/briefing/associations', async (request) => {
    const { minSimilarity = 0.7, recentDays = 7, limit = 10 } = request.query;
    const associations = getCrossThreadAssociations(minSimilarity, recentDays, limit);
    return { count: associations.length, associations };
  });
}
```

**Step 4: Register all routes, test LLM proxy**

```bash
# Test LLM health
curl -s http://localhost:5678/api/llm/health | jq .

# Test generation
curl -s http://localhost:5678/api/llm/generate -X POST -H "Content-Type: application/json" -d '{"prompt":"Say hello in one word"}' | jq .response

# Test embedding
curl -s http://localhost:5678/api/llm/embed -X POST -H "Content-Type: application/json" -d '{"text":"test embedding"}' | jq '.embedding | length'
```

**Step 5: Commit**

```bash
git add src/routes/llm.ts src/routes/briefing.ts src/lib/db.ts src/server.ts
git commit -m "feat(api): add LLM proxy and briefing endpoints"
```

---

### Task 7: Device Registration Endpoint + Table

**Files:**
- Create: `src/routes/devices.ts`
- Modify: `src/lib/db.ts`
- Modify: `src/server.ts`

**Step 1: Create device_tokens table (migration in db.ts)**

Add to the db.ts initialization:

```typescript
db.exec(`
  CREATE TABLE IF NOT EXISTS device_tokens (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    token TEXT NOT NULL UNIQUE,
    platform TEXT NOT NULL DEFAULT 'ios',
    created_at TEXT NOT NULL DEFAULT (datetime('now')),
    last_seen_at TEXT NOT NULL DEFAULT (datetime('now'))
  );
`);

export function registerDevice(token: string, platform = 'ios'): void {
  const stmt = db.prepare(`
    INSERT INTO device_tokens (token, platform, created_at, last_seen_at)
    VALUES (?, ?, datetime('now'), datetime('now'))
    ON CONFLICT(token) DO UPDATE SET last_seen_at = datetime('now')
  `);
  stmt.run(token, platform);
}

export function unregisterDevice(token: string): void {
  db.prepare('DELETE FROM device_tokens WHERE token = ?').run(token);
}

export function getDeviceTokens(platform?: string): string[] {
  if (platform) {
    return db.prepare('SELECT token FROM device_tokens WHERE platform = ?').all(platform).map((r: any) => r.token);
  }
  return db.prepare('SELECT token FROM device_tokens').all().map((r: any) => r.token);
}
```

**Step 2: Create devices route**

Create `src/routes/devices.ts`:

```typescript
import { FastifyInstance } from 'fastify';
import { registerDevice, unregisterDevice } from '../lib/db';

export async function devicesRoutes(server: FastifyInstance) {
  server.post<{ Body: { token: string; platform?: string } }>('/api/devices/register', async (request) => {
    const { token, platform = 'ios' } = request.body;
    registerDevice(token, platform);
    return { status: 'registered' };
  });

  server.post<{ Body: { token: string } }>('/api/devices/unregister', async (request) => {
    const { token } = request.body;
    unregisterDevice(token);
    return { status: 'unregistered' };
  });
}
```

**Step 3: Register, test, commit**

```bash
git add src/routes/devices.ts src/lib/db.ts src/server.ts
git commit -m "feat(api): add device token registration for push notifications"
```

---

### Task 8: Refactor server.ts to use route modules

**Files:**
- Modify: `src/server.ts`

**Step 1: Clean up server.ts**

Move the existing `/api/search` and `/api/related-notes` endpoints into the notes route module (they're already covered by the new routes). Update server.ts to only register route modules:

```typescript
import Fastify from 'fastify';
import { config, logger } from './lib';
import { ingest } from './workflows/ingest';
import { exportObsidian } from './workflows/export-obsidian';
import { requireAuth } from './lib/auth';
import { notesRoutes } from './routes/notes';
import { threadsRoutes } from './routes/threads';
import { sessionsRoutes } from './routes/sessions';
import { memoriesRoutes } from './routes/memories';
import { llmRoutes } from './routes/llm';
import { briefingRoutes } from './routes/briefing';
import { devicesRoutes } from './routes/devices';

const server = Fastify({ logger: false });

// Auth middleware for /api/* routes
server.addHook('onRequest', async (request, reply) => {
  if (request.url.startsWith('/api/')) {
    await requireAuth(request, reply);
  }
});

// Health check (no auth)
server.get('/health', async () => {
  return { status: 'ok', timestamp: new Date().toISOString() };
});

// Webhook endpoints (no auth - local only)
server.post<{ Body: any }>('/webhook/api/drafts', async (request, reply) => {
  // ... existing code unchanged ...
});

server.post<{ Body: { noteId?: number } }>('/webhook/api/export-obsidian', async (request, reply) => {
  // ... existing code unchanged ...
});

// Register API route modules
notesRoutes(server);
threadsRoutes(server);
sessionsRoutes(server);
memoriesRoutes(server);
llmRoutes(server);
briefingRoutes(server);
devicesRoutes(server);

async function start() {
  try {
    await server.listen({ port: config.port, host: config.host });
    logger.info({ port: config.port, host: config.host }, 'Selene webhook server started');
  } catch (err) {
    logger.error({ err }, 'Server failed to start');
    process.exit(1);
  }
}

start();
```

Keep the original `/api/search` and `/api/related-notes` for backward compatibility with the macOS app (which calls these), or update the macOS `SeleneAPIService.swift` later.

**Step 2: Verify existing endpoints still work**

```bash
# Restart server
launchctl kickstart -k gui/$(id -u)/com.selene.server

# Test original endpoints
curl -s http://localhost:5678/health | jq .
curl -s http://localhost:5678/api/search -X POST -H "Content-Type: application/json" -d '{"query":"test"}' | jq .count

# Test new endpoints
curl -s http://localhost:5678/api/notes?limit=3 | jq .count
curl -s http://localhost:5678/api/threads | jq .count
curl -s http://localhost:5678/api/llm/health | jq .
```

**Step 3: Commit**

```bash
git add src/server.ts
git commit -m "refactor(server): organize routes into modules"
```

---

## Phase 2: Swift Package Refactor

Extract shared code into a library target. Keep macOS working identically.

### Task 9: Create SeleneShared Target Structure

**Files:**
- Modify: `SeleneChat/Package.swift`
- Create: `SeleneChat/Sources/SeleneShared/` directory structure

**Step 1: Create directory structure**

```bash
cd SeleneChat
mkdir -p Sources/SeleneShared/Models
mkdir -p Sources/SeleneShared/Services
mkdir -p Sources/SeleneShared/Services/Migrations
mkdir -p Sources/SeleneShared/Protocols
mkdir -p Sources/SeleneShared/ViewModels
mkdir -p Sources/SeleneShared/Utilities
mkdir -p Sources/SeleneShared/Debug
```

**Step 2: Update Package.swift**

```swift
// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "SeleneChat",
    platforms: [
        .macOS(.v14),
        .iOS(.v17)
    ],
    products: [
        .executable(
            name: "SeleneChat",
            targets: ["SeleneChat"]
        ),
        .library(
            name: "SeleneShared",
            targets: ["SeleneShared"]
        )
    ],
    dependencies: [
        .package(url: "https://github.com/stephencelis/SQLite.swift.git", from: "0.15.0")
    ],
    targets: [
        .target(
            name: "SeleneShared",
            path: "Sources/SeleneShared"
        ),
        .executableTarget(
            name: "SeleneChat",
            dependencies: [
                "SeleneShared",
                .product(name: "SQLite", package: "SQLite.swift")
            ],
            path: "Sources/SeleneChat",
            resources: [
                .process("Resources")
            ]
        ),
        .testTarget(
            name: "SeleneChatTests",
            dependencies: ["SeleneChat", "SeleneShared"],
            path: "Tests"
        )
    ]
)
```

**Step 3: Create a placeholder file so the target compiles**

Create `SeleneChat/Sources/SeleneShared/SeleneShared.swift`:

```swift
// SeleneShared - Cross-platform library for SeleneChat
// Contains models, protocols, services, and view models shared between macOS and iOS.
import Foundation
```

**Step 4: Verify it builds**

```bash
cd SeleneChat && swift build
```

**Step 5: Commit**

```bash
git add SeleneChat/Package.swift SeleneChat/Sources/SeleneShared/
git commit -m "feat: create SeleneShared library target for cross-platform code"
```

---

### Task 10: Define DataProvider and LLMProvider Protocols

**Files:**
- Create: `SeleneChat/Sources/SeleneShared/Protocols/DataProvider.swift`
- Create: `SeleneChat/Sources/SeleneShared/Protocols/LLMProvider.swift`

**Step 1: Create DataProvider protocol**

Create `SeleneChat/Sources/SeleneShared/Protocols/DataProvider.swift`:

```swift
import Foundation

/// Protocol abstracting data access for SeleneChat.
/// Implemented by DatabaseService (macOS, direct SQLite) and RemoteDataService (iOS, HTTP).
public protocol DataProvider: AnyObject, Sendable {
    // MARK: - Notes
    func getAllNotes(limit: Int) async throws -> [Note]
    func getNote(byId noteId: Int) async throws -> Note?
    func searchNotes(query: String, limit: Int) async throws -> [Note]
    func searchNotesSemantically(query: String, limit: Int) async -> [Note]
    func getRecentNotes(days: Int, limit: Int) async throws -> [Note]
    func getNotesSince(_ date: Date, limit: Int) async throws -> [Note]
    func getRelatedNotes(for noteId: Int, limit: Int) async -> [(note: Note, relationshipType: String, strength: Double?)]
    func getThreadAssignmentsForNotes(_ noteIds: [Int]) async throws -> [Int: (threadName: String, threadId: Int64)]

    // MARK: - Threads
    func getActiveThreads(limit: Int) async throws -> [Thread]
    func getThreadById(_ threadId: Int64) async throws -> Thread?
    func getThreadByName(_ name: String) async throws -> (Thread, [Note])?
    func getTasksForThread(_ threadId: Int64) async throws -> [ThreadTask]

    // MARK: - Sessions
    func loadSessions() async throws -> [ChatSession]
    func saveSession(_ session: ChatSession) async throws
    func deleteSession(_ session: ChatSession) async throws
    func updateSessionPin(sessionId: UUID, isPinned: Bool) async throws
    func saveConversationMessage(sessionId: UUID, role: String, content: String) async throws
    func getRecentMessages(sessionId: UUID, limit: Int) async throws -> [(role: String, content: String, createdAt: Date)]
    func getAllRecentMessages(limit: Int) async throws -> [(sessionId: String, role: String, content: String, createdAt: Date)]

    // MARK: - Memories
    func getAllMemories(limit: Int) async throws -> [ConversationMemory]
    func insertMemory(content: String, type: ConversationMemory.MemoryType, confidence: Double, sourceSessionId: UUID?, embedding: [Float]?) async throws -> Int64
    func updateMemory(id: Int64, content: String, confidence: Double?, embedding: [Float]?) async throws
    func deleteMemory(id: Int64) async throws
    func touchMemories(ids: [Int64]) async throws
    func getAllMemoriesWithEmbeddings(limit: Int) async throws -> [(memory: ConversationMemory, embedding: [Float]?)]
    func saveMemoryEmbedding(id: Int64, embedding: [Float]) async throws

    // MARK: - Briefing Context
    func getCrossThreadAssociations(minSimilarity: Double, recentDays: Int, limit: Int) async throws -> [(noteAId: Int, noteBId: Int, similarity: Double)]

    // MARK: - API Availability
    func isAPIAvailable() async -> Bool
}

/// Default parameter values (protocols can't have defaults)
public extension DataProvider {
    func getAllNotes() async throws -> [Note] { try await getAllNotes(limit: 100) }
    func searchNotes(query: String) async throws -> [Note] { try await searchNotes(query: query, limit: 50) }
    func getRecentNotes(days: Int) async throws -> [Note] { try await getRecentNotes(days: days, limit: 10) }
    func getActiveThreads() async throws -> [Thread] { try await getActiveThreads(limit: 10) }
    func getAllMemories() async throws -> [ConversationMemory] { try await getAllMemories(limit: 50) }
}
```

**Step 2: Create LLMProvider protocol**

Create `SeleneChat/Sources/SeleneShared/Protocols/LLMProvider.swift`:

```swift
import Foundation

/// Protocol abstracting LLM access for SeleneChat.
/// Implemented by OllamaService (macOS, localhost) and RemoteOllamaService (iOS, via Fastify proxy).
public protocol LLMProvider: AnyObject, Sendable {
    func generate(prompt: String, model: String?) async throws -> String
    func embed(text: String, model: String?) async throws -> [Float]
    func isAvailable() async -> Bool
}

public extension LLMProvider {
    func generate(prompt: String) async throws -> String {
        try await generate(prompt: prompt, model: nil)
    }
    func embed(text: String) async throws -> [Float] {
        try await embed(text: text, model: nil)
    }
}
```

**Step 3: Verify build**

```bash
cd SeleneChat && swift build
```

**Step 4: Commit**

```bash
git add SeleneChat/Sources/SeleneShared/Protocols/
git commit -m "feat: define DataProvider and LLMProvider protocols"
```

---

### Task 11: Move Models to SeleneShared

**Files:**
- Move: All 24 files from `Sources/Models/` → `Sources/SeleneShared/Models/`
- Create: Re-export stubs in `Sources/SeleneChat/Models/` if needed

This is the largest file move. All model files are pure Foundation — no platform dependencies.

**Step 1: Move model files**

```bash
cd SeleneChat
# Move all model files to shared target
mv Sources/Models/*.swift Sources/SeleneShared/Models/

# Create the SeleneChat-specific Sources directory
mkdir -p Sources/SeleneChat/Models
mkdir -p Sources/SeleneChat/App
mkdir -p Sources/SeleneChat/Services
mkdir -p Sources/SeleneChat/Services/Migrations
mkdir -p Sources/SeleneChat/Views
mkdir -p Sources/SeleneChat/Views/Planning
mkdir -p Sources/SeleneChat/ViewModels
mkdir -p Sources/SeleneChat/Utilities
mkdir -p Sources/SeleneChat/Debug
```

**Step 2: Move remaining SeleneChat source files into the new path**

Since we changed `path` from `"Sources"` to `"Sources/SeleneChat"`, move everything else:

```bash
# Move App files
mv Sources/App/*.swift Sources/SeleneChat/App/

# Move Services
mv Sources/Services/*.swift Sources/SeleneChat/Services/
mv Sources/Services/Migrations/*.swift Sources/SeleneChat/Services/Migrations/

# Move Views
mv Sources/Views/*.swift Sources/SeleneChat/Views/
mv Sources/Views/Planning/*.swift Sources/SeleneChat/Views/Planning/

# Move ViewModels
mv Sources/ViewModels/*.swift Sources/SeleneChat/ViewModels/

# Move Utilities
mv Sources/Utilities/*.swift Sources/SeleneChat/Utilities/

# Move Debug
mv Sources/Debug/*.swift Sources/SeleneChat/Debug/

# Move Resources
mv Sources/Resources Sources/SeleneChat/Resources

# Clean up old directories
rmdir Sources/App Sources/Models Sources/Services/Migrations Sources/Services Sources/Views/Planning Sources/Views Sources/ViewModels Sources/Utilities Sources/Debug 2>/dev/null || true
```

**Step 3: Add access modifiers to shared models**

All types in SeleneShared need `public` access. For each model file in `Sources/SeleneShared/Models/`, change `struct`/`enum`/`class` to `public struct`/`public enum`/`public class`, and key properties/methods to `public`. This is tedious but necessary — the compiler will tell you what's missing.

**Step 4: Add `import SeleneShared` to SeleneChat files that use models**

Any file in `Sources/SeleneChat/` that references `Note`, `Message`, `ChatSession`, `Thread`, etc. needs:

```swift
import SeleneShared
```

**Step 5: Build and fix errors iteratively**

```bash
cd SeleneChat && swift build 2>&1 | head -50
```

Fix access modifiers and imports until it builds clean. This will take multiple iterations.

**Step 6: Run tests**

```bash
cd SeleneChat && swift test
```

**Step 7: Commit**

```bash
git add SeleneChat/Sources/ SeleneChat/Tests/
git commit -m "refactor: move models to SeleneShared library target"
```

---

### Task 12: Move Pure-Logic Services to SeleneShared

**Files:**
- Move to `Sources/SeleneShared/Services/`: QueryAnalyzer, ContextBuilder, all PromptBuilders, ActionExtractor, ActionService, CompressionService, SearchService, PrivacyRouter, MemoryService, BriefingContextBuilder, BriefingDataService, AIProviderService, ClaudeAPIService, ResurfaceTriggerService, SubprojectSuggestionService, CitationParser, VectorUtility
- Move to `Sources/SeleneShared/ViewModels/`: BriefingViewModel, ThreadWorkspaceChatViewModel
- Keep in `Sources/SeleneChat/Services/`: DatabaseService, OllamaService, SeleneAPIService, ThingsURLService, ThingsStatusService, VoiceInputManager, ObsidianService, WorkflowScheduler, WorkflowRunner, SpeechRecognitionService, SpeechSynthesisService, InboxService, ProjectService, TodayService, TodayViewModel

**Step 1: Move shareable service files**

```bash
cd SeleneChat

# Pure logic services → SeleneShared
mv Sources/SeleneChat/Services/QueryAnalyzer.swift Sources/SeleneShared/Services/
mv Sources/SeleneChat/Services/ContextBuilder.swift Sources/SeleneShared/Services/
mv Sources/SeleneChat/Services/DeepDivePromptBuilder.swift Sources/SeleneShared/Services/
mv Sources/SeleneChat/Services/SynthesisPromptBuilder.swift Sources/SeleneShared/Services/
mv Sources/SeleneChat/Services/ThinkingPartnerContextBuilder.swift Sources/SeleneShared/Services/
mv Sources/SeleneChat/Services/ThreadWorkspacePromptBuilder.swift Sources/SeleneShared/Services/
mv Sources/SeleneChat/Services/BriefingContextBuilder.swift Sources/SeleneShared/Services/
mv Sources/SeleneChat/Services/ActionExtractor.swift Sources/SeleneShared/Services/
mv Sources/SeleneChat/Services/ActionService.swift Sources/SeleneShared/Services/
mv Sources/SeleneChat/Services/CompressionService.swift Sources/SeleneShared/Services/
mv Sources/SeleneChat/Services/SearchService.swift Sources/SeleneShared/Services/
mv Sources/SeleneChat/Services/PrivacyRouter.swift Sources/SeleneShared/Services/
mv Sources/SeleneChat/Services/MemoryService.swift Sources/SeleneShared/Services/
mv Sources/SeleneChat/Services/AIProviderService.swift Sources/SeleneShared/Services/
mv Sources/SeleneChat/Services/ClaudeAPIService.swift Sources/SeleneShared/Services/
mv Sources/SeleneChat/Services/ResurfaceTriggerService.swift Sources/SeleneShared/Services/
mv Sources/SeleneChat/Services/SubprojectSuggestionService.swift Sources/SeleneShared/Services/

# ViewModels → SeleneShared
mv Sources/SeleneChat/ViewModels/BriefingViewModel.swift Sources/SeleneShared/ViewModels/
mv Sources/SeleneChat/ViewModels/ThreadWorkspaceChatViewModel.swift Sources/SeleneShared/ViewModels/

# Utilities → SeleneShared
mv Sources/SeleneChat/Utilities/CitationParser.swift Sources/SeleneShared/Utilities/
mv Sources/SeleneChat/Utilities/VectorUtility.swift Sources/SeleneShared/Utilities/

# Debug → SeleneShared
mv Sources/SeleneChat/Debug/*.swift Sources/SeleneShared/Debug/
```

**Step 2: Add public access modifiers and `import SeleneShared`**

Same pattern as Task 11 — add `public` to moved types, add `import SeleneShared` to SeleneChat files.

**Step 3: Build and fix**

```bash
cd SeleneChat && swift build 2>&1 | head -80
```

Services that reference `DatabaseService.shared` directly will need to be refactored to use `DataProvider` protocol instead. This is handled in Task 13.

**Step 4: Run tests**

```bash
cd SeleneChat && swift test
```

**Step 5: Commit**

```bash
git add SeleneChat/Sources/
git commit -m "refactor: move pure-logic services to SeleneShared"
```

---

### Task 13: Move ChatViewModel to SeleneShared + Protocol Dependencies

This is the critical refactor. ChatViewModel currently calls `DatabaseService.shared` and `OllamaService.shared` directly. It needs to use `DataProvider` and `LLMProvider` protocols instead.

**Files:**
- Move: `Sources/SeleneChat/Services/ChatViewModel.swift` → `Sources/SeleneShared/Services/`
- Modify: ChatViewModel to accept protocols via initializer

**Step 1: Refactor ChatViewModel to use protocols**

Change ChatViewModel's direct service references to protocol-based injection:

```swift
// Before:
// let db = DatabaseService.shared
// let ollama = OllamaService.shared

// After:
@MainActor
public class ChatViewModel: ObservableObject {
    public let dataProvider: DataProvider
    public let llmProvider: LLMProvider

    public init(dataProvider: DataProvider, llmProvider: LLMProvider) {
        self.dataProvider = dataProvider
        self.llmProvider = llmProvider
        // ... existing init code ...
    }

    // Replace all DatabaseService.shared calls with dataProvider
    // Replace all OllamaService.shared calls with llmProvider
}
```

Find-and-replace pattern:
- `DatabaseService.shared.getAllNotes` → `dataProvider.getAllNotes`
- `DatabaseService.shared.searchNotes` → `dataProvider.searchNotes`
- `DatabaseService.shared.getActiveThreads` → `dataProvider.getActiveThreads`
- `await OllamaService.shared.generate` → `try await llmProvider.generate`
- `await OllamaService.shared.embed` → `try await llmProvider.embed`
- `await OllamaService.shared.isAvailable()` → `await llmProvider.isAvailable()`

**Step 2: Do the same for any other shared service that directly references DatabaseService or OllamaService**

Check: MemoryService, BriefingDataService, CompressionService, BriefingViewModel, ThreadWorkspaceChatViewModel. Each needs to accept providers via init or have them injected.

**Step 3: Update SeleneChatApp.swift to inject concrete implementations**

```swift
// In SeleneChatApp.swift:
@StateObject private var chatViewModel = ChatViewModel(
    dataProvider: DatabaseService.shared,
    llmProvider: OllamaService.shared
)
```

**Step 4: Make DatabaseService conform to DataProvider**

In `Sources/SeleneChat/Services/DatabaseService.swift`, add:

```swift
extension DatabaseService: DataProvider {
    // Most methods already match the protocol signatures.
    // Add any missing conformance methods.
}
```

**Step 5: Make OllamaService conform to LLMProvider**

In `Sources/SeleneChat/Services/OllamaService.swift`, add:

```swift
extension OllamaService: LLMProvider {
    // generate() and embed() signatures should already match.
    // Adjust parameter names if needed.
}
```

**Step 6: Build and fix all compilation errors**

```bash
cd SeleneChat && swift build 2>&1 | head -80
```

This will be the most iterative step. Expect 20-50 compilation errors to fix.

**Step 7: Run full test suite**

```bash
cd SeleneChat && swift test
```

All 270+ existing tests must pass. The macOS app should work identically.

**Step 8: Commit**

```bash
git add SeleneChat/Sources/
git commit -m "refactor: ChatViewModel uses DataProvider/LLMProvider protocols

Enables cross-platform code sharing. macOS still uses DatabaseService +
OllamaService directly. iOS will use RemoteDataService + RemoteOllamaService."
```

---

## Phase 3: iOS App

### Task 14: Create SeleneMobile Target

**Files:**
- Modify: `SeleneChat/Package.swift`
- Create: `SeleneChat/Sources/SeleneMobile/App/SeleneMobileApp.swift`

**Step 1: Add iOS target to Package.swift**

Add to products:
```swift
.executable(name: "SeleneMobile", targets: ["SeleneMobile"]),
```

Add to targets:
```swift
.executableTarget(
    name: "SeleneMobile",
    dependencies: ["SeleneShared"],
    path: "Sources/SeleneMobile"
),
```

**Step 2: Create minimal iOS app entry point**

Create directory: `Sources/SeleneMobile/App/`

Create `Sources/SeleneMobile/App/SeleneMobileApp.swift`:

```swift
import SwiftUI
import SeleneShared

@main
struct SeleneMobileApp: App {
    @StateObject private var connectionManager = ConnectionManager()

    var body: some Scene {
        WindowGroup {
            if connectionManager.isConfigured {
                TabRootView()
                    .environmentObject(connectionManager)
            } else {
                ServerSetupView()
                    .environmentObject(connectionManager)
            }
        }
    }
}
```

**Step 3: Create ConnectionManager**

Create `Sources/SeleneMobile/Services/ConnectionManager.swift`:

```swift
import Foundation
import SeleneShared
import SwiftUI

@MainActor
class ConnectionManager: ObservableObject {
    @Published var serverURL: String = ""
    @Published var apiToken: String = ""
    @Published var isConnected = false
    @Published var isConfigured = false

    private(set) var dataProvider: (any DataProvider)?
    private(set) var llmProvider: (any LLMProvider)?

    init() {
        loadFromKeychain()
    }

    func configure(serverURL: String, apiToken: String) async -> Bool {
        self.serverURL = serverURL
        self.apiToken = apiToken

        let remote = RemoteDataService(baseURL: serverURL, token: apiToken)
        let remoteLLM = RemoteOllamaService(baseURL: serverURL, token: apiToken)

        // Test connection
        let available = await remote.isAPIAvailable()
        if available {
            self.dataProvider = remote
            self.llmProvider = remoteLLM
            self.isConnected = true
            self.isConfigured = true
            saveToKeychain()
            return true
        }
        return false
    }

    private func loadFromKeychain() {
        // Load from UserDefaults for now (Keychain integration later)
        if let url = UserDefaults.standard.string(forKey: "selene_server_url"),
           let token = UserDefaults.standard.string(forKey: "selene_api_token"),
           !url.isEmpty {
            self.serverURL = url
            self.apiToken = token
            self.isConfigured = true
            Task {
                _ = await configure(serverURL: url, apiToken: token)
            }
        }
    }

    private func saveToKeychain() {
        UserDefaults.standard.set(serverURL, forKey: "selene_server_url")
        UserDefaults.standard.set(apiToken, forKey: "selene_api_token")
    }
}
```

**Step 4: Create placeholder views**

Create `Sources/SeleneMobile/Views/TabRootView.swift`:

```swift
import SwiftUI
import SeleneShared

struct TabRootView: View {
    @EnvironmentObject var connectionManager: ConnectionManager

    var body: some View {
        TabView {
            Text("Chat")
                .tabItem { Label("Chat", systemImage: "message") }
            Text("Threads")
                .tabItem { Label("Threads", systemImage: "circle.hexagongrid") }
            Text("Briefing")
                .tabItem { Label("Briefing", systemImage: "sun.max") }
            Text("More")
                .tabItem { Label("More", systemImage: "ellipsis") }
        }
    }
}
```

Create `Sources/SeleneMobile/Views/ServerSetupView.swift`:

```swift
import SwiftUI

struct ServerSetupView: View {
    @EnvironmentObject var connectionManager: ConnectionManager
    @State private var serverURL = ""
    @State private var apiToken = ""
    @State private var isConnecting = false
    @State private var errorMessage: String?

    var body: some View {
        NavigationStack {
            Form {
                Section("Server Connection") {
                    TextField("Tailscale IP:Port", text: $serverURL)
                        .textContentType(.URL)
                        .autocapitalization(.none)
                        .keyboardType(.URL)
                    SecureField("API Token", text: $apiToken)
                }

                if let error = errorMessage {
                    Section {
                        Text(error)
                            .foregroundStyle(.red)
                    }
                }

                Section {
                    Button(action: connect) {
                        if isConnecting {
                            ProgressView()
                        } else {
                            Text("Connect")
                        }
                    }
                    .disabled(serverURL.isEmpty || isConnecting)
                }
            }
            .navigationTitle("Selene Setup")
        }
    }

    private func connect() {
        isConnecting = true
        errorMessage = nil

        var url = serverURL
        if !url.hasPrefix("http") {
            url = "http://\(url)"
        }

        Task {
            let success = await connectionManager.configure(serverURL: url, apiToken: apiToken)
            isConnecting = false
            if !success {
                errorMessage = "Could not connect to server. Check the URL and make sure Tailscale is active."
            }
        }
    }
}
```

**Step 5: Build for iOS simulator**

```bash
cd SeleneChat && swift build --triple arm64-apple-ios17.0-simulator
```

Note: This may need Xcode and an actual iOS build. If SPM CLI doesn't support iOS targets directly, use:

```bash
cd SeleneChat && xcodebuild -scheme SeleneMobile -destination 'platform=iOS Simulator,name=iPhone 16' build
```

**Step 6: Commit**

```bash
git add SeleneChat/
git commit -m "feat: create SeleneMobile iOS target with setup flow"
```

---

### Task 15: Implement RemoteDataService

**Files:**
- Create: `SeleneChat/Sources/SeleneMobile/Services/RemoteDataService.swift`

**Step 1: Create RemoteDataService**

This is the HTTP client that implements `DataProvider` by calling the Fastify REST API.

```swift
import Foundation
import SeleneShared

actor RemoteDataService: DataProvider {
    let baseURL: String
    let token: String
    private let session: URLSession
    private let decoder: JSONDecoder

    init(baseURL: String, token: String) {
        self.baseURL = baseURL
        self.token = token
        let config = URLSessionConfiguration.default
        config.timeoutIntervalForRequest = 30
        self.session = URLSession(configuration: config)

        self.decoder = JSONDecoder()
        self.decoder.dateDecodingStrategy = .iso8601
    }

    // MARK: - HTTP Helpers

    private func request(_ method: String, path: String, body: Data? = nil) async throws -> Data {
        guard let url = URL(string: "\(baseURL)\(path)") else {
            throw RemoteServiceError.invalidURL(path)
        }
        var req = URLRequest(url: url)
        req.httpMethod = method
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        if !token.isEmpty {
            req.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        }
        req.httpBody = body
        let (data, response) = try await session.data(for: req)
        guard let http = response as? HTTPURLResponse else {
            throw RemoteServiceError.invalidResponse
        }
        guard (200...299).contains(http.statusCode) else {
            throw RemoteServiceError.httpError(http.statusCode)
        }
        return data
    }

    private func get(_ path: String) async throws -> Data {
        try await request("GET", path: path)
    }

    private func post(_ path: String, body: Encodable) async throws -> Data {
        let data = try JSONEncoder().encode(body)
        return try await request("POST", path: path, body: data)
    }

    // MARK: - DataProvider Implementation

    func getAllNotes(limit: Int) async throws -> [Note] {
        let data = try await get("/api/notes?limit=\(limit)")
        let response = try decoder.decode(NotesListResponse.self, from: data)
        return response.notes
    }

    func getNote(byId noteId: Int) async throws -> Note? {
        do {
            let data = try await get("/api/notes/\(noteId)")
            return try decoder.decode(Note.self, from: data)
        } catch RemoteServiceError.httpError(404) {
            return nil
        }
    }

    func searchNotes(query: String, limit: Int) async throws -> [Note] {
        struct SearchBody: Encodable { let query: String; let limit: Int }
        let data = try await post("/api/notes/search", body: SearchBody(query: query, limit: limit))
        let response = try decoder.decode(NotesListResponse.self, from: data)
        return response.notes
    }

    func searchNotesSemantically(query: String, limit: Int) async -> [Note] {
        do {
            struct Body: Encodable { let query: String; let limit: Int }
            let data = try await post("/api/notes/retrieve", body: Body(query: query, limit: limit))
            let response = try decoder.decode(NotesListResponse.self, from: data)
            return response.notes
        } catch {
            return []
        }
    }

    func getRecentNotes(days: Int, limit: Int) async throws -> [Note] {
        let data = try await get("/api/notes/recent?days=\(days)&limit=\(limit)")
        let response = try decoder.decode(NotesListResponse.self, from: data)
        return response.notes
    }

    func getNotesSince(_ date: Date, limit: Int) async throws -> [Note] {
        let formatter = ISO8601DateFormatter()
        let dateStr = formatter.string(from: date)
        let data = try await get("/api/notes/since/\(dateStr)?limit=\(limit)")
        let response = try decoder.decode(NotesListResponse.self, from: data)
        return response.notes
    }

    func getRelatedNotes(for noteId: Int, limit: Int) async -> [(note: Note, relationshipType: String, strength: Double?)] {
        do {
            let data = try await get("/api/notes/\(noteId)/related?limit=\(limit)")
            let response = try decoder.decode(RelatedNotesAPIResponse.self, from: data)
            return response.results.map { ($0.note, $0.relationshipType, $0.strength) }
        } catch {
            return []
        }
    }

    func getThreadAssignmentsForNotes(_ noteIds: [Int]) async throws -> [Int: (threadName: String, threadId: Int64)] {
        struct Body: Encodable { let noteIds: [Int] }
        let data = try await post("/api/notes/thread-assignments", body: Body(noteIds: noteIds))
        let response = try decoder.decode(ThreadAssignmentsResponse.self, from: data)
        var result: [Int: (threadName: String, threadId: Int64)] = [:]
        for assignment in response.assignments {
            result[assignment.noteId] = (assignment.threadName, Int64(assignment.threadId))
        }
        return result
    }

    // MARK: - Threads

    func getActiveThreads(limit: Int) async throws -> [Thread] {
        let data = try await get("/api/threads?limit=\(limit)")
        let response = try decoder.decode(ThreadsListResponse.self, from: data)
        return response.threads
    }

    func getThreadById(_ threadId: Int64) async throws -> Thread? {
        do {
            let data = try await get("/api/threads/\(threadId)")
            return try decoder.decode(Thread.self, from: data)
        } catch RemoteServiceError.httpError(404) {
            return nil
        }
    }

    func getThreadByName(_ name: String) async throws -> (Thread, [Note])? {
        do {
            let encoded = name.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed) ?? name
            let data = try await get("/api/threads/search/\(encoded)")
            let response = try decoder.decode(ThreadWithNotesResponse.self, from: data)
            return (response.thread, response.notes)
        } catch RemoteServiceError.httpError(404) {
            return nil
        }
    }

    func getTasksForThread(_ threadId: Int64) async throws -> [ThreadTask] {
        let data = try await get("/api/threads/\(threadId)/tasks")
        let response = try decoder.decode(ThreadTasksResponse.self, from: data)
        return response.tasks
    }

    // MARK: - Sessions

    func loadSessions() async throws -> [ChatSession] {
        let data = try await get("/api/sessions")
        let response = try decoder.decode(SessionsListResponse.self, from: data)
        return response.sessions
    }

    func saveSession(_ session: ChatSession) async throws {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        let body = try encoder.encode(session)
        _ = try await request("PUT", path: "/api/sessions/\(session.id.uuidString)", body: body)
    }

    func deleteSession(_ session: ChatSession) async throws {
        _ = try await request("DELETE", path: "/api/sessions/\(session.id.uuidString)")
    }

    func updateSessionPin(sessionId: UUID, isPinned: Bool) async throws {
        struct Body: Encodable { let isPinned: Bool }
        _ = try await request("PATCH", path: "/api/sessions/\(sessionId.uuidString)/pin",
                             body: try JSONEncoder().encode(Body(isPinned: isPinned)))
    }

    func saveConversationMessage(sessionId: UUID, role: String, content: String) async throws {
        struct Body: Encodable { let role: String; let content: String }
        _ = try await post("/api/sessions/\(sessionId.uuidString)/messages",
                          body: Body(role: role, content: content))
    }

    func getRecentMessages(sessionId: UUID, limit: Int) async throws -> [(role: String, content: String, createdAt: Date)] {
        let data = try await get("/api/sessions/\(sessionId.uuidString)/messages?limit=\(limit)")
        let response = try decoder.decode(MessagesResponse.self, from: data)
        return response.messages.map { ($0.role, $0.content, $0.createdAt) }
    }

    func getAllRecentMessages(limit: Int) async throws -> [(sessionId: String, role: String, content: String, createdAt: Date)] {
        // Not yet implemented on server - return empty
        return []
    }

    // MARK: - Memories

    func getAllMemories(limit: Int) async throws -> [ConversationMemory] {
        let data = try await get("/api/memories?limit=\(limit)")
        let response = try decoder.decode(MemoriesListResponse.self, from: data)
        return response.memories
    }

    func insertMemory(content: String, type: ConversationMemory.MemoryType, confidence: Double, sourceSessionId: UUID?, embedding: [Float]?) async throws -> Int64 {
        struct Body: Encodable {
            let content: String; let type: String; let confidence: Double
            let sourceSessionId: String?; let embedding: [Float]?
        }
        let body = Body(content: content, type: type.rawValue, confidence: confidence,
                        sourceSessionId: sourceSessionId?.uuidString, embedding: embedding)
        let data = try await post("/api/memories", body: body)
        let response = try decoder.decode(CreateResponse.self, from: data)
        return Int64(response.id)
    }

    func updateMemory(id: Int64, content: String, confidence: Double?, embedding: [Float]?) async throws {
        struct Body: Encodable { let content: String; let confidence: Double?; let embedding: [Float]? }
        _ = try await request("PUT", path: "/api/memories/\(id)",
                             body: try JSONEncoder().encode(Body(content: content, confidence: confidence, embedding: embedding)))
    }

    func deleteMemory(id: Int64) async throws {
        _ = try await request("DELETE", path: "/api/memories/\(id)")
    }

    func touchMemories(ids: [Int64]) async throws {
        struct Body: Encodable { let ids: [Int64] }
        _ = try await post("/api/memories/touch", body: Body(ids: ids))
    }

    func getAllMemoriesWithEmbeddings(limit: Int) async throws -> [(memory: ConversationMemory, embedding: [Float]?)] {
        let memories = try await getAllMemories(limit: limit)
        return memories.map { ($0, nil) } // Embeddings not transferred over network
    }

    func saveMemoryEmbedding(id: Int64, embedding: [Float]) async throws {
        try await updateMemory(id: id, content: "", confidence: nil, embedding: embedding)
    }

    // MARK: - Briefing

    func getCrossThreadAssociations(minSimilarity: Double, recentDays: Int, limit: Int) async throws -> [(noteAId: Int, noteBId: Int, similarity: Double)] {
        let data = try await get("/api/briefing/associations?minSimilarity=\(minSimilarity)&recentDays=\(recentDays)&limit=\(limit)")
        let response = try decoder.decode(AssociationsResponse.self, from: data)
        return response.associations.map { ($0.noteAId, $0.noteBId, $0.similarity) }
    }

    func isAPIAvailable() async -> Bool {
        do {
            _ = try await get("/health")
            return true
        } catch {
            return false
        }
    }
}

// MARK: - Response Types

enum RemoteServiceError: Error, LocalizedError {
    case invalidURL(String)
    case invalidResponse
    case httpError(Int)

    var errorDescription: String? {
        switch self {
        case .invalidURL(let path): return "Invalid URL: \(path)"
        case .invalidResponse: return "Invalid server response"
        case .httpError(let code): return "HTTP error \(code)"
        }
    }
}

// Codable response wrappers
private struct NotesListResponse: Codable { let count: Int; let notes: [Note] }
private struct ThreadsListResponse: Codable { let count: Int; let threads: [Thread] }
private struct SessionsListResponse: Codable { let count: Int; let sessions: [ChatSession] }
private struct MemoriesListResponse: Codable { let count: Int; let memories: [ConversationMemory] }
private struct ThreadWithNotesResponse: Codable { let thread: Thread; let notes: [Note] }
private struct ThreadTasksResponse: Codable { let threadId: Int; let count: Int; let tasks: [ThreadTask] }
private struct MessagesResponse: Codable {
    struct MessageItem: Codable { let role: String; let content: String; let createdAt: Date }
    let messages: [MessageItem]
}
private struct AssociationsResponse: Codable {
    struct Item: Codable { let noteAId: Int; let noteBId: Int; let similarity: Double }
    let associations: [Item]
}
private struct RelatedNotesAPIResponse: Codable {
    struct Item: Codable { let note: Note; let relationshipType: String; let strength: Double? }
    let results: [Item]
}
private struct ThreadAssignmentsResponse: Codable {
    struct Item: Codable { let noteId: Int; let threadName: String; let threadId: Int }
    let assignments: [Item]
}
private struct CreateResponse: Codable { let id: Int }
```

**Step 2: Build for iOS**

```bash
cd SeleneChat && xcodebuild -scheme SeleneMobile -destination 'platform=iOS Simulator,name=iPhone 16' build
```

**Step 3: Commit**

```bash
git add SeleneChat/Sources/SeleneMobile/
git commit -m "feat(ios): implement RemoteDataService with full DataProvider conformance"
```

---

### Task 16: Implement RemoteOllamaService

**Files:**
- Create: `SeleneChat/Sources/SeleneMobile/Services/RemoteOllamaService.swift`

**Step 1: Create RemoteOllamaService**

```swift
import Foundation
import SeleneShared

actor RemoteOllamaService: LLMProvider {
    let baseURL: String
    let token: String
    private let session: URLSession

    init(baseURL: String, token: String) {
        self.baseURL = baseURL
        self.token = token
        let config = URLSessionConfiguration.default
        config.timeoutIntervalForRequest = 120 // LLM generation can be slow
        self.session = URLSession(configuration: config)
    }

    func generate(prompt: String, model: String?) async throws -> String {
        struct Body: Encodable { let prompt: String; let model: String? }
        struct Response: Decodable { let response: String }

        let body = try JSONEncoder().encode(Body(prompt: prompt, model: model))
        guard let url = URL(string: "\(baseURL)/api/llm/generate") else {
            throw RemoteServiceError.invalidURL("/api/llm/generate")
        }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        if !token.isEmpty {
            request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        }
        request.httpBody = body

        let (data, httpResponse) = try await session.data(for: request)
        guard let http = httpResponse as? HTTPURLResponse, (200...299).contains(http.statusCode) else {
            throw RemoteServiceError.httpError((httpResponse as? HTTPURLResponse)?.statusCode ?? 0)
        }

        let result = try JSONDecoder().decode(Response.self, from: data)
        return result.response
    }

    func embed(text: String, model: String?) async throws -> [Float] {
        struct Body: Encodable { let text: String; let model: String? }
        struct Response: Decodable { let embedding: [Float] }

        let body = try JSONEncoder().encode(Body(text: text, model: model))
        guard let url = URL(string: "\(baseURL)/api/llm/embed") else {
            throw RemoteServiceError.invalidURL("/api/llm/embed")
        }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        if !token.isEmpty {
            request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        }
        request.httpBody = body

        let (data, httpResponse) = try await session.data(for: request)
        guard let http = httpResponse as? HTTPURLResponse, (200...299).contains(http.statusCode) else {
            throw RemoteServiceError.httpError((httpResponse as? HTTPURLResponse)?.statusCode ?? 0)
        }

        return try JSONDecoder().decode(Response.self, from: data).embedding
    }

    func isAvailable() async -> Bool {
        guard let url = URL(string: "\(baseURL)/api/llm/health") else { return false }
        var request = URLRequest(url: url)
        if !token.isEmpty {
            request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        }
        do {
            struct Response: Decodable { let available: Bool }
            let (data, _) = try await session.data(for: request)
            return try JSONDecoder().decode(Response.self, from: data).available
        } catch {
            return false
        }
    }
}
```

**Step 2: Build and commit**

```bash
git add SeleneChat/Sources/SeleneMobile/Services/RemoteOllamaService.swift
git commit -m "feat(ios): implement RemoteOllamaService for LLM proxy"
```

---

### Task 17: Build iOS Chat View

**Files:**
- Create: `SeleneChat/Sources/SeleneMobile/Views/MobileChatView.swift`

**Step 1: Create MobileChatView**

This adapts the macOS ChatView for iPhone. Uses the shared ChatViewModel.

```swift
import SwiftUI
import SeleneShared

struct MobileChatView: View {
    @EnvironmentObject var connectionManager: ConnectionManager
    @StateObject private var chatViewModel: ChatViewModel

    init() {
        // Will be initialized with providers from ConnectionManager in onAppear
        _chatViewModel = StateObject(wrappedValue: ChatViewModel.placeholder())
    }

    @State private var inputText = ""
    @FocusState private var isInputFocused: Bool

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // Messages list
                ScrollViewReader { proxy in
                    ScrollView {
                        LazyVStack(spacing: 12) {
                            ForEach(chatViewModel.currentSession.messages) { message in
                                MessageBubble(message: message)
                                    .id(message.id)
                            }
                        }
                        .padding()
                    }
                    .onChange(of: chatViewModel.currentSession.messages.count) { _ in
                        if let last = chatViewModel.currentSession.messages.last {
                            proxy.scrollTo(last.id, anchor: .bottom)
                        }
                    }
                }

                Divider()

                // Input area
                HStack(spacing: 8) {
                    TextField("Ask Selene...", text: $inputText, axis: .vertical)
                        .textFieldStyle(.plain)
                        .lineLimit(1...5)
                        .focused($isInputFocused)
                        .onSubmit { sendMessage() }

                    Button(action: sendMessage) {
                        Image(systemName: "arrow.up.circle.fill")
                            .font(.title2)
                            .foregroundStyle(inputText.isEmpty ? .gray : .accentColor)
                    }
                    .disabled(inputText.isEmpty || chatViewModel.isProcessing)
                }
                .padding(.horizontal)
                .padding(.vertical, 8)
            }
            .navigationTitle("Selene")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Menu {
                        Button("New Chat") { chatViewModel.newSession() }
                        Button("Sessions") { /* show sessions sheet */ }
                    } label: {
                        Image(systemName: "ellipsis.circle")
                    }
                }
            }
        }
        .onAppear {
            if let dp = connectionManager.dataProvider, let llm = connectionManager.llmProvider {
                chatViewModel.configure(dataProvider: dp, llmProvider: llm)
            }
        }
    }

    private func sendMessage() {
        let text = inputText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else { return }
        inputText = ""
        Task {
            await chatViewModel.sendMessage(text)
        }
    }
}

struct MessageBubble: View {
    let message: Message

    var body: some View {
        HStack {
            if message.role == .user { Spacer() }

            VStack(alignment: message.role == .user ? .trailing : .leading, spacing: 4) {
                Text(message.content)
                    .padding(12)
                    .background(message.role == .user ? Color.accentColor : Color(.secondarySystemBackground))
                    .foregroundStyle(message.role == .user ? .white : .primary)
                    .cornerRadius(16)

                Text(message.timestamp, style: .time)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }

            if message.role == .assistant { Spacer() }
        }
    }
}
```

**Step 2: Update TabRootView to use real views**

```swift
struct TabRootView: View {
    @EnvironmentObject var connectionManager: ConnectionManager

    var body: some View {
        TabView {
            MobileChatView()
                .tabItem { Label("Chat", systemImage: "message") }
            Text("Threads - Coming Soon")
                .tabItem { Label("Threads", systemImage: "circle.hexagongrid") }
            Text("Briefing - Coming Soon")
                .tabItem { Label("Briefing", systemImage: "sun.max") }
            MobileSettingsView()
                .tabItem { Label("Settings", systemImage: "gear") }
        }
    }
}
```

**Step 3: Create MobileSettingsView**

```swift
import SwiftUI

struct MobileSettingsView: View {
    @EnvironmentObject var connectionManager: ConnectionManager

    var body: some View {
        NavigationStack {
            Form {
                Section("Connection") {
                    LabeledContent("Server", value: connectionManager.serverURL)
                    LabeledContent("Status", value: connectionManager.isConnected ? "Connected" : "Disconnected")
                }
                Section("About") {
                    LabeledContent("Version", value: "1.0.0")
                }
            }
            .navigationTitle("Settings")
        }
    }
}
```

**Step 4: Build and commit**

```bash
git add SeleneChat/Sources/SeleneMobile/
git commit -m "feat(ios): add MobileChatView with message bubbles and input"
```

---

### Task 18: Build iOS Thread and Briefing Views

**Files:**
- Create: `SeleneChat/Sources/SeleneMobile/Views/MobileThreadsView.swift`
- Create: `SeleneChat/Sources/SeleneMobile/Views/MobileBriefingView.swift`

These follow the same pattern as MobileChatView — use shared view models, iOS-specific layout. Implementation details match the macOS views but with NavigationStack push navigation instead of split views.

**Step 1: Create MobileThreadsView**

Thread list with momentum indicators. Tap pushes to thread detail with notes and deep-dive chat.

**Step 2: Create MobileBriefingView**

Morning briefing cards in a vertical scroll. Tap a card for deep-context follow-up chat.

**Step 3: Wire into TabRootView, build, commit**

```bash
git add SeleneChat/Sources/SeleneMobile/Views/
git commit -m "feat(ios): add threads and briefing views"
```

---

### Task 19: iOS Voice Input

**Files:**
- Create: `SeleneChat/Sources/SeleneMobile/Services/MobileSpeechService.swift`

iOS uses the same `Speech` framework as macOS but with iOS-specific authorization flow. Create a speech service that conforms to a shared protocol or wraps `SFSpeechRecognizer` for iOS.

**Step 1: Create MobileSpeechService with SFSpeechRecognizer**

Same pattern as macOS SpeechRecognitionService but using iOS audio session configuration.

**Step 2: Add voice button to MobileChatView input area**

**Step 3: Build, test on simulator, commit**

```bash
git commit -m "feat(ios): add voice input with SFSpeechRecognizer"
```

---

## Phase 4: Push Notifications & Live Activities

### Task 20: APNs Server Integration

**Files:**
- Create: `src/lib/apns.ts`
- Modify: `src/lib/config.ts`
- Modify: `src/workflows/daily-summary.ts`
- Modify: `src/workflows/detect-threads.ts`

**Step 1: Add APNs config**

In `src/lib/config.ts`:
```typescript
apnsKeyPath: process.env.APNS_KEY_PATH || '',
apnsKeyId: process.env.APNS_KEY_ID || '',
apnsTeamId: process.env.APNS_TEAM_ID || '',
apnsBundleId: process.env.APNS_BUNDLE_ID || 'com.selene.mobile',
apnsProduction: process.env.APNS_PRODUCTION === 'true',
```

**Step 2: Create APNs client**

Create `src/lib/apns.ts` using HTTP/2 to APNs gateway. Send notifications using device tokens from `device_tokens` table.

**Step 3: Add notification triggers to workflows**

- `daily-summary.ts`: After generating summary, send "Your morning briefing is ready" push
- `detect-threads.ts`: When new thread created, send "New thread detected: {name}"

**Step 4: Test with iOS device, commit**

```bash
git commit -m "feat: add APNs push notifications for briefing and thread activity"
```

---

### Task 21: iOS Push Notification Registration

**Files:**
- Modify: `SeleneChat/Sources/SeleneMobile/App/SeleneMobileApp.swift`
- Create: `SeleneChat/Sources/SeleneMobile/Services/PushNotificationService.swift`

**Step 1: Request notification permissions and register device token**

In SeleneMobileApp, add `UIApplicationDelegateAdaptor` to handle `didRegisterForRemoteNotificationsWithDeviceToken`. Send token to server via `POST /api/devices/register`.

**Step 2: Handle incoming notifications**

Route taps to appropriate views (briefing tab, thread detail, etc.)

**Step 3: Commit**

```bash
git commit -m "feat(ios): register for push notifications and handle delivery"
```

---

### Task 22: Live Activities

**Files:**
- Create: `SeleneChat/Sources/SeleneMobile/Activities/SeleneChatActivity.swift`
- Modify: `SeleneChat/Sources/SeleneMobile/Views/MobileChatView.swift`

**Step 1: Define ActivityAttributes**

```swift
import ActivityKit

struct SeleneChatActivity: ActivityAttributes {
    public struct ContentState: Codable, Hashable {
        var status: String
        var progress: Double
    }
    var queryPreview: String
}
```

**Step 2: Start activity when sending chat message**

In MobileChatView, when `chatViewModel.sendMessage()` is called:
- Start a live activity showing "Searching notes..."
- Update to "Thinking..." when LLM starts generating
- End activity when response arrives

**Step 3: Configure Info.plist for live activities**

Add `NSSupportsLiveActivities = YES`

**Step 4: Test, commit**

```bash
git commit -m "feat(ios): add live activities for chat processing state"
```

---

## Phase 5: Integration Testing & Polish

### Task 23: End-to-End Test

**Manual verification checklist:**

1. Start Selene server on Mac
2. Open SeleneMobile on iPhone
3. Enter Tailscale IP and API token
4. Verify connection succeeds
5. Send chat message → get AI response with citations
6. View thread list with momentum scores
7. Open morning briefing
8. Use voice input
9. Receive push notification for briefing
10. See live activity during chat processing

### Task 24: ATS Exception for Tailscale

**Files:**
- Create: `SeleneChat/Sources/SeleneMobile/Info.plist`

Add App Transport Security exception for Tailscale subnet (100.x.x.x):

```xml
<key>NSAppTransportSecurity</key>
<dict>
    <key>NSExceptionDomains</key>
    <dict>
        <key>100.0.0.0/8</key>
        <dict>
            <key>NSExceptionAllowsInsecureHTTPLoads</key>
            <true/>
        </dict>
    </dict>
</dict>
```

Note: Wildcard domain exceptions may not work for IP ranges. May need `NSAllowsLocalNetworking` or a specific IP exception.

### Task 25: Documentation Update

**Files:**
- Modify: `CLAUDE.md` — Add SeleneMobile to architecture diagram
- Modify: `SeleneChat/CLAUDE.md` — Document three-target structure
- Modify: `.claude/PROJECT-STATUS.md` — Update completed features

---

## Execution Notes

**Total tasks:** 25
**Estimated phases:** 4 main + 1 polish
**Dependencies:**
- Phase 1 (Server API) can be developed independently
- Phase 2 (Swift Refactor) can start in parallel with Phase 1
- Phase 3 (iOS App) requires Phase 1 + Phase 2 to be complete
- Phase 4 (Notifications) requires Phase 3

**Testing approach:**
- Server endpoints: curl commands after each task
- Swift refactor: `swift test` after each task (270+ tests must pass)
- iOS app: Xcode simulator builds
- Integration: Manual testing with real device over Tailscale

**Risk areas:**
- Task 11-13 (Swift refactor) — most files touched, highest regression risk
- Task 15 (RemoteDataService) — response format mismatches between server and Swift Codable models
- Task 20 (APNs) — certificate setup is fiddly
