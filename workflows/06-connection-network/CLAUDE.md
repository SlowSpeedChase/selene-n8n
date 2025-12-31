# 06-Connection Network Workflow Context

## Purpose

Builds relationship network between notes based on shared concepts, themes, and temporal proximity. Creates graph structure for exploring knowledge connections and discovering patterns. Designed for ADHD-friendly knowledge navigation.

## Current Status

**BLOCKED** - Workflow requires `note_connections` table which does not exist.
See `docs/STATUS.md` for details and resolution options.

## Tech Stack

- n8n Cron trigger (every 6 hours)
- better-sqlite3 for database operations
- Weighted similarity calculation (concept overlap + theme overlap + temporal)
- JSON array manipulation
- Network analysis metrics

## Key Files

- workflow.json (169 lines) - Main workflow definition
- README.md - Quick start and usage guide
- docs/STATUS.md - Test results and known issues
- scripts/test-with-markers.sh - Prerequisite checker

## Data Flow

1. **Every 6 Hours** - Cron trigger activates workflow
2. **Get Recent Notes** - SELECT from processed_notes JOIN raw_notes (LIMIT 100)
3. **Calculate Note Connections** - O(n^2) comparison of all note pairs
4. **Split Connections for Insert** - Transform to individual items
5. **Store Connection** - INSERT into note_connections (**TABLE MISSING**)
6. **Generate Network Statistics** - Calculate hub notes, strongest connections
7. **Store Network Statistics** - INSERT into network_analysis_history

## Common Patterns

### Concept Similarity Calculation
```javascript
// Jaccard similarity for concept overlap
function calculateSimilarity(concepts1, concepts2) {
    const set1 = new Set(JSON.parse(concepts1 || '[]'));
    const set2 = new Set(JSON.parse(concepts2 || '[]'));

    const intersection = new Set([...set1].filter(x => set2.has(x)));
    const union = new Set([...set1, ...set2]);

    return union.size > 0 ? intersection.size / union.size : 0;
}
```

### Finding Related Notes
```javascript
const db = require('better-sqlite3')('/selene/data/selene.db', { readonly: true });

// Get all notes with concepts
const notes = db.prepare('SELECT id, concepts FROM processed_notes WHERE test_run = ?').all(testRun);

// Compare current note to all others
const connections = notes
    .map(note => ({
        to_id: note.id,
        similarity: calculateSimilarity(currentConcepts, note.concepts)
    }))
    .filter(conn => conn.similarity > 0.3) // Threshold
    .sort((a, b) => b.similarity - a.similarity);

db.close();
```

### Storing Network Data
```javascript
// Store connection with weight
db.prepare(`
    INSERT INTO network_analysis_history
    (from_note_id, to_note_id, connection_strength, shared_concepts, created_at, test_run)
    VALUES (?, ?, ?, ?, CURRENT_TIMESTAMP, ?)
`).run(fromId, toId, similarity, JSON.stringify(sharedConcepts), testRun);
```

## Testing

### Run Tests
```bash
cd workflows/06-connection-network
./scripts/test-with-markers.sh
```

### Test Data Requirements
- Requires processed_notes with concepts populated
- Needs 5+ notes for meaningful network
- Test markers ensure isolation

## Database Schema

**Table: note_connections (DOES NOT EXIST - NEEDS TO BE CREATED)**
```sql
CREATE TABLE note_connections (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    source_note_id INTEGER NOT NULL,
    target_note_id INTEGER NOT NULL,
    connection_strength REAL,
    connection_type TEXT,             -- 'concept_based' or 'theme_based'
    shared_concepts TEXT,             -- JSON array
    shared_themes TEXT,               -- JSON array
    concept_overlap_score REAL,
    theme_overlap_score REAL,
    temporal_score REAL,
    days_between INTEGER,
    discovered_at DATETIME DEFAULT CURRENT_TIMESTAMP,
    is_active INTEGER DEFAULT 1,
    UNIQUE(source_note_id, target_note_id),
    FOREIGN KEY (source_note_id) REFERENCES raw_notes(id),
    FOREIGN KEY (target_note_id) REFERENCES raw_notes(id)
);
```

**Table: network_analysis_history (EXISTS)**
```sql
CREATE TABLE network_analysis_history (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    analysis_id TEXT UNIQUE NOT NULL,
    total_notes INTEGER,
    total_connections INTEGER,
    avg_connection_strength REAL,
    concept_based_count INTEGER,
    theme_based_count INTEGER,
    network_stats TEXT,               -- JSON object with detailed stats
    analyzed_at DATETIME DEFAULT CURRENT_TIMESTAMP
);
```

## Network Metrics

### Connection Strength Thresholds
- **0.7-1.0** - Strong connection (many shared concepts)
- **0.4-0.7** - Moderate connection (some overlap)
- **0.1-0.4** - Weak connection (minimal overlap)
- **<0.1** - Ignore (noise)

### Graph Statistics
```javascript
// Calculate node centrality (how connected each note is)
const centrality = db.prepare(`
    SELECT from_note_id, COUNT(*) as connection_count
    FROM network_analysis_history
    WHERE connection_strength > 0.3
    GROUP BY from_note_id
    ORDER BY connection_count DESC
`).all();
```

## Common Patterns

### Bidirectional Connections
```javascript
// Store connections in both directions for faster queries
db.prepare('INSERT INTO network_analysis_history (...)').run(fromId, toId, ...);
db.prepare('INSERT INTO network_analysis_history (...)').run(toId, fromId, ...);
```

### Avoiding Self-Connections
```javascript
// Skip comparing note to itself
if (note1.id === note2.id) continue;
```

### Batch Processing
```javascript
// Process in batches to avoid memory issues
const batchSize = 100;
for (let offset = 0; offset < totalNotes; offset += batchSize) {
    const batch = db.prepare('SELECT ... LIMIT ? OFFSET ?').all(batchSize, offset);
    // Process batch
}
```

## ADHD Applications

### Knowledge Discovery
- **Surface buried knowledge** - Rediscover forgotten notes through connections
- **Visual navigation** - Graph view appeals to ADHD visual thinking
- **Context switching** - Explore related ideas when focus shifts

### Pattern Recognition
- **Concept clusters** - Identify recurring themes across time
- **Interest tracking** - See how interests evolve and connect
- **Project alignment** - Find notes related to current focus

## Do NOT

- **NEVER create self-connections** - Note cannot connect to itself
- **NEVER skip similarity threshold** - Low scores create noise
- **NEVER process all notes at once** - Use batching for large datasets
- **NEVER store duplicate connections** - Check before inserting
- **NEVER ignore bidirectional links** - Store both directions

## Performance Optimization

### Indexing Strategy
```sql
CREATE INDEX idx_network_from ON network_analysis_history(from_note_id);
CREATE INDEX idx_network_to ON network_analysis_history(to_note_id);
CREATE INDEX idx_network_strength ON network_analysis_history(connection_strength);
```

### Incremental Updates
```javascript
// Only analyze new notes, not entire database each run
const newNotes = db.prepare(`
    SELECT id FROM processed_notes
    WHERE id NOT IN (SELECT DISTINCT from_note_id FROM network_analysis_history)
`).all();
```

## Related Context

@workflows/06-connection-network/README.md
@workflows/02-llm-processing/CLAUDE.md
@database/schema.sql
@workflows/CLAUDE.md
