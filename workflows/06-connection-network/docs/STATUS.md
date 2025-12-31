# Connection Network Workflow - Status & History

## Current Status

**Phase:** Structure Complete, Blocked on Schema
**Last Updated:** 2025-12-31
**Status:** BLOCKED - Missing database table

---

## Overview

The connection network workflow analyzes relationships between notes based on shared concepts, themes, and temporal proximity. It builds a knowledge graph for ADHD-friendly navigation and discovery.

---

## Configuration

- **Workflow File:** `workflows/06-connection-network/workflow.json`
- **Database Path:** `/selene/data/selene.db`
- **Source Table:** `processed_notes` (JOIN `raw_notes`)
- **Target Tables:**
  - `note_connections` (individual connections) - **DOES NOT EXIST**
  - `network_analysis_history` (analysis summaries) - EXISTS
- **Trigger:** Cron (every 6 hours: `0 */6 * * *`)
- **Status:** Inactive (blocked)

---

## Test Results

### Prerequisite Test: 2025-12-31

**Tester:** Claude Code
**Environment:** Docker (selene-n8n container)

| Test Case | Status | Notes |
|-----------|--------|-------|
| Database exists | PASS | data/selene.db found |
| Processed notes exist | PASS | 58 notes with concepts |
| note_connections table | FAIL | Table does not exist (CRITICAL) |
| network_analysis_history | PASS | Table exists |
| n8n container running | PASS | selene-n8n running |
| Previous analyses | PASS | 0 analyses (clean state) |

**Overall Result:** BLOCKED - 4/5 prerequisite tests passed

**Blocking Issue:**
The workflow references `note_connections` table in the "Store Connection" node, but this table does not exist in the database schema. The workflow will fail at step 5 of 7.

---

## Known Issues

### 1. Missing note_connections Table (CRITICAL - BLOCKING)

**Status:** OPEN - Requires schema migration
**Impact:** HIGH - Workflow cannot execute
**Discovered:** 2025-12-31

**Problem:**
The workflow.json "Store Connection" node (line 52-61) attempts to INSERT into `note_connections` table:

```javascript
const insertQuery = `INSERT OR REPLACE INTO note_connections (
    source_note_id, target_note_id,
    connection_strength, connection_type,
    ...
) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)`;
```

However, only `network_analysis_history` exists in the schema.

**Solution Options:**

**Option A: Create missing table (Recommended)**
```sql
CREATE TABLE note_connections (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    source_note_id INTEGER NOT NULL,
    target_note_id INTEGER NOT NULL,
    connection_strength REAL,
    connection_type TEXT,
    shared_concepts TEXT,
    shared_themes TEXT,
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

CREATE INDEX idx_note_connections_source ON note_connections(source_note_id);
CREATE INDEX idx_note_connections_target ON note_connections(target_note_id);
CREATE INDEX idx_note_connections_strength ON note_connections(connection_strength);
```

**Option B: Modify workflow to skip individual connections**
Remove the "Split Connections for Insert" and "Store Connection" nodes, keeping only the network statistics storage.

**Recommendation:** Option A - The individual connections enable rich querying like "find all notes related to X" which is valuable for ADHD knowledge navigation.

---

## Architecture Analysis

### Workflow Flow

```
[Every 6 Hours]
    |
    v
[Get Recent Notes] - SELECT from processed_notes/raw_notes (LIMIT 100)
    |
    v
[Calculate Note Connections] - O(n^2) comparison, threshold >= 0.3
    |
    v
[Split Connections for Insert] - Transform to individual items
    |
    v
[Store Connection] - INSERT into note_connections <-- WILL FAIL
    |
    v
[Generate Network Statistics] - Calculate metrics
    |
    v
[Store Network Statistics] - INSERT into network_analysis_history
```

### Connection Calculation

The workflow calculates a weighted connection score:
- **Concept Overlap (50%):** Jaccard-style similarity of concept arrays
- **Theme Overlap (30%):** Primary + secondary theme matching
- **Temporal Proximity (20%):** Decay over 30-day window

Only connections with score >= 0.3 are stored (noise reduction).

### Performance Considerations

- **Current limit:** 100 notes analyzed per run
- **Connection complexity:** O(n^2) = up to 4,950 comparisons
- **Storage limit:** Top 500 connections saved
- **Frequency:** Every 6 hours (not resource-intensive)

---

## Prerequisites for Production

To make this workflow production-ready:

1. **Create note_connections table**
   ```bash
   sqlite3 data/selene.db < database/migrations/add_note_connections.sql
   ```

2. **Add migration file**
   Create `database/migrations/add_note_connections.sql`

3. **Update database/schema.sql**
   Add the note_connections table definition

4. **Import workflow to n8n**
   ```bash
   ./scripts/manage-workflow.sh import /workflows/06-connection-network/workflow.json
   ```

5. **Activate workflow**
   Toggle active in n8n UI

6. **Verify execution**
   Wait for cron trigger or manually execute

---

## Development History

### 2025-12-31: Structure Completion

**Changes Made:**
- Created production-ready directory structure
- Added `scripts/test-with-markers.sh` prerequisite checker
- Added `docs/STATUS.md` (this file)
- Added `README.md` with comprehensive documentation
- Analyzed workflow.json for database dependencies
- Discovered missing `note_connections` table issue

**Technical Analysis:**
- Workflow has 7 nodes
- Cron trigger (no webhook)
- Uses better-sqlite3 for database operations
- Calculates weighted connection scores
- Stores individual connections AND summary statistics

**Files Created:**
- `/workflows/06-connection-network/README.md`
- `/workflows/06-connection-network/docs/STATUS.md`
- `/workflows/06-connection-network/scripts/test-with-markers.sh`

**Status:** Blocked pending schema migration

---

## Common Commands

### Check processed notes available

```bash
sqlite3 data/selene.db "
  SELECT COUNT(*) as count, primary_theme
  FROM processed_notes
  WHERE concepts IS NOT NULL
  GROUP BY primary_theme
  ORDER BY count DESC;
"
```

### View network analysis history

```bash
sqlite3 data/selene.db "
  SELECT analysis_id, total_notes, total_connections, analyzed_at
  FROM network_analysis_history
  ORDER BY analyzed_at DESC
  LIMIT 10;
"
```

### Check if note_connections exists

```bash
sqlite3 data/selene.db ".schema note_connections"
```

### View sample connections (once table exists)

```bash
sqlite3 data/selene.db "
  SELECT nc.source_note_id, r1.title as source,
         nc.target_note_id, r2.title as target,
         ROUND(nc.connection_strength, 2) as strength
  FROM note_connections nc
  JOIN raw_notes r1 ON nc.source_note_id = r1.id
  JOIN raw_notes r2 ON nc.target_note_id = r2.id
  ORDER BY nc.connection_strength DESC
  LIMIT 10;
"
```

---

## Sign-off

### Development
- [x] Workflow JSON exists
- [x] Directory structure complete
- [x] Test script created
- [x] Documentation complete
- [ ] Database schema complete (BLOCKED)

### Testing
- [ ] Prerequisites pass (4/5 - blocked)
- [ ] Workflow executes successfully
- [ ] Connections stored correctly
- [ ] Statistics calculated correctly
- [ ] Integration with SeleneChat

### Production
- [ ] Schema migration applied
- [ ] Workflow imported to n8n
- [ ] Workflow activated
- [ ] First analysis completed
- [ ] Monitoring in place

---

## Notes for Future Development

### Integration Ideas

1. **SeleneChat Integration**
   - "Find related notes" feature using note_connections
   - Visual graph display of knowledge network
   - Hub note highlighting

2. **Obsidian Export Enhancement**
   - Generate `[[wikilinks]]` based on connections
   - Create index notes for hub topics
   - Export connection graph as Obsidian Canvas

3. **ADHD-Specific Features**
   - "Rediscover" random strongly-connected note pairs
   - Cluster visualization for current interests
   - Time-based connection decay for relevance

### Performance Optimization (Future)

If note count grows significantly:
- Implement incremental analysis (only new notes)
- Use batch inserts instead of individual
- Add connection caching
- Consider background worker for analysis
