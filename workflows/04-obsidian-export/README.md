# 04-Obsidian-Export Workflow

**Status:** ✅ Complete and Production-Ready
**Version:** 2.0 (ADHD-Optimized)
**Last Updated:** October 30, 2025

## Overview

This workflow exports your processed notes from Selene into Obsidian-compatible markdown files, **optimized specifically for ADHD brains**.

### 🎯 What Makes This ADHD-Optimized?

This isn't just another export tool—it's designed from the ground up to work **with** ADHD executive function, not against it:

- ⚡ **Visual quick-scan** - Emoji indicators for instant assessment
- 🗂️ **Multiple organization** - Find notes by concept, theme, energy, or date
- 📋 **Action extraction** - TODOs pulled out automatically
- 🧠 **Brain state tracking** - Know your mental state when you wrote it
- 🔄 **Immediate access** - Hourly + on-demand, not daily at 7am
- 📊 **Self-awareness** - Track overwhelm, hyperfocus, and patterns

**The problem:** Traditional note systems assume you remember when you wrote something and can scan text walls.

**The solution:** Multiple access paths, visual indicators, context restoration, and instant action visibility.

## Quick Start

### Prerequisites Check

```bash
# 1. Verify workflows are running
# Open http://localhost:5678 and check:
# - 01-ingestion: Active ✅
# - 02-llm-processing: Active ✅
# - 05-sentiment-analysis: Active ✅

# 2. Verify you have notes ready to export
sqlite3 data/selene.db "
SELECT COUNT(*) as ready
FROM raw_notes rn
JOIN processed_notes pn ON rn.id = pn.raw_note_id
WHERE rn.exported_to_obsidian = 0
  AND rn.status = 'processed'
  AND pn.sentiment_analyzed = 1;
"
# Should show: number > 0
```

### Setup (5 minutes)

```bash
# 1. Create vault directory structure
mkdir -p vault/Selene/{Timeline,By-Concept,By-Theme,By-Energy/{high,medium,low},Concepts,Themes}

# 2. Import workflow.json to n8n
# - Open http://localhost:5678
# - Import from file → Select workflow.json
# - Configure SQLite credentials (should auto-detect)

# 3. Activate the workflow
# - Toggle "Active" in n8n UI

# 4. Test export immediately
curl -X POST http://localhost:5678/webhook/obsidian-export

# 5. Verify files created
ls -la vault/Selene/By-Concept/
```

📖 **For detailed setup:** See [docs/OBSIDIAN-EXPORT-SETUP.md](docs/OBSIDIAN-EXPORT-SETUP.md)

## Key Features

### 1. Visual Status at a Glance

Every note shows:
- **Energy:** ⚡ high, 🔋 medium, 🪫 low
- **Mood:** 🚀 excited, 😌 calm, 😰 anxious, 💪 motivated
- **ADHD:** 🧠 overwhelm, 🎯 hyperfocus, ⚠️ exec-dysfunction
- **Actions:** 🎯 X items detected

**Why:** ADHD brains excel at visual pattern matching. Scan emoji faster than reading text.

### 2. Multiple Organization Paths

Same note saved **4 different ways** to match how your brain searches:

```
vault/Selene/
├── By-Concept/        # PRIMARY: "That Docker thing"
├── By-Theme/          # "Technical stuff"
├── By-Energy/         # "What can I handle right now?"
└── Timeline/          # "Last week sometime" (backup)
```

**Why:** ADHD memory is context-based, not date-based.

### 3. Action Item Extraction

TODOs automatically extracted from text into separate checklist:

```markdown
## ✅ Action Items Detected

- [ ] Create Docker Compose file
- [ ] Set up API gateway
- [ ] Document deployment
```

**Why:** Executive function struggles with buried tasks. Make them visible.

### 4. Context Restoration Box

Every note starts with:
- **TL;DR** (decide relevance in 2 seconds)
- **Why this matters** (immediate context)
- **Brain state** (energy + mood when written)
- **Reading time** (time blindness helper)

**Why:** "Why did I care about this?" is the ADHD nemesis.

### 5. ADHD Insights Section

Tracks and displays:
- Overwhelm detection (🧠)
- Hyperfocus celebration (🎯)
- Stress indicators (😰)
- Energy level interpretation
- Emotional context

**Why:** Self-awareness is key to ADHD management.

### 6. Hourly + On-Demand Export

- **Automatic:** Every hour (not once at 7am)
- **On-demand:** Webhook trigger any time
- **Maximum delay:** 1 hour (usually 10-20 min)

**Why:** Out of sight = out of mind. Need immediate access.

## Folder Structure

After export, your vault looks like:

```
vault/Selene/
├── By-Concept/              # Find by "what was it about?"
│   ├── Docker/
│   │   └── 2025-10-30-project-planning.md
│   ├── ADHD/
│   └── Python/
│
├── By-Theme/                # Browse by category
│   ├── technical/
│   ├── personal/
│   └── ideas/
│
├── By-Energy/               # Match notes to current capacity
│   ├── high/                # Complex, deep thoughts
│   ├── medium/              # Regular notes
│   └── low/                 # Simple, scattered notes
│
├── Timeline/                # Chronological backup
│   └── 2025/10/
│       └── 2025-10-30-project-planning.md
│
└── Concepts/                # Hub pages (auto-generated)
    ├── Docker.md            # Shows all Docker notes
    └── ADHD.md
```

## Usage

### Automatic Export

Runs **every hour** automatically once activated. No action needed.

### On-Demand Export

Trigger immediately:

```bash
curl -X POST http://localhost:5678/webhook/obsidian-export
```

**Create shortcuts:**
- **Alfred:** Keyword → Run Script → curl command
- **iOS Shortcut:** Get URL → POST to webhook
- **Drafts Action:** Run JavaScript HTTP request

### Finding Your Notes

**By concept (primary method):**
```
Browse: vault/Selene/By-Concept/Docker/
```

**By energy level:**
```
Low energy today? Browse: vault/Selene/By-Energy/low/
High energy? Browse: vault/Selene/By-Energy/high/
```

**By theme:**
```
Browse: vault/Selene/By-Theme/technical/
```

**See all notes for a concept:**
```
Open: vault/Selene/Concepts/Docker.md
Check backlinks section
```

## Example Note Output

```markdown
# 🚀 Project Planning Meeting

## 🎯 Status at a Glance

| Indicator | Status | Details |
|-----------|--------|----------|
| Energy | ⚡ HIGH | Brain capacity indicator |
| Mood | 🚀 excited | Emotional state |
| Sentiment | ✅ positive | Overall tone (85%) |
| ADHD | 🎯 HYPERFOCUS | Markers detected |
| Actions | 🎯 3 items | Tasks extracted |

---

> **⚡ Quick Context**
> Discussed API architecture and Docker deployment.
>
> **Why this matters:** Related to Docker, API
> **Reading time:** 4 min
> **Brain state:** high energy, excited

---

## ✅ Action Items Detected

- [ ] Create Docker Compose file
- [ ] Configure API gateway
- [ ] Document deployment

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

### Context Clues
- **When was this?** Thursday, 2025-10-30 at 14:30
- **What was I thinking about?** Docker, API
- **How did I feel?** excited, positive

> **Memory Trigger**: Look for related notes tagged with these concepts
```

## Documentation

### Primary Documentation

📖 **[OBSIDIAN-EXPORT-GUIDE.md](docs/OBSIDIAN-EXPORT-GUIDE.md)**
- Complete feature documentation
- ADHD-specific explanations
- Usage patterns and best practices
- Dataview query examples
- Customization guide

📖 **[OBSIDIAN-EXPORT-SETUP.md](docs/OBSIDIAN-EXPORT-SETUP.md)**
- Step-by-step setup instructions
- Prerequisite checks
- Troubleshooting guide
- Verification checklist
- Performance notes

📖 **[OBSIDIAN-EXPORT-COMPARISON.md](docs/OBSIDIAN-EXPORT-COMPARISON.md)**
- ADHD vs Standard comparison
- Feature breakdown
- When to use each
- Migration guide

📖 **[OBSIDIAN-EXPORT-DOCKER.md](docs/OBSIDIAN-EXPORT-DOCKER.md)**
- Docker volume mount explanation
- Configuration options
- Verification procedures
- Common issues and fixes

📖 **[OBSIDIAN-EXPORT-IMPLEMENTATION.md](docs/OBSIDIAN-EXPORT-IMPLEMENTATION.md)**
- Implementation details
- Technical architecture
- Development notes
- Future enhancements

## Why ADHD-Optimized?

### Problems with Traditional Note Systems

❌ **Date-based organization** - "When did I write that?" (ADHD can't remember)
❌ **Plain text walls** - Can't scan quickly
❌ **Missing context** - "Why did I care?"
❌ **Buried actions** - TODOs lost in text
❌ **No energy matching** - Can't tell complexity
❌ **Once-daily export** - Out of sight = forgotten
❌ **No brain state** - Can't restore mental context

### How This Solves It

✅ **Concept-based primary** - "That Docker thing"
✅ **Visual indicators** - Scan emoji instantly
✅ **Context restoration** - TL;DR + why it matters
✅ **Action extraction** - Separate checklist
✅ **Energy folders** - Match to current capacity
✅ **Hourly + on-demand** - Always accessible
✅ **Brain state tracking** - Know your mental state

## Obsidian Integration

### Using with Dataview Plugin

**Find hyperfocus notes (gold mines!):**
```dataview
LIST concepts
FROM "Selene"
WHERE adhd_markers.hyperfocus = true
SORT date DESC
```

**Match energy to current capacity:**
```dataview
LIST
FROM "Selene/By-Energy/low"
WHERE date >= date(today) - dur(7 days)
```

**Track overwhelm patterns:**
```dataview
TABLE energy, mood, day
FROM "Selene"
WHERE adhd_markers.overwhelm = true
SORT date DESC
```

**This week's action items:**
```dataview
TASK
FROM "Selene"
WHERE date >= date(today) - dur(7 days)
```

### Using with Tasks Plugin

Action items are already in `- [ ]` format, so:
1. Install Obsidian Tasks plugin
2. Use `tasks not done` query
3. Filter by `path includes Selene`

## Docker Configuration

**Already configured!** Your docker-compose.yml is ready:

```yaml
volumes:
  - ${OBSIDIAN_VAULT_PATH:-./vault}:/obsidian:rw
```

**To use your real Obsidian vault:**

Edit `.env`:
```bash
OBSIDIAN_VAULT_PATH=/Users/yourusername/Documents/ObsidianVault
```

Then restart:
```bash
docker-compose restart n8n
```

📖 **Details:** [docs/OBSIDIAN-EXPORT-DOCKER.md](docs/OBSIDIAN-EXPORT-DOCKER.md)

## Troubleshooting

### "No notes exported"

**Check:**
```bash
# Are notes ready?
sqlite3 data/selene.db "
SELECT
  COUNT(*) FILTER (WHERE status = 'processed') as processed,
  COUNT(*) FILTER (WHERE sentiment_analyzed = 1) as sentiment_done
FROM processed_notes pn
JOIN raw_notes rn ON pn.raw_note_id = rn.id;
"
```

**Fix:** Ensure workflows 01, 02, 05 are all active and have processed notes.

### "Missing ADHD markers"

**Cause:** Workflow 05 (sentiment analysis) hasn't run yet.

**Fix:**
- Activate workflow 05
- Wait 45 seconds for it to run
- Verify: `SELECT sentiment_analyzed FROM processed_notes;` shows `1`

### "Webhook 404 error"

**Fix:**
1. Ensure workflow is activated
2. Get correct URL from webhook node in n8n
3. Restart n8n if needed: `docker-compose restart n8n`

📖 **Full troubleshooting:** [docs/OBSIDIAN-EXPORT-SETUP.md#troubleshooting](docs/OBSIDIAN-EXPORT-SETUP.md#troubleshooting)

## Files

```
04-obsidian-export/
├── README.md                                 # This file
├── workflow.json                             # ADHD-optimized n8n workflow
├── docs/
│   ├── OBSIDIAN-EXPORT-GUIDE.md             # Complete features guide
│   ├── OBSIDIAN-EXPORT-SETUP.md             # Setup instructions
│   ├── OBSIDIAN-EXPORT-COMPARISON.md        # Feature comparison
│   ├── OBSIDIAN-EXPORT-DOCKER.md            # Docker configuration
│   └── OBSIDIAN-EXPORT-IMPLEMENTATION.md    # Technical details
└── archive/
    └── workflow-standard.json                # Old simple version
```

## Performance

**Per note:**
- Processing: 2-5 seconds
- Storage: ~200KB (4 locations)
- CPU: Very low
- Memory: ~5MB

**Per hour:**
- Up to 50 notes
- ~2-3 minutes total
- Negligible system impact

## Next Steps

1. **Follow setup guide:** [docs/OBSIDIAN-EXPORT-SETUP.md](docs/OBSIDIAN-EXPORT-SETUP.md)
2. **Test export:** `curl -X POST http://localhost:5678/webhook/obsidian-export`
3. **Verify in vault:** `ls -la vault/Selene/By-Concept/`
4. **Open in Obsidian** and explore the organization
5. **Install Dataview** for powerful queries
6. **Create shortcuts** for on-demand export

## Support

- **Setup help:** [docs/OBSIDIAN-EXPORT-SETUP.md](docs/OBSIDIAN-EXPORT-SETUP.md)
- **Feature guide:** [docs/OBSIDIAN-EXPORT-GUIDE.md](docs/OBSIDIAN-EXPORT-GUIDE.md)
- **Docker config:** [docs/OBSIDIAN-EXPORT-DOCKER.md](docs/OBSIDIAN-EXPORT-DOCKER.md)
- **Troubleshooting:** Check execution logs in n8n

---

**Your notes are now optimized for how ADHD brains actually work. 🚀**

Ready to find things by concept instead of date? Let's go!
