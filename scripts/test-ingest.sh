#!/bin/bash
# Submit a test note to the test environment

set -e

# Colors
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

# Default values
TEST_RUN="${1:-manual_test_$(date +%s)}"
TITLE="${2:-Test Note $(date +"%Y-%m-%d %H:%M:%S")}"
CONTENT="${3:-This is a test note submitted to the test environment at $(date). Testing the complete workflow from ingestion to Obsidian export.}"

echo -e "${BLUE}=================================================="
echo "  Selene Test Note Submission"
echo -e "==================================================${NC}"
echo ""
echo -e "${YELLOW}Test Parameters:${NC}"
echo "  Test Run: $TEST_RUN"
echo "  Title: $TITLE"
echo "  Content: ${CONTENT:0:50}..."
echo ""

# Submit to TEST webhook
echo -e "${YELLOW}Submitting to test environment...${NC}"
RESPONSE=$(curl -s -X POST http://localhost:5678/webhook/api/test/drafts \
  -H "Content-Type: application/json" \
  -d "{
    \"title\": \"$TITLE\",
    \"content\": \"$CONTENT\",
    \"timestamp\": \"$(date -u +"%Y-%m-%dT%H:%M:%SZ")\",
    \"test_run\": \"$TEST_RUN\",
    \"source_type\": \"test_webhook\"
  }")

echo ""
echo -e "${GREEN}Response from webhook:${NC}"
echo "$RESPONSE" | python3 -m json.tool 2>/dev/null || echo "$RESPONSE"

echo ""
echo -e "${YELLOW}Waiting for processing (5 seconds)...${NC}"
sleep 5

# Check test database
echo ""
echo -e "${GREEN}Test Database Status:${NC}"
sqlite3 data-test/selene-test.db <<EOF
.mode column
.headers on
SELECT id, title, status, test_run, created_at
FROM raw_notes
WHERE test_run = '$TEST_RUN'
ORDER BY id DESC
LIMIT 1;
EOF

echo ""
echo -e "${BLUE}=================================================="
echo "  Note submitted successfully!"
echo "  Monitor processing:"
echo "    docker-compose logs -f n8n | grep -i test"
echo ""
echo "  Check results:"
echo "    ./scripts/test-verify.sh \"$TEST_RUN\""
echo -e "==================================================${NC}"
