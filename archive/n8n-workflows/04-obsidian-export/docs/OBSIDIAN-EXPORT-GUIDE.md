# Obsidian Export: ADHD-Optimized Edition

**Status:** ✅ Ready for Testing
**Version:** 2.0 (ADHD-Optimized)
**Last Updated:** October 30, 2025

## 🎯 What Makes This ADHD-Friendly?

This workflow addresses the core challenges ADHD brains face with knowledge management:

### ❌ Problems with Traditional Note Systems

1. **Can't find notes** - Date-based organization doesn't match how ADHD memory works
2. **Can't remember context** - "Why did I care about this?"
3. **Can't gauge importance** - Everything looks the same
4. **Can't see actions** - TODOs buried in text
5. **Can't restore mental state** - "What was I thinking?"
6. **Out of sight = gone forever** - Need immediate availability

### ✅ How This Workflow Solves It

1. **Multiple Organization Strategies**
   - By concept (how you remember: "that Docker thing")
   - By theme (categories that make sense)
   - By energy level (match tasks to capacity)
   - By timeline (backup chronological view)

2. **Visual Quick-Scan System**
   - Emoji status indicators at a glance
   - Energy: ⚡ (high), 🔋 (medium), 🪫 (low)
   - Mood: 🚀😌😰😤😊🤯💪🎯
   - ADHD badges: 🧠 OVERWHELM, 🎯 HYPERFOCUS, ⚠️ EXEC-DYS

3. **Context Restoration Box**
   - TL;DR summary (no need to read everything)
   - Why it matters (quick relevance check)
   - Brain state when written (helps predict usefulness)
   - Reading time estimate (time blindness helper)

4. **Automatic Action Item Extraction**
   - Pulls TODOs/tasks from text
   - Ready-to-use checklist format
   - Separate section so they're not lost

5. **ADHD Brain State Insights**
   - Were you overwhelmed? (be gentle with yourself)
   - Were you hyperfocused? (probably valuable!)
   - Were you stressed? (context matters)
   - Energy and mood tracked

6. **Immediate + Frequent Export**
   - Every hour (not once daily at 7am)
   - On-demand webhook (export right now!)
   - Out of mind? Trigger export anytime

## 🏗️ Vault Structure

Your notes are organized **4 different ways** so you can find them however your brain searches:

```
vault/Selene/
├── Timeline/              # Chronological (backup method)
│   └── 2025/
│       └── 10/
│           └── 2025-10-30-note-title.md
│
├── By-Concept/            # PRIMARY: Find by "what was it about?"
│   ├── Docker/
│   ├── ADHD/
│   ├── Python/
│   └── Work/
│
├── By-Theme/              # Find by category
│   ├── technical/
│   ├── personal/
│   ├── ideas/
│   └── tasks/
│
├── By-Energy/             # Match notes to current capacity
│   ├── high/              # Complex, deep thoughts
│   ├── medium/            # Regular notes
│   └── low/               # Simple, scattered thoughts
│
└── Concepts/              # Hub pages (auto-generated)
    ├── Docker.md          # Shows all Docker notes
    ├── ADHD.md
    └── ...
```

## 📄 Note Format Example

Here's what an ADHD-optimized note looks like:

```markdown
---
title: "Meeting Notes - Project Planning"
date: 2025-10-30
energy: high
mood: excited
sentiment: positive
adhd_markers:
  overwhelm: false
  hyperfocus: true
  executive_dysfunction: false
action_items: 3
reading_time: 4
---

# 🚀 Meeting Notes - Project Planning

## 🎯 Status at a Glance

| Indicator | Status | Details |
|-----------|--------|----------|
| Energy | ⚡ HIGH | Brain capacity indicator |
| Mood | 🚀 excited | Emotional state |
| Sentiment | ✅ positive | Overall tone (85%) |
| ADHD | 🎯 HYPERFOCUS | Markers detected |
| Actions | 🎯 3 items | Tasks extracted |

---

**🏷️ Theme**: [[Themes/technical]]
**💡 Concepts**: [[Concepts/Docker]] • [[Concepts/API]] • [[Concepts/Architecture]]
**📅 Created**: 2025-10-30 (Thursday) at 14:30
**⏱️ Reading Time**: 4 min

---

> **⚡ Quick Context**
> We discussed the new API architecture and how to containerize services.
>
> **Why this matters:** Related to Docker, API
> **Reading time:** 4 min
> **Brain state:** high energy, excited

---

## ✅ Action Items Detected

- [ ] Create Docker Compose file for services
- [ ] Set up API gateway configuration
- [ ] Document deployment process

> **Tip:** Copy these to your daily todo list or use Obsidian Tasks plugin

---

## 📝 Full Content

[Your original note content here]

---

## 🧠 ADHD Insights

### Brain State Analysis

- **Energy Level**: high ⚡
  - ⚡ Great time for complex tasks

- **Emotional Tone**: excited 🚀
  - 🎯 Hyperfocus detected - valuable insights likely!

- **Sentiment**: positive (85%)

### Context Clues

- **When was this?** Thursday, 2025-10-30 at 14:30
- **What was I thinking about?** Docker, API, Architecture
- **Theme**: technical
- **How did I feel?** excited, positive

> **Memory Trigger**: Look for related notes tagged with these concepts to restore full context

---

## 🔗 Related Notes

*Obsidian will automatically show backlinks here*

---

*🤖 This note was automatically processed and optimized for ADHD by Selene*
```

## 🚀 Quick Start

### Prerequisites

1. **Complete workflows 01-02-05** must be running:
   - 01: Ingestion (creates notes)
   - 02: LLM Processing (extracts concepts)
   - 05: Sentiment Analysis (detects ADHD markers)

2. **Vault path configured**:
   - Set `OBSIDIAN_VAULT_PATH` in `.env`, or
   - Defaults to `./vault`

### Setup

1. **Import the workflow:**
   ```bash
   # In n8n UI
   Settings → Import from file → workflow-adhd-optimized.json
   ```

2. **Configure vault path** (if needed):
   - Edit the workflow's function node
   - Update `OBSIDIAN_VAULT_PATH` or set environment variable

3. **Activate the workflow:**
   - Toggle "Active" in n8n UI
   - Runs every hour automatically

4. **Get on-demand webhook URL:**
   - Open the "On-Demand Export Webhook" node
   - Copy the webhook URL (e.g., `http://localhost:5678/webhook/obsidian-export`)

### Usage

#### Automatic Export
- Runs **every hour** (not daily!)
- Exports up to 50 new notes per run
- Waits until sentiment analysis is complete

#### On-Demand Export
Trigger immediately via webhook:

```bash
curl -X POST http://localhost:5678/webhook/obsidian-export
```

Or create a Drafts action, Alfred workflow, or iOS Shortcut to trigger it.

## 🧠 ADHD Features Explained

### 1. Visual Status Header

**Why:** ADHD brains excel at visual pattern matching. Scanning emoji is faster than reading text.

**What you see:**
- ⚡🔋🪫 = Energy level (match to current capacity)
- 🚀😌😰 = Mood (emotional context)
- ✅⚠️⚪ = Sentiment (overall vibe)
- 🎯🧠⚠️ = ADHD markers (important self-awareness)

**How to use:**
- Low energy? Look for 🪫 notes (simpler content)
- Need motivation? Find 🚀 notes (past excitement)
- Feeling overwhelmed? Avoid 🧠 OVERWHELM notes (might be triggering)

### 2. Context Restoration Box

**Why:** ADHD struggles with "why did I care?" - executive function needs help.

**What it does:**
- TL;DR summary (decide if worth reading)
- "Why this matters" (immediate relevance)
- Brain state (predict if useful now)
- Reading time (time blindness helper)

**How to use:**
- Scan this first, always
- If not relevant now, skip (guilt-free!)
- If relevant, you now have context to dive in

### 3. Action Item Extraction

**Why:** ADHD brains bury TODOs in walls of text, then forget them.

**What it does:**
- Automatically finds tasks/TODOs
- Extracts to separate checklist
- Ready for Obsidian Tasks plugin

**How to use:**
- Copy to daily todo list
- Or use Obsidian Tasks to aggregate across notes
- No more "I know I wrote that down somewhere..."

### 4. Multiple Organization Paths

**Why:** ADHD memory is context-based, not time-based.

**What it does:**
- Same note saved 4 ways
- Find by concept: "That Docker thing"
- Find by theme: "Technical stuff"
- Find by energy: "What can I handle right now?"
- Find by date: "Last week sometime?"

**How to use:**
- Primary: Browse `By-Concept/` folders
- Concept Hub pages show all related notes
- Match current energy: Low battery? Check `By-Energy/low/`
- Timeline is backup only

### 5. ADHD Marker Detection

**Why:** Self-awareness is key to ADHD management.

**What it tracks:**
- **Overwhelm** (🧠): System noticed too-much-ness in your writing
- **Hyperfocus** (🎯): You were in the zone - this is probably valuable!
- **Executive Dysfunction** (⚠️): Struggles detected - be compassionate
- **Stress** (😰): Indicators present - context for mood

**How to use:**
- Track patterns: "I'm always overwhelmed on Mondays"
- Celebrate hyperfocus: Those notes are gold!
- Be gentle: ED notes show you were struggling
- Aggregate: Search `tag:#adhd/overwhelm` to find triggers

### 6. Brain State Tracking

**Why:** ADHD has variable capacity. Past-you's brain state predicts if note is useful now.

**What it tracks:**
- Energy: high/medium/low
- Mood: excited/calm/anxious/frustrated/etc
- Sentiment: positive/negative/neutral/mixed
- Emotional tone

**How to use:**
- High energy now? Read high-energy notes (complexity match)
- Low energy? Avoid complex "high" notes (frustration protection)
- Feeling anxious? Maybe skip anxious notes (mood protection)
- Feeling motivated? Find excited/motivated notes (momentum amplifier)

## 📊 Tracking Your Patterns

### Using Obsidian Dataview

Install Dataview plugin, then create queries:

**Show overwhelm patterns:**
```dataview
TABLE energy, mood, day
FROM "Selene"
WHERE adhd_markers.overwhelm = true
SORT date DESC
```

**Find hyperfocus notes (gold mines!):**
```dataview
TABLE concepts, reading_time
FROM "Selene"
WHERE adhd_markers.hyperfocus = true
SORT date DESC
```

**Match energy to current capacity:**
```dataview
LIST
FROM "Selene/By-Energy/high"
WHERE date >= date(today) - dur(7 days)
SORT date DESC
```

**Today's action items:**
```dataview
TASK
FROM "Selene"
WHERE date = date(today)
```

## 🔧 Customization

### Change Export Frequency

Edit the cron trigger:
- `0 * * * *` = Every hour (default)
- `*/30 * * * *` = Every 30 minutes
- `0 */3 * * *` = Every 3 hours

### Add Custom ADHD Markers

In the markdown builder function, add your own patterns:

```javascript
// Add your patterns
if (note.content.match(/\btired\b|\bexhausted\b/i)) {
  adhdBadges.push('😴 FATIGUE');
}

if (note.content.match(/\bexcited\b|\bcan't wait\b/i)) {
  adhdBadges.push('⚡ ENERGIZED');
}
```

### Customize Organization

Want different folders? Edit the directory paths:

```javascript
// Add a "By-Priority" folder
const priorityDir = `${vaultPath}/Selene/By-Priority/${priority}`;
```

### Adjust Visual Indicators

Prefer different emoji? Update the mappings:

```javascript
const energyEmoji = {
  'high': '🔥',  // Changed from ⚡
  'medium': '➡️',
  'low': '💤'
}
```

## 🎯 Best Practices

### For ADHD Users

1. **Don't fight your brain**
   - Can't remember dates? Use By-Concept folders
   - Can't focus? Check context boxes first
   - Low energy? Browse By-Energy/low

2. **Leverage hyperfocus detection**
   - Tag: `#adhd/hyperfocus`
   - Those notes are your best work
   - Review them when stuck

3. **Use action items immediately**
   - Copy to daily TODO
   - Don't let them sit in notes
   - Or use Obsidian Tasks plugin

4. **Track your patterns**
   - Dataview queries show trends
   - "I'm always overwhelmed after meetings"
   - Use insights to adjust

5. **On-demand export is your friend**
   - Just captured something important?
   - Trigger export immediately
   - Don't wait for hourly run

6. **Energy matching**
   - High energy? Tackle high-energy notes
   - Low energy? Review simple notes
   - Prevents frustration and shame spiral

### For Vault Organization

1. **Use Concept folders as primary**
   - Browse by "what was it about?"
   - Timeline is backup only

2. **Create daily notes that link**
   - Daily note template: Link recent exports
   - Aggregate action items
   - Review by energy level

3. **Set up Dataview dashboards**
   - Weekly review: Overwhelm patterns
   - Hyperfocus highlights
   - Action items rollup

## 🧪 Testing

### Test Automatic Export

1. Ensure workflows 01, 02, 05 have processed a note
2. Wait for next hourly run (check Executions tab)
3. Look in vault: `Selene/By-Concept/[concept-name]/`
4. Should see note in multiple folders

### Test On-Demand Export

```bash
# Trigger export
curl -X POST http://localhost:5678/webhook/obsidian-export

# Check response
# Expected: {"success": true, "message": "Export triggered successfully"}

# Check vault
ls -la vault/Selene/By-Concept/
```

### Verify ADHD Features

1. **Check visual indicators:**
   - Open a note
   - Should see emoji status table at top

2. **Check action items:**
   - Write a note with "TODO: something"
   - Should appear in "Action Items Detected" section

3. **Check ADHD markers:**
   - Write an overwhelmed note
   - Should see 🧠 OVERWHELM badge

4. **Check organization:**
   - Same note should appear in 4 folders
   - Timeline, By-Concept, By-Theme, By-Energy

## 🐛 Troubleshooting

### Notes Not Exporting

**Check:**
1. Is workflow activated?
2. Are notes processed? (`status = 'processed'`)
3. Is sentiment analyzed? (`sentiment_analyzed = 1`)
4. Already exported? (`exported_to_obsidian = 1`)

**Debug:**
```bash
sqlite3 data/selene.db "
SELECT
  rn.status,
  pn.sentiment_analyzed,
  rn.exported_to_obsidian
FROM raw_notes rn
JOIN processed_notes pn ON rn.id = pn.raw_note_id
ORDER BY rn.created_at DESC
LIMIT 5;
"
```

### Missing ADHD Markers

**Check:**
- Workflow 05 (sentiment analysis) must run first
- Wait 45 seconds after processing
- Check: `SELECT sentiment_data FROM processed_notes LIMIT 1;`

### Webhook Not Working

**Check:**
```bash
# Test webhook is accessible
curl -X POST http://localhost:5678/webhook/obsidian-export

# Expected: JSON response with success: true
```

### Files Not Creating

**Check permissions:**
```bash
# Ensure vault directory exists
mkdir -p vault/Selene

# Check write permissions
ls -la vault/
```

## 📚 Further Customization

### Add Daily Dashboard

Create `vault/Selene/Dashboard.md`:

```markdown
# 🧠 ADHD Dashboard

## Today's Energy
- Current capacity: [high/medium/low]
- Recommended folder: [[By-Energy/[your-energy]]]

## Recent Hyperfocus Notes
\`\`\`dataview
LIST concepts
FROM "Selene"
WHERE adhd_markers.hyperfocus = true
SORT date DESC
LIMIT 5
\`\`\`

## Action Items This Week
\`\`\`dataview
TASK
FROM "Selene"
WHERE date >= date(today) - dur(7 days)
\`\`\`

## Overwhelm Warning
\`\`\`dataview
TABLE energy, mood
FROM "Selene"
WHERE adhd_markers.overwhelm = true
AND date >= date(today) - dur(3 days)
\`\`\`
```

### Integrate with Tasks Plugin

Install Obsidian Tasks, then:
1. Action items are already in `- [ ]` format
2. Use Tasks plugin to aggregate: `tasks not done`
3. Filter by source: `path includes Selene`

### Add to Daily Note Template

In your daily note template:

```markdown
## Notes Captured Today

\`\`\`dataview
LIST
FROM "Selene"
WHERE date = date({{date}})
\`\`\`

## Actions From Today

\`\`\`dataview
TASK
FROM "Selene"
WHERE date = date({{date}})
\`\`\`
```

## 🎉 Summary

This ADHD-optimized export solves the core problems:

✅ **Findability**: 4 organization methods, concept-based primary
✅ **Context**: TL;DR + why it matters + brain state
✅ **Visual scanning**: Emoji indicators for quick filtering
✅ **Action visibility**: Auto-extracted, separate section
✅ **Self-awareness**: ADHD markers and brain state tracking
✅ **Accessibility**: Hourly + on-demand, not once daily
✅ **Energy matching**: Notes organized by cognitive load

Your notes are now optimized for how ADHD brains actually work. 🚀

---

**Questions? Issues?**
- Check the troubleshooting section
- Review n8n execution logs
- Test with webhook curl command
