# Selene Thread System: Implementation Plan

**Date:** 2026-01-04
**Status:** Approved for Implementation
**Purpose:** Transform Selene from a note analysis system into a living thought consolidation system

---

## Executive Summary

Selene is a personal thought processing system for someone with ADHD. The core problem isn't capturing thoughts or organizing them — it's making sense of them over time and knowing when to act.

The user dumps thoughts into Drafts throughout the day. Those thoughts become notes. But complex thoughts don't map to simple actions. They form **threads** — lines of thinking that span multiple notes, have underlying motivations, and eventually become projects or writing or decisions.

**The system's job is to hold the thread so the user doesn't have to.**

Currently, Selene analyzes notes in isolation (concepts, themes, sentiment). What's missing is the **relationship between notes** — the associations that form threads, and the reconsolidation process that keeps threads alive as new thoughts arrive.

This plan adds that layer.

---

## User Perspective: How This Works

### What the User Does

Nothing different. They dump thoughts into Drafts. They live their life.

### What the User Sees

**Morning check-in via SeleneChat:**
> "3 threads updated overnight. 1 new thread emerged."

**Ask: "What's new?"**
> **Soccer/Community thread** — 2 new notes added
> Your note from Sunday about "missing team energy at work" was connected to your earlier notes about wanting to join a soccer league. This thread is becoming more about belonging than fitness.
>
> **New thread: Writing in Public**
> 4 notes from the past month clustered together. You've mentioned wanting to share ideas online, fear of judgment, and thoughts about what you'd write about. No clear action yet — still exploring.

**Later that week, new note captured:**
"Saw a guy at the coffee shop working on a blog post. Felt jealous. Why am I not doing that?"

**Next morning:**
> **Writing in Public thread** — updated
> New note added. Thread summary revised: "Desire to write publicly is growing. Emotional charge increasing (jealousy, frustration). May be approaching decision point."

**Ask: "What should I act on?"**
> System surfaces threads with momentum — recent activity, emotional charge, clear next actions emerging.

**Ask: "What have I abandoned?"**
> Threads with no new notes in 6+ weeks. User can revive, archive, or let fade.

**When ready to write or act:**
> User opens Obsidian, finds thread file with full summary, linked notes, and context. Everything in one place.

### The Key Insight

The user doesn't project manage. The system is their working memory for threads they're not actively touching. They dump thoughts in, the system consolidates while they sleep, and they return to find their thinking organized.

---

## Design Principle

**Small atomic units. Rich connections. Local context only.**

The brain doesn't file things hierarchically. It connects everything through association. Patterns emerge from repetition and resonance. Retrieval is context-triggered — one thought pulls related thoughts with it.

The system mirrors this:

```
Don't: Feed LLM 500 notes and say "find threads"
       (context explodes, output is garbage)

Do:    Feed LLM 5-10 related notes and say "what connects these?"
       (small context, high quality)
       Repeat thousands of times.
       Let structure emerge from many small operations.
```

**Context window is the only constraint.** But with many small operations on small clusters, context is never a problem.

---

## Current System: What Exists

### Workflows (Keep All)

| Workflow | Function | Keep? |
|----------|----------|-------|
| 01-Ingestion | Drafts → webhook → raw_notes | ✓ Keep |
| 02-LLM Processing | Extract concepts, themes, confidence | ✓ Keep + extend |
| 03-Pattern Detection | Find patterns across notes | ✓ Keep (may integrate with clustering) |
| 05-Sentiment | Track emotional content | ✓ Keep (becomes salience signal) |
| 06-Obsidian Export | Output to vault by concept | ✓ Keep + extend |
| 07-Task Extraction | Pull actions → Things 3 | ✓ Keep (link to threads) |
| 08-Project Detection | Group tasks into projects | ✓ Keep (link to threads) |

### Database Tables (Keep All)

| Table | Purpose | Keep? |
|-------|---------|-------|
| raw_notes | Source notes | ✓ Keep |
| processed_notes | Concepts, themes, confidence | ✓ Keep |
| detected_patterns | Pattern analysis | ✓ Keep |
| sentiment_history | Emotional tracking | ✓ Keep |
| task_metadata | Extracted tasks | ✓ Keep |
| project_metadata | Task groupings | ✓ Keep |

### Current Flow

```
Note → Concepts/Themes → Organize by Concept → Export
                      → Extract Tasks → Group into Projects
```

**What's Present:** Analysis (what is this note about?)
**What's Missing:** Association (what is this note connected to?)

---

## New System: What to Build

### New Database Tables

```sql
-- Vector embedding for each note
CREATE TABLE note_embeddings (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    raw_note_id INTEGER NOT NULL UNIQUE,
    embedding BLOB NOT NULL,  -- JSON array of floats
    model_version TEXT NOT NULL,  -- Track which model generated it
    created_at TEXT DEFAULT CURRENT_TIMESTAMP,
    FOREIGN KEY (raw_note_id) REFERENCES raw_notes(id)
);

-- Note-to-note similarity links
CREATE TABLE note_associations (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    note_a_id INTEGER NOT NULL,
    note_b_id INTEGER NOT NULL,
    similarity_score REAL NOT NULL,  -- 0.0 to 1.0
    created_at TEXT DEFAULT CURRENT_TIMESTAMP,
    updated_at TEXT DEFAULT CURRENT_TIMESTAMP,
    FOREIGN KEY (note_a_id) REFERENCES raw_notes(id),
    FOREIGN KEY (note_b_id) REFERENCES raw_notes(id),
    UNIQUE(note_a_id, note_b_id)
);

-- Threads (emergent clusters of related thinking)
CREATE TABLE threads (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    name TEXT NOT NULL,
    why TEXT,  -- The underlying motivation/goal
    summary TEXT,
    status TEXT DEFAULT 'active',  -- active, paused, completed, abandoned
    note_count INTEGER DEFAULT 0,
    last_activity_at TEXT,
    emotional_charge REAL,  -- Aggregate from sentiment
    momentum_score REAL,  -- Calculated from recent activity
    created_at TEXT DEFAULT CURRENT_TIMESTAMP,
    updated_at TEXT DEFAULT CURRENT_TIMESTAMP
);

-- Links between threads and notes
CREATE TABLE thread_notes (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    thread_id INTEGER NOT NULL,
    raw_note_id INTEGER NOT NULL,
    added_at TEXT DEFAULT CURRENT_TIMESTAMP,
    relevance_score REAL,  -- How central is this note to the thread
    FOREIGN KEY (thread_id) REFERENCES threads(id),
    FOREIGN KEY (raw_note_id) REFERENCES raw_notes(id),
    UNIQUE(thread_id, raw_note_id)
);

-- Thread history for tracking evolution
CREATE TABLE thread_history (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    thread_id INTEGER NOT NULL,
    summary_before TEXT,
    summary_after TEXT,
    trigger_note_id INTEGER,  -- What note caused this update
    change_type TEXT,  -- 'note_added', 'merged', 'split', 'renamed', 'summarized'
    created_at TEXT DEFAULT CURRENT_TIMESTAMP,
    FOREIGN KEY (thread_id) REFERENCES threads(id)
);

-- Indexes for performance
CREATE INDEX idx_embeddings_note ON note_embeddings(raw_note_id);
CREATE INDEX idx_associations_a ON note_associations(note_a_id);
CREATE INDEX idx_associations_b ON note_associations(note_b_id);
CREATE INDEX idx_associations_score ON note_associations(similarity_score);
CREATE INDEX idx_thread_notes_thread ON thread_notes(thread_id);
CREATE INDEX idx_thread_notes_note ON thread_notes(raw_note_id);
CREATE INDEX idx_threads_status ON threads(status);
CREATE INDEX idx_threads_activity ON threads(last_activity_at);
```

### New Workflow: 09-Embedding-Generation

**Trigger:** After 02-LLM Processing completes, OR batch job for existing notes

**Input:** Note content from raw_notes

**Process:**
1. Call Ollama embedding endpoint
2. Store vector in note_embeddings

**Ollama Embedding Call:**
```
POST http://localhost:11434/api/embeddings
{
  "model": "nomic-embed-text",  -- or mxbai-embed-large
  "prompt": "[note content]"
}
```

**Output:** Vector stored in note_embeddings table

**Notes:**
- nomic-embed-text produces 768-dimension vectors
- mxbai-embed-large produces 1024-dimension vectors
- Pick one model and stay consistent

### New Workflow: 10-Association-Computation

**Trigger:** After embedding generated for a note, OR periodic batch

**Input:** New note's embedding + all existing embeddings

**Process:**
1. Load new note's vector
2. Compute cosine similarity against all other note vectors
3. Store top N associations (where similarity > threshold)

**Cosine Similarity Function (JavaScript for n8n):**
```javascript
function cosineSimilarity(vecA, vecB) {
    let dotProduct = 0;
    let normA = 0;
    let normB = 0;
    for (let i = 0; i < vecA.length; i++) {
        dotProduct += vecA[i] * vecB[i];
        normA += vecA[i] * vecA[i];
        normB += vecB[i] * vecB[i];
    }
    return dotProduct / (Math.sqrt(normA) * Math.sqrt(normB));
}
```

**Parameters:**
- Similarity threshold: 0.7 (adjustable)
- Max associations per note: 20 (adjustable)

**Output:** Records in note_associations table

### New Workflow: 11-Thread-Detection

**Trigger:** After associations computed, OR periodic batch

**Purpose:** Find clusters of associated notes and create/update threads

**Process:**

**Step 1: Identify Clusters (No LLM)**
```
For each note without a thread:
    Get its associations (similarity > threshold)
    If associated notes share a thread:
        Candidate: add note to that thread
    Else if associated notes form a cluster (3+ notes):
        Candidate: new thread from cluster
    Else:
        Leave as orphan for now
```

**Step 2: Synthesize Thread (LLM)**
```
For each new or updated thread:
    Gather all notes in thread (max 10-15, prioritize recent/central)
    
    Prompt to Ollama:
    """
    These notes were written over time by the same person. They cluster together based on semantic similarity.
    
    Notes:
    ---
    [Note 1 - Date]
    [content]
    ---
    [Note 2 - Date]
    [content]
    ---
    [... up to 10-15 notes]
    
    Questions:
    1. What thread of thinking connects these notes?
    2. What is the underlying want, need, or motivation?
    3. Is there a clear direction or is this still exploring?
    4. Suggest a short name for this thread (2-5 words)
    
    Respond in JSON:
    {
        "name": "...",
        "why": "...",
        "summary": "...",
        "direction": "exploring|emerging|clear",
        "emotional_tone": "neutral|positive|negative|mixed"
    }
    """
```

**Output:** threads and thread_notes records

### New Workflow: 12-Reconsolidation

**Trigger:** Scheduled (hourly or nightly), runs continuously on the machine

**Purpose:** Keep threads alive and evolving

**Process:**

**Step 1: Update Thread Summaries**
```
For each thread with new notes since last summary:
    Gather current notes
    
    Prompt to Ollama:
    """
    Thread: [name]
    Previous summary: [old summary]
    Previous "why": [old why]
    
    New note(s) added:
    ---
    [new note content]
    ---
    
    Has the direction of this thread shifted? Update the summary.
    Has the underlying motivation become clearer?
    
    Respond in JSON:
    {
        "summary": "...",
        "why": "...",
        "direction_shifted": true/false,
        "shift_description": "..." (if shifted)
    }
    """
```

**Step 2: Merge Similar Threads**
```
Compare thread centroids (average of note embeddings)
If two threads have high similarity (>0.85) AND share notes:
    Propose merge
    Synthesize new combined summary
```

**Step 3: Split Divergent Threads**
```
For threads with 10+ notes:
    Run clustering within thread
    If clear sub-clusters emerge:
        Propose split
        Synthesize summaries for each
```

**Step 4: Calculate Momentum**
```
For each thread:
    momentum_score = (
        notes_added_last_7_days * 2 +
        notes_added_last_30_days * 1 +
        avg_sentiment_intensity * 0.5
    )
    Update thread record
```

**Step 5: Archive Stale Threads**
```
For threads with no activity in 60 days:
    Set status = 'inactive'
    (Don't delete - user can revive)
```

### Extend Workflow: 06-Obsidian Export

**Add:** Thread export alongside concept export

**New Output Structure:**
```
vault/
├── By-Concept/           (existing)
│   ├── fitness/
│   ├── writing/
│   └── ...
├── Threads/              (new)
│   ├── Soccer-Community.md
│   ├── Writing-In-Public.md
│   └── ...
└── _Index/               (new)
    ├── Active-Threads.md
    ├── Emerging-Threads.md
    └── Stale-Threads.md
```

**Thread File Format:**
```markdown
# Soccer & Community

**Status:** Active
**Last Activity:** 2026-01-03
**Notes:** 8

## Why

I want to feel part of a team again. The loneliness of remote work is getting to me. Soccer combines physical activity (which I need) with the social connection (which I'm craving).

## Summary

Started as a fitness goal, but has evolved into something more about belonging. Recent notes show frustration with isolation at work and nostalgia for team sports. The fitness angle is secondary to the community need.

## Direction

Emerging — not yet actionable, but building momentum.

---

## Linked Notes

### 2026-01-03 - Missing team energy at work
[content or excerpt]

### 2025-12-28 - Soccer could combine both goals
[content or excerpt]

### 2025-12-15 - I need to move more
[content or excerpt]

[... all linked notes, reverse chronological]

---

## Related Threads

- [[Health-Fitness]] (overlapping notes)
- [[Remote-Work-Struggles]] (thematically related)

## Possible Actions

- Research adult soccer leagues nearby
- Start running to build endurance
- Ask coworkers if anyone plays
```

### Extend: SeleneChat

**New Queries to Support:**

| Query | Response |
|-------|----------|
| "What's new?" / "What's emerging?" | Threads with recent activity, sorted by momentum |
| "Show me the [X] thread" | Thread summary + why + all linked notes |
| "What should I act on?" | Threads with high momentum + clear direction |
| "What's unresolved?" | Threads with no extracted actions |
| "What have I abandoned?" | Threads with status='inactive' |
| "What's growing?" | Threads where note_count increased significantly |
| "Merge [thread A] and [thread B]" | Manual merge trigger |
| "This note belongs in [thread]" | Manual assignment |

**Query Pattern:**
```
User question
      ↓
Parse intent (thread query? note query? action query?)
      ↓
Query database for relevant threads/notes
      ↓
If thread summary needed: return stored summary
If synthesis needed: call Ollama with small context
      ↓
Format response
```

### Extend: Task Extraction (Workflow 07)

**Change:** Link extracted tasks to threads, not just notes

```sql
-- Add to task_metadata
ALTER TABLE task_metadata ADD COLUMN thread_id INTEGER REFERENCES threads(id);
```

**When task is extracted:**
1. Check if source note belongs to a thread
2. If yes, link task to that thread
3. Task now has context: "This task is part of the [thread name] thread"

**Benefit:** When viewing a thread, you see not just notes but also the actions that emerged from it.

---

## Architecture Summary

```
┌─────────────────────────────────────────────────────────────────┐
│                         DATA LAYER                               │
│                                                                  │
│  raw_notes → processed_notes → note_embeddings                  │
│                                      ↓                          │
│                              note_associations                   │
│                                      ↓                          │
│                              threads ← thread_notes             │
│                                      ↓                          │
│                              thread_history                      │
└─────────────────────────────────────────────────────────────────┘
                                   ↓
┌─────────────────────────────────────────────────────────────────┐
│                      PROCESSING LAYER                            │
│                                                                  │
│  01-Ingestion → 02-LLM-Processing → 09-Embedding-Generation     │
│                                            ↓                     │
│                                     10-Association-Computation   │
│                                            ↓                     │
│  07-Task-Extraction ←──────────── 11-Thread-Detection           │
│         ↓                                  ↓                     │
│  08-Project-Detection              12-Reconsolidation           │
│                                     (runs continuously)          │
└─────────────────────────────────────────────────────────────────┘
                                   ↓
┌─────────────────────────────────────────────────────────────────┐
│                       OUTPUT LAYER                               │
│                                                                  │
│  SeleneChat (live queries) ←── Database ──→ Obsidian (snapshots)│
│                                                                  │
│  "What's emerging?"              /Threads/Soccer-Community.md   │
│  "Show me thread X"              /Threads/Writing-In-Public.md  │
│  "What should I act on?"         /_Index/Active-Threads.md      │
└─────────────────────────────────────────────────────────────────┘
```

---

## Implementation Order

### Phase 1: Foundation (Embeddings + Associations)

**Goal:** Position every note in "thought space" and connect them.

1. Create database migration for new tables
2. Select embedding model (recommend: nomic-embed-text via Ollama)
3. Build workflow 09-Embedding-Generation
4. Run batch embedding on all existing processed notes
5. Build workflow 10-Association-Computation
6. Run batch association on all embedded notes
7. Verify: Query database to see note clusters forming

**Checkpoint:** You can query "what notes are similar to this one?" and get meaningful results.

### Phase 2: Thread Detection

**Goal:** See your first threads emerge from the data.

1. Build workflow 11-Thread-Detection (clustering logic)
2. Build thread synthesis prompts for Ollama
3. Run on existing associated notes
4. Review output: Do the threads make sense?
5. Tune parameters (similarity threshold, cluster size)

**Checkpoint:** You have threads in the database with names, summaries, and linked notes.

### Phase 3: Living System

**Goal:** System updates itself as new notes arrive.

1. Wire embedding generation into existing 02-LLM-Processing
2. Wire association computation to trigger after embedding
3. Wire thread detection to trigger after associations
4. Build workflow 12-Reconsolidation
5. Schedule reconsolidation to run hourly/nightly
6. Test with new notes: Do they get added to threads?

**Checkpoint:** System processes new notes end-to-end without intervention.

### Phase 4: Interfaces

**Goal:** Access the threads.

1. Extend Obsidian export to generate thread files
2. Add SeleneChat queries for threads
3. Link tasks to threads in extraction workflow
4. Build index views (active, emerging, stale)

**Checkpoint:** User can ask "what's emerging?" and get a meaningful answer.

---

## Configuration Parameters

Store in config file, tune based on experience:

```json
{
  "embedding": {
    "model": "nomic-embed-text",
    "dimensions": 768
  },
  "associations": {
    "similarity_threshold": 0.7,
    "max_associations_per_note": 20
  },
  "clustering": {
    "min_cluster_size": 3,
    "thread_merge_threshold": 0.85
  },
  "reconsolidation": {
    "schedule": "0 * * * *",
    "max_notes_per_synthesis": 15,
    "stale_threshold_days": 60
  },
  "threads": {
    "momentum_weights": {
      "notes_7_days": 2.0,
      "notes_30_days": 1.0,
      "sentiment_intensity": 0.5
    }
  }
}
```

---

## Key Principles for Implementation

1. **Small context, many operations**
   Never feed more than 10-15 notes to LLM at once. Better to run 100 small operations than 1 large one.

2. **Let structure emerge**
   Don't predefine thread categories. Let clusters form from the data. The user's thinking defines the threads, not a taxonomy.

3. **Preserve history**
   Track thread evolution in thread_history. The user may want to see how their thinking developed over time.

4. **Fail gracefully**
   If embedding fails, note still gets processed normally. If thread detection fails, notes remain orphans until next run. System should never block on the new features.

5. **Tunable parameters**
   Similarity thresholds, cluster sizes, etc. should be configurable. What works for 100 notes may not work for 10,000.

6. **Local everything**
   All processing happens on the local machine. Ollama for LLM, SQLite for storage. No data leaves the system.

---

## Success Criteria

The system is working when:

1. User dumps a thought into Drafts
2. Without any further action, that thought:
   - Gets analyzed (concepts, themes, sentiment) ✓ already works
   - Gets embedded (vector position)
   - Gets associated (linked to similar notes)
   - Gets clustered (added to a thread, or seeds a new one)
   - Triggers thread summary update
3. User asks "what's emerging?" and sees their threads
4. User can open a thread in Obsidian and find everything in one place
5. User acts on ONE thing, confident the system holds the rest

---

## Files to Create/Modify

### New Files
- `database/migrations/009_thread_system.sql`
- `workflows/09-embedding-generation/workflow.json`
- `workflows/10-association-computation/workflow.json`
- `workflows/11-thread-detection/workflow.json`
- `workflows/12-reconsolidation/workflow.json`
- `config/thread-system-config.json`

### Modified Files
- `workflows/02-llm-processing/workflow.json` (add embedding trigger)
- `workflows/06-obsidian-export/workflow.json` (add thread export)
- `workflows/07-task-extraction/workflow.json` (add thread linking)
- `database/schema.sql` (add new tables)
- `SeleneChat/` (add thread queries)

---

## Questions for Implementation

1. Which Ollama embedding model to use? (nomic-embed-text recommended for balance of quality/speed)
2. Where to store vectors? (JSON blob in SQLite vs. separate vector store)
3. How often should reconsolidation run? (Hourly suggested, nightly minimum)
4. What's the minimum cluster size for a thread? (3 suggested)
5. Should thread merging be automatic or require user confirmation?

---

## End State Vision

The user has a **second brain that thinks while they sleep.**

They capture thoughts throughout the day — quick voice notes, typed fragments, half-formed ideas. They don't organize anything. They don't even think about it.

The system:
- Understands what each thought is about
- Connects it to related thoughts
- Notices patterns forming
- Names the threads of thinking
- Tracks what's growing vs. fading
- Surfaces what needs attention
- Holds everything else

When the user sits down to write, everything about a topic is collected. When they're ready to act, the context is there. When they're overwhelmed, they can ask "what actually matters right now?" and get an answer.

The goal isn't productivity. It's **cognitive relief** — the feeling that your thinking is held, organized, and accessible, without you having to hold it yourself.
