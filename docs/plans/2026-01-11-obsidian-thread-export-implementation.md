# Obsidian Thread Export Implementation Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** Export semantic threads to Obsidian vault as markdown files during reconsolidation.

**Architecture:** Add Phase 4 to `reconsolidate-threads.ts` that queries all threads, generates markdown with frontmatter and wiki-links, and writes to `{vault}/Selene/Threads/`.

**Tech Stack:** TypeScript, Node.js fs, SQLite

---

## Task 1: Add Thread Export Types and Helpers

**Files:**
- Modify: `src/workflows/reconsolidate-threads.ts`

**Step 1: Add imports and types at top of file**

After existing imports (line 2), add:

```typescript
import { writeFileSync, existsSync, mkdirSync } from 'fs';
import { join } from 'path';
```

After existing interfaces (around line 38), add:

```typescript
interface ExportableThread {
  id: number;
  name: string;
  why: string | null;
  summary: string | null;
  status: string;
  note_count: number;
  momentum_score: number | null;
  last_activity_at: string | null;
  created_at: string;
}

interface LinkedNote {
  id: number;
  title: string;
  created_at: string;
  exported_to_obsidian: number;
}
```

**Step 2: Add helper functions after calculateMomentum**

```typescript
/**
 * Create URL-friendly slug from thread name
 */
function createSlug(name: string): string {
  return name
    .toLowerCase()
    .replace(/[^a-z0-9\s-]/g, '')
    .replace(/\s+/g, '-')
    .slice(0, 50);
}

/**
 * Get status emoji for thread
 */
function getStatusEmoji(status: string): string {
  const emojis: Record<string, string> = {
    active: '🔥',
    paused: '⏸️',
    completed: '✅',
    abandoned: '💤',
  };
  return emojis[status] || '📌';
}

/**
 * Format date as YYYY-MM-DD
 */
function formatDate(dateStr: string | null): string {
  if (!dateStr) return 'unknown';
  return dateStr.split('T')[0];
}
```

**Step 3: Verify it compiles**

Run: `npx tsc --noEmit src/workflows/reconsolidate-threads.ts`
Expected: No errors

**Step 4: Commit**

```bash
git add src/workflows/reconsolidate-threads.ts
git commit -m "feat(threads): add types and helpers for Obsidian export"
```

---

## Task 2: Add Thread Query and Markdown Generation

**Files:**
- Modify: `src/workflows/reconsolidate-threads.ts`

**Step 1: Add function to get all threads for export**

After the helper functions from Task 1:

```typescript
/**
 * Get all threads for Obsidian export
 */
function getAllThreadsForExport(): ExportableThread[] {
  return db
    .prepare(
      `SELECT id, name, why, summary, status, note_count,
              momentum_score, last_activity_at, created_at
       FROM threads
       ORDER BY momentum_score DESC NULLS LAST`
    )
    .all() as ExportableThread[];
}

/**
 * Get linked notes for a thread
 */
function getLinkedNotesForExport(threadId: number): LinkedNote[] {
  return db
    .prepare(
      `SELECT r.id, r.title, r.created_at, r.exported_to_obsidian
       FROM raw_notes r
       JOIN thread_notes tn ON r.id = tn.raw_note_id
       WHERE tn.thread_id = ?
       ORDER BY r.created_at DESC`
    )
    .all(threadId) as LinkedNote[];
}
```

**Step 2: Add markdown generation function**

```typescript
/**
 * Generate Obsidian markdown for a thread
 */
function generateThreadMarkdown(thread: ExportableThread, notes: LinkedNote[]): string {
  const statusEmoji = getStatusEmoji(thread.status);
  const momentum = thread.momentum_score?.toFixed(1) || '0.0';
  const lastActivity = formatDate(thread.last_activity_at);
  const created = formatDate(thread.created_at);
  const today = new Date().toISOString().split('T')[0];

  // Build frontmatter
  const frontmatter = `---
title: "${thread.name.replace(/"/g, '\\"')}"
type: thread
status: ${thread.status}
momentum: ${thread.momentum_score || 0}
note_count: ${thread.note_count}
last_activity: ${lastActivity}
created: ${created}
tags:
  - selene/thread
  - status/${thread.status}
---`;

  // Build why section
  const whySection = thread.why
    ? `## Why This Thread Exists

${thread.why}`
    : '';

  // Build summary section
  const summarySection = thread.summary
    ? `## Current Summary

${thread.summary}`
    : '## Current Summary

*No summary generated yet.*';

  // Build status line
  const statusLine = `## Status

${statusEmoji} **${thread.status.charAt(0).toUpperCase() + thread.status.slice(1)}** | Momentum: ${momentum} | ${thread.note_count} notes`;

  // Build linked notes section
  let notesSection = '## Linked Notes\n\n';
  if (notes.length === 0) {
    notesSection += '*No notes linked yet.*';
  } else {
    for (const note of notes) {
      const noteDate = formatDate(note.created_at);
      const dateDisplay = new Date(note.created_at).toLocaleDateString('en-US', { month: 'short', day: 'numeric' });

      if (note.exported_to_obsidian) {
        // Create wiki-link to exported note
        const slug = note.title
          .toLowerCase()
          .replace(/[^a-z0-9\s-]/g, '')
          .replace(/\s+/g, '-')
          .slice(0, 50);
        notesSection += `- [[${noteDate}-${slug}]] - ${dateDisplay}\n`;
      } else {
        // Just show title without link
        notesSection += `- "${note.title}" *(not exported)* - ${dateDisplay}\n`;
      }
    }
  }

  // Combine all sections
  return `${frontmatter}

# ${thread.name}

${whySection}

${summarySection}

${statusLine}

---

${notesSection}

---

*Last updated: ${today} by Selene*
`;
}
```

**Step 3: Verify it compiles**

Run: `npx tsc --noEmit src/workflows/reconsolidate-threads.ts`
Expected: No errors

**Step 4: Commit**

```bash
git add src/workflows/reconsolidate-threads.ts
git commit -m "feat(threads): add thread query and markdown generation for Obsidian"
```

---

## Task 3: Add Export Function and Integrate into Workflow

**Files:**
- Modify: `src/workflows/reconsolidate-threads.ts`

**Step 1: Add the main export function**

After `generateThreadMarkdown`:

```typescript
/**
 * Export all threads to Obsidian vault
 */
function exportThreadsToObsidian(): number {
  const vaultPath = process.env.OBSIDIAN_VAULT_PATH;
  if (!vaultPath) {
    log.warn('OBSIDIAN_VAULT_PATH not set, skipping thread export');
    return 0;
  }

  const threadsDir = join(vaultPath, 'Selene', 'Threads');

  // Ensure directory exists
  if (!existsSync(threadsDir)) {
    mkdirSync(threadsDir, { recursive: true });
    log.info({ threadsDir }, 'Created Threads directory');
  }

  const threads = getAllThreadsForExport();
  let exported = 0;

  for (const thread of threads) {
    try {
      const notes = getLinkedNotesForExport(thread.id);
      const markdown = generateThreadMarkdown(thread, notes);
      const slug = createSlug(thread.name);
      const filePath = join(threadsDir, `${slug}.md`);

      writeFileSync(filePath, markdown, 'utf-8');
      exported++;

      log.debug({ threadId: thread.id, filePath }, 'Exported thread to Obsidian');
    } catch (err) {
      const error = err as Error;
      log.error({ err: error, threadId: thread.id }, 'Failed to export thread');
    }
  }

  log.info({ exported, total: threads.length }, 'Thread export to Obsidian complete');
  return exported;
}
```

**Step 2: Add Phase 4 to main workflow**

In the `reconsolidateThreads` function, after Phase 3 (calculateMomentum), add:

```typescript
  // Phase 4: Export threads to Obsidian
  const threadsExported = exportThreadsToObsidian();
```

Update the final log.info to include the export count:

```typescript
  log.info(
    {
      threadsResynthesized: result.processed,
      momentumUpdated,
      threadsExported,
      errors: result.errors,
    },
    'Thread reconsolidation complete'
  );
```

**Step 3: Verify it compiles**

Run: `npx tsc --noEmit src/workflows/reconsolidate-threads.ts`
Expected: No errors

**Step 4: Commit**

```bash
git add src/workflows/reconsolidate-threads.ts
git commit -m "feat(threads): integrate Obsidian export into reconsolidation workflow"
```

---

## Task 4: Test End-to-End

**Step 1: Run reconsolidation manually**

```bash
npx ts-node src/workflows/reconsolidate-threads.ts
```

Expected output includes: `threadsExported: 2`

**Step 2: Verify files created**

```bash
ls -la vault/Selene/Threads/
cat vault/Selene/Threads/event-driven-architecture-testing.md | head -40
```

Expected: Two markdown files with proper frontmatter and content

**Step 3: Verify frontmatter structure**

Check that files have:
- Valid YAML frontmatter
- Correct status, momentum, note_count
- Wiki-links for exported notes

**Step 4: Commit final verification**

```bash
git add -A
git commit -m "feat(threads): complete Obsidian thread export

- Export threads to Selene/Threads/ in Obsidian vault
- Generate markdown with frontmatter for Dataview
- Wiki-links to exported notes
- Integrated into hourly reconsolidation workflow"
```

---

## Summary

| Task | Files | Description |
|------|-------|-------------|
| 1 | reconsolidate-threads.ts | Add types and helper functions |
| 2 | reconsolidate-threads.ts | Add query and markdown generation |
| 3 | reconsolidate-threads.ts | Add export function, integrate into workflow |
| 4 | — | Test end-to-end |

**Total: 4 tasks, 1 file modified**
