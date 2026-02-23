# Dev Environment Isolation Design

**Date:** 2026-02-21
**Status:** Done
**Topic:** infrastructure, developer-experience, privacy

---

## Problem

Claude Code currently has access to production data (personal notes, threads, relationships) during development. There's no persistent development dataset, no parallel environment for debugging, and no clear separation between production and dev builds.

## Goals

1. **Privacy:** Claude Code never reads production data (`~/selene-data/`)
2. **Realistic dev data:** ~500 Claude-generated fictional notes spanning 3 months, processed through all pipelines (LLM, vectors, threads, relationships)
3. **Full parallel environment:** Separate database, vector store, Obsidian vault, server instance
4. **Beta builds:** macOS dev builds run from build dir; iOS via Xcode direct install
5. **Simultaneous operation:** Production and dev environments run side-by-side without conflict

---

## Architecture

### Three Environment Tiers

| Tier | `SELENE_ENV` | Data Root | Purpose |
|------|-------------|-----------|---------|
| **Production** | `production` | `~/selene-data/` | Real data. Claude Code never reads this. |
| **Development** | `development` | `~/selene-data-dev/` | Persistent fake data for daily dev/debug. |
| **Test** | `test` | `<project-root>/data-test/` | Ephemeral data for automated tests. |

### Dev Data Directory Layout

```
~/selene-data-dev/
  selene.db              # SQLite database (full schema, fake data)
  vectors.lance/         # LanceDB vector index
  vault/                 # Obsidian vault ("Selene-Dev")
  digests/               # Daily summary outputs
  voice-memos/           # Fake voice memo transcripts
  logs/                  # Dev server logs
```

### Process Management

| | Production | Development |
|---|---|---|
| **Tool** | launchd (existing) | Overmind (new) |
| **Server port** | 5678 | 5679 |
| **Start** | `launchctl start com.selene.server` | `overmind start -f Procfile.dev` |
| **Stop** | `launchctl stop com.selene.server` | Ctrl-C |
| **Logs** | `~/selene-data/logs/` | One terminal, color-coded |
| **Auto-restart** | Yes (KeepAlive) | No (see crashes immediately) |

Both can run simultaneously — different ports, different data directories, zero conflict.

### Build Pipeline

| | Production | Development |
|---|---|---|
| **macOS** | `build-app.sh` -> `/Applications/SeleneChat.app` | `swift build` -> `.build/debug/SeleneChat` |
| **iOS** | Future (TestFlight) | Xcode direct install to device |
| **Detection** | `.app` bundle -> production paths | CLI binary -> dev paths |
| **Server URL (iOS)** | Port 5678 | Port 5679 (user-configurable in app) |

---

## Seed Data Generator

### Approach

1. Claude generates a JSON fixture file with ~500 fictional notes spanning 3 months
2. Seed script inserts notes and runs them through all processing pipelines
3. Fixture file is gitignored (generated on demand, not committed)

### Fictional Persona

A character with ADHD managing multiple life domains (topics to be refined):
- **Work:** Software engineer with a side project (recipe app)
- **Learning:** Online course in ceramics
- **Health:** ADHD medication tracking, exercise, sleep
- **Personal:** Camping trip planning, apartment renovation
- **Random:** Book notes, podcast takeaways, shower thoughts

### Data Characteristics

- ~500 notes across 3 months
- Varied lengths (1 sentence to 3 paragraphs)
- Varied energy/mood markers
- Natural clustering (ceramics notes in bursts, work notes on weekdays)
- Cross-references between notes ("following up on that recipe API idea...")
- Enough for meaningful threads (8-12), relationships, momentum scores, and realistic briefings

### Seed Pipeline

The seed script (`scripts/seed-dev-data.ts`):
1. Reads the fixture JSON
2. Inserts notes into `raw_notes` with realistic timestamps
3. Runs `process-llm.ts` (concept extraction via Ollama)
4. Runs `index-vectors.ts` (embedding generation)
5. Runs `compute-relationships.ts` (note relationships)
6. Runs `detect-threads.ts` (thread detection)
7. Runs `reconsolidate-threads.ts` (thread summaries)
8. Runs `export-obsidian.ts` (populate dev Obsidian vault)

### Reset

`scripts/reset-dev-data.sh` — drops dev DB, clears vectors and vault, re-runs seed.

---

## Code Changes

### `src/lib/config.ts`

- Add `development` as a recognized `SELENE_ENV` value
- `development` maps all paths to `~/selene-data-dev/`
- CLI/script default changes from `test` to `development`

### SeleneChat `DatabaseService`

- CLI binary detection maps to `development` tier instead of `test`
- `.app` bundle continues mapping to `production`

### Health Endpoint

- Include current `SELENE_ENV` mode in health check response

---

## New Files

| File | Purpose |
|------|---------|
| `scripts/seed-dev-data.ts` | Generate fixture and process through all pipelines |
| `scripts/reset-dev-data.sh` | Wipe and reseed dev environment |
| `Procfile.dev` | Overmind process definitions for dev |
| `.env.development` | Dev environment variables |
| `fixtures/dev-seed-notes.json` | Claude-generated fake notes (gitignored) |

---

## Developer Workflow

### First-Time Setup

```bash
brew install overmind tmux
npx ts-node scripts/seed-dev-data.ts   # Generate fake data, process through pipelines
# Register ~/selene-data-dev/vault/ as "Selene-Dev" vault in Obsidian
```

### Starting a Dev Session

```bash
overmind start -f Procfile.dev          # Dev server (5679) + workflows
swift build                              # Build SeleneChat (auto-uses dev data)
.build/debug/SeleneChat                  # Run against dev DB
# iOS: Xcode build+run, point to http://<mac>:5679
```

### During Development

```bash
overmind connect server                  # Attach to server logs
overmind restart process-llm             # Restart specific workflow
curl http://localhost:5679/health        # Verify dev server mode
```

### Resetting Dev Data

```bash
scripts/reset-dev-data.sh               # Wipe and reseed everything
```

---

## Acceptance Criteria

- [x] `SELENE_ENV=development` resolves all paths to `~/selene-data-dev/`
- [x] Dev server runs on port 5679 alongside production on 5678
- [x] Seed script generates ~500 notes and processes through all pipelines
- [x] SeleneChat CLI build auto-connects to dev database
- [x] SeleneMobile can connect to dev server on port 5679
- [x] Dev Obsidian vault populated with fictional data
- [x] `reset-dev-data.sh` cleanly wipes and reseeds
- [x] Production data (`~/selene-data/`) is never read by dev tools
- [x] `overmind start -f Procfile.dev` brings up full dev stack

## ADHD Check

- [x] **Reduces friction:** One command to start dev (`overmind start`)
- [x] **Externalizes cognition:** Clear visual separation (different port, different app location)
- [x] **Makes things visible:** Health endpoint shows current mode; Obsidian vault is browsable
- [x] **Realistic over idealistic:** Fake data exercises real pipelines, not mocked stubs

## Scope Check

- [x] Estimable as < 1 week of focused work? **Yes** — completed in one session
