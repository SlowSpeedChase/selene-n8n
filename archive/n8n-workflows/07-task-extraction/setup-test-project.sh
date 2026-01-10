#!/bin/bash

# Setup Test Project in Things 3
# Creates a dedicated project for Selene testing with bidirectional sync

# Colors
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

echo -e "${BLUE}═══════════════════════════════════════════════════════${NC}"
echo -e "${BLUE}  Things 3 Test Environment Setup${NC}"
echo -e "${BLUE}═══════════════════════════════════════════════════════${NC}"
echo ""

# Step 1: Create test project in Things
echo -e "${CYAN}Step 1: Creating test project...${NC}"

PROJECT_NAME="Selene Test Project"
PROJECT_NOTES="Auto-created for Selene bidirectional sync testing. Tasks in this project are used for testing the integration between Selene notes and Things tasks."

# Encode parameters for URL
PROJECT_NAME_ENCODED=$(printf %s "$PROJECT_NAME" | jq -sRr @uri)
PROJECT_NOTES_ENCODED=$(printf %s "$PROJECT_NOTES" | jq -sRr @uri)

# Create project via Things URL scheme
THINGS_URL="things:///add-project?title=${PROJECT_NAME_ENCODED}&notes=${PROJECT_NOTES_ENCODED}"

echo -e "${YELLOW}Opening Things to create project...${NC}"
open "$THINGS_URL"

echo -e "${GREEN}✓ Project creation URL opened${NC}"
echo ""

# Step 2: Wait for user confirmation
echo -e "${YELLOW}Please check Things 3:${NC}"
echo "  1. Confirm the project was created"
echo "  2. Note the project appears in your Projects list"
echo ""

read -p "Press ENTER when you've confirmed the project exists in Things..."
echo ""

# Step 3: Create test task to verify project works
echo -e "${CYAN}Step 2: Creating test task in project...${NC}"

TEST_TASK_TITLE="Test Task - Verify Sync"
TEST_TASK_NOTES="This is a test task to verify the Things integration is working.

Created: $(date)
Source: Selene Test Suite"

# For this to work, we need the project ID
# Things URL scheme doesn't provide project ID in response
# User will need to manually note it or we'll query it later

echo -e "${YELLOW}We'll create tasks via the workflow once it's built${NC}"
echo -e "${GREEN}✓ Setup complete!${NC}"
echo ""

# Step 4: Instructions for next steps
echo -e "${BLUE}═══════════════════════════════════════════════════════${NC}"
echo -e "${BLUE}  Next Steps${NC}"
echo -e "${BLUE}═══════════════════════════════════════════════════════${NC}"
echo ""
echo "1. The test project '$PROJECT_NAME' should now be in Things"
echo "2. We'll use this project for all test tasks"
echo "3. Mock notes will create tasks in this project"
echo "4. Bidirectional sync will read task status from this project"
echo ""
echo -e "${CYAN}To get the project UUID (needed for workflow):${NC}"
echo "  - We'll use the project title for now"
echo "  - Things URL scheme: list?filter=projects"
echo "  - Or manually from Things export"
echo ""
echo -e "${GREEN}Setup complete! Ready for testing.${NC}"
