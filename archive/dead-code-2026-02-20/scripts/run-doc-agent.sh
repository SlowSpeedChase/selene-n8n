#!/bin/bash

# Documentation Agent Runner
# Triggers the Claude Code documentation agent to check and update docs

set -e

PROJECT_ROOT="/Users/chaseeasterling/selene-n8n"
AGENT_NAME="documentation-agent"
LOG_FILE="$PROJECT_ROOT/.claude/doc-agent.log"
LAST_RUN_FILE="$PROJECT_ROOT/.claude/.doc-agent-last-run"

# Colors for output
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

echo -e "${BLUE}═══════════════════════════════════════════════════${NC}"
echo -e "${BLUE}  Selene Documentation Agent${NC}"
echo -e "${BLUE}═══════════════════════════════════════════════════${NC}"
echo ""

# Change to project directory
cd "$PROJECT_ROOT"

# Detect what changed since last run
echo -e "${YELLOW}→${NC} Detecting changes..."

if [ -f "$LAST_RUN_FILE" ]; then
    LAST_RUN=$(cat "$LAST_RUN_FILE")
    echo "  Last run: $LAST_RUN"

    # Find modified files since last run
    CHANGED_FILES=$(find workflows database -type f \( -name "*.json" -o -name "*.sql" \) -newer "$LAST_RUN_FILE" 2>/dev/null || true)

    if [ -z "$CHANGED_FILES" ]; then
        echo -e "${GREEN}✓${NC} No changes detected since last run"

        # Still run if forced
        if [ "$1" != "--force" ]; then
            echo ""
            echo "Use --force to run anyway"
            exit 0
        else
            echo "  Running anyway (--force flag)"
        fi
    else
        echo -e "${YELLOW}  Changed files:${NC}"
        echo "$CHANGED_FILES" | while read -r file; do
            echo "    - $file"
        done
    fi
else
    echo "  First run - will perform full audit"
fi

echo ""

# Build the agent prompt
PROMPT="I am the documentation agent. Please analyze the Selene project and update any documentation that is outdated.

## My Tasks:
1. Scan workflows and database schema for recent changes
2. Identify documentation files that need updates
3. Propose specific changes needed
4. Wait for approval before making changes
5. Execute approved updates
6. Provide summary of changes made

## Detection Strategy:
"

if [ -n "$CHANGED_FILES" ]; then
    PROMPT="$PROMPT
Recent changes detected in:
$CHANGED_FILES

Please focus on documentation related to these changes.
"
else
    PROMPT="$PROMPT
No specific changes detected. Please perform a general documentation health check:
- Verify all timestamps are current
- Check cross-references are valid
- Ensure examples match current code
- Identify any obvious gaps or outdated information
"
fi

PROMPT="$PROMPT

Please begin by scanning for changes and presenting your findings."

# Save prompt to temp file
PROMPT_FILE=$(mktemp)
echo "$PROMPT" > "$PROMPT_FILE"

echo -e "${YELLOW}→${NC} Launching documentation agent..."
echo ""

# Note: This is a placeholder - actual invocation depends on how Claude Code agents are triggered
# Option 1: If there's a CLI command
# claude-code --agent "$AGENT_NAME" --prompt-file "$PROMPT_FILE"

# Option 2: If agents need to be manually invoked
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "AGENT PROMPT:"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
cat "$PROMPT_FILE"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""
echo -e "${YELLOW}To run the agent:${NC}"
echo "1. Open Claude Code CLI"
echo "2. Say: 'Load the documentation-agent and process this task:'"
echo "3. Copy/paste the prompt above"
echo ""
echo "OR simply say: 'Run the documentation agent to check for updates'"
echo ""

# Update last run timestamp
date > "$LAST_RUN_FILE"

# Log the run
echo "[$(date)] Documentation agent triggered" >> "$LOG_FILE"
if [ -n "$CHANGED_FILES" ]; then
    echo "$CHANGED_FILES" | sed 's/^/  /' >> "$LOG_FILE"
fi

# Cleanup
rm -f "$PROMPT_FILE"

echo -e "${GREEN}✓${NC} Ready for agent execution"
