# SeleneChat Vector Search Integration - Implementation Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** Integrate SeleneChat with the Selene backend's vector search API endpoints for semantic search and related notes discovery.

**Architecture:** Add a new `SeleneAPIService` actor for HTTP calls to the backend. Modify `DatabaseService` to try API first with SQLite fallback. Add `RelatedNotesView` component. Update `QueryAnalyzer` to detect semantic queries.

**Tech Stack:** Swift, SwiftUI, URLSession, async/await, Codable

---

## Task 1: Create SeleneAPIService

Add HTTP client for communicating with the Selene backend (`localhost:5678`).

**Files:**
- Create: `SeleneChat/Sources/Services/SeleneAPIService.swift`

### Step 1.1: Create the service file with error types

```swift
// SeleneChat/Sources/Services/SeleneAPIService.swift

import Foundation

/// HTTP client for Selene backend API endpoints
actor SeleneAPIService {
    static let shared = SeleneAPIService()

    private let baseURL = "http://localhost:5678"
    private let session = URLSession.shared
    private var lastHealthCheck: Date?
    private var isHealthy: Bool = false
    private let healthCacheSeconds: TimeInterval = 60

    private init() {}

    // MARK: - Error Types

    enum APIError: Error, LocalizedError {
        case serverUnavailable
        case invalidResponse
        case decodingFailed(String)
        case requestFailed(Int, String)

        var errorDescription: String? {
            switch self {
            case .serverUnavailable:
                return "Selene server is not available"
            case .invalidResponse:
                return "Invalid response from server"
            case .decodingFailed(let message):
                return "Failed to decode response: \(message)"
            case .requestFailed(let status, let message):
                return "Request failed (\(status)): \(message)"
            }
        }
    }
}
```

### Step 1.2: Add request/response models

Add these inside `SeleneAPIService.swift` after the error types:

```swift
    // MARK: - Request/Response Models

    struct SearchRequest: Encodable {
        let query: String
        let limit: Int
        let noteType: String?
        let actionability: String?

        init(query: String, limit: Int = 10, noteType: String? = nil, actionability: String? = nil) {
            self.query = query
            self.limit = limit
            self.noteType = noteType
            self.actionability = actionability
        }
    }

    struct SearchResponse: Decodable {
        let query: String
        let count: Int
        let results: [SearchResult]
    }

    struct SearchResult: Decodable {
        let id: Int
        let title: String
        let primaryTheme: String?
        let noteType: String?
        let distance: Double

        enum CodingKeys: String, CodingKey {
            case id, title, distance
            case primaryTheme = "primary_theme"
            case noteType = "note_type"
        }
    }

    struct RelatedNotesRequest: Encodable {
        let noteId: Int
        let limit: Int
        let includeLive: Bool

        init(noteId: Int, limit: Int = 10, includeLive: Bool = true) {
            self.noteId = noteId
            self.limit = limit
            self.includeLive = includeLive
        }
    }

    struct RelatedNotesResponse: Decodable {
        let noteId: Int
        let count: Int
        let results: [RelatedNoteResult]
    }

    struct RelatedNoteResult: Decodable {
        let id: Int
        let title: String
        let relationshipType: String
        let strength: Double?
        let source: String

        enum CodingKeys: String, CodingKey {
            case id, title, strength, source
            case relationshipType = "relationship_type"
        }
    }
```

### Step 1.3: Add health check method

Add after the models:

```swift
    // MARK: - Health Check

    /// Check if the Selene server is available (cached for 60s)
    func isAvailable() async -> Bool {
        // Return cached result if recent
        if let lastCheck = lastHealthCheck,
           Date().timeIntervalSince(lastCheck) < healthCacheSeconds {
            return isHealthy
        }

        guard let url = URL(string: "\(baseURL)/health") else {
            return false
        }

        do {
            var request = URLRequest(url: url)
            request.timeoutInterval = 2.0  // Quick timeout for health check

            let (_, response) = try await session.data(for: request)

            if let httpResponse = response as? HTTPURLResponse {
                isHealthy = httpResponse.statusCode == 200
            } else {
                isHealthy = false
            }
        } catch {
            isHealthy = false
        }

        lastHealthCheck = Date()
        return isHealthy
    }
```

### Step 1.4: Add semantic search method

```swift
    // MARK: - API Methods

    /// Search notes semantically by query text
    func searchNotes(query: String, limit: Int = 10, noteType: String? = nil, actionability: String? = nil) async throws -> [SearchResult] {
        guard await isAvailable() else {
            throw APIError.serverUnavailable
        }

        guard let url = URL(string: "\(baseURL)/api/search") else {
            throw APIError.invalidResponse
        }

        let requestBody = SearchRequest(
            query: query,
            limit: limit,
            noteType: noteType,
            actionability: actionability
        )

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try JSONEncoder().encode(requestBody)

        let (data, response) = try await session.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw APIError.invalidResponse
        }

        guard httpResponse.statusCode == 200 else {
            let message = String(data: data, encoding: .utf8) ?? "Unknown error"
            throw APIError.requestFailed(httpResponse.statusCode, message)
        }

        do {
            let searchResponse = try JSONDecoder().decode(SearchResponse.self, from: data)
            return searchResponse.results
        } catch {
            throw APIError.decodingFailed(error.localizedDescription)
        }
    }
```

### Step 1.5: Add related notes method

```swift
    /// Get notes related to a specific note
    func getRelatedNotes(noteId: Int, limit: Int = 10, includeLive: Bool = true) async throws -> [RelatedNoteResult] {
        guard await isAvailable() else {
            throw APIError.serverUnavailable
        }

        guard let url = URL(string: "\(baseURL)/api/related-notes") else {
            throw APIError.invalidResponse
        }

        let requestBody = RelatedNotesRequest(
            noteId: noteId,
            limit: limit,
            includeLive: includeLive
        )

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try JSONEncoder().encode(requestBody)

        let (data, response) = try await session.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw APIError.invalidResponse
        }

        guard httpResponse.statusCode == 200 else {
            let message = String(data: data, encoding: .utf8) ?? "Unknown error"
            throw APIError.requestFailed(httpResponse.statusCode, message)
        }

        do {
            let relatedResponse = try JSONDecoder().decode(RelatedNotesResponse.self, from: data)
            return relatedResponse.results
        } catch {
            throw APIError.decodingFailed(error.localizedDescription)
        }
    }
```

### Step 1.6: Commit Task 1

```bash
cd .worktrees/selenechat-vector-search
git add SeleneChat/Sources/Services/SeleneAPIService.swift
git commit -m "feat(selenechat): add SeleneAPIService for backend API calls

- Add actor-based HTTP client for Selene backend
- Implement /api/search endpoint for semantic search
- Implement /api/related-notes endpoint for related notes
- Add health check with 60s caching
- Add typed error handling"
```

---

## Task 2: Add Hybrid Retrieval to DatabaseService

Modify `DatabaseService` to try API first, fall back to SQLite.

**Files:**
- Modify: `SeleneChat/Sources/Services/DatabaseService.swift`

### Step 2.1: Add SeleneAPIService reference

At the top of `DatabaseService.swift`, add the API service reference:

```swift
// Add near other service references
private let apiService = SeleneAPIService.shared
```

### Step 2.2: Add semantic search method

Add a new method to `DatabaseService`:

```swift
    // MARK: - Semantic Search (API + Fallback)

    /// Search notes semantically. Tries API first, falls back to SQLite keyword search.
    func searchNotesSemanticaly(query: String, limit: Int = 10) async -> [Note] {
        // Try API first
        do {
            let apiResults = try await apiService.searchNotes(query: query, limit: limit)

            // Convert API results to full Note objects by fetching from local DB
            var notes: [Note] = []
            for result in apiResults {
                if let note = try await getNote(byId: result.id) {
                    notes.append(note)
                }
            }
            return notes
        } catch {
            // API unavailable - fall back to keyword search
            print("API search failed, falling back to SQLite: \(error.localizedDescription)")
            return await fallbackKeywordSearch(query: query, limit: limit)
        }
    }

    /// Fallback keyword search using SQLite LIKE queries
    private func fallbackKeywordSearch(query: String, limit: Int) async -> [Note] {
        // Extract keywords and search using existing methods
        let keywords = query.lowercased()
            .components(separatedBy: .whitespaces)
            .filter { $0.count > 2 }

        guard !keywords.isEmpty else {
            return (try? await getRecentProcessedNotes(limit: limit, timeScope: .allTime)) ?? []
        }

        return (try? await searchNotesByKeywords(keywords: keywords, limit: limit)) ?? []
    }
```

### Step 2.3: Add related notes method

```swift
    /// Get notes related to a specific note. Tries API first, falls back to associations table.
    func getRelatedNotes(for noteId: Int, limit: Int = 10) async -> [(note: Note, relationshipType: String, strength: Double?)] {
        // Try API first
        do {
            let apiResults = try await apiService.getRelatedNotes(noteId: noteId, limit: limit)

            // Convert to full Note objects with relationship info
            var results: [(note: Note, relationshipType: String, strength: Double?)] = []
            for related in apiResults {
                if let note = try await getNote(byId: related.id) {
                    results.append((note: note, relationshipType: related.relationshipType, strength: related.strength))
                }
            }
            return results
        } catch {
            // API unavailable - fall back to note_associations table
            print("Related notes API failed, falling back to SQLite: \(error.localizedDescription)")
            return await fallbackRelatedNotes(for: noteId, limit: limit)
        }
    }

    /// Fallback related notes using note_associations table
    private func fallbackRelatedNotes(for noteId: Int, limit: Int) async -> [(note: Note, relationshipType: String, strength: Double?)] {
        guard let db = db else { return [] }

        do {
            // Query associations table
            let query = """
                SELECT note_id_b as related_id, similarity_score
                FROM note_associations
                WHERE note_id_a = ?
                ORDER BY similarity_score DESC
                LIMIT ?
            """

            var results: [(note: Note, relationshipType: String, strength: Double?)] = []

            for row in try db.prepare(query, noteId, limit) {
                let relatedId = Int(row[0] as! Int64)
                let score = row[1] as? Double

                if let note = try await getNote(byId: relatedId) {
                    results.append((note: note, relationshipType: "EMBEDDING", strength: score))
                }
            }

            return results
        } catch {
            print("Fallback related notes query failed: \(error)")
            return []
        }
    }
```

### Step 2.4: Add API availability check helper

```swift
    /// Check if the Selene API is available
    func isAPIAvailable() async -> Bool {
        return await apiService.isAvailable()
    }
```

### Step 2.5: Commit Task 2

```bash
git add SeleneChat/Sources/Services/DatabaseService.swift
git commit -m "feat(selenechat): add hybrid retrieval with API fallback

- Add searchNotesSemanticaly() with API-first approach
- Add getRelatedNotes() with association table fallback
- Add isAPIAvailable() helper for UI status
- Graceful degradation when server unavailable"
```

---

## Task 3: Update QueryAnalyzer for Semantic Mode

Add detection for queries that benefit from semantic search.

**Files:**
- Modify: `SeleneChat/Sources/Services/QueryAnalyzer.swift`

### Step 3.1: Add semantic query type

In `QueryAnalyzer.swift`, update the `QueryType` enum:

```swift
enum QueryType {
    case pattern    // Looking for patterns/trends
    case search     // Explicit search request
    case knowledge  // Recall specific information
    case general    // Open-ended question
    case thread     // Thread-related query
    case semantic   // Conceptual/meaning-based query (NEW)
}
```

### Step 3.2: Add semantic indicators

Add a new constant array for semantic indicators:

```swift
private let semanticIndicators = [
    "similar to",
    "related to",
    "like my",
    "conceptually",
    "meaning",
    "connects to",
    "associated with",
    "reminds me of",
    "in the spirit of",
    "along the lines of"
]
```

### Step 3.3: Update detectQueryType method

In `detectQueryType(_:)`, add semantic detection before the default case:

```swift
// Add this case before the default return
// Check for semantic queries
for indicator in semanticIndicators {
    if lowercased.contains(indicator) {
        return .semantic
    }
}

// Also treat vague conceptual queries as semantic
if lowercased.starts(with: "what about") ||
   lowercased.starts(with: "thoughts on") ||
   lowercased.starts(with: "anything about") {
    return .semantic
}
```

### Step 3.4: Add useSemanticSearch helper

Add a public method to determine if semantic search should be used:

```swift
/// Determine if a query should use semantic (vector) search
func shouldUseSemanticSearch(_ query: String) -> Bool {
    let queryType = detectQueryType(query.lowercased())

    switch queryType {
    case .semantic:
        return true
    case .knowledge, .general:
        // Use semantic for conceptual queries without specific keywords
        let keywords = extractKeywords(from: query)
        return keywords.count <= 2  // Few keywords = more conceptual
    default:
        return false
    }
}
```

### Step 3.5: Commit Task 3

```bash
git add SeleneChat/Sources/Services/QueryAnalyzer.swift
git commit -m "feat(selenechat): add semantic query detection

- Add .semantic QueryType for conceptual queries
- Add semanticIndicators for detection
- Add shouldUseSemanticSearch() helper
- Route vague queries to vector search"
```

---

## Task 4: Integrate Semantic Search in ChatViewModel

Wire up the semantic search in the message flow.

**Files:**
- Modify: `SeleneChat/Sources/Services/ChatViewModel.swift`

### Step 4.1: Update sendMessage to use semantic search

In the `sendMessage` method, after query analysis and before note retrieval, add semantic routing:

Find the section where notes are retrieved (around `retrieveNotesFor`) and modify:

```swift
// After: let analysis = queryAnalyzer.analyze(content)

// Determine if we should use semantic search
let useSemantic = queryAnalyzer.shouldUseSemanticSearch(content)

// Retrieve notes - semantic or traditional
let relatedNotes: [Note]
if useSemantic {
    relatedNotes = await databaseService.searchNotesSemanticaly(
        query: content,
        limit: limitFor(queryType: analysis.queryType)
    )
} else {
    relatedNotes = try await databaseService.retrieveNotesFor(
        queryType: analysis.queryType,
        keywords: analysis.keywords,
        timeScope: analysis.timeScope,
        limit: limitFor(queryType: analysis.queryType)
    )
}
```

### Step 4.2: Commit Task 4

```bash
git add SeleneChat/Sources/Services/ChatViewModel.swift
git commit -m "feat(selenechat): integrate semantic search in chat flow

- Route conceptual queries through vector search API
- Fall back to keyword search for specific queries
- Maintain existing behavior for non-semantic queries"
```

---

## Task 5: Create RelatedNotesView Component

Add UI to show related notes for the current context.

**Files:**
- Create: `SeleneChat/Sources/Views/RelatedNotesView.swift`

### Step 5.1: Create the view file

```swift
// SeleneChat/Sources/Views/RelatedNotesView.swift

import SwiftUI

/// Displays notes related to a given note with relationship type badges
struct RelatedNotesView: View {
    let noteId: Int
    @State private var relatedNotes: [(note: Note, relationshipType: String, strength: Double?)] = []
    @State private var isLoading = true
    @State private var errorMessage: String?

    @EnvironmentObject var databaseService: DatabaseService

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            headerView

            if isLoading {
                loadingView
            } else if let error = errorMessage {
                errorView(error)
            } else if relatedNotes.isEmpty {
                emptyView
            } else {
                notesList
            }
        }
        .task {
            await loadRelatedNotes()
        }
    }

    // MARK: - Subviews

    private var headerView: some View {
        HStack {
            Image(systemName: "link")
                .foregroundColor(.secondary)
            Text("Related Notes")
                .font(.headline)
            Spacer()
            if !isLoading && !relatedNotes.isEmpty {
                Text("\(relatedNotes.count)")
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(Color.secondary.opacity(0.2))
                    .cornerRadius(4)
            }
        }
    }

    private var loadingView: some View {
        HStack {
            ProgressView()
                .scaleEffect(0.8)
            Text("Finding related notes...")
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .padding(.vertical, 8)
    }

    private func errorView(_ message: String) -> some View {
        HStack {
            Image(systemName: "exclamationmark.triangle")
                .foregroundColor(.orange)
            Text(message)
                .font(.caption)
                .foregroundColor(.secondary)
        }
    }

    private var emptyView: some View {
        Text("No related notes found")
            .font(.caption)
            .foregroundColor(.secondary)
            .padding(.vertical, 4)
    }

    private var notesList: some View {
        VStack(alignment: .leading, spacing: 6) {
            ForEach(relatedNotes, id: \.note.id) { item in
                RelatedNoteRow(
                    note: item.note,
                    relationshipType: item.relationshipType,
                    strength: item.strength
                )
            }
        }
    }

    // MARK: - Data Loading

    private func loadRelatedNotes() async {
        isLoading = true
        errorMessage = nil

        let results = await databaseService.getRelatedNotes(for: noteId, limit: 5)

        await MainActor.run {
            self.relatedNotes = results
            self.isLoading = false
        }
    }
}

/// Row displaying a single related note with relationship badge
struct RelatedNoteRow: View {
    let note: Note
    let relationshipType: String
    let strength: Double?

    var body: some View {
        HStack(spacing: 8) {
            relationshipBadge

            VStack(alignment: .leading, spacing: 2) {
                Text(note.title)
                    .font(.subheadline)
                    .lineLimit(1)

                Text(note.formattedDate)
                    .font(.caption2)
                    .foregroundColor(.secondary)
            }

            Spacer()

            if let strength = strength {
                Text(String(format: "%.0f%%", strength * 100))
                    .font(.caption2)
                    .foregroundColor(.secondary)
            }
        }
        .padding(.vertical, 4)
        .padding(.horizontal, 8)
        .background(Color.secondary.opacity(0.05))
        .cornerRadius(6)
    }

    private var relationshipBadge: some View {
        Text(badgeText)
            .font(.caption2)
            .fontWeight(.medium)
            .foregroundColor(badgeColor)
            .padding(.horizontal, 6)
            .padding(.vertical, 2)
            .background(badgeColor.opacity(0.15))
            .cornerRadius(4)
    }

    private var badgeText: String {
        switch relationshipType {
        case "SAME_THREAD": return "Thread"
        case "TEMPORAL": return "Time"
        case "EMBEDDING": return "Similar"
        default: return relationshipType
        }
    }

    private var badgeColor: Color {
        switch relationshipType {
        case "SAME_THREAD": return .purple
        case "TEMPORAL": return .blue
        case "EMBEDDING": return .green
        default: return .gray
        }
    }
}

#Preview {
    RelatedNotesView(noteId: 1)
        .environmentObject(DatabaseService.shared)
        .frame(width: 300)
        .padding()
}
```

### Step 5.2: Commit Task 5

```bash
git add SeleneChat/Sources/Views/RelatedNotesView.swift
git commit -m "feat(selenechat): add RelatedNotesView component

- Display related notes with relationship type badges
- Show SAME_THREAD, TEMPORAL, EMBEDDING relationships
- Include strength percentage when available
- Handle loading, empty, and error states"
```

---

## Task 6: Add API Status Indicator

Show the user when semantic search is available.

**Files:**
- Modify: `SeleneChat/Sources/Views/ChatView.swift`

### Step 6.1: Add API status state

In `ChatView.swift`, add state for API availability:

```swift
@State private var isAPIAvailable = false
```

### Step 6.2: Add status indicator to the header

Find the header/toolbar area and add a status indicator:

```swift
// Add near other status indicators or in toolbar
HStack(spacing: 4) {
    Circle()
        .fill(isAPIAvailable ? Color.green : Color.orange)
        .frame(width: 8, height: 8)
    Text(isAPIAvailable ? "Semantic" : "Keywords")
        .font(.caption2)
        .foregroundColor(.secondary)
}
.help(isAPIAvailable ? "Vector search available" : "Using keyword search (server offline)")
```

### Step 6.3: Check API status on appear

Add to the view's `.task` or `.onAppear`:

```swift
.task {
    isAPIAvailable = await databaseService.isAPIAvailable()
}
```

### Step 6.4: Commit Task 6

```bash
git add SeleneChat/Sources/Views/ChatView.swift
git commit -m "feat(selenechat): add API status indicator

- Show green dot when vector search available
- Show orange dot with 'Keywords' when server offline
- Check status on view appear"
```

---

## Task 7: Update BRANCH-STATUS.md

Mark planning complete, update for dev stage.

**Files:**
- Modify: `BRANCH-STATUS.md`

### Step 7.1: Update checklist

```markdown
### Planning
- [x] Design doc exists and approved
- [x] Conflict check completed (no overlapping work)
- [x] Dependencies identified and noted
- [x] Branch and worktree created
- [x] Implementation plan written (superpowers:writing-plans)

**Current Stage:** dev
```

### Step 7.2: Commit

```bash
git add BRANCH-STATUS.md
git commit -m "docs: mark planning complete, move to dev stage"
```

---

## Verification Checklist

After completing all tasks, verify:

- [ ] SeleneChat builds without errors: `xcodebuild -scheme SeleneChat build`
- [ ] Server running: `curl http://localhost:5678/health`
- [ ] API search works: Send a conceptual query like "thoughts on productivity"
- [ ] Fallback works: Stop server, query still returns results
- [ ] Related notes appear in UI
- [ ] Status indicator reflects server state

---

## Acceptance Criteria Mapping

| Criteria | Task |
|----------|------|
| SeleneChat can call `/api/search` and display results | Tasks 1, 2, 4 |
| SeleneChat can call `/api/related-notes` for current note | Tasks 1, 2, 5 |
| Graceful fallback when API unavailable | Task 2 |
| Related notes visible in UI with relationship type | Task 5 |
