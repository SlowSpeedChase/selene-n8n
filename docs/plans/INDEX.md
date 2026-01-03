# Design Documents Index

**Last Updated:** 2026-01-03

Status legend:
- **Active** - Ready for implementation or in progress
- **Completed** - Implemented and merged
- **Superseded** - Replaced by newer design

---

## Active (Ready for Implementation)

| Date | Document | Phase | Notes |
|------|----------|-------|-------|
| 2026-01-03 | planning-tab-redesign.md | 7.2 | Projects contain threads, Active first, no standalone conversations |
| 2026-01-02 | bidirectional-things-flow-design.md | 7.2e | Things status sync + resurface triggers |
| 2026-01-01 | project-grouping-design.md | 7.2f | Things project grouping |
| 2026-01-01 | n8n-upgrade-design.md | infra | n8n 1.x to 2.x upgrade |
| 2026-01-02 | plan-archive-agent-design.md | infra | Auto-archive stale design docs |
| 2026-01-02 | selenechat-auto-builder-design.md | infra | Post-merge hook for auto builds |
| 2026-01-02 | feedback-pipeline-design.md | infra | AI classification of #selene-feedback → backlog |
| 2026-01-02 | selenechat-uat-system-design.md | infra | Interactive UAT for SeleneChat views |
| 2026-01-02 | planning-persistence-refinement-design.md | 7.2g | Conversation persistence + task refinement |

---

## In Progress

| Date | Document | Notes |
|------|----------|-------|
| 2026-01-02 | feedback-pipeline-implementation.md | Implementation plan for feedback classification |
| 2026-01-02 | bidirectional-things-implementation.md | Implementation plan for 7.2e |
| 2026-01-01 | project-grouping-7.2f.1-implementation.md | Implementation plan for 7.2f |
| 2026-01-02 | subproject-suggestions-implementation.md | Implementation plan for 7.2f sub-project suggestions |

---

## Completed (Implemented)

| Date | Document | Completion |
|------|----------|------------|
| 2025-12-31 | ai-provider-toggle-design.md | 2025-12-31 (Phase 7.2d) |
| 2025-12-30 | task-extraction-planning-design.md | 2025-12-30 |
| 2025-12-30 | daily-summary-design.md | 2025-12-31 |
| 2025-12-31 | phase-7.2-selenechat-planning-design.md | Design complete |
| 2025-12-31 | workflow-lifecycle-management-design.md | Implemented |
| 2025-12-31 | feedback-pipeline-implementation.md | Merged |
| 2026-01-01 | selenechat-debug-system-design.md | Merged |
| 2025-11-14 | ollama-integration-design.md | Implemented |
| 2025-11-14 | selenechat-database-integration-design.md | Implemented |
| 2025-11-15 | selenechat-clickable-citations-design.md | Implemented |
| 2025-11-27 | modular-context-structure.md | Implemented |
| 2025-11-30 | dev-environment-design.md | Implemented |

---

## Superseded (Replaced)

| Date | Document | Superseded By |
|------|----------|---------------|
| 2025-11-25 | phase-7-1-gatekeeping-design.md | task-extraction-planning-design.md |
| 2025-11-14 | selenechat-db-integration.md | selenechat-database-integration-design.md |
| 2025-11-15 | selenechat-data-integration-design.md | selenechat-database-integration-design.md |

---

## Uncategorized

These documents need status review:

| Date | Document |
|------|----------|
| 2025-11-15 | selenechat-icon-design.md |
| 2025-11-30 | stop-and-research-skill-design.md |
| 2025-12-30 | trmnl-integration-design.md |
| 2025-12-31 | selenechat-vision-and-feedback-loop-design.md |
| 2025-12-31 | workflow-procedures-design.md |
| 2025-12-31 | workflow-standardization-design.md |
| auto-create-tasks-from-notes.md | (no date - legacy) |

---

## Maintenance

When creating a new design doc:
1. Use format: `YYYY-MM-DD-topic-type.md` (type: design, implementation, analysis)
2. Add entry to this INDEX.md in appropriate section
3. Update status when work begins/completes
