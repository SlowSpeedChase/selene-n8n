# Claude Code Notes: Sentiment Analysis Workflow

## Database Access Pattern (CRITICAL)

### Problem: SQLite Community Node Requires Credentials

The initial workflow used `n8n-nodes-sqlite.sqlite` nodes which require:
- Credential configuration in n8n UI
- Manual setup of database path
- Credential IDs that may not transfer between instances

### Solution: Use better-sqlite3 Directly

Based on the ingestion workflow pattern, we converted all database operations to use `better-sqlite3` in Function nodes.

**Why this works:**
1. **No credentials needed** - Direct file access via Docker volume mount
2. **Consistent with other workflows** - Matches ingestion pattern
3. **More portable** - Workflow works immediately after import
4. **Environment variable support** - Uses `NODE_FUNCTION_ALLOW_EXTERNAL=better-sqlite3`

**Example pattern:**

```javascript
const Database = require('better-sqlite3');

try {
  const db = new Database('/selene/data/selene.db', { readonly: true });

  const query = `SELECT ... FROM ... WHERE ...`;
  const stmt = db.prepare(query);
  const result = stmt.get(); // or .all() for multiple rows

  db.close();

  return { json: result || { id: null } };
} catch (error) {
  console.error('SQLite Error:', error);
  return { json: { id: null, error: error.message } };
}
```

**Key points:**
- Always use `{ readonly: true }` for SELECT queries
- Omit readonly for INSERT/UPDATE/DELETE
- Always close the database connection
- Use parameterized queries: `stmt.run(param1, param2)`
- Handle errors gracefully

---

## Node Type: IF vs Switch (CRITICAL)

### Problem: Switch Node with "exists" Operation Fails

The original workflow used a Switch node to check if a note exists:

```json
{
  "type": "n8n-nodes-base.switch",
  "conditions": {
    "number": [
      {
        "value1": "={{ $json.id }}",
        "operation": "exists"
      }
    ]
  }
}
```

**Issues found in ingestion workflow:**
- "exists" operation unreliable with null/undefined values
- Switch node doesn't handle empty results well
- Can cause workflow execution to hang

### Solution: Use IF Node with Boolean Comparison

Based on the ingestion workflow fix, we use an IF node:

```json
{
  "type": "n8n-nodes-base.if",
  "conditions": {
    "boolean": [
      {
        "value1": "={{ $json.id != null && $json.id != undefined }}",
        "value2": true
      }
    ]
  }
}
```

**Why this works:**
1. **Explicit null/undefined check** - Handles both JavaScript null values
2. **Boolean comparison** - Clear true/false evaluation
3. **More reliable** - IF node designed for binary decisions
4. **Consistent** - Matches proven pattern from ingestion workflow

**Pattern to follow:**
- **IF node**: For binary decisions (has note? is duplicate? is new?)
- **Switch node**: For multi-way routing (by status, by type, etc.)

---

## Docker Environment Configuration

### Required Environment Variables

In `docker-compose.yml`:

```yaml
environment:
  # Allow better-sqlite3 in Function nodes
  - NODE_FUNCTION_ALLOW_EXTERNAL=better-sqlite3
  - NODE_PATH=/home/node/.n8n/node_modules

  # Database path (used in documentation)
  - SELENE_DB_PATH=/selene/data/selene.db

  # Ollama configuration
  - OLLAMA_BASE_URL=http://localhost:11434
  - OLLAMA_MODEL=mistral:7b
```

### Volume Mounts

```yaml
volumes:
  # Database access
  - ${SELENE_DATA_PATH:-./data}:/selene/data:rw
```

**Key insights:**
- Database is at `./data/selene.db` on host
- Mounted to `/selene/data/selene.db` in container
- Must have read/write access (`:rw`)
- All workflows use same mount point for consistency

---

## Ollama API Access from Docker

### Host Access Pattern

Use `host.docker.internal` instead of `localhost`:

```json
{
  "url": "http://host.docker.internal:11434/api/generate"
}
```

**Why:**
- Docker containers can't access `localhost` (that's the container itself)
- `host.docker.internal` resolves to host machine
- Requires `extra_hosts` configuration in docker-compose.yml

```yaml
extra_hosts:
  - "host.docker.internal:host-gateway"
```

---

## Workflow Import Best Practices

### Nodes That Need Updating

When creating workflows, these nodes need special attention:

1. **SQLite nodes** → Convert to Function nodes with better-sqlite3
2. **Switch nodes** for existence checks → Convert to IF nodes with null checks
3. **HTTP requests to localhost** → Use host.docker.internal
4. **Credential references** → Remove, use direct access patterns

### Testing After Import

```bash
# 1. Check workflow appears in n8n
open http://localhost:5678

# 2. Activate the workflow

# 3. Test database access
docker-compose logs n8n --tail=20 -f

# 4. Verify processing
sqlite3 data/selene.db "SELECT COUNT(*) FROM processed_notes WHERE sentiment_analyzed = 0;"
```

---

## Common Patterns Learned

### 1. Query for Next Item to Process

```javascript
const Database = require('better-sqlite3');
const db = new Database('/selene/data/selene.db', { readonly: true });

const query = `SELECT * FROM table WHERE processed = 0 ORDER BY created_at DESC LIMIT 1`;
const stmt = db.prepare(query);
const result = stmt.get();

db.close();
return { json: result || { id: null } };
```

### 2. Update and Insert in Transaction

```javascript
const Database = require('better-sqlite3');
const db = new Database('/selene/data/selene.db');

// No explicit transaction needed for two statements
const updateStmt = db.prepare('UPDATE table SET field = ? WHERE id = ?');
updateStmt.run(value, id);

const insertStmt = db.prepare('INSERT INTO history (...) VALUES (...)');
insertStmt.run(value1, value2, value3);

db.close();
return { json: { success: true } };
```

### 3. Check for Existence Before Processing

```javascript
// In query function
return { json: result || { id: null } };

// In IF node
{
  "value1": "={{ $json.id != null && $json.id != undefined }}",
  "value2": true
}
```

### 4. Parse JSON with Fallback

```javascript
let data = defaultValue;

try {
  const parsed = JSON.parse(response);
  data = { ...data, ...parsed };
} catch (e) {
  // Fallback parsing with regex
  if (/pattern/i.test(response)) {
    data.field = true;
  }
}

return { json: data };
```

---

## Lessons from Debugging

### Issue: Workflow Imported But Not Processing

**Symptoms:**
- Workflow shows as active
- No errors in logs
- Database counts don't change

**Root causes found:**
1. SQLite community node needs credentials (not configured)
2. Switch node fails silently on null values
3. Localhost instead of host.docker.internal for Ollama

**Solution:**
- Use better-sqlite3 (no credentials)
- Use IF nodes with explicit null checks
- Use host.docker.internal for host services

### Issue: Module Not Found Error

**Symptom:** `Error: Cannot find module 'better-sqlite3'`

**Cause:** Missing environment variable

**Solution:**
```yaml
environment:
  - NODE_FUNCTION_ALLOW_EXTERNAL=better-sqlite3
```

Then restart: `docker-compose restart n8n`

### Issue: Database Permission Denied

**Symptom:** `EACCES: permission denied, open '/selene/data/selene.db'`

**Solution:**
```bash
chmod 644 data/selene.db
# Or if directory issues:
chmod 755 data/
```

---

## Architecture Decisions

### Why Cron Trigger Instead of Webhook?

Sentiment analysis uses a **cron trigger** (every 45 seconds) rather than a webhook because:

1. **Batch processing** - One note at a time, prevents overwhelming Ollama
2. **Rate limiting** - Natural rate limit from interval
3. **No external dependency** - Doesn't rely on upstream workflows triggering it
4. **Queue-based** - Processes backlog automatically
5. **Resilient** - If Ollama is down, next cycle will retry

### Why LIMIT 1 in Query?

```sql
SELECT ... WHERE sentiment_analyzed = 0 ORDER BY processed_at DESC LIMIT 1
```

**Reasoning:**
- Process one note per execution
- Prevents timeout on large batches
- Ollama processing takes 5-10 seconds per note
- Cron runs every 45 seconds = ~80 notes/hour max
- FIFO queue processing (oldest first with DESC)

### Why Store Full JSON and Individual Fields?

```sql
sentiment_data TEXT,          -- Full JSON object
overall_sentiment TEXT,        -- Extracted field
sentiment_score REAL,          -- Extracted field
emotional_tone TEXT,           -- Extracted field
energy_level TEXT              -- Extracted field
```

**Reasoning:**
1. **JSON field** - Complete data for future analysis
2. **Individual fields** - Fast queries without JSON parsing
3. **Backwards compatible** - Can add new JSON fields without schema changes
4. **Obsidian export** - Individual fields easy to use in frontmatter

---

## Future Improvements

### Multi-Model Comparison

Run 2-3 models in parallel:
```
Ollama: mistral:7b → Parse Results A
Ollama: llama2:7b  → Parse Results B
Ollama: mixtral    → Parse Results C
→ Aggregate Results (highest confidence wins)
```

### Adaptive Retry Logic

If analysis_confidence < 0.5:
- Retry with different temperature
- Use larger model
- Apply more structured prompting

### Batch Processing Mode

Add optional batch mode:
- Query for multiple notes (LIMIT 10)
- Process in parallel
- Faster for large backlogs

---

## Testing Checklist

Before deploying workflow changes:

- [ ] Test with database that has unanalyzed notes
- [ ] Test with empty database (no notes to process)
- [ ] Test IF node handles null values correctly
- [ ] Verify Ollama connection works
- [ ] Check sentiment_history inserts correctly
- [ ] Run automated test suite
- [ ] Verify ADHD markers detect correctly
- [ ] Check analysis_confidence > 0.7 average

---

## Key Files

| File | Purpose |
|------|---------|
| `workflow.json` | Main workflow (uses better-sqlite3) |
| `SETUP.md` | Import and activation guide |
| `README.md` | Full workflow documentation |
| `tests/TESTING.md` | Comprehensive testing guide |
| `tests/test-notes.json` | 8 ADHD pattern test cases |
| `tests/run-tests.sh` | Automated test runner |
| `archive/workflow-v1.json` | Original version (for reference) |

---

## Summary for Future Claude

When working on n8n workflows for Selene:

1. **Always use better-sqlite3** in Function nodes, never SQLite community nodes
2. **Always use IF nodes** for null checks, not Switch nodes with "exists"
3. **Always use host.docker.internal** for host services, not localhost
4. **Always close database connections** after queries
5. **Always handle null/undefined** explicitly in conditionals
6. **Always use parameterized queries** to prevent SQL injection
7. **Always test with empty results** (no notes found case)

These patterns are proven in both ingestion and sentiment workflows.

---

## Codebase Analysis Instructions

When analyzing the entire codebase or exploring project structure:

**Ignore test files and directories:**
- Skip files in `tests/` or `test/` directories
- Skip files ending with `.test.js`, `.test.ts`, `.spec.js`, `.spec.ts`
- Skip test configuration files like `jest.config.js`, `vitest.config.js`
- Focus on production code, workflows, and configuration files

**Why:**
- Tests are not part of the runtime behavior
- They add noise to codebase analysis
- Production code and workflows are what matters for understanding Selene's functionality

**When tests ARE relevant:**
- User explicitly asks about tests
- Debugging test failures
- Writing new tests
- Understanding test patterns for a specific feature
