# Branch: phase-7.2/planning-tab-redesign

**Created:** 2026-01-03
**Status:** Testing
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
- [x] Task 1: Database migration (Migration005_ProjectThreads)
- [x] Task 2: Update DiscussionThread model
- [x] Task 3: Update Project model
- [x] Task 4: Add thread CRUD to DatabaseService
- [x] Task 5: Update ProjectService
- [x] Task 6: Create ThreadListView
- [x] Task 7: Create StartConversationSheet
- [x] Task 8: Update ProjectDetailView
- [x] Task 9: Update PlanningView sections
- [x] Task 10: Update ActiveProjectsList
- [x] Task 11: Update sidebar navigation
- [x] Task 12: Final build and test

### Testing
- [x] Build passes
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

## Implementation Summary

### Commits (12)
1. `69e358a` - feat(db): add Migration005 for thread-project relationship
2. `9279372` - feat(model): add projectId and threadName to DiscussionThread
3. `570b135` - feat(model): add isSystem, threadCount, hasReviewBadge to Project
4. `9eadf84` - feat(db): add thread-project CRUD operations
5. `1d9ef31` - feat(service): add thread count and review badge to ProjectService
6. `6e7af6f` - feat(view): add ThreadListView component
7. `498ae55` - feat(view): add StartConversationSheet for project picker
8. `e6308b9` - feat(view): add thread list to ProjectDetailView
9. `08cc1be` - feat(view): reorder Planning tab sections, add Scratch Pad
10. `15bdbc4` - feat(view): add review badge and thread count to project rows

### Files Changed
- **New files:** Migration005_ProjectThreads.swift, ThreadListView.swift, StartConversationSheet.swift
- **Modified:** DiscussionThread.swift, Project.swift, DatabaseService.swift, ProjectService.swift, ProjectDetailView.swift, PlanningView.swift, ActiveProjectsList.swift

---

## Notes

- Existing standalone threads will migrate to Scratch Pad project
- System Scratch Pad project created in migration (is_system = 1)
- Legacy needsReviewSection and planningThreadsSection kept for backward compatibility but no longer shown in main view
