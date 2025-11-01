# Workflow Overview

**Version:** 1.0.0
**Last Updated:** October 30, 2025

## Table of Contents

- [Introduction](#introduction)
- [Workflow Architecture](#workflow-architecture)
- [Workflow Summary](#workflow-summary)
- [Workflow Details](#workflow-details)
- [Workflow Dependencies](#workflow-dependencies)
- [Scheduling & Triggers](#scheduling--triggers)
- [Data Flow Between Workflows](#data-flow-between-workflows)
- [Enabling & Disabling Workflows](#enabling--disabling-workflows)
- [Monitoring & Debugging](#monitoring--debugging)

---

## Introduction

Selene uses six independent n8n workflows to process notes from capture through analysis to export. Each workflow has a single responsibility and can be enabled, disabled, or modified independently.

**Design Philosophy:**
- **Sequential Processing**: One note at a time to avoid resource exhaustion
- **Fail-Safe**: Errors don't cascade; failed notes remain in queue
- **Observable**: Every step visible in n8n's execution history
- **Modular**: Add, remove, or modify workflows without affecting others

---

## Workflow Architecture

```
Input → [WF01: Ingestion] → [WF02: LLM Processing] → Output
                                       ↓
                     ┌─────────────────┴─────────────────┐
                     ↓                                   ↓
         [WF05: Sentiment Analysis]      [WF06: Network Connections]
                     ↓                                   ↓
         [sentiment_history table]       [network_analysis_history]

         [WF03: Pattern Detection]       [WF04: Obsidian Export]
                     ↓                                   ↓
         [detected_patterns table]       [Obsidian Vault Files]
```

---

## Workflow Summary

| # | Name | Trigger | Frequency | Dependencies | Purpose |
|---|------|---------|-----------|--------------|---------|
| **01** | Note Ingestion | Webhook | On-demand | better-sqlite3 | Receive notes, check duplicates, store in DB |
| **02** | LLM Processing | Cron | Every 30s | better-sqlite3, Ollama | Extract concepts & themes with AI |
| **03** | Pattern Detection | Cron | Daily @ 6am | n8n-nodes-sqlite | Analyze theme trends, detect patterns |
| **04** | Obsidian Export | Cron | Daily @ 7am | n8n-nodes-sqlite | Export processed notes as markdown |
| **05** | Sentiment Analysis | Cron | Every 45s | n8n-nodes-sqlite, Ollama | Analyze emotional tone, ADHD markers |
| **06** | Connection Network | Cron | Every 6h | n8n-nodes-sqlite | Calculate note relationships |

---

## Workflow Details

### Workflow 01: Note Ingestion

**File**: `01-ingestion-workflow.json`

**Purpose**: Entry point for all notes into the system.

**Trigger**: Webhook (HTTP POST)
- **Endpoint**: `http://localhost:5678/webhook/api/drafts`
- **Method**: POST
- **Auth**: None (local network trust)

**Input Format**:
```json
{
  "query": {
    "title": "Note Title",
    "content": "Note content goes here...",
    "timestamp": "2025-10-30T10:00:00Z",
    "tags": ["optional", "array"]
  }
}
```

**Processing Steps**:

1. **Parse Note Data**
   - Extract title, content, timestamp from payload
   - Support multiple input formats (query, body, etc.)
   - Validate that content is not empty
   - Calculate word count and character count
   - Extract hashtags from content (#tag format)

2. **Generate Content Hash**
   - Use FNV-1a hash algorithm on trimmed content
   - Creates unique identifier for duplicate detection
   - Hash is deterministic (same content = same hash)

3. **Check for Duplicate**
   - Query database for existing note with same content_hash
   - Uses better-sqlite3 in function node
   - Query: `SELECT id FROM raw_notes WHERE content_hash = ?`

4. **Branch: Is Duplicate?**
   - **YES**: Return response with status "duplicate"
   - **NO**: Continue to storage

5. **Store in Database**
   - Insert into `raw_notes` table
   - Set status = 'pending'
   - Set exported_to_obsidian = 0
   - Record import timestamp

6. **Return Success Response**
   ```json
   {
     "success": true,
     "action": "stored",
     "message": "Note successfully ingested",
     "noteId": 42
   }
   ```

**Dependencies**:
- better-sqlite3 (globally installed)
- SQLite database at `/selene/data/selene.db`

**Error Handling**:
- Empty content: Throws error, returns 400
- Database error: Logs error, treats as new note
- Malformed JSON: n8n handles, returns 400

**Performance**: < 1 second per note

---

### Workflow 02: LLM Processing

**File**: `02-llm-processing-workflow.json`

**Purpose**: Extract concepts and themes from pending notes using AI.

**Trigger**: Cron schedule (every 30 seconds)
- **Schedule**: `*/30 * * * * *` (every 30 seconds)
- **Timezone**: Uses `GENERIC_TIMEZONE` from environment

**Processing Steps**:

1. **Poll for Pending Notes**
   - Query: `SELECT * FROM raw_notes WHERE status='pending' LIMIT 1`
   - Processes one note at a time (sequential)
   - If no pending notes, workflow completes with no action

2. **Prepare LLM Prompt**
   - Construct prompt for concept extraction
   - Include note title and content
   - Request structured JSON response

3. **Call Ollama API**
   - **Endpoint**: `http://host.docker.internal:11434/api/generate`
   - **Model**: mistral:7b (configurable via env)
   - **Stream**: false (wait for complete response)
   - **Timeout**: 120 seconds

**LLM Prompt Template**:
```
Analyze this note and extract:
1. 3-5 key concepts (single words or short phrases)
2. One primary theme (main topic/category)
3. Up to 3 secondary themes (related topics)

Note Title: {{title}}
Note Content: {{content}}

Respond in JSON format:
{
  "concepts": ["concept1", "concept2", ...],
  "primary_theme": "main theme",
  "secondary_themes": ["theme1", "theme2"],
  "confidence": 0.85
}
```

4. **Parse LLM Response**
   - Extract JSON from response
   - Validate structure
   - Handle malformed responses gracefully

5. **Store Processing Results**
   - Insert into `processed_notes` table:
     - `raw_note_id`: Link to original note
     - `concepts`: JSON array of concepts
     - `primary_theme`: Main theme
     - `secondary_themes`: JSON array
     - `theme_confidence`: Confidence score
     - `processed_at`: Current timestamp

6. **Update Note Status**
   - Update `raw_notes` table:
     - Set `status = 'processed'`
     - Set `processed_at = CURRENT_TIMESTAMP`

**Dependencies**:
- better-sqlite3
- Ollama running on host (port 11434)
- Mistral:7b model pulled

**Error Handling**:
- Ollama timeout: Note remains pending, retries on next trigger
- JSON parse error: Logs error, note remains pending
- Database error: Transaction rollback, note stays pending

**Performance**: 10-30 seconds per note (depends on note length and model)

---

### Workflow 03: Pattern Detection

**File**: `03-pattern-detection-workflow.json`

**Purpose**: Analyze theme trends over time and detect emerging patterns.

**Trigger**: Cron schedule (daily at 6:00 AM)
- **Schedule**: `0 6 * * *` (6:00 AM daily)
- **Timezone**: Uses `GENERIC_TIMEZONE` from environment

**Processing Steps**:

1. **Query Theme Frequency (7 days)**
   ```sql
   SELECT
     primary_theme,
     COUNT(*) as count_7d
   FROM processed_notes pn
   JOIN raw_notes rn ON pn.raw_note_id = rn.id
   WHERE rn.created_at >= datetime('now', '-7 days')
   GROUP BY primary_theme
   ORDER BY count_7d DESC
   ```

2. **Query Theme Frequency (30 days)**
   - Same query but with `-30 days`
   - Compare to 7-day data

3. **Query Theme Frequency (90 days)**
   - Same query but with `-90 days`
   - Provides long-term context

4. **Calculate Trend Direction**
   - For each theme:
     - **Rising**: 7d frequency > 30d average
     - **Falling**: 7d frequency < 30d average
     - **Stable**: Within 10% of 30d average
   - Calculate velocity (rate of change)

5. **Compute Confidence Scores**
   - Based on data points available
   - More notes = higher confidence
   - Formula: `min(1.0, data_points / 30)`

6. **Generate Insights**
   - Identify top 3 rising themes
   - Identify top 3 falling themes
   - Detect new themes (only in 7d, not in 30d)
   - Detect dormant themes (in 90d but not 7d)

7. **Store Pattern Data**
   - Insert into `detected_patterns` table:
     - `pattern_type`: 'theme_trend'
     - `pattern_name`: Theme name
     - `description`: Trend description
     - `confidence`: Calculated confidence
     - `data_points`: Number of notes
     - `pattern_data`: JSON with full analysis
     - `insights`: Generated insights text

8. **Create Pattern Report**
   - Insert into `pattern_reports` table:
     - `report_id`: UUID
     - `time_range_start`: 90 days ago
     - `time_range_end`: Today
     - `total_patterns`: Count of patterns
     - `high_confidence_count`: Patterns > 0.7
     - `rising_trends_count`: Rising themes
     - `key_insights`: JSON array
     - `recommendations`: JSON array

**Dependencies**:
- n8n-nodes-sqlite community package
- SQLite database with sufficient history (ideally 90+ days)

**Error Handling**:
- Insufficient data: Generates report noting limited data
- Database errors: Logs and fails gracefully
- No themes found: Creates empty report

**Performance**: 5-15 seconds (depends on database size)

**Output Example**:
```json
{
  "rising_themes": [
    {"theme": "productivity", "velocity": 2.3, "confidence": 0.87},
    {"theme": "health", "velocity": 1.8, "confidence": 0.75}
  ],
  "falling_themes": [
    {"theme": "work", "velocity": -1.5, "confidence": 0.82}
  ],
  "new_themes": ["meditation", "reading"],
  "insights": [
    "Productivity theme showing 130% increase over last 7 days",
    "Health becoming more frequent in recent notes"
  ]
}
```

---

### Workflow 04: Obsidian Export

**File**: `04-obsidian-export-workflow.json`

**Purpose**: Export processed notes as markdown files to Obsidian vault.

**Trigger**: Cron schedule (daily at 7:00 AM)
- **Schedule**: `0 7 * * *` (7:00 AM daily)
- **Timezone**: Uses `GENERIC_TIMEZONE` from environment

**Processing Steps**:

1. **Query Notes Ready for Export**
   ```sql
   SELECT
     rn.id,
     rn.title,
     rn.content,
     rn.created_at,
     rn.word_count,
     rn.tags,
     pn.concepts,
     pn.primary_theme,
     pn.secondary_themes,
     pn.theme_confidence
   FROM raw_notes rn
   JOIN processed_notes pn ON rn.id = pn.raw_note_id
   WHERE rn.exported_to_obsidian = 0
     AND rn.status = 'processed'
   ORDER BY rn.created_at ASC
   LIMIT 50
   ```
   - Exports up to 50 notes per day
   - Oldest first (FIFO)

2. **For Each Note: Build Markdown**
   - Extract year from created_at
   - Parse concepts and themes from JSON
   - Generate YAML frontmatter
   - Create wikilinks for concepts and themes

**Markdown Template**:
```markdown
---
title: {{title}}
created: {{created_at}}
imported: {{imported_at}}
processed: {{processed_at}}
word_count: {{word_count}}
concepts: [{{concepts}}]
primary_theme: {{primary_theme}}
secondary_themes: [{{secondary_themes}}]
confidence: {{theme_confidence}}
tags: [{{tags}}]
---

# {{title}}

{{content}}

---

## Extracted Concepts

{{#each concepts}}
- [[{{this}}]]
{{/each}}

## Themes

**Primary**: [[{{primary_theme}}]]

**Secondary**:
{{#each secondary_themes}}
- [[{{this}}]]
{{/each}}

---

*Processed by Selene on {{processed_at}}*
```

3. **Write Note File**
   - **Path**: `/obsidian/Selene/Sources/{{year}}/{{sanitized_title}}.md`
   - Sanitize filename: Remove special characters
   - Create directory if doesn't exist
   - Write markdown content

4. **Update Concept Index Files**
   - For each concept in note:
     - File: `/obsidian/Selene/Concepts/{{concept}}.md`
     - Append note reference with backlink
     - Create file if doesn't exist

**Concept Index Template**:
```markdown
# {{concept}}

Notes containing this concept:

- [[{{note_title_1}}]] ({{date}})
- [[{{note_title_2}}]] ({{date}})
...
```

5. **Update Theme Index Files**
   - Similar to concept indexes
   - File: `/obsidian/Selene/Themes/{{theme}}.md`
   - List all notes with this theme

6. **Mark as Exported**
   - Update `raw_notes` table:
     - Set `exported_to_obsidian = 1`
     - Set `exported_at = CURRENT_TIMESTAMP`

**Dependencies**:
- n8n-nodes-sqlite
- File system write access to Obsidian vault
- Vault path configured: `/obsidian` (maps to host path)

**Error Handling**:
- File write failure: Log error, note remains not exported
- Directory creation failure: Workflow fails, retries next day
- Invalid filename: Sanitize more aggressively, retry

**Performance**: ~1 second per note (50 notes in ~50 seconds)

**Vault Structure**:
```
/obsidian/Selene/
├── Sources/
│   ├── 2024/
│   │   ├── My First Note.md
│   │   └── Another Note.md
│   └── 2025/
│       └── Recent Note.md
├── Concepts/
│   ├── productivity.md
│   ├── health.md
│   └── work.md
└── Themes/
    ├── personal-development.md
    ├── project-ideas.md
    └── daily-reflections.md
```

---

### Workflow 05: Sentiment Analysis

**File**: `05-sentiment-analysis-workflow.json`

**Purpose**: Analyze emotional tone, detect ADHD markers, and track mental state.

**Trigger**: Cron schedule (every 45 seconds)
- **Schedule**: `*/45 * * * * *` (every 45 seconds)
- **Timezone**: Uses `GENERIC_TIMEZONE` from environment

**Processing Steps**:

1. **Poll for Unanalyzed Notes**
   ```sql
   SELECT
     pn.id as processed_note_id,
     pn.raw_note_id,
     rn.title,
     rn.content,
     pn.concepts,
     pn.primary_theme
   FROM processed_notes pn
   JOIN raw_notes rn ON pn.raw_note_id = rn.id
   WHERE pn.sentiment_analyzed = 0
   LIMIT 1
   ```
   - Processes one note at a time

2. **Prepare Sentiment Prompt**
   - Construct specialized prompt for emotional analysis
   - Include note content and context

**Sentiment Prompt Template**:
```
Analyze the emotional tone and mental state in this note:

Title: {{title}}
Content: {{content}}

Provide analysis in JSON format:
{
  "overall_sentiment": "positive|negative|neutral|mixed",
  "sentiment_score": 0.75,  // -1 to 1 scale
  "emotional_tone": "excited|anxious|calm|frustrated|...",
  "energy_level": "high|medium|low",
  "stress_indicators": 0-5 scale,
  "key_emotions": ["emotion1", "emotion2"],
  "adhd_markers": {
    "hyperfocus": true/false,
    "task_switching": true/false,
    "overwhelm": true/false,
    "breakthrough": true/false
  },
  "analysis_confidence": 0.85
}
```

3. **Call Ollama API**
   - Same endpoint as Workflow 02
   - Model: mistral:7b
   - Timeout: 60 seconds (shorter than concept extraction)

4. **Parse Sentiment Response**
   - Extract JSON from LLM response
   - Validate all required fields
   - Apply defaults if fields missing

5. **Store Sentiment Data**
   - Insert into `sentiment_history` table:
     - `processed_note_id`: Link to processed_notes
     - `raw_note_id`: Link to raw_notes
     - `overall_sentiment`: positive/negative/neutral/mixed
     - `sentiment_score`: -1.0 to 1.0
     - `emotional_tone`: Primary emotion detected
     - `energy_level`: high/medium/low
     - `stress_indicators`: 0-5 scale
     - `key_emotions`: JSON array
     - `adhd_markers`: JSON object
     - `analysis_confidence`: 0.0-1.0

6. **Update Processed Notes**
   - Update `processed_notes` table:
     - Set `sentiment_analyzed = 1`
     - Copy key fields: `overall_sentiment`, `sentiment_score`, etc.
     - Set `sentiment_analyzed_at = CURRENT_TIMESTAMP`

**Dependencies**:
- n8n-nodes-sqlite
- Ollama (same as Workflow 02)
- Mistral:7b model

**Error Handling**:
- Ollama timeout: Note remains unanalyzed, retry later
- Invalid JSON: Log error, note stays unanalyzed
- Missing fields: Use defaults, complete analysis

**Performance**: 8-20 seconds per note

**Use Cases**:
- Track emotional patterns over time
- Identify stress periods
- Detect ADHD-specific patterns (hyperfocus, overwhelm)
- Correlate emotions with themes/concepts

**Example Output**:
```json
{
  "overall_sentiment": "positive",
  "sentiment_score": 0.72,
  "emotional_tone": "excited",
  "energy_level": "high",
  "stress_indicators": 2,
  "key_emotions": ["enthusiasm", "curiosity", "motivation"],
  "adhd_markers": {
    "hyperfocus": true,
    "task_switching": false,
    "overwhelm": false,
    "breakthrough": true
  },
  "analysis_confidence": 0.88
}
```

---

### Workflow 06: Connection Network

**File**: `06-connection-network-workflow.json`

**Purpose**: Discover relationships between notes based on shared concepts and themes.

**Trigger**: Cron schedule (every 6 hours)
- **Schedule**: `0 */6 * * *` (every 6 hours: 12am, 6am, 12pm, 6pm)
- **Timezone**: Uses `GENERIC_TIMEZONE` from environment

**Processing Steps**:

1. **Query All Processed Notes**
   ```sql
   SELECT
     pn.id,
     pn.raw_note_id,
     pn.concepts,
     pn.primary_theme,
     pn.secondary_themes,
     rn.title,
     rn.created_at
   FROM processed_notes pn
   JOIN raw_notes rn ON pn.raw_note_id = rn.id
   WHERE rn.status = 'processed'
   ORDER BY rn.created_at DESC
   LIMIT 1000
   ```
   - Analyzes up to 1000 most recent notes
   - Prevents performance issues with huge datasets

2. **Parse Concepts and Themes**
   - Extract JSON arrays from database
   - Build concept/theme index for each note
   - Create lookup tables

3. **Calculate Pairwise Connections**
   - For each pair of notes (N×(N-1)/2 comparisons):
     - Compare concept overlap
     - Compare theme overlap
     - Calculate Jaccard similarity

**Connection Strength Formula**:
```
concept_overlap = |concepts_A ∩ concepts_B| / |concepts_A ∪ concepts_B|
theme_overlap = (primary_match * 2.0) + (secondary_match * 1.0)
connection_strength = (concept_overlap * 0.6) + (theme_overlap * 0.4)
```

4. **Filter Weak Connections**
   - Only store connections with strength ≥ 0.3
   - Reduces noise from spurious connections
   - Focuses on meaningful relationships

5. **Store Network Statistics**
   - Insert into `network_analysis_history` table:
     - `analysis_id`: UUID
     - `total_notes`: Number of notes analyzed
     - `total_connections`: Connections found
     - `avg_connection_strength`: Mean strength
     - `concept_based_count`: Connections via concepts
     - `theme_based_count`: Connections via themes
     - `network_stats`: JSON with detailed stats

**Network Stats JSON**:
```json
{
  "strongest_connections": [
    {
      "note_a": "Note Title 1",
      "note_b": "Note Title 2",
      "strength": 0.87,
      "shared_concepts": ["concept1", "concept2"],
      "shared_themes": ["theme1"]
    }
  ],
  "most_connected_notes": [
    {
      "note_id": 42,
      "title": "Hub Note",
      "connection_count": 23,
      "avg_strength": 0.65
    }
  ],
  "isolated_notes": [
    {
      "note_id": 99,
      "title": "Standalone Note",
      "connection_count": 0
    }
  ],
  "concept_centrality": {
    "productivity": 0.82,
    "health": 0.67,
    "work": 0.54
  }
}
```

6. **Optional: Store Individual Connections**
   - If `note_connections` table exists:
     - Store each connection as a row
     - Enables graph visualization
     - Can be used for future features

**Dependencies**:
- n8n-nodes-sqlite
- Sufficient database history (works better with 100+ notes)

**Error Handling**:
- Insufficient notes: Creates minimal report
- Large dataset timeout: Reduces LIMIT in query
- JSON parse errors: Skips malformed notes

**Performance**:
- 100 notes: ~5 seconds
- 500 notes: ~30 seconds
- 1000 notes: ~60 seconds
- Scales O(N²) so limit is important

**Use Cases**:
- Discover unexpected connections between ideas
- Identify "hub" notes that connect many concepts
- Find isolated notes that might need better linking
- Generate "related notes" suggestions
- Visualize knowledge graph (future feature)

---

## Workflow Dependencies

### Package Dependencies

| Workflow | Package | Purpose |
|----------|---------|---------|
| 01 | better-sqlite3 | Direct SQLite access in function nodes |
| 02 | better-sqlite3 | Direct SQLite access in function nodes |
| 03 | n8n-nodes-sqlite | Structured SQLite queries |
| 04 | n8n-nodes-sqlite | Structured SQLite queries + File ops |
| 05 | n8n-nodes-sqlite | Structured SQLite queries |
| 06 | n8n-nodes-sqlite | Structured SQLite queries |

### External Dependencies

| Workflow | External Service | Required? |
|----------|-----------------|-----------|
| 01 | None | No |
| 02 | Ollama (host:11434) | Yes |
| 03 | None | No |
| 04 | Obsidian vault (file access) | No (just writes files) |
| 05 | Ollama (host:11434) | Yes |
| 06 | None | No |

### Workflow Dependencies (Execution Order)

```
WF01 (Ingestion) MUST run before WF02
WF02 (LLM Processing) MUST run before WF03, WF04, WF05, WF06
WF03, WF04, WF05, WF06 are independent of each other
```

**Recommendation**: Always enable workflows in order 01 → 02 → (others)

---

## Scheduling & Triggers

### Cron Syntax Reference

```
 ┌─────────────── second (0-59)
 │ ┌───────────── minute (0-59)
 │ │ ┌─────────── hour (0-23)
 │ │ │ ┌───────── day of month (1-31)
 │ │ │ │ ┌─────── month (1-12)
 │ │ │ │ │ ┌───── day of week (0-6, Sunday=0)
 │ │ │ │ │ │
 * * * * * *
```

### Current Schedules

| Workflow | Trigger Type | Schedule | Next Run Calculation |
|----------|-------------|----------|---------------------|
| 01 | Webhook | On-demand | When HTTP POST received |
| 02 | Cron | `*/30 * * * * *` | Every 30 seconds |
| 03 | Cron | `0 6 * * *` | Every day at 6:00 AM |
| 04 | Cron | `0 7 * * *` | Every day at 7:00 AM |
| 05 | Cron | `*/45 * * * * *` | Every 45 seconds |
| 06 | Cron | `0 */6 * * *` | Every 6 hours (12am, 6am, 12pm, 6pm) |

### Customizing Schedules

To change a workflow schedule:

1. Open workflow in n8n
2. Click on trigger node (usually first node)
3. Modify cron expression
4. Click "Execute Workflow" to test
5. Save workflow

**Examples**:

- Process faster: Change WF02 to `*/15 * * * * *` (every 15 seconds)
- Export more often: Change WF04 to `0 */3 * * *` (every 3 hours)
- Reduce load: Change WF05 to `0 */5 * * * *` (every 5 minutes)

---

## Data Flow Between Workflows

### Linear Flow (Main Pipeline)

```
[WF01: Ingestion]
  ↓ writes to raw_notes (status='pending')
[WF02: LLM Processing]
  ↓ writes to processed_notes, updates raw_notes (status='processed')
[WF04: Obsidian Export]
  ↓ reads processed_notes + raw_notes, writes markdown files
[Done]
```

### Parallel Analysis Flows

```
[WF02: LLM Processing]
  ↓ (processed_notes available)
  ├──→ [WF05: Sentiment Analysis]
  │      ↓ writes to sentiment_history
  │      └──→ Updates processed_notes (sentiment_analyzed=1)
  │
  └──→ [WF06: Connection Network]
         ↓ reads all processed_notes
         └──→ Writes to network_analysis_history
```

### Aggregate Analysis Flow

```
[Many processed_notes accumulated]
  ↓
[WF03: Pattern Detection]
  ↓ aggregates themes across time windows
  └──→ Writes to detected_patterns, pattern_reports
```

### Database State Transitions

```
Note Lifecycle:

raw_notes:
  status='pending'
    → (WF02) →
  status='processed'
    → (WF04) →
  exported_to_obsidian=1

processed_notes:
  sentiment_analyzed=0
    → (WF05) →
  sentiment_analyzed=1
```

---

## Enabling & Disabling Workflows

### Recommended Activation Order

**Phase 1: Core Pipeline**
1. Enable Workflow 01 (Ingestion)
2. Test by sending a note via webhook
3. Enable Workflow 02 (LLM Processing)
4. Wait 30 seconds, verify note is processed

**Phase 2: Export**
5. Enable Workflow 04 (Obsidian Export)
6. Manually trigger to test
7. Check Obsidian vault for exported files

**Phase 3: Advanced Analysis**
8. Enable Workflow 05 (Sentiment Analysis) - optional
9. Enable Workflow 06 (Connection Network) - optional
10. Enable Workflow 03 (Pattern Detection) - optional

### Disabling Workflows

**To temporarily disable a workflow:**
1. Open workflow in n8n
2. Toggle "Active" switch in top-right to OFF
3. Workflow stops triggering immediately

**To disable while keeping data:**
- Disable WF05 if sentiment analysis not needed
- Disable WF06 if connection network too slow
- Disable WF03 if pattern detection not useful yet

**Safe to disable:**
- WF03, WF05, WF06 are optional (no impact on core pipeline)

**Do NOT disable:**
- WF01 (breaks note ingestion)
- WF02 (notes stay pending forever)
- WF04 (notes never reach Obsidian)

---

## Monitoring & Debugging

### Viewing Execution History

1. Open n8n: http://localhost:5678
2. Click "Executions" in left sidebar
3. See list of all workflow runs

**Execution States:**
- **Success** (green): Workflow completed without errors
- **Error** (red): Workflow failed, see error details
- **Running** (blue): Currently executing
- **Waiting** (yellow): Waiting for trigger

### Debugging a Failed Workflow

1. **Click on failed execution** in Executions list
2. **See visual flow** with error highlighted
3. **Click on failed node** to see:
   - Input data
   - Error message
   - Stack trace (if available)
4. **Common fixes**:
   - Ollama not running: Start Ollama on host
   - Database locked: Restart n8n container
   - Invalid JSON: Check LLM response format

### Manual Workflow Execution

**To test a workflow manually:**

1. Open workflow in editor
2. Click "Execute Workflow" button (top-right)
3. Watch nodes light up as they execute
4. Click on each node to see input/output data

**For webhook workflows (WF01):**
- Use "Listen for Test Webhook" button
- Send test POST request
- See webhook payload in node

### Monitoring Active Workflows

**Check if workflows are running:**

```bash
# View n8n logs
docker-compose logs -f n8n

# Filter for workflow executions
docker-compose logs -f n8n | grep "Workflow executed"

# Check last 100 lines
docker-compose logs --tail=100 n8n
```

### Performance Monitoring

**Check workflow execution times:**

1. Go to Executions
2. Sort by "Duration"
3. Identify slow workflows

**Common slow operations:**
- WF02: Ollama calls (10-30s)
- WF05: Ollama calls (8-20s)
- WF06: Network calculations (10-60s with many notes)

**Optimization tips:**
- Reduce Ollama model size (7b → 3b for faster inference)
- Limit WF06 to fewer notes (change LIMIT in query)
- Increase schedule intervals to reduce load

### Database Health Checks

**Check note processing status:**

```bash
# Count notes by status
sqlite3 data/selene.db "
  SELECT status, COUNT(*)
  FROM raw_notes
  GROUP BY status;
"

# Check pending backlog
sqlite3 data/selene.db "
  SELECT COUNT(*) as pending_count
  FROM raw_notes
  WHERE status='pending';
"

# Check sentiment analysis backlog
sqlite3 data/selene.db "
  SELECT COUNT(*) as unanalyzed_count
  FROM processed_notes
  WHERE sentiment_analyzed=0;
"

# Check export backlog
sqlite3 data/selene.db "
  SELECT COUNT(*) as not_exported_count
  FROM raw_notes
  WHERE exported_to_obsidian=0 AND status='processed';
"
```

---

## Troubleshooting Common Issues

### Issue: Notes stuck in "pending" status

**Symptoms**: Notes appear in database but never get processed

**Causes**:
- Workflow 02 is not active
- Ollama is not running
- Ollama connection failed

**Solutions**:
```bash
# Check if WF02 is active (green toggle in n8n UI)

# Check Ollama status
curl http://localhost:11434/api/tags

# If not running:
ollama serve

# Check n8n can reach Ollama
docker exec selene-n8n wget -qO- http://host.docker.internal:11434/api/tags
```

### Issue: Workflow 04 not exporting files

**Symptoms**: Notes marked as processed but not in Obsidian vault

**Causes**:
- Vault path incorrect
- Permission issues
- Workflow not active

**Solutions**:
```bash
# Check vault path exists
ls -la /Users/chaseeasterling/selene-n8n/vault/Selene/

# Check permissions
ls -la vault/

# Manually trigger WF04
# In n8n: Open WF04 → Click "Execute Workflow"
```

### Issue: "Database is locked" errors

**Symptoms**: Workflows fail with SQLite lock error

**Causes**:
- Multiple workflows writing simultaneously
- Long-running query blocking writes

**Solutions**:
```bash
# Restart n8n (releases all locks)
docker-compose restart n8n

# Check for long-running processes
ps aux | grep sqlite3

# Stagger workflow schedules to avoid conflicts
```

### Issue: Ollama timeouts during processing

**Symptoms**: Workflow 02 or 05 fails with "timeout" error

**Causes**:
- Model too large for hardware
- Note content too long
- Ollama under heavy load

**Solutions**:
1. Use smaller model: `OLLAMA_MODEL=mistral:7b-instruct-q4_0`
2. Increase timeout in workflow HTTP Request node (default: 120s)
3. Limit note length in WF01 (truncate > 10,000 chars)

---

## Next Steps

- **[Individual Workflow Docs](../workflows/)** - Detailed guides for each workflow
- **[API Reference](../api/webhooks.md)** - Webhook API specifications
- **[Troubleshooting](../troubleshooting/workflows.md)** - Advanced workflow debugging

---

**Last Updated**: October 30, 2025
**Author**: Chase Easterling
**Version**: 1.0.0
