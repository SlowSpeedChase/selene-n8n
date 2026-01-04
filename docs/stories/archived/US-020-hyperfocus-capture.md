# US-020: Hyperfocus Capture Mode

**Status:** draft
**Priority:** 🟢 normal
**Effort:** M
**Created:** 2026-01-04
**Updated:** 2026-01-04

---

## User Story

As an **ADHD user in hyperfocus**,
I want **quick task capture without leaving current app**,
So that **I don't break flow but still capture ideas**.

---

## Context

Hyperfocus is precious - breaking it to "properly" capture a task means losing the state entirely. Quick capture from anywhere (global hotkey, share sheet, voice) lets ideas flow into the system without context switching. Capture first, process later.

---

## Acceptance Criteria

- [ ] Global hotkey triggers minimal capture window
- [ ] Voice input option for hands-free capture
- [ ] Capture window closes immediately after submit
- [ ] Captured items go to dedicated "hyperfocus dump" queue
- [ ] Processing happens later (async, invisible)

---

## ADHD Design Check

- [x] **Reduces friction?** 2-second capture, not 2-minute app switch
- [x] **Visible?** Captured items surface in normal review flow
- [x] **Externalizes cognition?** Dump and forget, system handles it

---

## Technical Notes

- Dependencies: US-001 (Auto-Extract Tasks)
- Affected components: macOS global hotkey, SeleneChat menu bar item
- Global hotkey registration (Cmd+Shift+S or similar)
- Minimal floating window: text field + submit
- Voice option using macOS dictation
- Items tagged with hyperfocus_capture = true for later processing
- Share sheet extension for iOS/macOS cross-app capture

---

## Links

- **Branch:** (added when active)
- **PR:** (added when complete)
- **Source:** docs/user-stories/things-integration-stories.md (Story F.5)
