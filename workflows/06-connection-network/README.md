# 06-Connection Network Workflow

## Purpose

Builds a connection network between notes by analyzing shared concepts, themes, and temporal proximity. Discovers relationships between ideas and identifies knowledge hubs for ADHD-friendly knowledge navigation.

## Quick Start

### 1. Prerequisites

Before this workflow can run:
- Notes must be processed by workflow 02-llm-processing (concepts extracted)
- The `note_connections` table must exist in the database (see Known Issues)
- n8n container must be running

### 2. Import Workflow

```bash
# Import the workflow into n8n
./scripts/manage-workflow.sh import /workflows/06-connection-network/workflow.json
```

### 3. Activate Workflow

The workflow runs on a cron schedule (every 6 hours). To activate:
1. Open n8n UI at http://localhost:5678
2. Navigate to the 06-Connection-Network workflow
3. Toggle the "Active" switch to ON

### 4. Test the Workflow

```bash
# Run the test suite to verify prerequisites
./workflows/06-connection-network/scripts/test-with-markers.sh
```

## Directory Structure

```
06-connection-network/
├── workflow.json           # n8n workflow definition (source of truth)
├── README.md              # This file (quick start guide)
├── CLAUDE.md              # AI context for development
├── docs/
│   └── STATUS.md          # Test results and current status
└── scripts/
    └── test-with-markers.sh  # Prerequisite checker and test suite
```

## How It Works

### Workflow Steps

1. **Every 6 Hours (Cron)** - Triggers the analysis
2. **Get Recent Notes** - Fetches last 100 processed notes with concepts/themes
3. **Calculate Note Connections** - Computes connection strength between all note pairs:
   - Concept overlap score (50% weight)
   - Theme overlap score (30% weight)
   - Temporal proximity score (20% weight, 30-day window)
4. **Split Connections for Insert** - Prepares individual connections for storage
5. **Store Connection** - Saves to `note_connections` table
6. **Generate Network Statistics** - Calculates network metrics:
   - Hub notes (most connected)
   - Strongest connections
   - Connection type distribution
7. **Store Network Statistics** - Archives analysis in `network_analysis_history`

### Connection Strength Calculation

```
connectionStrength = (conceptOverlap * 0.5) + (themeOverlap * 0.3) + (temporalScore * 0.2)
```

**Thresholds:**
- **0.7 - 1.0**: Strong connection (many shared concepts)
- **0.4 - 0.7**: Moderate connection (some overlap)
- **0.3 - 0.4**: Weak connection (minimum threshold)
- **< 0.3**: Ignored (noise reduction)

## Database Schema

### Table: note_connections

> **WARNING:** This table does not exist in the current schema. See Known Issues.

```sql
CREATE TABLE note_connections (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    source_note_id INTEGER NOT NULL,
    target_note_id INTEGER NOT NULL,
    connection_strength REAL,
    connection_type TEXT,           -- 'concept_based' or 'theme_based'
    shared_concepts TEXT,           -- JSON array
    shared_themes TEXT,             -- JSON array
    concept_overlap_score REAL,
    theme_overlap_score REAL,
    temporal_score REAL,
    days_between INTEGER,
    discovered_at DATETIME,
    is_active INTEGER DEFAULT 1,
    UNIQUE(source_note_id, target_note_id),
    FOREIGN KEY (source_note_id) REFERENCES raw_notes(id),
    FOREIGN KEY (target_note_id) REFERENCES raw_notes(id)
);
```

### Table: network_analysis_history

```sql
CREATE TABLE network_analysis_history (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    analysis_id TEXT UNIQUE NOT NULL,
    total_notes INTEGER,
    total_connections INTEGER,
    avg_connection_strength REAL,
    concept_based_count INTEGER,
    theme_based_count INTEGER,
    network_stats TEXT,             -- JSON object with detailed stats
    analyzed_at DATETIME DEFAULT CURRENT_TIMESTAMP
);
```

## ADHD Design Benefits

- **Surface Buried Knowledge** - Rediscover forgotten notes through connections
- **Visual Navigation** - Graph view appeals to ADHD visual thinking style
- **Context Switching** - Explore related ideas when focus naturally shifts
- **Hub Discovery** - Find central notes that connect multiple concepts
- **Temporal Patterns** - See how interests cluster in time

## Triggers

- **Type:** Cron Schedule
- **Frequency:** Every 6 hours (`0 */6 * * *`)
- **Manual:** Can be triggered via n8n UI "Execute Workflow" button

## Output

### Network Statistics (stored in network_analysis_history)

```json
{
  "networkStats": {
    "totalNotes": 100,
    "totalConnections": 250,
    "averageConnectionStrength": 0.45,
    "conceptBasedConnections": 180,
    "themeBasedConnections": 70,
    "topHubs": [
      {"noteId": 42, "connectionCount": 15, "title": "ADHD Management Systems"},
      {"noteId": 23, "connectionCount": 12, "title": "Productivity Workflows"}
    ],
    "strongestConnections": [
      {"sourceTitle": "Note A", "targetTitle": "Note B", "strength": 0.92}
    ],
    "analyzedAt": "2025-12-31T12:00:00.000Z"
  }
}
```

## Integration Points

### Upstream Dependencies

- **02-llm-processing** - Provides concepts and themes for each note
- **processed_notes table** - Source of analysis data

### Downstream Consumers

- **SeleneChat** - Could use connections for "related notes" feature
- **Obsidian Export** - Could generate graph-based markdown links

## Troubleshooting

### Workflow Not Running

```bash
# Check if container is running
docker ps | grep selene-n8n

# View n8n logs
docker-compose logs -f n8n
```

### No Connections Found

```bash
# Check if processed notes have concepts
sqlite3 data/selene.db "
  SELECT COUNT(*) FROM processed_notes
  WHERE concepts IS NOT NULL AND concepts != '[]';
"
```

### Database Errors

```bash
# Check table exists
sqlite3 data/selene.db ".tables"

# View schema
sqlite3 data/selene.db ".schema note_connections"
sqlite3 data/selene.db ".schema network_analysis_history"
```

## Known Issues

### 1. Missing note_connections Table (CRITICAL)

**Status:** BLOCKING - Workflow will fail
**Impact:** High - Cannot store individual connections
**Issue:** The workflow references `note_connections` table which does not exist in the database schema. Only `network_analysis_history` exists.

**Solution:** Add the table to the database:

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

### 2. No Webhook Trigger

**Status:** By design
**Impact:** Low - Cannot trigger manually via HTTP
**Note:** Use n8n UI to manually execute if needed for testing

## Maintenance

### View Recent Analyses

```bash
sqlite3 data/selene.db "
  SELECT analysis_id, total_notes, total_connections, analyzed_at
  FROM network_analysis_history
  ORDER BY analyzed_at DESC
  LIMIT 5;
"
```

### Clear Analysis History

```bash
# Clear all analysis history
sqlite3 data/selene.db "DELETE FROM network_analysis_history;"

# Clear connections (once table exists)
sqlite3 data/selene.db "DELETE FROM note_connections;"
```

## Next Steps

After workflow is working:
1. Create visualization in SeleneChat
2. Add connection-based recommendations
3. Export connections to Obsidian graph format
