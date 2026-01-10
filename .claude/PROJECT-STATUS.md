# Selene Project - Current Status

**Last Updated:** 2026-01-09
**Status:** TypeScript Backend Replacement Complete

---

## Project Overview

Selene is a **thought consolidation system** for someone with ADHD. The core problem is not capturing thoughts or organizing them - it is making sense of them over time and knowing when to act.

Notes form **threads** - lines of thinking that span multiple notes, have underlying motivations, and eventually become projects or writing or decisions. **The system's job is to hold the thread so the user does not have to.**

**Architecture:** TypeScript + Fastify + launchd with SQLite database + Ollama embeddings
**Location:** `/Users/chaseeasterling/selene-n8n`

---

## Current Focus: TypeScript Backend

**Branch:** `n8n-replacement` (this branch)

The n8n workflow engine has been replaced with a pure TypeScript backend:

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
| Daily Summary | `src/workflows/daily-summary.ts` | Done |
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
  - compute-embeddings (every 10 min)
  - compute-associations (every 10 min)
  - daily-summary (midnight)
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
  types/
    index.ts          # Shared TypeScript types

launchd/
  com.selene.server.plist
  com.selene.process-llm.plist
  com.selene.extract-tasks.plist
  com.selene.compute-embeddings.plist
  com.selene.compute-associations.plist
  com.selene.daily-summary.plist

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

1. **Merge this branch** - Complete the n8n replacement
2. **Phase 7.2** - SeleneChat Planning Integration
3. **Phase 7.3** - Cloud AI Integration (sanitization layer)
4. **Phase 7.4** - Contextual Surfacing

---

## Recent Achievements

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
- `docs/stories/INDEX.md` - User stories for implementation
- `database/schema.sql` - Database structure

**Source Code:**
- `src/server.ts` - Webhook server entry point
- `src/lib/` - Shared utilities
- `src/workflows/` - Background processing scripts
- `launchd/` - macOS launch agent configurations

---

## Questions for Next Session

1. Should we merge the n8n-replacement branch to main?
2. Any issues with the launchd scheduling?
3. Ready to start Phase 7.2 (SeleneChat Planning)?
