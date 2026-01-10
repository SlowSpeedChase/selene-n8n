# Workflow 03: Pattern Detection

**Status:** Production Ready
**Last Updated:** 2025-12-31

## Overview

This workflow analyzes processed notes to detect theme trends over time. It identifies significant changes in theme frequency (>=20%) and generates insights and recommendations.

## Quick Start

### Automatic Execution
The workflow runs automatically daily at 6:00 AM via cron trigger.

### Manual Execution
```bash
# Trigger via n8n CLI
docker exec selene-n8n n8n execute --id=F4YgT8MYfqGZYObF
```

### Run Tests
```bash
./workflows/03-pattern-detection/scripts/test-with-markers.sh
```

## What It Detects

### Theme Trends
- **What:** Identifies themes with significant frequency changes over 30-day windows
- **Threshold:** >=20% change in frequency (rising or falling)
- **Example:** "Project" theme rising by 35% over last month
- **Confidence:** Based on magnitude of change (0.0 - 0.9)

## Workflow Architecture

```
Cron Trigger (Daily 6am)
        |
        v
Get Theme Trends (SQLite)
  - Query processed_notes
  - Group by theme and week
  - Filter themes with 3+ occurrences
        |
        v
Calculate Theme Trends
  - Compare recent vs historical averages
  - Detect significant changes
  - Generate confidence scores
        |
        v
Store Pattern (SQLite)
  - Insert to detected_patterns table
        |
        v
Generate Insights Report
  - Summarize findings
  - Create recommendations
        |
        v
Store Insights Report (SQLite)
  - Insert to pattern_reports table
```

## Database Tables

### detected_patterns
Stores individual patterns detected:
- pattern_type: "theme_trend"
- pattern_name: e.g., "Theme Trend: Project"
- description: Human-readable summary
- confidence: 0.0 - 0.9 score
- data_points: Number of weeks analyzed
- pattern_data: JSON with detailed metrics
- insights: ADHD-focused recommendations

### pattern_reports
Stores summary reports:
- report_id: Unique identifier
- total_patterns: Count of patterns detected
- key_insights: JSON array of insights
- recommendations: JSON array of recommendations
- rising/falling_trends_count: Trend direction counts

## Configuration

| Setting | Value |
|---------|-------|
| Workflow ID | F4YgT8MYfqGZYObF |
| Trigger | Cron (0 6 * * *) |
| Source Table | processed_notes |
| Target Tables | detected_patterns, pattern_reports |
| Minimum Theme Frequency | 3 per week |
| Trend Threshold | 20% change |

## Data Requirements

For pattern detection to work effectively:
- **Minimum Notes:** 5+ processed notes
- **Theme Coverage:** Multiple themes appearing across weeks
- **Time Span:** Data spanning multiple weeks
- **Frequency:** Themes appearing 3+ times per week

## Output Example

### Pattern Record
```json
{
  "patternType": "theme_trend",
  "patternName": "Theme Trend: Project",
  "description": "The theme 'Project' has been rising by 35.0% over the last 30 days.",
  "confidence": 0.28,
  "dataPoints": 3,
  "patternData": {
    "theme": "project",
    "trendDirection": "rising",
    "percentChange": 35.0,
    "currentFrequency": 5,
    "historicalAverage": 3.7
  },
  "insights": "Growing focus on Project. Consider dedicating more structured time to this area."
}
```

## Troubleshooting

### No patterns detected
- **Check data volume:** Need 5+ processed notes minimum
- **Check time span:** Need data spanning multiple weeks
- **Check theme frequency:** Themes need 3+ occurrences per week
- **Check variation:** Need >=20% change in frequency

### Workflow not running
```bash
# Check if workflow is active in n8n
docker exec selene-n8n sqlite3 /home/node/.n8n/database.sqlite \
  "SELECT active FROM workflow_entity WHERE id='F4YgT8MYfqGZYObF';"
# Should return: 1
```

### Database errors
```bash
# Verify tables exist
sqlite3 data/selene.db ".schema detected_patterns"
sqlite3 data/selene.db ".schema pattern_reports"
```

## Files

```
03-pattern-detection/
    workflow.json           # Main workflow (source of truth)
    README.md               # This file
    CLAUDE.md               # AI context file
    docs/
        STATUS.md           # Test results and history
    scripts/
        test-with-markers.sh  # Automated test suite
    archive/
        workflow-enhanced.json  # Enhanced version (not deployed)
        workflow.backup.json    # Backup
        QUICK-START.md          # Enhanced version docs
        test-patterns.js        # Node.js test script
```

## Related Workflows

- **02-llm-processing:** Extracts themes used for pattern detection
- **04-obsidian-export:** Exports notes (could export pattern insights)
- **05-sentiment-analysis:** Provides additional data for analysis

## ADHD Optimizations

- **Actionable insights:** Not just data, but recommendations
- **Confidence levels:** Focus on high-confidence patterns first
- **Trend direction:** Clear rising/falling indicators
- **Time-based:** Tracks changes over time (visibility into patterns)
