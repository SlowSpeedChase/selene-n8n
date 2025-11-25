#!/bin/bash
# Check if CLAUDE.md files need updates based on staged changes
# Returns 0 if updates needed, 1 if no updates needed

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Check if we're in a git repository
if ! git rev-parse --is-inside-work-tree > /dev/null 2>&1; then
    echo -e "${RED}Not in a git repository${NC}"
    exit 1
fi

# Get list of staged files
STAGED_FILES=$(git diff --cached --name-only)

if [ -z "$STAGED_FILES" ]; then
    # No staged files, no updates needed
    exit 1
fi

# Initialize update flag
UPDATES_NEEDED=false
AFFECTED_COMPONENTS=()

# Check for trigger files
echo -e "${BLUE}Checking staged files for CLAUDE.md update triggers...${NC}"

while IFS= read -r file; do
    case "$file" in
        # Workflow JSON changes
        workflows/*/workflow.json)
            WORKFLOW_DIR=$(dirname "$file")
            echo -e "${YELLOW}  Detected: $file${NC}"
            echo -e "${GREEN}  → Update needed: ${WORKFLOW_DIR}/CLAUDE.md${NC}"
            AFFECTED_COMPONENTS+=("$WORKFLOW_DIR")
            UPDATES_NEEDED=true
            ;;

        # Database schema changes
        database/schema.sql)
            echo -e "${YELLOW}  Detected: $file${NC}"
            echo -e "${GREEN}  → Update needed: database/CLAUDE.md${NC}"
            AFFECTED_COMPONENTS+=("database")
            UPDATES_NEEDED=true
            ;;

        # Swift package changes
        SeleneChat/Package.swift)
            echo -e "${YELLOW}  Detected: $file${NC}"
            echo -e "${GREEN}  → Update needed: SeleneChat/CLAUDE.md${NC}"
            AFFECTED_COMPONENTS+=("SeleneChat")
            UPDATES_NEEDED=true
            ;;

        # Swift source changes in Services
        SeleneChat/Sources/Services/*.swift)
            echo -e "${YELLOW}  Detected: $file${NC}"
            echo -e "${GREEN}  → Update needed: SeleneChat/Sources/Services/CLAUDE.md${NC}"
            AFFECTED_COMPONENTS+=("SeleneChat/Sources/Services")
            UPDATES_NEEDED=true
            ;;

        # Swift source changes in Views
        SeleneChat/Sources/Views/*.swift)
            echo -e "${YELLOW}  Detected: $file${NC}"
            echo -e "${GREEN}  → Update needed: SeleneChat/Sources/Views/CLAUDE.md${NC}"
            AFFECTED_COMPONENTS+=("SeleneChat/Sources/Views")
            UPDATES_NEEDED=true
            ;;

        # New workflow directories
        workflows/*/*)
            if [ ! -f "$(dirname "$file")/CLAUDE.md" ]; then
                WORKFLOW_DIR=$(dirname "$file")
                echo -e "${YELLOW}  Detected new workflow: $file${NC}"
                echo -e "${GREEN}  → Create needed: ${WORKFLOW_DIR}/CLAUDE.md${NC}"
                AFFECTED_COMPONENTS+=("$WORKFLOW_DIR")
                UPDATES_NEEDED=true
            fi
            ;;

        # Docker or environment config changes
        docker-compose.yml|.env.example)
            echo -e "${YELLOW}  Detected: $file${NC}"
            echo -e "${GREEN}  → Update needed: CLAUDE.md (root)${NC}"
            AFFECTED_COMPONENTS+=(".")
            UPDATES_NEEDED=true
            ;;

        # Test script changes
        */test-with-markers.sh|*/cleanup-tests.sh)
            COMPONENT_DIR=$(dirname "$(dirname "$file")")
            echo -e "${YELLOW}  Detected: $file${NC}"
            echo -e "${GREEN}  → Update needed: ${COMPONENT_DIR}/CLAUDE.md${NC}"
            AFFECTED_COMPONENTS+=("$COMPONENT_DIR")
            UPDATES_NEEDED=true
            ;;
    esac
done <<< "$STAGED_FILES"

if [ "$UPDATES_NEEDED" = true ]; then
    echo ""
    echo -e "${BLUE}Summary:${NC}"
    echo -e "${GREEN}Updates needed for ${#AFFECTED_COMPONENTS[@]} component(s)${NC}"

    # Remove duplicates and save to temp file
    printf '%s\n' "${AFFECTED_COMPONENTS[@]}" | sort -u > /tmp/claude-context-updates

    exit 0
else
    echo -e "${GREEN}No CLAUDE.md updates needed for staged changes${NC}"
    exit 1
fi
