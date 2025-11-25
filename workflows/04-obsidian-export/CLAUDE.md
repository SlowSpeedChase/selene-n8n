# 04-Obsidian Export Workflow Context

## Purpose

Exports notes from SQLite to Obsidian vault as markdown files, maintaining backlinks, tags, and metadata. Enables visual knowledge management in Obsidian while keeping SQLite as source of truth.

## Tech Stack

- better-sqlite3 for database queries
- File system operations (Node.js fs module)
- Markdown generation
- Obsidian frontmatter (YAML)
- Wikilink syntax for backlinks

## Key Files

- workflow.json (158 lines) - Main workflow definition
- README.md - Export configuration guide
- docs/STATUS.md - Test results

## Data Flow

1. **Query Notes** - SELECT from raw_notes, processed_notes, sentiment_history
2. **Generate Markdown** - Format as Obsidian-compatible markdown
3. **Add Frontmatter** - Include metadata (date, tags, concepts)
4. **Create Backlinks** - Generate wikilinks for related notes
5. **Write Files** - Save to vault/Selene/ directory
6. **Update Index** - Maintain master index file

## Common Patterns

### Markdown Generation
```javascript
// Obsidian-compatible markdown with frontmatter
const markdown = `---
created: ${note.created_at}
tags: ${concepts.map(c => `#${c}`).join(', ')}
concepts: ${JSON.stringify(concepts)}
---

# ${note.title || 'Untitled Note'}

${note.content}

## Related Notes
${relatedNotes.map(n => `- [[${n.title}]]`).join('\n')}
`;
```

### File Naming
```javascript
// Sanitize filename for filesystem
const filename = note.title
    .replace(/[^a-z0-9]/gi, '-')
    .toLowerCase()
    .substring(0, 50) + '.md';
```

### Backlink Generation
```javascript
// Find related notes by concept overlap
const related = db.prepare(`
    SELECT DISTINCT r.id, r.content
    FROM raw_notes r
    JOIN processed_notes p ON r.id = p.raw_note_id
    WHERE p.concepts LIKE ?
    AND r.id != ?
`).all(`%${concept}%`, noteId);
```

## Vault Structure

```
vault/Selene/
├── Daily Notes/
│   └── YYYY-MM-DD.md
├── Concepts/
│   └── [concept-name].md
├── Notes/
│   └── [note-title].md
└── Index.md
```

## Testing

### Run Tests
```bash
cd workflows/04-obsidian-export
./scripts/test-with-markers.sh
```

### Validation
- Check vault/Selene/ for generated files
- Verify frontmatter YAML is valid
- Test backlinks open in Obsidian
- Ensure no file name collisions

## Database Schema

**Reads from:**
- raw_notes (content, created_at)
- processed_notes (concepts, themes, keywords)
- sentiment_history (sentiment, energy)

**No writes** - Export-only workflow

## Do NOT

- **NEVER delete existing vault files** - only add or update
- **NEVER use absolute paths** - vault location may change
- **NEVER export test data** to production vault - check test_run
- **NEVER skip filename sanitization** - breaks on special chars
- **NEVER overwrite without backup** - Obsidian edits may exist

## Known Issues

1. **File Name Collisions** - Multiple notes with same title
   - Workaround: Append ID to filename

2. **Large Vaults** - Export slows with >1000 notes
   - Workaround: Incremental export (only new/modified)

## Related Context

@workflows/04-obsidian-export/README.md
@database/schema.sql
@workflows/CLAUDE.md
