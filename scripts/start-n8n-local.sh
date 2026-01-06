#!/bin/bash
# Local n8n startup script for Selene
# Replaces Docker-based n8n with direct local execution

set -e

# Expected n8n version (must match what was used in Docker)
EXPECTED_N8N_VERSION="1.110.1"

# Get the project root directory
PROJECT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

# Check n8n is installed
if ! command -v n8n &> /dev/null; then
    echo "ERROR: n8n is not installed"
    echo "Run: npm install -g n8n@$EXPECTED_N8N_VERSION"
    exit 1
fi

# Check n8n version
INSTALLED_VERSION=$(n8n --version 2>/dev/null || echo "unknown")
if [ "$INSTALLED_VERSION" != "$EXPECTED_N8N_VERSION" ]; then
    echo "WARNING: n8n version mismatch"
    echo "  Expected: $EXPECTED_N8N_VERSION"
    echo "  Installed: $INSTALLED_VERSION"
    echo ""
    echo "To fix: npm install -g n8n@$EXPECTED_N8N_VERSION"
    echo ""
    read -p "Continue anyway? (y/N) " -n 1 -r
    echo
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        exit 1
    fi
fi

# n8n data directory (stores workflows, credentials, settings)
export N8N_USER_FOLDER="$PROJECT_ROOT/.n8n-local"

# Create directories if they don't exist
mkdir -p "$N8N_USER_FOLDER"
mkdir -p "$N8N_USER_FOLDER/logs"

# ============================================
# BASIC N8N CONFIGURATION
# ============================================

# Host Configuration
export N8N_HOST=0.0.0.0
export N8N_PORT=5678
export N8N_PROTOCOL=http
export WEBHOOK_URL=http://localhost:5678/
export N8N_EDITOR_BASE_URL=http://localhost:5678

# Execution Settings
export EXECUTIONS_MODE=regular
export EXECUTIONS_DATA_SAVE_ON_SUCCESS=all
export EXECUTIONS_DATA_SAVE_ON_ERROR=all
export EXECUTIONS_DATA_SAVE_MANUAL_EXECUTIONS=true
export EXECUTIONS_DATA_PRUNE=true
export EXECUTIONS_DATA_MAX_AGE=168  # Keep executions for 7 days

# Timezone
export GENERIC_TIMEZONE=America/Los_Angeles
export TZ=America/Los_Angeles

# Performance
export N8N_PAYLOAD_SIZE_MAX=16
export N8N_METRICS=false
export DB_SQLITE_POOL_SIZE=5

# Task Runners
export N8N_RUNNERS_ENABLED=true

# Logging
export N8N_LOG_LEVEL=warn
export N8N_LOG_OUTPUT=console,file
export N8N_LOG_FILE_LOCATION="$N8N_USER_FOLDER/logs/n8n.log"
export N8N_LOG_FILE_SIZE_MAX=16
export N8N_LOG_FILE_COUNT_MAX=10

# Disable telemetry
export N8N_DIAGNOSTICS_ENABLED=false
export N8N_VERSION_NOTIFICATIONS_ENABLED=false
export N8N_TEMPLATES_ENABLED=false

# Community nodes
export N8N_COMMUNITY_PACKAGES_ENABLED=true

# Allow external modules in Function nodes
export NODE_FUNCTION_ALLOW_EXTERNAL=better-sqlite3,crypto,fs,path

# Find better-sqlite3 path (global npm modules)
GLOBAL_NODE_MODULES="$(npm root -g)"
export NODE_PATH="$GLOBAL_NODE_MODULES"

# Security (local development)
export N8N_BLOCK_ENV_ACCESS_IN_NODE=false
export N8N_SECURE_COOKIE=false

# ============================================
# SELENE-SPECIFIC ENVIRONMENT VARIABLES
# These use LOCAL paths instead of Docker paths
# ============================================

# Project root (needed for scripts that use /workflows/ Docker mount)
export SELENE_PROJECT_ROOT="$PROJECT_ROOT"

# Production paths (local filesystem)
export SELENE_DB_PATH="$PROJECT_ROOT/data/selene.db"
export OBSIDIAN_VAULT_PATH="$PROJECT_ROOT/vault"
export SELENE_ENV=production

# Test paths
export SELENE_TEST_DB_PATH="$PROJECT_ROOT/data-test/selene-test.db"
export OBSIDIAN_TEST_VAULT_PATH="$PROJECT_ROOT/vault-test"

# Ollama (local - no need for host.docker.internal)
export OLLAMA_BASE_URL=http://localhost:11434
export OLLAMA_MODEL=${OLLAMA_MODEL:-mistral:7b}

# TRMNL webhook
export TRMNL_WEBHOOK_ID=1f73e060-9d02-4b85-b122-50d7275c7bd9

# ============================================

echo "============================================"
echo "Starting n8n locally (v$INSTALLED_VERSION)"
echo "============================================"
echo ""
echo "  n8n data:    $N8N_USER_FOLDER"
echo "  Selene DB:   $SELENE_DB_PATH"
echo "  Obsidian:    $OBSIDIAN_VAULT_PATH"
echo "  Ollama:      $OLLAMA_BASE_URL"
echo ""
echo "  Access n8n:  http://localhost:5678"
echo ""
echo "============================================"
echo ""

# Start n8n
exec n8n start
