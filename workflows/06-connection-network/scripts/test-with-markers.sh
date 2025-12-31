#!/bin/bash

# Connection Network Workflow Test Script with Test Markers
# Tests network analysis functionality with marked test data
#
# Prerequisites:
# - Docker n8n container running
# - Processed notes exist in database (with concepts/themes)
# - Workflow imported and active in n8n

set -e

# Colors for output
GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Configuration
DB_PATH="data/selene.db"
WORKFLOW_NAME="06-Connection-Network"

# Generate unique test run ID
TEST_RUN_ID="test-run-$(date +%Y%m%d-%H%M%S)"

# Test counters
PASSED=0
FAILED=0
TOTAL=0
WARNINGS=0

echo "=========================================="
echo "Connection Network Workflow Test Suite"
echo "=========================================="
echo -e "${BLUE}Test Run ID: ${TEST_RUN_ID}${NC}"
echo ""

# Helper function to log results
log_pass() {
    PASSED=$((PASSED + 1))
    TOTAL=$((TOTAL + 1))
    echo -e "${GREEN}PASS${NC} - $1"
}

log_fail() {
    FAILED=$((FAILED + 1))
    TOTAL=$((TOTAL + 1))
    echo -e "${RED}FAIL${NC} - $1"
    if [ -n "$2" ]; then
        echo "       $2"
    fi
}

log_warn() {
    WARNINGS=$((WARNINGS + 1))
    echo -e "${YELLOW}WARN${NC} - $1"
}

log_info() {
    echo -e "${BLUE}INFO${NC} - $1"
}

# Check prerequisites
echo -e "${YELLOW}Checking Prerequisites...${NC}"
echo ""

# Test 1: Check database exists
TOTAL=$((TOTAL + 1))
echo -n "Test 1: Database exists... "
if [ -f "$DB_PATH" ]; then
    log_pass "Database found at $DB_PATH"
else
    log_fail "Database not found at $DB_PATH"
    echo "Cannot continue without database."
    exit 1
fi

# Test 2: Check for processed notes with concepts
TOTAL=$((TOTAL + 1))
echo -n "Test 2: Processed notes exist... "
PROCESSED_COUNT=$(sqlite3 "$DB_PATH" "SELECT COUNT(*) FROM processed_notes WHERE concepts IS NOT NULL AND concepts != '[]';" 2>/dev/null || echo "0")
if [ "$PROCESSED_COUNT" -ge 5 ]; then
    log_pass "Found $PROCESSED_COUNT processed notes with concepts"
else
    log_warn "Only $PROCESSED_COUNT processed notes found (need 5+ for meaningful network)"
fi

# Test 3: Check note_connections table exists
TOTAL=$((TOTAL + 1))
echo -n "Test 3: note_connections table exists... "
TABLE_EXISTS=$(sqlite3 "$DB_PATH" "SELECT name FROM sqlite_master WHERE type='table' AND name='note_connections';" 2>/dev/null || echo "")
if [ -n "$TABLE_EXISTS" ]; then
    log_pass "note_connections table exists"
else
    log_fail "note_connections table does NOT exist"
    echo ""
    echo -e "${RED}CRITICAL ISSUE: The workflow requires 'note_connections' table which does not exist.${NC}"
    echo "The workflow will FAIL at the 'Store Connection' node."
    echo ""
    echo "The database only has 'network_analysis_history' table with different schema."
    echo "Either the table needs to be created or the workflow needs to be modified."
    echo ""
    echo "Suggested fix: Add to database/schema.sql:"
    echo ""
    echo "CREATE TABLE note_connections ("
    echo "    id INTEGER PRIMARY KEY AUTOINCREMENT,"
    echo "    source_note_id INTEGER NOT NULL,"
    echo "    target_note_id INTEGER NOT NULL,"
    echo "    connection_strength REAL,"
    echo "    connection_type TEXT,"
    echo "    shared_concepts TEXT,"
    echo "    shared_themes TEXT,"
    echo "    concept_overlap_score REAL,"
    echo "    theme_overlap_score REAL,"
    echo "    temporal_score REAL,"
    echo "    days_between INTEGER,"
    echo "    discovered_at DATETIME DEFAULT CURRENT_TIMESTAMP,"
    echo "    is_active INTEGER DEFAULT 1,"
    echo "    UNIQUE(source_note_id, target_note_id),"
    echo "    FOREIGN KEY (source_note_id) REFERENCES raw_notes(id),"
    echo "    FOREIGN KEY (target_note_id) REFERENCES raw_notes(id)"
    echo ");"
    echo ""
fi

# Test 4: Check network_analysis_history table exists
TOTAL=$((TOTAL + 1))
echo -n "Test 4: network_analysis_history table exists... "
NAH_EXISTS=$(sqlite3 "$DB_PATH" "SELECT name FROM sqlite_master WHERE type='table' AND name='network_analysis_history';" 2>/dev/null || echo "")
if [ -n "$NAH_EXISTS" ]; then
    log_pass "network_analysis_history table exists"
else
    log_fail "network_analysis_history table does NOT exist"
fi

# Test 5: Check n8n container is running
TOTAL=$((TOTAL + 1))
echo -n "Test 5: n8n container running... "
if docker ps --format '{{.Names}}' | grep -q "^selene-n8n$"; then
    log_pass "selene-n8n container is running"
else
    log_fail "selene-n8n container is not running"
    echo "Start with: docker-compose up -d"
fi

# Test 6: Sample data inspection
echo ""
echo -e "${YELLOW}Data Inspection...${NC}"
echo ""

log_info "Sample processed notes with concepts:"
sqlite3 -header -column "$DB_PATH" "
    SELECT
        pn.id,
        rn.title,
        pn.primary_theme,
        LENGTH(pn.concepts) as concepts_len
    FROM processed_notes pn
    JOIN raw_notes rn ON pn.raw_note_id = rn.id
    WHERE rn.test_run IS NULL
    AND pn.concepts IS NOT NULL
    LIMIT 5;
" 2>/dev/null || echo "Error querying processed notes"

echo ""

# Test 7: Check existing network analysis history
TOTAL=$((TOTAL + 1))
echo -n "Test 7: Existing network analyses... "
ANALYSIS_COUNT=$(sqlite3 "$DB_PATH" "SELECT COUNT(*) FROM network_analysis_history;" 2>/dev/null || echo "0")
if [ "$ANALYSIS_COUNT" -gt 0 ]; then
    log_pass "Found $ANALYSIS_COUNT previous network analyses"
    echo ""
    log_info "Most recent analysis:"
    sqlite3 -header -column "$DB_PATH" "
        SELECT
            analysis_id,
            total_notes,
            total_connections,
            ROUND(avg_connection_strength, 3) as avg_strength,
            analyzed_at
        FROM network_analysis_history
        ORDER BY analyzed_at DESC
        LIMIT 1;
    " 2>/dev/null || echo "Error querying history"
else
    log_pass "No previous analyses (clean state)"
fi

echo ""
echo "=========================================="
echo "Test Summary"
echo "=========================================="
echo -e "Total Tests: $TOTAL"
echo -e "${GREEN}Passed: $PASSED${NC}"
echo -e "${RED}Failed: $FAILED${NC}"
echo -e "${YELLOW}Warnings: $WARNINGS${NC}"
echo ""

# Workflow execution note
echo -e "${YELLOW}Note about workflow execution:${NC}"
echo ""
echo "This workflow runs on a cron schedule (every 6 hours)."
echo "It cannot be triggered manually via webhook."
echo ""
echo "To test the workflow logic:"
echo "1. Activate the workflow in n8n UI"
echo "2. Wait for next cron trigger, OR"
echo "3. Use n8n UI to manually execute the workflow"
echo ""

if [ -z "$TABLE_EXISTS" ]; then
    echo -e "${RED}WARNING: Workflow will FAIL without note_connections table!${NC}"
    echo "See above for schema to create."
    echo ""
fi

echo -e "${BLUE}Test Run ID: ${TEST_RUN_ID}${NC}"
echo ""

# Exit with error if critical tests failed
if [ "$FAILED" -gt 0 ]; then
    exit 1
else
    exit 0
fi
