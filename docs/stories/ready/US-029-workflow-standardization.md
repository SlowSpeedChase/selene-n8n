# US-029: Workflow Standardization

**Status:** draft
**Priority:** 🟡 high
**Effort:** L
**Created:** 2026-01-04
**Updated:** 2026-01-04

---

## User Story

As a **Selene developer maintaining workflows**,
I want **all workflows brought to production standard**,
So that **testing, debugging, and maintenance are consistent across the codebase**.

---

## Context

Workflow 01 (Ingestion) has proper test scripts, STATUS.md, and error handling. Workflows 02-06 are inconsistent - some lack tests, documentation varies, error handling is spotty. Standardizing reduces cognitive load when switching between workflows.

---

## Acceptance Criteria

- [ ] Each workflow has test-with-markers.sh script
- [ ] Each workflow has STATUS.md with test results
- [ ] Error handling pattern consistent across workflows
- [ ] README.md exists with quick-start and troubleshooting
- [ ] All workflows pass full test suite

---

## ADHD Design Check

- [x] **Reduces friction?** Same patterns everywhere = less context switching
- [ ] **Visible?** N/A (infrastructure)
- [x] **Externalizes cognition?** Consistent structure = less to remember

---

## Technical Notes

- Dependencies: None
- Affected components: workflows/02-06/
- Use workflow 01 as template
- Design doc: docs/plans/2025-12-31-workflow-standardization-design.md

---

## Links

- **Branch:** (added when active)
- **PR:** (added when complete)
- **Design doc:** docs/plans/2025-12-31-workflow-standardization-design.md
