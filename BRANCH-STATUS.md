# Branch Status: phase-7.2/selenechat-planning

**Created:** 2025-12-31
**Design Doc:** docs/plans/2025-12-31-phase-7.2-selenechat-planning-design.md
**Current Stage:** planning
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
- [ ] Add `task_links` table migration
- [ ] Create `ClaudeAPIService.swift`
- [ ] Create `ThingsURLService.swift`
- [ ] Create `PromptLoader.swift`
- [ ] Create initial methodology files in `prompts/planning/`

### Phase 7.2b: Planning Tab
- [ ] Add "Planning" to ContentView navigation
- [ ] Create `PlanningView.swift` (thread list)
- [ ] Create `PlanningThreadRow.swift`
- [ ] Query `discussion_threads` from database

### Phase 7.2c: Planning Conversations
- [ ] Create `PlanningConversationView.swift`
- [ ] Integrate Claude API for responses
- [ ] Implement task extraction from responses
- [ ] Create tasks in Things automatically
- [ ] Store relationships in `task_links`

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

**2025-12-31:** Branch created. Design complete with key decisions:
- Things is the task database (no duplication)
- Dual AI routing (Ollama local, Claude API for planning)
- Methodology files for editable prompts/triggers
- Bidirectional Things flow with resurface triggers

---

## Blocked Items

None currently.
