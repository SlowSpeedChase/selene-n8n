# Process Gap Fixes Design

**Created:** 2026-01-03
**Status:** Ready for Implementation
**Effort:** ~1 hour total
**Trigger:** Codebase cleanup audit revealed process gaps

---

## Problem Statement

During codebase cleanup, five process gaps were identified that cause documentation drift, orphaned files, and incomplete closure of work:

1. Closure ritual not followed after merges
2. Documentation drift when patterns change
3. Plan INDEX.md not updated when work completes
4. Files landing in root instead of proper locations
5. One-time completion marker files created but never cleaned

---

## Implementation Plan

### Task 1: Add Closure Ritual Checklist (~10 min)

**File:** `.claude/GITOPS.md`

**Change:** Add explicit post-merge checklist after "Step 1: Final Merge" section:

```markdown
### Post-Merge Checklist (MANDATORY)

After merge completes, Claude MUST:

- [ ] Create archive summary in `docs/completed/YYYY-MM-DD-phase-X.Y-feature.md`
- [ ] Update `docs/plans/INDEX.md` - move design doc to "Completed" section
- [ ] Update `.claude/PROJECT-STATUS.md` - move to completed
- [ ] Remove worktree: `git worktree remove .worktrees/feature-name`
- [ ] Verify no BRANCH-STATUS.md in main: `ls BRANCH-STATUS.md` (should not exist)
- [ ] Announce completion to user
```

---

### Task 2: Add Doc Drift Prevention (~5 min)

**File:** `.claude/GITOPS.md` or `CLAUDE.md`

**Change:** Add to "Before modifying documentation" section:

```markdown
### When Changing a Process

Before updating how something works:

1. Search for all docs referencing the old pattern:
   ```bash
   grep -r "old-pattern" docs/ .claude/ workflows/
   ```
2. Update or delete ALL references
3. Don't leave old patterns documented alongside new ones
```

---

### Task 3: Enhance Pre-Commit Hook for INDEX.md (~30 min)

**File:** `.git/hooks/pre-commit` or `scripts/hooks/pre-commit`

**Change:** Add logic to detect when a design doc should move to "Completed":

```bash
# Check if committing to main with a merge commit message
if git log -1 --pretty=%B | grep -q "^Merge"; then
  # Extract branch name from merge message
  BRANCH=$(git log -1 --pretty=%B | grep -oP "phase-[\d.]+/[\w-]+")

  if [ -n "$BRANCH" ]; then
    # Check if INDEX.md has this in "Active" but not "Completed"
    if grep -q "$BRANCH" docs/plans/INDEX.md; then
      echo "[process] Reminder: Update docs/plans/INDEX.md to mark $BRANCH as Completed"
    fi

    # Check for orphaned BRANCH-STATUS.md
    if [ -f "BRANCH-STATUS.md" ]; then
      echo "[process] Warning: BRANCH-STATUS.md found in root - should be removed after merge"
    fi
  fi
fi
```

---

### Task 4: Add Root File Drift Warning (~10 min)

**File:** `.git/hooks/pre-commit` or `scripts/hooks/pre-commit`

**Change:** Add warning for new files in root:

```bash
# Warn on new files in root that should be elsewhere
NEW_ROOT_FILES=$(git diff --cached --name-only --diff-filter=A | grep -E '^[^/]+\.(sh|md)$' | grep -v -E '^(CLAUDE|ROADMAP|README)\.md$')

if [ -n "$NEW_ROOT_FILES" ]; then
  echo ""
  echo "[process] Warning: New files added to project root:"
  echo "$NEW_ROOT_FILES"
  echo ""
  echo "Consider moving to:"
  echo "  - Scripts (.sh) → scripts/"
  echo "  - Documentation (.md) → docs/ or docs/guides/"
  echo "  - Design docs (.md) → docs/plans/"
  echo ""
  read -p "Continue anyway? (y/N) " -n 1 -r
  echo
  if [[ ! $REPLY =~ ^[Yy]$ ]]; then
    exit 1
  fi
fi
```

---

### Task 5: Add Completion Marker Rule (~2 min)

**File:** `CLAUDE.md`

**Change:** Add to "Critical Rules (Do NOT)" section:

```markdown
**Documentation:**
- ❌ **NEVER create *_COMPLETE.md or *_STATUS.md files** - Use design doc status field and docs/completed/ archive instead
```

Also add to `SeleneChat/CLAUDE.md` if it has its own rules section.

---

## Verification

After implementation:

1. **Test closure reminder:** Make a test merge commit, verify reminder appears
2. **Test root file warning:** `touch test.sh && git add test.sh`, verify warning
3. **Verify docs updated:** Check CLAUDE.md and GITOPS.md have new content

---

## Files to Modify

| File | Change Type |
|------|-------------|
| `.claude/GITOPS.md` | Add closure checklist, doc drift prevention |
| `CLAUDE.md` | Add completion marker rule |
| `scripts/hooks/pre-commit` or `.git/hooks/pre-commit` | Add INDEX.md reminder, root file warning |

---

## Success Criteria

- [ ] Post-merge checklist documented in GITOPS.md
- [ ] Doc drift prevention documented
- [ ] Pre-commit hook warns about INDEX.md updates needed
- [ ] Pre-commit hook warns about new root files
- [ ] Completion marker anti-pattern documented in CLAUDE.md
