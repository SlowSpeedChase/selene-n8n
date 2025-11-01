# Phase 1.5: UUID Tracking Foundation

**Created:** 2025-11-01
**Priority:** HIGH - Foundational improvement
**Status:** PLANNED

## Overview

Add source UUID tracking to the Selene system to enable precise draft identification, edit detection, and version management. This is a foundational improvement that should be implemented before adding more features.

## Problem Statement

Currently, the system cannot:
- Track specific drafts by their UUID (e.g., `18689285-1837-4EC1-8C78-259222DA939A`)
- Detect when a draft has been edited and re-sent
- Link database records back to the original draft in the Drafts app
- Distinguish between duplicate content vs. draft re-sends

**Current duplicate detection:**
- Only uses `content_hash` (SHA hash of content)
- Cannot detect if the same draft UUID has different content (edits)
- No way to query "which database record came from draft X?"

## Goals

1. **Track draft UUIDs** - Store the draft UUID alongside each note
2. **UUID-first duplicate logic** - Use UUID as primary identifier, content_hash as fallback
3. **Handle edits** - When UUID matches but content differs, update the existing record
4. **Backward compatible** - Non-Drafts sources (future) still work without UUIDs
5. **Query by UUID** - Enable fast lookups: "Did draft X get processed?"

## Architecture Changes

### Database Schema

**Add to `raw_notes` table:**
```sql
ALTER TABLE raw_notes ADD COLUMN source_uuid TEXT DEFAULT NULL;
CREATE INDEX idx_raw_notes_source_uuid ON raw_notes(source_uuid);
```

**Benefits:**
- Fast UUID lookups via index
- NULL-friendly (non-Drafts sources don't need UUIDs)
- Enables future features (edit history, version tracking)

### Payload Structure

**Current payload (Drafts → n8n):**
```json
{
  "title": "Note title",
  "content": "Note content...",
  "created_at": "2025-11-01T16:26:07.378Z",
  "source_type": "drafts"
}
```

**New payload:**
```json
{
  "title": "Note title",
  "content": "Note content...",
  "created_at": "2025-11-01T16:26:07.378Z",
  "source_type": "drafts",
  "source_uuid": "18689285-1837-4EC1-8C78-259222DA939A"
}
```

### Duplicate Detection Logic

**New UUID-First Strategy (Option C):**

```
IF source_uuid IS PROVIDED:
  Query: SELECT * FROM raw_notes WHERE source_uuid = ?

  IF UUID EXISTS:
    Compare content_hash

    IF content_hash DIFFERENT:
      → UPDATE existing record (draft was edited)
      → Update content, content_hash, imported_at
      → Reset status to 'pending' for re-processing
      → Preserve original created_at
    ELSE:
      → SKIP (exact duplicate)

  ELSE (UUID not in DB):
    Check content_hash for accidental duplicates

    IF content_hash EXISTS:
      → SKIP (same content, different draft)
    ELSE:
      → INSERT new record

ELSE (no UUID provided):
  Fall back to content_hash only (backward compatible)
```

**Rationale for Option C:**
- **Handles edits**: User can edit draft and re-send, system updates record
- **Prevents duplicates**: Same UUID = same logical note
- **Preserves content dedup**: Even without UUID, content_hash prevents dupes
- **Version control ready**: Foundation for future edit history tracking

## Implementation Plan

### Phase 1: Database Foundation
**Time: 30 minutes**

1. Create migration SQL script
2. Apply migration to database
3. Verify schema changes
4. Test queries with NULL UUIDs (backward compatibility)

**Deliverables:**
- `database/migrations/001_add_source_uuid.sql`
- Updated schema documentation

### Phase 2: Capture UUIDs
**Time: 30 minutes**

1. Update Drafts action script to send `draft.uuid`
2. Update workflow Parse Note Data node to extract UUID
3. Test: Send draft, verify UUID received by n8n

**Files Changed:**
- `workflows/01-ingestion/docs/drafts-selene-action.js`
- `workflows/01-ingestion/workflow.json` (Parse Note Data node)

### Phase 3: Store UUIDs
**Time: 30 minutes**

1. Update Insert Note node to store UUID
2. Test: Verify UUID is written to database
3. Query test: `SELECT id, title, source_uuid FROM raw_notes LIMIT 5`

**Files Changed:**
- `workflows/01-ingestion/workflow.json` (Insert Note node)

### Phase 4: UUID-First Duplicate Logic
**Time: 1-2 hours**

1. Update Check for Duplicate node with UUID query
2. Add UUID matching logic
3. Create Update Existing Note node (for edits)
4. Wire up workflow routing (insert vs. update vs. skip)
5. Update response messages to indicate action taken

**Files Changed:**
- `workflows/01-ingestion/workflow.json` (multiple nodes)

### Phase 5: Integration Testing
**Time: 1 hour**

**Test Cases:**
1. **New draft** → Should insert with UUID
2. **Resend same draft** → Should skip (duplicate UUID + content)
3. **Edit draft + resend** → Should update existing record
4. **Same content, different draft** → Should skip (content_hash match)
5. **Non-Drafts source** → Should work without UUID (backward compat)

**Queries for validation:**
```sql
-- Check UUID tracking
SELECT id, title, source_uuid, content_hash, status
FROM raw_notes
ORDER BY imported_at DESC LIMIT 10;

-- Find drafts with multiple imports (edit detection)
SELECT source_uuid, COUNT(*) as import_count, GROUP_CONCAT(imported_at)
FROM raw_notes
WHERE source_uuid IS NOT NULL
GROUP BY source_uuid
HAVING COUNT(*) > 1;

-- Verify backward compatibility (notes without UUIDs)
SELECT COUNT(*) FROM raw_notes WHERE source_uuid IS NULL;
```

## Success Criteria

- ✅ Database has `source_uuid` column with index
- ✅ Drafts action sends UUID in payload
- ✅ Workflow captures and stores UUID
- ✅ New drafts insert with UUID
- ✅ Resending same draft skips (duplicate detection)
- ✅ Editing draft updates existing record
- ✅ Can query: "SELECT * FROM raw_notes WHERE source_uuid = 'X'"
- ✅ Non-UUID sources still work (backward compatible)
- ✅ All existing workflows continue functioning

## Future Enhancements Enabled

Once UUID tracking is in place, these features become possible:

### Edit History Tracking
```sql
CREATE TABLE note_versions (
  id INTEGER PRIMARY KEY,
  note_id INTEGER REFERENCES raw_notes(id),
  source_uuid TEXT,
  content TEXT,
  content_hash TEXT,
  version_number INTEGER,
  edited_at DATETIME,
  change_summary TEXT
);
```

### Draft Sync Status
- Query Drafts app: "Which drafts are not yet in Selene?"
- Show in UI: "Last synced: 2 hours ago"

### Cross-Reference Links
- Obsidian note includes: `Source: [Open in Drafts](drafts://open?uuid=X)`
- Click link → opens original draft for editing

### Intelligent Re-processing
- If draft edited significantly, re-run LLM analysis
- If minor edit, keep existing concepts/themes

## Risk Assessment

**Low Risk:**
- Schema change is additive (doesn't break existing data)
- NULL UUIDs are allowed (backward compatible)
- Workflow changes are isolated to ingestion workflow

**Medium Risk:**
- Duplicate logic is complex (needs thorough testing)
- Update logic could overwrite wanted data (needs safeguards)

**Mitigation:**
- Test extensively before production use
- Backup database before applying migration
- Keep `content_hash` as secondary safety check
- Add workflow logging for debugging

## Timeline

**Total Time: 4-5 hours**

- Phase 1 (DB): 30 min
- Phase 2 (Capture): 30 min
- Phase 3 (Store): 30 min
- Phase 4 (Logic): 1-2 hours
- Phase 5 (Testing): 1 hour

**Recommended: Do incrementally over 1-2 days**

## Testing Strategy

### Incremental Validation

After each phase, verify:
1. No errors in n8n execution logs
2. Database queries return expected results
3. Drafts action still works
4. Existing functionality unaffected

### Integration Tests

**Test 1: Fresh Draft**
```
1. Create new draft in Drafts app
2. Send to Selene
3. Verify: INSERT with UUID
4. Query: SELECT source_uuid FROM raw_notes WHERE title = 'test'
```

**Test 2: Duplicate Detection**
```
1. Resend same draft (no edits)
2. Verify: SKIP (duplicate message)
3. Query: Confirm only 1 record with that UUID
```

**Test 3: Edit Detection**
```
1. Edit draft content in Drafts app
2. Resend to Selene
3. Verify: UPDATE (content updated)
4. Query: Confirm UUID same, content_hash different, status='pending'
5. Wait for LLM processing
6. Verify: Concepts re-extracted with new content
```

**Test 4: Backward Compatibility**
```
1. Send note without UUID (simulate non-Drafts source)
2. Verify: INSERT with NULL UUID
3. Query: Works with existing content_hash logic
```

## Documentation Updates

After implementation, update:

1. **workflow README** - Document UUID field in payloads
2. **Database schema doc** - Add `source_uuid` column
3. **Drafts integration guide** - Mention UUID tracking
4. **Current status** - Mark Phase 1.5 complete

## Dependencies

**Required:**
- Database: SQLite with `raw_notes` table
- Workflow: 01-ingestion active
- Drafts: Version that supports `draft.uuid` API

**No external dependencies added**

## Notes

- Draft UUIDs are provided by the Drafts app API via `draft.uuid`
- UUIDs are stable across app syncs (iCloud)
- UUIDs persist even if draft content changes
- Other sources (future: voice, email) won't have UUIDs - that's OK

## Related Issues

- User requested: "Track if draft with UUID X processed correctly"
- Foundation for edit history tracking
- Enables better duplicate detection
- Supports future draft sync dashboard

## Next Steps

1. Review and approve this plan
2. Start Phase 1: Database migration
3. Test incrementally after each phase
4. Update roadmap when complete

---

**Priority Justification:**

This is foundational work that should be done **before** adding more features. Without UUID tracking:
- Cannot answer "did draft X get processed?"
- Cannot handle draft edits intelligently
- Cannot build edit history or version tracking
- Difficult to debug "which note came from which draft?"

**User feedback:** "This feels important for the foundations" - CORRECT. This enables everything else.
