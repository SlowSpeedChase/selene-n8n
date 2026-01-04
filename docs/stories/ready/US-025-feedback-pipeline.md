# US-025: Feedback Pipeline

**Status:** ready
**Priority:** 🟡 high
**Effort:** M
**Created:** 2026-01-04
**Updated:** 2026-01-04

---

## User Story

As a **Selene user capturing development feedback**,
I want **my #selene-feedback notes automatically classified and added to the backlog**,
So that **ideas don't get lost and become actionable without manual processing**.

---

## Context

Development feedback captured via Drafts (#selene-feedback) stores to the database but sits unused. Auto-classification turns raw feedback into structured backlog items (user stories, bugs, improvements). The capture-to-action loop closes automatically.

---

## Acceptance Criteria

- [ ] Feedback notes classified: user_story | feature_request | bug | improvement | noise
- [ ] Classified items appended to docs/backlog/user-stories.md
- [ ] Duplicate detection prevents repeat entries
- [ ] Noise items logged but not added to backlog
- [ ] Original note linked from backlog item
- [ ] Processing happens in existing Workflow 01

---

## ADHD Design Check

- [x] **Reduces friction?** Capture feedback same as notes, processing automatic
- [x] **Visible?** Backlog items visible in markdown file
- [x] **Externalizes cognition?** System processes feedback, not user

---

## Technical Notes

- Dependencies: Workflow 01 (Ingestion), Ollama
- Affected components: Workflow 01 extension, feedback_notes table
- Ollama classifies feedback type
- Appends structured markdown to backlog file
- Design doc: docs/plans/2026-01-02-feedback-pipeline-design.md

---

## Links

- **Branch:** (added when active)
- **PR:** (added when complete)
- **Design doc:** docs/plans/2026-01-02-feedback-pipeline-design.md
