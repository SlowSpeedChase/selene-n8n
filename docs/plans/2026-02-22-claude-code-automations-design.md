# Claude Code Automations Design

**Date:** 2026-02-22
**Status:** Ready
**Topic:** dev-experience, tooling

## Summary

Add MCP servers, Claude Code hooks, and custom skills to the Selene project to improve development velocity and safety.

## Motivation

The project has strong git hooks and skills but lacks:
- **Live documentation** for dependencies (Fastify, LanceDB, SQLite.swift)
- **Edit-time feedback** for TypeScript type errors (currently only caught at runtime)
- **Hard gates** preventing accidental edits to `.env` or production database
- **Streamlined commands** for the two most common dev tasks (running workflows, checking launchd agents)

## Components

### 1. MCP Servers

#### context7

Live documentation lookup for npm/Swift packages. Fetches current API docs for Fastify, LanceDB, better-sqlite3, SQLite.swift, pino, etc.

- Scope: Project (`.mcp.json`)
- Install: `claude mcp add context7 --scope project -- npx -y @upstash/context7-mcp@latest`

#### sqlite-dev

Direct database queries against the dev database with persistent schema awareness.

- Scope: Project (`.mcp.json`)
- Database: `~/selene-data-dev/selene-dev.db` (dev only, no production access)
- Install: `claude mcp add sqlite-dev --scope project -- npx -y @anthropic/mcp-sqlite --db-path ~/selene-data-dev/selene-dev.db`

### 2. Claude Code Hooks

Location: `.claude/settings.json` (shared, checked into git)

#### TypeScript Type-Check (PostToolUse)

- Trigger: After any `Edit` or `Write` on a `.ts` file
- Action: Run `npx tsc --noEmit --pretty`, show first 20 lines of output
- Behavior: Non-blocking feedback — Claude sees errors and self-corrects

#### Block Sensitive File Edits (PreToolUse)

- Trigger: Before any `Edit` or `Write` on `.env*` or `selene.db`
- Action: Exit code 2 (blocks the tool call)
- Behavior: Hard gate — the edit is completely prevented

### 3. Custom Skills

#### run-workflow

- Location: `.claude/skills/run-workflow/SKILL.md`
- Invocation: User-only (`/run-workflow <name>`)
- Behavior:
  1. Accept workflow name argument (e.g., `process-llm`)
  2. Generate unique `test_run` marker
  3. Run `npx ts-node src/workflows/<name>.ts` with TEST_RUN env var
  4. Tail `logs/selene.log` with pino-pretty
  5. Report success/failure, remind about cleanup

#### launchd-check

- Location: `.claude/skills/launchd-check/SKILL.md`
- Invocation: User-only (`/launchd-check [agent-name]`)
- Behavior:
  1. No argument: check all `com.selene.*` agents
  2. With argument: check specific agent
  3. Report: status, last exit code, recent log output
  4. Flag non-zero exit codes or "not loaded" agents

## Acceptance Criteria

- [ ] context7 MCP server responds to documentation queries
- [ ] sqlite-dev MCP server connects to dev database and runs queries
- [ ] TypeScript type-check hook runs after `.ts` file edits and reports errors
- [ ] Sensitive file edit hook blocks edits to `.env` and `selene.db`
- [ ] `/run-workflow process-llm` executes the workflow with test markers
- [ ] `/launchd-check` reports status of all Selene launchd agents
- [ ] All configuration checked into git and works in worktrees

## ADHD Check

- **Reduces friction?** Yes — fewer manual commands, automatic type feedback
- **Makes things visible?** Yes — errors surfaced immediately, agent status at a glance
- **Externalizes cognition?** Yes — safety rules enforced by hooks, not memory

## Scope Check

Estimated: < 1 day. All components are configuration + short skill files, no application code changes.

## Implementation Approach

All-in-one: implement all components in a single pass (MCP servers first, then hooks, then skills), with verification after each component.
