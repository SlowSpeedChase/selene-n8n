# Archive - 01-ingestion Workflow

This directory contains archived versions and experimental implementations of the ingestion workflow.

## Files

### workflow-v2-sqlite-nodes-experimental.json
**Date:** 2025-10-30
**Status:** Experimental - Not Used
**Description:** Alternative implementation using n8n's SQLite community nodes instead of better-sqlite3 in Function nodes.

**Why Archived:**
- Requires manual SQLite credential configuration in n8n UI
- More complex setup process
- The better-sqlite3 approach (used in main workflow.json) is simpler and more maintainable

**Technical Details:**
- Uses `n8n-nodes-sqlite.sqlite` nodes for database operations
- Parameterized queries with `:param` syntax
- Requires SQLite API credentials configured with path: `/selene/data/selene.db`

**When to Use:**
- If you prefer using n8n's built-in nodes over custom Function node code
- If you want better visual representation of SQL queries in the workflow
- If you need features specific to the SQLite community node

---

## Archive Policy

Files are archived when:
1. They represent experimental or alternative implementations
2. They're superseded by better solutions
3. They may be useful for reference but aren't part of the active codebase

Files are NOT deleted because:
- They document decision-making process
- They may contain useful patterns for future work
- They provide context for troubleshooting
