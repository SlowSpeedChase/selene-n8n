# Architecture Decisions Log

This file documents important technical decisions made during development.

---

## ADR-001: Use better-sqlite3 in Function Nodes

**Date:** 2025-10-30
**Status:** Accepted
**Context:** Need to access SQLite database from n8n workflows

**Decision:** Use better-sqlite3 npm package with Function nodes instead of n8n's SQLite community nodes

**Reasoning:**
- More control over queries and error handling
- Can use transactions and complex operations
- Better performance for direct access
- More flexible than visual node configuration

**Implementation:**
- Install better-sqlite3 in `/home/node/.n8n/node_modules/`
- Set `NODE_FUNCTION_ALLOW_EXTERNAL=better-sqlite3`
- Set `NODE_PATH=/home/node/.n8n/node_modules`
- Use `require('better-sqlite3')` in Function nodes

**Consequences:**
- ✅ More flexibility in database operations
- ✅ Can use standard SQL without node limitations
- ⚠️ Requires careful module path management
- ⚠️ Workflows less visual (code in Function nodes)

---

## ADR-002: Test Data Marking System

**Date:** 2025-10-30
**Status:** Accepted
**Context:** Need to isolate test data from production data

**Decision:** Add `test_run` column to all tables, mark test data with unique IDs

**Implementation:**
```sql
ALTER TABLE raw_notes ADD COLUMN test_run TEXT DEFAULT NULL;
CREATE INDEX idx_raw_notes_test_run ON raw_notes(test_run);
```

**Reasoning:**
- Prevents test pollution of production database
- Enables programmatic cleanup
- Maintains referential integrity
- Keeps test and production in same database

**Consequences:**
- ✅ Easy test data identification
- ✅ Safe bulk cleanup operations
- ✅ Test run tracking and history
- ⚠️ Must remember to include test_run in test payloads
- ⚠️ Schema migration needed for existing databases

---

## ADR-003: Use IF Nodes Instead of Switch with notExists

**Date:** 2025-10-30
**Status:** Accepted
**Context:** Switch node with `notExists` operation fails when value is `null`

**Decision:** Use IF nodes with explicit null checks: `$json.id == null || $json.id == undefined`

**Reasoning:**
- n8n's `notExists` doesn't treat `null` as non-existent
- JavaScript null checking is more reliable
- IF nodes provide clearer logic

**Consequences:**
- ✅ Reliable null/undefined detection
- ✅ More explicit condition logic
- ⚠️ Must use correct comparison operators (==, not ===)

---

## ADR-004: Use responseMode: "onReceived" for Webhooks

**Date:** 2025-10-30
**Status:** Accepted
**Context:** Ingestion webhook needs to respond quickly

**Decision:** Use `responseMode: "onReceived"` for ingestion webhook

**Reasoning:**
- Immediate response to caller
- Workflow runs asynchronously
- Better user experience for Drafts app
- Prevents timeout issues

**Consequences:**
- ✅ Fast webhook response
- ✅ No timeout issues
- ⚠️ Can't return workflow results to caller
- ⚠️ Must check logs/database for errors

**Alternative Considered:** `responseMode: "lastNode"`
- Would wait for workflow completion
- Could return actual results
- Risk of timeouts
- Rejected for ingestion, may use for other workflows

---

## ADR-005: Docker Container Architecture

**Date:** 2025-10-29
**Status:** Accepted
**Context:** Need containerized n8n with custom dependencies

**Decision:** Custom Docker image based on n8n:latest with better-sqlite3 and SQLite tools

**Implementation:**
```dockerfile
FROM n8nio/n8n:latest
RUN apk add --no-cache python3 make g++ sqlite sqlite-dev
RUN npm install -g better-sqlite3@11.0.0
```

**Reasoning:**
- Reproducible environment
- Custom dependencies included
- Easy deployment and scaling
- Isolated from host system

**Consequences:**
- ✅ Consistent environment
- ✅ Easy to rebuild/redeploy
- ⚠️ Requires Docker knowledge
- ⚠️ Must rebuild for dependency changes

---

## ADR-006: Ollama Integration via host.docker.internal

**Date:** 2025-10-29
**Status:** Accepted
**Context:** Need to access Ollama running on host from n8n container

**Decision:** Use `host.docker.internal` hostname with extra_hosts mapping

**Implementation:**
```yaml
extra_hosts:
  - "host.docker.internal:host-gateway"
```

**Reasoning:**
- Standard Docker pattern for host access
- Works on macOS and Linux
- No network mode changes needed
- Ollama typically runs on host

**Consequences:**
- ✅ Clean separation of concerns
- ✅ Ollama can run independently
- ⚠️ Requires extra_hosts configuration
- ⚠️ URL must be `http://host.docker.internal:11434`

---

## ADR-007: Organized Folder Structure

**Date:** 2025-10-30
**Status:** Accepted
**Context:** Workflow directory becoming cluttered

**Decision:** Organize into `docs/`, `scripts/`, `archive/` subdirectories

**Structure:**
```
workflow/
├── workflow.json
├── README.md
├── INDEX.md
├── docs/         # Documentation
├── scripts/      # Executable utilities
└── archive/      # Deprecated files
```

**Reasoning:**
- Clear separation of concerns
- Easy navigation
- Professional organization
- Scalable pattern

**Consequences:**
- ✅ Clean root directory
- ✅ Easy to find files
- ✅ Clear file purposes
- ⚠️ Must update paths in documentation
- ⚠️ Must use relative paths in scripts

---

## ADR-008: SQLite as Primary Database

**Date:** 2025-10-29
**Status:** Accepted
**Context:** Need database for note storage

**Decision:** Use SQLite instead of PostgreSQL or MySQL

**Reasoning:**
- Simple deployment (file-based)
- No separate database server needed
- Good performance for single-user
- Easy backup (copy file)
- Perfect for local/personal use

**Consequences:**
- ✅ Simple setup and maintenance
- ✅ Easy backups
- ✅ Good performance for use case
- ⚠️ Not suitable for multi-user/concurrent writes
- ⚠️ Limited by file system

**Alternatives Considered:**
- PostgreSQL: Overkill for single-user
- MySQL: Unnecessary complexity
- JSON files: Poor query performance

---

## ADR-009: Environment Variable Configuration

**Date:** 2025-10-29
**Status:** Accepted
**Context:** Need configurable paths and settings

**Decision:** Use environment variables in docker-compose.yml with defaults

**Pattern:**
```yaml
- OLLAMA_MODEL=${OLLAMA_MODEL:-mistral:7b}
- SELENE_DB_PATH=/selene/data/selene.db
```

**Reasoning:**
- Flexible configuration
- Can override via .env file
- Clear defaults
- Standard Docker pattern

**Consequences:**
- ✅ Easy to reconfigure
- ✅ Clear defaults
- ✅ Can use .env file
- ⚠️ Must document all variables

---

## ADR-010: Duplicate Detection via Content Hash

**Date:** 2025-10-29
**Status:** Accepted
**Context:** Need to prevent duplicate note imports

**Decision:** Generate FNV-1a hash of content, use as unique constraint

**Implementation:**
```javascript
function simpleHash(str) {
  let hash = 2166136261;
  for (let i = 0; i < str.length; i++) {
    hash ^= str.charCodeAt(i);
    hash += (hash << 1) + (hash << 4) + (hash << 7) + (hash << 8) + (hash << 24);
  }
  return (hash >>> 0).toString(16);
}
```

**Reasoning:**
- Fast, non-cryptographic hash
- Works in n8n Function nodes (no crypto module)
- Good distribution for collision avoidance
- Deterministic (same content = same hash)

**Consequences:**
- ✅ Fast duplicate detection
- ✅ No crypto module dependency
- ✅ Database-level uniqueness constraint
- ⚠️ Extremely unlikely collision (acceptable risk)
- ⚠️ Hash changes if content changes (feature, not bug)

---

## Future Decisions Needed

### For Workflow 02 (LLM Processing):
1. **Batch vs Individual Processing**
   - Process one note at a time, or batch?
   - Trade-offs: Speed vs error isolation

2. **LLM Error Handling**
   - Retry logic?
   - Fallback strategies?
   - Store error info?

3. **processed_notes Schema**
   - What fields to store?
   - How to structure LLM output?
   - Relationships to raw_notes?

4. **Processing Triggers**
   - Automatic on ingest?
   - Manual trigger?
   - Scheduled batch?

---

## Rejected Alternatives

### Use n8n SQLite Community Node
**Rejected:** 2025-10-30
**Reason:** Less flexible than better-sqlite3 in Function nodes
**Details:** Community node requires credential configuration and is less flexible for complex queries

### Store in PostgreSQL
**Rejected:** 2025-10-29
**Reason:** Overkill for single-user personal note system
**Details:** Would add deployment complexity without benefit

### Separate test database
**Rejected:** 2025-10-30
**Reason:** test_run column provides better isolation
**Details:** Separate database would complicate deployment and testing

---

## Decision Guidelines

When making new decisions:

1. **Document immediately** - Don't wait
2. **Explain reasoning** - Future you will thank you
3. **Note consequences** - Both positive and negative
4. **Consider alternatives** - Show you thought it through
5. **Update this file** - Keep it current

**Template:**
```markdown
## ADR-XXX: Decision Title

**Date:** YYYY-MM-DD
**Status:** Accepted/Rejected/Superseded
**Context:** Why we needed to make this decision

**Decision:** What we decided to do

**Reasoning:**
- Why this approach
- Benefits expected
- Trade-offs considered

**Consequences:**
- ✅ Positive outcomes
- ⚠️ Negative/tradeoff outcomes

**Alternatives Considered:**
- Other option and why rejected
```
