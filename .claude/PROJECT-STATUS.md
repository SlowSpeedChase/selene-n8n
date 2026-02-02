# Selene Project - Current Status

**Last Updated:** 2026-02-02
**Status:** Phase 7.2 Complete | Thread System Phase 3 Complete | iMessage Daily Digest Active | Living System Active

---

## Project Overview

Selene is a **thought consolidation system** for someone with ADHD. The core problem is not capturing thoughts or organizing them - it is making sense of them over time and knowing when to act.

Notes form **threads** - lines of thinking that span multiple notes, have underlying motivations, and eventually become projects or writing or decisions. **The system's job is to hold the thread so the user does not have to.**

**Architecture:** TypeScript + Fastify + launchd with SQLite database + Ollama embeddings
**Location:** `/Users/chaseeasterling/selene-n8n`

---
## Current Focus: Thread System Phase 3 Complete

**Branch:** `main` (all work merged)

The thread system is now a **living system** - new notes flow through the full pipeline automatically:
- Embedding generation (every 5 min)
- Association computation (every 5 min)
- Thread detection (every 30 min)
- Thread reconsolidation (hourly) - updates summaries + calculates momentum

### Completed Components

| Component | File | Status |
|-----------|------|--------|
| Webhook Server | `src/server.ts` | Done |
| Database Utilities | `src/lib/db.ts` | Done |
| Ollama Client | `src/lib/ollama.ts` | Done |
| Logger (Pino) | `src/lib/logger.ts` | Done |
| Configuration | `src/lib/config.ts` | Done |
| Ingestion Workflow | `src/workflows/ingest.ts` | Done |
| LLM Processing | `src/workflows/process-llm.ts` | Done |
| Task Extraction | `src/workflows/extract-tasks.ts` | Done |
| Embedding Generation | `src/workflows/compute-embeddings.ts` | Done |
| Association Computation | `src/workflows/compute-associations.ts` | Done |
| Thread Detection | `src/workflows/detect-threads.ts` | Done |
| Thread Reconsolidation | `src/workflows/reconsolidate-threads.ts` | Done |
| Daily Summary | `src/workflows/daily-summary.ts` | Done |
| iMessage Digest | `src/workflows/send-digest.ts` | Done |
| Launchd Agents | `launchd/*.plist` | Done |
| Install Script | `scripts/install-launchd.sh` | Done |

### Why Replace n8n?

1. **Simpler debugging** - TypeScript stack traces vs n8n execution logs
2. **Version control** - All code in git, no UI state to sync
3. **Fewer moving parts** - No Docker, no n8n runtime overhead
4. **Type safety** - TypeScript catches errors at compile time
5. **macOS native** - launchd is reliable, built-in, and efficient

---

## System Architecture

### Components

```
Drafts App
    |
    v
Fastify Server (port 5678)
    |
    v
SQLite Database (data/selene.db)
    ^
    |
launchd Scheduled Jobs:
  - process-llm (every 5 min)
  - extract-tasks (every 5 min)
  - compute-embeddings (every 5 min)
  - compute-associations (every 5 min)
  - detect-threads (every 30 min)
  - reconsolidate-threads (hourly)
  - daily-summary (midnight)
  - send-digest (6am)
    |
    v
Ollama (localhost:11434)
  - mistral:7b (text generation)
  - nomic-embed-text (embeddings)
```

### Key Files

```
src/
  server.ts           # Fastify webhook server
  lib/
    config.ts         # Environment configuration
    db.ts             # better-sqlite3 database utilities
    logger.ts         # Pino structured logging
    ollama.ts         # Ollama API client
  workflows/
    ingest.ts         # Note ingestion (called by webhook)
    process-llm.ts    # LLM concept extraction
    extract-tasks.ts  # Task classification
    compute-embeddings.ts
    compute-associations.ts
    daily-summary.ts
    send-digest.ts
  types/
    index.ts          # Shared TypeScript types

launchd/
  com.selene.server.plist
  com.selene.process-llm.plist
  com.selene.extract-tasks.plist
  com.selene.compute-embeddings.plist
  com.selene.compute-associations.plist
  com.selene.daily-summary.plist
  com.selene.send-digest.plist

logs/
  selene.log          # Workflow logs (Pino JSON)
  server.out.log      # Server stdout
  server.err.log      # Server stderr
```

---

## Existing Features (Migrated)

### Ingestion
- Webhook endpoint: `POST /webhook/api/drafts`
- Duplicate detection via content hash
- Tag extraction from #hashtags
- Word/character count calculation
- Test data marking system (`test_run` column)

### LLM Processing
- Concept extraction via Ollama
- Theme detection
- Status tracking (pending -> processing -> completed)

### Task Extraction
- Three-way classification: actionable / needs_planning / archive_only
- Things 3 integration for actionable tasks
- Discussion threads for planning items

### Embeddings & Associations
- Semantic embeddings via nomic-embed-text
- Cosine similarity for note relationships
- Note clustering and thread detection

### Daily Summary
- Aggregates notes, insights, patterns
- LLM-generated executive summary
- Writes to Obsidian vault

---

## Database Schema

**Type:** SQLite
**Location:** `data/selene.db`

**Tables:**
- `raw_notes` - Ingested notes
- `processed_notes` - LLM processed notes
- `note_embeddings` - Semantic embeddings
- `note_associations` - Note relationships
- `detected_patterns` - Pattern detection results
- `extracted_tasks` - Task classification results

---

## Common Commands

### Server
```bash
curl http://localhost:5678/health           # Health check
tail -f logs/server.out.log                 # Server logs
launchctl kickstart -k gui/$(id -u)/com.selene.server  # Restart
```

### Workflows
```bash
npx ts-node src/workflows/process-llm.ts
npx ts-node src/workflows/extract-tasks.ts
npx ts-node src/workflows/compute-embeddings.ts
tail -f logs/selene.log | npx pino-pretty   # View logs
```

### Launchd
```bash
launchctl list | grep selene                # List agents
./scripts/install-launchd.sh                # Install agents
```

### Testing
```bash
curl -X POST http://localhost:5678/webhook/api/drafts \
  -H "Content-Type: application/json" \
  -d '{"title": "Test", "content": "Test content", "test_run": "test-123"}'

./scripts/cleanup-tests.sh --list           # List test runs
./scripts/cleanup-tests.sh test-123         # Cleanup
```

---

## Next Steps

**Completed:**
- ✅ n8n replacement merged to main (TypeScript + Fastify + launchd)
- ✅ Phase 7.2 complete (SeleneChat Planning Integration)
- ✅ Thread System Phase 1-2 complete (Embeddings, Associations, Detection)
- ✅ Thread System Phase 3 complete (Living System with reconsolidation)
- ✅ iMessage Daily Digest (condensed summary at 6am)

**Up Next (choose one track):**

**Track A: Thread System Phase 3+ (Advanced Features)**
- Thread splitting (sub-clusters emerge)
- Thread merging (related threads combine)
- Stale thread archiving (60+ days inactive)

**Track B: SeleneChat UI**
- Forest Study visual redesign (design docs ready)
- Interface improvements (command palette, focus mode)

**Track C: Phase 7.4 (Contextual Surfacing)**
- Thread continuation prompts
- Resurface dormant threads

**Track D: Thread System Phase 4 (Interfaces)**
- ~~SeleneChat thread queries~~ ✅ Done
- ~~Thread export to Obsidian~~ ✅ Done
- Link tasks to threads

**Track E: LanceDB Migration**
- Vector database for better embedding storage/queries
- Design doc ready in `docs/plans/`

**Deprioritized (bundled for future):**
- Phase 7.3 (Cloud AI Integration) + Things Checklist Generation
- Rationale: Checklist quality would benefit significantly from Cloud AI
- Branch `feature/things-checklist` preserved with implementation (7 commits)

---

## Recent Achievements

### 2026-02-02
- **iMessage Daily Digest** - Condensed daily summary sent to phone at 6am via AppleScript
  - `daily-summary.ts` generates bullet-point digest via Ollama at midnight
  - `send-digest.ts` sends via iMessage at 6am (new launchd job)
  - Configured with `IMESSAGE_DIGEST_TO` env var
  - End-to-end tested and working

### 2026-01-11
- **Obsidian Thread Export Complete** - Threads export to `Selene/Threads/` during reconsolidation
  - Markdown with frontmatter for Dataview queries
  - Wiki-links to exported notes
  - Integrated into hourly reconsolidation workflow
- **SeleneChat Thread Queries Complete** - "what's emerging" and "show me [thread]" queries
  - Added Thread model to SeleneChat
  - Added thread query detection to QueryAnalyzer
  - Added getActiveThreads/getThreadByName to DatabaseService
  - Thread queries bypass Ollama for instant response
- **Thread System Phase 3 Complete** - Living System active
- Created `reconsolidate-threads.ts` workflow (summary updates + momentum)
- Created launchd plist for hourly reconsolidation
- Updated launchd intervals: embeddings/associations now 5 min, detect-threads 30 min
- Fixed server launchd plist to use `npm run start`
- End-to-end pipeline tested and verified
- 2 active threads with momentum scores calculated

### 2026-01-10
- Synced ROADMAP.md with stories INDEX.md
- Confirmed Phase 7.2 fully complete (7.2f.2-6 all merged)
- Confirmed Thread System Phase 1-2 complete
- Updated documentation with four next-track options
- Completed US-045: Thread Detection Workflow
- Applied thread system database migration (013_thread_system.sql)
- Generated embeddings for 15 production notes
- Computed 64 associations (threshold 0.5)
- Detected 2 threads via LLM synthesis
- Created launchd plist for scheduled thread detection

### 2026-01-09
- Completed TypeScript backend replacement
- Implemented all workflow scripts
- Created launchd agents for scheduling
- Updated documentation

### 2026-01-04
- Thread System Design complete
- Stories US-040 through US-044 defined

### 2025-12-31
- Phase 7.2d Complete - AI Provider Toggle
- Phase 7.2 Design Complete - SeleneChat Planning Integration

### 2025-12-30
- Phase 7.1 Complete - Task Extraction with Classification
- File-based Things integration with launchd automation

---

## Files to Reference

**Must Read:**
- `docs/plans/2026-01-04-selene-thread-system-design.md` - Thread system design
- `docs/plans/INDEX.md` - Design documents for implementation
- `database/schema.sql` - Database structure

**Source Code:**
- `src/server.ts` - Webhook server entry point
- `src/lib/` - Shared utilities
- `src/workflows/` - Background processing scripts
- `launchd/` - macOS launch agent configurations

---

## Questions for Next Session

1. Which track to pursue next? (A: Thread Advanced, B: UI Redesign, C: Contextual Surfacing, D: Thread Interfaces, E: LanceDB)
2. Monitor the living system over the next few days - are thread summaries updating correctly?
