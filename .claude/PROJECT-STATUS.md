# Selene n8n Project - Current Status

**Last Updated:** 2025-12-31
**Status:** Workflows 01, 07 & 08 Complete - Phase 7.2d (AI Provider Toggle) Design Complete

---

## Project Overview

Selene is an n8n-based automation system for capturing, processing, and managing notes from various sources (primarily Drafts app) with LLM processing and Obsidian export.

**Architecture:** Docker-based n8n with SQLite database
**Location:** `/Users/chaseeasterling/selene-n8n`

---

## Completed Workflows

### ✅ 01-Ingestion Workflow (COMPLETE)

**Status:** Tested and Production Ready (6/7 tests passing)
**Location:** `workflows/01-ingestion/`
**Webhook:** `http://localhost:5678/webhook/api/drafts`

**What It Does:**
- Receives notes via webhook (POST JSON)
- Validates content and extracts metadata
- Generates content hash for duplicate detection
- Extracts hashtags from content
- Stores in `raw_notes` table with status='pending'

**Key Features:**
- ✅ Duplicate detection via content hash
- ✅ Tag extraction (#hashtag support)
- ✅ Word/character count calculation
- ✅ Test data marking system (`test_run` column)
- ✅ Automated test suite with cleanup
- ✅ Drafts app integration ready

**Database Table:** `raw_notes`
```sql
CREATE TABLE raw_notes (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    title TEXT NOT NULL,
    content TEXT NOT NULL,
    content_hash TEXT UNIQUE NOT NULL,
    source_type TEXT DEFAULT 'drafts',
    word_count INTEGER DEFAULT 0,
    character_count INTEGER DEFAULT 0,
    tags TEXT, -- JSON array
    created_at DATETIME NOT NULL,
    imported_at DATETIME DEFAULT CURRENT_TIMESTAMP,
    processed_at DATETIME,
    exported_at DATETIME,
    status TEXT DEFAULT 'pending',
    exported_to_obsidian INTEGER DEFAULT 0,
    test_run TEXT DEFAULT NULL
);
```

**Configuration:**
- better-sqlite3 installed in `/home/node/.n8n/node_modules/`
- `NODE_FUNCTION_ALLOW_EXTERNAL=better-sqlite3`
- `NODE_PATH=/home/node/.n8n/node_modules`

**Known Issues:**
- Alternative query parameter format not supported (low priority)

**Testing:**
- Test suite: `./workflows/01-ingestion/scripts/test-with-markers.sh`
- Cleanup: `./workflows/01-ingestion/scripts/cleanup-tests.sh`

**Documentation:**
- Quick reference: `workflows/01-ingestion/INDEX.md`
- Status/results: `workflows/01-ingestion/docs/STATUS.md`
- Drafts setup: `workflows/01-ingestion/docs/DRAFTS-QUICKSTART.md`

---

### ✅ 08-Daily-Summary Workflow (COMPLETE)

**Status:** Production Ready
**Location:** `workflows/08-daily-summary/`
**Completed:** 2025-12-31

**What It Does:**
- Runs daily at midnight (00:00) via schedule trigger
- Queries last 24 hours of data from three sources:
  - `raw_notes` - Recently captured notes
  - `processed_notes` - LLM-extracted concepts and themes
  - `detected_patterns` - Active recurring patterns
- Sends data to Ollama (mistral:7b) for executive summary generation
- Writes formatted markdown to `/obsidian/Selene/Daily/YYYY-MM-DD-summary.md`
- Includes error fallback if Ollama is offline

**Key Features:**
- ✅ Automated daily execution (cron: 0 0 * * *)
- ✅ Multi-source data aggregation (notes + insights + patterns)
- ✅ LLM-generated executive summary
- ✅ ADHD-friendly daily context visibility
- ✅ Graceful error handling (Ollama timeout/offline)
- ✅ Obsidian vault integration

**Output Format:**
- Markdown file with daily statistics
- Summary of note activity and themes
- Connection to detected patterns
- Automatic timestamp and metadata

**Workflow Nodes:**
- Schedule: Midnight Daily (scheduleTrigger)
- Query All Data (function - parallel queries)
- Build Summary Prompt (function)
- Send to Ollama (httpRequest with 120s timeout)
- Fallback: Ollama Error (function)
- Prepare Markdown (function)
- Convert to Binary (moveBinaryData)
- Write to Obsidian (writeBinaryFile)

**Configuration:**
- Ollama URL: `http://host.docker.internal:11434/api/generate`
- Model: `mistral:7b`
- Output path: `/obsidian/Selene/Daily/`
- Timezone: Server timezone

**Testing:**
- Test script: `./workflows/08-daily-summary/scripts/test-with-markers.sh`
- Status: All tests passing (as of 2025-12-31)

**Documentation:**
- Quick start: `workflows/08-daily-summary/README.md`
- Status/results: `workflows/08-daily-summary/docs/STATUS.md`

---

### ✅ 07-Task-Extraction Workflow (COMPLETE)

**Status:** Production Ready
**Location:** `workflows/07-task-extraction/`
**Completed:** 2025-12-30

**What It Does:**
- Classifies notes as: `actionable`, `needs_planning`, or `archive_only`
- Extracts tasks from actionable notes using Ollama LLM
- Routes actionable tasks to Things 3 inbox via file-based handoff
- Flags `needs_planning` notes with discussion threads for SeleneChat
- Stores classification metadata in database

**Key Features:**
- ✅ Three-way classification using Ollama
- ✅ ADHD-optimized task metadata (energy, overwhelm, time estimates)
- ✅ File-based Things integration with launchd automation
- ✅ Discussion threads for planning items
- ✅ Full E2E tests passing

**Things Bridge Components:**
```
scripts/things-bridge/
├── add-task-to-things.scpt      # AppleScript for Things API
├── process-pending-tasks.sh     # Wrapper script
└── com.selene.things-bridge.plist  # launchd configuration
```

**Documentation:**
- Status/results: `workflows/07-task-extraction/STATUS.md`
- Design: `docs/plans/2025-12-30-task-extraction-planning-design.md`

---

## Next Workflows (TODO)

### 🔄 02-LLM Processing (IN PROGRESS)

**Status:** Not Started
**Location:** `workflows/02-llm-processing/` (file exists: `02-llm-processing-workflow.json`)
**Purpose:** Process notes from `raw_notes` with LLM

**Expected Flow:**
1. Query `raw_notes` WHERE status='pending'
2. Send to Ollama for processing
3. Extract insights, topics, connections
4. Store in `processed_notes` table
5. Update raw_notes.status='processed'

**Ollama Configuration:**
- URL: `http://host.docker.internal:11434` (from n8n container)
- Model: `mistral:7b` (configurable via `OLLAMA_MODEL` env var)
- Container has `host.docker.internal` mapped to host gateway

**Database Table:** `processed_notes` (needs verification)

**Questions to Answer:**
- What processing should be done?
- What should be extracted?
- How to structure processed_notes table?
- Batch processing or one-by-one?
- Error handling for LLM failures?

### 📊 03-Pattern Detection

**Status:** Not Started
**Location:** `workflows/03-pattern-detection/` (file exists: `03-pattern-detection-workflow.json`)

**Expected:** Analyze patterns across processed notes

### 📤 04-Obsidian Export

**Status:** Not Started
**Location:** `workflows/04-obsidian-export/` (file exists: `04-obsidian-export-workflow.json`)

**Expected:** Export processed notes to Obsidian vault
**Vault Path:** `/obsidian` (mounted from `${OBSIDIAN_VAULT_PATH:-./vault}`)

### 📈 05-Sentiment Analysis

**Status:** Not Started
**Location:** (file exists: `05-sentiment-analysis-workflow.json`)

### 🕸️ 06-Connection Network

**Status:** Not Started
**Location:** (file exists: `06-connection-network-workflow.json`)

---

## Technical Architecture

### Database

**Type:** SQLite
**Location:** `data/selene.db`
**Container Path:** `/selene/data/selene.db`

**Tables:**
- `raw_notes` - Ingested notes (workflow 01 ✅)
- `processed_notes` - LLM processed notes (workflow 02)
- `detected_patterns` - Pattern detection results (workflow 03)
- `sentiment_history` - Sentiment analysis (workflow 05)
- `network_analysis_history` - Connection network (workflow 06)
- `pattern_reports` - Pattern reports (workflow 03)
- `test_table` - Unknown purpose

**Schema Location:** `database/schema.sql`

### Docker Setup

**Container:** `selene-n8n`
**Image:** Custom build from `Dockerfile`
**Base:** `n8nio/n8n:latest`

**Volumes:**
- `n8n_data:/home/node/.n8n` - Persistent n8n data
- `./data:/selene/data:rw` - Database
- `./vault:/obsidian:rw` - Obsidian vault
- `.:/workflows:ro` - Workflow files (read-only)

**Environment Variables:**
```yaml
# Authentication
N8N_BASIC_AUTH_ACTIVE=true
N8N_BASIC_AUTH_USER=admin
N8N_BASIC_AUTH_PASSWORD=selene_n8n_2025

# Node modules
NODE_FUNCTION_ALLOW_EXTERNAL=better-sqlite3
NODE_PATH=/home/node/.n8n/node_modules

# Database paths
SELENE_DB_PATH=/selene/data/selene.db
OBSIDIAN_VAULT_PATH=/obsidian

# Ollama
OLLAMA_BASE_URL=http://localhost:11434
OLLAMA_MODEL=mistral:7b

# Community packages
N8N_COMMUNITY_PACKAGES_ENABLED=true
N8N_COMMUNITY_PACKAGES_INSTALL=n8n-nodes-sqlite
```

**Network:**
- `host.docker.internal:host-gateway` mapped for Ollama access

### Dependencies

**Installed in Container:**
- better-sqlite3@11.0.0 (in `/home/node/.n8n/node_modules/`)
- n8n-nodes-sqlite (community package)

**System Packages:**
- python3, make, g++, sqlite, sqlite-dev

---

## Important Patterns & Decisions

### 1. Better-SQLite3 Integration

**Problem:** n8n's VM2 sandbox can't access globally installed modules
**Solution:** Install in workspace + set NODE_PATH + whitelist with NODE_FUNCTION_ALLOW_EXTERNAL

**Usage in workflows:**
```javascript
const Database = require('better-sqlite3');
const db = new Database('/selene/data/selene.db');
// ... use db
db.close();
```

### 2. Test Data Management

**Pattern:** All test data marked with `test_run` column
**Benefit:** Easy programmatic cleanup without affecting production data

**Usage:**
```json
{
  "title": "Test Note",
  "content": "Content",
  "test_run": "test-run-20251030-120000"
}
```

**Cleanup:**
```bash
./scripts/cleanup-tests.sh test-run-20251030-120000
```

### 3. Switch vs IF Nodes

**Issue:** Switch node with `notExists` doesn't work with `null` values
**Solution:** Use IF node with explicit null check

**Correct Pattern:**
```javascript
// In IF node condition:
$json.id == null || $json.id == undefined
```

### 4. Workflow Response Modes

**webhook responseMode: "onReceived"** - Returns immediately, workflow runs async
**webhook responseMode: "lastNode"** - Waits for workflow completion

Currently using `onReceived` for ingestion workflow.

---

## Network Configuration

**Local Network IP:** 192.168.1.26
**Tailscale IP:** 100.111.6.10
**n8n Port:** 5678

**Drafts Webhook URLs:**
- Same device: `http://localhost:5678/webhook/api/drafts`
- Same WiFi: `http://192.168.1.26:5678/webhook/api/drafts`
- Tailscale: `http://100.111.6.10:5678/webhook/api/drafts`

---

## Testing Strategy

### Automated Tests
- Location: `workflows/*/scripts/test-with-markers.sh`
- Marks all data with unique `test_run` ID
- Provides cleanup instructions

### Manual Tests
- Always include `test_run` parameter
- Clean up after testing

### CI/CD Ready
- Tests can run in pipeline
- Automatic cleanup possible
- Test data isolated from production

---

## Common Commands

### Docker Management
```bash
docker-compose ps              # Check status
docker-compose logs n8n        # View logs
docker-compose restart n8n     # Restart
docker-compose down            # Stop
docker-compose up -d           # Start
```

### Database Access
```bash
sqlite3 data/selene.db "SELECT * FROM raw_notes LIMIT 5;"
sqlite3 data/selene.db ".tables"
sqlite3 data/selene.db ".schema raw_notes"
```

### Testing
```bash
cd workflows/01-ingestion
./scripts/test-with-markers.sh           # Run tests
./scripts/cleanup-tests.sh --list        # List test runs
./scripts/cleanup-tests.sh <test-run-id> # Clean specific run
```

---

## Next Session Priorities

1. **Implement Phase 7.2d - AI Provider Toggle** (NEXT)
   - Design doc: `docs/plans/2025-12-31-ai-provider-toggle-design.md`
   - Local LLM (Ollama) as default, explicit cloud opt-in
   - Per-conversation override with visual indicators

2. **Phase 7.2d-1: Core Infrastructure**
   - Create `AIProvider.swift` enum
   - Create `AIProviderService.swift` protocol and implementation
   - Update `ClaudeAPIService` to check for env var API key
   - Add `provider` field to `PlanningMessage` model

3. **Phase 7.2d-2: Settings UI**
   - Create `AIProviderSettings.swift` popover view
   - Add gear icon to Planning tab header
   - Show provider connection status

4. **Phase 7.2d-3: Conversation Toggle**
   - Add provider badge to conversation header
   - Implement "Include history?" prompt when switching to cloud
   - Store per-conversation provider override

5. **Phase 7.2d-4: Visual Indicators**
   - Style cloud messages with blue tint
   - Add provider icons to message bubbles
   - Inline error display for missing API key

6. **Phase 7.2e: Bidirectional Things Flow** (after 7.2d)
   - Implement Things status checking via AppleScript
   - Add resurface trigger logic
   - Update thread status based on task progress

---

## Files to Reference

**Must Read:**
- `workflows/01-ingestion/INDEX.md` - Complete file reference
- `workflows/01-ingestion/docs/STATUS.md` - Test results & patterns
- `database/schema.sql` - Database structure
- `docker-compose.yml` - Environment configuration

**Workflow Files:**
- `02-llm-processing-workflow.json` - Next to implement
- `03-pattern-detection-workflow.json`
- `04-obsidian-export-workflow.json`
- `05-sentiment-analysis-workflow.json`
- `06-connection-network-workflow.json`

---

## Questions for Next Session

1. Is Ollama running and accessible?
2. What model should be used? (default: mistral:7b)
3. What insights should LLM extract?
4. Should processing be batched or individual?
5. How to handle LLM failures/timeouts?
6. What metadata should be stored in processed_notes?
7. Should we trigger processing automatically or manually?

---

## Recent Achievements

### 2025-12-31
📋 Phase 7.2d Design Complete - AI Provider Toggle
- Local LLM (Ollama) as default, explicit cloud opt-in
- Global setting with per-conversation override
- Settings via gear icon in Planning tab header
- "Include history?" prompt when switching to cloud mid-conversation
- Visual indicators: header badge + message bubble styling
- API key via environment variable (ANTHROPIC_API_KEY)

📋 Phase 7.2 Design Complete - SeleneChat Planning Integration
- New "Planning" sidebar tab for guided breakdown conversations
- Dual AI routing: Ollama (sensitive) / Claude API (planning)
- Things as task database - only store relationship links in Selene
- Methodology layer: editable prompts/triggers without code changes
- Bidirectional Things flow with resurface triggers (progress/stuck/complete)
- Design doc: `docs/plans/2025-12-31-phase-7.2-selenechat-planning-design.md`

### 2025-12-30
✅ Completed Phase 7.1 - Task Extraction with Classification
✅ Three-way note classification (actionable/needs_planning/archive_only)
✅ File-based Things integration with launchd automation
✅ AppleScript bridge for Things API
✅ Discussion threads for planning items
✅ Full E2E tests passing for both actionable and needs_planning paths

### 2025-12-31
✅ Completed Workflow 08 - Daily Summary
✅ Implemented automated daily executive summaries
✅ Integrated Ollama LLM for summary generation
✅ Multi-source data aggregation (notes, insights, patterns)
✅ Obsidian vault output with markdown formatting
✅ Error handling for Ollama offline scenarios
✅ All tests passing

### 2025-10-30
✅ Completed ingestion workflow testing (6/7 pass rate)
✅ Fixed better-sqlite3 module loading
✅ Fixed switch node logic for duplicate detection
✅ Implemented test data management system
✅ Created comprehensive documentation
✅ Organized folder structure
✅ Set up Drafts app integration guide
✅ Marked existing test data for cleanup
✅ Updated all documentation paths

**Ready for:** Workflow 02 - LLM Processing

---

## Context Structure (2025-11-27)

### Modular Documentation

The codebase now uses modular context files optimized for Claude Code AI development:

**Root Level:**
- `CLAUDE.md` - High-level overview with navigation
- `ROADMAP.md` - Project phases and planning

**`.claude/` Directory:**
- `README.md` - Context navigation guide (START HERE)
- `DEVELOPMENT.md` - Architecture, patterns, decisions
- `OPERATIONS.md` - Daily commands and procedures
- `ADHD_Principles.md` - ADHD design framework
- `PROJECT-STATUS.md` - Current state (this file)

**`workflows/` Directory:**
- `CLAUDE.md` - Workflow development patterns
- `XX-name/workflow.json` - Source of truth for workflows
- `XX-name/docs/STATUS.md` - Per-workflow test results

**`scripts/` Directory:**
- `CLAUDE.md` - Script utilities documentation
- `manage-workflow.sh` - Workflow CLI tool

### Why This Structure?

**Single Responsibility:**
- Each file serves one specific AI task
- Development decisions separate from operations
- Workflow patterns separate from architecture

**Minimal Context Loading:**
- Agents read only what's needed for current task
- Faster context loading
- Reduced token usage

**DRY Principle:**
- Information lives in one canonical location
- Cross-references using @filename syntax
- No duplication across files

### Loading Patterns

**For workflow modifications:**
```
@workflows/CLAUDE.md → @.claude/OPERATIONS.md → @scripts/CLAUDE.md
```

**For architectural decisions:**
```
@.claude/DEVELOPMENT.md → @.claude/ADHD_Principles.md → @ROADMAP.md
```

**For daily operations:**
```
@.claude/OPERATIONS.md → @.claude/PROJECT-STATUS.md
```
