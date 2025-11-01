# Selene n8n Migration Roadmap

**Created:** 2025-10-18
**Purpose:** Rebuild Selene as a visual, maintainable n8n workflow system
**Source:** Based on Python codebase analysis from `/selene` project

---

## Executive Summary

This roadmap translates the Selene Python codebase into a clean, visual n8n-based system. You've built a comprehensive note processing system but haven't been able to use it due to complexity. This fresh start uses n8n's visual workflows to make the system:

- **Simple to understand** - See the entire flow on one screen
- **Easy to debug** - Visual execution logs and error handling
- **Maintainable yourself** - No Python expertise required
- **Incrementally buildable** - Start with basics, add features as needed

---

## What We Learned from the Python Codebase

### Core Architecture (What We're Keeping)

1. **Database Schema** ✅ **REUSE AS-IS**
   - SQLite database with excellent schema design
   - Tables: `raw_notes`, `processed_notes`, `themes`, `concepts`, `connections`, `patterns`
   - Path: `/selene/data/schema.sql` (304 lines, production-ready)
   - **Action:** Copy schema.sql to new project and reuse

2. **Drafts Integration Pattern** ✅ **SIMPLIFY FOR N8N**
   - Current: Complex Python client with x-callback-url, HTTP server, retries
   - n8n approach: Simple webhook endpoint + HTTP request nodes
   - Key insight: Drafts can POST directly to n8n webhooks (already working in your test file)

3. **Ollama/LLM Processing** ✅ **SIMPLIFY FOR N8N**
   - Current: Sophisticated adapter with retry logic, prompt templates
   - n8n approach: HTTP Request node to `localhost:11434/api/generate`
   - Key prompts to preserve:
     - Concept extraction: "Extract 5-10 key concepts as JSON array"
     - Theme detection: "Identify primary and secondary themes as JSON"
     - Entity extraction: "Extract people, places, organizations, dates as JSON"

4. **Obsidian Export** ✅ **SIMPLIFY FOR N8N**
   - Current: Complex Python exporter with 1000+ lines
   - n8n approach: Simple workflow that queries DB and writes markdown files
   - Vault structure to preserve: `Selene/Concepts/`, `Selene/Themes/`, `Selene/Patterns/`

### What We're **NOT** Keeping

❌ **Python complexity** - All Python code stays archived
❌ **Virtual environments** - No more venv/pyenv
❌ **MCP server** - n8n replaces this orchestration layer
❌ **Production packaging** - Start simple, build up
❌ **268 tests** - Start fresh with simpler validation
❌ **Privacy guard scanning** - Manual localhost validation is enough

---

## n8n Workflow Architecture

### Phase 1: Core Workflow (START HERE)
**Goal:** Get a single note from Drafts → Ollama → SQLite working

```
┌─────────────────┐
│  Drafts Action  │
│  (sends note)   │
└────────┬────────┘
         │ HTTP POST
         ▼
┌─────────────────┐
│  n8n Webhook    │
│  Trigger Node   │
└────────┬────────┘
         │
         ▼
┌─────────────────┐
│  Extract Data   │
│  (Set Node)     │
└────────┬────────┘
         │
         ▼
┌─────────────────┐
│  Ollama HTTP    │
│  Request Node   │
│  (Concepts)     │
└────────┬────────┘
         │
         ▼
┌─────────────────┐
│  Ollama HTTP    │
│  Request Node   │
│  (Themes)       │
└────────┬────────┘
         │
         ▼
┌─────────────────┐
│  SQLite Insert  │
│  raw_notes      │
└────────┬────────┘
         │
         ▼
┌─────────────────┐
│  SQLite Insert  │
│  processed_notes│
└────────┬────────┘
         │
         ▼
┌─────────────────┐
│  Response Node  │
│  (Success JSON) │
└─────────────────┘
```

**Workflow File:** `01-core-ingestion.json`

**Node Details:**
1. **Webhook Trigger** - POST endpoint at `/webhook/selene/ingest`
2. **Set Node** - Extract: `{{ $json.content }}`, `{{ $json.title }}`, `{{ $json.uuid }}`
3. **HTTP Request (Concepts)** - POST to `http://localhost:11434/api/generate`
   ```json
   {
     "model": "mistral:7b",
     "prompt": "Extract 5-10 key concepts from this note as a JSON array: {{ $json.content }}",
     "stream": false
   }
   ```
4. **HTTP Request (Themes)** - POST to `http://localhost:11434/api/generate`
   ```json
   {
     "model": "mistral:7b",
     "prompt": "Identify primary theme and 2-3 secondary themes as JSON: {{ $json.content }}",
     "stream": false
   }
   ```
5. **SQLite Node** - Insert into `raw_notes` table
6. **SQLite Node** - Insert into `processed_notes` table
7. **Respond to Webhook** - Return success JSON with analysis

**Testing:**
- Use your existing `drafts-test-simple.js` script
- Expected result: Note appears in SQLite, Ollama processes it, success response to Drafts

---

### Phase 2: Obsidian Export Workflow
**Goal:** Export processed notes to Obsidian vault

```
┌─────────────────┐
│  Schedule/Cron  │
│  (hourly)       │
└────────┬────────┘
         │
         ▼
┌─────────────────┐
│  SQLite Query   │
│  Get Notes      │
└────────┬────────┘
         │
         ▼
┌─────────────────┐
│  Loop Over      │
│  Notes          │
└────────┬────────┘
         │
         ▼
┌─────────────────┐
│  Generate MD    │
│  (Function)     │
└────────┬────────┘
         │
         ▼
┌─────────────────┐
│  Write File     │
│  (to vault)     │
└─────────────────┘
```

**Workflow File:** `02-obsidian-export.json`

**Node Details:**
1. **Schedule Trigger** - Every hour (or manual trigger)
2. **SQLite Query** - `SELECT * FROM processed_notes WHERE exported = 0 LIMIT 100`
3. **Loop Node** - Iterate over results
4. **Function Node** - Generate markdown:
   ```javascript
   const note = $input.item.json;
   const concepts = JSON.parse(note.concepts || '[]');
   const themes = JSON.parse(note.themes || '[]');

   const markdown = `# ${note.title}

   ## Concepts
   ${concepts.map(c => `- [[${c}]]`).join('\n')}

   ## Themes
   ${themes.map(t => `- [[${t}]]`).join('\n')}

   ## Content
   ${note.content}

   ---
   *Processed: ${note.processed_at}*
   `;

   return {
     json: {
       filename: `Note_${note.id}.md`,
       content: markdown
     }
   };
   ```
5. **Write Binary File** - Save to `~/vault/Selene/Sources/`

---

### Phase 3: Pattern Detection Workflow (Optional)
**Goal:** Detect theme trends and concept clusters

```
┌─────────────────┐
│  Schedule/Cron  │
│  (daily)        │
└────────┬────────┘
         │
         ▼
┌─────────────────┐
│  SQLite Query   │
│  Theme Counts   │
└────────┬────────┘
         │
         ▼
┌─────────────────┐
│  Analyze Trends │
│  (Function)     │
└────────┬────────┘
         │
         ▼
┌─────────────────┐
│  Insert Pattern │
│  (SQLite)       │
└────────┬────────┘
         │
         ▼
┌─────────────────┐
│  Export Pattern │
│  to Obsidian    │
└─────────────────┘
```

**Workflow File:** `03-pattern-detection.json`

---

## Database Schema (COPY AS-IS)

**File:** `schema.sql` (from `/selene/data/schema.sql`)

**Key Tables:**
- `raw_notes` - Incoming notes from Drafts
- `processed_notes` - LLM analysis results
- `themes` - Discovered themes with trends
- `concepts` - Extracted concepts
- `connections` - Links between notes
- `patterns` - Detected patterns over time

**Action:** Copy the entire schema.sql file to new project and run it to create database

**Database Location:** `/Users/chaseeasterling/selene-n8n/data/selene.db`

---

## Drafts Integration (SIMPLIFIED)

### Current Python Approach (DON'T USE)
- Complex HTTP server with threading
- x-callback-url protocol
- Retry logic and timeout handling
- 1200+ lines of code

### n8n Approach (USE THIS)

**1. Drafts Action Script:**
```javascript
// File: drafts-to-selene.js
const WEBHOOK_URL = "http://localhost:5678/webhook/selene/ingest";

const payload = {
  uuid: draft.uuid,
  title: draft.title || "Untitled",
  content: draft.content,
  tags: draft.tags,
  created: draft.createdAt.toISOString()
};

const http = HTTP.create();
const response = http.request({
  url: WEBHOOK_URL,
  method: "POST",
  headers: { "Content-Type": "application/json" },
  data: payload
});

if (response.success) {
  app.displayInfoMessage("✅ Sent to Selene!");
} else {
  app.displayErrorMessage(`❌ Failed: ${response.statusCode}`);
}
```

**2. n8n Webhook Configuration:**
- Path: `/webhook/selene/ingest`
- Method: POST
- Response: JSON with processing results

**That's it!** No server management, no threading, no complexity.

---

## Ollama/LLM Integration (SIMPLIFIED)

### Current Python Approach (DON'T USE)
- Adapter pattern with interfaces
- Prompt template system
- Retry logic and exponential backoff
- Custom response parsers

### n8n Approach (USE THIS)

**HTTP Request Node Configuration:**

**Endpoint:** `http://localhost:11434/api/generate`
**Method:** POST

**For Concept Extraction:**
```json
{
  "model": "mistral:7b",
  "prompt": "Extract 5-10 key concepts from this note. Return ONLY a JSON array of strings, like: [\"concept1\", \"concept2\", \"concept3\"]\n\nNote content:\n{{ $json.content }}",
  "stream": false,
  "options": {
    "temperature": 0.3
  }
}
```

**Parse Response:**
```javascript
// Function node after HTTP request
const response = $input.item.json.response;
// Extract JSON array from response
const match = response.match(/\[.*\]/s);
if (match) {
  return { json: { concepts: JSON.parse(match[0]) } };
}
return { json: { concepts: [] } };
```

**For Theme Detection:**
```json
{
  "model": "mistral:7b",
  "prompt": "Identify themes in this note. Return ONLY a JSON object like: {\"primary\": \"main-theme\", \"secondary\": [\"theme1\", \"theme2\"]}\n\nNote content:\n{{ $json.content }}",
  "stream": false,
  "options": {
    "temperature": 0.3
  }
}
```

**Key Ollama Prompts (From Codebase Analysis):**

1. **Concept Extraction Prompt:**
   - System: "You are a concept extraction assistant for ADHD-friendly note processing."
   - User: "Extract 5-10 key concepts. Return JSON array only."
   - Max tokens: 500

2. **Theme Detection Prompt:**
   - System: "You categorize notes into themes for knowledge organization."
   - User: "Identify primary and secondary themes. Return JSON object only."
   - Max tokens: 300

3. **Entity Extraction Prompt:**
   - System: "You extract named entities: people, places, organizations, dates."
   - User: "Extract entities. Return JSON: {\"people\":[], \"places\":[], \"organizations\":[], \"dates\":[]}"
   - Max tokens: 500

---

## Project Structure

```
/Users/chaseeasterling/selene-n8n/
│
├── README.md                    # Project overview and setup
├── ROADMAP.md                   # This file
│
├── database/
│   ├── schema.sql              # Copy from /selene/data/schema.sql
│   └── selene.db               # SQLite database (created on first run)
│
├── n8n-workflows/
│   ├── 01-core-ingestion.json          # Phase 1: Drafts → Ollama → SQLite
│   ├── 02-obsidian-export.json         # Phase 2: SQLite → Obsidian markdown
│   ├── 03-pattern-detection.json       # Phase 3: Analyze patterns
│   └── 99-utilities.json               # Helper workflows (backup, cleanup)
│
├── drafts-actions/
│   ├── send-to-selene.js              # Main Drafts action
│   └── test-connection.js             # Test n8n connection
│
├── config/
│   ├── n8n.env                        # n8n environment variables
│   └── ollama-models.txt              # Required Ollama models
│
├── scripts/
│   ├── setup.sh                       # Initial setup script
│   ├── backup-db.sh                   # Database backup
│   └── test-ollama.sh                 # Test Ollama connection
│
└── vault/                             # Obsidian vault (export target)
    └── Selene/
        ├── Concepts/                  # Individual concept notes
        ├── Themes/                    # Theme analysis notes
        ├── Patterns/                  # Pattern detection results
        └── Sources/                   # Original note references
```

---

## Phased Implementation Plan

### ✅ Phase 1: Minimal Viable System (Week 1)
**Goal:** Get ONE note flowing through the entire pipeline

**Tasks:**
1. ✅ Create project directory structure
2. ⬜ Copy `schema.sql` from old project
3. ⬜ Create SQLite database: `sqlite3 database/selene.db < database/schema.sql`
4. ⬜ Build n8n workflow `01-core-ingestion.json`:
   - Webhook trigger
   - Extract note data
   - Call Ollama for concepts
   - Call Ollama for themes
   - Insert into `raw_notes`
   - Insert into `processed_notes`
   - Return success response
5. ⬜ Create Drafts action `send-to-selene.js`
6. ⬜ Test end-to-end with a real note
7. ⬜ Verify data in SQLite: `sqlite3 database/selene.db "SELECT * FROM processed_notes;"`

**Success Criteria:**
- ✅ Send note from Drafts
- ✅ Note appears in `raw_notes` table
- ✅ Ollama processes note (concepts + themes in `processed_notes`)
- ✅ Drafts shows success message
- ✅ Process takes < 30 seconds

**Time Estimate:** 2-4 hours

---

### ⬜ Phase 2: Obsidian Export (Week 2)
**Goal:** See your processed notes in Obsidian vault

**Tasks:**
1. ⬜ Create Obsidian vault directory structure
2. ⬜ Build n8n workflow `02-obsidian-export.json`:
   - Schedule trigger (hourly)
   - Query unexported notes from SQLite
   - Loop over results
   - Generate markdown with concept/theme links
   - Write files to vault
   - Mark notes as exported
3. ⬜ Test with 5-10 notes
4. ⬜ Verify Obsidian can open and link notes

**Success Criteria:**
- ✅ Notes auto-export to Obsidian
- ✅ Concept links work (`[[concept-name]]`)
- ✅ Theme links work (`[[theme-name]]`)
- ✅ Vault structure is clean and navigable

**Time Estimate:** 3-5 hours

---

### ⬜ Phase 3: Basic Pattern Detection (Week 3-4)
**Goal:** See theme trends over time

**Tasks:**
1. ⬜ Build n8n workflow `03-pattern-detection.json`:
   - Schedule trigger (daily)
   - Query theme frequency over last 7/30/90 days
   - Calculate trending themes (increasing frequency)
   - Detect concept clusters (concepts that appear together)
   - Insert results into `patterns` table
   - Export pattern notes to Obsidian
2. ⬜ Create pattern visualization in Obsidian

**Success Criteria:**
- ✅ Daily pattern analysis runs automatically
- ✅ Can see which themes are trending
- ✅ Concept clusters are identified
- ✅ Pattern notes link to source notes

**Time Estimate:** 4-6 hours

---

### ⬜ Phase 4: Polish & Enhancements (Ongoing)
**Optional improvements as needed:**

- **Error Handling:** Add IF nodes to handle Ollama failures
- **Batch Processing:** Add workflow to process multiple notes at once
- **Custom Themes:** Add UI to define your own theme categories
- **Search Interface:** Add n8n workflow with webhook for searching notes
- **Backup Automation:** Schedule daily SQLite backups
- **Stats Dashboard:** Create n8n workflow that generates daily stats

---

## Configuration Files

### `config/n8n.env`
```bash
# n8n Configuration
N8N_PORT=5678
N8N_HOST=localhost
N8N_PROTOCOL=http

# Database
SELENE_DB_PATH=/Users/chaseeasterling/selene-n8n/database/selene.db

# Ollama
OLLAMA_BASE_URL=http://localhost:11434
OLLAMA_MODEL=mistral:7b

# Obsidian
OBSIDIAN_VAULT_PATH=/Users/chaseeasterling/selene-n8n/vault

# Webhooks
WEBHOOK_BASE_URL=http://localhost:5678
```

### `config/ollama-models.txt`
```
mistral:7b
```

---

## Setup Instructions

### Prerequisites
- ✅ Docker installed (for n8n)
- ✅ Ollama installed with `mistral:7b` model
- ✅ Drafts app on iOS/Mac
- ✅ SQLite3 installed (comes with macOS)

### Initial Setup

**1. Create Project Structure:**
```bash
cd /Users/chaseeasterling
mkdir -p selene-n8n/{database,n8n-workflows,drafts-actions,config,scripts,vault/Selene/{Concepts,Themes,Patterns,Sources}}
cd selene-n8n
```

**2. Copy Database Schema:**
```bash
cp "/Users/chaseeasterling/Library/Mobile Documents/com~apple~CloudDocs/selene/data/schema.sql" database/
```

**3. Create Database:**
```bash
sqlite3 database/selene.db < database/schema.sql
```

**4. Start n8n (using Docker from old project):**
```bash
# Use existing docker-compose from /selene or create new one
cd "/Users/chaseeasterling/Library/Mobile Documents/com~apple~CloudDocs/selene"
docker-compose up -d
```

**5. Verify Ollama:**
```bash
curl http://localhost:11434/api/tags
# Should show mistral:7b in the list
```

**6. Create First Workflow:**
- Open n8n: `http://localhost:5678`
- Create new workflow
- Add nodes as described in Phase 1
- Save as `01-core-ingestion`
- Activate workflow
- Copy webhook URL

**7. Create Drafts Action:**
- Copy `drafts-to-selene.js` content
- Update `WEBHOOK_URL` with your n8n webhook URL
- Test with a note

---

## Testing & Validation

### Test 1: Webhook Connection
```bash
curl -X POST http://localhost:5678/webhook/selene/ingest \
  -H "Content-Type: application/json" \
  -d '{
    "uuid": "test-123",
    "title": "Test Note",
    "content": "This is a test note about project planning and meeting with the team.",
    "tags": ["test"],
    "created": "2025-10-18T10:00:00Z"
  }'
```

**Expected:** JSON response with success status

### Test 2: Ollama Processing
```bash
curl http://localhost:11434/api/generate -d '{
  "model": "mistral:7b",
  "prompt": "Extract key concepts from this text as a JSON array: Meeting about project planning",
  "stream": false
}'
```

**Expected:** JSON response with concepts array

### Test 3: Database Insertion
```bash
sqlite3 database/selene.db "SELECT COUNT(*) FROM raw_notes;"
sqlite3 database/selene.db "SELECT COUNT(*) FROM processed_notes;"
```

**Expected:** Counts increase after processing notes

### Test 4: End-to-End
1. Send note from Drafts app
2. Check n8n execution log (should show success)
3. Query database: `sqlite3 database/selene.db "SELECT title, concepts, themes FROM processed_notes ORDER BY id DESC LIMIT 1;"`
4. Verify concepts and themes were extracted

---

## Key Differences from Python Version

| Aspect | Python Version | n8n Version |
|--------|---------------|-------------|
| **Codebase Size** | 10,000+ lines | ~3 workflows (~500 lines equivalent) |
| **Setup Complexity** | venv, dependencies, config files | Import JSON, connect nodes |
| **Debugging** | Stack traces, logging | Visual execution logs |
| **Maintenance** | Python expertise required | Drag & drop nodes |
| **Testing** | 268 unit tests | Manual workflow testing |
| **Extensibility** | Write Python code | Add n8n nodes |
| **Visibility** | Code in files | Visual canvas |

---

## Migration Notes

### What to Copy from Python Project

✅ **COPY THESE:**
- `data/schema.sql` - Complete database schema
- `docs/n8n-workflows/drafts-test-simple.js` - Working Drafts action
- Ollama prompt templates (extracted in this doc)
- Configuration values (ports, model names)

❌ **DON'T COPY THESE:**
- All `.py` files
- `requirements.txt`
- `venv/` directory
- `tests/` directory
- `production-package/`
- Python-specific config files

### Archive Strategy

**Move old project to:**
```bash
mv "/Users/chaseeasterling/Library/Mobile Documents/com~apple~CloudDocs/selene" \
   "/Users/chaseeasterling/selene-archive-2025-10-18"
```

**What to keep accessible:**
- `schema.sql` (copied to new project)
- Ollama prompts (documented here)
- Workflow concepts (documented here)
- Any custom notes or documentation

---

## Next Steps (Immediate)

1. ✅ **Read this roadmap** - Make sure it makes sense
2. ⬜ **Copy database schema** - `cp schema.sql` to new project
3. ⬜ **Create database** - Run schema.sql
4. ⬜ **Start n8n** - Get workflow editor open
5. ⬜ **Build Phase 1 workflow** - Core ingestion only
6. ⬜ **Test with one note** - End-to-end validation
7. ⬜ **Verify in SQLite** - Confirm data is stored

**Don't:**
- ❌ Try to build everything at once
- ❌ Add features before core works
- ❌ Worry about the Python code
- ❌ Stress about completeness

**Focus on:** Getting ONE note from Drafts → Ollama → SQLite working perfectly.

---

## Support Resources

### Ollama API Reference
- Generate endpoint: `POST http://localhost:11434/api/generate`
- Model list: `GET http://localhost:11434/api/tags`
- Docs: https://github.com/ollama/ollama/blob/main/docs/api.md

### n8n Documentation
- HTTP Request node: https://docs.n8n.io/integrations/builtin/core-nodes/n8n-nodes-base.httprequest/
- SQLite node: https://docs.n8n.io/integrations/builtin/app-nodes/n8n-nodes-base.sqlite/
- Webhook node: https://docs.n8n.io/integrations/builtin/core-nodes/n8n-nodes-base.webhook/
- Function node: https://docs.n8n.io/code-examples/expressions/

### SQLite
- Query syntax: https://www.sqlite.org/lang.html
- CLI reference: https://www.sqlite.org/cli.html

---

## Questions to Ask Yourself

Before starting each phase, ask:

1. **Does the previous phase work perfectly?**
   - If no: Fix it before proceeding
   - If yes: Continue to next phase

2. **Can I explain what this workflow does in one sentence?**
   - If no: Simplify it
   - If yes: Build it

3. **Will I use this feature regularly?**
   - If no: Skip it for now
   - If yes: Prioritize it

4. **Can I test this in under 5 minutes?**
   - If no: Break it into smaller pieces
   - If yes: Build and test it

---

## Success Metrics

**Week 1:**
- ✅ 1 note successfully processed end-to-end
- ✅ Can query the note in SQLite
- ✅ Drafts action works reliably

**Week 2:**
- ✅ 10+ notes in system
- ✅ Notes exported to Obsidian
- ✅ Concept links work in Obsidian

**Week 3:**
- ✅ 50+ notes processed
- ✅ Pattern detection running daily
- ✅ Can see theme trends

**Month 1:**
- ✅ Using system daily for new notes
- ✅ Comfortable modifying workflows
- ✅ Backups running automatically

---

## Conclusion

This roadmap gives you a **clear path from complex Python codebase to simple n8n workflows**.

**The key insight:** You don't need to rebuild everything. Start with the absolute minimum (Phase 1) and only add features when you actually need them.

**Remember:**
- Used code has value, unused code has none
- Simple systems get used, complex ones get abandoned
- Visual workflows beat Python complexity
- Incremental progress beats perfect planning

**Start with Phase 1. Get one note working. Then decide what's next.**

Good luck! 🚀
