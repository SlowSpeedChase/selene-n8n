# SeleneChat Vector Search Integration

**Status:** Vision
**Created:** 2026-01-27
**Topic:** selenechat

## Problem

SeleneChat currently uses SQLite-based text search (concepts, themes, content matching). The new LanceDB vector search provides semantic similarity but SeleneChat can't access it directly (no Swift LanceDB bindings).

## Solution

Integrate SeleneChat with the new HTTP API endpoints:
- `POST /api/search` - Semantic search by query text
- `POST /api/related-notes` - Get related notes for a given note

## API Endpoints (Already Built)

### Semantic Search
```bash
POST http://localhost:5678/api/search
Content-Type: application/json

{
  "query": "productivity and focus",
  "limit": 10,
  "noteType": "task",        # optional filter
  "actionability": "actionable"  # optional filter
}

Response:
{
  "query": "productivity and focus",
  "count": 10,
  "results": [
    {
      "id": 84,
      "title": "...",
      "primary_theme": "...",
      "note_type": null,
      "distance": 376.78
    }
  ]
}
```

### Related Notes
```bash
POST http://localhost:5678/api/related-notes
Content-Type: application/json

{
  "noteId": 6,
  "limit": 10,
  "includeLive": true
}

Response:
{
  "noteId": 6,
  "count": 5,
  "results": [
    {
      "id": 11,
      "title": "...",
      "relationship_type": "SAME_THREAD",
      "strength": null,
      "source": "precomputed"
    }
  ]
}
```

## Implementation Tasks

### Task 1: Add APIService to SeleneChat
Create `SeleneChat/Sources/Services/APIService.swift`:
- HTTP client for Selene backend
- Methods: `searchNotes(query:)`, `getRelatedNotes(noteId:)`
- Error handling for server unavailable

### Task 2: Add Hybrid Retrieval to DatabaseService
Modify `DatabaseService.retrieveNotesFor()`:
- Try API search first for semantic results
- Fall back to SQLite if API unavailable
- Merge results intelligently

### Task 3: Add "Related Notes" UI Component
- Show related notes when viewing a note
- Display relationship type (SAME_THREAD, TEMPORAL, EMBEDDING)
- Click to navigate to related note

### Task 4: Update QueryAnalyzer for Semantic Mode
- Detect queries that would benefit from semantic search
- Route to API vs SQLite based on query type

## ADHD Check

- [x] Reduces friction - semantic search finds conceptually related notes without exact keywords
- [x] Makes information visible - "Related Notes" surfaces connections user might miss
- [x] Externalizes cognition - system finds patterns user doesn't have to remember

## Scope Check

- [ ] < 1 week focused work (estimate: 3-4 days)

## Acceptance Criteria

- [ ] SeleneChat can call `/api/search` and display results
- [ ] SeleneChat can call `/api/related-notes` for current note
- [ ] Graceful fallback when API unavailable
- [ ] Related notes visible in UI with relationship type

## Dependencies

- [x] LanceDB transition complete (PR #28 merged)
- [x] API endpoints built (`/api/search`, `/api/related-notes`)
- [ ] Selene server running (launchd agent)

## Notes

The API is ready. This design doc tracks the SeleneChat Swift integration work.
