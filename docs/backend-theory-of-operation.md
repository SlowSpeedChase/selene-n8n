# Backend Theory of Operation

**Last Updated:** 2026-01-28
**Purpose:** Explain how the Selene backend actually works - from note capture to retrieval

---

## Case Study: Thread Click Flow

*This flow was discovered while debugging "I don't have any notes matching that query yet" error when clicking threads in Today View.*

### The Complete Journey

```
User clicks thread in Today View
    ↓
ContentView.swift (line 37)
    Creates query: "show me [thread.name] thread"
    Switches to Chat tab
    ↓
ChatView.swift (line 85)
    Receives initialQuery parameter
    Auto-sends via chatViewModel.sendMessage()
    ↓
ChatViewModel.swift (line 38)
    Checks: Is this a thread query?
    ↓
QueryAnalyzer.swift (line 216)
    detectThreadIntent() checks patterns:
    - "show me X thread" ✓ MATCH
    - Extracts thread name from regex
    ↓
ChatViewModel.swift (line 321)
    handleThreadQuery() called
    Routes to formatThreadDetails()
    ↓
DatabaseService.swift
    getThreadByName() executes SQL:
    SELECT * FROM threads WHERE name LIKE ?
    JOINs with note_threads to get linked notes
    ↓
ChatViewModel.swift (line 359)
    Formats response with:
    - Thread summary, status, momentum
    - List of linked notes with dates
    ↓
ChatView.swift (line 46)
    Displays formatted response
    User sees thread details!
```

### Key Components

**1. Query Pattern Matching**
- QueryAnalyzer uses regex patterns to detect intent
- Thread queries require specific keywords ("show me", "thread")
- Pattern mismatch = falls through to generic search (bug we fixed)

**2. Direct Database Access**
- Thread queries bypass LLM for speed
- SQL joins `threads` table with `note_threads` link table
- Returns structured data (not AI-generated)

**3. Response Formatting**
- ChatViewModel formats the data into markdown
- Includes citations to source notes
- User can click citations to view full notes

### What Could Go Wrong

| Issue | Cause | Symptom |
|-------|-------|---------|
| "No notes matching" | Query doesn't match pattern | Falls to keyword search |
| Empty thread list | No threads in database | "No active threads yet" |
| Thread not found | Name doesn't match exactly | "Couldn't find thread" |

---

## System Architecture

### Three-Tier Pipeline

```
┌─────────────────────────────────────────────────────────┐
│ TIER 1: CAPTURE (Zero friction input)                  │
├─────────────────────────────────────────────────────────┤
│ Drafts App → HTTP POST → Fastify server (port 5678)    │
│ Server → SQLite INSERT → raw_notes table                │
│ Status: pending                                         │
└─────────────────────────────────────────────────────────┘
                           ↓
┌─────────────────────────────────────────────────────────┐
│ TIER 2: PROCESS (Background workflows via launchd)     │
├─────────────────────────────────────────────────────────┤
│ Every 5 min:  process-llm.ts                            │
│   - Sends pending notes to Ollama (mistral:7b)          │
│   - Extracts concepts, themes, energy                   │
│   - Updates processed_notes table                       │
│                                                          │
│ Every 5 min:  compute-embeddings.ts                     │
│   - Generates vectors (nomic-embed-text)                │
│   - Stores in note_embeddings table                     │
│                                                          │
│ Every 5 min:  compute-associations.ts                   │
│   - Calculates cosine similarity                        │
│   - Creates note_associations (threshold > 0.5)         │
│                                                          │
│ Every 30 min: detect-threads.ts                         │
│   - Clusters associated notes                           │
│   - LLM generates thread summary                        │
│   - Creates threads + note_threads links                │
│                                                          │
│ Hourly:       reconsolidate-threads.ts                  │
│   - Updates thread summaries                            │
│   - Calculates momentum scores                          │
│   - Exports to Obsidian markdown                        │
└─────────────────────────────────────────────────────────┘
                           ↓
┌─────────────────────────────────────────────────────────┐
│ TIER 3: RETRIEVE (Query & explore)                     │
├─────────────────────────────────────────────────────────┤
│ SeleneChat macOS app → SQLite queries                   │
│ Obsidian → Exported markdown files                      │
└─────────────────────────────────────────────────────────┘
```

### Database Tables

**Core Data:**
- `raw_notes` - Original captured content
- `processed_notes` - LLM-extracted metadata
- `note_embeddings` - Semantic vectors (1536 dimensions)

**Relationships:**
- `note_associations` - Note-to-note similarity scores
- `threads` - Clustered groups of related notes
- `note_threads` - Many-to-many link table

**Tasks:**
- `extracted_tasks` - Actionable items for Things 3

---

## Query Routing in SeleneChat

### Decision Tree

```
User types query
    ↓
QueryAnalyzer.analyze()
    ↓
┌─────────────────────────────────┐
│ Is it a thread query?           │
│ ("show me X thread")            │
└─────────────────────────────────┘
         YES ↓         NO ↓
    Thread Query    Continue
         ↓               ↓
    Direct DB      ┌─────────────────────────────┐
    No LLM         │ Should use semantic search? │
                   │ (conceptual vs keyword)     │
                   └─────────────────────────────┘
                        YES ↓         NO ↓
                   Vector Search   Keyword Search
                        ↓               ↓
                   LanceDB API    SQLite LIKE
                        ↓               ↓
                   ┌───────────────────────┐
                   │ Found notes?          │
                   └───────────────────────┘
                        YES ↓    NO ↓
                   Build Context  "No notes yet"
                        ↓
                   Ollama LLM
                        ↓
                   Format response
                        ↓
                   Display with citations
```

### Query Types

| Type | Example | Search Method | LLM Used? |
|------|---------|---------------|-----------|
| Thread | "show me X thread" | Direct SQL | No |
| Semantic | "similar to X" | Vector search | Yes |
| Pattern | "when do I feel productive" | Keyword + metadata | Yes |
| Search | "notes about Docker" | Keyword | Yes |
| Knowledge | "what did I say about Y" | Keyword | Yes |

---

## Data Flow: Note Lifecycle

### Timeline

```
T+0 min:   User captures note in Drafts
           POST /webhook/api/drafts
           INSERT INTO raw_notes
           status = 'pending'

T+5 min:   process-llm.ts runs
           Ollama extracts concepts/themes
           INSERT INTO processed_notes
           status = 'completed'

T+10 min:  compute-embeddings.ts runs
           nomic-embed-text generates vector
           INSERT INTO note_embeddings

T+15 min:  compute-associations.ts runs
           Cosine similarity > 0.5
           INSERT INTO note_associations

T+30 min:  detect-threads.ts runs (if 3+ associated notes)
           LLM clusters related notes
           INSERT INTO threads
           INSERT INTO note_threads (links)

T+60 min:  reconsolidate-threads.ts runs
           LLM updates thread summary
           Calculate momentum score
           Export to Obsidian

T+forever: User queries via SeleneChat
           Retrieve notes/threads
           Discuss and refine ideas
```

### Status Tracking

Each workflow checks the previous step completed:
- `process-llm.ts`: Reads notes with status='pending'
- `compute-embeddings.ts`: Reads notes WHERE id NOT IN (SELECT note_id FROM note_embeddings)
- `detect-threads.ts`: Reads associations WHERE similarity > threshold

---

## Next: Block Diagrams

See `backend-block-diagrams.md` for visual representations of:
1. Overall system architecture
2. Query routing decision tree
3. Thread detection clustering
4. LLM prompt flow

---

*This document is a living reference. Update when architecture changes.*
