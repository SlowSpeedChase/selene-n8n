# Workflow 03: Pattern Detection (Enhanced)

**Status:** Ready for Testing
**Last Updated:** 2025-11-02

## Overview

This workflow analyzes processed notes to detect meaningful patterns in concepts, themes, and sentiment. It provides insights into your thinking patterns, focus areas, and emotional states.

## What It Detects

### 1. Concept Clusters
- **What:** Identifies concepts that frequently appear together across notes
- **Example:** "project" + "deadline" appearing together 5 times
- **Insight:** Reveals connected ideas in your thinking
- **Confidence:** Based on co-occurrence frequency and strength

### 2. Dominant Concepts
- **What:** Finds concepts that appear frequently across multiple notes
- **Example:** "ADHD" mentioned in 8 different notes spanning 3 themes
- **Insight:** Core ideas you're currently focused on
- **Confidence:** Based on frequency and theme spread

### 3. Energy Patterns
- **What:** Analyzes distribution of energy levels (high/medium/low)
- **Example:** 60% of notes show "high" energy
- **Insight:** Your typical mental/physical energy state
- **Confidence:** Based on percentage of occurrence

### 4. Sentiment Patterns
- **What:** Tracks overall sentiment distribution (positive/negative/neutral)
- **Example:** 70% positive sentiment with average score 0.8
- **Insight:** Emotional tone of your recent thinking
- **Confidence:** Based on consistency and sample size

### 5. Emotional Tone Patterns
- **What:** Identifies dominant emotional tones (determined, anxious, excited, etc.)
- **Example:** "determined" appearing in 35% of notes
- **Insight:** Recurring emotional states
- **Confidence:** Based on frequency

## Triggers

### Automatic
- **Schedule:** Daily at 6am
- **Purpose:** Regular pattern analysis to track trends over time

### On-Demand
- **Webhook:** `POST /webhook/pattern-analysis`
- **Purpose:** Run analysis anytime (useful after adding many notes)
- **Response:** JSON with detected patterns and insights

## Workflow Architecture

```
Trigger (Cron or Webhook)
  ↓
Merge Triggers
  ↓
  ├─→ Get All Concepts → Analyze Concept Clusters ─┐
  │                                                  ↓
  └─→ Get Sentiment Data → Analyze Sentiment Patterns → Merge All Patterns
                                                          ↓
                                                        Store Pattern (for each)
                                                          ↓
                                                        Generate Insights Report
                                                          ↓
                                                        Store Report
                                                          ↓
                                                        Return Response
```

## Database Storage

### `detected_patterns` Table
Stores individual patterns detected:
- Pattern type (concept_cluster, dominant_concept, energy_pattern, etc.)
- Pattern name and description
- Confidence score (0.0 - 1.0)
- Time range and data points
- Detailed pattern data (JSON)
- Actionable insights

### `pattern_reports` Table
Stores summary reports:
- Report ID and generation timestamp
- Total patterns detected
- Confidence level breakdown
- Key insights (array)
- Recommendations (array)
- Full pattern summary

## Output Example

### Webhook Response
```json
{
  "success": true,
  "reportId": "pattern_report_1730512345678",
  "patternsDetected": 8,
  "message": "Pattern analysis complete: 8 patterns detected",
  "keyInsights": [
    "🎯 Found 8 patterns across your notes.",
    "✨ 5 high-confidence patterns detected with strong evidence.",
    "📊 3 Concept Cluster patterns identified.",
    "📊 2 Energy Pattern patterns identified."
  ],
  "recommendations": [
    "💡 Strong concept connection detected: project + deadline. Consider creating a dedicated note exploring this relationship.",
    "⚡ High energy pattern! Great time to tackle challenging or creative tasks.",
    "📚 Core concepts emerging: ADHD, Project Management. These could form the foundation for deeper exploration or documentation."
  ]
}
```

## Minimum Data Requirements

- **Concept Clusters:** At least 5 notes with concepts
- **Dominant Concepts:** At least 3 mentions of a concept
- **Energy Patterns:** At least 3 notes with sentiment analysis
- **Sentiment Patterns:** At least 3 notes with sentiment analysis

## Testing

### Manual Test via Webhook

```bash
# Trigger pattern analysis
curl -X POST http://localhost:5678/webhook/pattern-analysis

# Expected: JSON response with detected patterns
```

### Database Verification

```sql
-- Check detected patterns
SELECT
  pattern_type,
  pattern_name,
  confidence,
  data_points
FROM detected_patterns
ORDER BY discovered_at DESC
LIMIT 10;

-- Check latest report
SELECT
  report_id,
  total_patterns,
  high_confidence_count,
  key_insights,
  recommendations
FROM pattern_reports
ORDER BY generated_at DESC
LIMIT 1;
```

## Pattern Confidence Levels

- **High (0.7-1.0):** Strong evidence, actionable insights
- **Medium (0.4-0.7):** Emerging pattern, worth monitoring
- **Low (0.0-0.4):** Weak signal, needs more data

## ADHD Optimizations

- **Visual indicators** in insights (🎯, ✨, 📊, 💡, ⚡, 📚)
- **Actionable recommendations** - not just data
- **Energy-aware** - patterns consider your energy levels
- **Immediate feedback** - webhook returns results instantly

## Future Enhancements

Potential additions (not yet implemented):
- Time-of-day patterns (when you're most productive)
- Theme trends (weekly/monthly changes)
- Concept network visualization
- Pattern anomaly detection
- Correlation with calendar events

## Troubleshooting

### No patterns detected
- Check if you have enough notes (need 5+ with concepts/sentiment)
- Verify processed_notes has sentiment_analyzed = 1
- Check if concepts are being extracted properly

### Low confidence patterns only
- Normal for small datasets
- Confidence increases with more data
- Continue capturing notes

### Patterns not stored
- Check database permissions
- Verify table schema matches expected structure
- Check n8n execution logs for errors

## Related Workflows

- **02-llm-processing:** Extracts concepts used for clustering
- **05-sentiment-analysis:** Provides sentiment data for pattern detection
- **04-obsidian-export:** Could export pattern insights (future enhancement)

## Files

- `workflow.json` - Original theme trend workflow
- `workflow-enhanced.json` - New multi-pattern detection workflow
- `README.md` - This file
