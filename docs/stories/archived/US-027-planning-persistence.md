# US-027: Planning Conversation Persistence

**Status:** draft
**Priority:** 🔥 critical
**Effort:** L
**Created:** 2026-01-04
**Updated:** 2026-01-04

---

## User Story

As an **ADHD user who plans in multiple sessions**,
I want **SeleneChat to remember our planning conversations**,
So that **I can resume discussions without re-explaining context**.

---

## Context

Planning complex projects happens over days or weeks. Without persistence, each session starts fresh - losing context, decisions, and progress. Storing conversation history lets the AI resume intelligently: "Last time we discussed X and created tasks Y, Z. What's next?"

---

## Acceptance Criteria

- [ ] Last 15 messages per thread stored in database
- [ ] Resuming thread loads context automatically
- [ ] AI shows tasks created from this thread
- [ ] Task status (from Things) reflected in conversation
- [ ] Can refine existing tasks from the thread

---

## ADHD Design Check

- [x] **Reduces friction?** No re-explaining, just continue
- [x] **Visible?** See what was discussed and decided
- [x] **Externalizes cognition?** System remembers context for you

---

## Technical Notes

- Dependencies: US-012 (Completion Tracking), Planning tab infrastructure
- Affected components: planning_messages table, ChatViewModel, AI prompts
- Store messages in planning_messages table
- Load last 15 on thread resume
- Build AI context with tasks + statuses + recent messages
- Design doc: docs/plans/2026-01-02-planning-persistence-refinement-design.md

---

## Links

- **Branch:** (added when active)
- **PR:** (added when complete)
- **Design doc:** docs/plans/2026-01-02-planning-persistence-refinement-design.md
