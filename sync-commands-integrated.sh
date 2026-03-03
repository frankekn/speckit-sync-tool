#!/usr/bin/env bash

# ==============================================================================
# SpecKit Sync - 整合版多功能同步工具
# ==============================================================================
#
# 功能：
#   - ✅ 動態命令掃描 (Phase 1)
#   - ✅ 13 種 AI 代理支援 (Phase 2)
#   - ✅ 模版同步 (Phase 3)
#   - ✅ 自動更新 spec-kit
#   - ✅ 配置自動升級 (v1.0.0 → v2.1.0)
#
# 使用方式：
#   sync-commands-integrated.sh init                    # 初始化
#   sync-commands-integrated.sh detect-agents           # 檢測代理
#   sync-commands-integrated.sh check [--agent NAME]    # 檢查更新
#   sync-commands-integrated.sh update [--agent NAME]   # 執行同步
#   sync-commands-integrated.sh templates list          # 列出模版
#   sync-commands-integrated.sh templates sync          # 同步模版
#   sync-commands-integrated.sh scan                    # 掃描新命令
#   sync-commands-integrated.sh cleanup [--apply] [--all-projects] [--workspace-dir PATH]
#                                                  # 清理 Spec-Kit 注入
#
# 版本：2.1.0
# ==============================================================================

set -euo pipefail

# ==============================================================================
# 全域變數
# ==============================================================================

VERSION="2.1.0"
VERBOSITY="${VERBOSITY:-normal}"  # quiet|normal|verbose|debug
DRY_RUN=false
JSON_OUTPUT=false
JSON_REPORT_PATH=""
CLEANUP_APPLY=false
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(pwd)"
CONFIG_FILE="$PROJECT_ROOT/.speckit-sync.json"

# spec-kit 路徑（預設為同層級目錄）
SPECKIT_PATH="${SPECKIT_PATH:-$(dirname "$SCRIPT_DIR")/spec-kit}"
SPECKIT_COMMANDS="$SPECKIT_PATH/templates/commands"
SPECKIT_TEMPLATES="$SPECKIT_PATH/templates"

# AI 代理配置映射表（14 種代理）
declare -A AGENTS=(
    ["claude"]=".claude/commands"
    ["copilot"]=".github/prompts"
    ["gemini"]=".gemini/commands"
    ["cursor"]=".cursor/rules"
    ["qwen"]=".qwen/commands"
    ["opencode"]=".opencode/command"
    ["codex"]=".codex/prompts"
    ["windsurf"]=".windsurf/workflows"
    ["kilocode"]=".kilocode/rules"
    ["auggie"]=".augment/rules"
    ["codebuddy"]=".codebuddy/commands"
    ["roo"]=".roo/rules"
    ["q"]=".amazonq/prompts"
    ["droid"]=".factory/commands"
)

# 代理顯示名稱
declare -A AGENT_NAMES=(
    ["claude"]="Claude Code"
    ["copilot"]="GitHub Copilot"
    ["gemini"]="Gemini CLI"
    ["cursor"]="Cursor"
    ["qwen"]="Qwen Code"
    ["opencode"]="opencode"
    ["codex"]="Codex CLI"
    ["windsurf"]="Windsurf"
    ["kilocode"]="Kilo Code"
    ["auggie"]="Auggie CLI"
    ["codebuddy"]="CodeBuddy CLI"
    ["roo"]="Roo Code"
    ["q"]="Amazon Q Developer CLI"
    ["droid"]="Droid CLI"
)

# 代理目錄的替代選項（以管道符分隔）
declare -A AGENT_ALT_DIRS=(
    ["cursor"]=".cursor/commands"
    ["opencode"]=".opencode/commands"
    ["codex"]=".codex/commands"
    ["kilocode"]=".kilocode"
    ["auggie"]=".augment/commands"
    ["roo"]=".roo/rules-mode-writer|.roo/commands"
    ["q"]=".amazonq/commands"
    ["droid"]=".factory/prompts"
)

# 代理對應的 CLI 可執行檔名稱
declare -A AGENT_CLI=(
    ["claude"]="claude"
    ["gemini"]="gemini"
    ["cursor"]="cursor"
    ["qwen"]="qwen"
    ["opencode"]="opencode"
    ["codex"]="codex"
    ["auggie"]="auggie"
    ["codebuddy"]="codebuddy"
    ["q"]="q"
    ["droid"]="droid"
)

# 代理是否需要 CLI 工具
declare -A AGENT_REQUIRES_CLI=(
    ["claude"]="true"
    ["copilot"]="false"
    ["gemini"]="true"
    ["cursor"]="true"
    ["qwen"]="true"
    ["opencode"]="true"
    ["codex"]="true"
    ["windsurf"]="false"
    ["kilocode"]="false"
    ["auggie"]="true"
    ["codebuddy"]="true"
    ["roo"]="false"
    ["q"]="true"
    ["droid"]="true"
)

get_agent_dir_candidates() {
    local agent="$1"
    local candidates=("${AGENTS[$agent]}")

    if [[ -v AGENT_ALT_DIRS[$agent] ]]; then
        local alt="${AGENT_ALT_DIRS[$agent]}"
        IFS='|' read -r -a alt_array <<< "$alt"
        candidates+=("${alt_array[@]}")
    fi

    printf '%s\n' "${candidates[@]}"
}

find_existing_agent_dir() {
    local agent="$1"
    local candidate

    while IFS= read -r candidate; do
        [[ -z "$candidate" ]] && continue
        if [[ -d "$PROJECT_ROOT/$candidate" ]]; then
            echo "$candidate"
            return 0
        fi
    done < <(get_agent_dir_candidates "$agent")

    return 1
}

resolve_agent_dir() {
    local agent="$1"
    local existing

    if existing=$(find_existing_agent_dir "$agent"); then
        echo "$existing"
    else
        echo "${AGENTS[$agent]}"
    fi
}

get_agent_display_name() {
    local agent="$1"
    echo "${AGENT_NAMES[$agent]:-$agent}"
}

agent_requires_cli() {
    local agent="$1"
    [[ "${AGENT_REQUIRES_CLI[$agent]:-true}" == "true" ]]
}

get_agent_cli_tool() {
    local agent="$1"
    echo "${AGENT_CLI[$agent]:-$agent}"
}

agent_cli_available() {
    local agent="$1"
    if ! agent_requires_cli "$agent"; then
        return 0
    fi

    local cli
    cli="$(get_agent_cli_tool "$agent")"
    [[ -z "$cli" ]] && return 1
    command -v "$cli" &>/dev/null
}

detect_installed_agents() {
    local installed=()

    for agent in "${!AGENTS[@]}"; do
        if agent_cli_available "$agent"; then
            installed+=("$agent")
        fi
    done

    echo "${installed[@]}"
}

# 顏色定義
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
GRAY='\033[0;90m'
BOLD='\033[1m'
NC='\033[0m'

# 狀態符號標準（避免重複定義，提升視覺一致性）
readonly ICON_SUCCESS="✓"
readonly ICON_ERROR="✗"
readonly ICON_WARNING="⚠"
readonly ICON_INFO="ℹ"
readonly ICON_NEW="⊕"
readonly ICON_OUTDATED="↻"
readonly ICON_PACKAGE="📦"
readonly ICON_SYNC="🔄"
readonly ICON_ROCKET="🚀"

# ==============================================================================
# 工具函數
# ==============================================================================

log_info() {
    if [[ "$VERBOSITY" != "quiet" ]]; then
        echo -e "${BLUE}${ICON_INFO}${NC} $*"
    fi
    return 0
}

log_success() {
    if [[ "$VERBOSITY" != "quiet" ]]; then
        echo -e "${GREEN}${ICON_SUCCESS}${NC} $*"
    fi
    return 0
}

log_error() {
    echo -e "${RED}${ICON_ERROR}${NC} $*" >&2  # Always show errors
}

log_warning() {
    if [[ "$VERBOSITY" != "quiet" ]]; then
        echo -e "${YELLOW}${ICON_WARNING}${NC} $*"
    fi
    return 0
}

log_header() {
    if [[ "$VERBOSITY" != "quiet" ]]; then
        echo ""
        echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
        echo -e "${CYAN}${BOLD}$1${NC}"
        echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    fi
}

log_section() {
    if [[ "$VERBOSITY" != "quiet" ]]; then
        echo ""
        echo -e "${BLUE}${BOLD}▶ $1${NC}"
    fi
}

log_debug() {
    if [[ "$VERBOSITY" =~ ^(debug|verbose)$ ]]; then
        echo -e "${GRAY}[DEBUG]${NC} $*" >&2
    fi
    return 0
}

log_verbose() {
    if [[ "$VERBOSITY" =~ ^(debug|verbose)$ ]]; then
        echo -e "${GRAY}$*${NC}"
    fi
    return 0
}

# 計時包裝器（僅在 verbose/debug 模式顯示）
with_timing() {
    local description="$1"
    shift

    if [[ "$VERBOSITY" =~ ^(debug|verbose)$ ]]; then
        local start_time=$(date +%s.%N)
        log_verbose "Start: $description"
        "$@"
        local exit_code=$?
        local end_time=$(date +%s.%N)
        local duration=$(echo "$end_time - $start_time" | bc)
        log_verbose "Done: $description (took ${duration}s)"
        return $exit_code
    else
        "$@"
    fi
}

# Dry-run 執行包裝器
dry_run_execute() {
    local description="$1"
    shift

    if [[ "$DRY_RUN" == true ]]; then
        echo -e "${YELLOW}[DRY-RUN]${NC} $description"
        echo -e "${GRAY}    Command: $*${NC}"
        return 0
    else
        "$@"
    fi
}

# 進度指示器
show_progress() {
    local current="$1"
    local total="$2"
    local message="${3:-Processing}"

    # 檢測是否為終端（避免在日誌文件中產生異常字符）
    if [[ ! -t 1 ]]; then
        # 非終端環境，使用簡單格式
        echo "[$current/$total] $message"
        return
    fi

    local percent=$((current * 100 / total))
    local filled=$((current * 40 / total))
    local empty=$((40 - filled))

    printf "\r${BLUE}[%3d%%]${NC} " "$percent"
    printf "${GREEN}%*s${NC}" "$filled" | tr ' ' '█'
    printf "${GRAY}%*s${NC}" "$empty" | tr ' ' '░'
    printf " %s (%d/%d)" "$message" "$current" "$total"

    [[ $current -eq $total ]] && echo ""  # newline on completion
}

# ==============================================================================
# 依賴檢查
# ==============================================================================

check_dependencies() {
    local missing=()
    local required_cmds=()

    if [[ $# -gt 0 ]]; then
        required_cmds=("$@")
    else
        required_cmds=("git" "jq" "diff" "grep")
    fi

    log_debug "Checking required tools: ${required_cmds[*]}"

    for cmd in "${required_cmds[@]}"; do
        if ! command -v "$cmd" &>/dev/null; then
            missing+=("$cmd")
        fi
    done

    if [[ ${#missing[@]} -gt 0 ]]; then
        log_error "Missing required tools"
        echo ""
        echo "${BOLD}Missing tools:${NC}"
        printf "  ${RED}${ICON_ERROR}${NC} %s\n" "${missing[@]}"
        echo ""
        echo "${BOLD}${ICON_ROCKET} Install:${NC}"
        echo "  macOS:   ${CYAN}brew install ${missing[*]}${NC}"
        echo "  Ubuntu:  ${CYAN}sudo apt install ${missing[*]}${NC}"
        echo "  CentOS:  ${CYAN}sudo yum install ${missing[*]}${NC}"
        return 1
    fi

    log_debug "Dependency check passed"
    return 0
}

# ==============================================================================
# spec-kit 自動更新
# ==============================================================================

# 版本比較函數 (semver: major.minor.patch)
compare_versions() {
    local ver1="$1"
    local ver2="$2"

    # 移除 v 前綴
    ver1="${ver1#v}"
    ver2="${ver2#v}"

    # 分割版本號並轉換為陣列
    local v1_major=$(echo "$ver1" | cut -d. -f1)
    local v1_minor=$(echo "$ver1" | cut -d. -f2)
    local v1_patch=$(echo "$ver1" | cut -d. -f3)

    local v2_major=$(echo "$ver2" | cut -d. -f1)
    local v2_minor=$(echo "$ver2" | cut -d. -f2)
    local v2_patch=$(echo "$ver2" | cut -d. -f3)

    # 預設值為 0
    v1_major=${v1_major:-0}
    v1_minor=${v1_minor:-0}
    v1_patch=${v1_patch:-0}
    v2_major=${v2_major:-0}
    v2_minor=${v2_minor:-0}
    v2_patch=${v2_patch:-0}

    # 比較 major
    if [[ "$v1_major" -gt "$v2_major" ]]; then
        echo ">"
        return 0
    elif [[ "$v1_major" -lt "$v2_major" ]]; then
        echo "<"
        return 0
    fi

    # 比較 minor
    if [[ "$v1_minor" -gt "$v2_minor" ]]; then
        echo ">"
        return 0
    elif [[ "$v1_minor" -lt "$v2_minor" ]]; then
        echo "<"
        return 0
    fi

    # 比較 patch
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
    if [[ ! -d "$SPECKIT_PATH/.git" ]]; then
        log_warning "spec-kit is not a git repository, skipping auto update"
        return 0
    fi

    log_info "Checking for a newer spec-kit version..."

    cd "$SPECKIT_PATH"

    # 檢查是否有未提交的變更
    if ! git diff-index --quiet HEAD -- 2>/dev/null; then
        log_warning "spec-kit has uncommitted changes, skipping auto update"
        cd - >/dev/null
        return 0
    fi

    # 獲取當前 tag（如果在 tag 上）或 commit
    local current_tag=$(git describe --tags --exact-match 2>/dev/null || echo "")

    # 如果不在 tag 上，嘗試獲取最近的 tag
    if [[ -z "$current_tag" ]]; then
        current_tag=$(git describe --tags --abbrev=0 2>/dev/null || echo "unknown")
    fi

    # 從 GitHub API 獲取最新 release 版本
    local latest_tag=$(curl -s https://api.github.com/repos/github/spec-kit/releases/latest | grep '"tag_name"' | cut -d'"' -f4)

    if [[ -z "$latest_tag" ]]; then
        log_warning "Unable to fetch latest version from GitHub, using local version"
        log_info "Local version: $current_tag"
        cd - >/dev/null
        return 0
    fi

    # 比較版本（移除 v 前綴）
    local comparison=$(compare_versions "$current_tag" "$latest_tag")

    if [[ "$comparison" == "<" ]]; then
        log_info "New version found: $current_tag -> $latest_tag"
        log_info "Updating to $latest_tag..."

        # Fetch tags
        git fetch --tags --quiet 2>/dev/null || {
            log_error "Failed to fetch tags"
            cd - >/dev/null
            return 1
        }

        # Checkout 到最新 tag
        if git checkout "$latest_tag" --quiet 2>/dev/null; then
            log_success "spec-kit updated: $current_tag -> $latest_tag"
        else
            log_error "Failed to switch to $latest_tag"
            cd - >/dev/null
            return 1
        fi
    else
        log_success "spec-kit is already up to date ($current_tag)"
    fi

    cd - >/dev/null
}

# ==============================================================================
# 動態命令掃描 (Phase 1)
# ==============================================================================

get_standard_commands_from_speckit() {
    local commands=()

    if [[ ! -d "$SPECKIT_COMMANDS" ]]; then
        log_error "spec-kit commands directory not found"
        echo ""
        echo "${BOLD}${ICON_WARNING} Expected path:${NC} $SPECKIT_COMMANDS"
        echo ""
        echo "${BOLD}${ICON_WARNING} Possible reasons:${NC}"
        echo "  1. SPECKIT_PATH is incorrect"
        echo "  2. spec-kit repository is incomplete"
        echo "  3. spec-kit version is too old"
        echo ""
        echo "${BOLD}${ICON_ROCKET} Suggested actions:${NC}"
        echo "  1. Check current settings:"
        echo "     ${CYAN}echo \$SPECKIT_PATH${NC}"
        echo "     ${GRAY}Current value: $SPECKIT_PATH${NC}"
        echo ""
        echo "  2. Verify directory structure:"
        echo "     ${CYAN}ls -la $SPECKIT_PATH${NC}"
        echo ""
        echo "  3. Re-clone spec-kit:"
        echo "     ${CYAN}git clone https://github.com/github/github-models-template.git spec-kit${NC}"
        return 1
    fi

    for file in "$SPECKIT_COMMANDS"/*.md; do
        [[ -f "$file" ]] && commands+=("$(basename "$file")")
    done

    echo "${commands[@]}"
}

get_command_description() {
    local file="$1"

    # 嘗試從 YAML frontmatter 讀取描述
    if [[ -f "$file" ]]; then
        local desc=$(sed -n '/^---$/,/^---$/p' "$file" | grep "^description:" | cut -d':' -f2- | sed 's/^[[:space:]]*//')
        if [[ -n "$desc" ]]; then
            echo "$desc"
            return
        fi
    fi

    # 如果沒有 frontmatter，返回預設描述
    case "$(basename "$file")" in
        specify.md) echo "Write feature specification" ;;
        plan.md) echo "Create implementation plan" ;;
        tasks.md) echo "Break down task list" ;;
        implement.md) echo "Implement code changes" ;;
        constitution.md) echo "Project constitution and principles" ;;
        clarify.md) echo "Clarify requirements" ;;
        analyze.md) echo "Code analysis" ;;
        checklist.md) echo "Run checklist" ;;
        *) echo "Unknown command" ;;
    esac
}

scan_new_commands() {
    local agent="$1"

    # 防禦性檢查：確保代理存在
    if [[ ! -v AGENTS[$agent] ]]; then
        log_error "Unknown agent: $agent"
        return 1
    fi

    local commands_dir="$(resolve_agent_dir "$agent")"

    log_section "Scan new commands ($agent)"

    # 獲取 spec-kit 中的所有命令
    local speckit_commands=($(get_standard_commands_from_speckit))

    # 獲取配置中已知的命令
    local config=$(load_config)
    local known_commands=$(echo "$config" | jq -r ".agents.${agent}.commands.standard[], .agents.${agent}.commands.synced[]" 2>/dev/null)

    local new_commands=()
    for cmd in "${speckit_commands[@]}"; do
        if ! echo "$known_commands" | grep -q "^$cmd$"; then
            new_commands+=("$cmd")
        fi
    done

    if [[ ${#new_commands[@]} -eq 0 ]]; then
        log_success "No new commands found"
        return
    fi

    log_info "Found ${#new_commands[@]} new commands:"
    for cmd in "${new_commands[@]}"; do
        local desc=$(get_command_description "$SPECKIT_COMMANDS/$cmd")
        echo "  ⊕ $cmd - $desc"
    done

    # 互動式選擇
    echo ""
    read -p "Add these new commands to sync list? [y/N] " -r
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        for cmd in "${new_commands[@]}"; do
            config=$(echo "$config" | jq ".agents.${agent}.commands.standard += [\"$cmd\"]")
        done
        save_config "$config"
        log_success "Added ${#new_commands[@]} new commands to config"
    else
        log_info "Skipped adding new commands"
    fi
}

# ==============================================================================
# Spec-Kit 反向清理
# ==============================================================================

get_cleanup_agent_dirs() {
    local -a dirs=()
    local agent
    local candidate

    for agent in "${!AGENTS[@]}"; do
        while IFS= read -r candidate; do
            [[ -z "$candidate" ]] && continue
            dirs+=("$candidate")
        done < <(get_agent_dir_candidates "$agent")
    done

    # 官方 spec-kit 額外路徑（本工具映射之外）
    dirs+=(
        ".github/agents"
        ".qoder/commands"
        ".shai/commands"
        ".agent/workflows"
        ".bob/commands"
        ".speckit/commands"
        ".kilocode/workflows"
    )

    printf '%s\n' "${dirs[@]}" | awk 'NF && !seen[$0]++'
}

remove_path_safely() {
    local path="$1"

    [[ -e "$path" ]] || return 0

    if command -v trash >/dev/null 2>&1; then
        trash "$path"
    else
        log_warning "trash not found, falling back to rm -rf: $path"
        rm -rf "$path"
    fi
}

sanitize_agents_md() {
    local input_file="$1"
    local output_file="$2"

    awk '
        BEGIN {
            skip_section = 0
            blank = 0
        }
        {
            line = $0

            if (skip_section == 1) {
                if (line ~ /^## / || line ~ /^<!-- MANUAL ADDITIONS (START|END) -->$/) {
                    skip_section = 0
                } else {
                    next
                }
            }

            if (line ~ /\/speckit\./) next
            if (line ~ /^Auto-generated from all feature plans/) next
            if (line ~ /^# .*Development Guidelines$/) next
            if (line ~ /^<!-- MANUAL ADDITIONS START -->$/) next
            if (line ~ /^<!-- MANUAL ADDITIONS END -->$/) next

            if (line ~ /^## (Active Technologies|Project Structure|Commands|Code Style|Recent Changes)$/) {
                skip_section = 1
                next
            }

            if (line ~ /^[[:space:]]*$/) {
                if (blank == 1) next
                blank = 1
                print ""
                next
            }

            blank = 0
            print line
        }
    ' "$input_file" > "$output_file"
}

prune_empty_agent_dirs() {
    local -a cleanup_dirs=("$@")
    local rel_dir
    local abs_dir
    local current

    for rel_dir in "${cleanup_dirs[@]}"; do
        abs_dir="$PROJECT_ROOT/$rel_dir"
        current="$abs_dir"

        while [[ "$current" != "$PROJECT_ROOT" ]] && [[ "$current" == "$PROJECT_ROOT/"* ]]; do
            if [[ -d "$current" ]] && [[ -z "$(find "$current" -mindepth 1 -maxdepth 1 2>/dev/null)" ]]; then
                remove_path_safely "$current"
                current="$(dirname "$current")"
            else
                break
            fi
        done
    done
}

cleanup_repo() {
    local apply_mode="$1"

    log_header "Clean Spec-Kit artifacts"
    log_info "Mode: $([ "$apply_mode" == "true" ] && echo "apply (--apply)" || echo "preview")"

    local -a standard_commands=()
    local -a cleanup_dirs=()
    local cmd
    local dir
    local file
    local source
    local target

    local standard_raw=""
    if [[ -d "$SPECKIT_COMMANDS" ]]; then
        standard_raw="$(get_standard_commands_from_speckit)"
        read -r -a standard_commands <<< "$standard_raw"
    else
        log_warning "Cannot find $SPECKIT_COMMANDS, skipping exact template match"
    fi

    mapfile -t cleanup_dirs < <(get_cleanup_agent_dirs)

    local -a delete_targets=()
    local -a delete_reasons=()
    declare -A seen_targets=()

    add_delete_target() {
        local path="$1"
        local reason="$2"
        if [[ -n "${seen_targets[$path]+x}" ]]; then
            return
        fi
        seen_targets["$path"]=1
        delete_targets+=("$path")
        delete_reasons+=("$reason")
    }

    # 1) speckit 命名的命令檔
    for dir in "${cleanup_dirs[@]}"; do
        local abs_dir="$PROJECT_ROOT/$dir"
        [[ -d "$abs_dir" ]] || continue

        while IFS= read -r file; do
            [[ -z "$file" ]] && continue
            add_delete_target "$file" "speckit_named"
        done < <(find "$abs_dir" -type f \
            \( -name 'speckit.*.md' -o -name 'speckit.*.toml' -o -name 'speckit.*.agent.md' -o -name 'speckit.*.prompt.md' \) 2>/dev/null)
    done

    # 2) 與官方模板完全一致的標準命令檔
    if [[ ${#standard_commands[@]} -gt 0 ]] && [[ -d "$SPECKIT_COMMANDS" ]]; then
        for dir in "${cleanup_dirs[@]}"; do
            local abs_dir="$PROJECT_ROOT/$dir"
            [[ -d "$abs_dir" ]] || continue

            for cmd in "${standard_commands[@]}"; do
                source="$SPECKIT_COMMANDS/$cmd"
                target="$abs_dir/$cmd"
                [[ -f "$source" ]] || continue
                [[ -f "$target" ]] || continue

                if diff -q "$source" "$target" >/dev/null 2>&1; then
                    add_delete_target "$target" "template_match:$cmd"
                fi
            done
        done
    fi

    # 3) 固定路徑（.specify / config）
    [[ -e "$PROJECT_ROOT/.specify" ]] && add_delete_target "$PROJECT_ROOT/.specify" ".specify_dir"
    [[ -e "$PROJECT_ROOT/.speckit-sync.json" ]] && add_delete_target "$PROJECT_ROOT/.speckit-sync.json" "sync_config"
    while IFS= read -r file; do
        [[ -z "$file" ]] && continue
        add_delete_target "$file" "sync_config_backup"
    done < <(find "$PROJECT_ROOT" -maxdepth 1 -type f -name '.speckit-sync.json.backup.*' 2>/dev/null)

    # 4) AGENTS.md 就地清理（只在命中特徵時處理）
    local agents_file="$PROJECT_ROOT/AGENTS.md"
    local agents_action="none"
    local agents_tmp=""
    if [[ -f "$agents_file" ]] && grep -Eq '/speckit\.|Auto-generated from all feature plans' "$agents_file"; then
        agents_tmp="$(mktemp)"
        sanitize_agents_md "$agents_file" "$agents_tmp"

        if ! diff -q "$agents_file" "$agents_tmp" >/dev/null 2>&1; then
            if grep -q '[^[:space:]]' "$agents_tmp"; then
                agents_action="rewrite"
            else
                agents_action="delete"
            fi
        fi
    fi

    local total_hits="${#delete_targets[@]}"
    [[ "$agents_action" != "none" ]] && total_hits=$((total_hits + 1))

    if [[ "$total_hits" -eq 0 ]]; then
        log_info "No Spec-Kit artifacts found"
        [[ -n "$agents_tmp" ]] && rm -f "$agents_tmp"
        return 10
    fi

    echo ""
    log_section "Matched items"
    local i
    for i in "${!delete_targets[@]}"; do
        if [[ "$apply_mode" == "true" ]]; then
            echo "  - Deleted: ${delete_targets[$i]} (${delete_reasons[$i]})"
        else
            echo "  - Will delete: ${delete_targets[$i]} (${delete_reasons[$i]})"
        fi
    done

    if [[ "$agents_action" == "rewrite" ]]; then
        echo "  - $([ "$apply_mode" == "true" ] && echo "rewrite" || echo "will rewrite"): $agents_file (remove Spec-Kit injected block)"
    elif [[ "$agents_action" == "delete" ]]; then
        echo "  - $([ "$apply_mode" == "true" ] && echo "delete" || echo "will delete"): $agents_file (empty after cleanup)"
    fi

    if [[ "$apply_mode" != "true" ]]; then
        echo ""
        log_info "Preview complete. Add --apply to perform cleanup."
        [[ -n "$agents_tmp" ]] && rm -f "$agents_tmp"
        return 0
    fi

    # 實際執行
    local deleted_count=0
    for i in "${!delete_targets[@]}"; do
        remove_path_safely "${delete_targets[$i]}"
        deleted_count=$((deleted_count + 1))
    done

    local modified_count=0
    if [[ "$agents_action" == "rewrite" ]]; then
        cp "$agents_tmp" "$agents_file"
        modified_count=1
    elif [[ "$agents_action" == "delete" ]]; then
        remove_path_safely "$agents_file"
        deleted_count=$((deleted_count + 1))
    fi
    [[ -n "$agents_tmp" ]] && rm -f "$agents_tmp"

    prune_empty_agent_dirs "${cleanup_dirs[@]}"

    echo ""
    log_header "Cleanup complete"
    echo "  ${ICON_SUCCESS} Deleted: $deleted_count"
    echo "  ${ICON_SUCCESS} Rewritten: $modified_count"
    echo "  ${ICON_PACKAGE} Total matches: $total_hits"

    return 0
}

repo_has_speckit_artifacts() {
    local repo_root="$1"
    local -a cleanup_dirs=()
    local -a standard_commands=()
    local standard_raw=""
    local dir
    local cmd
    local abs_dir

    [[ -d "$repo_root" ]] || return 1

    [[ -e "$repo_root/.specify" ]] && return 0
    [[ -e "$repo_root/.speckit-sync.json" ]] && return 0
    [[ -f "$repo_root/AGENTS.md" ]] && grep -Eq '/speckit\.|Auto-generated from all feature plans' "$repo_root/AGENTS.md" && return 0

    mapfile -t cleanup_dirs < <(get_cleanup_agent_dirs)

    for dir in "${cleanup_dirs[@]}"; do
        abs_dir="$repo_root/$dir"
        [[ -d "$abs_dir" ]] || continue

        if find "$abs_dir" -type f \( -name 'speckit.*.md' -o -name 'speckit.*.toml' -o -name 'speckit.*.agent.md' -o -name 'speckit.*.prompt.md' \) | grep -q .; then
            return 0
        fi
    done

    if [[ -d "$SPECKIT_COMMANDS" ]]; then
        standard_raw="$(get_standard_commands_from_speckit)"
        read -r -a standard_commands <<< "$standard_raw"

        for dir in "${cleanup_dirs[@]}"; do
            abs_dir="$repo_root/$dir"
            [[ -d "$abs_dir" ]] || continue

            for cmd in "${standard_commands[@]}"; do
                [[ -f "$SPECKIT_COMMANDS/$cmd" ]] || continue
                [[ -f "$abs_dir/$cmd" ]] || continue
                if diff -q "$SPECKIT_COMMANDS/$cmd" "$abs_dir/$cmd" >/dev/null 2>&1; then
                    return 0
                fi
            done
        done
    fi

    return 1
}

cleanup_single_project() {
    local project_root="$1"
    local apply_mode="$2"
    local old_project_root="$PROJECT_ROOT"
    local old_config_file="$CONFIG_FILE"
    local code=0

    PROJECT_ROOT="$project_root"
    CONFIG_FILE="$PROJECT_ROOT/.speckit-sync.json"

    if cleanup_repo "$apply_mode"; then
        code=0
    else
        code=$?
    fi

    PROJECT_ROOT="$old_project_root"
    CONFIG_FILE="$old_config_file"
    return "$code"
}

cleanup_all_projects() {
    local workspace_dir="$1"
    local apply_mode="$2"
    local -a projects=()
    local project_dir
    local project_name
    local total=0
    local success=0
    local skipped=0
    local failed=0
    local code=0

    log_header "Batch clean Spec-Kit artifacts"
    log_info "Scan directory: $workspace_dir"

    if [[ ! -d "$workspace_dir" ]]; then
        log_error "Directory does not exist: $workspace_dir"
        return 1
    fi

    for project_dir in "$workspace_dir"/*; do
        [[ -d "$project_dir" ]] || continue
        project_name="$(basename "$project_dir")"
        [[ "$project_name" == "spec-kit" || "$project_name" == "speckit-sync-tool" ]] && continue

        if repo_has_speckit_artifacts "$project_dir"; then
            projects+=("$project_dir")
        fi
    done

    if [[ ${#projects[@]} -eq 0 ]]; then
        log_info "No Spec-Kit artifacts found"
        return 10
    fi

    total=${#projects[@]}
    echo ""
    echo "Project list:"
    local index=1
    for project_dir in "${projects[@]}"; do
        echo "  $index. $(basename "$project_dir")"
        index=$((index + 1))
    done

    for project_dir in "${projects[@]}"; do
        project_name="$(basename "$project_dir")"
        log_section "Cleanup project: $project_name"

        if cleanup_single_project "$project_dir" "$apply_mode"; then
            success=$((success + 1))
        else
            code=$?
            if [[ "$code" -eq 10 ]]; then
                skipped=$((skipped + 1))
            else
                failed=$((failed + 1))
            fi
        fi
    done

    log_header "Batch Cleanup Complete"
    echo "  ✅ Success: $success"
    echo "  ⏭️  Skipped: $skipped"
    echo "  ❌ Failed: $failed"
    echo "  📦 Total: $total"

    [[ "$failed" -gt 0 ]] && return 1
    return 0
}

# ==============================================================================
# 代理偵測與管理 (Phase 2)
# ==============================================================================

# 靜默版本：只返回代理名稱陣列（用於程式化調用）
detect_agents_quiet() {
    local detected=()

    for agent in "${!AGENTS[@]}"; do
        if dir=$(find_existing_agent_dir "$agent"); then
            detected+=("$agent")
        fi
    done

    if [[ ${#detected[@]} -eq 0 ]]; then
        return 1
    fi

    echo "${detected[@]}"
}

# 詳細版本：顯示偵測過程（用於命令行顯示）
detect_agents() {
    log_section "Detect AI agents"

    local detected=()

    for agent in "${!AGENTS[@]}"; do
        if dir=$(find_existing_agent_dir "$agent"); then
            detected+=("$agent")
            log_success "${AGENT_NAMES[$agent]} ($dir)"
        fi
    done

    if [[ ${#detected[@]} -eq 0 ]]; then
        log_warning "No AI agent directories detected"
        return 1
    fi

    echo ""
    log_info "Detected ${#detected[@]} agents"

    echo "${detected[@]}"
}

select_agents_interactive() {
    # 將所有互動輸出重定向到 stderr，只有最終結果輸出到 stdout
    {
        log_section "Select agents to enable"

        local detected_agents=($(detect_agents_quiet))

        if [[ ${#detected_agents[@]} -eq 0 ]]; then
            log_error "No agents detected"
            return 1
        fi

        local selected=()

        echo "Select agents to enable sync (space to select, Enter to confirm):"
        echo ""

        for i in "${!detected_agents[@]}"; do
            local agent="${detected_agents[$i]}"

            # 防禦性檢查：確保代理存在於映射表中
            if [[ ! -v AGENT_NAMES[$agent] ]] || [[ ! -v AGENTS[$agent] ]]; then
                log_warning "Skip unknown agent: $agent"
                continue
            fi

            local name="${AGENT_NAMES[$agent]}"
            local dir="$(resolve_agent_dir "$agent")"

            read -p "[$((i+1))] $name ($dir) [Y/n] " -r || true
            if [[ -z "${REPLY:-}" ]] || [[ "${REPLY:-y}" =~ ^[Yy]$ ]]; then
                selected+=("$agent")
                log_success "Selected: $name"
            else
                log_info "Skipped: $name"
            fi
        done

        echo "${selected[@]}"
    } >&2

    # 最終結果輸出到 stdout
    echo "${selected[@]}"
}

# ==============================================================================
# 配置檔案管理
# ==============================================================================

load_config() {
    if [[ ! -f "$CONFIG_FILE" ]]; then
        log_debug "Config file not found, returning empty config"
        echo "{}"
        return
    fi

    log_debug "Loading config: $CONFIG_FILE"

    # 驗證 JSON 格式
    if ! jq empty "$CONFIG_FILE" 2>/dev/null; then
        log_error "Config file format error (invalid JSON)"
        echo ""
        echo "${BOLD}${ICON_WARNING} Config file:${NC} $CONFIG_FILE"
        echo ""
        echo "${BOLD}${ICON_ROCKET} Suggested actions:${NC}"
        echo "  1. Check file content:"
        echo "     ${CYAN}cat $CONFIG_FILE${NC}"
        echo ""
        echo "  2. Validate JSON syntax:"
        echo "     ${CYAN}jq . $CONFIG_FILE${NC}"
        echo ""
        echo "  3. Re-initialize (will overwrite current config):"
        echo "     ${CYAN}rm $CONFIG_FILE && speckit-sync init${NC}"
        echo ""
        echo "  4. Restore from backup (if available):"
        echo "     ${CYAN}cp $CONFIG_FILE.backup $CONFIG_FILE${NC}"
        return 1
    fi

    local config=$(cat "$CONFIG_FILE")

    # 驗證必要欄位
    local version=$(echo "$config" | jq -r '.version // empty')
    if [[ -z "$version" ]]; then
        log_warning "Config has no version; upgrade may be required"
        log_info "Run ${CYAN}upgrade${NC} to upgrade config"
    fi

    echo "$config"
}

save_config() {
    local config="$1"
    echo "$config" | jq '.' > "$CONFIG_FILE"
}

get_config_version() {
    local config="$1"
    echo "$config" | jq -r '.version // "1.0.0"'
}

# 配置升級函數
upgrade_config() {
    local config="$1"
    local current_version=$(get_config_version "$config")

    log_info "Current config version: $current_version"

    # v1.0.0 → v1.1.0：添加動態命令掃描
    if [[ "$current_version" == "1.0.0" ]]; then
        log_info "Upgrading config: v1.0.0 -> v1.1.0"
        config=$(echo "$config" | jq '.version = "1.1.0"')
        current_version="1.1.0"
    fi

    # v1.1.0 → v2.0.0：添加多代理支援
    if [[ "$current_version" == "1.1.0" ]]; then
        log_info "Upgrading config: v1.1.0 -> v2.0.0"

        # 將舊的 commands 結構轉換為 agents.claude
        local old_commands=$(echo "$config" | jq -r '.commands // {}')

        config=$(echo "$config" | jq --argjson old_cmds "$old_commands" '
            .version = "2.0.0" |
            .agents = {
                "claude": {
                    "enabled": true,
                    "commands_dir": ".claude/commands",
                    "commands": $old_cmds
                }
            } |
            del(.commands)
        ')
        current_version="2.0.0"
    fi

    # v2.0.0 → v2.1.0：添加模版支援
    if [[ "$current_version" == "2.0.0" ]]; then
        log_info "Upgrading config: v2.0.0 -> v2.1.0"

        config=$(echo "$config" | jq '
            .version = "2.1.0" |
            .templates = {
                "enabled": false,
                "sync_dir": ".claude/templates",
                "selected": [],
                "last_sync": null
            }
        ')
        current_version="2.1.0"
    fi

    echo "$config"
}

# ==============================================================================
# 模版管理 (Phase 3)
# ==============================================================================

get_available_templates() {
    local templates=()

    if [[ ! -d "$SPECKIT_TEMPLATES" ]]; then
        log_warning "spec-kit templates directory not found: $SPECKIT_TEMPLATES"
        return
    fi

    for file in "$SPECKIT_TEMPLATES"/*; do
        [[ -f "$file" ]] && templates+=("$(basename "$file")")
    done

    echo "${templates[@]}"
}

templates_list() {
    log_header "Available templates"

    local templates=($(get_available_templates))

    if [[ ${#templates[@]} -eq 0 ]]; then
        log_warning "No templates found"
        return
    fi

    local config=$(load_config)
    local selected=$(echo "$config" | jq -r '.templates.selected[]' 2>/dev/null)

    echo ""
    for i in "${!templates[@]}"; do
        local tpl="${templates[$i]}"
        local status=" "

        if echo "$selected" | grep -q "^$tpl$"; then
            status="${GREEN}✓${NC}"
        fi

        printf "[%2d] %s %s\n" "$((i+1))" "$status" "$tpl"
    done
}

update_templates() {
    local agent="$1"

    # 防禦性檢查：確保代理存在
    if [[ ! -v AGENT_NAMES[$agent] ]] || [[ ! -v AGENTS[$agent] ]]; then
        log_error "Unknown agent: $agent"
        return 1
    fi

    log_header "Sync ${AGENT_NAMES[$agent]} templates"

    local config=$(load_config)
    local commands_dir="$(resolve_agent_dir "$agent")"

    # 從 commands 目錄中提取 agent 根目錄
    # 例如: .claude/commands → .claude
    local agent_root=$(dirname "$commands_dir")
    local templates_dir="$PROJECT_ROOT/$agent_root/templates"

    # 讀取 templates 到陣列中
    local templates_array=()
    while IFS= read -r line; do
        [[ -n "$line" ]] && templates_array+=("$line")
    done < <(echo "$config" | jq -r ".agents.${agent}.templates.selected[]" 2>/dev/null)

    # 建立目標目錄
    dry_run_execute "Create templates directory: $templates_dir" mkdir -p "$templates_dir" </dev/null

    echo ""

    local synced=0
    local added=0
    local skipped=0

    for tpl in "${templates_array[@]}"; do
        local src="$SPECKIT_TEMPLATES/$tpl"
        local dest="$templates_dir/$tpl"

        if [[ ! -f "$src" ]]; then
            log_warning "$tpl - source file does not exist in spec-kit"
            : $((skipped++))
            continue
        fi

        # 檢查檔案是否已存在且相同
        if [[ -f "$dest" ]] && diff -q "$src" "$dest" >/dev/null 2>&1 </dev/null; then
            log_info "$tpl - already up to date"
            : $((skipped++))
        else
            dry_run_execute "Sync template: $tpl" cp "$src" "$dest" </dev/null
            if [[ -f "$dest" ]]; then
                log_success "$tpl - updated"
                : $((synced++))
            else
                log_success "$tpl - added"
                : $((added++))
            fi
        fi
    done

    echo ""
    log_info "Summary:"
    echo "  ✅ Synced: $synced"
    echo "  ⊕  Added: $added"
    echo "  ⊙  Skipped: $skipped"
    echo "  ═══════════"
    echo "  📦 Total: $((synced + added + skipped))"

    # 更新最後同步時間
    if [[ "$DRY_RUN" == false ]]; then
        config=$(echo "$config" | jq --arg agent "$agent" \
            ".agents[\$agent].templates.last_sync = \"$(date -u +%Y-%m-%dT%H:%M:%SZ)\"")
        save_config "$config"
    fi

    log_success "Templates synced to: $templates_dir"
}

templates_select() {
    local agent="$1"

    # 防禦性檢查：確保代理存在
    if [[ ! -v AGENT_NAMES[$agent] ]] || [[ ! -v AGENTS[$agent] ]]; then
        log_error "Unknown agent: $agent"
        return 1
    fi

    log_header "Select templates for ${AGENT_NAMES[$agent]}"

    local templates=($(get_available_templates))

    if [[ ${#templates[@]} -eq 0 ]]; then
        log_error "No templates found"
        return 1
    fi

    local config=$(load_config)
    local selected=()

    echo ""
    echo "Available templates:"
    echo ""

    for i in "${!templates[@]}"; do
        local tpl="${templates[$i]}"
        printf "[%2d] %s\n" "$((i+1))" "$tpl"
    done

    echo ""
    echo "Selection options:"
    echo "  • Enter numbers (space-separated): 1 3 5"
    echo "  • Enter range: 1-3"
    echo "  • Select all: a or all"
    echo "  • Cancel: q or quit"
    echo ""

    read -p "Choose > " -r

    if [[ "$REPLY" == "q" ]] || [[ "$REPLY" == "quit" ]]; then
        log_info "Cancelled"
        return 1
    fi

    if [[ "$REPLY" == "a" ]] || [[ "$REPLY" == "all" ]]; then
        selected=("${templates[@]}")
    else
        # 解析選擇
        for choice in $REPLY; do
            if [[ "$choice" =~ ^([0-9]+)-([0-9]+)$ ]]; then
                # 範圍選擇
                local start=${BASH_REMATCH[1]}
                local end=${BASH_REMATCH[2]}
                for ((i=start; i<=end; i++)); do
                    if [[ $i -ge 1 ]] && [[ $i -le ${#templates[@]} ]]; then
                        selected+=("${templates[$((i-1))]}")
                    fi
                done
            elif [[ "$choice" =~ ^[0-9]+$ ]]; then
                # 單一選擇
                if [[ $choice -ge 1 ]] && [[ $choice -le ${#templates[@]} ]]; then
                    selected+=("${templates[$((choice-1))]}")
                fi
            fi
        done
    fi

    if [[ ${#selected[@]} -eq 0 ]]; then
        log_warning "No templates selected"
        return 1
    fi

    # 去重
    selected=($(printf '%s\n' "${selected[@]}" | sort -u))

    echo ""
    log_success "Selected ${#selected[@]} templates:"
    for tpl in "${selected[@]}"; do
        echo "  • $tpl"
    done

    # 更新配置
    local selected_json=$(printf '%s\n' "${selected[@]}" | jq -R . | jq -s .)
    config=$(echo "$config" | jq --arg agent "$agent" --argjson sel "$selected_json" \
        ".agents[\$agent].templates.selected = \$sel | .agents[\$agent].templates.enabled = true")
    save_config "$config"

    echo ""
    log_success "Config updated"
}

# ==============================================================================
# 命令同步
# ==============================================================================

check_command() {
    local agent="$1"
    local command="$2"

    # 防禦性檢查：確保代理存在
    if [[ ! -v AGENTS[$agent] ]]; then
        echo "error"
        return
    fi

    local commands_dir="$(resolve_agent_dir "$agent")"

    local source="$SPECKIT_COMMANDS/$command"
    local target="$PROJECT_ROOT/$commands_dir/$command"

    if [[ ! -f "$source" ]]; then
        echo "missing_source"
        return
    fi

    if [[ ! -f "$target" ]]; then
        echo "new"
        return
    fi

    if diff -q "$source" "$target" >/dev/null 2>&1; then
        echo "synced"
    else
        echo "outdated"
    fi
}

sync_command() {
    local agent="$1"
    local command="$2"

    # 防禦性檢查：確保代理存在
    if [[ ! -v AGENTS[$agent] ]]; then
        log_error "Unknown agent: $agent"
        return 1
    fi

    local commands_dir="$(resolve_agent_dir "$agent")"

    local source="$SPECKIT_COMMANDS/$command"
    local target="$PROJECT_ROOT/$commands_dir/$command"

    if [[ ! -f "$source" ]]; then
        log_error "$command - source file does not exist"
        return 1
    fi

    dry_run_execute "Create directory: $(dirname "$target")" mkdir -p "$(dirname "$target")"
    dry_run_execute "Copy file: $source -> $target" cp "$source" "$target"
    return 0
}

check_updates() {
    local agent="$1"

    # 防禦性檢查：確保代理存在
    if [[ ! -v AGENT_NAMES[$agent] ]]; then
        log_error "Unknown agent: $agent"
        return 1
    fi

    log_header "Check ${AGENT_NAMES[$agent]} updates"

    # 自動更新 spec-kit
    with_timing "spec-kit update check" update_speckit_repo

    local config=$(load_config)
    local commands=$(echo "$config" | jq -r ".agents.${agent}.commands.standard[]" 2>/dev/null)

    local synced=0
    local outdated=0
    local new=0
    local missing=0

    echo ""
    while IFS= read -r cmd; do
        [[ -z "$cmd" ]] && continue

        local status=$(check_command "$agent" "$cmd")

        case "$status" in
            synced)
                echo -e "${GREEN}✓${NC} $cmd - up to date"
                synced=$((synced + 1))
                ;;
            outdated)
                echo -e "${YELLOW}↻${NC} $cmd - update available"
                outdated=$((outdated + 1))
                ;;
            new)
                echo -e "${CYAN}⊕${NC} $cmd - missing locally (new command)"
                new=$((new + 1))
                ;;
            missing_source)
                echo -e "${RED}✗${NC} $cmd - does not exist in spec-kit"
                missing=$((missing + 1))
                ;;
        esac
    done <<< "$commands"

    echo ""
    log_info "Summary:"
    echo "  ✅ Synced: $synced"
    echo "  ⊕  Missing: $new"
    echo "  ↻  Outdated: $outdated"
    echo "  ✗  Missing in source: $missing"
    echo "  ═══════════"
    echo "  📦 Total: $((synced + new + outdated + missing))"

    if [[ $((new + outdated)) -gt 0 ]]; then
        echo ""
        log_warning "Found $((new + outdated)) commands that need updates"
        log_info "Run 'update' to sync"
    fi
}

# ==============================================================================
# 命令同步
# ==============================================================================

update_commands() {
    local agent="$1"

    # 防禦性檢查：確保代理存在
    if [[ ! -v AGENT_NAMES[$agent] ]] || [[ ! -v AGENTS[$agent] ]]; then
        log_error "Unknown agent: $agent"
        return 1
    fi

    log_header "Sync ${AGENT_NAMES[$agent]} commands"

    local config=$(load_config)
    local commands=$(echo "$config" | jq -r ".agents.${agent}.commands.standard[]" 2>/dev/null)
    local commands_dir="$(resolve_agent_dir "$agent")"

    echo ""

    local updated=0
    local added=0
    local skipped=0

    while IFS= read -r cmd; do
        [[ -z "$cmd" ]] && continue

        local status=$(check_command "$agent" "$cmd")

        case "$status" in
            synced)
                log_info "$cmd - up to date, skipped"
                skipped=$((skipped + 1))
                ;;
            outdated)
                if sync_command "$agent" "$cmd"; then
                    log_success "$cmd - updated"
                    updated=$((updated + 1))
                fi
                ;;
            new)
                if sync_command "$agent" "$cmd"; then
                    log_success "$cmd - added"
                    added=$((added + 1))
                fi
                ;;
            missing_source)
                log_error "$cmd - does not exist in spec-kit"
                ;;
        esac
    done <<< "$commands"

    echo ""
    log_header "Sync complete"
    echo "  ⊕  Added: $added"
    echo "  ↻  Updated: $updated"
    echo "  ✓  Skipped: $skipped"
}

# ==============================================================================
# 一鍵更新流程
# ==============================================================================

update_all() {
    log_header "One-click sync"

    local output_json="$JSON_OUTPUT"
    local has_failure=0

    if [[ "$DRY_RUN" == true ]]; then
        log_info "[DRY-RUN] Skipping spec-kit update"
    else
        with_timing "spec-kit update check" update_speckit_repo
    fi

    local config
    config="$(load_config)"

    declare -A candidate_agents=()
    declare -a processing_order=()
    # 從配置中取得啟用的代理
    while IFS= read -r agent; do
        [[ -z "$agent" ]] && continue
        if [[ -z "${candidate_agents[$agent]+x}" ]]; then
            candidate_agents[$agent]=1
            processing_order+=("$agent")
        fi
    done < <(printf '%s' "$config" | jq -r '(.agents // {}) | to_entries[] | select(.value.enabled == true) | .key')

    # 從目錄掃描取得代理
    local detected_dirs
    if detected_dirs=$(detect_agents_quiet 2>/dev/null); then
        for agent in $detected_dirs; do
            if [[ -z "${candidate_agents[$agent]+x}" ]]; then
                candidate_agents[$agent]=1
                processing_order+=("$agent")
            fi
        done
    fi

    if [[ ${#processing_order[@]} -eq 0 ]]; then
        log_warning "No processable agents found. Run init or create agent directories first."
        return 0
    fi

    # 建立 CLI 安裝集合
    declare -A installed_cli_set=()
    local installed_cli
    installed_cli="$(detect_installed_agents)"
    for agent in $installed_cli; do
        installed_cli_set[$agent]=1
    done

    declare -a summary_success=()
    declare -a summary_skipped=()
    declare -a summary_preview=()
    declare -a summary_missing_cli=()
    declare -a summary_failed=()
    declare -a json_records=()

    for agent in "${processing_order[@]}"; do
        local display
        display="$(get_agent_display_name "$agent")"
        local requires_cli=false
        local has_cli=true
        local cli_name
        cli_name="$(get_agent_cli_tool "$agent")"

        if agent_requires_cli "$agent"; then
            requires_cli=true
            if [[ -z "${installed_cli_set[$agent]+x}" ]]; then
                has_cli=false
            fi
        fi

        local configured=false
        if printf '%s' "$config" | jq -e --arg agent "$agent" '(.agents // {}) | has($agent)' >/dev/null 2>&1; then
            configured=true
        fi

        local resolved_dir
        resolved_dir="$(resolve_agent_dir "$agent")"

        if [[ "$requires_cli" == true ]] && [[ "$has_cli" == false ]]; then
            local message="${display} detected, but CLI not found (${cli_name})."
            summary_missing_cli+=("$display|$message")
            if [[ "$output_json" == true ]]; then
                json_records+=("$(jq -cn --arg project "$PROJECT_ROOT" --arg agent "$agent" --arg name "$display" --arg status "skipped" --arg reason "missing_cli" '{project:$project,agent:$agent,name:$name,status:$status,reason:$reason}')")
            fi
            log_warning "$message"
            continue
        fi

        if [[ "$configured" != true ]]; then
            local message="${display} is not enabled in config yet."
            summary_skipped+=("$display|$message")
            if [[ "$output_json" == true ]]; then
                json_records+=("$(jq -cn --arg project "$PROJECT_ROOT" --arg agent "$agent" --arg name "$display" --arg status "skipped" --arg reason "not_configured" '{project:$project,agent:$agent,name:$name,status:$status,reason:$reason}')")
            fi
            log_info "$message"
            continue
        fi

        if [[ "$DRY_RUN" == true ]]; then
            local message="[DRY-RUN] ${display} will sync commands and templates"
            summary_preview+=("$display|$message")
            if [[ "$output_json" == true ]]; then
                json_records+=("$(jq -cn --arg project "$PROJECT_ROOT" --arg agent "$agent" --arg name "$display" --arg status "preview" --arg reason "dry_run" '{project:$project,agent:$agent,name:$name,status:$status,reason:$reason}')")
            fi
            log_info "$message"
            continue
        fi

        log_section "Processing $display"

        local templates_enabled
        templates_enabled="$(printf '%s' "$config" | jq -r --arg agent "$agent" '(.agents // {})[$agent].templates.enabled // false' 2>/dev/null)"
        [[ "$templates_enabled" == "null" ]] && templates_enabled="false"

        local template_status="disabled"

        if update_commands "$agent"; then
            local message="${display} command sync complete"

            if [[ "$templates_enabled" == "true" ]]; then
                template_status="skipped"
                if update_templates "$agent"; then
                    template_status="synced"
                else
                    template_status="failed"
                    has_failure=1
                    local fail_msg="${display} template sync failed"
                    summary_failed+=("$display|$fail_msg")
                    if [[ "$output_json" == true ]]; then
                        json_records+=("$(jq -cn --arg project "$PROJECT_ROOT" --arg agent "$agent" --arg name "$display" --arg status "failed" --arg reason "template_sync_failed" '{project:$project,agent:$agent,name:$name,status:$status,reason:$reason}')")
                    fi
                    config="$(load_config)"
                    continue
                fi
            fi

            summary_success+=("$display|$message")
            if [[ "$output_json" == true ]]; then
                json_records+=(
                    "$(jq -cn --arg project "$PROJECT_ROOT" --arg agent "$agent" --arg name "$display" --arg status "success" --arg reason "synced" --arg template "$template_status" '{project:$project,agent:$agent,name:$name,status:$status,reason:$reason,templates:(if $template == "disabled" then null else $template end)}')"
                )
            fi

            log_success "$message"
        else
            local message="${display} command sync failed"
            summary_failed+=("$display|$message")
            has_failure=1
            if [[ "$output_json" == true ]]; then
                json_records+=("$(jq -cn --arg project "$PROJECT_ROOT" --arg agent "$agent" --arg name "$display" --arg status "failed" --arg reason "command_sync_failed" '{project:$project,agent:$agent,name:$name,status:$status,reason:$reason}')")
            fi
            log_error "$message"
        fi

        config="$(load_config)"
    done

    echo ""
    log_header "One-click update summary"

    if [[ ${#summary_success[@]} -eq 0 && ${#summary_preview[@]} -eq 0 && ${#summary_skipped[@]} -eq 0 && ${#summary_missing_cli[@]} -eq 0 && ${#summary_failed[@]} -eq 0 ]]; then
        log_info "No results to display"
    fi

    local entry
    for entry in "${summary_success[@]}"; do
        local name="${entry%%|*}"
        local msg="${entry#*|}"
        log_success "$msg"
    done

    for entry in "${summary_preview[@]}"; do
        local msg="${entry#*|}"
        log_info "$msg"
    done

    for entry in "${summary_skipped[@]}"; do
        local msg="${entry#*|}"
        log_info "$msg"
    done

    for entry in "${summary_missing_cli[@]}"; do
        local msg="${entry#*|}"
        log_warning "$msg"
    done

    for entry in "${summary_failed[@]}"; do
        local msg="${entry#*|}"
        log_error "$msg"
    done

    if [[ "$output_json" == true ]]; then
        local report_dir="$PROJECT_ROOT/out"
        mkdir -p "$report_dir"
        JSON_REPORT_PATH="$report_dir/update-report.json"
        if [[ ${#json_records[@]} -gt 0 ]]; then
            local json_payload
            json_payload="[$(IFS=,; echo "${json_records[*]}")]"
            printf '%s' "$json_payload" | jq '.' > "$JSON_REPORT_PATH"
        else
            printf '[]' | jq '.' > "$JSON_REPORT_PATH"
        fi
        echo ""
        log_info "JSON report written to: $JSON_REPORT_PATH"
    fi

    return "$has_failure"
}

# ==============================================================================
# ==============================================================================
# 互動式精靈
# ==============================================================================

wizard() {
    log_header "SpecKit Sync Interactive Setup Wizard"

    echo ""
    echo -e "${BOLD}Welcome to SpecKit Sync!${NC}"
    echo "This wizard helps you complete initial setup and start syncing commands."
    echo ""

    # ==================== 步驟 1: 環境檢查 ====================
    log_section "Step 1/6: Environment checks"
    echo ""

    # 檢查依賴
    log_info "Checking required tools..."
    if ! check_dependencies; then
        log_error "Install required tools before running the wizard"
        return 1
    fi
    log_success "All required tools are installed"

    echo ""

    # 檢查 spec-kit 路徑
    log_info "Checking spec-kit path..."
    if [[ ! -d "$SPECKIT_PATH" ]]; then
        log_error "Invalid spec-kit path: $SPECKIT_PATH"
        echo ""
        echo "${BOLD}${ICON_ROCKET} Options:${NC}"
        echo "  1. Set SPECKIT_PATH to the correct path"
        echo "  2. Clone spec-kit to: $(dirname "$SCRIPT_DIR")/spec-kit"
        echo ""
        read -p "Clone spec-kit automatically? [y/N] " -r
        if [[ $REPLY =~ ^[Yy]$ ]]; then
            local clone_path="$(dirname "$SCRIPT_DIR")/spec-kit"
            log_info "Cloning spec-kit to $clone_path..."
            if git clone https://github.com/github/github-models-template.git "$clone_path" 2>/dev/null; then
                SPECKIT_PATH="$clone_path"
                SPECKIT_COMMANDS="$SPECKIT_PATH/templates/commands"
                SPECKIT_TEMPLATES="$SPECKIT_PATH/templates"
                log_success "spec-kit clone succeeded"
            else
                log_error "Clone failed, please configure manually"
                return 1
            fi
        else
            return 1
        fi
    else
        log_success "spec-kit path is valid: $SPECKIT_PATH"

        # 檢查是否需要更新
        if [[ -d "$SPECKIT_PATH/.git" ]]; then
            log_info "Checking spec-kit updates..."
            update_speckit_repo
        fi
    fi

    echo ""

    # ==================== 步驟 2: 偵測代理 ====================
    log_section "Step 2/6: Detect AI agents"
    echo ""

    log_info "Scanning project directory..."
    local detected_agents=($(detect_agents_quiet))

    if [[ ${#detected_agents[@]} -eq 0 ]]; then
        log_warning "No AI agent directories detected"
        echo ""
        echo "${BOLD}${ICON_INFO} Supported agents and directories:${NC}"
        for agent in "${!AGENTS[@]}"; do
            echo "  • ${AGENT_NAMES[$agent]}: ${AGENTS[$agent]}"
        done
        echo ""
        read -p "Create default directory for Claude Code? [y/N] " -r
        if [[ $REPLY =~ ^[Yy]$ ]]; then
            mkdir -p "$PROJECT_ROOT/.claude/commands"
            log_success "Created .claude/commands directory"
            detected_agents=("claude")
        else
            log_error "No available agents, cannot continue"
            return 1
        fi
    else
        log_success "Detected ${#detected_agents[@]} agents:"
        for agent in "${detected_agents[@]}"; do
            echo "  ${GREEN}${ICON_SUCCESS}${NC} ${AGENT_NAMES[$agent]} ($(resolve_agent_dir "$agent"))"
        done
    fi

    echo ""

    # ==================== 步驟 3: Select agents to enable ====================
    log_section "Step 3/6: Select agents to enable"
    echo ""

    local selected_agents=()

    if [[ ${#detected_agents[@]} -eq 1 ]]; then
        log_info "Only one agent detected, auto-selected: ${AGENT_NAMES[${detected_agents[0]}]}"
        selected_agents=("${detected_agents[0]}")
    else
        echo "Please choose agents to enable sync:"
        echo ""

        for i in "${!detected_agents[@]}"; do
            local agent="${detected_agents[$i]}"
            local name="${AGENT_NAMES[$agent]}"
            local dir="$(resolve_agent_dir "$agent")"

            read -p "  [$((i+1))] $name ($dir) - enable? [Y/n] " -r
            if [[ -z "${REPLY:-}" ]] || [[ "${REPLY:-y}" =~ ^[Yy]$ ]]; then
                selected_agents+=("$agent")
                log_success "  Selected: $name"
            else
                log_info "  Skipped: $name"
            fi
        done
    fi

    if [[ ${#selected_agents[@]} -eq 0 ]]; then
        log_error "No agents selected"
        return 1
    fi

    echo ""
    log_success "Selected ${#selected_agents[@]} agents"

    echo ""

    # ==================== 步驟 4: 選擇同步策略 ====================
    log_section "Step 4/6: Select sync strategy"
    echo ""

    echo "${BOLD}Sync strategy options:${NC}"
    echo "  [1] Semi-auto (recommended) - ask on conflicts, auto backup"
    echo "  [2] Full auto - overwrite automatically, keep backups"
    echo "  [3] Manual - confirm every file"
    echo ""

    local strategy_mode="semi-auto"
    local on_conflict="ask"

    read -p "Choose (1-3) [default: 1]: " -r
    case "${REPLY:-1}" in
        1)
            strategy_mode="semi-auto"
            on_conflict="ask"
            log_success "Selected: semi-auto mode"
            ;;
        2)
            strategy_mode="auto"
            on_conflict="overwrite"
            log_success "Selected: full auto mode"
            ;;
        3)
            strategy_mode="manual"
            on_conflict="ask"
            log_success "Selected: manual mode"
            ;;
        *)
            log_warning "Invalid choice, using default: semi-auto mode"
            ;;
    esac

    echo ""

    # ==================== 步驟 5: 選擇要同步的命令 ====================
    log_section "Step 5/6: Select commands to sync"
    echo ""

    log_info "Scanning available commands in spec-kit..."
    local standard_commands=($(get_standard_commands_from_speckit))

    if [[ ${#standard_commands[@]} -eq 0 ]]; then
        log_error "No commands found"
        return 1
    fi

    log_success "Found ${#standard_commands[@]} standard commands"
    echo ""

    echo "${BOLD}Command selection:${NC}"
    echo "  [1] Sync all commands (recommended for new projects)"
    echo "  [2] Sync core commands only (specify, plan, tasks, implement)"
    echo "  [3] Custom selection"
    echo ""

    local selected_commands=()

    read -p "Choose (1-3) [default: 1]: " -r
    case "${REPLY:-1}" in
        1)
            selected_commands=("${standard_commands[@]}")
            log_success "Selected: all ${#selected_commands[@]} commands"
            ;;
        2)
            local core_commands=("specify.md" "plan.md" "tasks.md" "implement.md")
            for cmd in "${core_commands[@]}"; do
                if [[ " ${standard_commands[@]} " =~ " ${cmd} " ]]; then
                    selected_commands+=("$cmd")
                fi
            done
            log_success "Selected: ${#selected_commands[@]} core commands"
            ;;
        3)
            echo ""
            echo "${BOLD}Available commands:${NC}"
            for i in "${!standard_commands[@]}"; do
                local cmd="${standard_commands[$i]}"
                local desc=$(get_command_description "$SPECKIT_COMMANDS/$cmd")
                printf "  [%2d] %s - %s\n" "$((i+1))" "$cmd" "$desc"
            done
            echo ""
            echo "Enter command numbers to sync (space-separated, Enter to finish):"
            read -p "> " -r

            for num in $REPLY; do
                if [[ "$num" =~ ^[0-9]+$ ]] && [[ "$num" -ge 1 ]] && [[ "$num" -le "${#standard_commands[@]}" ]]; then
                    local idx=$((num - 1))
                    selected_commands+=("${standard_commands[$idx]}")
                fi
            done

            if [[ ${#selected_commands[@]} -eq 0 ]]; then
                log_warning "No command selected, using all commands"
                selected_commands=("${standard_commands[@]}")
            else
                log_success "Selected: ${#selected_commands[@]} commands"
            fi
            ;;
        *)
            log_warning "Invalid selection, using default: all commands"
            selected_commands=("${standard_commands[@]}")
            ;;
    esac

    echo ""

    # ==================== 步驟 6: 創建配置並執行同步 ====================
    log_section "Step 6/6: Create config and run sync"
    echo ""

    # 檢查是否已有配置
    if [[ -f "$CONFIG_FILE" ]]; then
        log_warning "Config file already exists"
        read -p "Overwrite existing config? [y/N] " -r
        if [[ ! $REPLY =~ ^[Yy]$ ]]; then
            log_info "Keeping existing config, wizard finished"
            return 0
        fi

        # 備份現有配置
        local backup_file="$CONFIG_FILE.backup.$(date +%Y%m%d_%H%M%S)"
        cp "$CONFIG_FILE" "$backup_file"
        log_success "Existing config backed up: $backup_file"
    fi

    # 建立配置
    log_info "Creating config file..."

    local config=$(cat <<EOF
{
  "version": "2.1.0",
  "source": {
    "type": "local",
    "path": "$SPECKIT_PATH",
    "version": "unknown"
  },
  "strategy": {
    "mode": "$strategy_mode",
    "on_conflict": "$on_conflict"
  },
  "agents": {},
  "metadata": {
    "project_name": "$(basename "$PROJECT_ROOT")",
    "initialized": "$(date -u +%Y-%m-%dT%H:%M:%SZ)",
    "last_check": null,
    "total_syncs": 0
  }
}
EOF
)

    # 為每個選擇的代理添加配置
    local commands_json=$(printf '%s\n' "${selected_commands[@]}" | jq -R . | jq -s .)

    for agent in "${selected_agents[@]}"; do
        local agent_dir="$(resolve_agent_dir "$agent")"

        config=$(echo "$config" | jq --arg agent "$agent" \
                                      --arg dir "$agent_dir" \
                                      --argjson cmds "$commands_json" '
            .agents[$agent] = {
                "enabled": true,
                "commands_dir": $dir,
                "commands": {
                    "standard": $cmds,
                    "custom": [],
                    "synced": [],
                    "customized": []
                },
                "templates": {
                    "enabled": false,
                    "selected": [],
                    "last_sync": null
                }
            }
        ')
    done

    save_config "$config"
    log_success "Config file created: $CONFIG_FILE"

    echo ""

    # 詢問是否立即執行同步
    read -p "Run command sync now? [Y/n] " -r
    if [[ -z "${REPLY:-}" ]] || [[ "${REPLY:-y}" =~ ^[Yy]$ ]]; then
        echo ""
        log_header "Start syncing commands"

        for agent in "${selected_agents[@]}"; do
            echo ""
            update_commands "$agent"
        done

        echo ""
        log_header "Wizard complete"
        echo ""
        log_success "Setup complete! All commands are synced."
    else
        echo ""
        log_header "Wizard complete"
        echo ""
        log_success "Setup complete!"
        echo ""
        log_info "Next steps:"
        echo "  1. Run 'check' to check updates"
        echo "  2. Run 'update' to sync commands"
        echo "  3. Run 'templates select' to choose templates"
    fi

    echo ""
}
# 初始化
# ==============================================================================

init_config() {
    log_header "Initialize SpecKit Sync config"

    if [[ -f "$CONFIG_FILE" ]]; then
        log_warning "Config file already exists: $CONFIG_FILE"
        read -p "Re-initialize? [y/N] " -r
        [[ ! $REPLY =~ ^[Yy]$ ]] && return
    fi

    # 檢查 spec-kit 路徑
    if [[ ! -d "$SPECKIT_PATH" ]]; then
        log_error "Invalid spec-kit path: $SPECKIT_PATH"
        log_info "Please set a valid SPECKIT_PATH environment variable"
        return 1
    fi

    # 偵測並選擇代理
    local detected_agents=($(detect_agents 2>/dev/null))

    if [[ ${#detected_agents[@]} -eq 0 ]]; then
        log_error "No AI agent directories detected"
        log_info "Ensure the project has at least one agent directory (e.g. .claude/commands)"
        return 1
    fi

    local selected_agents=($(select_agents_interactive))

    if [[ ${#selected_agents[@]} -eq 0 ]]; then
        log_error "No agents selected"
        return 1
    fi

    # 為每個代理獲取標準命令
    local standard_commands=($(get_standard_commands_from_speckit))

    # 建立配置
    local config=$(cat <<EOF
{
  "version": "2.1.0",
  "source": {
    "type": "local",
    "path": "$SPECKIT_PATH",
    "version": "unknown"
  },
  "strategy": {
    "mode": "semi-auto",
    "on_conflict": "ask"
  },
  "agents": {},
  "templates": {
    "enabled": false,
    "sync_dir": ".claude/templates",
    "selected": [],
    "last_sync": null
  },
  "metadata": {
    "project_name": "$(basename "$PROJECT_ROOT")",
    "initialized": "$(date -u +%Y-%m-%dT%H:%M:%SZ)",
    "last_check": null,
    "total_syncs": 0
  }
}
EOF
)

    # 為每個選擇的代理添加配置
    for agent in "${selected_agents[@]}"; do
        # 防禦性檢查：確保代理存在
        if [[ ! -v AGENTS[$agent] ]]; then
            log_warning "Skip unknown agent: $agent"
            continue
        fi

        local agent_dir="$(resolve_agent_dir "$agent")"
        local commands_json=$(printf '%s\n' "${standard_commands[@]}" | jq -R . | jq -s .)

        config=$(echo "$config" | jq --arg agent "$agent" \
                                      --arg dir "$agent_dir" \
                                      --argjson cmds "$commands_json" '
            .agents[$agent] = {
                "enabled": true,
                "commands_dir": $dir,
                "commands": {
                    "standard": $cmds,
                    "custom": [],
                    "synced": [],
                    "customized": []
                },
                "templates": {
                    "enabled": false,
                    "selected": [],
                    "last_sync": null
                }
            }
        ')
    done

    save_config "$config"

    log_success "Initialization complete!"
    log_info "Config file: $CONFIG_FILE"
    log_info "Enabled agents: ${selected_agents[*]}"
    log_info "Detected ${#standard_commands[@]} standard commands"

    echo ""
    log_info "Next steps:"
    echo "  1. Run 'check' to check updates"
    echo "  2. Run 'update' to sync commands"
    echo "  3. Run 'templates select' to choose templates"
}

# ==============================================================================
# 主程式
# ==============================================================================

show_usage() {
    cat <<EOF
${CYAN}${BOLD}SpecKit Sync - Integrated CLI v${VERSION}${NC}

Usage:
    $0 <command> [options]

Commands:
    wizard                       interactive setup wizard (recommended for first-time setup)
    init                         initialize config
    detect-agents                detect available AI agents
    check [options]              check update status
    update [options]             run command sync
    scan [--agent <name>]        scan and add new commands
    cleanup [--apply] [--all-projects] [--workspace-dir PATH]
                                 clean Spec-Kit injected artifacts (preview by default)
    update-all [options]         one-click check and sync for all agents

    templates list               list available templates
    templates select             select templates to sync
    templates sync               sync selected templates

    status                       show current config status
    upgrade                      upgrade config file version

Options:
    --agent <name>               specify target agent
    --project-root <path>        specify target project path (default: current directory)
    --path <path>                shorthand for --project-root
    --all-agents                 auto-detect and process all agents (ignores enabled flags in config)
    --dry-run, -n                preview mode (show actions without executing)
    --quiet, -q                  quiet mode (errors only)
    --verbose, -v                verbose mode (extra details)
    --debug                      debug mode (all messages + timing)
    --json                       output JSON report for update-all
    --apply                      with cleanup, actually perform delete/rewrite
    --all-projects               with cleanup, scan all repos under workspace
    --workspace-dir <path>       with cleanup --all-projects (recommended)
    --github-dir <path>          compatibility alias for --workspace-dir
    --help                       show this help message

Environment Variables:
    SPECKIT_PATH                 spec-kit repository path (default: ../spec-kit)
    VERBOSITY                    output level: quiet|normal|verbose|debug (default: normal)
    WORKSPACE_DIR                root for cleanup batch scan (default: current directory)
    GITHUB_DIR                   compatibility alias for WORKSPACE_DIR

Examples:
    # Use interactive wizard (recommended first run)
    $0 wizard

    # Initialize config (advanced users)
    $0 init

    # Check enabled agents in config
    $0 check

    # Check all detected agents (regardless of enabled status)
    $0 check --all-agents

    # Check only claude agent
    $0 check --agent claude

    # Update enabled agents in config
    $0 update

    # Update all detected agents
    $0 update --all-agents

    # Scan for new commands
    $0 scan

    # Preview cleanup of Spec-Kit artifacts
    $0 cleanup

    # Apply cleanup
    $0 cleanup --apply

    # Run against a specific project path (no need to cd first)
    $0 status --project-root /path/to/my-project

    # Batch preview cleanup (without batch-sync-all.sh)
    $0 cleanup --all-projects --workspace-dir /path/to/workspace

    # Batch apply cleanup
    $0 cleanup --all-projects --workspace-dir /path/to/workspace --apply

    # Select and sync templates
    $0 templates select
    $0 templates sync

EOF
}

show_status() {
    log_header "Config status"

    if [[ ! -f "$CONFIG_FILE" ]]; then
        log_warning "Config file does not exist, run 'init' first"
        return 1
    fi

    local config=$(load_config)
    local version=$(get_config_version "$config")

    echo ""
    log_info "Config version: $version"
    log_info "Project name: $(echo "$config" | jq -r '.metadata.project_name')"
    log_info "Initialized at: $(echo "$config" | jq -r '.metadata.initialized')"

    echo ""
    log_section "Enabled agents"

    local agents=$(echo "$config" | jq -r '.agents | keys[]' 2>/dev/null)
    while IFS= read -r agent; do
        [[ -z "$agent" ]] && continue

        # 防禦性檢查：確保代理存在
        if [[ ! -v AGENT_NAMES[$agent] ]]; then
            continue
        fi

        local enabled=$(echo "$config" | jq -r ".agents.${agent}.enabled")
        local dir=$(echo "$config" | jq -r ".agents.${agent}.commands_dir")
        local cmd_count=$(echo "$config" | jq -r ".agents.${agent}.commands.standard | length")

        if [[ "$enabled" == "true" ]]; then
            echo "  ✓ ${AGENT_NAMES[$agent]} ($dir) - $cmd_count commands"
        fi
    done <<< "$agents"

    echo ""
    log_section "Template sync status"

    local has_templates=false
    while IFS= read -r agent; do
        [[ -z "$agent" ]] && continue

        # 防禦性檢查：確保代理存在
        if [[ ! -v AGENT_NAMES[$agent] ]]; then
            continue
        fi

        local tpl_enabled=$(echo "$config" | jq -r ".agents.${agent}.templates.enabled")
        local tpl_count=$(echo "$config" | jq -r ".agents.${agent}.templates.selected | length")
        local tpl_sync=$(echo "$config" | jq -r ".agents.${agent}.templates.last_sync // \"Never synced\"")

        if [[ "$tpl_enabled" == "true" ]] || [[ "$tpl_count" != "0" ]]; then
            has_templates=true
            echo "  ${AGENT_NAMES[$agent]}:"
            echo "    • Status: $([ "$tpl_enabled" == "true" ] && echo "enabled" || echo "disabled")"
            echo "    • Selected: $tpl_count templates"
            echo "    • Last sync: $tpl_sync"
        fi
    done <<< "$agents"

    if [[ "$has_templates" == false ]]; then
        echo "  No templates configured for any agents"
        echo "  Run 'templates select --agent <name>' to start"
    fi
}

main() {
    local command="${1:-}"
    local subcommand="${2:-}"
    local agent=""
    local all_agents=false
    local cleanup_apply=false
    local cleanup_all_projects_flag=false
    local cleanup_workspace_dir="${WORKSPACE_DIR:-${GITHUB_DIR:-$PWD}}"
    local project_root_override=""

    # 解析參數
    shift || true
    while [[ $# -gt 0 ]]; do
        case "$1" in
            --agent)
                agent="$2"
                shift 2
                ;;
            --project-root|--path)
                project_root_override="$2"
                shift 2
                ;;
            --all-agents)
                all_agents=true
                shift
                ;;
            --dry-run|-n)
                DRY_RUN=true
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
            --json)
                JSON_OUTPUT=true
                shift
                ;;
            --apply)
                cleanup_apply=true
                shift
                ;;
            --all-projects)
                cleanup_all_projects_flag=true
                shift
                ;;
            --workspace-dir)
                cleanup_workspace_dir="$2"
                shift 2
                ;;
            --github-dir)
                cleanup_workspace_dir="$2"
                shift 2
                ;;
            --help|-h)
                show_usage
                exit 0
                ;;
            *)
                subcommand="$1"
                shift
                ;;
        esac
    done

    if [[ -n "$project_root_override" ]]; then
        if [[ ! -d "$project_root_override" ]]; then
            log_error "Project path does not exist: $project_root_override"
            exit 1
        fi
        PROJECT_ROOT="$(cd "$project_root_override" && pwd)"
        CONFIG_FILE="$PROJECT_ROOT/.speckit-sync.json"
        log_info "Using project path: $PROJECT_ROOT"
    fi

    # cleanup 給「只拿來移除」使用者：採最小依賴，不要求 git/jq
    if [[ "$command" == "cleanup" ]]; then
        with_timing "Dependency check" check_dependencies diff grep find awk || exit 1
    else
        with_timing "Dependency check" check_dependencies || exit 1
    fi

    case "$command" in
        wizard)
            wizard
            ;;
        init)
            init_config
            ;;
        detect-agents)
            detect_agents
            ;;
        check)
            if [[ -n "$agent" ]]; then
                check_updates "$agent"
            elif [[ "$all_agents" == true ]]; then
                # 檢查所有偵測到的代理（不管配置中是否啟用）
                log_info "Detecting all agents and checking updates..."
                local detected_agents=($(detect_agents_quiet))

                if [[ ${#detected_agents[@]} -eq 0 ]]; then
                    log_warning "No AI agent directories detected"
                    return 1
                fi

                log_info "Found ${#detected_agents[@]} agents"
                echo ""

                for ag in "${detected_agents[@]}"; do
                    check_updates "$ag"
                    echo ""
                done
            else
                # 檢查所有啟用的代理
                local config=$(load_config)
                local agents=$(echo "$config" | jq -r '.agents | to_entries[] | select(.value.enabled == true) | .key')

                while IFS= read -r ag; do
                    [[ -z "$ag" ]] && continue
                    check_updates "$ag"
                    echo ""
                done <<< "$agents"
            fi
            ;;
        update)
            if [[ -n "$agent" ]]; then
                update_commands "$agent"
            elif [[ "$all_agents" == true ]]; then
                # 更新所有偵測到的代理（不管配置中是否啟用）
                log_info "Detecting all agents and updating..."
                local detected_agents=($(detect_agents_quiet))

                if [[ ${#detected_agents[@]} -eq 0 ]]; then
                    log_warning "No AI agent directories detected"
                    return 1
                fi

                log_info "Found ${#detected_agents[@]} agents"
                echo ""

                for ag in "${detected_agents[@]}"; do
                    update_commands "$ag"
                    echo ""
                done
            else
                # 更新所有啟用的代理
                local config=$(load_config)
                local agents=$(echo "$config" | jq -r '.agents | to_entries[] | select(.value.enabled == true) | .key')

                while IFS= read -r ag; do
                    [[ -z "$ag" ]] && continue
                    update_commands "$ag"
                    echo ""
                done <<< "$agents"
            fi
            ;;
        scan)
            if [[ -n "$agent" ]]; then
                scan_new_commands "$agent"
            else
                log_error "Please specify agent: --agent <name>"
                exit 1
            fi
            ;;
        cleanup)
            CLEANUP_APPLY="$cleanup_apply"
            if [[ "$DRY_RUN" == true ]]; then
                CLEANUP_APPLY=false
                log_info "--dry-run enabled, cleanup will run in preview mode"
            fi

            if [[ "$cleanup_all_projects_flag" == true ]]; then
                if cleanup_all_projects "$cleanup_workspace_dir" "$CLEANUP_APPLY"; then
                    exit 0
                else
                    local cleanup_batch_exit=$?
                    if [[ "$cleanup_batch_exit" -eq 10 ]]; then
                        exit 10
                    fi
                    exit "$cleanup_batch_exit"
                fi
            fi

            if cleanup_repo "$CLEANUP_APPLY"; then
                exit 0
            else
                local cleanup_exit=$?
                if [[ "$cleanup_exit" -eq 10 ]]; then
                    exit 10
                fi
                exit "$cleanup_exit"
            fi
            ;;
        rollback)
            log_warning "Backup command removed. Use git checkout to restore files if needed."
            exit 0
            ;;
        update-all)
            update_all
            ;;
        templates)
            case "$subcommand" in
                list)
                    templates_list
                    ;;
                select)
                    if [[ -n "$agent" ]]; then
                        templates_select "$agent"
                    elif [[ "$all_agents" == true ]]; then
                        # 為所有偵測到的代理選擇模版
                        local detected_agents=($(detect_agents_quiet))

                        if [[ ${#detected_agents[@]} -eq 0 ]]; then
                            log_warning "No AI agent directories detected"
                            return 1
                        fi

                        for ag in "${detected_agents[@]}"; do
                            templates_select "$ag"
                            echo ""
                        done
                    else
                        # 為所有啟用的代理選擇模版
                        local config=$(load_config)
                        local agents=$(echo "$config" | jq -r '.agents | to_entries[] | select(.value.enabled == true) | .key')

                        if [[ -z "$agents" ]]; then
                            log_error "No enabled agents found, run init first"
                            return 1
                        fi

                        while IFS= read -r ag; do
                            [[ -z "$ag" ]] && continue
                            templates_select "$ag"
                            echo ""
                        done <<< "$agents"
                    fi
                    ;;
                sync)
                    if [[ -n "$agent" ]]; then
                        update_templates "$agent"
                    elif [[ "$all_agents" == true ]]; then
                        # 同步所有偵測到的代理的模版
                        local detected_agents=($(detect_agents_quiet))

                        if [[ ${#detected_agents[@]} -eq 0 ]]; then
                            log_warning "No AI agent directories detected"
                            return 1
                        fi

                        log_info "Found ${#detected_agents[@]} agents"
                        echo ""

                        for ag in "${detected_agents[@]}"; do
                            update_templates "$ag"
                            echo ""
                        done
                    else
                        # 同步所有啟用的代理的模版
                        local config=$(load_config)
                        local agents=$(echo "$config" | jq -r '.agents | to_entries[] | select(.value.enabled == true) | .key')

                        while IFS= read -r ag; do
                            [[ -z "$ag" ]] && continue
                            update_templates "$ag"
                            echo ""
                        done <<< "$agents"
                    fi
                    ;;
                *)
                    log_error "Unknown template command: $subcommand"
                    echo "Available commands: list, select, sync"
                    exit 1
                    ;;
            esac
            ;;
        status)
            show_status
            ;;
        upgrade)
            local config=$(load_config)
            config=$(upgrade_config "$config")
            save_config "$config"
            log_success "Config upgraded to v$(get_config_version "$config")"
            ;;
        --help|-h|help)
            show_usage
            ;;
        *)
            log_error "Unknown command: $command"
            echo ""
            show_usage
            exit 1
            ;;
    esac
}

main "$@"
