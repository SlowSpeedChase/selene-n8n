# Selene n8n - Custom Image with SQLite and Dependencies
FROM n8nio/n8n:latest

# Switch to root to install packages
USER root

# Install system dependencies needed for better-sqlite3
RUN apk add --no-cache \
    python3 \
    make \
    g++ \
    sqlite \
    sqlite-dev

# Set working directory
WORKDIR /home/node

# Install better-sqlite3 globally so it's available to all workflows
# Must be run as root for global installation
RUN npm install -g better-sqlite3@11.0.0

# Copy custom entrypoint script with executable permissions
COPY --chmod=755 scripts/docker-entrypoint.sh /usr/local/bin/docker-entrypoint.sh

# Change ownership of installed packages to node user
RUN chown -R node:node /home/node

# Switch back to node user for runtime
USER node

# Install n8n community packages for SQLite support
# These will be installed when the container starts via environment variables
# N8N_COMMUNITY_PACKAGES_ENABLED=true allows this

# Create directory for Selene data
RUN mkdir -p /home/node/.n8n

# Use custom entrypoint to fix permissions before starting n8n
ENTRYPOINT ["/usr/local/bin/docker-entrypoint.sh"]

# Expose n8n port
EXPOSE 5678

# Health check
HEALTHCHECK --interval=30s --timeout=10s --retries=3 --start-period=40s \
    CMD wget --spider -q http://localhost:5678/healthz || exit 1

# Note: The base n8n image already has the correct CMD and ENTRYPOINT
# We don't need to override it
