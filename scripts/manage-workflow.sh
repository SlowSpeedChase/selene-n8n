#!/bin/bash
# Script Purpose: Manage n8n workflows via CLI (export, import, list)
# Usage: ./scripts/manage-workflow.sh [command] [options]

set -e  # Exit on error
set -u  # Exit on undefined variable

# Color output for readability
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
BLUE='\033[0;34m'
NC='\033[0m'  # No Color

# Configuration
CONTAINER_NAME="selene-n8n"
WORKFLOWS_DIR="./workflows"

# Helper functions
log_info() {
    echo -e "${GREEN}[INFO]${NC} $1"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

log_warn() {
    echo -e "${YELLOW}[WARN]${NC} $1"
}

log_step() {
    echo -e "${BLUE}[STEP]${NC} $1"
}

# Check if container is running
check_container() {
    if ! docker ps --format '{{.Names}}' | grep -q "^${CONTAINER_NAME}$"; then
        log_error "Container '${CONTAINER_NAME}' is not running"
        log_info "Start it with: docker-compose up -d"
        exit 1
    fi
}

# List all workflows
list_workflows() {
    log_info "Listing all workflows..."
    docker exec "$CONTAINER_NAME" n8n list:workflow
}

# Export workflow
export_workflow() {
    local workflow_id="$1"
    local output_file="${2:-}"

    if [ -z "$workflow_id" ]; then
        log_error "Usage: $0 export <workflow-id> [output-file]"
        exit 1
    fi

    # If no output file specified, create timestamped backup
    if [ -z "$output_file" ]; then
        output_file="/workflows/backup-${workflow_id}-$(date +%Y%m%d-%H%M%S).json"
        log_info "No output file specified, using: $output_file"
    fi

    log_step "Exporting workflow ID: $workflow_id"
    docker exec "$CONTAINER_NAME" n8n export:workflow --id="$workflow_id" --output="$output_file"
    log_info "✓ Workflow exported to: $output_file"
}

# Import workflow
import_workflow() {
    local input_file="$1"
    local separate="${2:-false}"

    if [ -z "$input_file" ]; then
        log_error "Usage: $0 import <input-file> [--separate]"
        exit 1
    fi

    log_step "Importing workflow from: $input_file"

    if [ "$separate" = "--separate" ]; then
        docker exec "$CONTAINER_NAME" n8n import:workflow --input="$input_file" --separate
        log_info "✓ Workflow imported as separate instance"
    else
        docker exec "$CONTAINER_NAME" n8n import:workflow --input="$input_file"
        log_info "✓ Workflow imported"
    fi
}

# Update workflow (export backup, then import)
update_workflow() {
    local workflow_id="$1"
    local input_file="$2"

    if [ -z "$workflow_id" ] || [ -z "$input_file" ]; then
        log_error "Usage: $0 update <workflow-id> <input-file>"
        exit 1
    fi

    # Create backup first
    log_step "Creating backup of workflow $workflow_id..."
    export_workflow "$workflow_id"

    # Import updated version
    log_step "Importing updated workflow..."
    import_workflow "$input_file" "--separate"

    log_info "✓ Workflow updated successfully"
}

# Show workflow details
show_workflow() {
    local workflow_id="$1"

    if [ -z "$workflow_id" ]; then
        log_error "Usage: $0 show <workflow-id>"
        exit 1
    fi

    log_info "Showing details for workflow ID: $workflow_id"
    docker exec "$CONTAINER_NAME" n8n show:workflow --id="$workflow_id"
}

# Export credentials (backup)
export_credentials() {
    local output_file="${1:-/workflows/credentials-backup-$(date +%Y%m%d-%H%M%S).json}"

    log_step "Exporting credentials..."
    log_warn "Credentials contain sensitive data - handle with care!"
    docker exec "$CONTAINER_NAME" n8n export:credentials --output="$output_file"
    log_info "✓ Credentials exported to: $output_file"
}

# Interactive workflow selection
select_workflow() {
    log_info "Fetching workflows..."
    docker exec "$CONTAINER_NAME" n8n list:workflow

    echo ""
    read -p "Enter workflow ID: " workflow_id
    echo "$workflow_id"
}

# Show usage
usage() {
    cat <<EOF
${GREEN}n8n Workflow Management Script${NC}

${YELLOW}Usage:${NC}
  $0 <command> [options]

${YELLOW}Commands:${NC}
  ${BLUE}list${NC}                          List all workflows
  ${BLUE}show${NC} <id>                     Show workflow details
  ${BLUE}export${NC} <id> [output]          Export workflow to JSON
  ${BLUE}import${NC} <file> [--separate]    Import workflow from JSON
  ${BLUE}update${NC} <id> <file>            Update workflow (backup + import)
  ${BLUE}backup-creds${NC} [output]         Export credentials to JSON

${YELLOW}Examples:${NC}
  # List all workflows
  $0 list

  # Export specific workflow
  $0 export 1 /workflows/01-ingestion/workflow.json

  # Import workflow
  $0 import /workflows/01-ingestion/workflow.json

  # Update existing workflow (creates backup first)
  $0 update 1 /workflows/01-ingestion/workflow.json

  # Backup credentials
  $0 backup-creds

${YELLOW}Interactive Mode:${NC}
  # Export with workflow selection
  $0 export

  # Show with workflow selection
  $0 show

${YELLOW}Notes:${NC}
  - Container must be running (docker-compose up -d)
  - File paths are relative to container (/workflows maps to ./workflows)
  - Backups are timestamped automatically
  - Always test workflows after importing changes

EOF
}

# Main script logic
main() {
    # Check if container is running
    check_container

    local command="${1:-}"

    case "$command" in
        list)
            list_workflows
            ;;
        show)
            if [ $# -eq 1 ]; then
                # Interactive mode
                workflow_id=$(select_workflow)
                show_workflow "$workflow_id"
            else
                show_workflow "$2"
            fi
            ;;
        export)
            if [ $# -eq 1 ]; then
                # Interactive mode
                workflow_id=$(select_workflow)
                export_workflow "$workflow_id"
            else
                export_workflow "${2:-}" "${3:-}"
            fi
            ;;
        import)
            import_workflow "${2:-}" "${3:-}"
            ;;
        update)
            update_workflow "${2:-}" "${3:-}"
            ;;
        backup-creds)
            export_credentials "${2:-}"
            ;;
        help|--help|-h)
            usage
            ;;
        "")
            log_error "No command specified"
            usage
            exit 1
            ;;
        *)
            log_error "Unknown command: $command"
            usage
            exit 1
            ;;
    esac
}

# Run main function
main "$@"
