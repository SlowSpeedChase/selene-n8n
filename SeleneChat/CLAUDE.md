# SeleneChat macOS App Context

## Purpose

Native macOS app for querying and exploring notes stored in Selene SQLite database. Provides conversational interface with Ollama LLM and clickable citations for source notes. ADHD-optimized for quick note retrieval and visual knowledge exploration.

## Tech Stack

- **Swift** 5.9+ (SwiftUI framework)
- **SQLite.swift** - Swift wrapper for SQLite database
- **Ollama** - Local LLM integration (mistral:7b)
- **Swift Package Manager** - Dependency management
- **XCTest** - Testing framework

## Key Files

- Package.swift - Swift package manifest with dependencies
- Sources/App/SeleneChatApp.swift - App entry point
- Sources/App/ContentView.swift - Main UI container
- Sources/Models/ - Data models (Note, ChatMessage, Citation)
- Sources/Services/ - Business logic (DatabaseService, SearchService, OllamaService)
- Sources/Views/ - UI components (ChatView, CitationView, etc.)
- Tests/ - Unit and integration tests
- Sources/Debug/ - Debug logging and snapshot system (DEBUG builds only)

## Architecture

### MVVM Pattern
```
Views (SwiftUI)
  ↓
ViewModels (@Published state)
  ↓
Services (Business logic)
  ↓
Models (Data structures)
  ↓
SQLite Database
```

### Key Services
- **DatabaseService** - SQLite connection and queries
- **SearchService** - Note search with relevance ranking
- **OllamaService** - LLM communication and response parsing
- **CitationService** - Extract and link source notes

## Data Flow

1. **User Types Query** - ChatView captures input
2. **Search Notes** - SearchService finds relevant notes
3. **Generate Context** - Combine query + retrieved notes
4. **Call Ollama** - OllamaService sends prompt with context
5. **Parse Response** - Extract answer + citation markers [1], [2]
6. **Display with Citations** - ChatView shows answer with clickable citations
7. **Navigate to Source** - Click citation → DetailView shows full note

## Common Patterns

### SwiftUI View Structure
```swift
struct ChatView: View {
    @StateObject private var viewModel = ChatViewModel()

    var body: some View {
        VStack {
            messagesList
            inputArea
        }
        .onAppear { viewModel.loadInitialData() }
    }
}
```

### Async/Await for LLM Calls
```swift
func sendQuery(_ query: String) async {
    do {
        let response = try await ollamaService.generateResponse(
            query: query,
            context: relevantNotes
        )
        await MainActor.run {
            messages.append(response)
        }
    } catch {
        // Handle error
    }
}
```

### Database Queries with SQLite.swift
```swift
import SQLite

let db = try Connection(dbPath)
let notesTable = Table("raw_notes")
let id = Expression<Int64>("id")
let content = Expression<String>("content")

let results = try db.prepare(
    notesTable.filter(content.like("%\(query)%"))
).map { Note(from: $0) }
```

## Testing

### Run Tests
```bash
cd SeleneChat
swift test
```

### Test Coverage Areas
- DatabaseService - CRUD operations
- SearchService - Relevance ranking
- OllamaService - LLM integration
- Citation parsing - Extract [1], [2] markers
- View models - State management

## ADHD-Optimized Features

### Visual Design
- **Clean interface** - Minimal distractions
- **Clear hierarchy** - Chat > Citations > Details
- **Color coding** - User vs. AI messages distinct

### Cognitive Load Reduction
- **Instant search** - No loading delays
- **Clickable citations** - Direct source access
- **Session summaries** - Review conversation context
- **Keyboard shortcuts** - Fast navigation

### Context Preservation
- **Chat history** - Review previous queries
- **Citation links** - Always traceable to source
- **Related notes** - Discover connections

## Do NOT

- **NEVER block main thread** - Use async/await for I/O
- **NEVER force-unwrap optionals** - Use guard/if let
- **NEVER expose database connection** - Encapsulate in Service
- **NEVER hardcode database path** - Use environment or config
- **NEVER skip error handling** - All service calls can fail

## Build and Run

### Auto-Build on Commit (Recommended)
Commits that touch SeleneChat files automatically trigger a rebuild and install to `/Applications/SeleneChat.app` via the `post-commit` git hook. A macOS notification confirms success/failure.

This is the standard workflow - just commit your changes and the production app updates automatically.

### Manual Build & Install
```bash
cd SeleneChat
./build-app.sh                              # Build .app bundle
cp -R .build/release/SeleneChat.app /Applications/  # Install
```

### Development (CLI - uses test database)
```bash
cd SeleneChat
swift build
swift run
```
Note: CLI builds use `~/selene-n8n/data-test/selene-test.db`, not production data.

### Release (CLI)
```bash
swift build -c release
.build/release/SeleneChat
```

### Xcode
```bash
swift package generate-xcodeproj
open SeleneChat.xcodeproj
```

### Database Selection
- **CLI binary** → test database (`~/selene-n8n/data-test/selene-test.db`)
- **.app bundle** → production database (`~/selene-data/selene.db`)

Detection is automatic via `isRunningFromAppBundle()` in DatabaseService.

## Related Context

@SeleneChat/README.md
@SeleneChat/Sources/Services/CLAUDE.md
@SeleneChat/Sources/Views/CLAUDE.md
@database/schema.sql
@README.md
