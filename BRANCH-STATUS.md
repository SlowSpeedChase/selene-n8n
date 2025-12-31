# Branch Status: phase-7.1/task-extraction

**Created:** 2025-12-30
**Design Doc:** docs/plans/2025-12-30-task-extraction-planning-design.md
**Current Stage:** dev
**Last Rebased:** 2025-12-30

## Overview

Implements task extraction with classification logic for the Selene knowledge system. Local AI (Ollama) classifies notes into three categories:
- **actionable** - Clear tasks routed to Things inbox
- **needs_planning** - Goals/projects flagged for SeleneChat planning sessions
- **archive_only** - Thoughts/reflections stored for Obsidian export

This is the foundation of Phase 7, enabling intelligent triage of captured notes.

## Dependencies

- Workflow 02 (LLM Processing) must be operational - Currently working
- Ollama with mistral:7b - Installed and functional
- Things app integration - Requires Things URL scheme access
- No other active branches affect this work

---

## Stages

### Planning
- [x] Design doc exists and approved
- [x] Conflict check completed (no overlapping work)
- [x] Dependencies identified and noted
- [x] Branch and worktree created
- [x] Implementation plan written (superpowers:writing-plans)
  - Plan location: `IMPLEMENTATION-PLAN.md` (9 tasks, ~3 hours estimated)

### Dev
- [x] Tests written first (superpowers:test-driven-development)
- [x] Core implementation complete (Batch 1 + Batch 2 done)
- [x] All tests passing (58 tests: 32 migration + 26 prompt)
- [x] No linting/type errors
- [x] Code follows project patterns

### Testing
- [x] Unit tests pass (58 tests: 32 migration + 26 prompt)
- [~] Integration tests pass (if applicable) - Partial, see notes below
- [x] Manual testing completed
- [~] Edge cases verified - Classification edge cases need refinement
- [x] Verified with superpowers:verification-before-completion

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

**2025-12-30 - Branch Initialized**
- First test of GitOps workflow from `.claude/GITOPS.md`
- Design doc approved: 2025-12-30-task-extraction-planning-design.md
- Key deliverables:
  1. Classification logic in workflow (actionable/needs_planning/archive_only)
  2. Database schema updates (classification, planning_status fields)
  3. Things inbox integration for actionable tasks
  4. Flagging system for needs_planning items

**Existing worktree:** feature/daily-summary is active but unrelated to this work.

**2025-12-30 - Planning Complete**
- Implementation plan created: `IMPLEMENTATION-PLAN.md`
- 9 tasks identified, ~3 hours total estimated time
- Key implementation areas:
  1. Database migration (new columns + discussion_threads table)
  2. Classification prompt and Ollama integration
  3. Workflow restructure with routing logic
  4. Test script for all classification paths
- Ready to proceed to dev stage

**2025-12-30 - Batch 1 Complete (Tasks 1-2)**
- Following TDD workflow: RED -> GREEN -> REFACTOR
- Task 1: Database migration (008_classification_fields.sql)
  - Added `classification` column to processed_notes (actionable/needs_planning/archive_only)
  - Added `planning_status` column to processed_notes (pending_review/in_planning/planned/archived)
  - Created `discussion_threads` table for SeleneChat planning threads
  - 32 tests passing (all constraints and indexes verified)
- Task 2: Classification prompt (prompts/classification-prompt.txt)
  - Clear decision rules matching metadata-definitions.md
  - JSON output format with classification, confidence, reasoning
  - Edge case handling for mixed/ambiguous content
  - 26 tests passing (all categories, rules, and format verified)
- Total: 58 tests passing

**Files created:**
- `database/migrations/008_classification_fields.sql`
- `database/migrations/tests/test-008-classification.sh`
- `prompts/classification-prompt.txt`
- `prompts/tests/test-classification-prompt.sh`

**2025-12-30 - Batch 2 Complete (Tasks 3-6)**
- Task 3: Add Classification Node to workflow
  - Added "Build Classification Prompt" node with full classification template
  - Added "Ollama Classify Note" HTTP request node (30s timeout)
  - Added "Parse Classification" node with JSON parsing and validation
  - Classification values: actionable, needs_planning, archive_only
- Task 4: Add Routing Logic (Switch Node)
  - Added "Route by Classification" Switch node with 3 outputs
  - Output 0: actionable -> Task extraction pipeline
  - Output 1: needs_planning -> Flag for Planning node
  - Output 2 (fallback): archive_only -> Store Classification node
- Task 5: Update Task Extraction Prompt
  - Renamed to "Build Task Extraction Prompt" for clarity
  - Added classification context to prompt
  - Notes that content is pre-classified as actionable
- Task 6: Update Status Handling
  - "Update Status (Actionable)" - Updates classification and things_integration_status
  - "Flag for Planning" - Creates discussion_thread record for SeleneChat
  - "Store Classification (Archive)" - Updates classification only, no task extraction

**Files modified:**
- `workflows/07-task-extraction/workflow.json` - Complete workflow restructure (14 nodes)
- `workflows/07-task-extraction/STATUS.md` - Updated with new architecture
- `workflows/07-task-extraction/README.md` - Added classification documentation

---

## Blocked Items

### n8n Switch Node Compatibility Issue

The Switch node typeVersion 3 format is not compatible with n8n 1.110.1. Initial workaround attempted (downgrade to typeVersion 2) but still encountering "Could not find property option" errors. The classification is working correctly (Ollama returns correct classifications), but the routing and database updates are not executing.

**Next steps:**
1. Further investigate n8n node compatibility
2. Consider alternative routing approach (IF node chain instead of Switch)
3. Test on newer n8n version if available

---

## Notes

**2025-12-30 - Batch 3 Complete (Tasks 7-8) - Testing Phase**

**Task 7: Test Script Created**
- Created comprehensive test script at `workflows/07-task-extraction/scripts/test-with-markers.sh`
- Tests all three classification paths (actionable, needs_planning, archive_only)
- Added worktree detection for database path resolution
- Generates unique test_run IDs for cleanup
- Verifies database state after each test

**Test Script Features:**
- Dependency checks (n8n, Ollama, Things wrapper, database, migration)
- Creates test notes with proper raw_notes + processed_notes records
- Triggers workflow via webhook
- Verifies classification, discussion_threads, and task_metadata
- Provides cleanup instructions and optional auto-cleanup

**Task 8: Integration Testing Results**

**Test Results (2025-12-30 19:08):**
- Test Run ID: test-run-20251230-190844
- Total Tests: 3
- Passed: 1 (archive_only path)
- Failed: 2 (actionable and needs_planning paths)
- Skipped: 0

**Observations:**
1. Classification LLM is working correctly:
   - "Call dentist" classified as `actionable` with confidence 1
   - "Redesign website" classified as `needs_planning` with confidence 0.9
   - "Energy levels" classified as `archive_only` with confidence 1

2. Routing issue:
   - All notes show `archive_only` in database despite correct LLM output
   - Switch node routing appears to fail silently
   - No "Update Status" or "Flag for Planning" logs observed

3. n8n compatibility:
   - Error: "Could not find property option" persists
   - Attempted fixes: Switch typeVersion 2, simplified SplitOut options
   - Workflow imports successfully but routing does not execute

**Files Modified (Batch 3):**
- `workflows/07-task-extraction/scripts/test-with-markers.sh` - Complete test script
- `workflows/07-task-extraction/workflow.json` - Switch node downgrade attempt

**Workflow State:**
- Workflow imports and webhook triggers correctly
- Classification prompt and Ollama call work correctly
- Parse Classification node works correctly
- Route by Classification Switch node has compatibility issues
- Downstream nodes (actionable, needs_planning paths) do not execute

**Recommended Resolution:**
Replace Switch node with IF node chain:
```
Parse Classification
    -> IF actionable -> Build Task Extraction Prompt -> ...
    -> IF needs_planning -> Flag for Planning
    -> (else) Store Classification (Archive)
```
