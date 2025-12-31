#!/bin/bash

echo "========================================"
echo "Sentiment Analysis Status Check"
echo "========================================"
echo ""

echo "1. Unanalyzed Notes Count:"
sqlite3 data/selene.db "SELECT COUNT(*) FROM processed_notes WHERE sentiment_analyzed = 0;"
echo ""

echo "2. Notes Waiting for Analysis:"
sqlite3 data/selene.db "
SELECT rn.id, rn.title
FROM processed_notes pn
JOIN raw_notes rn ON pn.raw_note_id = rn.id
WHERE pn.sentiment_analyzed = 0
ORDER BY pn.processed_at DESC;" -header -column
echo ""

echo "3. Recently Analyzed Notes:"
sqlite3 data/selene.db "
SELECT rn.title, pn.overall_sentiment, pn.emotional_tone, pn.sentiment_analyzed_at
FROM processed_notes pn
JOIN raw_notes rn ON pn.raw_note_id = rn.id
WHERE pn.sentiment_analyzed = 1
ORDER BY pn.sentiment_analyzed_at DESC
LIMIT 3;" -header -column
echo ""

echo "4. Docker Services Status:"
docker-compose ps | grep selene-n8n
echo ""

echo "5. Ollama Status:"
if curl -s http://localhost:11434/api/tags > /dev/null 2>&1; then
    echo "✓ Ollama is accessible"
else
    echo "✗ Ollama is NOT accessible"
fi
echo ""

echo "6. Active Workflows in n8n:"
docker-compose logs n8n --tail=200 | grep "Activated workflow" | tail -5
echo ""

echo "7. Recent n8n Errors:"
docker-compose logs n8n --tail=100 | grep -i "error" | grep -v "Error tracking disabled" | tail -5
echo ""

echo "========================================"
echo "Troubleshooting Steps:"
echo "========================================"
echo ""
echo "If sentiment workflow is NOT in active workflows list:"
echo "  1. Open n8n UI: http://localhost:5678"
echo "  2. Find 'Selene: Sentiment Analysis (Enhanced v2)' workflow"
echo "  3. Click the workflow to open it"
echo "  4. Check for any red error icons on nodes"
echo "  5. Toggle the 'Active' switch OFF then ON again"
echo "  6. Save the workflow"
echo "  7. Restart n8n: docker-compose restart n8n"
echo ""
echo "If workflow shows errors:"
echo "  1. Click on the node with error"
echo "  2. Check the error message"
echo "  3. Common issues:"
echo "     - Module not found → Restart n8n"
echo "     - Database error → Check permissions on data/selene.db"
echo "     - Ollama error → Verify Ollama is running"
echo ""
