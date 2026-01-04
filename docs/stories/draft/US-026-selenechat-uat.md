# US-026: SeleneChat UAT System

**Status:** draft
**Priority:** 🟢 normal
**Effort:** M
**Created:** 2026-01-04
**Updated:** 2026-01-04

---

## User Story

As a **Selene developer shipping SeleneChat features**,
I want **interactive UAT flows for each view**,
So that **I can systematically verify features work before merging**.

---

## Context

SeleneChat has multiple views (Library, Chat, Planning, Search) that need testing. Manual verification is inconsistent and easy to forget. Structured UAT with checkboxes ensures every feature is verified against acceptance criteria before release.

---

## Acceptance Criteria

- [ ] UAT checklist exists for each major view
- [ ] Checklists live in docs/uat/ or similar
- [ ] Can be invoked from SeleneChat or command line
- [ ] Results tracked (pass/fail with notes)
- [ ] Blocking issues prevent merge

---

## ADHD Design Check

- [x] **Reduces friction?** Pre-made checklist, no remembering what to test
- [x] **Visible?** Checklist shows what's tested vs. not
- [x] **Externalizes cognition?** System tracks test coverage

---

## Technical Notes

- Dependencies: None
- Affected components: docs/uat/, testing workflow
- Could integrate with branch status workflow
- Design doc: docs/plans/2026-01-02-selenechat-uat-system-design.md

---

## Links

- **Branch:** (added when active)
- **PR:** (added when complete)
- **Design doc:** docs/plans/2026-01-02-selenechat-uat-system-design.md
