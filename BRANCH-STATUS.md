# Branch Status: phase-7/planning-redesign

**Created:** 2026-01-02
**Design Doc:** docs/plans/2026-01-02-planning-inbox-redesign.md
**Current Stage:** planning
**Last Rebased:** 2026-01-02

## Overview

Redesigns Phase 7 planning flow: ALL notes go through SeleneChat Inbox for user triage before any tasks are created. Removes auto-task creation. Adds Active/Parked project structure.

Key changes:
- No auto-routing to Things (user confirms everything)
- Inbox triage with quick-action buttons
- Active vs Parked projects to prevent overwhelm
- Classification becomes UI hint, not routing decision

## Dependencies

- None - this is a design revision that supersedes parts of Phase 7.1/7.2

---

## Stages

### Planning
- [x] Design doc exists and approved
- [x] Conflict check completed (no overlapping work)
- [x] Dependencies identified and noted
- [x] Branch and worktree created
- [x] Implementation plan written (superpowers:writing-plans)

### Dev
- [ ] Tests written first (superpowers:test-driven-development)
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

### Docs
- [x] Design documents updated
- [ ] workflow STATUS.md updated (if workflow changed)
- [ ] README updated (if interface changed)
- [x] Roadmap docs updated
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

## Notes

This redesign came from a brainstorming session (2026-01-02) discussing user stories and whether the auto-routing model made sense. Key insights:

1. User wants to verify AI understanding before tasks are created
2. Automatic task creation could lead to Things inbox overwhelm
3. The planning conversation itself is valuable, even for "simple" tasks
4. Need Active/Parked distinction to prevent SeleneChat overwhelm
5. Context memory needed for reopening old projects with new notes

Future features identified:
- Parking lot rot detection (surface stale items)
- AI suggestions when Active doesn't appeal
- Task check-in conversations ("why haven't you done this?")
- Explicit "not this" correction for wrong project suggestions

---

## Blocked Items

None currently.
