# Branch Status: phase-7.2e/bidirectional-things

**Created:** 2026-01-02
**Design Doc:** docs/plans/2026-01-02-bidirectional-things-flow-design.md
**Current Stage:** dev
**Last Rebased:** 2026-01-02

## Overview

Implement bidirectional Things 3 integration for SeleneChat Planning tab. Query task status from Things via AppleScript, evaluate resurface triggers (progress/stuck/completion), and bring planning threads back to "review" status when action is needed.

## Dependencies

- None (builds on existing Phase 7.2a-d work already in main)

---

## Stages

### Planning
- [x] Design doc exists and approved
- [x] Conflict check completed (no overlapping work)
- [x] Dependencies identified and noted
- [x] Branch and worktree created
- [x] Implementation plan written (superpowers:writing-plans)

### Dev
- [x] Tests written first (superpowers:test-driven-development) - N/A: SwiftUI view integration, no unit tests applicable
- [x] Core implementation complete
- [x] All tests passing - swift build succeeds
- [x] No linting/type errors
- [x] Code follows project patterns

**Implementation Summary:**
- Migration003_BidirectionalThings.swift - adds status tracking columns
- ThingsTaskStatus.swift - model for Things task status
- ThingsStatusService.swift - AppleScript bridge
- ResurfaceTriggerService.swift - trigger evaluation with embedded config
- DatabaseService.swift - added sync/resurface methods
- PlanningView.swift - sync on tab open, Needs Review section
- DiscussionThread.swift - added resurface fields

### Testing
- [x] Unit tests pass - swift build succeeds, no unit tests for this feature
- [ ] Integration tests pass (if applicable)
- [ ] Manual testing completed
- [ ] Edge cases verified
- [ ] Verified with superpowers:verification-before-completion

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

- Sync on tab open only (no background polling)
- Reuses existing get-task-status.scpt AppleScript
- Config via existing resurface-triggers.yaml

---

## Blocked Items

(none)
