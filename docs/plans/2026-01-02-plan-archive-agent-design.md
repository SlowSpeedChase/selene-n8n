# Plan Archive Agent Design

**Date:** 2026-01-02
**Status:** Active
**Phase:** Infrastructure

---

## Overview

A git post-commit hook that automatically archives completed/superseded design documents and cleans up stale references, preventing "context rot" where old plans pollute Claude's working context.

**Problem solved:** 34 plan files (~24K lines) in `docs/plans/` include 11 completed and 3 superseded designs that can confuse Claude when exploring the codebase.

---

## Trigger

Runs as a **post-commit hook** after every successful commit.

**Skips when:**
- Commit message starts with `chore: archive stale` (recursion prevention)
- Running on a merge commit
- Running in a worktree (only archives in main repo)
- `docs/plans/` doesn't exist

---

## Detection Logic

### Priority 1: INDEX.md Status (authoritative)

| Status | Action |
|--------|--------|
| Completed | Archive immediately |
| Superseded | Archive immediately |
| Active | Never archive |
| In Progress | Never archive |

### Priority 2: Git History (for uncategorized items)

A document qualifies for archival if ALL conditions are met:

1. **Not in INDEX.md** OR listed as "Uncategorized"
2. **No modifications in 14+ days** - checked via `git log -1 --format=%cd <file>`
3. **Associated branch merged** - if filename contains a phase (e.g., `phase-7.2`), verify branch was merged to main
4. **No open references** - not referenced in CLAUDE.md's navigation table as "Primary Context"

### Safety Valves

- Files modified in current commit are skipped
- Manual override: Add `<!-- KEEP: reason -->` comment to prevent archival
- Dry-run mode: `ARCHIVE_DRY_RUN=1 git commit ...`

---

## Archival Process

### Step 1: Move Files

```
docs/plans/2025-11-27-modular-context-structure.md
    -> docs/plans/_archived/2025-11-27-modular-context-structure.md
```

### Step 2: Update INDEX.md

Remove entry from Completed/Superseded/Uncategorized tables. Add to collapsed "Archived" section:

```markdown
<details>
<summary>Archived (12 documents)</summary>

| Date | Document | Archived |
|------|----------|----------|
| 2025-11-27 | modular-context-structure.md | 2026-01-02 |
...
</details>
```

### Step 3: Clean References

Scan and update stale references in:
- `CLAUDE.md` (navigation table)
- `.claude/PROJECT-STATUS.md` (next priorities, achievements)
- `.claude/GITOPS.md` (example references)

For each reference:
- In navigation table -> remove the row
- In prose -> replace with `[archived]` note or remove sentence
- In "Recent Achievements" -> leave alone (historical record)

### Step 4: Commit Changes

```
chore: archive stale design documents

Archived 3 documents to docs/plans/_archived/:
- 2025-11-27-modular-context-structure.md (superseded)
- 2025-11-25-phase-7-1-gatekeeping-design.md (superseded)
- 2025-11-14-selenechat-db-integration.md (superseded)

Updated references in CLAUDE.md, PROJECT-STATUS.md
```

---

## Implementation Structure

### New Files

```
scripts/
├── hooks/
│   ├── pre-commit           # (existing) documentation validation
│   └── post-commit          # (new) triggers archival
├── archive-stale-plans.sh   # (new) main archival logic
└── setup-hooks.sh           # (updated) also symlinks post-commit

docs/plans/
└── _archived/               # (new) destination for archived plans
    └── .gitkeep
```

### post-commit Hook

```bash
#!/bin/bash
# Plan archival post-commit hook

# Skip if this is an archive commit (prevent recursion)
if git log -1 --format=%s | grep -q "^chore: archive stale"; then
    exit 0
fi

# Skip merge commits
if git rev-parse -q --verify MERGE_HEAD >/dev/null 2>&1; then
    exit 0
fi

# Skip in worktrees (only archive in main repo)
if [ -f "$(git rev-parse --git-dir)/commondir" ]; then
    exit 0
fi

# Run archival (silent unless changes made)
"$(dirname "$0")/../../scripts/archive-stale-plans.sh"
```

### setup-hooks.sh Update

Add to existing script:
```bash
ln -sf "../../scripts/hooks/post-commit" "$PROJECT_ROOT/.git/hooks/post-commit"
echo "  Post-commit hook installed (plan archival)"
```

---

## Edge Cases

### Worktree Handling

- Git hooks run in the worktree where commit happens
- Script detects worktrees via `git rev-parse --git-dir`
- Only archives in main repo; worktrees inherit from main

### Failure Behavior

- Hook failures are **non-blocking** (archival is maintenance, not validation)
- Errors logged to stderr but don't prevent original commit
- If archival commit fails, original commit still succeeds

### Manual Override

Add to any plan file header to prevent archival:
```markdown
<!-- KEEP: Still referenced by active feature work -->
```

### Dry-Run Mode

```bash
ARCHIVE_DRY_RUN=1 git commit -m "my change"
# Prints what would be archived without actually doing it
```

---

## Success Criteria

1. After implementation, `docs/plans/` contains only Active/In Progress documents
2. Claude Code sessions no longer discover superseded plans during exploration
3. INDEX.md stays current automatically
4. No manual intervention required for routine archival

---

## Future Considerations

- Could extend to other documentation directories if context rot spreads
- Could add "resurrection" command to un-archive a plan if needed
- Could integrate with doc-maintainer agent for broader documentation hygiene
