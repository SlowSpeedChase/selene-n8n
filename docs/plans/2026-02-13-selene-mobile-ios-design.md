# Selene Mobile (iOS) Design

**Status:** Ready
**Created:** 2026-02-13
**Updated:** 2026-02-13

---

## Problem

SeleneChat only runs on macOS. When away from the Mac, there's no way to query notes, review threads, check the morning briefing, or chat with Selene. For an ADHD-focused system, mobile access is critical — thoughts don't wait until you're at your desk.

---

## Solution

Native iOS app (SeleneMobile) that provides full feature parity with SeleneChat, communicating with the Mac over Tailscale VPN. The existing Fastify server gets expanded with REST endpoints. Shared Swift code (models, view models, services) lives in a common library used by both platforms.

**Key decisions:**
- **Native iOS** (not web/PWA) — best UX, push notifications, live activities, widgets
- **Expand Fastify server** (not new Swift server) — leverages existing infrastructure
- **Protocol-based data layer** — `DataProvider`/`LLMProvider` protocols with local (macOS) and remote (iOS) implementations
- **Same SPM package** — three targets: SeleneShared, SeleneChat, SeleneMobile
- **Proxy Ollama through Fastify** — single network endpoint for iPhone

---

## Design

### Architecture

```
┌─────────────────────────────────────────────────┐
│          SeleneShared (Swift library)            │
│  Models, ChatViewModel, QueryAnalyzer,          │
│  ContextBuilder, BriefingGenerator,             │
│  MemoryService, CompressionService,             │
│  ActionExtractor, prompt builders               │
├────────────────────┬────────────────────────────┤
│ SeleneChat (macOS) │ SeleneMobile (iOS)         │
│ DatabaseService    │ RemoteDataService          │
│ (direct SQLite)    │ (HTTP → Fastify → SQLite)  │
│ OllamaService      │ RemoteOllamaService        │
│ (localhost:11434)  │ (HTTP → Fastify → Ollama)  │
│ WorkflowScheduler  │ Push notifications         │
│ CrystalStatusItem  │ Live Activities            │
│ macOS views        │ iOS views + tab nav        │
└────────────────────┴────────────────────────────┘
                          │
                    Tailscale VPN
                          │
              ┌───────────┴───────────┐
              │ Fastify Server :5678  │
              │ Existing endpoints +  │
              │ ~30 new REST APIs +   │
              │ Ollama proxy +        │
              │ APNs push delivery    │
              └───────────────────────┘
```

### Protocol Layer

```swift
protocol DataProvider {
    // Notes
    func getAllNotes(limit: Int) async throws -> [Note]
    func getNote(byId id: Int) async throws -> Note?
    func searchNotes(query: String, limit: Int) async throws -> [Note]
    func searchNotesSemantically(query: String, limit: Int) async -> [Note]
    func getRecentNotes(days: Int, limit: Int) async throws -> [Note]
    func getNotesSince(_ date: Date, limit: Int) async throws -> [Note]
    func getRelatedNotes(for noteId: Int, limit: Int) async -> [(note: Note, relationshipType: String, strength: Double?)]
    func retrieveNotesFor(queryType: QueryAnalyzer.QueryType, keywords: [String], timeScope: QueryAnalyzer.TimeScope, limit: Int) async throws -> [Note]

    // Threads
    func getActiveThreads(limit: Int) async throws -> [Thread]
    func getThreadById(_ id: Int64) async throws -> Thread?
    func getThreadByName(_ name: String) async throws -> (Thread, [Note])?
    func getTasksForThread(_ threadId: Int64) async throws -> [ThreadTask]
    func getThreadAssignmentsForNotes(_ noteIds: [Int]) async throws -> [Int: (threadName: String, threadId: Int64)]

    // Sessions
    func loadSessions() async throws -> [ChatSession]
    func saveSession(_ session: ChatSession) async throws
    func deleteSession(_ session: ChatSession) async throws
    func updateSessionPin(sessionId: UUID, isPinned: Bool) async throws
    func saveConversationMessage(sessionId: UUID, role: String, content: String) async throws
    func getRecentMessages(sessionId: UUID, limit: Int) async throws -> [(role: String, content: String, createdAt: Date)]

    // Memories
    func getAllMemories(limit: Int) async throws -> [ConversationMemory]
    func insertMemory(content: String, type: ConversationMemory.MemoryType, confidence: Double, sourceSessionId: UUID?, embedding: [Float]?) async throws -> Int64
    func updateMemory(id: Int64, content: String, confidence: Double?, embedding: [Float]?) async throws
    func deleteMemory(id: Int64) async throws
    func touchMemories(ids: [Int64]) async throws

    // Briefing context
    func getCrossThreadAssociations(minSimilarity: Double, recentDays: Int, limit: Int) async throws -> [(noteAId: Int, noteBId: Int, similarity: Double)]
}

protocol LLMProvider {
    func generate(prompt: String, model: String?) async throws -> String
    func embed(text: String) async throws -> [Float]
    func isAvailable() async -> Bool
}
```

- `DatabaseService` (macOS) implements `DataProvider` with direct SQLite
- `RemoteDataService` (iOS) implements `DataProvider` with HTTP calls to Fastify
- `OllamaService` (macOS) implements `LLMProvider` with localhost:11434
- `RemoteOllamaService` (iOS) implements `LLMProvider` via Fastify proxy

### Fastify API Endpoints

All endpoints require `Authorization: Bearer <token>` header.

**Notes:**
| Endpoint | Method | Purpose |
|----------|--------|---------|
| `/api/notes` | GET | List notes (query: limit) |
| `/api/notes/:id` | GET | Single note by ID |
| `/api/notes/search` | POST | Full-text search (body: query, limit) |
| `/api/notes/recent` | GET | Recent notes (query: days, limit) |
| `/api/notes/since/:date` | GET | Notes since timestamp |
| `/api/notes/retrieve` | POST | Hybrid retrieval (body: queryType, keywords, timeScope, limit) |
| `/api/notes/:id/related` | GET | Related notes (query: limit) |
| `/api/notes/thread-assignments` | POST | Thread assignments for note IDs (body: noteIds) |

**Threads:**
| Endpoint | Method | Purpose |
|----------|--------|---------|
| `/api/threads` | GET | Active threads (query: limit) |
| `/api/threads/:id` | GET | Thread by ID |
| `/api/threads/search/:name` | GET | Fuzzy search thread by name |
| `/api/threads/:id/tasks` | GET | Tasks for thread |

**Sessions:**
| Endpoint | Method | Purpose |
|----------|--------|---------|
| `/api/sessions` | GET | All sessions |
| `/api/sessions/:id` | PUT | Save/update session |
| `/api/sessions/:id` | DELETE | Delete session |
| `/api/sessions/:id/pin` | PATCH | Toggle pin (body: isPinned) |
| `/api/sessions/:id/messages` | GET | Session messages (query: limit) |
| `/api/sessions/:id/messages` | POST | Save message (body: role, content) |

**Memories:**
| Endpoint | Method | Purpose |
|----------|--------|---------|
| `/api/memories` | GET | All memories (query: limit) |
| `/api/memories` | POST | Create memory |
| `/api/memories/:id` | PUT | Update memory |
| `/api/memories/:id` | DELETE | Delete memory |
| `/api/memories/touch` | POST | Touch memories (body: ids) |

**Briefing:**
| Endpoint | Method | Purpose |
|----------|--------|---------|
| `/api/briefing/associations` | GET | Cross-thread associations (query: minSimilarity, recentDays, limit) |

**LLM Proxy:**
| Endpoint | Method | Purpose |
|----------|--------|---------|
| `/api/llm/generate` | POST | Proxy to Ollama generate (body: prompt, model) |
| `/api/llm/embed` | POST | Proxy to Ollama embeddings (body: text) |
| `/api/llm/health` | GET | Check Ollama availability |

**Push Notifications:**
| Endpoint | Method | Purpose |
|----------|--------|---------|
| `/api/devices/register` | POST | Register APNs device token |
| `/api/devices/unregister` | POST | Remove device token |

### iOS View Structure

Tab-based navigation:

```
┌─────────────────────────────────────┐
│           SeleneMobile              │
├─────────────────────────────────────┤
│                                     │
│  [Active Tab Content]               │
│                                     │
├─────┬───────┬──────────┬────────────┤
│ Chat│Threads│ Briefing │   More     │
└─────┴───────┴──────────┴────────────┘
```

**Chat Tab:** Full chat interface with voice input, session history in sidebar (sheet on iPhone), citations with tap-to-expand.

**Threads Tab:** Active threads list sorted by momentum. Tap for thread detail: summary, linked notes, deep-dive chat, Things tasks.

**Briefing Tab:** Morning briefing cards. Deep context chat for follow-up questions. Same BriefingGenerator, different layout.

**More Tab:** Settings (server URL, auth token stored in Keychain), memories list, planning/inbox, note capture (text input → POST to webhook).

### Push Notifications

Server-side APNs integration using `@parse/node-apn` or direct HTTP/2 to APNs.

**Notification triggers (added to existing workflows):**
- `daily-summary.ts` → "Your morning briefing is ready"
- `detect-threads.ts` → "New thread detected: {name}" (when new thread created)
- `reconsolidate-threads.ts` → "Thread '{name}' is heating up" (momentum spike)
- `compute-relationships.ts` → "New connection found between your notes" (high-similarity new pair)

**Device token storage:** New `device_tokens` SQLite table:
```sql
CREATE TABLE device_tokens (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    token TEXT NOT NULL UNIQUE,
    platform TEXT NOT NULL DEFAULT 'ios',
    created_at TEXT NOT NULL DEFAULT (datetime('now')),
    last_seen_at TEXT NOT NULL DEFAULT (datetime('now'))
);
```

### Live Activities

Using ActivityKit for Dynamic Island and Lock Screen presence.

**Chat Processing Activity:**
```swift
struct SeleneChatActivity: ActivityAttributes {
    struct ContentState: Codable, Hashable {
        var status: String  // "searching notes", "thinking", "generating"
        var progress: Double  // 0.0 to 1.0
    }
    var queryPreview: String  // Truncated query text
}
```
Started when chat request sent, updated during processing stages, ended when response received.

**Briefing Activity:**
```swift
struct SeleneBriefingActivity: ActivityAttributes {
    struct ContentState: Codable, Hashable {
        var status: String  // "building", "ready"
        var cardCount: Int
    }
    var date: Date
}
```
Push-to-start via APNs when daily-summary workflow begins. Updated when complete.

### Security

- **Network:** Tailscale VPN (WireGuard encryption, device authentication)
- **API Auth:** Bearer token in `Authorization` header. Token set in server `.env` (`SELENE_API_TOKEN`), stored in iOS Keychain
- **ATS Exception:** Tailscale IPs (100.x.x.x) use HTTP, needs Info.plist exception for that subnet
- **No local data cache initially** — all data fetched on demand. Offline mode is a future enhancement.

### Package.swift Changes

```swift
let package = Package(
    name: "SeleneChat",
    platforms: [
        .macOS(.v14),
        .iOS(.v17)
    ],
    products: [
        .executable(name: "SeleneChat", targets: ["SeleneChat"]),
        .executable(name: "SeleneMobile", targets: ["SeleneMobile"]),
        .library(name: "SeleneShared", targets: ["SeleneShared"]),
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
            resources: [.process("Resources")]
        ),
        .executableTarget(
            name: "SeleneMobile",
            dependencies: ["SeleneShared"],
            path: "Sources/SeleneMobile"
        ),
        .testTarget(
            name: "SeleneChatTests",
            dependencies: ["SeleneChat", "SeleneShared"],
            path: "Tests"
        ),
    ]
)
```

Note: SQLite.swift is only a dependency of the macOS target. The iOS target doesn't need it — all data access goes through HTTP.

---

## Implementation Notes

### Phase 1: Server API (TypeScript)
- Add bearer token auth middleware to Fastify
- Implement all REST endpoints (notes, threads, sessions, memories, briefing, LLM proxy)
- Add APNs push notification support
- Update existing workflows to trigger notifications
- Add `device_tokens` table

### Phase 2: Swift Refactor
- Extract `SeleneShared` library target
- Define `DataProvider` and `LLMProvider` protocols
- Refactor `DatabaseService` to implement `DataProvider`
- Refactor `OllamaService` to implement `LLMProvider`
- Update `ChatViewModel` and all services to use protocols
- Ensure macOS app still works identically

### Phase 3: iOS App
- Create `SeleneMobile` target
- Implement `RemoteDataService` (HTTP → Fastify)
- Implement `RemoteOllamaService` (HTTP → Fastify → Ollama)
- Build iOS views: TabRootView, MobileChatView, MobileThreadView, MobileBriefingView, SettingsView
- Voice input using iOS SFSpeechRecognizer
- Server URL + auth token configuration with Keychain storage

### Phase 4: Notifications & Live Activities
- APNs certificate setup and server integration
- Device token registration flow
- Notification triggers in workflows
- Live Activity for chat processing
- Live Activity for briefing

### Dependencies
- Apple Developer account (for APNs + iOS development)
- Tailscale on both devices (already configured)
- Xcode for iOS simulator testing and device deployment

### Affected Files
- `src/server.ts` — New endpoints + auth middleware
- `src/lib/config.ts` — New config vars (API token, APNs)
- `SeleneChat/Package.swift` — Three-target restructure
- `SeleneChat/Sources/**` — Major restructure into SeleneShared + platform targets
- New: `src/lib/auth.ts`, `src/lib/apns.ts`, `src/routes/*.ts`
- New: `Sources/SeleneShared/`, `Sources/SeleneMobile/`

---

## Ready for Implementation Checklist

- [x] **Acceptance criteria defined** - See below
- [x] **ADHD check passed** - See below
- [ ] **Scope check** - Large project (~3-4 weeks). Should be broken into phases.
- [x] **No blockers** - Tailscale configured, Apple dev account available

### Acceptance Criteria

- [ ] Fastify server has all REST endpoints with bearer token auth
- [ ] Ollama proxy endpoint works (send prompt, get response)
- [ ] Swift code split into SeleneShared + SeleneChat + SeleneMobile targets
- [ ] macOS app works identically after refactor (no regression)
- [ ] iOS app connects to server over Tailscale IP
- [ ] Chat works on iPhone (send message, get AI response with citations)
- [ ] Thread list displays on iPhone with momentum scores
- [ ] Morning briefing displays on iPhone
- [ ] Voice input works on iPhone
- [ ] Push notifications delivered for briefing and thread activity
- [ ] Live activity shows during chat processing
- [ ] Auth token stored in Keychain, server URL configurable

### ADHD Design Check

- [x] **Reduces friction?** Access Selene from pocket — no need to be at desk. Capture thoughts anywhere.
- [x] **Visible?** Push notifications surface insights proactively. Live activities keep context visible.
- [x] **Externalizes cognition?** Full note access + chat from anywhere = always-available external memory.

---

## Links

- **Supersedes:** selenechat-remote-access-design.md (Vision, laptop access — this is broader)
- **Branch:** (added when implementation starts)
- **PR:** (added when complete)
