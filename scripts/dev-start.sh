#!/bin/bash
# Script Purpose: Start development n8n environment
# Usage: ./scripts/dev-start.sh

set -e
set -u

# Color output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
BLUE='\033[0;34m'
NC='\033[0m'

log_info() { echo -e "${GREEN}[INFO]${NC} $1"; }
log_error() { echo -e "${RED}[ERROR]${NC} $1"; }
log_step() { echo -e "${BLUE}[STEP]${NC} $1"; }

# Navigate to project root
cd "$(dirname "$0")/.."

# Check if dev database exists, create if not
if [ ! -f "data/selene-dev.db" ]; then
    log_step "Creating development database..."
    if [ -f "database/schema.sql" ]; then
        sqlite3 data/selene-dev.db < database/schema.sql
        log_info "Development database created from schema"
    else
        log_error "schema.sql not found - cannot create database"
        exit 1
    fi
fi

# Start dev stack
log_step "Starting development n8n stack..."
docker-compose -f docker-compose.dev.yml up -d

# Wait for health check
log_step "Waiting for n8n-dev to be healthy..."
for i in {1..30}; do
    if docker exec selene-n8n-dev wget --spider -q http://localhost:5678/healthz 2>/dev/null; then
        log_info "n8n-dev is healthy"
        break
    fi
    if [ $i -eq 30 ]; then
        log_error "n8n-dev failed to start within 30 seconds"
        exit 1
    fi
    sleep 1
done

# Update environment indicator
log_step "Updating environment indicator..."
cat > .claude/CURRENT-ENV.md << 'EOF'
# Current Environment

**Status:** DEVELOPMENT

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
- Development: **RUNNING** (port 5679)

---

*This file is automatically updated by dev-start.sh and dev-stop.sh*
EOF

log_info "Development environment ready!"
log_info "  n8n UI: http://localhost:5679"
log_info "  Database: data/selene-dev.db"
log_info "  Container: selene-n8n-dev"
echo ""
log_info "To stop: ./scripts/dev-stop.sh"
