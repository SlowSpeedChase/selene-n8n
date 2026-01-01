# Selene-n8n Project Context

> **For Claude:** This is a high-level overview. For detailed context, see the Context Guide below and load specific files as needed.

---

## Purpose

ADHD-focused knowledge management system using n8n workflows, SQLite, and local LLM processing for note capture, organization, and retrieval. Designed to externalize working memory and make information visual and accessible.

---

## Tech Stack

- **n8n** - Workflow automation engine (Docker-based)
- **SQLite** + better-sqlite3 - Database for note storage
- **Ollama** + mistral:7b - Local LLM for concept extraction
- **Swift** + SwiftUI - SeleneChat macOS app
- **Docker** - Container orchestration
- **Drafts** - iOS/Mac note capture app

---

## Context Navigation

**New to this project? Start here:** `@.claude/README.md`

**Quick reference for common tasks:**

| Task | Primary Context | Supporting Context |
|------|-----------------|-------------------|
| **Modify workflows** | `@workflows/CLAUDE.md` | `@.claude/OPERATIONS.md` |
| **Understand architecture** | `@.claude/DEVELOPMENT.md` | `@ROADMAP.md` |
| **Run tests** | `@.claude/OPERATIONS.md` | `@workflows/CLAUDE.md` |
| **Design ADHD features** | `@.claude/ADHD_Principles.md` | `@.claude/DEVELOPMENT.md` |
| **Daily operations** | `@.claude/OPERATIONS.md` | `@scripts/CLAUDE.md` |
| **Check status** | `@.claude/PROJECT-STATUS.md` | `@ROADMAP.md` |
| **Phase 7 / Task extraction** | `@docs/plans/2025-12-30-task-extraction-planning-design.md` | `@docs/architecture/metadata-definitions.md` |
| **Development workflow** | `@.claude/GITOPS.md` | `@templates/BRANCH-STATUS.md` |

---

## Development Workflow (MANDATORY)

**Claude MUST follow `@.claude/GITOPS.md` for all development work.**

Key requirements:
- All work in phase-named branches: `phase-X.Y/feature-name`
- Every branch has `BRANCH-STATUS.md` with stage checklists
- Use superpowers skills at each stage (TDD, verification, code review)
- Full closure ritual after merge (archive, update roadmap, cleanup)

**Stages:** planning → dev → testing → docs → review → ready

**Quick commands:**
```bash
# Start new work
git worktree add -b phase-X.Y/name .worktrees/name main

# Check active work
git worktree list
```

**See:** `@.claude/GITOPS.md` for complete workflow

---

## Architecture Overview

### Three-Tier System

```
┌─────────────────────────────────────────────────────────────┐
│ TIER 1: CAPTURE                                             │
│ Drafts App → Webhook → 01-Ingestion → SQLite               │
│ Design: One-click capture, zero friction                   │
└─────────────────────────────────────────────────────────────┘

┌─────────────────────────────────────────────────────────────┐
│ TIER 2: PROCESS                                             │
│ n8n Workflows → Ollama LLM → Extract patterns              │
│ Design: Automatic organization, visual patterns            │
└─────────────────────────────────────────────────────────────┘

┌─────────────────────────────────────────────────────────────┐
│ TIER 3: RETRIEVE                                            │
│ SeleneChat (macOS) + Obsidian → Query & Explore            │
│ Design: Information visible without mental overhead        │
└─────────────────────────────────────────────────────────────┘
```

**Why this architecture?** See `@.claude/DEVELOPMENT.md` (System Architecture section)

---

## ADHD Design Principles

1. **Externalize Working Memory** - Visual systems, not mental tracking
2. **Make Time Visible** - Structured vs. unstructured time
3. **Reduce Friction** - One-click capture, minimal steps
4. **Visual Over Mental** - "Out of sight, out of mind"
5. **Realistic Over Idealistic** - Under-schedule, not over-schedule

**Full framework:** `@.claude/ADHD_Principles.md`

---

## MANDATORY: Workflow Procedure Check

**BEFORE taking ANY action involving n8n workflows, you MUST:**

1. Read `@workflows/CLAUDE.md` (the full procedures section)
2. Identify which procedure applies (Create, Modify, or Delete)
3. Follow that procedure step-by-step without skipping

**Trigger conditions (if ANY apply, read procedures first):**
- User mentions: workflow, n8n, webhook, node, trigger
- User asks to: add, modify, fix, debug, delete, remove, create
- Files involved: `workflow.json`, `workflows/` directory
- Actions on: ingestion, processing, export, or any numbered workflow (01-, 02-, etc.)

**Examples that trigger this:**
- "Add a new node to the ingestion workflow" → Read procedures, use MODIFY
- "Create a workflow for daily summaries" → Read procedures, use CREATE
- "Remove the old sentiment workflow" → Read procedures, use DELETE
- "Fix the webhook in 02-llm-processing" → Read procedures, use MODIFY

**Claude: This is not optional. Skipping procedures causes git sync issues and broken workflows.**

---

## Critical Rules (Do NOT)

**Workflow Modifications:**
- ❌ **NEVER edit workflows in the n8n UI, period** - ALL workflow modifications MUST be done via CLI
- ❌ **NEVER suggest UI edits when debugging or adding features** - Use the CLI workflow process below
- ✅ **ALWAYS use the mandatory 6-step CLI workflow process** for all workflow changes

**MANDATORY Workflow Modification Process:**
1. Export: `./scripts/manage-workflow.sh export <id>`
2. Edit: Use Read/Edit tools on `workflows/XX-name/workflow.json`
3. Update: `./scripts/manage-workflow.sh update <id> <file>`
4. Test: `./workflows/XX-name/scripts/test-with-markers.sh`
5. Document: Update `workflows/XX-name/docs/STATUS.md`
6. Commit: Git add workflow.json and STATUS.md

**Why this is mandatory:**
- UI changes don't persist in git (breaks version control)
- JSON files are the single source of truth
- CLI workflow ensures testing and documentation happen
- Professional n8n teams never use UI for version-controlled workflows

**Testing:**
- ❌ **NEVER use production database for testing** - Always use test_run markers
- ❌ **NEVER skip `test_run` marker** when testing workflows
- ❌ **NEVER commit test data** to production tables
- ✅ **ALWAYS cleanup test data** with `./scripts/cleanup-tests.sh`

**Documentation:**
- ❌ **NEVER modify workflow.json without updating STATUS.md**
- ✅ **ALWAYS update documentation** after changes

**Security:**
- ❌ **NEVER commit .env files** - Use .env.example only
- ❌ **NEVER skip duplicate detection** in ingestion workflow

**Code Quality:**
- ❌ **NEVER use ANY type** in TypeScript/Swift - Always specify types
- ✅ **ALWAYS use parameterized SQL queries** (prevent injection)

**See:** `@workflows/CLAUDE.md` and `@.claude/OPERATIONS.md` for detailed procedures

---

## Quick Command Reference

### Workflow Management
```bash
./scripts/manage-workflow.sh list              # List workflows
./scripts/manage-workflow.sh export <id>       # Export workflow
./scripts/manage-workflow.sh update <id> <file> # Update workflow
```

### Testing
```bash
./workflows/XX-name/scripts/test-with-markers.sh  # Test workflow
./scripts/cleanup-tests.sh --list                  # List test runs
./scripts/cleanup-tests.sh <test-run-id>           # Cleanup
```

### Docker
```bash
docker-compose up -d       # Start
docker-compose logs -f n8n # View logs
docker-compose restart n8n # Restart
```

### Database
```bash
sqlite3 data/selene.db "SELECT COUNT(*) FROM raw_notes;"
sqlite3 data/selene.db ".schema raw_notes"
```

**Full command reference:** `@.claude/OPERATIONS.md`

---

## Project Status

**Completed:**
- ✅ Workflow 01 (Ingestion) - Production ready
- ✅ Workflow 02 (LLM Processing) - Concept extraction working
- ✅ Workflow 03 (Pattern Detection) - Theme trend analysis
- ✅ Phase 2 - Obsidian Export - ADHD-optimized export
- ✅ SeleneChat - Database integration, Ollama AI, clickable citations

**Ready for Implementation:**
- 📋 Phase 7.1 - Task Extraction with Classification (design revised 2025-12-30)
  - Local AI classifies: actionable / needs_planning / archive_only
  - Actionable tasks route to Things inbox
  - needs_planning items flagged for SeleneChat

**Next Up:**
- ⬜ Phase 7.2 - SeleneChat Planning Integration
- ⬜ Phase 7.3 - Cloud AI Integration (sanitization layer)
- ⬜ Phase 7.4 - Contextual Surfacing

**Details:** `@.claude/PROJECT-STATUS.md`

---

## File Organization

### Key Directories

```
selene-n8n/
├── .claude/                 # Context files for AI development
│   ├── README.md           # Context navigation guide (START HERE)
│   ├── DEVELOPMENT.md      # Architecture and decisions
│   ├── OPERATIONS.md       # Daily commands and procedures
│   ├── ADHD_Principles.md  # ADHD design framework
│   └── PROJECT-STATUS.md   # Current state
├── workflows/              # n8n workflows
│   ├── CLAUDE.md          # Workflow development patterns
│   └── XX-name/           # Individual workflows
│       ├── workflow.json  # Source of truth
│       ├── README.md      # Quick start
│       ├── docs/STATUS.md # Test results
│       └── scripts/       # Test utilities
├── scripts/                # Project-wide utilities
│   ├── CLAUDE.md          # Script documentation
│   └── manage-workflow.sh # Workflow CLI tool
├── database/              # Database schema
│   └── schema.sql
├── docs/                  # User documentation
│   ├── README.md          # Documentation index
│   └── roadmap/           # Phase documents
├── SeleneChat/            # macOS app
└── data/                  # SQLite database
    └── selene.db
```

---

## Common Workflows

### Modifying a Workflow

1. Export: `./scripts/manage-workflow.sh export <id>`
2. Edit: Use Read/Edit tools on `workflows/XX-name/workflow.json`
3. Update: `./scripts/manage-workflow.sh update <id> <file>`
4. Test: `./workflows/XX-name/scripts/test-with-markers.sh`
5. Document: Update `workflows/XX-name/docs/STATUS.md`
6. Commit: `git add workflows/XX-name/workflow.json workflows/XX-name/docs/STATUS.md`

**See:** `@workflows/CLAUDE.md` (Workflow Modification Workflow)

### Testing Changes

1. Generate test ID: `TEST_RUN="test-run-$(date +%Y%m%d-%H%M%S)"`
2. Send test data with `test_run` marker
3. Verify results in database
4. Cleanup: `./scripts/cleanup-tests.sh "$TEST_RUN"`

**See:** `@.claude/OPERATIONS.md` (Testing Procedures)

### Daily Development

**Starting:**
- Check `@.claude/PROJECT-STATUS.md`
- Start Docker: `docker-compose up -d`
- Review `@ROADMAP.md` for next tasks

**During:**
- Test frequently with `test_run` markers
- Update STATUS.md after changes
- Commit logical chunks

**Ending:**
- Run full test suite
- Update PROJECT-STATUS.md
- Cleanup test data
- Commit all changes

**See:** `@.claude/OPERATIONS.md` (Daily Development Checklist)

---

## Learning Resources

**Getting oriented:**
1. Read `@.claude/README.md` (context navigation)
2. Read `@.claude/DEVELOPMENT.md` (architecture)
3. Read `@.claude/ADHD_Principles.md` (design philosophy)
4. Read `@.claude/PROJECT-STATUS.md` (current state)

**Working on specific tasks:**
- Workflows: `@workflows/CLAUDE.md`
- Scripts: `@scripts/CLAUDE.md`
- Operations: `@.claude/OPERATIONS.md`

**Deep dives:**
- Database schema: `@database/schema.sql`
- Phase details: `@docs/roadmap/`
- Project roadmap: `@ROADMAP.md`

---

## Support

**Documentation Questions:**
- Start with `@.claude/README.md` (context guide)
- Check relevant context file for your task
- Review `@docs/README.md` (user documentation)

**Technical Issues:**
- Check `@.claude/OPERATIONS.md` (Troubleshooting section)
- Review workflow STATUS.md files
- Check Docker logs: `docker-compose logs -f n8n`

---

## Version History

- **2025-12-30**: Added GitOps development practices (.claude/GITOPS.md)
- **2025-12-30**: Phase 7.1 design revised - Task Extraction with Classification
- **2025-11-27**: Reorganized into modular context structure
- **2025-11-13**: Added SeleneChat enhancements phase
- **2025-11-01**: Added Phase 1.5 (UUID Tracking Foundation)
- **2025-10-30**: Phase 1 completed (10 notes processed)
- **2025-10-18**: Initial roadmap created

---

**This is a living document. Update after major changes or architectural decisions.**

**For detailed context on any topic, see the navigation guide:** `@.claude/README.md`
