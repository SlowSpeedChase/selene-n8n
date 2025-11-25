# 03-Pattern Detection Workflow Context

## Purpose

Analyzes processed notes to detect emerging patterns, themes, and trends over time. Identifies recurring concepts and tracks theme evolution in the knowledge base.

## Tech Stack

- better-sqlite3 for database operations
- Temporal analysis (date-based grouping)
- Statistical aggregation (COUNT, frequency analysis)
- JSON array manipulation for pattern matching

## Key Files

- workflow.json (144 lines) - Main workflow definition
- README.md - Quick start and overview
- docs/STATUS.md - Test results and current status

## Data Flow

1. **Query Processed Notes** - SELECT from processed_notes with date range
2. **Extract Themes** - Parse JSON themes from all notes
3. **Calculate Frequency** - COUNT occurrences of each theme
4. **Identify Trends** - Compare current vs. historical frequencies
5. **Store Patterns** - INSERT detected patterns into detected_patterns table
6. **Generate Report** - Summarize findings in pattern_reports table

## Common Patterns

### Theme Extraction
```javascript
// Parse JSON themes from all notes
const notes = db.prepare('SELECT themes FROM processed_notes WHERE test_run = ?').all(testRun);
const allThemes = notes.flatMap(row => JSON.parse(row.themes || '[]'));
```

### Frequency Analysis
```javascript
// Count theme occurrences
const themeFreq = {};
allThemes.forEach(theme => {
    themeFreq[theme] = (themeFreq[theme] || 0) + 1;
});

// Sort by frequency
const topThemes = Object.entries(themeFreq)
    .sort((a, b) => b[1] - a[1])
    .slice(0, 10);
```

### Trend Detection
```javascript
// Compare current week vs. previous week
const currentWeek = getThemes(weekStart, weekEnd);
const previousWeek = getThemes(weekStart - 7days, weekEnd - 7days);

// Calculate change
const trending = currentWeek.map(theme => ({
    theme: theme.name,
    current: theme.count,
    previous: previousWeek[theme.name] || 0,
    change: theme.count - (previousWeek[theme.name] || 0)
}));
```

## Testing

### Run Tests
```bash
cd workflows/03-pattern-detection
./scripts/test-with-markers.sh
```

### Test Data Requirements
- Requires processed_notes with themes populated
- Needs multiple notes across different dates
- Test markers ensure isolation

## Database Schema

**Table: detected_patterns**
```sql
CREATE TABLE detected_patterns (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    pattern_type TEXT,              -- 'theme_trend', 'concept_cluster', etc.
    pattern_data TEXT,               -- JSON of pattern details
    frequency INTEGER,
    first_seen DATETIME,
    last_seen DATETIME,
    confidence_score REAL,
    test_run TEXT
);
```

**Table: pattern_reports**
```sql
CREATE TABLE pattern_reports (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    report_date DATE,
    summary TEXT,                    -- JSON summary of patterns
    top_themes TEXT,                 -- JSON array of top themes
    created_at DATETIME DEFAULT CURRENT_TIMESTAMP,
    test_run TEXT
);
```

## Do NOT

- **NEVER run without processed notes** - will produce empty results
- **NEVER skip date range filtering** - processing all notes is expensive
- **NEVER ignore confidence scores** - low confidence patterns are noise
- **NEVER store duplicate patterns** - check before inserting

## Related Context

@workflows/03-pattern-detection/README.md
@workflows/02-llm-processing/CLAUDE.md
@database/schema.sql
@workflows/CLAUDE.md
