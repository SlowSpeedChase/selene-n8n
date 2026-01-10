# Test Data Management

## Overview

The ingestion workflow now supports automatic test data marking for easy cleanup. This prevents test data from polluting your production database and makes it simple to remove test entries programmatically.

## How It Works

### 1. Database Schema

The `raw_notes` table now includes a `test_run` column:

```sql
ALTER TABLE raw_notes ADD COLUMN test_run TEXT DEFAULT NULL;
CREATE INDEX idx_raw_notes_test_run ON raw_notes(test_run);
```

- **`test_run`**: Optional identifier for test runs (e.g., `test-run-20251030-120000`)
- **Default**: `NULL` for production data
- **Indexed**: For fast filtering and cleanup

### 2. Workflow Support

The workflow accepts an optional `test_run` parameter in the webhook payload:

```json
{
  "title": "My Note",
  "content": "Note content",
  "test_run": "test-run-20251030-120000"
}
```

This parameter is automatically stored in the database and can be used to identify and remove test data later.

## Running Tests with Markers

### Automated Test Script

Use the new test script that automatically marks all test data:

```bash
./workflows/01-ingestion/test-with-markers.sh
```

This script:
- Generates a unique test run ID (e.g., `test-run-20251030-120515`)
- Runs all test cases
- Marks all created entries with the test run ID
- Provides cleanup instructions at the end

**Example Output:**
```
==========================================
Selene Ingestion Workflow Test Suite
==========================================
Test Run ID: test-run-20251030-120515

Running Tests...

Test 1: Basic Note Ingestion... PASS
Test 2: Note with Tags... PASS
Test 3: Duplicate Detection... PASS
...

==========================================
Test Summary
==========================================
Total Tests: 6
Passed: 6
Failed: 0

Test Run ID: test-run-20251030-120515

To clean up test data:
  ./workflows/01-ingestion/cleanup-tests.sh test-run-20251030-120515
```

### Manual Testing

When manually testing via curl, add the `test_run` parameter:

```bash
curl -X POST http://localhost:5678/webhook/api/drafts \
  -H "Content-Type: application/json" \
  -d '{
    "title": "Test Note",
    "content": "This is a test",
    "test_run": "my-manual-test"
  }'
```

## Cleaning Up Test Data

### Cleanup Script Usage

The cleanup script provides several options:

#### List All Test Runs

```bash
./workflows/01-ingestion/cleanup-tests.sh --list
```

**Example Output:**
```
==========================================
Test Runs in Database
==========================================

test_run                     count  first_import         last_import
---------------------------  -----  -------------------  -------------------
test-run-20251030-120515     6      2025-10-30 12:05:20  2025-10-30 12:05:35
test-run-20251030-115030     4      2025-10-30 11:50:32  2025-10-30 11:50:45
my-manual-test               2      2025-10-30 10:30:15  2025-10-30 10:31:20
```

#### Delete Specific Test Run

```bash
./workflows/01-ingestion/cleanup-tests.sh test-run-20251030-120515
```

**Example Output:**
```
Found 6 records for test run: test-run-20251030-120515

Records to be deleted:
id  title              created_at
--  -----------------  -------------------
1   Test Note 1        2025-10-29 22:00:00
2   Tagged Note        2025-10-29 22:05:00
...

Delete these records? (yes/no): yes
Successfully deleted 6 records from test run: test-run-20251030-120515
```

#### Delete ALL Test Data

```bash
./workflows/01-ingestion/cleanup-tests.sh --all
```

**⚠️ Warning:** This deletes ALL entries where `test_run IS NOT NULL`

**Example Output:**
```
WARNING: This will delete ALL test data from the database!
Are you sure? (yes/no): yes
Deleting 15 test records...
Successfully deleted 15 test records.
```

## Direct SQL Queries

### View Test Data

```bash
# All test data
sqlite3 data/selene.db "SELECT * FROM raw_notes WHERE test_run IS NOT NULL;"

# Specific test run
sqlite3 data/selene.db "SELECT * FROM raw_notes WHERE test_run='test-run-20251030-120515';"

# Count by test run
sqlite3 data/selene.db "SELECT test_run, COUNT(*) FROM raw_notes GROUP BY test_run;"
```

### Manual Cleanup

```bash
# Delete specific test run
sqlite3 data/selene.db "DELETE FROM raw_notes WHERE test_run='test-run-20251030-120515';"

# Delete ALL test data
sqlite3 data/selene.db "DELETE FROM raw_notes WHERE test_run IS NOT NULL;"
```

## Best Practices

### For Automated Testing

1. **Always use `test-with-markers.sh`** instead of the old `test.sh`
2. **Clean up after each test run** to keep the database clean
3. **Use descriptive test run IDs** for manual tests (e.g., `feature-X-test`)

### For Development

1. **Mark all dev/test entries** with a `test_run` value
2. **Never use `test_run` for production data** - keep it `NULL`
3. **Regularly clean up old test data** using `cleanup-tests.sh --list`

### For CI/CD

Example test and cleanup pipeline:

```bash
# Run tests
./workflows/01-ingestion/test-with-markers.sh

# Capture exit code
TEST_RESULT=$?

# Always cleanup test data, even if tests failed
TEST_RUN_ID=$(./workflows/01-ingestion/cleanup-tests.sh --list | tail -1 | awk '{print $1}')
if [ -n "$TEST_RUN_ID" ]; then
    echo "yes" | ./workflows/01-ingestion/cleanup-tests.sh "$TEST_RUN_ID"
fi

# Exit with test result
exit $TEST_RESULT
```

## Migration Notes

### Updating Existing Database

If you have an existing database without the `test_run` column:

```bash
# Add column
sqlite3 data/selene.db "ALTER TABLE raw_notes ADD COLUMN test_run TEXT DEFAULT NULL;"

# Create index
sqlite3 data/selene.db "CREATE INDEX idx_raw_notes_test_run ON raw_notes(test_run);"

# Mark existing test data (optional)
sqlite3 data/selene.db "UPDATE raw_notes SET test_run='existing-test-data' WHERE <your-condition>;"
```

### Updating Workflow

The workflow needs to be re-imported to support the `test_run` parameter. See STATUS.md for details on the workflow update.

## Troubleshooting

### Test data not being marked

- Verify the workflow was re-imported after the update
- Check that you're using `test-with-markers.sh` or including `test_run` in your payload
- Verify the database schema includes the `test_run` column

### Cleanup script errors

- Ensure the database path is correct in the script
- Check that you have write permissions on the database
- Verify SQLite3 is installed and accessible

### Old test data still present

```bash
# List all test runs to find old data
./workflows/01-ingestion/cleanup-tests.sh --list

# Clean up specific old runs
./workflows/01-ingestion/cleanup-tests.sh test-run-OLD-ID
```
