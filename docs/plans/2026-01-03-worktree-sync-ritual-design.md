# Worktree Sync Ritual Design

**Created:** 2026-01-03
**Status:** Completed
**Implemented:** 2026-01-03
**Problem:** Feature branches diverge from main during 2-3 session work, causing painful rebases at merge time

---

## Problem Statement

When working on feature branches in worktrees:
1. Work spans 2-3 sessions (a few days)
2. Other work gets merged to main during this time
3. Divergence is only discovered at merge time
4. Late rebases are more painful than early ones

## Solution: Session Start Ritual

Add a mandatory check when Claude enters any worktree. Catch drift early, rebase frequently, avoid merge-time surprises.

---

## Implementation

### 1. The Trigger & Check

**When it fires:**
- Claude enters any worktree directory (`.worktrees/*`)
- This happens when: user asks to work on a feature, Claude switches context, or session starts in a worktree

**What Claude does:**
```bash
git fetch origin
BEHIND=$(git rev-list --count HEAD..origin/main)
```

**The announcement:**
- If `BEHIND > 0`: "Main has X new commits since you branched. Rebase now before continuing?"
- If `BEHIND = 0`: Silent (no interruption)

**User response options:**
- "Yes" → Claude runs `git rebase origin/main`, handles conflicts if any
- "No, continue anyway" → Claude notes the risk and proceeds
- "Show me what changed" → Claude shows `git log --oneline HEAD..origin/main`

### 2. Documentation Locations

**Primary: GITOPS.md**
Add "Session Start Ritual" section near the top, after Core Principles. This is the canonical procedure.

**Secondary: CLAUDE.md**
Add "MANDATORY: Worktree Sync Check" section with trigger conditions. Points to GITOPS.md for full procedure.

### 3. GITOPS.md Addition

Insert after "Core Principles", before "Branch Naming Convention":

```markdown
---

## Session Start Ritual (MANDATORY)

**Before doing ANY work in a worktree, Claude MUST check for divergence:**

### Step 1: Fetch and Check
```bash
git fetch origin
BEHIND=$(git rev-list --count HEAD..origin/main)
```

### Step 2: Announce if Behind
If `BEHIND > 0`:
> "Main has [X] new commits. Rebase now before continuing?"

Options to offer:
- **Rebase now** (recommended) → `git rebase origin/main`
- **Show changes first** → `git log --oneline HEAD..origin/main`
- **Skip** (not recommended) → Note risk, proceed

If `BEHIND = 0`: Proceed silently.

### Step 3: Handle Rebase
If rebasing and conflicts occur:
1. Show conflicting files
2. Offer to help resolve
3. Complete with `git rebase --continue`

**Why this matters:** Small, frequent rebases are painless. Large rebases after days of drift cause merge conflicts and frustration.
```

### 4. CLAUDE.md Addition

Add after "MANDATORY: Workflow Procedure Check":

```markdown
---

## MANDATORY: Worktree Sync Check

**BEFORE doing ANY work in a `.worktrees/*` directory, you MUST:**

1. Run: `git fetch origin && git rev-list --count HEAD..origin/main`
2. If behind: Announce and offer to rebase before proceeding
3. See `@.claude/GITOPS.md` (Session Start Ritual) for full procedure

**Trigger conditions:**
- User asks to continue work on a feature branch
- Session starts with working directory in `.worktrees/*`
- Switching from main repo to a worktree

**This is not optional.** Skipping this leads to painful rebases at merge time.
```

---

## Success Criteria

1. Claude always checks divergence when entering a worktree
2. User is informed before main drifts too far
3. Rebases happen in small increments, not all at once at merge time
4. Merge-time surprises are eliminated

---

## Implementation Tasks

1. [ ] Add "Session Start Ritual" section to `.claude/GITOPS.md`
2. [ ] Add "MANDATORY: Worktree Sync Check" section to `CLAUDE.md`
3. [ ] Update `docs/plans/INDEX.md` with this design
