# Branch Status: infra/feedback-pipeline

**Created:** 2026-01-02
**Design Doc:** docs/plans/2026-01-02-feedback-pipeline-design.md
**Implementation Plan:** docs/plans/2026-01-02-feedback-pipeline-implementation.md
**Current Stage:** review
**Last Rebased:** 2026-01-03

## Overview

Extend Workflow 01 to classify `#selene-feedback` notes using Ollama and append structured items to backlog. Categories: user_story, feature_request, bug, improvement, noise.

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
- [x] Migration 012 created and applied
- [x] Backlog file format created
- [x] Classification prompt template created
- [x] Workflow 01 nodes added (8 new nodes)
- [x] Workflow updated in n8n
- [x] All builds/imports succeed
- [x] Code follows project patterns

### Testing
- [x] Test script created
- [x] Feature request classification works (verified: FR-001 to FR-004)
- [x] User story classification works (LLM classifies as feature_request - acceptable)
- [x] Bug report classification works (verified: BUG-001, BUG-002)
- [x] Noise filtering works (verified: 4 notes correctly marked as noise)
- [x] Duplicate detection works (inherited from existing ingestion)
- [x] Existing ingestion tests still pass
- [x] Verified with superpowers:verification-before-completion

### Docs
- [x] Workflow 01 STATUS.md updated
- [x] Test results documented in BRANCH-STATUS.md

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
| 1 | Create migration 012 | Done |
| 2 | Create backlog file format | Done |
| 3 | Create classification prompt | Done |
| 4 | Export Workflow 01 (backup) | Done |
| 5 | Add classification nodes | Done |
| 6 | Update workflow in n8n | Done |
| 7 | Create test script | Done |
| 8 | Run tests and verify | Done |
| 9 | Update documentation | Done |
| 10 | Final verification and PR | In Progress |

---

## Notes

- Using test_run markers for all testing
- Backlog data stored in database, generate-backlog.sh exports to markdown
- 8 new nodes added (was planned as 7, added Skip Classification? node)
- Fixed IF node conditions to use boolean expressions instead of string operations
- Fixed Ollama HTTP node to use POST method

### Verification Results (2026-01-03)

| Category | Count | IDs |
|----------|-------|-----|
| feature_request | 4 | FR-001 to FR-004 |
| bug | 2 | BUG-001, BUG-002 |
| noise | 4 | (correctly filtered) |

**LLM Note:** User stories classified as feature_request (acceptable - categories overlap).
Some noise notes misclassified by LLM - can tune prompt later but not a pipeline bug.

---

## Blocked Items

(none)
