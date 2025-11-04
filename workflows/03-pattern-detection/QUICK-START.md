# Pattern Detection - Quick Start Guide

## What We Built

An enhanced pattern detection workflow that analyzes your 36 notes and finds:

### ✅ Detected Patterns (From Your Data)

**Energy Patterns:**
- 🔋 **75% Medium Energy** - Your dominant energy state
- ⚡ 19.4% High Energy
- 🪫 5.6% Low Energy

**Sentiment Patterns:**
- ✅ **44.4% Positive** - Largest sentiment group
- ⚖️ **36.1% Neutral** - Second largest
- 😔 19.4% Negative

**Emotional Tone:**
- 🎯 **38.9% Determined** - Your primary emotional tone
- 😌 22.2% Calm
- 😤 8.3% Frustrated

**Dominant Concepts:**
- 📝 "UUID" (3 mentions across notes)

## Import & Test

### Step 1: Import the Workflow

1. Open n8n: http://localhost:5678
2. Click **"Workflows"** in the left sidebar
3. Click **"Add workflow"** (top right)
4. Click **"..."** (three dots) → **"Import from File"**
5. Select: `/Users/chaseeasterling/selene-n8n/workflows/03-pattern-detection/workflow-enhanced.json`
6. The workflow will load with all nodes visible

### Step 2: Activate the Workflow

1. Click the **"Inactive"** toggle in the top right (should turn to **"Active"**)
2. This enables both triggers:
   - Daily at 6am (automatic)
   - Webhook (on-demand)

### Step 3: Test Via Webhook

Run the analysis right now:

```bash
curl -X POST http://localhost:5678/webhook/pattern-analysis
```

**Expected Response:**
```json
{
  "success": true,
  "reportId": "pattern_report_1730568245678",
  "patternsDetected": 8,
  "message": "Pattern analysis complete: 8 patterns detected",
  "keyInsights": [
    "🎯 Found 8 patterns across your notes.",
    "✨ 5 high-confidence patterns detected with strong evidence.",
    ...
  ],
  "recommendations": [
    "⚡ High energy pattern! Great time to tackle challenging tasks.",
    ...
  ]
}
```

### Step 4: Verify in Database

Check that patterns were stored:

```bash
sqlite3 /Users/chaseeasterling/selene-n8n/data/selene.db "
SELECT
  pattern_type,
  pattern_name,
  confidence,
  data_points
FROM detected_patterns
ORDER BY discovered_at DESC
LIMIT 5;
"
```

**Expected Output:** 5-10 detected patterns

### Step 5: View Pattern Report

```bash
sqlite3 /Users/chaseeasterling/selene-n8n/data/selene.db "
SELECT
  report_id,
  total_patterns,
  high_confidence_count,
  json_extract(key_insights, '$') as insights
FROM pattern_reports
ORDER BY generated_at DESC
LIMIT 1;
"
```

## What the Workflow Does

1. **Trigger** - Runs daily at 6am OR via webhook
2. **Get Concepts** - Extracts all concepts from processed notes
3. **Analyze Clusters** - Finds concepts that appear together
4. **Get Sentiment** - Retrieves sentiment/energy data
5. **Analyze Patterns** - Detects energy, sentiment, tone patterns
6. **Store Patterns** - Saves each pattern to `detected_patterns` table
7. **Generate Report** - Creates summary with insights & recommendations
8. **Store Report** - Saves to `pattern_reports` table
9. **Return Response** - Sends JSON back (webhook only)

## Pattern Types Detected

| Type | Description | Example |
|------|-------------|---------|
| `concept_cluster` | Concepts appearing together | "project" + "deadline" (5 times) |
| `dominant_concept` | Frequently mentioned concepts | "ADHD" (8 mentions) |
| `energy_pattern` | Dominant energy levels | 75% medium energy |
| `sentiment_pattern` | Overall sentiment trends | 44% positive |
| `emotional_tone_pattern` | Primary emotional states | 38% determined |

## Troubleshooting

### Webhook returns "Workflow not found"
- Make sure workflow is **Active** (toggle in top right)
- Wait 30 seconds after activating for webhook to register
- Check n8n logs: `docker-compose logs n8n | tail -50`

### No patterns detected
- Normal if you have < 5 notes with concepts
- Check: `SELECT COUNT(*) FROM processed_notes WHERE concepts IS NOT NULL;`
- Should be 36+ notes

### Patterns not storing
- Check n8n execution logs (click workflow → "Executions")
- Look for red error nodes
- Verify database permissions

## Next Steps

After testing:

1. **Let it run daily** - Patterns will become more meaningful over time
2. **Add more notes** - More data = better patterns
3. **Review insights** - Check recommendations in pattern reports
4. **Export to Obsidian** - (Next phase) Create pattern summary pages

## Files Created

- `workflow-enhanced.json` - The new workflow (import this)
- `workflow.json` - Original theme-trend workflow (backup)
- `workflow.backup.json` - Backup of original
- `README.md` - Full documentation
- `QUICK-START.md` - This file
- `test-patterns.js` - Node test script (optional)

## Pattern Insights from Your Current Data

Based on your 36 notes:

**🎯 Key Finding:** You're in a **determined** state (38.9%) with **medium energy** (75%), showing consistent engagement across multiple themes.

**⚡ Energy Insight:** Your medium energy pattern suggests steady productivity. This is actually ideal for sustainable ADHD workflows - not burning out, not stuck.

**✅ Sentiment Insight:** Healthy balance of 44% positive and 36% neutral suggests balanced perspective without excessive negativity.

**💡 Recommendation:** Your "determined" + "medium energy" combination is perfect for incremental progress. Continue current practices!
