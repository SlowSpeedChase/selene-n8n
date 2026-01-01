#!/bin/bash
#
# Selene n8n Workflow Import Script
# Imports all workflow JSON files into n8n
#
# Usage: ./scripts/import-workflows.sh
#

set -e  # Exit on error

echo "========================================="
echo "Selene n8n Workflow Import"
echo "========================================="
echo ""

# Colors for output
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Wrapper for n8n CLI commands - filters noisy "Error tracking disabled" message
n8n_exec() {
    docker exec selene-n8n n8n "$@" 2>&1 | grep -v "Error tracking disabled"
}

# Import production workflows
echo -e "${YELLOW}Importing production workflows...${NC}"
n8n_exec import:workflow --input=/workflows/workflows/01-ingestion/workflow.json
n8n_exec import:workflow --input=/workflows/workflows/02-llm-processing/workflow.json
n8n_exec import:workflow --input=/workflows/workflows/03-pattern-detection/workflow.json
n8n_exec import:workflow --input=/workflows/workflows/04-obsidian-export/workflow.json
n8n_exec import:workflow --input=/workflows/workflows/05-sentiment-analysis/workflow.json
n8n_exec import:workflow --input=/workflows/workflows/06-connection-network/workflow.json
n8n_exec import:workflow --input=/workflows/workflows/07-task-extraction/workflow.json
echo -e "${GREEN}✓ Production workflows imported${NC}"

# Import test workflows (if they exist)
echo -e "${YELLOW}Importing test workflows...${NC}"
n8n_exec import:workflow --input=/workflows/workflows/01-ingestion/workflow-test.json 2>/dev/null || true
n8n_exec import:workflow --input=/workflows/workflows/02-llm-processing/workflow-test.json 2>/dev/null || true
n8n_exec import:workflow --input=/workflows/workflows/04-obsidian-export/workflow-test.json 2>/dev/null || true
n8n_exec import:workflow --input=/workflows/workflows/05-sentiment-analysis/workflow-test.json 2>/dev/null || true
echo -e "${GREEN}✓ Test workflows imported${NC}"

# Import Apple variant (if it exists)
echo -e "${YELLOW}Importing Apple variant...${NC}"
n8n_exec import:workflow --input=/workflows/workflows/02-llm-processing_apple/workflow.json 2>/dev/null || true
echo -e "${GREEN}✓ Apple variant imported${NC}"

# Activate production workflows
echo -e "${YELLOW}Activating production workflows...${NC}"
docker exec selene-n8n sqlite3 /home/node/.n8n/database.sqlite \
  "UPDATE workflow_entity SET active = 1 WHERE name IN (
    '01-Note-Ingestion | Selene',
    '02-LLM-Processing | Selene',
    '04-Obsidian-Export | Selene',
    '05-Sentiment-Analysis | Selene',
    '07-Task-Extraction'
  );"

# Restart to activate
docker-compose restart n8n
echo -e "${GREEN}✓ Workflows activated${NC}"

# Wait for restart
echo -e "${YELLOW}Waiting for n8n to restart...${NC}"
sleep 10

echo ""
echo -e "${GREEN}=========================================${NC}"
echo -e "${GREEN}Import Complete!${NC}"
echo -e "${GREEN}=========================================${NC}"
echo ""
echo "Active workflows:"
echo "  - 01-Note-Ingestion | Selene"
echo "  - 02-LLM-Processing | Selene"
echo "  - 04-Obsidian-Export | Selene"
echo "  - 05-Sentiment-Analysis | Selene (with Task Extraction trigger)"
echo "  - 07-Task-Extraction (NEW)"
echo ""
echo "IMPORTANT: Start the Things wrapper before testing:"
echo "  cd ~/selene-n8n && npm run mcp-wrapper"
echo ""
echo "Check your browser at: http://localhost:5678"
echo ""
