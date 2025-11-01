# Archive: Previous Workflow Versions

This folder contains previous versions of the Obsidian export workflow.

## workflow-standard.json

**Description:** Original simple export workflow
**Date Archived:** October 30, 2025
**Reason:** Replaced with ADHD-optimized version

### Features (Standard Version)

- Single daily export at 7am
- Date-based organization only
- Basic markdown formatting
- Simple concept indexing
- Minimal metadata

### Why Archived

The standard version was replaced with a comprehensive ADHD-optimized version that includes:
- Multiple organization paths (concept, theme, energy, date)
- Visual status indicators
- Action item extraction
- Brain state tracking
- Hourly + on-demand export
- ADHD insights

### Can I Still Use It?

Yes! If you prefer the simpler approach:

1. **Rename to restore:**
   ```bash
   cp archive/workflow-standard.json workflow-standard-restored.json
   ```

2. **Import to n8n** as a separate workflow

3. **Update vault path** in the function node (line ~113)

4. **Deactivate ADHD workflow** if you don't want both running

### Comparison

| Feature | Standard (This Archive) | ADHD-Optimized (Current) |
|---------|------------------------|--------------------------|
| Export frequency | Once daily (7am) | Hourly + on-demand |
| Organization | 1 path (date) | 4 paths (concept/theme/energy/date) |
| ADHD features | None | 8 major systems |
| Metadata fields | 5 basic | 20+ comprehensive |
| File size | ~9KB | ~20KB |

### Documentation

For the current ADHD-optimized version, see:
- [../README.md](../README.md) - Main overview
- [../docs/OBSIDIAN-EXPORT-GUIDE.md](../docs/OBSIDIAN-EXPORT-GUIDE.md) - Complete guide
- [../docs/OBSIDIAN-EXPORT-COMPARISON.md](../docs/OBSIDIAN-EXPORT-COMPARISON.md) - Detailed comparison

---

**Note:** This is the archive folder. The current production workflow is `workflow.json` in the parent directory.
