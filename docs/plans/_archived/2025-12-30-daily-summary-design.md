# Daily Executive Summary - Design Document

**Date:** 2025-12-30
**Status:** Approved
**Workflow:** 07-daily-summary

---

## Overview

A new n8n workflow that runs at midnight, gathers data from Selene, generates a brief executive summary via Ollama, and saves it to the Obsidian vault.

**Purpose:** Externalize what's been captured and processed daily, making information visible without mental overhead (ADHD principle).

---

## Requirements

| Requirement | Decision |
|-------------|----------|
| Summary content | Combination: recent activity AND emerging patterns |
| Output location | Obsidian vault (`Daily/YYYY-MM-DD-summary.md`) |
| Format | Minimal: brief paragraph + key themes |
| Trigger | Scheduled at midnight |
| LLM | Ollama (mistral:7b) |
| No activity days | Create file anyway, noting quiet day |

---

## Data Flow

```
Schedule (midnight) → Query today's notes → Query processed insights →
Query patterns → Build context → Ollama summary → Write to Obsidian
```

**Data sources:**
1. `raw_notes` - Notes captured in the last 24 hours
2. `processed_notes` - LLM-extracted insights from recent processing
3. `detected_patterns` - Emerging themes across note corpus

---

## LLM Prompt

```
You are summarizing a personal knowledge capture system for someone with ADHD.
Be brief and clear. Write 2-4 sentences max.

Today's date: {date}

Notes captured today ({count}):
{list of titles and tags}

Insights extracted:
{processed concepts, if any}

Recurring themes:
{detected patterns, if any}

Write a brief executive summary paragraph covering:
- What was captured today (or note if quiet day)
- Any notable insights or themes emerging
```

---

## Output Format

**Normal day:**
```markdown
# Daily Summary - December 30, 2025

Captured 3 notes today focused on project planning and workflow automation.
The LLM extracted concepts around "task management" and "n8n integrations"
which connect to your ongoing theme of building external memory systems.

---
*Generated automatically at midnight by Selene*
```

**Quiet day:**
```markdown
# Daily Summary - December 30, 2025

No new notes captured today. Your recent themes around ADHD tooling
and knowledge management remain active from earlier this week.

---
*Generated automatically at midnight by Selene*
```

---

## Technical Implementation

### Workflow Nodes

1. **Schedule Trigger** - Cron: `0 0 * * *` (midnight daily)

2. **Query Today's Notes** - Code node (better-sqlite3)
   ```sql
   SELECT title, tags, word_count, created_at
   FROM raw_notes
   WHERE date(created_at) = date('now', '-1 day')
   AND test_run IS NULL
   ```

3. **Query Processed Insights** - Code node
   ```sql
   SELECT concepts, themes
   FROM processed_notes
   WHERE date(processed_at) = date('now', '-1 day')
   AND test_run IS NULL
   ```

4. **Query Patterns** - Code node
   ```sql
   SELECT pattern_type, description
   FROM detected_patterns
   ORDER BY detected_at DESC LIMIT 5
   ```

5. **Build Prompt** - Code node assembles context + prompt

6. **Ollama Request** - HTTP Request to `http://host.docker.internal:11434/api/generate`

7. **Write to Obsidian** - Code node writes to `/obsidian/Daily/YYYY-MM-DD-summary.md`

### File Structure

```
workflows/07-daily-summary/
├── workflow.json          # Source of truth
├── README.md              # Quick start
├── docs/
│   └── STATUS.md          # Test results
└── scripts/
    ├── test-with-markers.sh
    └── cleanup-tests.sh
```

### Dependencies

- better-sqlite3 (existing)
- Ollama running on host (existing)
- Obsidian vault mounted at `/obsidian` (existing)

---

## Edge Cases

| Scenario | Behavior |
|----------|----------|
| No notes today | Creates summary noting quiet day |
| Ollama unavailable | Logs error, creates file noting "summary generation failed" |
| Obsidian vault unmounted | Logs error, workflow fails gracefully |
| processed_notes empty | Skips insights section, still summarizes captures |
| detected_patterns empty | Omits patterns, focuses on daily activity |
| Run twice same day | Overwrites existing file (idempotent) |
| Daily/ folder missing | Creates folder on first run |

---

## Testing Strategy

- `test_run` column support for test data isolation
- Test files written to `Daily/test-YYYY-MM-DD-summary.md`
- Cleanup script removes test files from Obsidian vault
- Test script at `workflows/07-daily-summary/scripts/test-with-markers.sh`

---

## Implementation Checklist

- [ ] Create workflow directory structure
- [ ] Build workflow.json with all nodes
- [ ] Import workflow to n8n
- [ ] Test with markers
- [ ] Verify Obsidian output
- [ ] Create documentation (README.md, STATUS.md)
- [ ] Activate scheduled trigger

---

*Design approved: 2025-12-30*
