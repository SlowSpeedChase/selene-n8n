#!/bin/sh
# Selene n8n Docker Entrypoint
# Fixes permissions on n8n config files before starting n8n

# Fix directory permissions (owner-only access)
chmod 700 /home/node/.n8n 2>/dev/null || true

# Fix config file permissions (owner read/write only)
chmod 600 /home/node/.n8n/config 2>/dev/null || true

# Fix any other sensitive files that may exist
chmod 600 /home/node/.n8n/.n8n-* 2>/dev/null || true

# Execute n8n with any passed arguments
exec n8n "$@"
