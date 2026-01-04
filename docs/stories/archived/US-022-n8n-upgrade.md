# US-022: n8n 2.x Upgrade

**Status:** draft
**Priority:** 🟡 high
**Effort:** L
**Created:** 2026-01-04
**Updated:** 2026-01-04

---

## User Story

As a **Selene developer maintaining infrastructure**,
I want **n8n upgraded from 1.110.1 to 2.x**,
So that **we benefit from security hardening, performance, and new features**.

---

## Context

n8n 2.x brings significant improvements: task runners for isolated execution, 10x SQLite performance, MCP nodes for SeleneChat integration. Being 13+ versions behind accumulates technical debt and risks compatibility issues with future workflows. Upgrade now while codebase is manageable.

---

## Acceptance Criteria

- [ ] All existing workflows pass tests after upgrade
- [ ] `manage-workflow.sh` updated for new CLI commands
- [ ] Environment variables configured for executeCommand
- [ ] File access restrictions configured for Selene paths
- [ ] Rollback plan documented and tested
- [ ] Zero downtime during migration

---

## ADHD Design Check

- [ ] **Reduces friction?** N/A (infrastructure)
- [ ] **Visible?** N/A (infrastructure)
- [ ] **Externalizes cognition?** N/A (infrastructure)

---

## Technical Notes

- Dependencies: None (infrastructure)
- Affected components: Dockerfile, docker-compose.yml, manage-workflow.sh
- Key breaking changes: executeCommand disabled, update:workflow → publish:workflow
- Risk: Community package compatibility (n8n-nodes-sqlite)
- Design doc: docs/plans/2026-01-01-n8n-upgrade-design.md

---

## Links

- **Branch:** (added when active)
- **PR:** (added when complete)
- **Design doc:** docs/plans/2026-01-01-n8n-upgrade-design.md
