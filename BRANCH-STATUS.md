# Branch Status: feature/selenechat-vector-search

**Created:** 2026-01-27
**Design Doc:** docs/plans/2026-01-27-selenechat-vector-search-design.md
**Current Stage:** dev
**Last Rebased:** 2026-01-27

## Overview

Integrate SeleneChat with the new HTTP API vector search endpoints (`/api/search`, `/api/related-notes`) built during the LanceDB transition. Adds semantic search and related notes UI to the macOS app.

## Dependencies

- [x] LanceDB transition complete (PR #28 merged)
- [x] API endpoints built (`/api/search`, `/api/related-notes`)
- [ ] Selene server running (launchd agent)

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

## Implementation Tasks (from design doc)

1. **Add APIService to SeleneChat** - HTTP client for Selene backend
2. **Add Hybrid Retrieval to DatabaseService** - API first, SQLite fallback
3. **Add "Related Notes" UI Component** - Show related notes with relationship types
4. **Update QueryAnalyzer for Semantic Mode** - Route queries appropriately

## Acceptance Criteria

- [ ] SeleneChat can call `/api/search` and display results
- [ ] SeleneChat can call `/api/related-notes` for current note
- [ ] Graceful fallback when API unavailable
- [ ] Related notes visible in UI with relationship type

---

## Notes

Running notes, decisions, questions, etc.

---

## Blocked Items

Move any blocked checklist items here with reason:

- None
