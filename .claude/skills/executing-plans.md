---
name: Executing Plans
description: Execute detailed plans in batches with review checkpoints
when_to_use: when partner provides a complete implementation plan to execute in controlled batches with review checkpoints
version: 2.3.0
---

# Executing Plans

## Overview

Load plan, review critically, execute tasks in batches, report for review between batches.

**Core principle:** Batch execution with checkpoints for architect review.

**Announce at start:** "I'm using the Executing Plans skill to implement this plan."

## TDD is Mandatory

**Before writing ANY implementation code, you MUST invoke `superpowers:test-driven-development`.**

This is not optional. This is not "if the plan mentions tests." Every feature, every bugfix, every behavior change requires TDD.

```
Plan says "implement X" → Write failing test FIRST → Then implement
Plan says "add Y feature" → Write failing test FIRST → Then implement
Plan says "fix Z bug" → Write failing test FIRST → Then implement
```

**Red flags (you're rationalizing):**
- "The plan doesn't mention tests" → TDD is implicit in ALL dev work
- "This is too simple to test" → Simple code breaks. Test it.
- "I'll add tests after" → Tests-after prove nothing. Start over.
- "Let me just get it working first" → That's not TDD. Stop.

**If you wrote implementation code before a failing test existed, delete it and start over.**

## The Process

### Step 0: Session Start Ritual (if in worktree)

**MANDATORY before any work in a `.worktrees/*` directory:**

```bash
git fetch origin
BEHIND=$(git rev-list --count HEAD..origin/main)
```

If behind: "Main has [X] new commits. Rebase now before continuing?"
- Offer rebase, show changes, or skip (note risk)

**See:** `@.claude/GITOPS.md` for full procedure

### Step 1: Load and Review Plan
1. Read plan file
2. **Check:** Does this work belong in a worktree? If significant feature work, create one per GITOPS.md
3. **Check:** If in worktree, does BRANCH-STATUS.md exist? If not, create from template
4. Review critically - identify any questions or concerns about the plan
5. If concerns: Raise them with your human partner before starting
6. If no concerns: Create TodoWrite and proceed

### Step 2: Execute Batch
**Default: First 3 tasks**

For each task:
1. Mark as in_progress
2. **If task involves writing code:** Invoke `superpowers:test-driven-development` FIRST
   - Write failing test before ANY implementation
   - Watch test fail (mandatory - never skip)
   - Write minimal code to pass
   - Refactor only after green
3. **Invoke other required skills for current stage** (see GitOps Skills below)
4. Follow each step exactly (plan has bite-sized steps)
5. Run verifications as specified
6. Mark as completed
7. **Update BRANCH-STATUS.md** checklist if in worktree

**TDD Checkpoint:** Before marking a coding task complete, verify:
- [ ] Test existed before implementation
- [ ] Watched test fail
- [ ] Implementation is minimal (no YAGNI)
- [ ] All tests pass

### Step 3: Report
When batch complete:
- Show what was implemented
- Show verification output
- **Show current BRANCH-STATUS.md stage progress** (if in worktree)
- Say: "Ready for feedback."

### Step 4: Continue
Based on feedback:
- Apply changes if needed
- Execute next batch
- **At stage boundaries:** Announce stage transition, update BRANCH-STATUS.md
- Repeat until complete

### Step 5: Complete Development

After all tasks complete and verified:
- Announce: "I'm using the Finishing a Development Branch skill to complete this work."
- Switch to skills/collaboration/finishing-a-development-branch
- Follow that skill to verify tests, present options, execute choice
- **If merged:** Complete closure ritual per GITOPS.md (archive, update roadmap, cleanup worktree)

## When to Stop and Ask for Help

**STOP executing immediately when:**
- Hit a blocker mid-batch (missing dependency, test fails, instruction unclear)
- Plan has critical gaps preventing starting
- You don't understand an instruction
- Verification fails repeatedly

**Ask for clarification rather than guessing.**

## When to Revisit Earlier Steps

**Return to Review (Step 1) when:**
- Partner updates the plan based on your feedback
- Fundamental approach needs rethinking

**Don't force through blockers** - stop and ask.

## Remember
- **TDD is mandatory** - test before code, always
- Review plan critically first
- Follow plan steps exactly
- Don't skip verifications
- Reference skills when plan says to
- Between batches: just report and wait
- Stop when blocked, don't guess

---

## GitOps Integration (This Repository)

**Full reference:** `@.claude/GITOPS.md`

### Required Skills by Stage

| Stage | Required Skills |
|-------|-----------------|
| **planning** | `superpowers:brainstorming`, `superpowers:writing-plans`, `superpowers:using-git-worktrees` |
| **dev** | `superpowers:test-driven-development`, `superpowers:subagent-driven-development` |
| **testing** | `superpowers:systematic-debugging`, `superpowers:verification-before-completion` |
| **review** | `superpowers:requesting-code-review`, `superpowers:receiving-code-review` |
| **ready** | `superpowers:finishing-a-development-branch` |

**Invoke the relevant skill before starting stage work.**

### Stage Checkpoints

When completing a development stage:
1. Announce: "Stage [X] complete. Moving to [Y]."
2. Update `Current Stage:` in BRANCH-STATUS.md
3. Commit: `git commit -m "checkpoint: [stage] complete"`

### Closure Ritual (After Merge)

- [ ] Archive summary created in `docs/completed/`
- [ ] `docs/plans/INDEX.md` updated
- [ ] `.claude/PROJECT-STATUS.md` updated
- [ ] Worktree removed
- [ ] No orphaned files in project root

**Don't announce completion until all closure items are done.**
