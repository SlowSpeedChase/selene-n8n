#!/bin/bash
# Script Purpose: Stop development n8n environment
# Usage: ./scripts/dev-stop.sh

set -e
set -u

# Color output
GREEN='\033[0;32m'
BLUE='\033[0;34m'
NC='\033[0m'

log_info() { echo -e "${GREEN}[INFO]${NC} $1"; }
log_step() { echo -e "${BLUE}[STEP]${NC} $1"; }

# Navigate to project root
cd "$(dirname "$0")/.."

# Stop dev stack
log_step "Stopping development n8n stack..."
docker-compose -f docker-compose.dev.yml down

# Update environment indicator
log_step "Updating environment indicator..."
cat > .claude/CURRENT-ENV.md << 'EOF'
# Current Environment

**Status:** PRODUCTION

---

## What This Means

- **PRODUCTION**: Claude should NOT make changes to workflows or test against production database
- **DEVELOPMENT**: Claude can freely modify workflows and test against dev database

## Environment Details

| Environment | Port | Database | Container |
|-------------|------|----------|-----------|
| Production | 5678 | selene.db | selene-n8n |
| Development | 5679 | selene-dev.db | selene-n8n-dev |

## Switching Environments

Use the dev scripts:
- `./scripts/dev-start.sh` - Start dev environment (updates this file)
- `./scripts/dev-stop.sh` - Stop dev environment (updates this file)

## Current Status

- Production: Running (always on)
- Development: Not running

---

*This file is automatically updated by dev-start.sh and dev-stop.sh*
EOF

log_info "Development environment stopped"
log_info "Production remains on port 5678"
