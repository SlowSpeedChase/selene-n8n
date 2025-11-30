#!/bin/bash
# Script Purpose: Checklist-driven workflow promotion from dev to production
# Usage: ./scripts/promote-workflow.sh <workflow-name>
# Example: ./scripts/promote-workflow.sh 01-ingestion

set -e
set -u

# Color output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m'

log_info() { echo -e "${GREEN}[INFO]${NC} $1"; }
log_error() { echo -e "${RED}[ERROR]${NC} $1"; }
log_warn() { echo -e "${YELLOW}[WARN]${NC} $1"; }
log_step() { echo -e "${BLUE}[STEP]${NC} $1"; }
log_gate() { echo -e "${CYAN}[GATE]${NC} $1"; }

# Navigate to project root
cd "$(dirname "$0")/.."

# Validate input
if [ $# -eq 0 ]; then
    log_error "Usage: $0 <workflow-name>"
    log_info "Example: $0 01-ingestion"
    log_info ""
    log_info "Available workflows:"
    ls -d workflows/*/ 2>/dev/null | xargs -I{} basename {} || echo "  No workflows found"
    exit 1
fi

WORKFLOW_NAME="$1"
WORKFLOW_DIR="workflows/$WORKFLOW_NAME"
WORKFLOW_JSON="$WORKFLOW_DIR/workflow.json"

# Validate workflow exists
if [ ! -d "$WORKFLOW_DIR" ]; then
    log_error "Workflow directory not found: $WORKFLOW_DIR"
    exit 1
fi

if [ ! -f "$WORKFLOW_JSON" ]; then
    log_error "Workflow JSON not found: $WORKFLOW_JSON"
    exit 1
fi

echo ""
echo "╔════════════════════════════════════════════════════════════════╗"
echo "║           WORKFLOW PROMOTION CHECKLIST                         ║"
echo "║           Workflow: $WORKFLOW_NAME"
echo "╚════════════════════════════════════════════════════════════════╝"
echo ""

# ─────────────────────────────────────────────────────────────────────
# GATE 1: Verify dev tests pass
# ─────────────────────────────────────────────────────────────────────
log_step "1/7: Verify dev tests pass"

TEST_SCRIPT="$WORKFLOW_DIR/scripts/test-with-markers.sh"
if [ -f "$TEST_SCRIPT" ]; then
    log_info "Test script found: $TEST_SCRIPT"
    log_warn "Run the test script manually and verify all tests pass"
    log_info "Command: $TEST_SCRIPT"
else
    log_warn "No test script found at: $TEST_SCRIPT"
    log_warn "Manual testing required"
fi

echo ""
log_gate "Have all tests passed? (y/n)"
read -r gate1
if [ "$gate1" != "y" ]; then
    log_error "Promotion stopped: Tests not verified"
    exit 1
fi

# ─────────────────────────────────────────────────────────────────────
# GATE 2: Show diff
# ─────────────────────────────────────────────────────────────────────
log_step "2/7: Review changes"

echo ""
log_info "Changes in $WORKFLOW_JSON:"
git diff --stat "$WORKFLOW_JSON" 2>/dev/null || log_info "No uncommitted changes"
echo ""
git diff "$WORKFLOW_JSON" 2>/dev/null | head -50 || true

echo ""
log_gate "Do the changes look correct? (y/n)"
read -r gate2
if [ "$gate2" != "y" ]; then
    log_error "Promotion stopped: Changes not approved"
    exit 1
fi

# ─────────────────────────────────────────────────────────────────────
# GATE 3: Documentation check
# ─────────────────────────────────────────────────────────────────────
log_step "3/7: Verify documentation"

STATUS_MD="$WORKFLOW_DIR/docs/STATUS.md"
if [ -f "$STATUS_MD" ]; then
    log_info "STATUS.md found: $STATUS_MD"
    log_info "Last modified: $(stat -f '%Sm' "$STATUS_MD" 2>/dev/null || stat -c '%y' "$STATUS_MD" 2>/dev/null || echo 'unknown')"
else
    log_warn "STATUS.md not found: $STATUS_MD"
fi

echo ""
log_gate "Is the documentation current? (y/n)"
read -r gate3
if [ "$gate3" != "y" ]; then
    log_error "Promotion stopped: Documentation not current"
    exit 1
fi

# ─────────────────────────────────────────────────────────────────────
# GATE 4: Final approval
# ─────────────────────────────────────────────────────────────────────
log_step "4/7: Final approval"

echo ""
echo "╔════════════════════════════════════════════════════════════════╗"
echo "║  PROMOTION SUMMARY                                             ║"
echo "╠════════════════════════════════════════════════════════════════╣"
echo "║  Workflow: $WORKFLOW_NAME"
echo "║  Source: $WORKFLOW_JSON"
echo "║  Target: Production n8n (port 5678)"
echo "╚════════════════════════════════════════════════════════════════╝"
echo ""

log_gate "Approve promotion to production? (type 'PROMOTE' to confirm)"
read -r gate4
if [ "$gate4" != "PROMOTE" ]; then
    log_error "Promotion stopped: Not approved"
    exit 1
fi

# ─────────────────────────────────────────────────────────────────────
# STEP 5: Import to production
# ─────────────────────────────────────────────────────────────────────
log_step "5/7: Importing to production..."

# Check production container is running
if ! docker ps --format '{{.Names}}' | grep -q "^selene-n8n$"; then
    log_error "Production container 'selene-n8n' is not running"
    log_info "Start with: docker-compose up -d"
    exit 1
fi

# Get workflow ID from n8n (by name matching)
log_info "Importing workflow to production n8n..."
docker exec selene-n8n n8n import:workflow --input="/workflows/$WORKFLOW_JSON" --separate

log_info "Workflow imported to production"

# ─────────────────────────────────────────────────────────────────────
# GATE 6: Verify production
# ─────────────────────────────────────────────────────────────────────
log_step "6/7: Verify production"

echo ""
log_warn "Please verify the workflow is working in production:"
log_info "  1. Open n8n at http://localhost:5678"
log_info "  2. Check the workflow is active"
log_info "  3. Run a quick smoke test if applicable"
echo ""

log_gate "Is production working correctly? (y/n)"
read -r gate6
if [ "$gate6" != "y" ]; then
    log_error "Promotion verification failed"
    log_warn "Consider rolling back by reimporting a backup"
    exit 1
fi

# ─────────────────────────────────────────────────────────────────────
# STEP 7: Commit
# ─────────────────────────────────────────────────────────────────────
log_step "7/7: Commit changes"

# Check if there are changes to commit
if git diff --quiet "$WORKFLOW_JSON" && git diff --quiet "$STATUS_MD" 2>/dev/null; then
    log_info "No uncommitted changes to commit"
else
    log_info "Staging changes..."
    git add "$WORKFLOW_JSON"
    [ -f "$STATUS_MD" ] && git add "$STATUS_MD"

    log_gate "Commit message (or press Enter for default):"
    read -r commit_msg
    if [ -z "$commit_msg" ]; then
        commit_msg="feat($WORKFLOW_NAME): promote workflow to production"
    fi

    git commit -m "$commit_msg"
    log_info "Changes committed"
fi

echo ""
echo "╔════════════════════════════════════════════════════════════════╗"
echo "║  PROMOTION COMPLETE                                            ║"
echo "╚════════════════════════════════════════════════════════════════╝"
echo ""
log_info "Workflow $WORKFLOW_NAME has been promoted to production"
