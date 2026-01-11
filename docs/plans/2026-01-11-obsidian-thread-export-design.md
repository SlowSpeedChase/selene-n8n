# Obsidian Thread Export Design

**Date:** 2026-01-11
**Status:** Approved
**Scope:** Export semantic threads to Obsidian vault

---

## Overview

Export threads from the Selene database to Obsidian as markdown files, making threads visible in the user's PKM system alongside existing note exports.

**Key decisions:**
- Location: `Selene/Threads/` folder
- Trigger: Integrated into `reconsolidate-threads.ts` (hourly)
- Files overwrite on each run (thread is source of truth)
- Deleted threads leave orphan files (preserves history)

---

## File Structure

**Location:** `{vault}/Selene/Threads/{thread-slug}.md`

**Example:** `Selene/Threads/event-driven-architecture-testing.md`

---

## Thread File Format

```markdown
---
title: "Event-Driven Architecture Testing"
type: thread
status: active
momentum: 33.25
note_count: 11
last_activity: 2026-01-10
created: 2026-01-10
tags:
  - selene/thread
  - status/active
---

# Event-Driven Architecture Testing

## Why This Thread Exists

To test and verify the functionality of an event-driven architecture...

## Current Summary

A series of notes documenting tests on event-driven architecture...

## Status

🔥 **Active** | Momentum: 33.2 | 11 notes

---

## Linked Notes

- [[2026-01-08-webhook-testing-results]] - Jan 8
- [[2026-01-07-event-flow-debugging]] - Jan 7
- [[2026-01-05-architecture-decisions]] - Jan 5

---

*Last updated: 2026-01-11 by Selene*
```

---

## Frontmatter Fields

| Field | Type | Description |
|-------|------|-------------|
| title | string | Thread name |
| type | string | Always "thread" |
| status | string | active, paused, completed, abandoned |
| momentum | number | Momentum score (0-100+) |
| note_count | number | Number of linked notes |
| last_activity | date | Last activity date |
| created | date | Thread creation date |
| tags | array | Includes `selene/thread` + status tag |

---

## Status Badges

| Status | Display |
|--------|---------|
| active | 🔥 **Active** |
| paused | ⏸️ **Paused** |
| completed | ✅ **Completed** |
| abandoned | 💤 **Abandoned** |

---

## Linked Notes Format

**If note is exported to Obsidian:**
```markdown
- [[2026-01-08-webhook-testing-results]] - Jan 8
```

**If note is not yet exported:**
```markdown
- "Webhook Testing Results" (not exported) - Jan 8
```

Uses wiki-link format for Obsidian graph connections.

---

## Implementation

**Modified file:** `src/workflows/reconsolidate-threads.ts`

**New functions:**
- `exportThreadsToObsidian()` - Main export function
- `generateThreadMarkdown(thread, notes)` - Generate markdown for one thread
- `createSlug(name)` - Create URL-friendly filename

**Database queries:**
- Get all threads (any status)
- Get linked notes for each thread with export status

**Flow:**
1. After reconsolidation updates summaries/momentum
2. Query all threads
3. For each thread, generate markdown
4. Write to `{vault}/Selene/Threads/{slug}.md`
5. Log export count

---

## Edge Cases

| Scenario | Behavior |
|----------|----------|
| Thread with 0 notes | Export with "No notes linked yet" |
| Thread deleted | File remains (orphan, manual cleanup) |
| Thread name changes | New file created, old file orphaned |
| Note not exported | Show title without wiki-link |
| Very long thread name | Slug truncated to 50 chars |

---

## Success Criteria

1. Running reconsolidate-threads.ts creates/updates thread files in Obsidian
2. Thread files have correct frontmatter for Dataview queries
3. Linked notes use wiki-links when possible
4. Status badges reflect current thread state
5. Momentum and note counts are accurate

---

## Files Changed

| File | Change |
|------|--------|
| `src/workflows/reconsolidate-threads.ts` | Add export functions |

**No new files needed** - integrates into existing workflow.
