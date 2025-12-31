# Branch Status: phase-7.2/selenechat-planning

**Created:** 2025-12-31
**Design Doc:** docs/plans/2025-12-31-phase-7.2-selenechat-planning-design.md
**Current Stage:** dev
**Last Rebased:** 2025-12-31

## Overview

Add Planning tab to SeleneChat for guided breakdown conversations. Uses dual AI routing (Ollama for sensitive notes, Claude API for planning) and integrates with Things 3 via URL scheme. Methodology files control prompts/triggers without code changes.

## Dependencies

- Phase 7.1 complete (discussion_threads table exists)
- Things 3 installed with URL scheme enabled
- Claude API key for planning conversations

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
- [x] Core implementation complete
- [ ] All tests passing
- [ ] No linting/type errors
- [x] Code follows project patterns

### Testing
- [ ] Unit tests pass
- [ ] Integration tests pass (if applicable)
- [ ] Manual testing completed
- [ ] Edge cases verified
- [ ] Verified with superpowers:verification-before-completion

### Docs
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

## Implementation Plan

### Phase 7.2a: Foundation
- [x] Add `task_links` table migration
- [x] Create `ClaudeAPIService.swift`
- [x] Create `ThingsURLService.swift`
- [x] Create `PromptLoader.swift`
- [x] Create initial methodology files in `prompts/planning/`

### Phase 7.2b: Planning Tab
- [x] Add "Planning" to ContentView navigation
- [x] Create `PlanningView.swift` (thread list)
- [x] Create `PlanningThreadRow.swift`
- [x] Query `discussion_threads` from database

### Phase 7.2c: Planning Conversations
- [x] Create `PlanningConversationView.swift`
- [x] Integrate Claude API for responses
- [x] Implement task extraction from responses
- [x] Create tasks in Things automatically
- [x] Store relationships in `task_links`

### Phase 7.2d: Bidirectional Flow
- [ ] Implement Things status checking via AppleScript
- [ ] Add resurface trigger logic
- [ ] Update thread status based on task progress
- [ ] Add "review" state UI

### Phase 7.2e: Testing & Polish
- [ ] Unit tests for services
- [ ] Integration tests for Things URL scheme
- [ ] Test methodology file loading
- [ ] UI polish and error handling

---

## Notes

**2025-12-31:** Implementation plan created with 10 tasks:
- Tasks 1-3: Database foundation (task_links, DiscussionThread, queries)
- Tasks 4-5: Services (ClaudeAPIService, ThingsURLService)
- Tasks 6-8: UI (Navigation, PlanningView, ConversationView)
- Tasks 9-10: Methodology files and status
- See: `docs/plans/2025-12-31-phase-7.2-implementation-plan.md`

**2025-12-31:** Branch created. Design complete with key decisions:
- Things is the task database (no duplication)
- Dual AI routing (Ollama local, Claude API for planning)
- Methodology files for editable prompts/triggers
- Bidirectional Things flow with resurface triggers

**2025-12-31:** Phase 7.2a-c implementation complete (Tasks 1-10):
- Task 1: Database migration - Added `task_links` table via `add_task_links.sql`
- Task 2: Created `DiscussionThread` model with note/task associations
- Task 3: Added thread queries to `DatabaseService` (fetch threads, update status)
- Task 4: Created `ClaudeAPIService` with streaming support and task extraction
- Task 5: Created `ThingsURLService` for URL scheme task creation
- Task 6: Added Planning tab navigation to `ContentView`
- Task 7: Created `PlanningView` with thread list and filtering
- Task 8: Created `PlanningConversationView` with Claude integration
- Task 9: Created methodology files (`system-prompt.md`, `triggers.json`, `extraction-rules.md`)
- Task 10: Updated BRANCH-STATUS.md (this entry)
- Next: Testing stage - verify build, run tests, manual verification

---

## Blocked Items

None currently.
