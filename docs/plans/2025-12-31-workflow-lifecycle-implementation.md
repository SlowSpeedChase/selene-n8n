# Workflow Lifecycle Management Implementation Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** Implement git-first workflow management to prevent n8n database clutter with sync, status, cleanup, and init commands.

**Architecture:** Enhance `scripts/manage-workflow.sh` with new commands. Use `.workflow-ids.json` mapping file (gitignored) to track n8n IDs. Sync injects IDs into workflow JSON before import to enable in-place updates.

**Tech Stack:** Bash, jq (JSON manipulation), SQLite (n8n database queries), Docker exec for n8n CLI

**Design Doc:** `docs/plans/2025-12-31-workflow-lifecycle-management-design.md`

---

## Task 1: Setup - Add Mapping File Template and Gitignore

**Files:**
- Create: `.workflow-ids.example.json`
- Modify: `.gitignore`

**Step 1: Create example mapping file**

Create `.workflow-ids.example.json`:
```json
{
  "_comment": "Copy to .workflow-ids.json and populate with your n8n workflow IDs",
  "01-ingestion": "your-n8n-id-here",
  "02-llm-processing": "your-n8n-id-here"
}
```

**Step 2: Add .workflow-ids.json to gitignore**

Add to `.gitignore`:
```
# Workflow ID mapping (environment-specific)
.workflow-ids.json
```

**Step 3: Commit**

```bash
git add .workflow-ids.example.json .gitignore
git commit -m "chore: add workflow ID mapping template and gitignore"
```

---

## Task 2: Implement Helper Functions

**Files:**
- Modify: `scripts/manage-workflow.sh`

**Step 1: Add jq dependency check**

Add after existing helper functions (around line 38):
```bash
# Check for jq (required for JSON manipulation)
check_jq() {
    if ! command -v jq &> /dev/null; then
        log_error "jq is required but not installed"
        log_info "Install with: brew install jq"
        exit 1
    fi
}
```

**Step 2: Add mapping file functions**

Add after `check_jq`:
```bash
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
```

**Step 3: Add n8n database query function**

Add after mapping functions:
```bash
# Query n8n database directly
query_n8n_db() {
    local query="$1"
    docker exec "$CONTAINER_NAME" sh -c "sqlite3 /home/node/.n8n/database.sqlite \"$query\""
}

# Get all workflows from n8n
get_n8n_workflows() {
    query_n8n_db "SELECT id, name, active FROM workflow_entity ORDER BY name;"
}
```

**Step 4: Verify syntax**

```bash
bash -n scripts/manage-workflow.sh && echo "SYNTAX OK"
```
Expected: `SYNTAX OK`

**Step 5: Commit**

```bash
git add scripts/manage-workflow.sh
git commit -m "feat: add helper functions for workflow ID mapping"
```

---

## Task 3: Implement `status` Command

**Files:**
- Modify: `scripts/manage-workflow.sh`

**Step 1: Add status function**

Add before the `usage()` function:
```bash
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
```

**Step 2: Add status to case statement**

Find the `case "$command" in` block and add after the `backup-creds)` case:
```bash
        status)
            status_workflows
            ;;
```

**Step 3: Update usage text**

In the `usage()` function, add to the Commands section:
```bash
  ${BLUE}status${NC}                        Show sync status and orphaned workflows
```

**Step 4: Verify syntax**

```bash
bash -n scripts/manage-workflow.sh && echo "SYNTAX OK"
```
Expected: `SYNTAX OK`

**Step 5: Commit**

```bash
git add scripts/manage-workflow.sh
git commit -m "feat: add status command to show sync state and orphans"
```

---

## Task 4: Implement `init` Command

**Files:**
- Modify: `scripts/manage-workflow.sh`

**Step 1: Add init function**

Add after `status_workflows` function:
```bash
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
```

**Step 2: Add init to case statement**

Add to the case statement:
```bash
        init)
            init_mapping
            ;;
```

**Step 3: Update usage text**

Add to Commands section:
```bash
  ${BLUE}init${NC}                          Initialize mapping file from current n8n state
```

**Step 4: Verify syntax**

```bash
bash -n scripts/manage-workflow.sh && echo "SYNTAX OK"
```
Expected: `SYNTAX OK`

**Step 5: Commit**

```bash
git add scripts/manage-workflow.sh
git commit -m "feat: add init command to create mapping from n8n state"
```

---

## Task 5: Implement `sync` Command

**Files:**
- Modify: `scripts/manage-workflow.sh`

**Step 1: Add sync single workflow function**

Add after `init_mapping` function:
```bash
# Sync a single workflow from git to n8n
sync_single_workflow() {
    local workflow_name="$1"
    local workflow_dir="$WORKFLOWS_DIR/$workflow_name"
    local workflow_file="$workflow_dir/workflow.json"

    if [ ! -f "$workflow_file" ]; then
        log_error "Workflow file not found: $workflow_file"
        return 1
    fi

    local mapped_id=$(get_mapped_id "$workflow_name")
    local tmp_file=$(mktemp)

    if [ -n "$mapped_id" ]; then
        # Update existing: inject ID into workflow JSON
        log_step "Updating $workflow_name → $mapped_id"
        jq --arg id "$mapped_id" '.id = $id' "$workflow_file" > "$tmp_file"
    else
        # New workflow: import without ID, capture new ID after
        log_step "Creating new workflow: $workflow_name"
        cp "$workflow_file" "$tmp_file"
    fi

    # Copy to container and import
    local container_path="/tmp/workflow-import-$$.json"
    docker cp "$tmp_file" "$CONTAINER_NAME:$container_path"

    # Import workflow
    local import_output
    import_output=$(docker exec "$CONTAINER_NAME" n8n import:workflow --input="$container_path" 2>&1)
    local import_status=$?

    # Cleanup temp files
    rm -f "$tmp_file"
    docker exec "$CONTAINER_NAME" rm -f "$container_path" 2>/dev/null || true

    if [ $import_status -ne 0 ]; then
        log_error "Import failed for $workflow_name"
        echo "$import_output"
        return 1
    fi

    # If new workflow, find and save the ID
    if [ -z "$mapped_id" ]; then
        # Get workflow name from JSON to find in n8n
        local json_name=$(jq -r '.name' "$workflow_file")
        local new_id=$(query_n8n_db "SELECT id FROM workflow_entity WHERE name = '$json_name' ORDER BY createdAt DESC LIMIT 1;")

        if [ -n "$new_id" ]; then
            set_mapped_id "$workflow_name" "$new_id"
            log_info "  New ID captured: $new_id"
        else
            log_warn "  Could not capture new workflow ID"
        fi
    fi

    log_info "✓ $workflow_name synced"
}

# Sync all or specific workflow
sync_workflows() {
    check_jq

    local target="${1:-}"

    if [ -n "$target" ]; then
        # Sync single workflow
        sync_single_workflow "$target"
    else
        # Sync all workflows
        log_info "Syncing all workflows from git to n8n..."
        echo ""

        local workflow_dirs=$(find "$WORKFLOWS_DIR" -maxdepth 1 -type d -name "[0-9]*" | sort)
        local success_count=0
        local fail_count=0

        for dir in $workflow_dirs; do
            if [ -f "$dir/workflow.json" ]; then
                local name=$(get_workflow_name "$dir")
                if sync_single_workflow "$name"; then
                    success_count=$((success_count + 1))
                else
                    fail_count=$((fail_count + 1))
                fi
            fi
        done

        echo ""
        log_info "Sync complete: $success_count succeeded, $fail_count failed"

        # Check for orphans
        local orphan_count=$(get_n8n_workflows | while IFS='|' read -r id name active; do
            if [ -n "$id" ]; then
                local tracked=$(get_all_tracked_ids)
                if ! echo "$tracked" | grep -q "$id"; then
                    echo "$id"
                fi
            fi
        done | wc -l | tr -d ' ')

        if [ "$orphan_count" -gt 0 ]; then
            log_warn "$orphan_count orphaned workflows in n8n (run 'status' for details)"
        fi
    fi
}
```

**Step 2: Add sync to case statement**

Add to the case statement:
```bash
        sync)
            sync_workflows "${2:-}"
            ;;
```

**Step 3: Update usage text**

Add to Commands section:
```bash
  ${BLUE}sync${NC} [name]                    Sync workflow(s) from git to n8n
```

**Step 4: Verify syntax**

```bash
bash -n scripts/manage-workflow.sh && echo "SYNTAX OK"
```
Expected: `SYNTAX OK`

**Step 5: Commit**

```bash
git add scripts/manage-workflow.sh
git commit -m "feat: add sync command to push git workflows to n8n"
```

---

## Task 6: Implement `cleanup` Command

**Files:**
- Modify: `scripts/manage-workflow.sh`

**Step 1: Add cleanup function**

Add after `sync_workflows` function:
```bash
# Clean up orphaned workflows
cleanup_workflows() {
    check_jq

    local force="${1:-}"

    log_info "Finding orphaned workflows..."

    # Get tracked IDs
    local tracked_ids=$(get_all_tracked_ids)

    # Find orphans
    local orphans=""
    local orphan_count=0

    while IFS='|' read -r id name active; do
        if [ -n "$id" ]; then
            if ! echo "$tracked_ids" | grep -q "^${id}$"; then
                orphans="$orphans$id|$name|$active\n"
                orphan_count=$((orphan_count + 1))
            fi
        fi
    done <<< "$(get_n8n_workflows)"

    if [ "$orphan_count" -eq 0 ]; then
        log_info "No orphaned workflows found"
        return 0
    fi

    echo ""
    echo "Found $orphan_count orphaned workflows:"
    echo ""
    printf "  %-20s  %-35s  %s\n" "ID" "Name" "Status"
    printf "  %-20s  %-35s  %s\n" "--------------------" "-----------------------------------" "------"

    echo -e "$orphans" | while IFS='|' read -r id name active; do
        if [ -n "$id" ]; then
            local status="inactive"
            [ "$active" = "1" ] && status="ACTIVE"
            printf "  %-20s  %-35s  %s\n" "$id" "$name" "$status"
        fi
    done

    echo ""

    # Check for active workflows
    local active_count=$(echo -e "$orphans" | grep "|1$" | grep -v "^$" | wc -l | tr -d ' ')
    if [ "$active_count" -gt 0 ]; then
        log_warn "$active_count orphaned workflows are ACTIVE"
        log_warn "Active workflows will NOT be deleted (disable them first)"
    fi

    # Confirm deletion
    if [ "$force" != "--force" ]; then
        read -p "Delete all inactive orphaned workflows? [y/N]: " -n 1 -r
        echo
        if [[ ! $REPLY =~ ^[Yy]$ ]]; then
            log_info "Aborted"
            return 0
        fi
    fi

    # Delete orphans (skip active)
    local deleted=0
    echo -e "$orphans" | while IFS='|' read -r id name active; do
        if [ -n "$id" ] && [ "$active" != "1" ]; then
            log_step "Deleting: $id ($name)"
            if docker exec "$CONTAINER_NAME" n8n delete:workflow --id="$id" 2>/dev/null; then
                log_info "  ✓ Deleted"
                deleted=$((deleted + 1))
            else
                log_error "  Failed to delete"
            fi
        fi
    done

    echo ""
    log_info "Cleanup complete"
}
```

**Step 2: Add cleanup to case statement**

Add to the case statement:
```bash
        cleanup)
            cleanup_workflows "${2:-}"
            ;;
```

**Step 3: Update usage text**

Add to Commands section:
```bash
  ${BLUE}cleanup${NC} [--force]              Delete orphaned workflows from n8n
```

**Step 4: Verify syntax**

```bash
bash -n scripts/manage-workflow.sh && echo "SYNTAX OK"
```
Expected: `SYNTAX OK`

**Step 5: Commit**

```bash
git add scripts/manage-workflow.sh
git commit -m "feat: add cleanup command to remove orphaned workflows"
```

---

## Task 7: Integration Testing

**Files:**
- None (testing only)

**Step 1: Run init to create mapping**

```bash
./scripts/manage-workflow.sh init
```
Expected: Mapping file created with IDs for each workflow

**Step 2: Check status**

```bash
./scripts/manage-workflow.sh status
```
Expected: Shows synced workflows and lists orphans

**Step 3: Test sync on single workflow**

```bash
./scripts/manage-workflow.sh sync 01-ingestion
```
Expected: Workflow synced successfully

**Step 4: Run cleanup (inspect only)**

```bash
./scripts/manage-workflow.sh cleanup
```
When prompted, answer `n` first to inspect. Then run again with `y` if ready to clean.

**Step 5: Verify clean state**

```bash
./scripts/manage-workflow.sh status
```
Expected: No orphans (or only active orphans if any were skipped)

---

## Task 8: Update Documentation

**Files:**
- Modify: `scripts/CLAUDE.md`

**Step 1: Update manage-workflow.sh section**

Find the `## manage-workflow.sh` section and add the new commands to the Usage block:

```bash
# New lifecycle commands
./scripts/manage-workflow.sh status              # Show sync state and orphans
./scripts/manage-workflow.sh init                # Initialize mapping from n8n
./scripts/manage-workflow.sh sync [name]         # Sync git → n8n
./scripts/manage-workflow.sh cleanup [--force]   # Remove orphaned workflows
```

**Step 2: Add workflow lifecycle section**

Add new section after the existing manage-workflow.sh documentation:

```markdown
### Workflow Lifecycle Management

The script now includes git-first workflow lifecycle management:

**Source of Truth:** `workflows/XX-name/workflow.json` files in git

**ID Mapping:** `.workflow-ids.json` (gitignored) maps logical names to n8n IDs

**Daily Workflow:**
```bash
# 1. Edit workflow JSON in git
# 2. Push to n8n
./scripts/manage-workflow.sh sync 07-task-extraction

# 3. Test
./workflows/07-task-extraction/scripts/test-with-markers.sh

# 4. Commit
git add workflows/07-task-extraction/workflow.json
git commit -m "feat(07): description"
```

**First-Time Setup:**
```bash
./scripts/manage-workflow.sh init     # Create mapping from current n8n state
./scripts/manage-workflow.sh status   # Review
./scripts/manage-workflow.sh cleanup  # Remove old versions
```
```

**Step 3: Commit**

```bash
git add scripts/CLAUDE.md
git commit -m "docs: update script documentation with lifecycle commands"
```

---

## Task 9: Final Commit and Cleanup

**Step 1: Verify all changes**

```bash
git status
git log --oneline -10
```

**Step 2: Run full test cycle**

```bash
./scripts/manage-workflow.sh status
```

**Step 3: Create summary commit if needed**

If any uncommitted changes remain:
```bash
git add -A
git commit -m "chore: workflow lifecycle management implementation complete"
```

---

## Completion Checklist

- [ ] `.workflow-ids.example.json` created
- [ ] `.workflow-ids.json` in `.gitignore`
- [ ] Helper functions added (jq check, mapping file operations, n8n queries)
- [ ] `status` command working
- [ ] `init` command working
- [ ] `sync` command working
- [ ] `cleanup` command working
- [ ] Documentation updated
- [ ] All tests passing
- [ ] All changes committed
