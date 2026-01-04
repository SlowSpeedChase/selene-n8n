# US-030: Development Process Gap Fixes

**Status:** draft
**Priority:** 🟡 high
**Effort:** M
**Created:** 2026-01-04
**Updated:** 2026-01-04

---

## User Story

As a **Selene developer following GitOps workflow**,
I want **process gaps fixed (closure ritual, doc drift, pre-commit)**,
So that **development workflow is complete and reliable**.

---

## Context

Current development workflow has gaps: closure ritual after merge isn't enforced, documentation drifts from code, pre-commit hooks could catch more issues. Fixing these gaps makes the GitOps workflow complete and self-enforcing.

---

## Acceptance Criteria

- [ ] Closure ritual checklist exists and is enforced
- [ ] Doc drift detection warns when code changes without doc updates
- [ ] Pre-commit hook validates workflow JSON
- [ ] Branch cleanup happens automatically after merge
- [ ] STATUS file updates detected in commit

---

## ADHD Design Check

- [x] **Reduces friction?** System catches what you'd forget
- [x] **Visible?** Warnings show when things are missed
- [x] **Externalizes cognition?** Process enforced by tooling

---

## Technical Notes

- Dependencies: None
- Affected components: .git/hooks/, scripts/
- Three areas: closure ritual, doc drift, pre-commit enhancements
- Design doc: docs/plans/2026-01-03-process-gap-fixes-design.md

---

## Links

- **Branch:** (added when active)
- **PR:** (added when complete)
- **Design doc:** docs/plans/2026-01-03-process-gap-fixes-design.md
