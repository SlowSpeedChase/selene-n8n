#!/bin/bash
# Story Management Script
set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"
STORIES_DIR="$PROJECT_ROOT/docs/stories"
TEMPLATE="$STORIES_DIR/templates/STORY-TEMPLATE.md"

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
BLUE='\033[0;34m'
NC='\033[0m'

get_next_id() {
    local max_id=0
    local files
    files=$(find "$STORIES_DIR" -name "US-*.md" 2>/dev/null || true)
    for file in $files; do
        if [[ -f "$file" ]]; then
            id=$(basename "$file" | grep -oE 'US-[0-9]+' | sed 's/US-//')
            if [[ "$id" -gt "$max_id" ]]; then
                max_id=$id
            fi
        fi
    done
    printf "%03d" $((max_id + 1))
}

cmd_status() {
    echo ""
    echo -e "${GREEN}=== User Story Status ===${NC}"
    echo ""

    local active=$(find "$STORIES_DIR/active" -name "US-*.md" 2>/dev/null | wc -l | tr -d ' ')
    if [[ "$active" -ge 5 ]]; then
        echo -e "${RED}Active:  $active/5 (at max!)${NC}"
    else
        echo -e "Active:  ${BLUE}$active${NC}/5"
    fi
    find "$STORIES_DIR/active" -name "US-*.md" 2>/dev/null | xargs -I{} basename {} | sed 's/^/  /' || true

    local ready=$(find "$STORIES_DIR/ready" -name "US-*.md" 2>/dev/null | wc -l | tr -d ' ')
    echo -e "Ready:   ${BLUE}$ready${NC}"

    local draft=$(find "$STORIES_DIR/draft" -name "US-*.md" 2>/dev/null | wc -l | tr -d ' ')
    echo -e "Draft:   ${BLUE}$draft${NC}"

    local done=$(find "$STORIES_DIR/done" -name "US-*.md" 2>/dev/null | wc -l | tr -d ' ')
    echo -e "Done:    ${BLUE}$done${NC}"
    echo ""
}

cmd_new() {
    local title="$1"
    if [[ -z "$title" ]]; then
        echo -e "${RED}Usage: $0 new <title-in-kebab-case>${NC}"
        exit 1
    fi

    local next_id=$(get_next_id)
    local filename="US-$next_id-$title.md"
    local filepath="$STORIES_DIR/draft/$filename"

    cp "$TEMPLATE" "$filepath"

    # macOS sed vs GNU sed compatibility
    if [[ "$(uname)" == "Darwin" ]]; then
        sed -i '' "s/{NNN}/$next_id/g" "$filepath"
        sed -i '' "s/{Title}/$title/g" "$filepath"
        sed -i '' "s/YYYY-MM-DD/$(date +%Y-%m-%d)/g" "$filepath"
    else
        sed -i "s/{NNN}/$next_id/g" "$filepath"
        sed -i "s/{Title}/$title/g" "$filepath"
        sed -i "s/YYYY-MM-DD/$(date +%Y-%m-%d)/g" "$filepath"
    fi

    echo -e "${GREEN}Created:${NC} $filepath"
    echo ""
    echo "Next steps:"
    echo "  1. Edit the story file"
    echo "  2. Run: $0 promote US-$next_id"
}

cmd_promote() {
    local story_id="$1"
    if [[ -z "$story_id" ]]; then
        echo -e "${RED}Usage: $0 promote <US-XXX>${NC}"
        exit 1
    fi

    local story_file="" current_state=""
    for state in draft ready active; do
        local found=$(find "$STORIES_DIR/$state" -name "$story_id-*.md" 2>/dev/null | head -1)
        if [[ -n "$found" ]]; then
            story_file="$found"
            current_state="$state"
            break
        fi
    done

    if [[ -z "$story_file" ]]; then
        echo -e "${RED}Story not found: $story_id${NC}"
        exit 1
    fi

    local next_state=""
    case "$current_state" in
        draft) next_state="ready" ;;
        ready) next_state="active" ;;
        active) next_state="done" ;;
    esac

    if [[ "$next_state" == "active" ]]; then
        local count=$(find "$STORIES_DIR/active" -name "US-*.md" 2>/dev/null | wc -l | tr -d ' ')
        if [[ "$count" -ge 5 ]]; then
            echo -e "${RED}Active stories at max (5). Complete one first.${NC}"
            exit 1
        fi
    fi

    mv "$story_file" "$STORIES_DIR/$next_state/$(basename "$story_file")"
    echo -e "${GREEN}Moved:${NC} $current_state -> $next_state"
    echo -e "${YELLOW}Remember to update docs/stories/INDEX.md${NC}"

    if [[ "$next_state" == "active" ]]; then
        local kebab_title=$(basename "$story_file" .md | sed "s/$story_id-//")
        echo ""
        echo "Create branch with:"
        echo "  git worktree add -b $story_id/$kebab_title .worktrees/$kebab_title main"
    fi
}

cmd_list() {
    local state="${1:-all}"

    if [[ "$state" == "all" ]]; then
        for s in active ready draft done; do
            echo -e "${GREEN}=== $s ===${NC}"
            find "$STORIES_DIR/$s" -name "US-*.md" 2>/dev/null | xargs -I{} basename {} | sort || echo "  (none)"
            echo ""
        done
    else
        if [[ ! -d "$STORIES_DIR/$state" ]]; then
            echo -e "${RED}Unknown state: $state${NC}"
            echo "Valid states: draft, ready, active, done"
            exit 1
        fi
        find "$STORIES_DIR/$state" -name "US-*.md" 2>/dev/null | xargs -I{} basename {} | sort || echo "(none)"
    fi
}

case "${1:-}" in
    status) cmd_status ;;
    new) cmd_new "$2" ;;
    promote) cmd_promote "$2" ;;
    list) cmd_list "$2" ;;
    *)
        echo "Usage: $0 <command>"
        echo ""
        echo "Commands:"
        echo "  status            Show story counts by state"
        echo "  new <title>       Create new story in draft/"
        echo "  promote <US-XXX>  Move story to next state"
        echo "  list [state]      List stories (all, draft, ready, active, done)"
        ;;
esac
