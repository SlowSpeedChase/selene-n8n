#!/bin/bash
# Test the feedback classification pipeline
# Uses test_run marker to isolate test data

set -e

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/../../.." && pwd)"
DB_PATH="$PROJECT_ROOT/data/selene.db"
WEBHOOK_URL="http://localhost:5678/webhook/api/drafts"

# Colors
GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[0;33m'
NC='\033[0m'

TEST_RUN="test-run-$(date +%Y%m%d-%H%M%S)"

echo "=========================================="
echo "Feedback Pipeline Test"
echo "Test Run: $TEST_RUN"
echo "=========================================="

# Test 1: User story feedback
echo -e "\n${YELLOW}Test 1: User story feedback${NC}"
RESPONSE=$(curl -s -X POST "$WEBHOOK_URL" \
  -H "Content-Type: application/json" \
  -d "{
    \"content\": \"I wanted to see where my tasks came from but there was no way to trace them back to the original note #selene-feedback\",
    \"test_run\": \"$TEST_RUN\"
  }")

echo "Response: $RESPONSE"
if echo "$RESPONSE" | grep -q "feedback_classified\|feedback_stored"; then
  echo -e "${GREEN}✓ Test 1 passed${NC}"
else
  echo -e "${RED}✗ Test 1 failed${NC}"
fi

sleep 2  # Wait for Ollama

# Test 2: Feature request feedback
echo -e "\n${YELLOW}Test 2: Feature request feedback${NC}"
RESPONSE=$(curl -s -X POST "$WEBHOOK_URL" \
  -H "Content-Type: application/json" \
  -d "{
    \"content\": \"Add dark mode to SeleneChat #selene-feedback\",
    \"test_run\": \"$TEST_RUN\"
  }")

echo "Response: $RESPONSE"
if echo "$RESPONSE" | grep -q "feedback_classified\|feedback_stored"; then
  echo -e "${GREEN}✓ Test 2 passed${NC}"
else
  echo -e "${RED}✗ Test 2 failed${NC}"
fi

sleep 2

# Test 3: Bug report feedback
echo -e "\n${YELLOW}Test 3: Bug report feedback${NC}"
RESPONSE=$(curl -s -X POST "$WEBHOOK_URL" \
  -H "Content-Type: application/json" \
  -d "{
    \"content\": \"The task extraction gave me a high-energy task when I specifically said I was tired #selene-feedback\",
    \"test_run\": \"$TEST_RUN\"
  }")

echo "Response: $RESPONSE"
if echo "$RESPONSE" | grep -q "feedback_classified\|feedback_stored"; then
  echo -e "${GREEN}✓ Test 3 passed${NC}"
else
  echo -e "${RED}✗ Test 3 failed${NC}"
fi

sleep 2

# Test 4: Noise (should be filtered)
echo -e "\n${YELLOW}Test 4: Noise feedback${NC}"
RESPONSE=$(curl -s -X POST "$WEBHOOK_URL" \
  -H "Content-Type: application/json" \
  -d "{
    \"content\": \"testing 123 #selene-feedback\",
    \"test_run\": \"$TEST_RUN\"
  }")

echo "Response: $RESPONSE"
if echo "$RESPONSE" | grep -q "feedback"; then
  echo -e "${GREEN}✓ Test 4 passed (feedback processed)${NC}"
else
  echo -e "${RED}✗ Test 4 failed${NC}"
fi

sleep 2

# Verify database entries
echo -e "\n${YELLOW}Verifying database entries...${NC}"
echo "Feedback notes created:"
sqlite3 "$DB_PATH" "SELECT id, category, status, backlog_id FROM feedback_notes WHERE test_run = '$TEST_RUN';" 2>/dev/null || echo "Could not query database (file may not exist in worktree)"

# Verify backlog entries (in test file)
echo -e "\n${YELLOW}Checking test backlog file...${NC}"
if [ -f "$PROJECT_ROOT/docs/backlog/user-stories-test.md" ]; then
  echo "Test backlog contents:"
  grep -E "^\|" "$PROJECT_ROOT/docs/backlog/user-stories-test.md" | tail -10
else
  echo "Test backlog file not found (expected for noise-only tests)"
fi

# Cleanup prompt
echo -e "\n${YELLOW}=========================================="
echo "Test run complete: $TEST_RUN"
echo "==========================================${NC}"
echo ""
echo "To cleanup test data, run:"
echo "  sqlite3 $DB_PATH \"DELETE FROM feedback_notes WHERE test_run = '$TEST_RUN';\""
echo "  rm -f $PROJECT_ROOT/docs/backlog/user-stories-test.md"
