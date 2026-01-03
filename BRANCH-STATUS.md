# Branch Status: infra/feedback-pipeline

**Created:** 2026-01-02
**Design Doc:** docs/plans/2026-01-02-feedback-pipeline-design.md
**Implementation Plan:** docs/plans/2026-01-02-feedback-pipeline-implementation.md
**Current Stage:** planning
**Last Rebased:** 2026-01-02

## Overview

Extend Workflow 01 to classify `#selene-feedback` notes using Ollama and append structured items to `docs/backlog/user-stories.md`. Categories: user_story, feature_request, bug, improvement, noise.

## Dependencies

- Workflow 01 (Ingestion) - must be working
- Ollama running with mistral:7b
- `feedback_notes` table exists (migration 009)

---

## Stages

### Planning
- [x] Design doc exists and approved
- [x] Conflict check completed (no overlapping work)
- [x] Dependencies identified and noted
- [x] Branch and worktree created
- [x] Implementation plan written

### Dev
- [ ] Migration 012 created and applied
- [ ] Backlog file format created
- [ ] Classification prompt template created
- [ ] Workflow 01 nodes added (7 new nodes)
- [ ] Workflow updated in n8n
- [ ] All builds/imports succeed
- [ ] Code follows project patterns

### Testing
- [ ] Test script created
- [ ] User story classification works
- [ ] Feature request classification works
- [ ] Bug report classification works
- [ ] Noise filtering works
- [ ] Duplicate detection works
- [ ] Existing ingestion tests still pass
- [ ] Verified with superpowers:verification-before-completion

### Docs
- [ ] Workflow 01 STATUS.md updated
- [ ] Test results documented

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

## Implementation Tasks

| # | Task | Status |
|---|------|--------|
| 1 | Create migration 012 | Pending |
| 2 | Create backlog file format | Pending |
| 3 | Create classification prompt | Pending |
| 4 | Export Workflow 01 (backup) | Pending |
| 5 | Add classification nodes | Pending |
| 6 | Update workflow in n8n | Pending |
| 7 | Create test script | Pending |
| 8 | Run tests and verify | Pending |
| 9 | Update documentation | Pending |
| 10 | Final verification and PR | Pending |

---

## Notes

- Using test_run markers for all testing
- Test backlog writes to user-stories-test.md (not production)
- Noise/duplicate items logged but not added to backlog

---

## Blocked Items

(none)
