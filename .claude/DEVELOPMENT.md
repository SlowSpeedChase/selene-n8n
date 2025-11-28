# Development Context: Architecture & Decisions

**Purpose:** Architectural patterns, technology choices, and development standards for Selene. Read this when making design decisions or understanding system internals.

**Related Context:**
- `@.claude/ADHD_Principles.md` - Why we make ADHD-focused design choices
- `@.claude/OPERATIONS.md` - How to execute common operations
- `@workflows/CLAUDE.md` - Workflow-specific implementation patterns

---

## System Architecture

### Three-Tier Design

```
┌─────────────────────────────────────────────────────────────┐
│ TIER 1: CAPTURE (Reduce Friction)                          │
│ ┌──────────────┐                                            │
│ │  Drafts App  │ → Webhook → 01-Ingestion → SQLite         │
│ └──────────────┘                                            │
│ Design Goal: One-click note capture, zero organization      │
└─────────────────────────────────────────────────────────────┘

┌─────────────────────────────────────────────────────────────┐
│ TIER 2: PROCESS (Externalize Working Memory)               │
│ ┌──────────────────────────────────────────────────────┐   │
│ │ n8n Workflows:                                        │   │
│ │ 02-LLM Processing → Concepts/Themes                   │   │
│ │ 03-Pattern Detection → Trends                         │   │
│ │ 05-Sentiment Analysis → Emotional Tone                │   │
│ │ 06-Connection Network → Relationships                 │   │
│ └──────────────────────────────────────────────────────┘   │
│ Design Goal: Automatic organization, visual patterns       │
└─────────────────────────────────────────────────────────────┘

┌─────────────────────────────────────────────────────────────┐
│ TIER 3: RETRIEVE (Make Information Visible)                │
│ ┌─────────────────┐   ┌──────────────────┐                 │
│ │  SeleneChat App │   │ Obsidian Vault   │                 │
│ │  (Swift/macOS)  │   │ (04-Export)      │                 │
│ └─────────────────┘   └──────────────────┘                 │
│ Design Goal: Query and explore without mental overhead     │
└─────────────────────────────────────────────────────────────┘
```

### Why This Architecture?

**ADHD-Driven Decisions:**

1. **Single Capture Point** - Drafts app is the ONLY input
   - Reduces decision paralysis: "Where should this note go?"
   - Prevents information fragmentation across multiple apps
   - See: `@.claude/ADHD_Principles.md` (Capture section)

2. **Automatic Processing** - No manual tagging/filing
   - ADHD brains struggle with consistent categorization
   - LLM does the "thinking work" of extracting concepts
   - Visual patterns emerge without mental effort

3. **Multiple Retrieval Options** - SeleneChat + Obsidian
   - SeleneChat: Quick AI-powered search
   - Obsidian: Visual graph exploration
   - Different modes for different ADHD states (hyperfocus vs scattered)

---

## Technology Choices

### n8n vs Python

**Original System:** 10,000+ lines of Python
**Current System:** ~1,600 lines of n8n JSON

**Why We Switched:**

| Aspect | Python | n8n | ADHD Impact |
|--------|--------|-----|-------------|
| **Visibility** | Code in files | Visual canvas | ✅ Reduces "out of sight, out of mind" |
| **Debugging** | Stack traces | Execution logs | ✅ Visual flow easier to follow |
| **Maintenance** | Requires Python knowledge | Drag & drop | ✅ Lower cognitive load |
| **Setup** | venv, dependencies | Import JSON | ✅ Reduces friction |

**Decision:** Visual beats text for ADHD brains. n8n makes the entire system visible on one screen.

### SQLite vs PostgreSQL

**Choice:** SQLite (better-sqlite3)

**Rationale:**
- **Local-first:** All data on user's machine (privacy)
- **No server management:** Zero setup friction
- **Fast enough:** Tested with 10,000+ notes
- **Portable:** Single file database
- **ADHD-friendly:** No configuration paralysis

**Trade-offs Accepted:**
- ❌ No concurrent writes (not needed for personal system)
- ❌ No advanced features (not needed yet)
- ✅ Simplicity wins for solo ADHD user

### Ollama vs Cloud LLMs

**Choice:** Ollama (mistral:7b) local LLM

**Rationale:**
- **Privacy:** Notes never leave user's machine
- **No API costs:** Free to run unlimited processing
- **Offline capable:** Works without internet
- **Fast enough:** 10-30 seconds per note acceptable

**Trade-offs Accepted:**
- ❌ Less accurate than GPT-4 (good enough for concept extraction)
- ❌ Requires decent hardware (M1 Mac minimum)
- ✅ Privacy and cost win for personal notes

### Docker vs Native

**Choice:** Docker containerization

**Rationale:**
- **Reproducible:** Same environment everywhere
- **Isolated:** No conflicts with system packages
- **Easy reset:** `docker-compose down && docker-compose up -d`
- **ADHD-friendly:** "It just works" without troubleshooting

**Trade-offs Accepted:**
- ❌ Requires Docker installation
- ❌ Slightly more resource usage
- ✅ Simplicity wins over optimization

---

## Database Schema Design

### Core Tables

#### `raw_notes` (Ingestion Layer)
```sql
CREATE TABLE raw_notes (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    title TEXT NOT NULL,
    content TEXT NOT NULL,
    content_hash TEXT UNIQUE NOT NULL,  -- SHA256 for deduplication
    source_type TEXT DEFAULT 'drafts',
    source_uuid TEXT,                    -- Draft UUID for edit tracking
    word_count INTEGER DEFAULT 0,
    character_count INTEGER DEFAULT 0,
    tags TEXT,                           -- JSON array
    created_at DATETIME NOT NULL,
    imported_at DATETIME DEFAULT CURRENT_TIMESTAMP,
    processed_at DATETIME,
    exported_at DATETIME,
    status TEXT DEFAULT 'pending',       -- pending, processing, completed, failed
    exported_to_obsidian INTEGER DEFAULT 0,
    test_run TEXT DEFAULT NULL           -- Test data marker
);
```

**Design Decisions:**

- **content_hash:** Prevents exact duplicates (ADHD = repeat captures of same thought)
- **source_uuid:** Track individual drafts for edit detection (Phase 1.5)
- **status column:** Explicit workflow state tracking
- **test_run:** Programmatic test data isolation (never pollute production)
- **Timestamps:** created_at (user time) vs imported_at (system time)

#### `processed_notes` (LLM Layer)
```sql
CREATE TABLE processed_notes (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    raw_note_id INTEGER NOT NULL,
    concepts TEXT,                       -- JSON array of key concepts
    primary_theme TEXT,
    secondary_themes TEXT,               -- JSON array
    confidence_score REAL,
    processing_model TEXT DEFAULT 'mistral:7b',
    processed_at DATETIME DEFAULT CURRENT_TIMESTAMP,
    test_run TEXT DEFAULT NULL,
    FOREIGN KEY (raw_note_id) REFERENCES raw_notes(id)
);
```

**Design Decisions:**

- **JSON storage:** Flexible arrays without separate tables (YAGNI)
- **confidence_score:** Track LLM certainty for future filtering
- **processing_model:** Track which LLM version for debugging
- **Foreign key:** Maintain relationship to source note

### Testing Pattern: test_run Column

**Problem:** How to test workflows without polluting production data?

**Solution:** Every table has nullable `test_run` column

**Pattern:**
```bash
# Test data marked with unique ID
TEST_RUN="test-run-$(date +%Y%m%d-%H%M%S)"

# In test payload
{"content": "Test note", "test_run": "$TEST_RUN"}

# Cleanup
sqlite3 data/selene.db "DELETE FROM raw_notes WHERE test_run = '$TEST_RUN';"
```

**Why This Works:**
- Production data: `test_run IS NULL`
- Test data: `test_run = 'test-run-...'`
- Programmatic cleanup without manual sorting
- Zero risk of deleting production data

**See:** `@scripts/CLAUDE.md` (cleanup-tests.sh)

---

## Common Development Patterns

### Pattern 1: Duplicate Detection

**Problem:** ADHD users capture the same thought multiple times

**Solution:** SHA256 hash of content

**Implementation:**
```javascript
// In n8n Function node
const crypto = require('crypto');
const content = $json.content.trim();
const hash = crypto.createHash('sha256').update(content).digest('hex');

return {
  ...item.json,
  content_hash: hash
};
```

**Database Constraint:**
```sql
content_hash TEXT UNIQUE NOT NULL
```

**Behavior:** Second identical note is rejected (duplicate key error)

### Pattern 2: Status Tracking

**Problem:** Need to know what's been processed

**Solution:** Explicit status column with state transitions

**States:**
- `pending` → Note captured, waiting for processing
- `processing` → LLM currently analyzing
- `completed` → Processing finished
- `failed` → Error occurred (with error details)

**Transitions:**
```
pending → processing → completed
        ↓
       failed
```

**Query Pattern:**
```sql
-- Get unprocessed notes
SELECT * FROM raw_notes WHERE status = 'pending' LIMIT 10;

-- Mark as processing
UPDATE raw_notes SET status = 'processing' WHERE id = ?;

-- Mark as complete
UPDATE raw_notes SET
  status = 'completed',
  processed_at = CURRENT_TIMESTAMP
WHERE id = ?;
```

### Pattern 3: Node Naming Convention

**Format:** `[Verb] + [Object]`

**Examples:**
- ✅ "Parse Note Data"
- ✅ "Check for Duplicate"
- ✅ "Insert Raw Note"
- ✅ "Send to Ollama"
- ❌ "Function" (what does it do?)
- ❌ "Main Logic" (too vague)
- ❌ "Process" (verb needs object)

**Why:** ADHD brains scan visually. Clear names reduce cognitive load when debugging.

### Pattern 4: Error Handling

**Rule:** Every n8n node connects to error handler

**Pattern:**
```
[Node] → [Success Path]
   ↓
[On Error] → [Log Error] → [Update Status to Failed]
```

**Implementation:**
- Error node captures full context
- Logs to database or file
- Updates status column
- Optionally sends notification

**Why:** Failures must be visible. ADHD = "out of sight, out of mind" applies to errors too.

### Pattern 5: JSON Storage for Complex Data

**When to Use:**
- Arrays of strings (tags, concepts, themes)
- Small nested objects (metadata)
- Data structure evolving (early development)

**When NOT to Use:**
- Need to query/filter by nested values
- Large datasets (use proper columns + indexes)
- Relational data (use foreign keys)

**Example:**
```javascript
// Store concepts as JSON
{
  "concepts": ["time management", "focus", "productivity"],
  "primary_theme": "ADHD strategies",
  "secondary_themes": ["executive function", "motivation"]
}
```

**Query Pattern:**
```sql
-- SQLite JSON functions
SELECT * FROM processed_notes
WHERE json_extract(concepts, '$[0]') = 'time management';
```

---

## Integration Points

### Ollama Integration

**Container Access:**
```yaml
extra_hosts:
  - "host.docker.internal:host-gateway"
```

**URL from n8n:**
```
http://host.docker.internal:11434
```

**Why:** n8n runs in Docker, Ollama runs on host machine

**Model Configuration:**
```bash
# Environment variable
OLLAMA_MODEL=mistral:7b

# In workflow
POST http://host.docker.internal:11434/api/generate
{
  "model": "{{ $env.OLLAMA_MODEL }}",
  "prompt": "...",
  "stream": false
}
```

**See:** `@docs/roadmap/11-OLLAMA-INTEGRATION.md`

### Drafts App Integration

**Webhook URL:**
```
http://localhost:5678/webhook/api/drafts        # Same device
http://192.168.1.26:5678/webhook/api/drafts     # Same WiFi
http://100.111.6.10:5678/webhook/api/drafts     # Tailscale
```

**Payload Format:**
```json
{
  "title": "Note Title",
  "content": "Note content...",
  "uuid": "draft-uuid-123",
  "test_run": null
}
```

**Drafts Action Script:**
```javascript
let endpoint = "http://localhost:5678/webhook/api/drafts";
let data = {
  "title": draft.title,
  "content": draft.content,
  "uuid": draft.uuid
};

let http = HTTP.create();
let response = http.request({
  "url": endpoint,
  "method": "POST",
  "data": data,
  "headers": {"Content-Type": "application/json"}
});
```

**See:** `@workflows/01-ingestion/docs/DRAFTS-QUICKSTART.md`

### Obsidian Export Integration

**Vault Path:**
```yaml
volumes:
  - ${OBSIDIAN_VAULT_PATH:-./vault}:/obsidian:rw
```

**Export Format:**
```markdown
---
created: 2025-11-27T10:30:00
concepts: [[time management]], [[focus]], [[productivity]]
theme: ADHD strategies
---

# Note Title

Note content...

## Extracted Concepts
- time management
- focus
- productivity

## Related Notes
- [[Note about focus]]
- [[Note about productivity]]
```

**See:** `@workflows/04-obsidian-export/`

---

## Performance Considerations

### Tested Limits

| Metric | Tested | Performance |
|--------|--------|-------------|
| **Database Size** | 10,000+ notes | No slowdown |
| **Note Processing** | mistral:7b | 10-30 seconds per note |
| **Export Speed** | Obsidian | ~50 notes/minute |
| **Concurrent Processing** | Sequential | 1 note at a time (by design) |

### Optimization Decisions

**Sequential Processing (Not Parallel):**
- **Why:** Ollama on consumer hardware (M1 Mac) handles 1 request well, struggles with parallel
- **Trade-off:** Slower bulk processing, but reliable results
- **ADHD Impact:** User captures notes throughout day, not in batches

**Polling vs Event-Driven:**
- **Original:** Cron schedules (every 30 seconds)
- **Phase 6:** Event-driven triggers
- **Result:** 3x faster processing, 100% resource efficiency
- **See:** `@docs/roadmap/08-PHASE-6-EVENT-DRIVEN.md`

---

## Development Standards

### Testing Requirements

**Every workflow must have:**
1. `scripts/test-with-markers.sh` - Automated test suite
2. `docs/STATUS.md` - Test results and pass/fail tracking
3. Test cases for success path
4. Test cases for error conditions
5. Cleanup procedure

**See:** `@workflows/CLAUDE.md` (Testing section)

### Documentation Requirements

**When modifying workflows:**
1. Update `workflows/XX-name/docs/STATUS.md` with changes
2. Update `workflows/XX-name/README.md` if interface changed
3. Update `.claude/PROJECT-STATUS.md` when complete
4. Commit workflow.json to git

**See:** `@workflows/CLAUDE.md` (Documentation section)

### Git Commit Conventions

**Format:** `type: description`

**Types:**
- `feat:` New feature
- `fix:` Bug fix
- `docs:` Documentation only
- `refactor:` Code restructure, no behavior change
- `test:` Add or modify tests
- `workflow:` n8n workflow changes

**Examples:**
```bash
git commit -m "feat: add task extraction workflow"
git commit -m "fix: duplicate detection in ingestion workflow"
git commit -m "docs: update STATUS.md with test results"
git commit -m "workflow: add error handling to LLM processing"
```

---

## Questions to Ask When Designing Features

### ADHD Impact Check

Before implementing any feature, ask:

1. **Does this reduce friction?**
   - How many clicks/decisions required?
   - Can it be automated?

2. **Is this visible?**
   - Will user remember it exists?
   - Can they see progress/state?

3. **Does this reduce cognitive load?**
   - How much mental tracking required?
   - Can information be externalized?

4. **Is this realistic (not idealistic)?**
   - Does it assume perfect user behavior?
   - Does it account for forgetfulness?

**See:** `@.claude/ADHD_Principles.md` for full framework

### Technical Decision Checklist

1. **YAGNI:** Do we actually need this now?
2. **DRY:** Are we duplicating existing functionality?
3. **Testability:** Can we write automated tests?
4. **Simplicity:** Is this the simplest solution?
5. **Visibility:** Can we see when it breaks?

---

## Related Context Files

- **`@.claude/ADHD_Principles.md`** - Why ADHD drives our architecture
- **`@.claude/OPERATIONS.md`** - Daily commands and operations
- **`@workflows/CLAUDE.md`** - Workflow implementation patterns
- **`@.claude/PROJECT-STATUS.md`** - Current state of development
- **`@ROADMAP.md`** - Planned phases and features
