# GitOps Development Practices

**Purpose:** Standardized workflow for parallel development streams. Claude MUST follow these practices for all development work.

**Related Context:**
- `@.claude/DEVELOPMENT.md` - Architecture and patterns
- `@.claude/OPERATIONS.md` - Daily commands
- `@templates/BRANCH-STATUS.md` - Branch status template

---

## Core Principles

1. **Visibility** - All work state visible in BRANCH-STATUS.md
2. **Isolation** - Each piece of work in its own worktree/branch
3. **Checkpoints** - Explicit stages with checklists
4. **Traceability** - Phase-based naming; full closure ritual
5. **Currency** - Frequent rebasing keeps branches healthy

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

---

## Branch Naming Convention

```
phase-X.Y/short-description
```

**Examples:**
- `phase-7.1/task-extraction`
- `phase-7.2/selenechat-planning`
- `phase-3.1/pattern-detection-fix`

---

## The Complete Workflow

```
┌─────────────────────────────────────────────────────────────────┐
│ 1. KICKOFF                                                       │
│    Design doc approved → Conflict check → Create worktree       │
│    → Initialize BRANCH-STATUS.md                                │
└─────────────────────────────────────────────────────────────────┘
                              ↓
┌─────────────────────────────────────────────────────────────────┐
│ 2. DEVELOPMENT LOOP                                              │
│    Stages: planning → dev → testing → docs → review → ready    │
│    - Claude prompts to help with each checklist item            │
│    - Mark items complete only when done                         │
│    - Rebase frequently                                          │
└─────────────────────────────────────────────────────────────────┘
                              ↓
┌─────────────────────────────────────────────────────────────────┐
│ 3. CLOSURE RITUAL                                                │
│    Merge → Archive summary → Update roadmap →                   │
│    Update PROJECT-STATUS → Remove worktree → Announce           │
└─────────────────────────────────────────────────────────────────┘
```

---

## Stage 1: Kickoff Process

Before creating a branch, complete this formal intake:

### Step 1: Design Document
- Must have approved design in `docs/plans/YYYY-MM-DD-<topic>-design.md`
- Design includes: scope, architecture, success criteria
- User approves design before proceeding

### Step 2: Conflict Check
```bash
# List all active worktrees
git worktree list

# Review each BRANCH-STATUS.md for potential overlaps
```
- Note any dependencies or coordination needed

### Step 3: Create Branch and Worktree
```bash
git worktree add -b phase-X.Y/feature-name .worktrees/feature-name main
cd .worktrees/feature-name
```

### Step 4: Initialize BRANCH-STATUS.md
Copy from `templates/BRANCH-STATUS.md` and fill in:
- Branch name and dates
- Link to design doc
- Overview of work
- Any dependencies

---

## Stage 2: Development Loop

### Checkpoint Stages

| Stage | Purpose | Key Checklist Items |
|-------|---------|---------------------|
| **planning** | Finalize approach | Design approved, plan written |
| **dev** | Build it | Tests first, implementation, no errors |
| **testing** | Verify it works | All tests pass, manual testing, edge cases, UAT sign-off (SeleneChat) |
| **docs** | Document it | STATUS.md, README, roadmap |
| **review** | Get approval | Code reviewed, feedback addressed |
| **ready** | Prepare to merge | Rebased, final tests, all checks complete |

### Superpowers Skills by Stage

| Stage | Required Skills |
|-------|-----------------|
| **planning** | `superpowers:brainstorming`, `superpowers:writing-plans`, `superpowers:using-git-worktrees` |
| **dev** | `superpowers:test-driven-development`, `superpowers:subagent-driven-development` |
| **testing** | `superpowers:systematic-debugging`, `superpowers:verification-before-completion` |
| **review** | `superpowers:requesting-code-review`, `superpowers:receiving-code-review` |
| **ready** | `superpowers:finishing-a-development-branch` |

**Claude MUST invoke the relevant skill before starting stage work.**

### Working Through Checklists

For each unchecked item, Claude:
1. States what the item requires
2. Offers to help complete it
3. Waits for completion or user direction
4. Marks complete only when actually done

**Example:**
```
Claude: "Next item: 'Tests written'
         This needs unit tests for the classification logic.
         Want me to write these tests now?"

User: "yes"

Claude: [writes tests]
        "Tests written and passing. Marking complete.

         Next item: 'No linting errors'
         Want me to run the linter and fix any issues?"
```

### Stage Transitions

When all items in a stage are checked:
1. Announce: "Stage [X] complete. Moving to [Y]."
2. Update `Current Stage:` in BRANCH-STATUS.md
3. Commit: `git commit -m "checkpoint: [stage] complete"`

### Blocked Items

If an item can't be completed:
- Add `BLOCKED:` prefix with reason
- Move to "Blocked Items" section in BRANCH-STATUS.md
- Continue with other items if possible

---

## Rebase Strategy

Branches must stay current with main.

### When to Rebase
- Before starting any new work session on a branch
- After another branch merges to main
- Before entering `review` stage
- Before entering `ready` stage

### How to Rebase
```bash
git fetch origin
git rebase origin/main

# If conflicts, resolve then:
git add <resolved files>
git rebase --continue

# Update BRANCH-STATUS.md and commit
```

### Checking Branch Status
```bash
# See all active work
git worktree list

# Commits in branch not in main
git log --oneline main..HEAD

# Commits in main not in branch
git log --oneline HEAD..main
```

---

## Stage 3: Closure Ritual

When work is merged, complete this full closure:

### Step 1: Final Merge
```bash
git checkout main
git pull origin main
git merge phase-X.Y/feature-name
git push origin main
```

### Step 2: Archive Summary
Create `docs/completed/YYYY-MM-DD-phase-X.Y-feature-name.md`:

```markdown
# Completed: Phase X.Y - Feature Name

**Completed:** YYYY-MM-DD
**Branch:** phase-X.Y/feature-name
**Duration:** X days (started YYYY-MM-DD)

## Summary
Brief description of what was built.

## Key Changes
- List of significant changes
- Files added/modified
- New capabilities

## Design Doc
Link to: docs/plans/YYYY-MM-DD-design.md

## Lessons Learned
- What went well
- What was harder than expected
- Notes for future similar work
```

### Step 3: Update Roadmap
- Mark phase/feature complete in `docs/roadmap/`
- Update `ROADMAP.md` status
- Add to version history

### Step 4: Update PROJECT-STATUS.md
- Move from "In Progress" to "Completed"
- Update any related status

### Step 5: Cleanup
```bash
git worktree remove .worktrees/feature-name
git branch -d phase-X.Y/feature-name  # optional
```

### Step 6: Announce
Claude summarizes: "Phase X.Y complete. [Brief summary]. Archived to docs/completed/."

### Post-Merge Verification Checklist

**Claude MUST verify all items before announcing completion:**

- [ ] Archive summary created in `docs/completed/`
- [ ] `docs/plans/INDEX.md` updated - design doc moved to "Completed" section
- [ ] `.claude/PROJECT-STATUS.md` updated
- [ ] Worktree removed
- [ ] No `BRANCH-STATUS.md` in main root: `ls BRANCH-STATUS.md` should fail
- [ ] No orphaned files left in project root

**If any item is missed, complete it before announcing.**

---

## Commands Cheat Sheet

```bash
# Start new work
git worktree add -b phase-X.Y/name .worktrees/name main
cd .worktrees/name
cp ../../templates/BRANCH-STATUS.md ./BRANCH-STATUS.md

# Check active work
git worktree list

# Check for updates from main
git fetch origin
git log --oneline HEAD..origin/main

# Rebase on main
git rebase origin/main

# Stage checkpoint commit
git commit -m "checkpoint: [stage] complete"

# Cleanup after merge
git worktree remove .worktrees/name
git branch -d phase-X.Y/name
```

---

## Quick Reference: Stage Checklists

### Planning
- [ ] Design doc exists and approved
- [ ] Conflict check completed
- [ ] Dependencies identified
- [ ] Branch and worktree created
- [ ] Implementation plan written

### Dev
- [ ] Tests written first (TDD)
- [ ] Core implementation complete
- [ ] All tests passing
- [ ] No linting/type errors
- [ ] Code follows project patterns

### Testing
- [ ] Unit tests pass
- [ ] Integration tests pass (if applicable)
- [ ] Manual testing completed
- [ ] Edge cases verified
- [ ] Verified with superpowers:verification-before-completion
- [ ] UAT sign-off (SeleneChat only - see `SeleneChat/Tests/UAT/`)

### Docs
- [ ] workflow STATUS.md updated (if workflow changed)
- [ ] README updated (if interface changed)
- [ ] Roadmap docs updated
- [ ] Code comments where needed

### Review
- [ ] Requested review (superpowers:requesting-code-review)
- [ ] Review feedback addressed
- [ ] Changes approved

### Ready
- [ ] Rebased on latest main
- [ ] Final test pass after rebase
- [ ] BRANCH-STATUS.md fully checked
- [ ] Ready for merge

---

## GitHub Conventions

### Commit Message Format

```
type(scope): description

[optional body]

🤖 Generated with [Claude Code](https://claude.com/claude-code)

Co-Authored-By: Claude Opus 4.5 <noreply@anthropic.com>
```

**Types:** `feat`, `fix`, `docs`, `refactor`, `test`, `chore`

**Scopes:** workflow number (01, 07), component name (selenechat, scripts), or `docs`

**Examples:**
```
feat(07): add task classification node
fix(selenechat): resolve database connection timeout
docs: update GITOPS with commit conventions
refactor(scripts): simplify workflow export logic
```

### Pull Request Format

```markdown
## Summary
- [1-3 bullet points describing the change]

## Changes
- List of files/components changed
- Any breaking changes

## Test Plan
- [ ] Tests pass
- [ ] Manual verification completed

## Design Doc
Link: docs/plans/YYYY-MM-DD-*.md (if applicable)

🤖 Generated with [Claude Code](https://claude.com/claude-code)
```

### Branch Merge Process

1. Ensure all stage checklists are complete
2. Create PR with format above
3. Request review if significant changes
4. Squash merge to main (keeps history clean)
5. Complete closure ritual (see Stage 3 above)

---

## Documentation Maintenance

### Preventing Documentation Drift

When changing how a process works, **search for all references before updating**:

```bash
# Before changing a pattern, find all docs that reference it
grep -r "old-pattern-name" docs/ .claude/ workflows/ scripts/

# Example: before removing workflow-test.json pattern
grep -r "workflow-test" docs/ .claude/ workflows/
```

**Rule:** Don't leave old patterns documented alongside new ones. Update or delete ALL references.

### When to Update Documentation

| Trigger | Action |
|---------|--------|
| Process changes | Search and update all references |
| File moves | Update all path references |
| Feature completes | Move design doc to "Completed" in INDEX.md |
| Pattern deprecated | Remove from all docs, not just primary one |

---

## Related Documents

- `@templates/BRANCH-STATUS.md` - Full template for branch status
- `@docs/completed/` - Archive of completed work
- `@.claude/DEVELOPMENT.md` - Architecture and patterns
- `@.claude/PROJECT-STATUS.md` - Current project state
