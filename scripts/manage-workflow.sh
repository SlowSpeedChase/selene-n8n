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

# Dev mode flag
DEV_MODE=false
DEV_CONTAINER_NAME="selene-n8n-dev"

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

# Check for jq (required for JSON manipulation)
check_jq() {
    if ! command -v jq &> /dev/null; then
        log_error "jq is required but not installed"
        log_info "Install with: brew install jq"
        exit 1
    fi
}

# Mapping file path
MAPPING_FILE="./.workflow-ids.json"

# Get workflow ID from mapping file
get_mapped_id() {
    local workflow_name="$1"
    if [ -f "$MAPPING_FILE" ]; then
        jq -r --arg name "$workflow_name" '.[$name] // empty' "$MAPPING_FILE"
    fi
}

# Set workflow ID in mapping file
set_mapped_id() {
    local workflow_name="$1"
    local workflow_id="$2"

    if [ ! -f "$MAPPING_FILE" ]; then
        echo "{}" > "$MAPPING_FILE"
    fi

    local tmp=$(mktemp)
    jq --arg name "$workflow_name" --arg id "$workflow_id" '.[$name] = $id' "$MAPPING_FILE" > "$tmp"
    mv "$tmp" "$MAPPING_FILE"
}

# Get all tracked IDs from mapping file
get_all_tracked_ids() {
    if [ -f "$MAPPING_FILE" ]; then
        jq -r 'to_entries[] | select(.key != "_comment") | .value' "$MAPPING_FILE"
    fi
}

# Extract workflow name from directory path (e.g., "workflows/07-task-extraction" -> "07-task-extraction")
get_workflow_name() {
    local dir="$1"
    basename "$dir"
}

# Query n8n database directly
query_n8n_db() {
    local query="$1"
    docker exec "$CONTAINER_NAME" sh -c "sqlite3 /home/node/.n8n/database.sqlite \"$query\""
}

# Get all workflows from n8n
get_n8n_workflows() {
    query_n8n_db "SELECT id, name, active FROM workflow_entity ORDER BY name;"
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

# Show sync status
status_workflows() {
    check_jq

    log_info "Checking workflow sync status..."
    echo ""

    # Get all workflow directories
    local workflow_dirs=$(find "$WORKFLOWS_DIR" -maxdepth 1 -type d -name "[0-9]*" | sort)

    # Get all n8n workflows
    local n8n_data=$(get_n8n_workflows)

    # Collect tracked IDs
    local tracked_ids=""

    echo "=== Synced Workflows ==="
    for dir in $workflow_dirs; do
        if [ -f "$dir/workflow.json" ]; then
            local name=$(get_workflow_name "$dir")
            local mapped_id=$(get_mapped_id "$name")

            if [ -n "$mapped_id" ]; then
                # Check if exists in n8n
                local n8n_info=$(echo "$n8n_data" | grep "^${mapped_id}|" || true)
                if [ -n "$n8n_info" ]; then
                    local active=$(echo "$n8n_info" | cut -d'|' -f3)
                    local status_icon="inactive"
                    [ "$active" = "1" ] && status_icon="active"
                    printf "  %-25s → %s (%s)\n" "$name" "$mapped_id" "$status_icon"
                    tracked_ids="$tracked_ids $mapped_id"
                else
                    printf "  %-25s → %s (NOT IN N8N!)\n" "$name" "$mapped_id"
                fi
            else
                printf "  %-25s → (not mapped)\n" "$name"
            fi
        fi
    done

    echo ""
    echo "=== Orphaned in n8n (not tracked in git) ==="
    local orphan_count=0
    while IFS='|' read -r id name active; do
        if [ -n "$id" ]; then
            # Check if this ID is tracked
            if ! echo "$tracked_ids" | grep -q "$id"; then
                local status_icon="inactive"
                [ "$active" = "1" ] && status_icon="ACTIVE"
                printf "  %-20s  %-30s (%s)\n" "$id" "$name" "$status_icon"
                orphan_count=$((orphan_count + 1))
            fi
        fi
    done <<< "$n8n_data"

    if [ "$orphan_count" -eq 0 ]; then
        echo "  (none)"
    fi

    echo ""
    echo "=== Summary ==="
    echo "  Orphaned workflows: $orphan_count"
    if [ "$orphan_count" -gt 0 ]; then
        log_warn "Run './scripts/manage-workflow.sh cleanup' to remove orphans"
    fi
}

# Initialize mapping file from current n8n state
init_mapping() {
    check_jq

    log_info "Initializing workflow ID mapping..."

    if [ -f "$MAPPING_FILE" ]; then
        log_warn "Mapping file already exists: $MAPPING_FILE"
        read -p "Overwrite? [y/N]: " -n 1 -r
        echo
        if [[ ! $REPLY =~ ^[Yy]$ ]]; then
            log_info "Aborted"
            return 1
        fi
    fi

    # Start fresh mapping
    echo "{}" > "$MAPPING_FILE"

    # Get all workflow directories
    local workflow_dirs=$(find "$WORKFLOWS_DIR" -maxdepth 1 -type d -name "[0-9]*" | sort)

    # Get all n8n workflows
    local n8n_data=$(get_n8n_workflows)

    for dir in $workflow_dirs; do
        if [ -f "$dir/workflow.json" ]; then
            local name=$(get_workflow_name "$dir")
            log_step "Finding n8n ID for: $name"

            # Find matching workflows in n8n (match on name pattern)
            # Use the directory name pattern (e.g., "07-task-extraction" matches "07-Task-Extraction")
            local prefix=$(echo "$name" | cut -d'-' -f1)  # Get "07" from "07-task-extraction"
            local matches=$(echo "$n8n_data" | grep "^.*|${prefix}-" || true)

            if [ -z "$matches" ]; then
                log_warn "  No match found in n8n for: $name"
                continue
            fi

            # Count matches
            local match_count=$(echo "$matches" | wc -l | tr -d ' ')

            if [ "$match_count" -eq 1 ]; then
                local id=$(echo "$matches" | cut -d'|' -f1)
                local n8n_name=$(echo "$matches" | cut -d'|' -f2)
                set_mapped_id "$name" "$id"
                log_info "  Mapped: $name → $id ($n8n_name)"
            else
                # Multiple matches - prefer active one
                local active_match=$(echo "$matches" | grep "|1$" | head -1)
                if [ -n "$active_match" ]; then
                    local id=$(echo "$active_match" | cut -d'|' -f1)
                    local n8n_name=$(echo "$active_match" | cut -d'|' -f2)
                    set_mapped_id "$name" "$id"
                    log_warn "  Multiple matches, using active: $name → $id ($n8n_name)"
                else
                    log_error "  Multiple inactive matches for $name - please resolve manually:"
                    echo "$matches" | while IFS='|' read -r id n8n_name active; do
                        echo "    $id  $n8n_name"
                    done
                fi
            fi
        fi
    done

    echo ""
    log_info "Mapping file created: $MAPPING_FILE"
    log_info "Run './scripts/manage-workflow.sh status' to review"
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
  ${BLUE}status${NC}                        Show sync status and orphaned workflows
  ${BLUE}init${NC}                          Initialize mapping file from current n8n state

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

${YELLOW}Dev Mode:${NC}
  Add --dev flag to target development environment
  $0 --dev list
  $0 --dev export 1
  $0 --dev update 1 /workflows/01-ingestion/workflow.json

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
        status)
            status_workflows
            ;;
        init)
            init_mapping
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

# Parse global flags
ARGS=()
while [[ $# -gt 0 ]]; do
    case "$1" in
        --dev)
            DEV_MODE=true
            CONTAINER_NAME="$DEV_CONTAINER_NAME"
            shift
            ;;
        *)
            ARGS+=("$1")
            shift
            ;;
    esac
done
set -- "${ARGS[@]}"

# Run main function
main "$@"
