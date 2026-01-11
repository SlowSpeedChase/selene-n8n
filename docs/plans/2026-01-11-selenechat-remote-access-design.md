# SeleneChat Remote Access Design

**Status:** Draft
**Created:** 2026-01-11
**Author:** Claude + Chase

## Problem

SeleneChat currently only works on the desktop where the SQLite database and Ollama are running. The user wants to run SeleneChat on a laptop anywhere in the house, with the desktop acting as the server.

## Solution

Convert the desktop into a server that exposes:
1. REST API for database operations (via Fastify on port 5678)
2. Ollama LLM API (port 11434)

SeleneChat gains a "Remote Mode" that connects to these APIs instead of accessing local files.

## Architecture

```
MacBook (Client)                    Desktop (Server)
┌──────────────────┐               ┌──────────────────────┐
│ SeleneChat       │───HTTP:5678──→│ Fastify API          │
│                  │               │     ↓                │
│ - APIService     │               │ SQLite (selene.db)   │
│ - OllamaService  │───HTTP:11434─→│                      │
│                  │               │ Ollama (mistral:7b)  │
└──────────────────┘               └──────────────────────┘
```

## API Endpoints

### Notes (read-only)

| Method | Endpoint | Description |
|--------|----------|-------------|
| GET | `/api/notes` | List recent notes. Query params: `limit` |
| GET | `/api/notes/:id` | Get single note by ID |
| GET | `/api/notes/search` | Full-text search. Query params: `q`, `limit` |
| GET | `/api/notes/by-concept` | Filter by concept. Query params: `concept`, `limit` |
| GET | `/api/notes/by-theme` | Filter by theme. Query params: `theme`, `limit` |
| GET | `/api/notes/by-energy` | Filter by energy level. Query params: `energy`, `limit` |
| GET | `/api/notes/by-date` | Date range filter. Query params: `from`, `to` |

### Chat Sessions (read/write)

| Method | Endpoint | Description |
|--------|----------|-------------|
| GET | `/api/sessions` | List all chat sessions |
| POST | `/api/sessions` | Create or update session |
| DELETE | `/api/sessions/:id` | Delete session |
| PATCH | `/api/sessions/:id/pin` | Toggle pin status. Body: `{ "isPinned": bool }` |
| POST | `/api/sessions/:id/compress` | Compress old session. Body: `{ "summary": string }` |

### Discussion Threads (read/write)

| Method | Endpoint | Description |
|--------|----------|-------------|
| GET | `/api/threads` | List pending/active/review threads |
| GET | `/api/threads/:id` | Get single thread by ID |
| PATCH | `/api/threads/:id/status` | Update status. Body: `{ "status": string }` |

## Server Changes

### Fastify Binding

Update `src/server.ts` to bind to all interfaces:

```typescript
await server.listen({ port: 5678, host: '0.0.0.0' })
```

### New Route Files

Create `src/routes/api/` with:
- `notes.ts` - Note query endpoints
- `sessions.ts` - Chat session CRUD
- `threads.ts` - Discussion thread operations

### Ollama Network Access

Update Ollama launchd plist or startup to bind to network:

```bash
OLLAMA_HOST=0.0.0.0 ollama serve
```

## SeleneChat Changes

### New Files

**`Sources/Services/APIService.swift`**
- HTTP client for all database operations
- Conforms to `DataServiceProtocol`
- Uses async/await with URLSession

**`Sources/Services/DataServiceProtocol.swift`**
- Protocol defining all data operations
- Both `DatabaseService` and `APIService` conform to it

### Modified Files

**`Sources/Services/DatabaseService.swift`**
- Add conformance to `DataServiceProtocol`
- No logic changes, just protocol adoption

**`Sources/Services/OllamaService.swift`**
- Make `baseURL` configurable instead of hardcoded `localhost`
- Read from UserDefaults or passed configuration

**`Sources/Views/SettingsView.swift`**
- Add "Server Mode" section:
  - Toggle: Local / Remote
  - Text field: Server Address
  - Button: Test Connection

**`Sources/App/SeleneChatApp.swift`**
- Check settings at launch
- Instantiate correct service (DatabaseService or APIService)
- Pass server address to OllamaService if remote

### Service Protocol

```swift
protocol DataServiceProtocol {
    func getAllNotes(limit: Int) async throws -> [Note]
    func searchNotes(query: String, limit: Int) async throws -> [Note]
    func getNote(byId: Int) async throws -> Note?
    func getNoteByConcept(_ concept: String, limit: Int) async throws -> [Note]
    func getNotesByTheme(_ theme: String, limit: Int) async throws -> [Note]
    func getNotesByEnergy(_ energy: String, limit: Int) async throws -> [Note]
    func getNotesByDateRange(from: Date, to: Date) async throws -> [Note]

    func saveSession(_ session: ChatSession) async throws
    func loadSessions() async throws -> [ChatSession]
    func deleteSession(_ session: ChatSession) async throws
    func updateSessionPin(sessionId: UUID, isPinned: Bool) async throws
    func compressSession(sessionId: UUID, summary: String) async throws

    func getPendingThreads() async throws -> [DiscussionThread]
    func getThread(byId: Int) async throws -> DiscussionThread?
    func updateThreadStatus(_ threadId: Int, status: DiscussionThread.Status) async throws
}
```

## Network Configuration

### Server (Desktop)

1. Fastify binds to `0.0.0.0:5678`
2. Ollama binds to `0.0.0.0:11434`
3. No authentication (trusted home network)

### Client (Laptop)

Configure server address in Settings:
- IP address: `192.168.1.xxx`
- Or hostname: `chases-desktop.local`

## Implementation Phases

### Phase 1: Server API
- Add REST endpoints to Fastify
- Bind to `0.0.0.0`
- Test with curl from laptop
- Existing SeleneChat unchanged

### Phase 2: SeleneChat Remote Mode
- Create `APIService.swift`
- Create `DataServiceProtocol`
- Add server settings UI
- Make OllamaService URL configurable
- Test local/remote switching

### Phase 3: Polish
- Connection status indicator
- Graceful offline handling
- Ollama launchd plist update
- Optional: Bonjour auto-discovery

## Security Considerations

- No authentication - relies on home network security
- Both services bound to 0.0.0.0 (all interfaces)
- If network security is a concern later, can add API key header

## Testing Strategy

### Server Testing
```bash
# From laptop, test notes endpoint
curl http://192.168.1.xxx:5678/api/notes?limit=5

# Test search
curl "http://192.168.1.xxx:5678/api/notes/search?q=docker"

# Test Ollama
curl http://192.168.1.xxx:11434/api/tags
```

### SeleneChat Testing
1. Start in Local mode, verify existing functionality
2. Switch to Remote mode with valid server
3. Verify all features work (search, chat, threads)
4. Test with server unavailable (graceful error handling)

## Open Questions

None at this time.

## Related Documents

- `docs/plans/2026-01-04-selene-thread-system-design.md`
- `SeleneChat/Sources/Services/CLAUDE.md`
