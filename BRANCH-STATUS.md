# Branch Status: phase-7.2f/sub-project-suggestions

**Created:** 2026-01-02
**Design Doc:** docs/plans/2026-01-01-project-grouping-design.md (Phase 7.2f section)
**Current Stage:** planning
**Last Rebased:** 2026-01-02 (fresh from main)

## Overview

Sub-project suggestions feature: When a heading within a Things project accumulates 5+ tasks with a distinct sub-concept, surface a suggestion in SeleneChat for the user to spin it off as its own project.

Key behaviors:
- Detection: 5+ tasks in heading with distinct sub-concept
- Surfacing: Show suggestion card in SeleneChat
- Approval: Create new project, move tasks to it
- Decline: Suppress future suggestions for that heading

## Dependencies

- Phase 7.2a-e should be complete (project creation, headings, etc.)
- SeleneChat with PlanningView infrastructure
- Things bridge scripts

---

## Stages

### Planning
- [x] Design doc exists and approved
- [x] Conflict check completed (no overlapping work)
- [x] Dependencies identified and noted
- [x] Branch and worktree created
- [ ] Implementation plan written (superpowers:writing-plans)

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
- [ ] UAT sign-off (SeleneChat)

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

## Notes

**2026-01-02:** Branch created fresh from main. Starting planning stage.

---

## Blocked Items

None currently.
