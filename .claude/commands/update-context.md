---
name: update-context
description: Update CLAUDE.md files and code comments for AI navigation
---

Run the code-context-agent to analyze and update AI context files throughout the codebase.

Usage:
- `/update-context` - Update all CLAUDE.md files
- `/update-context <path>` - Update specific component (e.g., workflows/01-ingestion)
- `/update-context --validate` - Validate existing CLAUDE.md files
- `/update-context --check-staleness` - Report outdated context files
- `/update-context --full` - Full refresh of entire codebase

This command triggers the code-context-agent to maintain CLAUDE.md files (100-150 lines each) and minimal inline comments for non-obvious code.
