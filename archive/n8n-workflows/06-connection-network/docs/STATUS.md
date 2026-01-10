# Connection Network Workflow - Status & History

## Current Status

**Phase:** Production Ready
**Last Updated:** 2026-01-04
**Status:** ACTIVE - Workflow running successfully

---

## Overview

The connection network workflow analyzes relationships between notes based on shared concepts, themes, and temporal proximity. It builds a knowledge graph for ADHD-friendly navigation and discovery.

---

## Configuration

- **Workflow File:** `workflows/06-connection-network/workflow.json`
- **Database Path:** `/selene/data/selene.db`
- **Source Table:** `processed_notes` (JOIN `raw_notes`)
- **Target Tables:**
  - `note_connections` (individual connections) - EXISTS
  - `network_analysis_history` (analysis summaries) - EXISTS
- **Triggers:**
  - Cron (every 6 hours: `0 */6 * * *`)
  - Webhook: `POST /webhook/api/network-analysis`
- **Status:** Active

---

## Test Results

### Full Integration Test: 2026-01-01

**Tester:** Claude Code
**Environment:** Docker (selene-n8n container)

| Test Case | Status | Notes |
|-----------|--------|-------|
| Database exists | PASS | data/selene.db found |
| Processed notes exist | PASS | 68 notes with concepts |
| note_connections table | PASS | Created via migration 008 |
| network_analysis_history | PASS | Table exists |
| n8n container running | PASS | selene-n8n running |
| Webhook trigger | PASS | POST /webhook/api/network-analysis |
| Connection calculation | PASS | 69 connections calculated |
| Self-connection prevention | PASS | 0 self-connections stored |
| Batch insert | PASS | 66 unique connections stored |
| Statistics generation | PASS | Hub notes and metrics calculated |

**Overall Result:** PASS - All tests successful

**Execution Results:**
```json
{
  "success": true,
  "totalNotes": 68,
  "totalConnections": 69,
  "connectionsStored": 69,
  "avgStrength": 0.375,
  "message": "Network analysis completed and stored successfully"
}
```

**Connection Distribution:**
- Concept-based: 11 (16%)
- Theme-based: 58 (84%)
- Self-connections: 0 (correctly filtered)

---

## Workflow Architecture

### Sequential Flow (Batch Processing)

```
[Every 6 Hours / Manual Trigger]
    |
    v
[Get Recent Notes] - SELECT from processed_notes/raw_notes (LIMIT 100)
    |
    v
[Calculate Note Connections] - O(n^2) comparison, threshold >= 0.3
    |                          Skips self-connections for duplicate entries
    v
[Store All Connections] - Batch INSERT using transaction
    |
    v
[Generate Network Statistics] - Calculate hub notes, strongest connections
    |
    v
[Store Network Statistics] - INSERT into network_analysis_history
    |
    v
[Return Result] - Success response with metrics
```

### Key Features

1. **Batch Insert with Transaction** - All connections inserted atomically
2. **Self-Connection Prevention** - Handles duplicate `raw_note_id` in `processed_notes`
3. **Weighted Scoring**:
   - Concept Overlap (50%): Jaccard-style similarity
   - Theme Overlap (30%): Primary + secondary theme matching
   - Temporal Proximity (20%): Decay over 30-day window
4. **Noise Reduction**: Only connections with score >= 0.3 stored

---

## Database Schema

### note_connections Table (Migration 008)

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
    discovered_at DATETIME,
    is_active INTEGER DEFAULT 1,
    test_run TEXT,                    -- Test data isolation
    UNIQUE(source_note_id, target_note_id),
    FOREIGN KEY (source_note_id) REFERENCES raw_notes(id),
    FOREIGN KEY (target_note_id) REFERENCES raw_notes(id)
);
```

---

## Development History

### 2026-01-01: Production Release

**Changes Made:**
- Created migration `008_note_connections.sql` with proper schema
- Fixed parallel execution bug causing only 1 connection stored
- Restructured workflow: split/parallel → sequential batch insert
- Added self-connection prevention for duplicate `processed_notes` entries
- Added webhook trigger with `httpMethod: POST`
- Verified batch transaction inserts all connections atomically

**Issues Fixed:**
1. Missing `note_connections` table → Created via migration
2. Parallel branch execution → Changed to sequential batch
3. Self-connections from duplicate data → Added ID check
4. Webhook not responding to POST → Added `httpMethod` parameter

**Test Results:**
- 68 notes analyzed
- 69 connections found
- 66 unique connections stored (some pairs had duplicate source data)
- 0 self-connections
- Average connection strength: 0.375

### 2025-12-31: Structure Completion

**Changes Made:**
- Created production-ready directory structure
- Added `scripts/test-with-markers.sh` prerequisite checker
- Added initial `docs/STATUS.md`
- Analyzed workflow.json for database dependencies
- Discovered missing `note_connections` table issue

**Status:** BLOCKED pending schema migration

---

## Common Commands

### Trigger analysis manually

```bash
curl -X POST "http://localhost:5678/webhook/api/network-analysis" \
  -H "Content-Type: application/json" -d '{}'
```

### View connection count

```bash
sqlite3 data/selene.db "SELECT COUNT(*) FROM note_connections;"
```

### View top connections

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

### View network analysis history

```bash
sqlite3 data/selene.db "
  SELECT analysis_id, total_notes, total_connections,
         ROUND(avg_connection_strength, 3) as avg_strength,
         analyzed_at
  FROM network_analysis_history
  ORDER BY analyzed_at DESC
  LIMIT 5;
"
```

---

## Sign-off

### Development
- [x] Workflow JSON exists
- [x] Directory structure complete
- [x] Test script created
- [x] Documentation complete
- [x] Database schema complete

### Testing
- [x] Prerequisites pass
- [x] Workflow executes successfully
- [x] Connections stored correctly
- [x] Statistics calculated correctly
- [ ] Integration with SeleneChat

### Production
- [x] Schema migration applied
- [x] Workflow imported to n8n
- [x] Workflow activated
- [x] First analysis completed
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

### Data Quality Notes

- Found 2 duplicate `raw_note_id` entries in `processed_notes` (IDs 38, 61)
- Self-connection prevention handles this gracefully
- Consider adding UNIQUE constraint on `processed_notes.raw_note_id`
