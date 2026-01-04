# US-035: Sub-Project Suggestions

**Status:** draft
**Priority:** normal
**Effort:** M
**Phase:** 7.2f.6
**Created:** 2026-01-04
**Updated:** 2026-01-04

---

## User Story

As an **ADHD user with a growing project**,
I want **the system to suggest spinning off sub-projects when appropriate**,
So that **my projects stay focused and manageable**.

---

## Context

Projects grow organically. A "Website Redesign" project might accumulate 15 frontend tasks, 8 backend tasks, and 5 content tasks. When a heading gets 5+ tasks with a distinct sub-concept, that's often a project of its own. Suggesting the split keeps projects from becoming overwhelming.

---

## Acceptance Criteria

- [ ] After heading accumulates 5+ tasks with distinct sub-concept
- [ ] Surface suggestion in SeleneChat: "Spin off 'Frontend Work' as its own project?"
- [ ] User approves: create new project, move tasks
- [ ] User declines: don't suggest again for this heading
- [ ] Suppression persisted (won't keep nagging)

---

## ADHD Design Check

- [x] **Reduces friction?** User just approves/declines
- [x] **Visible?** Suggestion surfaces proactively
- [x] **Externalizes cognition?** System detects growth patterns

---

## Technical Notes

- Dependencies: Phase 7.2f.3 (Headings Within Projects)
- Affected components: SeleneChat UI, suggestion tracking table
- Scripts: `surface_suggestion(heading_id)` function
- Design doc: [Project Grouping Design](../../plans/2026-01-01-project-grouping-design.md) (Phase 7.2f section)

**AI output structure from design doc:**
```javascript
{
  "action": "suggest_subproject",
  "data": {
    "source_heading": "Frontend Work",
    "suggested_name": "React Component Library",
    "task_ids": ["aaa", "bbb", "ccc", "ddd", "eee"]
  }
}
```

---

## Links

- **Branch:** (added when active)
- **PR:** (added when complete)
- **Parent Epic:** US-021 (Automatic Project Grouping)
- **Design doc:** docs/plans/2026-01-01-project-grouping-design.md
