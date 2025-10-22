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

# Verbosity level
VERBOSITY="${VERBOSITY:-normal}"  # quiet|normal|verbose|debug

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
    [[ "$VERBOSITY" != "quiet" ]] && echo -e "${BLUE}ℹ${NC} $1"
}

log_success() {
    [[ "$VERBOSITY" != "quiet" ]] && echo -e "${GREEN}✓${NC} $1"
}

log_warning() {
    [[ "$VERBOSITY" != "quiet" ]] && echo -e "${YELLOW}⚠${NC} $1"
}

log_error() {
    echo -e "${RED}✗${NC} $1"  # Always show errors
}

log_header() {
    if [[ "$VERBOSITY" != "quiet" ]]; then
        echo ""
        echo -e "${CYAN}╔════════════════════════════════════════════════════╗${NC}"
        echo -e "${CYAN}║ $1${NC}"
        echo -e "${CYAN}╚════════════════════════════════════════════════════╝${NC}"
    fi
}

log_section() {
    if [[ "$VERBOSITY" != "quiet" ]]; then
        echo ""
        echo -e "${MAGENTA}▶ $1${NC}"
        echo -e "${MAGENTA}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    fi
}

log_debug() {
    [[ "$VERBOSITY" =~ ^(debug|verbose)$ ]] && echo -e "${CYAN}[DEBUG]${NC} $1" >&2
}

log_verbose() {
    [[ "$VERBOSITY" =~ ^(debug|verbose)$ ]] && echo -e "${CYAN}$1${NC}"
}

# ============================================================================
# Project scanning
# ============================================================================

scan_projects() {
    local found_projects=()

    # All supported AI agent CLI directories
    local agent_dirs=(
        ".claude/commands"
        ".github/prompts"
        ".gemini/commands"
        ".cursor/rules"
        ".cursor/commands"
        ".qwen/commands"
        ".opencode/command"
        ".opencode/commands"
        ".codex/prompts"
        ".codex/commands"
        ".windsurf/workflows"
        ".kilocode/rules"
        ".kilocode"
        ".augment/rules"
        ".augment/commands"
        ".codebuddy/commands"
        ".roo/rules"
        ".roo/rules-mode-writer"
        ".roo/commands"
        ".amazonq/prompts"
        ".amazonq/commands"
        ".agents/commands"
        ".factory/commands"
        ".factory/prompts"
    )

    for dir in "$GITHUB_DIR"/*; do
        [ -d "$dir" ] || continue

        local project_name=$(basename "$dir")

        # Skip spec-kit and sync tool itself
        if [ "$project_name" = "spec-kit" ] || [ "$project_name" = "speckit-sync-tool" ]; then
            continue
        fi

        # Check if has any AI agent CLI directory
        local has_agent=false
        for agent_dir in "${agent_dirs[@]}"; do
            if [ -d "$dir/$agent_dir" ]; then
                has_agent=true
                break
            fi
        done

        if [ "$has_agent" = true ]; then
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

    cd "$project_dir" || return 2  # 失敗：無法進入目錄

    # Check if initialized
    if [ ! -f ".speckit-sync.json" ]; then
        log_warning "Project not initialized"

        if [ "$mode" = "interactive" ]; then
            echo -n "Initialize this project? [y/N] "
            read -r ans
            if [ "${ans:-N}" = "y" ]; then
                if ! VERBOSITY="$VERBOSITY" $SYNC_TOOL init; then
                    log_error "Initialization failed"
                    return 2  # 失敗：初始化失敗
                fi
            else
                log_info "Skipped initialization"
                return 1  # 跳過：用戶選擇不初始化
            fi
        elif [ "$mode" = "auto" ] || [ "$mode" = "one-click" ]; then
            log_info "Auto-initializing..."
            if ! SPECKIT_PATH="$SPECKIT_PATH" VERBOSITY="$VERBOSITY" $SYNC_TOOL init; then
                log_error "Auto-initialization failed"
                return 2  # 失敗：自動初始化失敗
            fi
        else
            return 1  # 跳過：check-only 模式且未初始化
        fi
    fi

    if [ "$mode" = "one-click" ]; then
        echo ""
        log_info "One-click update in progress..."
        if ! SPECKIT_PATH="$SPECKIT_PATH" VERBOSITY="$VERBOSITY" $SYNC_TOOL update-all --json; then
            log_error "One-click update failed for $project_name"
            return 2
        fi
        return 0
    fi

    # Run check
    echo ""
    if ! SPECKIT_PATH="$SPECKIT_PATH" VERBOSITY="$VERBOSITY" $SYNC_TOOL check; then
        log_error "Check failed for $project_name"
        return 2  # 失敗：檢查失敗
    fi

    # Decide whether to update based on mode
    if [ "$mode" = "check-only" ]; then
        log_info "Check-only mode, skipping update"
        return 0  # 成功：check-only 模式完成
    fi

    echo ""

    if [ "$mode" = "interactive" ]; then
        echo -n "Update this project? [y/N] "
        read -r ans
        if [ "${ans:-N}" = "y" ]; then
            if ! SPECKIT_PATH="$SPECKIT_PATH" VERBOSITY="$VERBOSITY" $SYNC_TOOL update; then
                log_error "Update failed for $project_name"
                return 2  # 失敗：更新失敗
            fi
            return 0  # 成功：更新完成
        else
            log_info "Skipped update"
            return 1  # 跳過：用戶選擇不更新
        fi
    elif [ "$mode" = "auto" ]; then
        log_info "Auto-updating..."
        if ! SPECKIT_PATH="$SPECKIT_PATH" VERBOSITY="$VERBOSITY" $SYNC_TOOL update; then
            log_error "Auto-update failed for $project_name"
            return 2  # 失敗：自動更新失敗
        fi
        return 0  # 成功：自動更新完成
    fi
}

compare_versions() {
    local ver1="$1"
    local ver2="$2"

    # Remove v prefix
    ver1="${ver1#v}"
    ver2="${ver2#v}"

    # Split version numbers
    local v1_major=$(echo "$ver1" | cut -d. -f1)
    local v1_minor=$(echo "$ver1" | cut -d. -f2)
    local v1_patch=$(echo "$ver1" | cut -d. -f3)

    local v2_major=$(echo "$ver2" | cut -d. -f1)
    local v2_minor=$(echo "$ver2" | cut -d. -f2)
    local v2_patch=$(echo "$ver2" | cut -d. -f3)

    # Default to 0
    v1_major=${v1_major:-0}
    v1_minor=${v1_minor:-0}
    v1_patch=${v1_patch:-0}
    v2_major=${v2_major:-0}
    v2_minor=${v2_minor:-0}
    v2_patch=${v2_patch:-0}

    # Compare major
    if [[ "$v1_major" -gt "$v2_major" ]]; then
        echo ">"
        return 0
    elif [[ "$v1_major" -lt "$v2_major" ]]; then
        echo "<"
        return 0
    fi

    # Compare minor
    if [[ "$v1_minor" -gt "$v2_minor" ]]; then
        echo ">"
        return 0
    elif [[ "$v1_minor" -lt "$v2_minor" ]]; then
        echo "<"
        return 0
    fi

    # Compare patch
    if [[ "$v1_patch" -gt "$v2_patch" ]]; then
        echo ">"
        return 0
    elif [[ "$v1_patch" -lt "$v2_patch" ]]; then
        echo "<"
        return 0
    fi

    echo "="
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

    # Get current tag (if on a tag) or commit
    local current_tag=$(git describe --tags --exact-match 2>/dev/null || echo "")

    # If not on a tag, try to get the nearest tag
    if [[ -z "$current_tag" ]]; then
        current_tag=$(git describe --tags --abbrev=0 2>/dev/null || echo "unknown")
    fi

    # Get latest release from GitHub API
    local latest_tag=$(curl -s https://api.github.com/repos/github/spec-kit/releases/latest | grep '"tag_name"' | cut -d'"' -f4)

    if [[ -z "$latest_tag" ]]; then
        log_warning "Cannot fetch latest version from GitHub, using local version"
        log_info "Local version: $current_tag"
        cd - >/dev/null
        return 0
    fi

    # Compare versions (remove v prefix)
    local comparison=$(compare_versions "$current_tag" "$latest_tag")

    if [[ "$comparison" == "<" ]]; then
        log_info "Found new version: $current_tag → $latest_tag"
        log_info "Updating to $latest_tag..."

        # Fetch tags
        git fetch --tags --quiet 2>/dev/null || {
            log_error "Cannot fetch tags"
            cd - >/dev/null
            return 1
        }

        # Checkout to latest tag
        if git checkout "$latest_tag" --quiet 2>/dev/null; then
            log_success "spec-kit updated: $current_tag → $latest_tag"
        else
            log_error "Cannot switch to $latest_tag"
            cd - >/dev/null
            return 1
        fi
    else
        log_success "spec-kit is up to date ($current_tag)"
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
        log_error "No projects found with AI agent CLI directories"
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
        local exit_code
        process_project "$project" "$mode"
        exit_code=$?

        case $exit_code in
            0)  # 成功
                success=$((success + 1))
                ;;
            1)  # 跳過
                skipped=$((skipped + 1))
                ;;
            *)  # 失敗（2 或其他非零值）
                failed=$((failed + 1))
                ;;
        esac
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
    --one-click         Run update-all for each project (one command)
    --quiet, -q         Quiet mode (errors only)
    --verbose, -v       Verbose mode (detailed output)
    --debug             Debug mode (all messages with timing)
    --help              Show this help message

Environment variables:
    GITHUB_DIR          GitHub projects directory (default: ~/Documents/GitHub)
    SPECKIT_PATH        spec-kit repository path (default: \$GITHUB_DIR/spec-kit)
    VERBOSITY           Output level: quiet|normal|verbose|debug (default: normal)

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
            --one-click)
                mode="one-click"
                shift
                ;;
            --quiet|-q)
                VERBOSITY="quiet"
                shift
                ;;
            --verbose|-v)
                VERBOSITY="verbose"
                shift
                ;;
            --debug)
                VERBOSITY="debug"
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
