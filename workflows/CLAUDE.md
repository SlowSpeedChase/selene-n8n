# n8n Workflows Context

## Purpose

Six automated workflows for note processing: ingestion, LLM processing, pattern detection, Obsidian export, sentiment analysis, and connection network building. Each workflow operates independently on SQLite data.

## Tech Stack

- **n8n** - Workflow automation engine
- **better-sqlite3** - Node.js SQLite driver (embedded in n8n Function nodes)
- **Ollama** - Local LLM integration (mistral:7b model)
- **Webhook triggers** - For external integrations (Drafts, etc.)
- **Cron scheduling** - For periodic workflows

## Key Files

- **01-ingestion/** - Webhook-triggered note capture (365 lines JSON)
- **02-llm-processing/** - LLM concept extraction (293 lines JSON)
- **03-pattern-detection/** - Theme trend analysis (144 lines JSON)
- **04-obsidian-export/** - Markdown file generation (158 lines JSON)
- **05-sentiment-analysis/** - Emotional tone tracking (249 lines JSON)
- **06-connection-network/** - Note relationship mapping (169 lines JSON)

## Workflow Structure

Each workflow follows this pattern:
```
workflows/XX-name/
├── workflow.json          # Main workflow definition
├── README.md             # Quick start, setup instructions
├── docs/
│   ├── STATUS.md         # Test results and current status
│   ├── *-SETUP.md        # Detailed configuration guide
│   └── *-REFERENCE.md    # Technical reference
├── scripts/
│   ├── test-with-markers.sh    # Automated testing
│   └── cleanup-tests.sh         # Test data cleanup
└── tests/                # Test data or scripts
```

## Common Patterns

### Node Naming Convention
- Format: **"Verb + Object"** (e.g., "Parse Note Data", "Check for Duplicate", "Insert into Database")
- Use title case
- Be specific and descriptive

### Error Handling
- **Every node** must connect to error handler
- Error nodes log to console and optionally to database
- Critical failures should set status = 'failed'

### Database Operations
```javascript
// In n8n Function nodes using better-sqlite3
const db = require('better-sqlite3')('/data/selene.db');

// Always use parameterized queries (prevents SQL injection)
const stmt = db.prepare('INSERT INTO table (col1, col2) VALUES (?, ?)');
stmt.run(value1, value2);

// For test data, ALWAYS include test_run marker
const testRun = $input.item.json.test_run || null;
stmt.run(value1, value2, testRun);
```

### Test Data Isolation
- All test records marked with `test_run` column
- Format: `test-run-YYYYMMDD-HHMMSS`
- Production data has `test_run = NULL`
- Cleanup scripts filter by test_run value

### Status Tracking
- Use `status` column: 'pending', 'processing', 'completed', 'failed'
- Update timestamps: `created_at`, `processed_at`, `updated_at`
- Enable workflow resumption after failures

## Testing

### Running Tests
```bash
# Test specific workflow
cd workflows/01-ingestion
./scripts/test-with-markers.sh

# List all test runs
./scripts/cleanup-tests.sh --list

# Clean specific test run
./scripts/cleanup-tests.sh test-run-20251124-120000
```

### Test Status Tracking
Each workflow maintains `docs/STATUS.md` with:
- Current test pass/fail count (e.g., "6/7 tests passing")
- Last test run timestamp
- Known issues or failing tests
- Recent changes

## n8n-Specific Patterns

### Accessing Input Data
```javascript
// In Function nodes
const items = $input.all();           // All input items
const item = $input.item.json;        // Current item JSON
const previousNode = $('NodeName').item.json;  // Output from specific node
```

### Environment Variables
```javascript
// Access .env variables
const webhookUrl = $env.WEBHOOK_URL;
const ollamaHost = $env.OLLAMA_HOST;
```

### JSON Storage
```javascript
// Store arrays/objects as JSON TEXT
const concepts = ['concept1', 'concept2'];
stmt.run(JSON.stringify(concepts));

// Parse on retrieval
const row = db.prepare('SELECT concepts FROM table WHERE id = ?').get(id);
const conceptsArray = JSON.parse(row.concepts);
```

## Workflow Dependencies

**Data Flow:**
```
01-ingestion → raw_notes table
              ↓
02-llm-processing → processed_notes table
                   ↓
03-pattern-detection → detected_patterns table
05-sentiment-analysis → sentiment_history table
06-connection-network → network_analysis_history table
04-obsidian-export ← All tables (reads for export)
```

**Trigger Types:**
- 01-ingestion: Webhook (on-demand from Drafts)
- 02-06: Cron schedule or manual trigger

## Common Commands

```bash
# Import workflow to n8n
./scripts/import-workflows.sh

# Access n8n web interface
open http://localhost:5678

# View n8n logs
docker-compose logs -f n8n

# Restart n8n after changes
docker-compose restart n8n
```

## Do NOT

- **NEVER skip error handling** - every node needs error path
- **NEVER hardcode database paths** - use /data/selene.db (Docker mount)
- **NEVER use string concatenation for SQL** - always use parameterized queries
- **NEVER commit workflow.json without testing** - run tests first
- **NEVER modify production data during testing** - use test_run markers
- **NEVER delete nodes without checking dependencies** - other workflows may reference table structures

## Workflow Editing Best Practices

1. **Test in isolation** - Use test-with-markers.sh before committing
2. **Update STATUS.md** - Document test results after changes
3. **Maintain node naming** - Follow "Verb + Object" pattern
4. **Version control** - Commit workflow.json with descriptive message
5. **Document breaking changes** - Update README if API/schema changes

## Related Context

@workflows/01-ingestion/README.md
@workflows/02-llm-processing/README.md
@database/schema.sql
@README.md
