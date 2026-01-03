# Branch: phase-7.2/planning-tab-redesign

**Created:** 2026-01-03
**Status:** Development
**Design:** `docs/plans/2026-01-03-planning-tab-redesign.md`
**Implementation Plan:** `docs/plans/2026-01-03-planning-tab-implementation.md`
**Last Rebased:** 2026-01-03

---

## Overview

Restructure Planning tab so projects contain threads, Active Projects appears first, and no standalone conversations exist.

## Key Changes

- Section order: Active Projects -> Scratch Pad (if populated) -> Suggestions -> Inbox -> Parked
- Projects contain sub-topic threads with focused conversations
- Thread auto-naming from first message
- Scratch Pad as default catch-all project (hidden until populated)
- Resurface alerts as badges on projects, not separate section
- One SeleneChat project = One Things project, threads = headings

---

## Stage Checklist

### Planning
- [x] Design document created
- [x] Open questions resolved
- [x] Worktree created
- [x] Implementation plan written

### Development
- [ ] Task 1: Database migration (Migration005_ProjectThreads)
- [ ] Task 2: Update DiscussionThread model
- [ ] Task 3: Update Project model
- [ ] Task 4: Add thread CRUD to DatabaseService
- [ ] Task 5: Update ProjectService
- [ ] Task 6: Create ThreadListView
- [ ] Task 7: Create StartConversationSheet
- [ ] Task 8: Update ProjectDetailView
- [ ] Task 9: Update PlanningView sections
- [ ] Task 10: Update ActiveProjectsList
- [ ] Task 11: Update sidebar navigation
- [ ] Task 12: Final build and test

### Testing
- [ ] Build passes
- [ ] Manual testing complete
- [ ] Edge cases verified

### Documentation
- [ ] CLAUDE.md updated if needed
- [ ] README updates if user-facing

### Review
- [ ] Code review requested
- [ ] Feedback addressed

### Ready
- [ ] All tests pass
- [ ] Ready for merge

---

## Files to Modify

### Database
- `Migration005_ProjectThreads.swift` - New migration for thread structure

### Models
- `DiscussionThread.swift` - Add project_id, thread_name
- `Project.swift` - Add isSystem, threadCount, hasReviewBadge

### Services
- `DatabaseService.swift` - Thread CRUD operations
- `ProjectService.swift` - Thread management

### Views
- `PlanningView.swift` - Reorder sections, remove standalone threads section
- `ProjectDetailView.swift` - Add thread list
- `ThreadListView.swift` - New component
- `StartConversationSheet.swift` - New component for project picker

---

## Notes

- Existing standalone threads will migrate to Scratch Pad project
- System Scratch Pad project created in migration (is_system = 1)
