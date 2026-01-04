# US-024: SeleneChat Auto-Builder

**Status:** draft
**Priority:** 🟢 normal
**Effort:** S
**Created:** 2026-01-04
**Updated:** 2026-01-04

---

## User Story

As a **Selene developer working on SeleneChat**,
I want **the app automatically rebuilt after merging branches**,
So that **the installed app always reflects the latest code**.

---

## Context

Currently after merging a branch with SeleneChat changes, the installed app is stale until manually rebuilt. Auto-building on merge ensures the app you're testing matches the code you just merged. Reduces "why isn't this working?" debugging.

---

## Acceptance Criteria

- [ ] Post-merge hook detects SeleneChat/ changes
- [ ] Triggers `swift build -c release` automatically
- [ ] Installs built app to /Applications
- [ ] Sends notification when build completes
- [ ] Build failures logged clearly with notification

---

## ADHD Design Check

- [x] **Reduces friction?** No manual build step to remember
- [ ] **Visible?** N/A (infrastructure)
- [x] **Externalizes cognition?** System handles build, not user

---

## Technical Notes

- Dependencies: None
- Affected components: .git/hooks/post-merge, build-app.sh
- Only triggers when SeleneChat/ files changed
- Uses existing build infrastructure
- Design doc: docs/plans/2026-01-02-selenechat-auto-builder-design.md

---

## Links

- **Branch:** (added when active)
- **PR:** (added when complete)
- **Design doc:** docs/plans/2026-01-02-selenechat-auto-builder-design.md
