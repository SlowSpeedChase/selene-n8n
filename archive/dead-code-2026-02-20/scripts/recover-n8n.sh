#!/bin/bash
#
# Selene n8n Recovery Script
# Automates the recovery process from database corruption
#
# Usage: ./scripts/recover-n8n.sh
#

set -e  # Exit on error

echo "========================================="
echo "Selene n8n Recovery Script"
echo "========================================="
echo ""

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Check if we're in the right directory
if [ ! -f "docker-compose.yml" ]; then
    echo -e "${RED}Error: docker-compose.yml not found. Run this script from the selene-n8n directory.${NC}"
    exit 1
fi

# Step 1: Backup
echo -e "${YELLOW}Step 1: Creating backup...${NC}"
BACKUP_DIR="backup-$(date +%Y%m%d-%H%M%S)"
mkdir -p "$BACKUP_DIR"

if docker ps | grep -q selene-n8n; then
    docker cp selene-n8n:/home/node/.n8n/database.sqlite "$BACKUP_DIR/database-backup.sqlite" 2>/dev/null || true
    echo -e "${GREEN}✓ Database backed up to $BACKUP_DIR${NC}"
else
    echo -e "${YELLOW}Container not running, skipping database backup${NC}"
fi

# Step 2: Verify workflow backups
echo -e "${YELLOW}Step 2: Verifying workflow backups...${NC}"
WORKFLOW_COUNT=$(find workflows/ -name "workflow.json" -o -name "workflow-test.json" | wc -l)
echo -e "${GREEN}✓ Found $WORKFLOW_COUNT workflow JSON files${NC}"

# Step 3: Confirm with user
echo ""
echo -e "${RED}WARNING: This will delete the n8n database and start fresh!${NC}"
echo "Your workflow JSON files will be re-imported."
echo ""
read -p "Continue? (yes/no): " -r
if [[ ! $REPLY =~ ^[Yy]es$ ]]; then
    echo "Aborted."
    exit 1
fi

# Step 4: Stop and remove
echo -e "${YELLOW}Step 3: Stopping container and removing volume...${NC}"
docker-compose down
docker volume rm selene_n8n_data || true
echo -e "${GREEN}✓ Old volume removed${NC}"

# Step 5: Start fresh
echo -e "${YELLOW}Step 4: Starting fresh container...${NC}"
docker-compose up -d --build
echo -e "${GREEN}✓ Container started${NC}"

# Wait for n8n to be ready
echo -e "${YELLOW}Step 5: Waiting for n8n to initialize...${NC}"
sleep 15
until docker exec selene-n8n wget -q --spider http://localhost:5678 2>/dev/null; do
    echo "Waiting for n8n..."
    sleep 5
done
echo -e "${GREEN}✓ n8n is ready${NC}"

# Step 6: Instructions for user
echo ""
echo -e "${GREEN}=========================================${NC}"
echo -e "${GREEN}Recovery Complete - Action Required${NC}"
echo -e "${GREEN}=========================================${NC}"
echo ""
echo -e "${YELLOW}NEXT STEPS:${NC}"
echo ""
echo "1. Open your browser to: http://localhost:5678"
echo "2. Create an owner account (use credentials you'll remember)"
echo "3. Once logged in, run the import script:"
echo ""
echo -e "   ${GREEN}./scripts/import-workflows.sh${NC}"
echo ""
echo "Backup location: $BACKUP_DIR"
echo ""
