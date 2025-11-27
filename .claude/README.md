# Claude Code Context Guide

**Purpose:** Navigation map for AI agents working on Selene. Read this first to understand which context files to load for your task.

---

## Context Loading Strategy

**Claude Code automatically loads:**
- Root `CLAUDE.md` (always)
- Files in `.claude/` directory (project-wide)
- `CLAUDE.md` files in subdirectories (when working in that area)

**You should explicitly read:**
- Context files relevant to your specific task
- Referenced files using @filename syntax

---

## Quick Reference: What to Read for Common Tasks

### Modifying n8n Workflows
**Primary:** `@workflows/CLAUDE.md`
**Supporting:** `@.claude/OPERATIONS.md`, `@scripts/CLAUDE.md`
**Commands:** Use `./scripts/manage-workflow.sh`

### Understanding System Architecture
**Primary:** `@.claude/DEVELOPMENT.md`
**Supporting:** `@CLAUDE.md`, `@ROADMAP.md`

### Testing Workflows
**Primary:** `@workflows/CLAUDE.md` (Testing section)
**Supporting:** `@scripts/CLAUDE.md` (test-with-markers.sh)

### Database Operations
**Primary:** `@.claude/DEVELOPMENT.md` (Database section)
**Supporting:** `@database/schema.sql`

### ADHD Feature Design
**Primary:** `@.claude/ADHD_Principles.md`
**Supporting:** `@.claude/DEVELOPMENT.md` (Design Decisions)

### Daily Operations (Testing, Debugging, Commits)
**Primary:** `@.claude/OPERATIONS.md`
**Supporting:** `@scripts/CLAUDE.md`

### Project Status Check
**Primary:** `@.claude/PROJECT-STATUS.md`
**Supporting:** `@ROADMAP.md`

---

## Context File Descriptions

### Root Level

#### `CLAUDE.md` (Project Overview)
**Load for:** Initial orientation, system overview
**Contains:**
- Project purpose and goals
- High-level architecture diagram
- Key components list
- Critical "Do NOT" rules
- Quick reference to detailed context files

#### `ROADMAP.md` (Project Planning)
**Load for:** Understanding project phases, what's next
**Contains:**
- Phase-by-phase implementation plan
- Current status and completed work
- Links to detailed phase documents in `docs/roadmap/`

---

### `.claude/` (Project-Wide Principles)

#### `.claude/ADHD_Principles.md`
**Load for:** Designing ADHD-friendly features
**Contains:**
- Neurological characteristics of ADHD
- 3-step framework (Capture, Organize, Plan)
- Design principles (Visual Over Mental, Reduce Friction)
- Emotional regulation integration
- Success metrics for ADHD systems

#### `.claude/DEVELOPMENT.md`
**Load for:** Making architectural decisions
**Contains:**
- System architecture deep dive
- Database schema and patterns
- Technology choices and rationale
- Development patterns (testing, error handling)
- Performance considerations
- Integration points (Ollama, Obsidian, Drafts)

#### `.claude/OPERATIONS.md`
**Load for:** Daily development tasks
**Contains:**
- Common commands (Docker, testing, database)
- Testing procedures and patterns
- Debugging workflows
- Git commit conventions
- CI/CD patterns
- Troubleshooting quick reference

#### `.claude/PROJECT-STATUS.md`
**Load for:** Understanding current state
**Contains:**
- Completed workflows and features
- In-progress work
- Known issues
- Recent achievements
- Next session priorities

---

### `workflows/` (Workflow Development)

#### `workflows/CLAUDE.md`
**Load for:** Working with n8n workflows
**Contains:**
- Workflow modification procedures (CLI-only)
- Node naming conventions
- Error handling patterns
- JSON structure patterns
- Testing requirements
- Documentation requirements (STATUS.md updates)
- Integration testing patterns

#### `workflows/XX-name/README.md`
**Load for:** Understanding specific workflow
**Contains:**
- Workflow-specific quick start
- What the workflow does
- Configuration requirements
- Testing instructions

#### `workflows/XX-name/docs/STATUS.md`
**Load for:** Current test results for specific workflow
**Contains:**
- Test pass/fail status
- Known issues
- Recent changes
- Performance metrics

---

### `scripts/` (Utility Operations)

#### `scripts/CLAUDE.md`
**Load for:** Using or modifying utility scripts
**Contains:**
- Script purposes and usage
- Common patterns (test markers, cleanup)
- Integration with workflows
- Error handling examples

---

### `database/` (Data Schema)

#### `database/schema.sql`
**Load for:** Understanding data structures
**Contains:**
- Table definitions
- Column types and constraints
- Indexes and relationships
- Migration patterns

---

### `docs/` (Comprehensive Documentation)

#### `docs/README.md`
**Load for:** User-facing documentation
**Contains:**
- Setup guides
- API documentation
- Troubleshooting
- Integration guides

#### `docs/roadmap/` (Phase Documents)
**Load for:** Detailed phase implementation
**Contains:**
- Phase-specific technical details
- Implementation specifications
- Testing procedures
- Migration guides

---

## Loading Patterns for AI Agents

### Pattern 1: New to Project
```
Read:
1. @CLAUDE.md (overview)
2. @.claude/README.md (this file)
3. @.claude/PROJECT-STATUS.md (current state)
4. Task-specific context (see Quick Reference above)
```

### Pattern 2: Continuing Existing Work
```
Read:
1. @.claude/PROJECT-STATUS.md (what's in progress)
2. Task-specific context files
3. Relevant workflow/script CLAUDE.md files
```

### Pattern 3: Making Architectural Decisions
```
Read:
1. @.claude/DEVELOPMENT.md (patterns and decisions)
2. @.claude/ADHD_Principles.md (if user-facing)
3. @ROADMAP.md (future plans)
4. Relevant implementation files
```

### Pattern 4: Bug Fixing
```
Read:
1. @.claude/OPERATIONS.md (debugging procedures)
2. @workflows/CLAUDE.md (if workflow issue)
3. @scripts/CLAUDE.md (if script issue)
4. Relevant STATUS.md files
```

---

## Context File Maintenance Rules

### When to Update Each File

**`CLAUDE.md` (Root):**
- New major components added
- Architecture changes
- Critical "Do NOT" rules added

**`.claude/DEVELOPMENT.md`:**
- New architectural patterns established
- Technology choices made
- Database schema changes
- Integration points added

**`.claude/OPERATIONS.md`:**
- New common commands added
- Testing procedures change
- New debugging patterns discovered

**`.claude/PROJECT-STATUS.md`:**
- After completing any task/workflow
- Daily during active development
- When starting new work

**`workflows/CLAUDE.md`:**
- Workflow modification patterns change
- New testing requirements
- New documentation standards

**`workflows/XX-name/docs/STATUS.md`:**
- After every test run
- When bugs are discovered/fixed
- When workflow is modified

---

## Principles for Context Organization

1. **Single Responsibility:** Each file serves one specific AI task
2. **DRY:** Information lives in one canonical location
3. **Clear References:** Use @filename syntax to point to related context
4. **Minimal Loading:** Agent reads only what's needed for current task
5. **Progressive Disclosure:** Overview → Specific → Details
6. **Always Current:** Update context immediately when reality changes

---

## Questions?

If unsure which context to load, start with this file's Quick Reference section at the top.
