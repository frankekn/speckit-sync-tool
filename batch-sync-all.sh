#!/usr/bin/env bash
#
# Batch sync spec-kit commands across multiple projects
#
# Usage:
#   ./batch-sync-all.sh                    # Interactive mode
#   ./batch-sync-all.sh --auto             # Auto mode (no prompts)
#   ./batch-sync-all.sh --check-only       # Check only, no updates
#

set -e

# ============================================================================
# Configuration
# ============================================================================

# GitHub directory (adjust according to your environment)
GITHUB_DIR="${GITHUB_DIR:-$HOME/Documents/GitHub}"

# spec-kit path
SPECKIT_PATH="${SPECKIT_PATH:-$GITHUB_DIR/spec-kit}"

# Sync tool path (this script's directory)
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SYNC_TOOL="$SCRIPT_DIR/sync-commands-integrated.sh"

# Project list (can be customized)
# If empty, will auto-scan all projects with .claude/commands directory
PROJECTS=()

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
MAGENTA='\033[0;35m'
NC='\033[0m' # No Color

# ============================================================================
# Helper functions
# ============================================================================

log_info() {
    echo -e "${BLUE}ℹ${NC} $1"
}

log_success() {
    echo -e "${GREEN}✓${NC} $1"
}

log_warning() {
    echo -e "${YELLOW}⚠${NC} $1"
}

log_error() {
    echo -e "${RED}✗${NC} $1"
}

log_header() {
    echo ""
    echo -e "${CYAN}╔════════════════════════════════════════════════════╗${NC}"
    echo -e "${CYAN}║ $1${NC}"
    echo -e "${CYAN}╚════════════════════════════════════════════════════╝${NC}"
}

log_section() {
    echo ""
    echo -e "${MAGENTA}▶ $1${NC}"
    echo -e "${MAGENTA}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
}

# ============================================================================
# Project scanning
# ============================================================================

scan_projects() {
    local found_projects=()

    for dir in "$GITHUB_DIR"/*; do
        [ -d "$dir" ] || continue

        local project_name=$(basename "$dir")

        # Skip spec-kit and sync tool itself
        if [ "$project_name" = "spec-kit" ] || [ "$project_name" = "speckit-sync-tool" ]; then
            continue
        fi

        # Check if has .claude/commands directory
        if [ -d "$dir/.claude/commands" ]; then
            found_projects+=("$project_name")
        fi
    done

    echo "${found_projects[@]}"
}

# ============================================================================
# Main functionality
# ============================================================================

process_project() {
    local project_name="$1"
    local mode="${2:-interactive}"
    local project_dir="$GITHUB_DIR/$project_name"

    log_section "Processing project: $project_name"

    cd "$project_dir"

    # Check if initialized
    if [ ! -f ".speckit-sync.json" ]; then
        log_warning "Project not initialized"

        if [ "$mode" = "interactive" ]; then
            echo -n "Initialize this project? [y/N] "
            read -r ans
            if [ "${ans:-N}" = "y" ]; then
                $SYNC_TOOL init
            else
                log_info "Skipped initialization"
                return 1
            fi
        elif [ "$mode" = "auto" ]; then
            log_info "Auto-initializing..."
            SPECKIT_PATH="$SPECKIT_PATH" $SYNC_TOOL init
        else
            return 1
        fi
    fi

    # Run check
    echo ""
    SPECKIT_PATH="$SPECKIT_PATH" $SYNC_TOOL check

    # Decide whether to update based on mode
    if [ "$mode" = "check-only" ]; then
        log_info "Check-only mode, skipping update"
        return 0
    fi

    echo ""

    if [ "$mode" = "interactive" ]; then
        echo -n "Update this project? [y/N] "
        read -r ans
        if [ "${ans:-N}" = "y" ]; then
            SPECKIT_PATH="$SPECKIT_PATH" $SYNC_TOOL update
            return 0
        else
            log_info "Skipped update"
            return 1
        fi
    elif [ "$mode" = "auto" ]; then
        log_info "Auto-updating..."
        SPECKIT_PATH="$SPECKIT_PATH" $SYNC_TOOL update
        return 0
    fi
}

update_speckit_repo() {
    # Check if it's a git repository
    if [ ! -d "$SPECKIT_PATH/.git" ]; then
        log_warning "spec-kit is not a git repository, skipping auto-update"
        return 0
    fi

    log_info "Checking for spec-kit updates..."

    # Switch to spec-kit directory
    cd "$SPECKIT_PATH"

    # Check for uncommitted changes
    if ! git diff-index --quiet HEAD -- 2>/dev/null; then
        log_warning "spec-kit has uncommitted changes, skipping auto-update"
        log_info "Please handle manually: cd $SPECKIT_PATH && git status"
        cd - >/dev/null
        return 0
    fi

    # Get current branch
    local current_branch=$(git rev-parse --abbrev-ref HEAD)

    # Fetch latest version
    git fetch origin --quiet 2>/dev/null || {
        log_warning "Cannot connect to remote repository, using local version"
        cd - >/dev/null
        return 0
    }

    # Check for updates
    local local_commit=$(git rev-parse HEAD)
    local remote_commit=$(git rev-parse origin/$current_branch 2>/dev/null || echo "$local_commit")

    if [ "$local_commit" != "$remote_commit" ]; then
        log_info "Found spec-kit update, updating..."

        # Show version change
        local old_version=$(grep '^version' "$SPECKIT_PATH/pyproject.toml" | cut -d'"' -f2 2>/dev/null || echo "unknown")

        if git pull origin $current_branch --quiet; then
            local new_version=$(grep '^version' "$SPECKIT_PATH/pyproject.toml" | cut -d'"' -f2 2>/dev/null || echo "unknown")
            log_success "spec-kit updated: $old_version → $new_version"
        else
            log_error "spec-kit update failed"
            cd - >/dev/null
            return 1
        fi
    else
        local version=$(grep '^version' "$SPECKIT_PATH/pyproject.toml" | cut -d'"' -f2 2>/dev/null || echo "unknown")
        log_success "spec-kit is up to date ($version)"
    fi

    cd - >/dev/null
}

batch_sync() {
    local mode="${1:-interactive}"

    log_header "Batch Sync Spec-Kit Commands"

    # Auto-update spec-kit repository
    update_speckit_repo
    echo ""

    # If no projects specified, auto-scan
    if [ ${#PROJECTS[@]} -eq 0 ]; then
        log_info "Scanning for projects in $GITHUB_DIR..."
        PROJECTS=($(scan_projects))
    fi

    if [ ${#PROJECTS[@]} -eq 0 ]; then
        log_error "No projects found with .claude/commands directory"
        exit 1
    fi

    log_success "Found ${#PROJECTS[@]} project(s)"
    echo ""

    # Display project list
    echo "Project list:"
    local index=1
    for project in "${PROJECTS[@]}"; do
        echo "  $index. $project"
        index=$((index + 1))
    done

    echo ""

    # Statistics
    local total=${#PROJECTS[@]}
    local success=0
    local skipped=0
    local failed=0

    # Process each project
    for project in "${PROJECTS[@]}"; do
        if process_project "$project" "$mode"; then
            success=$((success + 1))
        else
            skipped=$((skipped + 1))
        fi
    done

    # Show summary
    log_header "Batch Sync Complete"
    echo ""
    echo "📊 Statistics:"
    echo "  ✅ Success: $success project(s)"
    echo "  ⏭️  Skipped: $skipped project(s)"
    echo "  ❌ Failed: $failed project(s)"
    echo "  ═══════════════"
    echo "  📦 Total: $total project(s)"
}

# ============================================================================
# Specific project list configuration example
# ============================================================================

# Uncomment and customize the projects you want to sync
# PROJECTS=(
#     "bni-system"
#     "article_writing"
#     "mehmo_edu"
#     "sales-inventory-report-web"
#     "ourjrney_seo"
# )

# ============================================================================
# Main program
# ============================================================================

show_usage() {
    cat << EOF
${CYAN}Batch Sync Spec-Kit Commands Tool${NC}

Usage:
    $0 [options]

Options:
    --auto              Auto mode (no prompts, auto-update)
    --check-only        Check only, no updates
    --help              Show this help message

Environment variables:
    GITHUB_DIR          GitHub projects directory (default: ~/Documents/GitHub)
    SPECKIT_PATH        spec-kit repository path (default: \$GITHUB_DIR/spec-kit)

Examples:
    # Interactive mode (prompt for each project)
    $0

    # Auto mode (no prompts, update directly)
    $0 --auto

    # Check-only mode (show status, no updates)
    $0 --check-only

    # Custom GitHub directory
    GITHUB_DIR=/custom/path $0

Custom project list:
    Edit this script and set the PROJECTS variable:

    PROJECTS=(
        "project1"
        "project2"
        "project3"
    )

EOF
}

main() {
    local mode="interactive"

    # Parse arguments
    while [[ $# -gt 0 ]]; do
        case $1 in
            --auto)
                mode="auto"
                shift
                ;;
            --check-only)
                mode="check-only"
                shift
                ;;
            --help|-h)
                show_usage
                exit 0
                ;;
            *)
                log_error "Unknown option: $1"
                echo ""
                show_usage
                exit 1
                ;;
        esac
    done

    # Check if sync tool exists
    if [ ! -f "$SYNC_TOOL" ]; then
        log_error "Sync tool not found: $SYNC_TOOL"
        exit 1
    fi

    # Check if GitHub directory exists
    if [ ! -d "$GITHUB_DIR" ]; then
        log_error "GitHub directory does not exist: $GITHUB_DIR"
        log_info "Please set the correct GITHUB_DIR environment variable"
        exit 1
    fi

    # Execute batch sync
    batch_sync "$mode"
}

main "$@"
