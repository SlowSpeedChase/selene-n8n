# Selene-n8n Project Context

## Purpose

ADHD-focused knowledge management system using n8n workflows, SQLite, and local LLM processing for note capture, organization, and retrieval. Designed to externalize working memory and make information visual and accessible.

## Tech Stack

- **n8n** - Workflow automation engine (Docker-based)
- **SQLite** + better-sqlite3 - Database for note storage
- **Ollama** + mistral:7b - Local LLM for concept extraction
- **Swift** + SwiftUI - SeleneChat macOS app
- **Docker** - Container orchestration
- **Drafts** - iOS/Mac note capture app

## Key Components

- **workflows/** - 6 n8n automation workflows (~1,627 lines JSON total)
- **SeleneChat/** - Native macOS query interface (Swift)
- **database/** - SQLite schema and migrations (8 tables)
- **scripts/** - Utility automation (15+ bash scripts)
- **docs/** - Comprehensive documentation hub

## ADHD Design Principles

1. **Externalize Working Memory** - Visual systems, not mental tracking
2. **Make Time Visible** - Structured vs. unstructured time
3. **Reduce Friction** - One-click capture, minimal steps
4. **Visual Over Mental** - "Out of sight, out of mind"
5. **Realistic Over Idealistic** - Under-schedule, not over-schedule

## Architecture

**Three-Tier System:**
1. **Capture** (Drafts → n8n webhook → SQLite) - Single collection point
2. **Process** (n8n workflows → Ollama LLM) - Concept extraction, sentiment analysis
3. **Retrieve** (SeleneChat macOS app) - Query and explore notes

**Data Flow:**
```
Drafts App → Webhook (01-ingestion) → raw_notes table
           → LLM Processing (02) → processed_notes table
           → Pattern Detection (03) → detected_patterns table
           → Sentiment Analysis (05) → sentiment_history table
           → Connection Network (06) → network_analysis_history table
           → Obsidian Export (04) → vault/Selene/

SeleneChat → SQLite.swift → Query all tables → Display with citations
```

## Common Commands

```bash
# Docker n8n
docker-compose up -d              # Start n8n container
docker-compose down               # Stop n8n
docker-compose logs -f n8n        # View logs

# Testing
./scripts/test-ingest.sh          # Test note ingestion
./scripts/cleanup-tests.sh --list # List test runs
./scripts/cleanup-tests.sh <id>   # Clean specific test run

# SeleneChat
cd SeleneChat && swift build      # Build Swift app
swift test                         # Run tests
swift run                          # Run app

# Database
sqlite3 data/selene.db            # Access database directly
```

## Testing Patterns

**Test Data Isolation:**
- ALL test data marked with `test_run` column
- Format: `test-run-YYYYMMDD-HHMMSS`
- Programmatic cleanup without affecting production
- NULL test_run = production data

**Workflow Testing:**
- Each workflow has `scripts/test-with-markers.sh`
- Automated cleanup with `scripts/cleanup-tests.sh`
- STATUS.md tracks test results (e.g., 6/7 passing)

## Common Patterns

- **Duplicate Detection** - SHA256 hash of content in `content_hash` column
- **Status Tracking** - `status` column for workflow state (pending, processing, completed, failed)
- **Temporal Tracking** - `created_at`, `processed_at`, `updated_at` columns
- **Node Naming** - "Verb + Object" format (e.g., "Parse Note Data", "Check for Duplicate")
- **Error Handling** - Every n8n node connects to error handler
- **JSON Storage** - Complex data (concepts, themes) stored as JSON in TEXT columns

## File Organization

**Workflow Structure:**
```
workflows/XX-name/
├── workflow.json          # Main n8n workflow
├── README.md             # Quick start guide
├── docs/
│   ├── STATUS.md         # Test results
│   ├── *-SETUP.md        # Configuration guides
│   └── *-REFERENCE.md    # Technical details
├── scripts/
│   ├── test-with-markers.sh
│   └── cleanup-tests.sh
└── tests/                # Test data/scripts
```

**Documentation Structure:**
```
docs/
├── README.md             # Master index
├── roadmap/              # 15+ modular phase documents
├── plans/                # Design documents
└── [guides, architecture, workflows, api, troubleshooting]/
```

## Do NOT

- **NEVER skip duplicate detection** in ingestion workflow
- **NEVER use production database for testing** - always use test_run markers
- **NEVER modify workflow.json without updating STATUS.md**
- **NEVER commit .env files** - use .env.example only
- **NEVER commit test data** to production tables
- **NEVER skip `test_run` marker** when testing workflows
- **NEVER use ANY type in TypeScript/Swift** - always specify types

## Project Status

**Completed:**
- ✅ Workflow 01 (Ingestion) - Production ready, 6/7 tests passing
- ✅ SeleneChat - Database integration, Ollama AI, clickable citations

**In Progress:**
- 🔨 Phase 1.5 - UUID Tracking Foundation

**Next Up:**
- ⬜ Workflow 02 (LLM Processing) - Concept extraction
- ⬜ Phase 2 - Obsidian Export

## Related Context

@README.md
@docs/README.md
@ROADMAP.md
@.claude/ADHD_Principles.md
@.claude/PROJECT-STATUS.md
