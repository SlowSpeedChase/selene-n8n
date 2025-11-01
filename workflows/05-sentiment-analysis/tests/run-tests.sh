#!/bin/bash

# Sentiment Analysis Testing Script
# This script sends test notes and validates the sentiment analysis results

set -e

WEBHOOK_URL="http://localhost:5678/webhook/api/drafts"
DB_PATH="data/selene.db"
TEST_NOTES_FILE="workflows/05-sentiment-analysis/tests/test-notes.json"
RESULTS_FILE="workflows/05-sentiment-analysis/tests/test-results.json"

echo "========================================"
echo "Sentiment Analysis Testing"
echo "========================================"
echo ""

# Check prerequisites
echo "Checking prerequisites..."

if ! command -v jq &> /dev/null; then
    echo "Warning: jq not found. Install with: brew install jq"
    USE_JQ=false
else
    USE_JQ=true
fi

if ! docker-compose ps | grep -q "selene-n8n.*Up"; then
    echo "Error: n8n container is not running"
    exit 1
fi

if ! curl -s http://localhost:11434/api/tags > /dev/null; then
    echo "Error: Ollama is not running"
    exit 1
fi

echo "✓ n8n is running"
echo "✓ Ollama is accessible"
echo ""

# Count unanalyzed notes before test
BEFORE_COUNT=$(sqlite3 "$DB_PATH" "SELECT COUNT(*) FROM processed_notes WHERE sentiment_analyzed = 0;")
echo "Unanalyzed notes before test: $BEFORE_COUNT"
echo ""

# Send test notes
echo "Sending test notes..."
echo ""

if [ ! -f "$TEST_NOTES_FILE" ]; then
    echo "Error: Test notes file not found: $TEST_NOTES_FILE"
    exit 1
fi

if [ "$USE_JQ" = true ]; then
    # Use jq to parse JSON
    TEST_COUNT=$(jq length "$TEST_NOTES_FILE")

    for i in $(seq 0 $((TEST_COUNT - 1))); do
        NAME=$(jq -r ".[$i].name" "$TEST_NOTES_FILE")
        TITLE=$(jq -r ".[$i].title" "$TEST_NOTES_FILE")
        CONTENT=$(jq -r ".[$i].content" "$TEST_NOTES_FILE")

        echo "Sending: $NAME"

        TIMESTAMP=$(date -u +"%Y-%m-%dT%H:%M:%SZ")

        RESPONSE=$(curl -s -X POST "$WEBHOOK_URL" \
          -H "Content-Type: application/json" \
          -d "{
            \"query\": {
              \"title\": $(echo "$TITLE" | jq -Rs .),
              \"content\": $(echo "$CONTENT" | jq -Rs .),
              \"timestamp\": \"$TIMESTAMP\"
            }
          }")

        if echo "$RESPONSE" | grep -q "success"; then
            echo "  ✓ Sent successfully"
        else
            echo "  ✗ Failed: $RESPONSE"
        fi

        # Small delay to avoid overwhelming the system
        sleep 1
    done
else
    echo "jq not available - sending subset of tests manually..."
    # Fallback: send a couple test notes manually

    curl -s -X POST "$WEBHOOK_URL" \
      -H "Content-Type: application/json" \
      -d '{
        "query": {
          "title": "Test: Overwhelm Pattern",
          "content": "I have 15 different projects and cant focus. Everything feels urgent. My brain is racing. Too much at once.",
          "timestamp": "'$(date -u +"%Y-%m-%dT%H:%M:%SZ")'"
        }
      }' > /dev/null
    echo "  ✓ Sent overwhelm test"
    sleep 1

    curl -s -X POST "$WEBHOOK_URL" \
      -H "Content-Type: application/json" \
      -d '{
        "query": {
          "title": "Test: Hyperfocus Pattern",
          "content": "Been at this for 6 hours straight. Lost track of time completely. Started at 2pm, looked up and its 8pm. Completely dialed in. In the zone.",
          "timestamp": "'$(date -u +"%Y-%m-%dT%H:%M:%SZ")'"
        }
      }' > /dev/null
    echo "  ✓ Sent hyperfocus test"
fi

echo ""
echo "========================================"
echo "Waiting for processing..."
echo "========================================"
echo ""
echo "Workflow 02 (LLM Processing) takes ~30 seconds per note"
echo "Workflow 05 (Sentiment Analysis) takes ~45 seconds interval + 5-10s processing"
echo ""
echo "Waiting 90 seconds for workflows to catch up..."

for i in {90..1}; do
    printf "\r%2d seconds remaining..." "$i"
    sleep 1
done
echo ""
echo ""

# Check how many were processed
AFTER_COUNT=$(sqlite3 "$DB_PATH" "SELECT COUNT(*) FROM processed_notes WHERE sentiment_analyzed = 0;")
ANALYZED_COUNT=$(sqlite3 "$DB_PATH" "SELECT COUNT(*) FROM processed_notes WHERE sentiment_analyzed = 1;")

echo "========================================"
echo "Processing Status"
echo "========================================"
echo ""
echo "Unanalyzed notes after test: $AFTER_COUNT"
echo "Total analyzed notes: $ANALYZED_COUNT"
echo "Notes processed in this test: $((BEFORE_COUNT - AFTER_COUNT))"
echo ""

# Show recent sentiment analyses
echo "========================================"
echo "Recent Sentiment Analyses"
echo "========================================"
echo ""

sqlite3 "$DB_PATH" "
SELECT
    rn.title,
    pn.overall_sentiment,
    pn.emotional_tone,
    pn.energy_level,
    pn.sentiment_score,
    SUBSTR(pn.sentiment_data, 1, 100) as data_preview
FROM processed_notes pn
JOIN raw_notes rn ON pn.raw_note_id = rn.id
WHERE pn.sentiment_analyzed = 1
ORDER BY pn.sentiment_analyzed_at DESC
LIMIT 5;
" -header -column

echo ""
echo ""

# Detailed analysis of test patterns
echo "========================================"
echo "ADHD Marker Detection Summary"
echo "========================================"
echo ""

sqlite3 "$DB_PATH" "
SELECT
    COUNT(CASE WHEN adhd_markers LIKE '%\"overwhelm\":true%' THEN 1 END) as overwhelm_detected,
    COUNT(CASE WHEN adhd_markers LIKE '%\"hyperfocus\":true%' THEN 1 END) as hyperfocus_detected,
    COUNT(CASE WHEN adhd_markers LIKE '%\"executive_dysfunction\":true%' THEN 1 END) as exec_dysfunction_detected,
    COUNT(CASE WHEN adhd_markers LIKE '%\"scattered\":true%' THEN 1 END) as scattered_detected,
    COUNT(CASE WHEN adhd_markers LIKE '%\"burnout\":true%' THEN 1 END) as burnout_detected,
    COUNT(CASE WHEN adhd_markers LIKE '%\"time_blindness\":true%' THEN 1 END) as time_blindness_detected,
    COUNT(CASE WHEN adhd_markers LIKE '%\"positive_traits\":true%' THEN 1 END) as positive_traits_detected,
    COUNT(*) as total_analyzed
FROM sentiment_history;
" -header -column

echo ""
echo ""

# Show full details of most recent analysis
echo "========================================"
echo "Most Recent Analysis Details"
echo "========================================"
echo ""

LATEST_SENTIMENT=$(sqlite3 "$DB_PATH" "
SELECT sentiment_data
FROM processed_notes
WHERE sentiment_analyzed = 1
ORDER BY sentiment_analyzed_at DESC
LIMIT 1;
")

if [ -n "$LATEST_SENTIMENT" ] && [ "$USE_JQ" = true ]; then
    echo "$LATEST_SENTIMENT" | jq .
else
    echo "$LATEST_SENTIMENT"
fi

echo ""
echo "========================================"
echo "Test Complete!"
echo "========================================"
echo ""
echo "To view all sentiment data:"
echo "  sqlite3 $DB_PATH \"SELECT * FROM sentiment_history ORDER BY analyzed_at DESC LIMIT 10;\""
echo ""
echo "To export results:"
echo "  sqlite3 $DB_PATH \"SELECT rn.title, pn.sentiment_data FROM processed_notes pn JOIN raw_notes rn ON pn.raw_note_id = rn.id WHERE pn.sentiment_analyzed = 1;\" > sentiment-export.txt"
echo ""
