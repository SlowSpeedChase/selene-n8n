# Test Environment Guide

**Current Approach:** Use `test_run` markers in the production database with cleanup scripts.

---

## Quick Start

### 1. Run Tests with Markers

```bash
# Generate unique test ID
TEST_RUN="test-run-$(date +%Y%m%d-%H%M%S)"

# Submit test note
curl -X POST http://localhost:5678/webhook/api/drafts \
  -H "Content-Type: application/json" \
  -d "{
    \"title\": \"Test Note\",
    \"content\": \"Test content\",
    \"test_run\": \"$TEST_RUN\"
  }"
```

### 2. Verify Test Data

```bash
sqlite3 data/selene.db "SELECT * FROM raw_notes WHERE test_run = '$TEST_RUN';"
```

### 3. Cleanup Test Data

```bash
# List test runs
./scripts/cleanup-tests.sh --list

# Cleanup specific test run
./scripts/cleanup-tests.sh "$TEST_RUN"
```

---

## How It Works

| Data Type | `test_run` Column | Safe to Delete |
|-----------|-------------------|----------------|
| Production | `NULL` | Never auto-deleted |
| Test | `'test-run-...'` | Yes, via cleanup script |

**Benefits:**
- No separate test database needed
- Zero risk of deleting production data
- Programmatic cleanup
- Test in real environment

---

## Workflow-Specific Testing

Each workflow has a test script:

```bash
./workflows/01-ingestion/scripts/test-with-markers.sh
./workflows/02-llm-processing/scripts/test-with-markers.sh
# etc.
```

These scripts:
1. Generate unique test_run ID
2. Submit test data
3. Verify processing
4. Optionally cleanup

---

## Verification

### Check for Stale Test Data

```bash
# Count test notes in database
sqlite3 data/selene.db "SELECT COUNT(*) FROM raw_notes WHERE test_run IS NOT NULL;"

# Should be 0 after cleanup
```

### Verify Production is Clean

```bash
# Production notes have NULL test_run
sqlite3 data/selene.db "SELECT COUNT(*) FROM raw_notes WHERE test_run IS NULL;"
```

---

## Best Practices

1. **Always use test_run marker** for test data
2. **Clean up after testing** with cleanup-tests.sh
3. **Use workflow test scripts** when available
4. **Never manually delete** rows without checking test_run

---

## Related

- `@.claude/OPERATIONS.md` - Full testing procedures
- `@scripts/cleanup-tests.sh` - Test cleanup utility
- `@workflows/*/scripts/test-with-markers.sh` - Per-workflow tests
