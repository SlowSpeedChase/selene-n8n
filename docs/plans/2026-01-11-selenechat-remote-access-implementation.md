# SeleneChat Remote Access Implementation Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** Enable SeleneChat to run on a laptop, connecting to desktop's Fastify API and Ollama over the local network.

**Architecture:** Desktop exposes REST API for database operations (notes, sessions, threads) via Fastify on port 5678, and Ollama on port 11434. SeleneChat gains a Remote Mode that uses HTTP instead of direct SQLite access.

**Tech Stack:** TypeScript/Fastify (server), Swift/SwiftUI (client), SQLite, Ollama

**Design Doc:** `docs/plans/2026-01-11-selenechat-remote-access-design.md`

---

## Phase 1: Server API

### Task 1: Bind Fastify to Network Interface

**Files:**
- Modify: `src/server.ts`

**Step 1: Update server listen call**

In `src/server.ts`, find the `server.listen` call and change from `localhost` to `0.0.0.0`:

```typescript
// Change from:
await server.listen({ port: config.port })
// or
await server.listen({ port: config.port, host: 'localhost' })

// To:
await server.listen({ port: config.port, host: '0.0.0.0' })
```

**Step 2: Test server starts and is accessible**

```bash
# Start server
npm run start &
sleep 2

# Test from localhost
curl http://localhost:5678/health

# Get local IP
ifconfig | grep "inet " | grep -v 127.0.0.1

# Test from network IP (replace with your IP)
curl http://192.168.x.x:5678/health

# Stop server
pkill -f "ts-node src/server.ts"
```

Expected: Both requests return `{"status":"healthy"}`

**Step 3: Commit**

```bash
git add src/server.ts
git commit -m "feat(api): bind Fastify server to all network interfaces"
```

---

### Task 2: Create Notes API Routes

**Files:**
- Create: `src/routes/api/notes.ts`
- Modify: `src/server.ts`

**Step 1: Create notes route file**

Create `src/routes/api/notes.ts`:

```typescript
import { FastifyInstance } from 'fastify';
import { getDb } from '../../lib/db';

interface NoteRow {
  id: number;
  title: string;
  content: string;
  content_hash: string;
  source_type: string;
  word_count: number;
  character_count: number;
  tags: string | null;
  created_at: string;
  imported_at: string;
  processed_at: string | null;
  exported_at: string | null;
  status: string;
  exported_to_obsidian: number;
  source_uuid: string | null;
  test_run: string | null;
  // processed_notes fields (from LEFT JOIN)
  concepts: string | null;
  concept_confidence: string | null;
  primary_theme: string | null;
  secondary_themes: string | null;
  theme_confidence: number | null;
  overall_sentiment: string | null;
  sentiment_score: number | null;
  emotional_tone: string | null;
  energy_level: string | null;
}

function formatNote(row: NoteRow) {
  return {
    id: row.id,
    title: row.title,
    content: row.content,
    contentHash: row.content_hash,
    sourceType: row.source_type,
    wordCount: row.word_count,
    characterCount: row.character_count,
    tags: row.tags ? JSON.parse(row.tags) : null,
    createdAt: row.created_at,
    importedAt: row.imported_at,
    processedAt: row.processed_at,
    exportedAt: row.exported_at,
    status: row.status,
    exportedToObsidian: row.exported_to_obsidian === 1,
    sourceUuid: row.source_uuid,
    testRun: row.test_run,
    concepts: row.concepts ? JSON.parse(row.concepts) : null,
    conceptConfidence: row.concept_confidence ? JSON.parse(row.concept_confidence) : null,
    primaryTheme: row.primary_theme,
    secondaryThemes: row.secondary_themes ? JSON.parse(row.secondary_themes) : null,
    themeConfidence: row.theme_confidence,
    overallSentiment: row.overall_sentiment,
    sentimentScore: row.sentiment_score,
    emotionalTone: row.emotional_tone,
    energyLevel: row.energy_level,
  };
}

export async function notesRoutes(server: FastifyInstance) {
  const db = getDb();

  // GET /api/notes - List recent notes
  server.get<{
    Querystring: { limit?: string };
  }>('/api/notes', async (request, reply) => {
    const limit = parseInt(request.query.limit || '100', 10);

    const rows = db.prepare(`
      SELECT r.*, p.concepts, p.concept_confidence, p.primary_theme,
             p.secondary_themes, p.theme_confidence, p.overall_sentiment,
             p.sentiment_score, p.emotional_tone, p.energy_level
      FROM raw_notes r
      LEFT JOIN processed_notes p ON r.id = p.raw_note_id
      WHERE r.test_run IS NULL
      ORDER BY r.created_at DESC
      LIMIT ?
    `).all(limit) as NoteRow[];

    return rows.map(formatNote);
  });

  // GET /api/notes/:id - Get single note
  server.get<{
    Params: { id: string };
  }>('/api/notes/:id', async (request, reply) => {
    const id = parseInt(request.params.id, 10);

    const row = db.prepare(`
      SELECT r.*, p.concepts, p.concept_confidence, p.primary_theme,
             p.secondary_themes, p.theme_confidence, p.overall_sentiment,
             p.sentiment_score, p.emotional_tone, p.energy_level
      FROM raw_notes r
      LEFT JOIN processed_notes p ON r.id = p.raw_note_id
      WHERE r.id = ?
    `).get(id) as NoteRow | undefined;

    if (!row) {
      return reply.status(404).send({ error: 'Note not found' });
    }

    return formatNote(row);
  });

  // GET /api/notes/search - Full-text search
  server.get<{
    Querystring: { q: string; limit?: string };
  }>('/api/notes/search', async (request, reply) => {
    const query = request.query.q;
    const limit = parseInt(request.query.limit || '50', 10);

    if (!query) {
      return reply.status(400).send({ error: 'Query parameter q is required' });
    }

    const searchPattern = `%${query}%`;
    const rows = db.prepare(`
      SELECT r.*, p.concepts, p.concept_confidence, p.primary_theme,
             p.secondary_themes, p.theme_confidence, p.overall_sentiment,
             p.sentiment_score, p.emotional_tone, p.energy_level
      FROM raw_notes r
      LEFT JOIN processed_notes p ON r.id = p.raw_note_id
      WHERE r.test_run IS NULL
        AND (r.content LIKE ? OR r.title LIKE ?)
      ORDER BY r.created_at DESC
      LIMIT ?
    `).all(searchPattern, searchPattern, limit) as NoteRow[];

    return rows.map(formatNote);
  });

  // GET /api/notes/by-concept - Filter by concept
  server.get<{
    Querystring: { concept: string; limit?: string };
  }>('/api/notes/by-concept', async (request, reply) => {
    const concept = request.query.concept;
    const limit = parseInt(request.query.limit || '50', 10);

    if (!concept) {
      return reply.status(400).send({ error: 'Query parameter concept is required' });
    }

    const searchPattern = `%${concept}%`;
    const rows = db.prepare(`
      SELECT r.*, p.concepts, p.concept_confidence, p.primary_theme,
             p.secondary_themes, p.theme_confidence, p.overall_sentiment,
             p.sentiment_score, p.emotional_tone, p.energy_level
      FROM raw_notes r
      INNER JOIN processed_notes p ON r.id = p.raw_note_id
      WHERE r.test_run IS NULL AND p.concepts LIKE ?
      ORDER BY r.created_at DESC
      LIMIT ?
    `).all(searchPattern, limit) as NoteRow[];

    return rows.map(formatNote);
  });

  // GET /api/notes/by-theme - Filter by theme
  server.get<{
    Querystring: { theme: string; limit?: string };
  }>('/api/notes/by-theme', async (request, reply) => {
    const theme = request.query.theme;
    const limit = parseInt(request.query.limit || '50', 10);

    if (!theme) {
      return reply.status(400).send({ error: 'Query parameter theme is required' });
    }

    const searchPattern = `%${theme}%`;
    const rows = db.prepare(`
      SELECT r.*, p.concepts, p.concept_confidence, p.primary_theme,
             p.secondary_themes, p.theme_confidence, p.overall_sentiment,
             p.sentiment_score, p.emotional_tone, p.energy_level
      FROM raw_notes r
      INNER JOIN processed_notes p ON r.id = p.raw_note_id
      WHERE r.test_run IS NULL
        AND (p.primary_theme = ? OR p.secondary_themes LIKE ?)
      ORDER BY r.created_at DESC
      LIMIT ?
    `).all(theme, searchPattern, limit) as NoteRow[];

    return rows.map(formatNote);
  });

  // GET /api/notes/by-energy - Filter by energy level
  server.get<{
    Querystring: { energy: string; limit?: string };
  }>('/api/notes/by-energy', async (request, reply) => {
    const energy = request.query.energy;
    const limit = parseInt(request.query.limit || '50', 10);

    if (!energy) {
      return reply.status(400).send({ error: 'Query parameter energy is required' });
    }

    const rows = db.prepare(`
      SELECT r.*, p.concepts, p.concept_confidence, p.primary_theme,
             p.secondary_themes, p.theme_confidence, p.overall_sentiment,
             p.sentiment_score, p.emotional_tone, p.energy_level
      FROM raw_notes r
      INNER JOIN processed_notes p ON r.id = p.raw_note_id
      WHERE r.test_run IS NULL AND p.energy_level = ?
      ORDER BY r.created_at DESC
      LIMIT ?
    `).all(energy, limit) as NoteRow[];

    return rows.map(formatNote);
  });

  // GET /api/notes/by-date - Date range filter
  server.get<{
    Querystring: { from: string; to: string };
  }>('/api/notes/by-date', async (request, reply) => {
    const { from, to } = request.query;

    if (!from || !to) {
      return reply.status(400).send({ error: 'Query parameters from and to are required' });
    }

    const rows = db.prepare(`
      SELECT r.*, p.concepts, p.concept_confidence, p.primary_theme,
             p.secondary_themes, p.theme_confidence, p.overall_sentiment,
             p.sentiment_score, p.emotional_tone, p.energy_level
      FROM raw_notes r
      LEFT JOIN processed_notes p ON r.id = p.raw_note_id
      WHERE r.test_run IS NULL
        AND r.created_at >= ? AND r.created_at <= ?
      ORDER BY r.created_at DESC
    `).all(from, to) as NoteRow[];

    return rows.map(formatNote);
  });
}
```

**Step 2: Register routes in server.ts**

Add to `src/server.ts` after other route registrations:

```typescript
import { notesRoutes } from './routes/api/notes';

// In the server setup, after existing routes:
await server.register(notesRoutes);
```

**Step 3: Test notes endpoints**

```bash
# Start server
npm run start &
sleep 2

# Test list notes
curl http://localhost:5678/api/notes?limit=3 | jq

# Test get single note (use an ID from previous result)
curl http://localhost:5678/api/notes/1 | jq

# Test search
curl "http://localhost:5678/api/notes/search?q=test" | jq

# Stop server
pkill -f "ts-node src/server.ts"
```

Expected: JSON arrays/objects with note data

**Step 4: Commit**

```bash
git add src/routes/api/notes.ts src/server.ts
git commit -m "feat(api): add notes REST endpoints"
```

---

### Task 3: Create Sessions API Routes

**Files:**
- Create: `src/routes/api/sessions.ts`
- Modify: `src/server.ts`

**Step 1: Create sessions route file**

Create `src/routes/api/sessions.ts`:

```typescript
import { FastifyInstance } from 'fastify';
import { getDb } from '../../lib/db';

interface SessionRow {
  id: string;
  title: string;
  created_at: string;
  updated_at: string;
  message_count: number;
  is_pinned: number;
  compression_state: string;
  compressed_at: string | null;
  full_messages_json: string | null;
  summary_text: string | null;
}

interface SessionBody {
  id: string;
  title: string;
  createdAt: string;
  updatedAt: string;
  messages: unknown[];
  isPinned: boolean;
  compressionState: string;
  compressedAt: string | null;
  summaryText: string | null;
}

function formatSession(row: SessionRow) {
  return {
    id: row.id,
    title: row.title,
    createdAt: row.created_at,
    updatedAt: row.updated_at,
    messageCount: row.message_count,
    isPinned: row.is_pinned === 1,
    compressionState: row.compression_state,
    compressedAt: row.compressed_at,
    messages: row.full_messages_json ? JSON.parse(row.full_messages_json) : [],
    summaryText: row.summary_text,
  };
}

export async function sessionsRoutes(server: FastifyInstance) {
  const db = getDb();

  // Ensure chat_sessions table exists
  db.exec(`
    CREATE TABLE IF NOT EXISTS chat_sessions (
      id TEXT PRIMARY KEY,
      title TEXT NOT NULL,
      created_at TEXT NOT NULL,
      updated_at TEXT NOT NULL,
      message_count INTEGER NOT NULL DEFAULT 0,
      is_pinned INTEGER NOT NULL DEFAULT 0,
      compression_state TEXT NOT NULL DEFAULT 'full',
      compressed_at TEXT,
      full_messages_json TEXT,
      summary_text TEXT
    )
  `);

  // GET /api/sessions - List all sessions
  server.get('/api/sessions', async () => {
    const rows = db.prepare(`
      SELECT * FROM chat_sessions
      ORDER BY updated_at DESC
    `).all() as SessionRow[];

    return rows.map(formatSession);
  });

  // POST /api/sessions - Create or update session
  server.post<{
    Body: SessionBody;
  }>('/api/sessions', async (request, reply) => {
    const session = request.body;
    const messagesJson = JSON.stringify(session.messages);

    const existing = db.prepare('SELECT id FROM chat_sessions WHERE id = ?').get(session.id);

    if (existing) {
      db.prepare(`
        UPDATE chat_sessions SET
          title = ?,
          updated_at = ?,
          message_count = ?,
          is_pinned = ?,
          compression_state = ?,
          compressed_at = ?,
          full_messages_json = ?,
          summary_text = ?
        WHERE id = ?
      `).run(
        session.title,
        session.updatedAt,
        session.messages.length,
        session.isPinned ? 1 : 0,
        session.compressionState,
        session.compressedAt,
        session.compressionState === 'full' ? messagesJson : null,
        session.summaryText,
        session.id
      );
    } else {
      db.prepare(`
        INSERT INTO chat_sessions
        (id, title, created_at, updated_at, message_count, is_pinned,
         compression_state, compressed_at, full_messages_json, summary_text)
        VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
      `).run(
        session.id,
        session.title,
        session.createdAt,
        session.updatedAt,
        session.messages.length,
        session.isPinned ? 1 : 0,
        session.compressionState,
        session.compressedAt,
        session.compressionState === 'full' ? messagesJson : null,
        session.summaryText
      );
    }

    return { success: true };
  });

  // DELETE /api/sessions/:id - Delete session
  server.delete<{
    Params: { id: string };
  }>('/api/sessions/:id', async (request, reply) => {
    const result = db.prepare('DELETE FROM chat_sessions WHERE id = ?').run(request.params.id);

    if (result.changes === 0) {
      return reply.status(404).send({ error: 'Session not found' });
    }

    return { success: true };
  });

  // PATCH /api/sessions/:id/pin - Toggle pin status
  server.patch<{
    Params: { id: string };
    Body: { isPinned: boolean };
  }>('/api/sessions/:id/pin', async (request, reply) => {
    const result = db.prepare(`
      UPDATE chat_sessions SET is_pinned = ? WHERE id = ?
    `).run(request.body.isPinned ? 1 : 0, request.params.id);

    if (result.changes === 0) {
      return reply.status(404).send({ error: 'Session not found' });
    }

    return { success: true };
  });

  // POST /api/sessions/:id/compress - Compress session
  server.post<{
    Params: { id: string };
    Body: { summary: string };
  }>('/api/sessions/:id/compress', async (request, reply) => {
    const now = new Date().toISOString();

    const result = db.prepare(`
      UPDATE chat_sessions SET
        compression_state = 'compressed',
        summary_text = ?,
        compressed_at = ?,
        full_messages_json = NULL
      WHERE id = ?
    `).run(request.body.summary, now, request.params.id);

    if (result.changes === 0) {
      return reply.status(404).send({ error: 'Session not found' });
    }

    return { success: true };
  });
}
```

**Step 2: Register routes in server.ts**

Add to `src/server.ts`:

```typescript
import { sessionsRoutes } from './routes/api/sessions';

// After notesRoutes:
await server.register(sessionsRoutes);
```

**Step 3: Test sessions endpoints**

```bash
# Start server
npm run start &
sleep 2

# Test list sessions (may be empty)
curl http://localhost:5678/api/sessions | jq

# Test create session
curl -X POST http://localhost:5678/api/sessions \
  -H "Content-Type: application/json" \
  -d '{
    "id": "test-session-1",
    "title": "Test Session",
    "createdAt": "2026-01-11T12:00:00Z",
    "updatedAt": "2026-01-11T12:00:00Z",
    "messages": [{"role": "user", "content": "Hello"}],
    "isPinned": false,
    "compressionState": "full",
    "compressedAt": null,
    "summaryText": null
  }' | jq

# Verify it was created
curl http://localhost:5678/api/sessions | jq

# Delete test session
curl -X DELETE http://localhost:5678/api/sessions/test-session-1 | jq

# Stop server
pkill -f "ts-node src/server.ts"
```

**Step 4: Commit**

```bash
git add src/routes/api/sessions.ts src/server.ts
git commit -m "feat(api): add chat sessions REST endpoints"
```

---

### Task 4: Create Threads API Routes

**Files:**
- Create: `src/routes/api/threads.ts`
- Modify: `src/server.ts`

**Step 1: Create threads route file**

Create `src/routes/api/threads.ts`:

```typescript
import { FastifyInstance } from 'fastify';
import { getDb } from '../../lib/db';

interface ThreadRow {
  id: number;
  raw_note_id: number | null;
  thread_type: string;
  prompt: string;
  status: string;
  created_at: string;
  surfaced_at: string | null;
  completed_at: string | null;
  related_concepts: string | null;
  project_id: number | null;
  thread_name: string | null;
  resurface_reason: string | null;
  last_resurfaced_at: string | null;
  // From JOIN
  note_title: string | null;
  note_content: string | null;
}

function formatThread(row: ThreadRow) {
  return {
    id: row.id,
    rawNoteId: row.raw_note_id,
    threadType: row.thread_type,
    prompt: row.prompt,
    status: row.status,
    createdAt: row.created_at,
    surfacedAt: row.surfaced_at,
    completedAt: row.completed_at,
    relatedConcepts: row.related_concepts ? JSON.parse(row.related_concepts) : null,
    projectId: row.project_id,
    threadName: row.thread_name,
    resurfaceReason: row.resurface_reason,
    lastResurfacedAt: row.last_resurfaced_at,
    noteTitle: row.note_title,
    noteContent: row.note_content,
  };
}

export async function threadsRoutes(server: FastifyInstance) {
  const db = getDb();

  // GET /api/threads - List pending/active/review threads
  server.get('/api/threads', async () => {
    const rows = db.prepare(`
      SELECT dt.*, rn.title as note_title, rn.content as note_content
      FROM discussion_threads dt
      LEFT JOIN raw_notes rn ON dt.raw_note_id = rn.id
      WHERE dt.status IN ('pending', 'active', 'review')
        AND dt.test_run IS NULL
      ORDER BY
        CASE WHEN dt.status = 'review' THEN 0 ELSE 1 END,
        dt.created_at DESC
    `).all() as ThreadRow[];

    return rows.map(formatThread);
  });

  // GET /api/threads/:id - Get single thread
  server.get<{
    Params: { id: string };
  }>('/api/threads/:id', async (request, reply) => {
    const id = parseInt(request.params.id, 10);

    const row = db.prepare(`
      SELECT dt.*, rn.title as note_title, rn.content as note_content
      FROM discussion_threads dt
      LEFT JOIN raw_notes rn ON dt.raw_note_id = rn.id
      WHERE dt.id = ?
    `).get(id) as ThreadRow | undefined;

    if (!row) {
      return reply.status(404).send({ error: 'Thread not found' });
    }

    return formatThread(row);
  });

  // PATCH /api/threads/:id/status - Update thread status
  server.patch<{
    Params: { id: string };
    Body: { status: string };
  }>('/api/threads/:id/status', async (request, reply) => {
    const id = parseInt(request.params.id, 10);
    const { status } = request.body;
    const now = new Date().toISOString();

    let sql = 'UPDATE discussion_threads SET status = ?';
    const params: (string | number)[] = [status];

    if (status === 'active') {
      sql += ', surfaced_at = ?';
      params.push(now);
    }

    if (status === 'completed' || status === 'dismissed') {
      sql += ', completed_at = ?';
      params.push(now);
    }

    sql += ' WHERE id = ?';
    params.push(id);

    const result = db.prepare(sql).run(...params);

    if (result.changes === 0) {
      return reply.status(404).send({ error: 'Thread not found' });
    }

    return { success: true };
  });
}
```

**Step 2: Register routes in server.ts**

Add to `src/server.ts`:

```typescript
import { threadsRoutes } from './routes/api/threads';

// After sessionsRoutes:
await server.register(threadsRoutes);
```

**Step 3: Test threads endpoints**

```bash
# Start server
npm run start &
sleep 2

# Test list threads
curl http://localhost:5678/api/threads | jq

# If there are threads, test get single thread
curl http://localhost:5678/api/threads/1 | jq

# Stop server
pkill -f "ts-node src/server.ts"
```

**Step 4: Commit**

```bash
git add src/routes/api/threads.ts src/server.ts
git commit -m "feat(api): add discussion threads REST endpoints"
```

---

### Task 5: Create Routes Index File

**Files:**
- Create: `src/routes/api/index.ts`
- Modify: `src/server.ts`

**Step 1: Create index file**

Create `src/routes/api/index.ts`:

```typescript
import { FastifyInstance } from 'fastify';
import { notesRoutes } from './notes';
import { sessionsRoutes } from './sessions';
import { threadsRoutes } from './threads';

export async function apiRoutes(server: FastifyInstance) {
  await server.register(notesRoutes);
  await server.register(sessionsRoutes);
  await server.register(threadsRoutes);
}
```

**Step 2: Simplify server.ts imports**

Update `src/server.ts` to use single import:

```typescript
// Replace individual route imports with:
import { apiRoutes } from './routes/api';

// Replace individual registrations with:
await server.register(apiRoutes);
```

**Step 3: Verify all endpoints still work**

```bash
npm run start &
sleep 2
curl http://localhost:5678/api/notes?limit=1 | jq
curl http://localhost:5678/api/sessions | jq
curl http://localhost:5678/api/threads | jq
pkill -f "ts-node src/server.ts"
```

**Step 4: Commit**

```bash
git add src/routes/api/index.ts src/server.ts
git commit -m "refactor(api): consolidate API route registration"
```

---

## Phase 2: SeleneChat Remote Mode

### Task 6: Create DataServiceProtocol

**Files:**
- Create: `SeleneChat/Sources/Services/DataServiceProtocol.swift`

**Step 1: Create the protocol file**

Create `SeleneChat/Sources/Services/DataServiceProtocol.swift`:

```swift
import Foundation

/// Protocol defining data operations for both local and remote modes
protocol DataServiceProtocol {
    // MARK: - Notes
    func getAllNotes(limit: Int) async throws -> [Note]
    func searchNotes(query: String, limit: Int) async throws -> [Note]
    func getNote(byId noteId: Int) async throws -> Note?
    func getNoteByConcept(_ concept: String, limit: Int) async throws -> [Note]
    func getNotesByTheme(_ theme: String, limit: Int) async throws -> [Note]
    func getNotesByEnergy(_ energy: String, limit: Int) async throws -> [Note]
    func getNotesByDateRange(from: Date, to: Date) async throws -> [Note]

    // MARK: - Chat Sessions
    func saveSession(_ session: ChatSession) async throws
    func loadSessions() async throws -> [ChatSession]
    func deleteSession(_ session: ChatSession) async throws
    func updateSessionPin(sessionId: UUID, isPinned: Bool) async throws
    func compressSession(sessionId: UUID, summary: String) async throws

    // MARK: - Discussion Threads
    func getPendingThreads() async throws -> [DiscussionThread]
    func getThread(byId threadId: Int) async throws -> DiscussionThread?
    func updateThreadStatus(_ threadId: Int, status: DiscussionThread.Status) async throws
}
```

**Step 2: Commit**

```bash
cd SeleneChat
git add Sources/Services/DataServiceProtocol.swift
git commit -m "feat(selenechat): add DataServiceProtocol for local/remote abstraction"
```

---

### Task 7: Make DatabaseService Conform to Protocol

**Files:**
- Modify: `SeleneChat/Sources/Services/DatabaseService.swift`

**Step 1: Add protocol conformance**

At the end of `DatabaseService.swift`, add:

```swift
// MARK: - DataServiceProtocol Conformance
extension DatabaseService: DataServiceProtocol {}
```

Note: DatabaseService already implements all required methods. This just declares conformance.

**Step 2: Verify it compiles**

```bash
cd SeleneChat
swift build 2>&1 | head -20
```

Expected: Build succeeds (or shows unrelated warnings)

**Step 3: Commit**

```bash
git add Sources/Services/DatabaseService.swift
git commit -m "feat(selenechat): make DatabaseService conform to DataServiceProtocol"
```

---

### Task 8: Create APIService

**Files:**
- Create: `SeleneChat/Sources/Services/APIService.swift`

**Step 1: Create APIService**

Create `SeleneChat/Sources/Services/APIService.swift`:

```swift
import Foundation

/// Remote API client implementing DataServiceProtocol
actor APIService: DataServiceProtocol, ObservableObject {
    private let baseURL: String
    private let session = URLSession.shared
    private let decoder: JSONDecoder
    private let encoder: JSONEncoder

    init(serverAddress: String) {
        self.baseURL = "http://\(serverAddress):5678"

        self.decoder = JSONDecoder()
        decoder.keyDecodingStrategy = .convertFromSnakeCase
        decoder.dateDecodingStrategy = .iso8601

        self.encoder = JSONEncoder()
        encoder.keyEncodingStrategy = .convertToSnakeCase
        encoder.dateEncodingStrategy = .iso8601
    }

    enum APIError: Error, LocalizedError {
        case invalidURL
        case requestFailed(Int)
        case decodingFailed(Error)
        case networkError(Error)

        var errorDescription: String? {
            switch self {
            case .invalidURL:
                return "Invalid server URL"
            case .requestFailed(let code):
                return "Request failed with status \(code)"
            case .decodingFailed(let error):
                return "Failed to decode response: \(error.localizedDescription)"
            case .networkError(let error):
                return "Network error: \(error.localizedDescription)"
            }
        }
    }

    // MARK: - HTTP Helpers

    private func get<T: Decodable>(_ path: String) async throws -> T {
        guard let url = URL(string: "\(baseURL)\(path)") else {
            throw APIError.invalidURL
        }

        do {
            let (data, response) = try await session.data(from: url)

            guard let httpResponse = response as? HTTPURLResponse else {
                throw APIError.requestFailed(0)
            }

            guard httpResponse.statusCode == 200 else {
                throw APIError.requestFailed(httpResponse.statusCode)
            }

            return try decoder.decode(T.self, from: data)
        } catch let error as APIError {
            throw error
        } catch let error as DecodingError {
            throw APIError.decodingFailed(error)
        } catch {
            throw APIError.networkError(error)
        }
    }

    private func post<T: Encodable>(_ path: String, body: T) async throws {
        guard let url = URL(string: "\(baseURL)\(path)") else {
            throw APIError.invalidURL
        }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try encoder.encode(body)

        let (_, response) = try await session.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse,
              httpResponse.statusCode == 200 else {
            throw APIError.requestFailed((response as? HTTPURLResponse)?.statusCode ?? 0)
        }
    }

    private func patch<T: Encodable>(_ path: String, body: T) async throws {
        guard let url = URL(string: "\(baseURL)\(path)") else {
            throw APIError.invalidURL
        }

        var request = URLRequest(url: url)
        request.httpMethod = "PATCH"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try encoder.encode(body)

        let (_, response) = try await session.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse,
              httpResponse.statusCode == 200 else {
            throw APIError.requestFailed((response as? HTTPURLResponse)?.statusCode ?? 0)
        }
    }

    private func delete(_ path: String) async throws {
        guard let url = URL(string: "\(baseURL)\(path)") else {
            throw APIError.invalidURL
        }

        var request = URLRequest(url: url)
        request.httpMethod = "DELETE"

        let (_, response) = try await session.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse,
              httpResponse.statusCode == 200 else {
            throw APIError.requestFailed((response as? HTTPURLResponse)?.statusCode ?? 0)
        }
    }

    // MARK: - Notes

    func getAllNotes(limit: Int = 100) async throws -> [Note] {
        try await get("/api/notes?limit=\(limit)")
    }

    func searchNotes(query: String, limit: Int = 50) async throws -> [Note] {
        let encoded = query.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? query
        return try await get("/api/notes/search?q=\(encoded)&limit=\(limit)")
    }

    func getNote(byId noteId: Int) async throws -> Note? {
        do {
            return try await get("/api/notes/\(noteId)")
        } catch APIError.requestFailed(404) {
            return nil
        }
    }

    func getNoteByConcept(_ concept: String, limit: Int = 50) async throws -> [Note] {
        let encoded = concept.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? concept
        return try await get("/api/notes/by-concept?concept=\(encoded)&limit=\(limit)")
    }

    func getNotesByTheme(_ theme: String, limit: Int = 50) async throws -> [Note] {
        let encoded = theme.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? theme
        return try await get("/api/notes/by-theme?theme=\(encoded)&limit=\(limit)")
    }

    func getNotesByEnergy(_ energy: String, limit: Int = 50) async throws -> [Note] {
        let encoded = energy.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? energy
        return try await get("/api/notes/by-energy?energy=\(encoded)&limit=\(limit)")
    }

    func getNotesByDateRange(from: Date, to: Date) async throws -> [Note] {
        let formatter = ISO8601DateFormatter()
        let fromStr = formatter.string(from: from).addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? ""
        let toStr = formatter.string(from: to).addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? ""
        return try await get("/api/notes/by-date?from=\(fromStr)&to=\(toStr)")
    }

    // MARK: - Chat Sessions

    private struct SessionDTO: Codable {
        let id: String
        let title: String
        let createdAt: String
        let updatedAt: String
        let messages: [Message]
        let isPinned: Bool
        let compressionState: String
        let compressedAt: String?
        let summaryText: String?
    }

    func saveSession(_ session: ChatSession) async throws {
        let formatter = ISO8601DateFormatter()
        let dto = SessionDTO(
            id: session.id.uuidString,
            title: session.title,
            createdAt: formatter.string(from: session.createdAt),
            updatedAt: formatter.string(from: session.updatedAt),
            messages: session.messages,
            isPinned: session.isPinned,
            compressionState: session.compressionState.rawValue,
            compressedAt: session.compressedAt.map { formatter.string(from: $0) },
            summaryText: session.summaryText
        )
        try await post("/api/sessions", body: dto)
    }

    private struct SessionResponse: Codable {
        let id: String
        let title: String
        let createdAt: String
        let updatedAt: String
        let messageCount: Int
        let isPinned: Bool
        let compressionState: String
        let compressedAt: String?
        let messages: [Message]
        let summaryText: String?
    }

    func loadSessions() async throws -> [ChatSession] {
        let responses: [SessionResponse] = try await get("/api/sessions")
        let formatter = ISO8601DateFormatter()

        return responses.compactMap { r in
            guard let id = UUID(uuidString: r.id),
                  let createdAt = formatter.date(from: r.createdAt),
                  let updatedAt = formatter.date(from: r.updatedAt) else {
                return nil
            }

            return ChatSession(
                id: id,
                messages: r.messages,
                createdAt: createdAt,
                updatedAt: updatedAt,
                title: r.title,
                isPinned: r.isPinned,
                compressionState: ChatSession.CompressionState(rawValue: r.compressionState) ?? .full,
                compressedAt: r.compressedAt.flatMap { formatter.date(from: $0) },
                summaryText: r.summaryText
            )
        }
    }

    func deleteSession(_ session: ChatSession) async throws {
        try await delete("/api/sessions/\(session.id.uuidString)")
    }

    func updateSessionPin(sessionId: UUID, isPinned: Bool) async throws {
        try await patch("/api/sessions/\(sessionId.uuidString)/pin", body: ["isPinned": isPinned])
    }

    func compressSession(sessionId: UUID, summary: String) async throws {
        try await post("/api/sessions/\(sessionId.uuidString)/compress", body: ["summary": summary])
    }

    // MARK: - Discussion Threads

    func getPendingThreads() async throws -> [DiscussionThread] {
        try await get("/api/threads")
    }

    func getThread(byId threadId: Int) async throws -> DiscussionThread? {
        do {
            return try await get("/api/threads/\(threadId)")
        } catch APIError.requestFailed(404) {
            return nil
        }
    }

    func updateThreadStatus(_ threadId: Int, status: DiscussionThread.Status) async throws {
        try await patch("/api/threads/\(threadId)/status", body: ["status": status.rawValue])
    }
}
```

**Step 2: Verify it compiles**

```bash
cd SeleneChat
swift build 2>&1 | head -30
```

**Step 3: Commit**

```bash
git add Sources/Services/APIService.swift
git commit -m "feat(selenechat): add APIService for remote server communication"
```

---

### Task 9: Add Server Settings

**Files:**
- Modify: `SeleneChat/Sources/Views/SettingsView.swift`

**Step 1: Add server mode settings**

Add to SettingsView.swift in the appropriate section:

```swift
// Add these @AppStorage properties at the top of the view
@AppStorage("serverMode") private var serverMode: String = "local"
@AppStorage("serverAddress") private var serverAddress: String = ""

// Add this section in the body, after the existing database path section:
Section("Server Mode") {
    Picker("Mode", selection: $serverMode) {
        Text("Local").tag("local")
        Text("Remote Server").tag("remote")
    }
    .pickerStyle(.segmented)

    if serverMode == "remote" {
        TextField("Server Address", text: $serverAddress)
            .textFieldStyle(.roundedBorder)
            .help("IP address or hostname (e.g., 192.168.1.100 or desktop.local)")

        Button("Test Connection") {
            Task {
                await testServerConnection()
            }
        }

        if !connectionTestResult.isEmpty {
            Text(connectionTestResult)
                .foregroundColor(connectionTestSuccess ? .green : .red)
                .font(.caption)
        }
    }
}

// Add these state variables
@State private var connectionTestResult = ""
@State private var connectionTestSuccess = false

// Add this function
private func testServerConnection() async {
    guard !serverAddress.isEmpty else {
        connectionTestResult = "Please enter a server address"
        connectionTestSuccess = false
        return
    }

    let testURL = URL(string: "http://\(serverAddress):5678/health")!

    do {
        let (_, response) = try await URLSession.shared.data(from: testURL)
        if let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 {
            connectionTestResult = "Connected successfully!"
            connectionTestSuccess = true
        } else {
            connectionTestResult = "Server returned error"
            connectionTestSuccess = false
        }
    } catch {
        connectionTestResult = "Connection failed: \(error.localizedDescription)"
        connectionTestSuccess = false
    }
}
```

**Step 2: Verify it compiles**

```bash
cd SeleneChat
swift build 2>&1 | head -20
```

**Step 3: Commit**

```bash
git add Sources/Views/SettingsView.swift
git commit -m "feat(selenechat): add server mode settings UI"
```

---

### Task 10: Make OllamaService URL Configurable

**Files:**
- Modify: `SeleneChat/Sources/Services/OllamaService.swift`

**Step 1: Add configurable baseURL**

Update OllamaService to accept a configurable host:

```swift
// Change from:
private let baseURL = "http://localhost:11434"

// To:
private var baseURL: String

// Add initializer:
init(host: String = "localhost") {
    self.baseURL = "http://\(host):11434"
}

// Update shared instance to read from UserDefaults:
static var shared: OllamaService = {
    let serverMode = UserDefaults.standard.string(forKey: "serverMode") ?? "local"
    let serverAddress = UserDefaults.standard.string(forKey: "serverAddress") ?? "localhost"
    let host = serverMode == "remote" ? serverAddress : "localhost"
    return OllamaService(host: host)
}()

// Add method to reconfigure:
func reconfigure(host: String) {
    self.baseURL = "http://\(host):11434"
    // Clear availability cache
    lastAvailabilityCheck = nil
    cachedAvailability = false
}
```

**Step 2: Commit**

```bash
cd SeleneChat
git add Sources/Services/OllamaService.swift
git commit -m "feat(selenechat): make OllamaService host configurable"
```

---

### Task 11: Wire Up Service Switching in App

**Files:**
- Modify: `SeleneChat/Sources/App/SeleneChatApp.swift`

**Step 1: Add service switching logic**

This task requires examining the current SeleneChatApp structure and adding logic to switch between DatabaseService and APIService based on settings. The exact implementation depends on how services are currently injected.

Key changes:
1. Check `serverMode` UserDefaults at launch
2. If "remote", create APIService with serverAddress
3. If "local", use DatabaseService
4. Pass the appropriate service to views

**Step 2: Commit**

```bash
cd SeleneChat
git add Sources/App/SeleneChatApp.swift
git commit -m "feat(selenechat): add service switching based on server mode"
```

---

## Phase 3: Polish

### Task 12: Configure Ollama for Network Access

**Files:**
- Modify: `launchd/com.selene.ollama.plist` (or create if needed)

**Step 1: Check current Ollama setup**

```bash
launchctl list | grep ollama
ps aux | grep ollama
```

**Step 2: If using launchd, update plist**

Add environment variable:
```xml
<key>EnvironmentVariables</key>
<dict>
    <key>OLLAMA_HOST</key>
    <string>0.0.0.0</string>
</dict>
```

**Step 3: Test from laptop**

```bash
# From laptop, replace IP with desktop IP
curl http://192.168.x.x:11434/api/tags
```

**Step 4: Commit if plist was changed**

```bash
git add launchd/
git commit -m "feat: configure Ollama to listen on all interfaces"
```

---

### Task 13: Add Connection Status Indicator

**Files:**
- Modify: `SeleneChat/Sources/Views/ContentView.swift` (or appropriate main view)

**Step 1: Add status indicator**

Add a small indicator showing connection status when in remote mode:
- Green dot: Connected
- Red dot: Disconnected
- Gray dot: Local mode

**Step 2: Commit**

```bash
cd SeleneChat
git add Sources/Views/
git commit -m "feat(selenechat): add connection status indicator"
```

---

### Task 14: Integration Testing

**Files:** None (testing only)

**Step 1: Start server on desktop**

```bash
npm run start
```

**Step 2: Test from laptop**

1. Open SeleneChat
2. Go to Settings
3. Switch to "Remote Server" mode
4. Enter desktop IP address
5. Click "Test Connection"
6. Verify notes load
7. Send a chat message
8. Verify Ollama responds

**Step 3: Document any issues found**

---

---

## Phase 4: Client Distribution

### Task 15: Build Release App Bundle

**Files:**
- Create: `scripts/build-selenechat.sh`

**Step 1: Create build script**

Create `scripts/build-selenechat.sh`:

```bash
#!/bin/bash
# Build SeleneChat for distribution

set -e

cd "$(dirname "$0")/../SeleneChat"

echo "Building SeleneChat release..."
swift build -c release

# Create app bundle structure
APP_DIR="$HOME/Applications/SeleneChat.app"
CONTENTS_DIR="$APP_DIR/Contents"
MACOS_DIR="$CONTENTS_DIR/MacOS"
RESOURCES_DIR="$CONTENTS_DIR/Resources"

mkdir -p "$MACOS_DIR" "$RESOURCES_DIR"

# Copy binary
cp .build/release/SeleneChat "$MACOS_DIR/"

# Create Info.plist
cat > "$CONTENTS_DIR/Info.plist" << 'PLIST'
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>CFBundleExecutable</key>
    <string>SeleneChat</string>
    <key>CFBundleIdentifier</key>
    <string>com.selene.chat</string>
    <key>CFBundleName</key>
    <string>SeleneChat</string>
    <key>CFBundlePackageType</key>
    <string>APPL</string>
    <key>CFBundleShortVersionString</key>
    <string>1.0</string>
    <key>LSMinimumSystemVersion</key>
    <string>14.0</string>
    <key>NSHighResolutionCapable</key>
    <true/>
</dict>
</plist>
PLIST

# Write version file for update checking
VERSION=$(date +%Y%m%d%H%M%S)
echo "$VERSION" > "$RESOURCES_DIR/version.txt"

echo "SeleneChat.app built at: $APP_DIR"
echo "Version: $VERSION"
```

**Step 2: Make executable**

```bash
chmod +x scripts/build-selenechat.sh
```

**Step 3: Test build**

```bash
./scripts/build-selenechat.sh
```

**Step 4: Commit**

```bash
git add scripts/build-selenechat.sh
git commit -m "feat: add SeleneChat build script"
```

---

### Task 16: Add App Serve Endpoint

**Files:**
- Create: `src/routes/api/app.ts`
- Modify: `src/routes/api/index.ts`

**Step 1: Create app route**

Create `src/routes/api/app.ts`:

```typescript
import { FastifyInstance } from 'fastify';
import { createReadStream, existsSync, statSync, readFileSync } from 'fs';
import { join } from 'path';
import { homedir } from 'os';
import { execSync } from 'child_process';

export async function appRoutes(server: FastifyInstance) {
  const appPath = join(homedir(), 'Applications', 'SeleneChat.app');
  const versionFile = join(appPath, 'Contents', 'Resources', 'version.txt');

  // GET /api/app/version - Get current app version
  server.get('/api/app/version', async (request, reply) => {
    if (!existsSync(versionFile)) {
      return reply.status(404).send({ error: 'App not built' });
    }
    const version = readFileSync(versionFile, 'utf-8').trim();
    return { version };
  });

  // GET /api/app/download - Download app as zip
  server.get('/api/app/download', async (request, reply) => {
    if (!existsSync(appPath)) {
      return reply.status(404).send({ error: 'App not found' });
    }

    // Create temporary zip
    const zipPath = '/tmp/SeleneChat.zip';
    execSync(`cd ~/Applications && zip -r ${zipPath} SeleneChat.app`);

    const stat = statSync(zipPath);
    reply.header('Content-Type', 'application/zip');
    reply.header('Content-Disposition', 'attachment; filename="SeleneChat.zip"');
    reply.header('Content-Length', stat.size);

    return reply.send(createReadStream(zipPath));
  });
}
```

**Step 2: Register route**

Update `src/routes/api/index.ts`:

```typescript
import { appRoutes } from './app';

// Add to apiRoutes function:
await server.register(appRoutes);
```

**Step 3: Test endpoints**

```bash
npm run start &
sleep 2
curl http://localhost:5678/api/app/version
pkill -f "ts-node src/server.ts"
```

**Step 4: Commit**

```bash
git add src/routes/api/app.ts src/routes/api/index.ts
git commit -m "feat(api): add app version and download endpoints"
```

---

### Task 17: Create Client Update Script

**Files:**
- Create: `scripts/update-selenechat-client.sh`

This script runs on the laptop to check for and install updates.

**Step 1: Create update script**

Create `scripts/update-selenechat-client.sh`:

```bash
#!/bin/bash
# Update SeleneChat from remote server
# Run this on the laptop

set -e

# Configuration
SERVER="${SELENE_SERVER:-192.168.1.xxx}"  # Set your desktop IP
APP_DIR="$HOME/Applications/SeleneChat.app"
VERSION_FILE="$APP_DIR/Contents/Resources/version.txt"

# Get local version
LOCAL_VERSION="0"
if [ -f "$VERSION_FILE" ]; then
    LOCAL_VERSION=$(cat "$VERSION_FILE")
fi

# Get remote version
REMOTE_VERSION=$(curl -s "http://$SERVER:5678/api/app/version" | grep -o '"version":"[^"]*"' | cut -d'"' -f4)

if [ -z "$REMOTE_VERSION" ]; then
    echo "Error: Could not get remote version"
    exit 1
fi

echo "Local version:  $LOCAL_VERSION"
echo "Remote version: $REMOTE_VERSION"

if [ "$LOCAL_VERSION" = "$REMOTE_VERSION" ]; then
    echo "Already up to date!"
    exit 0
fi

echo "Downloading update..."

# Download and extract
curl -s "http://$SERVER:5678/api/app/download" -o /tmp/SeleneChat.zip

# Backup current app if exists
if [ -d "$APP_DIR" ]; then
    rm -rf "$APP_DIR.bak"
    mv "$APP_DIR" "$APP_DIR.bak"
fi

# Extract new version
cd ~/Applications
unzip -q -o /tmp/SeleneChat.zip
rm /tmp/SeleneChat.zip

echo "Updated to version $REMOTE_VERSION"
echo "Restart SeleneChat to use the new version"
```

**Step 2: Make executable**

```bash
chmod +x scripts/update-selenechat-client.sh
```

**Step 3: Commit**

```bash
git add scripts/update-selenechat-client.sh
git commit -m "feat: add client update script for laptop"
```

---

### Task 18: Create Laptop launchd Agent for Auto-Updates

**Files:**
- Create: `launchd/client/com.selene.update-check.plist`

This plist is installed on the laptop to periodically check for updates.

**Step 1: Create plist**

Create `launchd/client/com.selene.update-check.plist`:

```xml
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>Label</key>
    <string>com.selene.update-check</string>
    <key>ProgramArguments</key>
    <array>
        <string>/bin/bash</string>
        <string>-c</string>
        <string>$HOME/selene-n8n/scripts/update-selenechat-client.sh >> /tmp/selenechat-update.log 2>&1</string>
    </array>
    <key>EnvironmentVariables</key>
    <dict>
        <key>SELENE_SERVER</key>
        <string>192.168.1.xxx</string>
    </dict>
    <key>StartInterval</key>
    <integer>3600</integer>
    <key>RunAtLoad</key>
    <true/>
    <key>StandardOutPath</key>
    <string>/tmp/selenechat-update.log</string>
    <key>StandardErrorPath</key>
    <string>/tmp/selenechat-update.log</string>
</dict>
</plist>
```

**Step 2: Create client install script**

Create `scripts/install-client.sh`:

```bash
#!/bin/bash
# Install SeleneChat client on laptop
# Run this once on the laptop

set -e

if [ -z "$1" ]; then
    echo "Usage: $0 <server-ip>"
    echo "Example: $0 192.168.1.100"
    exit 1
fi

SERVER_IP="$1"
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"

echo "Installing SeleneChat client..."
echo "Server: $SERVER_IP"

# Update plist with correct server IP
PLIST_SRC="$SCRIPT_DIR/../launchd/client/com.selene.update-check.plist"
PLIST_DST="$HOME/Library/LaunchAgents/com.selene.update-check.plist"

mkdir -p "$HOME/Library/LaunchAgents"

# Copy and customize plist
sed "s/192.168.1.xxx/$SERVER_IP/g" "$PLIST_SRC" > "$PLIST_DST"

# Set the correct path to the update script
sed -i '' "s|\$HOME/selene-n8n/scripts|$SCRIPT_DIR|g" "$PLIST_DST"

# Load the agent
launchctl unload "$PLIST_DST" 2>/dev/null || true
launchctl load "$PLIST_DST"

# Run initial update
export SELENE_SERVER="$SERVER_IP"
"$SCRIPT_DIR/update-selenechat-client.sh"

echo ""
echo "Installation complete!"
echo "SeleneChat will check for updates every hour."
echo "App installed at: ~/Applications/SeleneChat.app"
```

**Step 3: Make executable**

```bash
chmod +x scripts/install-client.sh
```

**Step 4: Commit**

```bash
git add launchd/client/ scripts/install-client.sh
git commit -m "feat: add automatic client update system for laptop"
```

---

### Task 19: Document Client Setup

**Files:**
- Create: `docs/CLIENT-SETUP.md`

**Step 1: Create documentation**

Create `docs/CLIENT-SETUP.md`:

```markdown
# SeleneChat Client Setup (Laptop)

## Prerequisites

- macOS 14.0 or later
- Network access to your desktop

## Installation

### 1. Clone the repository

```bash
git clone <repo-url> ~/selene-n8n
cd ~/selene-n8n
```

### 2. Run the install script

```bash
./scripts/install-client.sh 192.168.1.xxx
```

Replace `192.168.1.xxx` with your desktop's IP address.

### 3. Configure SeleneChat

1. Open SeleneChat from ~/Applications
2. Go to Settings (Cmd+,)
3. Set Mode to "Remote Server"
4. Enter your desktop's IP address
5. Click "Test Connection"

## How Updates Work

- The laptop checks for updates every hour
- If a new version is found, it downloads and installs automatically
- You'll need to restart SeleneChat to use the new version
- Update logs: `/tmp/selenechat-update.log`

## Manual Update

```bash
SELENE_SERVER=192.168.1.xxx ~/selene-n8n/scripts/update-selenechat-client.sh
```

## Troubleshooting

### Connection Failed

1. Verify desktop IP: `ping 192.168.1.xxx`
2. Verify server running: `curl http://192.168.1.xxx:5678/health`
3. Check firewall settings on desktop

### Update Not Working

1. Check logs: `cat /tmp/selenechat-update.log`
2. Verify launchd agent: `launchctl list | grep selene`
3. Test manually: `SELENE_SERVER=xxx ./scripts/update-selenechat-client.sh`
```

**Step 2: Commit**

```bash
git add docs/CLIENT-SETUP.md
git commit -m "docs: add client setup guide for laptop installation"
```

---

## Summary

| Phase | Tasks | Description |
|-------|-------|-------------|
| 1 | 1-5 | Server API endpoints |
| 2 | 6-11 | SeleneChat remote mode |
| 3 | 12-14 | Polish and testing |
| 4 | 15-19 | Client distribution and auto-updates |

Total: 19 tasks
