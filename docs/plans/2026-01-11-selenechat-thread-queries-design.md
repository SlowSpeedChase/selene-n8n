# SeleneChat Thread Queries Design

**Date:** 2026-01-11
**Status:** Approved
**Scope:** Add "what's emerging" and "show me [thread]" queries to SeleneChat

---

## Overview

Add thread query support to SeleneChat so users can ask about their semantic threads directly in the chat interface.

**Queries supported:**
- "What's emerging?" - List active threads sorted by momentum
- "Show me [thread name] thread" - Show thread details + linked notes

**Key decision:** Thread queries bypass Ollama - data is already structured, so we format directly. Faster response, no token cost.

---

## Query Detection

### QueryAnalyzer Changes

Add new query type and thread intent:

```swift
enum QueryType {
    case pattern
    case search
    case knowledge
    case general
    case thread      // NEW
}

enum ThreadQueryIntent {
    case listActive           // "what's emerging"
    case showSpecific(String) // "show me X thread"
}
```

### Detection Patterns

**listActive triggers:**
- "what's emerging"
- "what's new with threads"
- "active threads"
- "show threads"
- "my threads"

**showSpecific triggers:**
- "show me [name] thread"
- "tell me about [name] thread"
- "what's the [name] thread"
- "[name] thread"

Extract thread name using regex: `show me (.+?) thread` or `(.+?) thread$`

---

## Database Layer

### Thread Model

```swift
struct Thread: Identifiable, Hashable {
    let id: Int64
    let name: String
    let why: String?
    let summary: String?
    let status: String
    let noteCount: Int
    let momentumScore: Double?
    let lastActivityAt: Date?
}
```

### DatabaseService Methods

```swift
// Get active threads sorted by momentum
func getActiveThreads(limit: Int = 10) async throws -> [Thread]

// Get thread by fuzzy name match + its linked notes
func getThreadByName(_ name: String) async throws -> (Thread, [Note])?
```

### SQL Queries

**getActiveThreads:**
```sql
SELECT id, name, why, summary, status, note_count, momentum_score, last_activity_at
FROM threads
WHERE status = 'active'
ORDER BY momentum_score DESC
LIMIT ?
```

**getThreadByName:**
```sql
-- Step 1: Find thread
SELECT id, name, why, summary, status, note_count, momentum_score, last_activity_at
FROM threads
WHERE name LIKE '%' || ? || '%'
  AND status = 'active'
LIMIT 1

-- Step 2: Get linked notes
SELECT r.id, r.title, r.content, r.created_at, ...
FROM raw_notes r
JOIN thread_notes tn ON r.id = tn.raw_note_id
WHERE tn.thread_id = ?
ORDER BY r.created_at DESC
```

---

## Response Formatting

### "What's emerging" Response

```
📊 Active Threads (by momentum)

1. **Event-Driven Architecture Testing** (momentum: 33.2)
   → 5 notes | Last activity: 2 days ago
   "Testing and validating the event-driven workflow system"

2. **Project Journey** (momentum: 9.3)
   → 3 notes | Last activity: 5 days ago
   "Exploring project management approaches"

Ask "show me [thread name] thread" for details.
```

### "Show me X thread" Response

```
🧵 Event-Driven Architecture Testing

**Why:** Validating that the new workflow system handles events correctly

**Summary:** Testing and validating the event-driven workflow system...

**Direction:** emerging

---

**Linked Notes (5):**
• [1] "Webhook testing results" - Jan 8
• [2] "Event flow debugging" - Jan 7
• [3] "Architecture decisions" - Jan 5
...
```

Notes are clickable citations linking to NoteDetailView.

---

## Chat Flow Integration

```
User types query
       ↓
QueryAnalyzer.analyze()
       ↓
   QueryType?
       ↓
┌──────┴──────┐
│   .thread   │ ← NEW PATH
└──────┬──────┘
       ↓
ThreadQueryIntent?
       ↓
┌─────────────┬─────────────┐
│ .listActive │ .showSpecific │
└──────┬──────┴──────┬──────┘
       ↓             ↓
getActiveThreads() │ getThreadByName()
       ↓             ↓
Format response directly (no LLM)
       ↓
Display in chat as Message
```

---

## Error Handling

| Scenario | Response |
|----------|----------|
| No active threads | "No active threads yet. Threads emerge when 3+ related notes cluster together." |
| Thread name not found | "I couldn't find a thread matching '[name]'. Try 'what's emerging' to see active threads." |
| Database error | "Sorry, I couldn't access thread data. Please check the database connection." |

---

## Files to Modify

| File | Changes |
|------|---------|
| `QueryAnalyzer.swift` | Add `.thread` type, `ThreadQueryIntent`, detection patterns |
| `DatabaseService.swift` | Add `Thread` model, `getActiveThreads()`, `getThreadByName()` |
| `ChatViewModel.swift` | Handle `.thread` query type, format responses |
| `Message.swift` | Possibly add thread-specific message type (optional) |

---

## Success Criteria

1. User types "what's emerging" → sees list of active threads with momentum
2. User types "show me [name] thread" → sees thread details + linked notes
3. Linked notes are clickable citations
4. Response is instant (no LLM latency)
5. Graceful error messages for edge cases
