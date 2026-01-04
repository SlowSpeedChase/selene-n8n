# Story-Driven Development

**Purpose:** Guide for working with user stories in Selene development.

---

## Quick Reference

```bash
# View dashboard
./scripts/story.sh status

# Create new story
./scripts/story.sh new feature-name

# Promote story to next state
./scripts/story.sh promote US-NNN

# List stories by state
./scripts/story.sh list [draft|ready|active|done]
```

---

## Story Lifecycle

```
draft/ → ready/ → active/ → done/
  │        │         │        │
Ideas   Refined   Working   Merged
         with       on       PR
       criteria   branch
```

### States

| State | What It Means | Requirements |
|-------|---------------|--------------|
| **draft/** | Idea captured, needs refinement | Has user story (As a... I want... So that...) |
| **ready/** | Actionable, can be started | Has acceptance criteria, ADHD check done |
| **active/** | Being worked on now | Has git branch, max 5 concurrent |
| **done/** | Completed and merged | PR merged, story archived |

---

## Working with Stories

### Creating a Story

```bash
./scripts/story.sh new time-blocking-feature
```

Creates `docs/stories/draft/US-NNN-time-blocking-feature.md` from template.

Edit to fill in:
1. User story (As a... I want... So that...)
2. Context (why it matters)
3. Acceptance criteria (testable)
4. ADHD design check
5. Technical notes

### Promoting a Story

```bash
# Draft → Ready (has acceptance criteria)
./scripts/story.sh promote US-017

# Ready → Active (starting work)
./scripts/story.sh promote US-017
# Creates branch: git worktree add -b US-017/daily-planning .worktrees/daily-planning main

# Active → Done (PR merged)
./scripts/story.sh promote US-017
```

**Constraints:**
- Cannot promote draft → ready without acceptance criteria
- Cannot have more than 5 active stories
- Moving to active suggests branch creation command

---

## Story Template Sections

### User Story

```markdown
As a **[type of user]**,
I want **[goal/desire]**,
So that **[benefit/value]**.
```

Focus on the user's perspective, not implementation.

### Context

Why does this matter? What problem does it solve? ADHD users especially benefit from understanding the "why" - it aids motivation and prioritization.

### Acceptance Criteria

Testable requirements. When are we done?

```markdown
- [ ] When X happens, Y should result
- [ ] User can see Z in the interface
- [ ] Data persists after app restart
```

### ADHD Design Check

Every story must pass this check:

```markdown
- [ ] **Reduces friction?** (fewer steps/decisions)
- [ ] **Visible?** (won't be forgotten)
- [ ] **Externalizes cognition?** (system remembers, not user)
```

If a feature fails all three, reconsider if it belongs in Selene.

### Technical Notes

- Dependencies (which stories must come first)
- Affected components (files, tables, workflows)
- Link to design doc if complex

---

## Branch Naming

**Old:** `phase-X.Y/feature-name`
**New:** `US-NNN/brief-description`

Examples:
- `US-001/auto-extract-tasks`
- `US-017/daily-planning`
- `US-022/n8n-upgrade`

---

## Commit Format

```
US-NNN: description

- Detail 1
- Detail 2
```

Example:
```
US-001: add task extraction prompt

- LLM prompt extracts verb-first tasks
- Handles multiple tasks per note
- Links back to raw_note_id
```

---

## PR Format

```
US-NNN: Story title

## Summary
[1-3 bullet points]

## Test plan
[How to verify]

## Acceptance criteria
- [x] Criterion 1
- [x] Criterion 2
```

---

## Integration with GitOps

Stories integrate with existing GitOps workflow:

1. **Planning:** Story moves draft → ready
2. **Start:** Story moves ready → active, create worktree
3. **Dev:** Work on feature, reference US-NNN in commits
4. **Review:** Create PR with story acceptance criteria
5. **Merge:** Story moves active → done, closure ritual

See `@.claude/GITOPS.md` for full development workflow.

---

## Design Docs

Stories and design docs work together:

- **Simple stories:** No design doc needed
- **Complex stories:** Create design doc, link from story
- **Existing design docs:** Stay in `docs/plans/`, linked from stories

When to create a design doc:
- Multiple components affected
- Architecture decisions needed
- Trade-offs to document
- XL effort stories

---

## INDEX.md

`docs/stories/INDEX.md` is the dashboard:

- Shows counts by state
- Lists all stories grouped by phase
- Quick links to each story file

**Keep it updated** when promoting stories.

---

## Do NOT

- Start work without a story (no "quick fixes" that grow)
- Have more than 5 active stories
- Skip acceptance criteria
- Forget the ADHD design check
- Create stories for trivial changes (just commit them)

---

## Related

- `@docs/stories/INDEX.md` - Story dashboard
- `@.claude/GITOPS.md` - Full development workflow
- `@scripts/story.sh` - Story management script
