# Design Documents Index

**Last Updated:** 2026-02-06

Design docs are the planning unit for Selene development. Each doc captures an idea, architecture, and implementation plan.

---

## Status Definitions

| Status | Meaning | Next Step |
|--------|---------|-----------|
| **Vision** | Idea captured, needs refinement | Add acceptance criteria, ADHD check, scope check |
| **Ready** | Implementation-ready | Create branch, start GitOps workflow |
| **In Progress** | Branch exists, being built | Complete GitOps stages |
| **Done** | Implemented and merged | Archive if old |

**A design is "Ready" when it has:**
- [ ] Acceptance criteria defined
- [ ] ADHD check passed (reduces friction? visible? externalizes cognition?)
- [ ] Scope check passed (< 1 week of focused work)
- [ ] No blockers

---

## Vision (Needs Refinement)

Ideas captured but not yet ready for implementation.

| Date | Document | Topic | Notes |
|------|----------|-------|-------|
| 2026-02-04 | 2026-02-04-conversation-memory-design.md | selenechat | Persistent conversation memory with mem0-inspired patterns |
| 2026-01-26 | selenechat-contextual-evolution.md | selenechat | Project-scoped chats, connected info, lab notes - needs breakdown |
| 2026-01-26 | today-view-design.md | selenechat | ADHD landing page - needs acceptance criteria |
| 2026-01-11 | selenechat-remote-access-design.md | selenechat | Run SeleneChat on laptop with desktop server |
| 2026-01-05 | weekly-review-react-flow-design.md | ux-core | "Present -> React -> File" paradigm |
| 2026-01-05 | selenechat-interface-inspiration-design.md | selenechat | Design patterns research - reference doc |
| 2026-01-05 | selenechat-redesign-design.md | selenechat | Forest Study design system |
| 2026-01-01 | n8n-upgrade-design.md | infra | Superseded by TypeScript replacement |

---

## Ready (Implementation-Ready)

These have acceptance criteria, ADHD check, and scope check. Ready to create a branch.

| Date | Document | Topic | Notes |
|------|----------|-------|-------|
| 2026-02-06 | 2026-02-06-memory-embedding-retrieval-design.md | selenechat | Embedding-based memory retrieval and consolidation |

---

## Deprioritized

Designs that are ready but not currently a priority. These are bundled together for future implementation.

| Date | Document | Topic | Notes |
|------|----------|-------|-------|
| 2026-01-26 | phase-7.3-cloud-ai-integration.md | cloud-ai | Privacy-preserving cloud AI with sanitization |
| 2026-01-26 | phase-7.3-implementation-plan.md | cloud-ai | 21 tasks, implementation ready |
| 2026-01-11 | things-checklist-integration-design.md | things | Checklist generation - benefits from Cloud AI |

**Bundle rationale:** Things checklist generation uses LLM for task breakdown. Local Ollama produces adequate results, but Cloud AI would significantly improve quality. Implement together when Cloud AI is prioritized.

---

## In Progress

Branch exists, actively being worked on.

| Date | Document | Branch | Notes |
|------|----------|--------|-------|
| - | - | - | No active branches |

---

## Done (Implemented)

| Date | Document | Completed | Notes |
|------|----------|-----------|-------|
| 2026-02-05 | 2026-02-05-voice-input-design.md | 2026-02-05 | Voice input Phase 1: Apple Speech, push-to-talk, URL scheme |
| 2026-02-05 | 2026-02-05-selene-thinking-partner-design.md | 2026-02-05 | Proactive briefing, cross-thread synthesis, deep-dive dialogue |
| 2026-02-02 | 2026-02-02-imessage-daily-digest-design.md | 2026-02-02 | iMessage daily digest at 6am via AppleScript |
| 2026-01-27 | 2026-01-27-selenechat-vector-search-design.md | 2026-01-27 | SeleneChat vector search integration |
| 2026-01-26 | 2026-01-26-lancedb-transition.md | 2026-01-27 | LanceDB vector DB, typed relationships |
| 2026-01-11 | selenechat-thread-queries-design.md | 2026-01-11 | Thread queries in SeleneChat |
| 2026-01-11 | obsidian-thread-export-design.md | 2026-01-11 | Thread export to Obsidian |
| 2026-01-10 | phase-3-living-system-design.md | 2026-01-11 | Thread reconsolidation |
| 2026-01-09 | n8n-replacement-design.md | 2026-01-10 | TypeScript backend |
| 2026-01-06 | test-isolation-design.md | 2026-01-06 | Test data isolation |
| 2026-01-05 | batch-embed-notes-design.md | 2026-01-05 | Batch embedding |
| 2026-01-05 | association-computation-design.md | 2026-01-06 | Note associations |
| 2026-01-04 | selene-thread-system-design.md | 2026-01-11 | Core thread system |
| 2026-01-04 | embedding-workflow-implementation.md | 2026-01-05 | Embedding workflow |

---

## Archived

Superseded, abandoned, or very old designs. Kept for reference.

<details>
<summary>View Archived (40+)</summary>

| Date | Document | Reason |
|------|----------|--------|
| 2026-01-04 | user-story-system-design.md | Replaced by simplified two-layer system |
| 2026-01-02 | plan-archive-agent-design.md | Deprioritized |
| 2026-01-02 | selenechat-auto-builder-design.md | Deprioritized |
| 2026-01-02 | feedback-pipeline-design.md | Deprioritized |
| 2026-01-02 | selenechat-uat-system-design.md | Deprioritized |
| 2026-01-03 | process-gap-fixes-design.md | Deprioritized |
| 2025-12-31 | ai-provider-toggle-design.md | Implemented |
| 2025-12-30 | task-extraction-planning-design.md | Implemented |
| 2025-12-30 | daily-summary-design.md | Implemented |
| 2025-12-31 | phase-7.2-selenechat-planning-design.md | Implemented |
| 2025-12-31 | workflow-lifecycle-management-design.md | Superseded |
| 2025-12-31 | workflow-standardization-design.md | Superseded by TS replacement |
| 2026-01-01 | selenechat-debug-system-design.md | Implemented |
| 2025-11-14 | ollama-integration-design.md | Implemented |
| 2025-11-14 | selenechat-database-integration-design.md | Implemented |
| 2025-11-15 | selenechat-clickable-citations-design.md | Implemented |
| 2025-11-27 | modular-context-structure.md | Implemented |
| 2025-11-30 | dev-environment-design.md | Implemented |
| 2025-11-25 | phase-7-1-gatekeeping-design.md | Superseded |
| 2026-01-02 | bidirectional-things-flow-design.md | Implemented |
| 2026-01-01 | project-grouping-design.md | Implemented |

</details>

---

## Workflow

### Creating a Design Doc

1. Use brainstorming skill to explore the idea
2. Write to `docs/plans/YYYY-MM-DD-topic-design.md`
3. Add entry to this INDEX in "Vision" section
4. Status: **Vision**

### Making It Ready

1. Add acceptance criteria (testable)
2. Complete ADHD check
3. Verify scope (< 1 week)
4. Move to "Ready" section
5. Status: **Ready**

### Starting Implementation

1. Create branch: `git worktree add -b feature-name .worktrees/feature-name main`
2. Copy BRANCH-STATUS.md template
3. Move doc to "In Progress" section
4. Follow GitOps stages (see `.claude/GITOPS.md`)
5. Status: **In Progress**

### Completing

1. Merge to main
2. Move doc to "Done" section
3. Complete closure ritual
4. Status: **Done**

---

## Related

- `templates/DESIGN-DOC-TEMPLATE.md` - Template for new designs
- `.claude/GITOPS.md` - Implementation workflow
- `.claude/PROJECT-STATUS.md` - Current project state
