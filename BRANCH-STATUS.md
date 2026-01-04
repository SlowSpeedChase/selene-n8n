# Branch Status: US-031/auto-assignment

**Story:** US-031 - Auto-Assignment for New Tasks
**Phase:** 7.2f.2
**Created:** 2026-01-04

---

## Current Stage: ready

- [x] planning
- [x] dev
- [x] testing
- [x] docs
- [ ] review
- [x] ready

---

## Implementation Checklist

- [x] Add "Find Matching Project" node to Workflow 07
- [x] Update "Prepare Things Task" to include project_id in JSON
- [x] Update "Store Task Metadata" to save things_project_id
- [x] Update `process-pending-tasks.sh` to call assign script
- [x] `assign-to-project.scpt` already exists
- [x] Test with existing project data
- [x] Update Workflow 07 STATUS.md

---

## Technical Approach

**Best-Overlap Matching:** Count concept overlaps between task and each project, assign to highest scorer.

**Workflow 07 modification point:** After "Store Task Metadata" node

**New nodes:**
1. Find Matching Project (SQL query)
2. Route by Project Match (IF node)
3. Assign to Project (osascript + DB update)

---

## Notes

- Concepts come from `processed_notes.concepts` via Fetch Note Data
- Projects have `primary_concept` + `related_concepts` in `project_metadata`
- No AI calls in hot path - pure SQL matching
