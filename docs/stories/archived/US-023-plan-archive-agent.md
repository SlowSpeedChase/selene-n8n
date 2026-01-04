# US-023: Plan Archive Agent

**Status:** draft
**Priority:** 🟢 normal
**Effort:** M
**Created:** 2026-01-04
**Updated:** 2026-01-04

---

## User Story

As a **Selene developer managing documentation**,
I want **stale design docs automatically archived**,
So that **docs/plans stays focused on active work and context isn't polluted**.

---

## Context

Design docs accumulate over time. Completed or superseded docs clutter the plans directory, making it hard to find active designs. Automatic archival based on INDEX.md status keeps documentation fresh without manual cleanup sessions.

---

## Acceptance Criteria

- [ ] Docs marked Completed/Superseded in INDEX.md auto-move to _archived/
- [ ] Uncategorized docs older than 14 days flagged for review
- [ ] INDEX.md updated with Archived section
- [ ] References in CLAUDE.md cleaned up
- [ ] `<!-- KEEP: reason -->` comment prevents archival
- [ ] Runs via post-commit hook or on-demand

---

## ADHD Design Check

- [ ] **Reduces friction?** N/A (infrastructure)
- [ ] **Visible?** N/A (infrastructure)
- [ ] **Externalizes cognition?** System handles cleanup, not user

---

## Technical Notes

- Dependencies: None
- Affected components: scripts/archive-stale-plans.sh, post-commit hook
- Parses INDEX.md for status markers
- Safe: dry-run mode available
- Design doc: docs/plans/2026-01-02-plan-archive-agent-design.md

---

## Links

- **Branch:** (added when active)
- **PR:** (added when complete)
- **Design doc:** docs/plans/2026-01-02-plan-archive-agent-design.md
