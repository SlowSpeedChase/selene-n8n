# 03-Pattern Detection Workflow Context

## Purpose

Analyzes processed notes to detect theme trends over time. Identifies significant changes (>=20%) in theme frequency across 30-day windows and generates ADHD-focused insights and recommendations.

## Tech Stack

- better-sqlite3 for database operations
- Temporal analysis (strftime for week grouping)
- Statistical aggregation (COUNT, AVG)
- Trend detection (percent change calculation)

## Key Files

- `workflow.json` (144 lines) - Main workflow definition (source of truth)
- `README.md` - Quick start and overview
- `docs/STATUS.md` - Test results and current status
- `scripts/test-with-markers.sh` - Automated test script

## Workflow ID

**n8n ID:** F4YgT8MYfqGZYObF

## Data Flow

1. **Cron Trigger** - Runs daily at 6:00 AM
2. **Get Theme Trends** - Query processed_notes for theme frequency by week
3. **Calculate Theme Trends** - Compare recent vs historical averages
4. **Store Pattern** - INSERT into detected_patterns table
5. **Generate Insights Report** - Create summary with recommendations
6. **Store Report** - INSERT into pattern_reports table

## Common Patterns

### Theme Query
```javascript
const query = `
  SELECT
    primary_theme,
    strftime('%Y-W%W', processed_at) as week,
    COUNT(*) as frequency,
    MIN(processed_at) as week_start
  FROM processed_notes
  WHERE processed_at >= date('now', '-30 days')
  GROUP BY primary_theme, week
  HAVING COUNT(*) >= 3
  ORDER BY primary_theme, week`;
```

### Trend Detection
```javascript
// Compare recent (last 2 weeks) vs historical average
const recentAvg = frequencies.slice(-2).reduce((a, b) => a + b, 0) / 2;
const historicalAvg = frequencies.slice(0, -2).reduce((a, b) => a + b, 0) / (frequencies.length - 2);
const percentChange = ((recentAvg - historicalAvg) / historicalAvg) * 100;

// Only flag significant changes (>=20%)
if (Math.abs(percentChange) >= 20) {
  // Create pattern...
}
```

### Confidence Scoring
```javascript
// Confidence based on magnitude of change (capped at 0.9)
const confidence = Math.min(0.9, Math.abs(percentChange) / 100 * 0.8);
```

## Testing

### Run Tests
```bash
./workflows/03-pattern-detection/scripts/test-with-markers.sh
```

### Manual Trigger
```bash
docker exec selene-n8n n8n execute --id=F4YgT8MYfqGZYObF
```

### Verify Results
```sql
-- Check detected patterns
SELECT pattern_type, pattern_name, confidence, discovered_at
FROM detected_patterns
ORDER BY discovered_at DESC
LIMIT 5;

-- Check reports
SELECT report_id, total_patterns, generated_at
FROM pattern_reports
ORDER BY generated_at DESC
LIMIT 3;
```

## Database Schema

**Table: detected_patterns**
```sql
CREATE TABLE detected_patterns (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    pattern_type TEXT NOT NULL,
    pattern_name TEXT NOT NULL,
    description TEXT,
    confidence REAL,
    data_points INTEGER,
    pattern_data TEXT,  -- JSON
    time_range_start DATETIME,
    time_range_end DATETIME,
    insights TEXT,
    discovered_at DATETIME DEFAULT CURRENT_TIMESTAMP,
    is_active INTEGER DEFAULT 1
);
```

**Table: pattern_reports**
```sql
CREATE TABLE pattern_reports (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    report_id TEXT UNIQUE NOT NULL,
    generated_at DATETIME DEFAULT CURRENT_TIMESTAMP,
    time_range_start DATETIME,
    time_range_end DATETIME,
    total_patterns INTEGER,
    high_confidence_count INTEGER,
    medium_confidence_count INTEGER,
    low_confidence_count INTEGER,
    rising_trends_count INTEGER,
    falling_trends_count INTEGER,
    key_insights TEXT,
    recommendations TEXT,
    report_data TEXT
);
```

## Do NOT

- **NEVER run without processed notes** - Workflow requires data from 02-llm-processing
- **NEVER skip date range filtering** - Processing all notes is expensive
- **NEVER store duplicate patterns** - Consider adding deduplication if needed
- **NEVER ignore confidence scores** - Low confidence patterns may be noise
- **NEVER modify workflow.json without updating STATUS.md**

## Data Requirements

- **Minimum Notes:** 5+ processed notes
- **Theme Coverage:** Multiple themes appearing across weeks
- **Time Span:** Data spanning multiple weeks
- **Frequency Threshold:** Themes appearing 3+ times per week
- **Change Threshold:** >=20% frequency change to detect as trend

## Archived Files

The `archive/` directory contains:
- `workflow-enhanced.json` - More comprehensive version with webhook support and additional pattern types (energy, sentiment, concept clustering)
- `workflow.backup.json` - Backup of original workflow
- `QUICK-START.md` - Quick start for enhanced version
- `test-patterns.js` - Node.js test script

These files are preserved but not deployed to n8n.

## Related Context

- `@workflows/03-pattern-detection/README.md`
- `@workflows/03-pattern-detection/docs/STATUS.md`
- `@workflows/02-llm-processing/CLAUDE.md`
- `@database/schema.sql`
- `@workflows/CLAUDE.md`
