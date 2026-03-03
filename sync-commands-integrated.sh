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
        log_verbose "開始: $description"
        "$@"
        local exit_code=$?
        local end_time=$(date +%s.%N)
        local duration=$(echo "$end_time - $start_time" | bc)
        log_verbose "完成: $description (耗時 ${duration}s)"
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
        echo -e "${GRAY}    指令: $*${NC}"
        return 0
    else
        "$@"
    fi
}

# 進度指示器
show_progress() {
    local current="$1"
    local total="$2"
    local message="${3:-處理中}"

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

    [[ $current -eq $total ]] && echo ""  # 完成時換行
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

    log_debug "檢查必要工具: ${required_cmds[*]}"

    for cmd in "${required_cmds[@]}"; do
        if ! command -v "$cmd" &>/dev/null; then
            missing+=("$cmd")
        fi
    done

    if [[ ${#missing[@]} -gt 0 ]]; then
        log_error "缺少必要工具"
        echo ""
        echo "${BOLD}缺少的工具：${NC}"
        printf "  ${RED}${ICON_ERROR}${NC} %s\n" "${missing[@]}"
        echo ""
        echo "${BOLD}${ICON_ROCKET} 安裝方式：${NC}"
        echo "  macOS:   ${CYAN}brew install ${missing[*]}${NC}"
        echo "  Ubuntu:  ${CYAN}sudo apt install ${missing[*]}${NC}"
        echo "  CentOS:  ${CYAN}sudo yum install ${missing[*]}${NC}"
        return 1
    fi

    log_debug "依賴檢查通過"
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
        log_warning "spec-kit 不是 git 倉庫，跳過自動更新"
        return 0
    fi

    log_info "檢查 spec-kit 是否有新版本..."

    cd "$SPECKIT_PATH"

    # 檢查是否有未提交的變更
    if ! git diff-index --quiet HEAD -- 2>/dev/null; then
        log_warning "spec-kit 有未提交的變更，跳過自動更新"
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
        log_warning "無法從 GitHub 獲取最新版本，使用本地版本"
        log_info "本地版本: $current_tag"
        cd - >/dev/null
        return 0
    fi

    # 比較版本（移除 v 前綴）
    local comparison=$(compare_versions "$current_tag" "$latest_tag")

    if [[ "$comparison" == "<" ]]; then
        log_info "發現新版本: $current_tag → $latest_tag"
        log_info "正在更新到 $latest_tag..."

        # Fetch tags
        git fetch --tags --quiet 2>/dev/null || {
            log_error "無法 fetch tags"
            cd - >/dev/null
            return 1
        }

        # Checkout 到最新 tag
        if git checkout "$latest_tag" --quiet 2>/dev/null; then
            log_success "spec-kit 已更新: $current_tag → $latest_tag"
        else
            log_error "無法切換到 $latest_tag"
            cd - >/dev/null
            return 1
        fi
    else
        log_success "spec-kit 已是最新版本 ($current_tag)"
    fi

    cd - >/dev/null
}

# ==============================================================================
# 動態命令掃描 (Phase 1)
# ==============================================================================

get_standard_commands_from_speckit() {
    local commands=()

    if [[ ! -d "$SPECKIT_COMMANDS" ]]; then
        log_error "找不到 spec-kit 命令目錄"
        echo ""
        echo "${BOLD}${ICON_WARNING} 預期路徑：${NC}$SPECKIT_COMMANDS"
        echo ""
        echo "${BOLD}${ICON_WARNING} 可能的原因：${NC}"
        echo "  1. SPECKIT_PATH 設定錯誤"
        echo "  2. spec-kit 倉庫不完整"
        echo "  3. spec-kit 版本過舊"
        echo ""
        echo "${BOLD}${ICON_ROCKET} 建議操作：${NC}"
        echo "  1. 檢查當前設定："
        echo "     ${CYAN}echo \$SPECKIT_PATH${NC}"
        echo "     ${GRAY}目前值: $SPECKIT_PATH${NC}"
        echo ""
        echo "  2. 驗證目錄結構："
        echo "     ${CYAN}ls -la $SPECKIT_PATH${NC}"
        echo ""
        echo "  3. 重新克隆 spec-kit："
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
        specify.md) echo "撰寫功能規格" ;;
        plan.md) echo "制定實作計劃" ;;
        tasks.md) echo "分解任務清單" ;;
        implement.md) echo "執行程式碼實作" ;;
        constitution.md) echo "專案憲法與原則" ;;
        clarify.md) echo "釐清需求" ;;
        analyze.md) echo "程式碼分析" ;;
        checklist.md) echo "執行檢查清單" ;;
        *) echo "未知命令" ;;
    esac
}

scan_new_commands() {
    local agent="$1"

    # 防禦性檢查：確保代理存在
    if [[ ! -v AGENTS[$agent] ]]; then
        log_error "未知代理: $agent"
        return 1
    fi

    local commands_dir="$(resolve_agent_dir "$agent")"

    log_section "掃描新命令 ($agent)"

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
        log_success "沒有發現新命令"
        return
    fi

    log_info "發現 ${#new_commands[@]} 個新命令："
    for cmd in "${new_commands[@]}"; do
        local desc=$(get_command_description "$SPECKIT_COMMANDS/$cmd")
        echo "  ⊕ $cmd - $desc"
    done

    # 互動式選擇
    echo ""
    read -p "是否要將這些新命令加入同步列表？[y/N] " -r
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        for cmd in "${new_commands[@]}"; do
            config=$(echo "$config" | jq ".agents.${agent}.commands.standard += [\"$cmd\"]")
        done
        save_config "$config"
        log_success "已添加 ${#new_commands[@]} 個新命令到配置"
    else
        log_info "已跳過新命令添加"
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
        log_warning "找不到 trash，改用 rm -rf: $path"
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

    log_header "清理 Spec-Kit 痕跡"
    log_info "模式: $([ "$apply_mode" == "true" ] && echo "套用 (--apply)" || echo "預覽")"

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
        log_warning "找不到 $SPECKIT_COMMANDS，將略過模板精準比對"
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
        log_info "未發現 Spec-Kit 痕跡"
        [[ -n "$agents_tmp" ]] && rm -f "$agents_tmp"
        return 10
    fi

    echo ""
    log_section "命中項目"
    local i
    for i in "${!delete_targets[@]}"; do
        if [[ "$apply_mode" == "true" ]]; then
            echo "  - 刪除: ${delete_targets[$i]} (${delete_reasons[$i]})"
        else
            echo "  - 將刪除: ${delete_targets[$i]} (${delete_reasons[$i]})"
        fi
    done

    if [[ "$agents_action" == "rewrite" ]]; then
        echo "  - $([ "$apply_mode" == "true" ] && echo "改寫" || echo "將改寫"): $agents_file (移除 Spec-Kit 區塊)"
    elif [[ "$agents_action" == "delete" ]]; then
        echo "  - $([ "$apply_mode" == "true" ] && echo "刪除" || echo "將刪除"): $agents_file (清理後為空)"
    fi

    if [[ "$apply_mode" != "true" ]]; then
        echo ""
        log_info "預覽完成。若要實際清理，請加上 --apply。"
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
    log_header "清理完成"
    echo "  ${ICON_SUCCESS} 已刪除: $deleted_count"
    echo "  ${ICON_SUCCESS} 已改寫: $modified_count"
    echo "  ${ICON_PACKAGE} 總命中: $total_hits"

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

    log_header "批次清理 Spec-Kit 痕跡"
    log_info "掃描目錄: $workspace_dir"

    if [[ ! -d "$workspace_dir" ]]; then
        log_error "目錄不存在: $workspace_dir"
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
        log_info "未找到 Spec-Kit 痕跡"
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
    log_section "偵測 AI 代理"

    local detected=()

    for agent in "${!AGENTS[@]}"; do
        if dir=$(find_existing_agent_dir "$agent"); then
            detected+=("$agent")
            log_success "${AGENT_NAMES[$agent]} ($dir)"
        fi
    done

    if [[ ${#detected[@]} -eq 0 ]]; then
        log_warning "未偵測到任何 AI 代理目錄"
        return 1
    fi

    echo ""
    log_info "偵測到 ${#detected[@]} 個代理"

    echo "${detected[@]}"
}

select_agents_interactive() {
    # 將所有互動輸出重定向到 stderr，只有最終結果輸出到 stdout
    {
        log_section "選擇要啟用的代理"

        local detected_agents=($(detect_agents_quiet))

        if [[ ${#detected_agents[@]} -eq 0 ]]; then
            log_error "沒有偵測到任何代理"
            return 1
        fi

        local selected=()

        echo "請選擇要啟用同步的代理（空格鍵選擇，Enter 確認）："
        echo ""

        for i in "${!detected_agents[@]}"; do
            local agent="${detected_agents[$i]}"

            # 防禦性檢查：確保代理存在於映射表中
            if [[ ! -v AGENT_NAMES[$agent] ]] || [[ ! -v AGENTS[$agent] ]]; then
                log_warning "跳過未知代理: $agent"
                continue
            fi

            local name="${AGENT_NAMES[$agent]}"
            local dir="$(resolve_agent_dir "$agent")"

            read -p "[$((i+1))] $name ($dir) [Y/n] " -r || true
            if [[ -z "${REPLY:-}" ]] || [[ "${REPLY:-y}" =~ ^[Yy]$ ]]; then
                selected+=("$agent")
                log_success "已選擇: $name"
            else
                log_info "已跳過: $name"
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
        log_debug "配置文件不存在，返回空配置"
        echo "{}"
        return
    fi

    log_debug "載入配置: $CONFIG_FILE"

    # 驗證 JSON 格式
    if ! jq empty "$CONFIG_FILE" 2>/dev/null; then
        log_error "配置文件格式錯誤（無效的 JSON）"
        echo ""
        echo "${BOLD}${ICON_WARNING} 配置文件位置：${NC}$CONFIG_FILE"
        echo ""
        echo "${BOLD}${ICON_ROCKET} 建議操作：${NC}"
        echo "  1. 檢查文件內容："
        echo "     ${CYAN}cat $CONFIG_FILE${NC}"
        echo ""
        echo "  2. 驗證 JSON 語法："
        echo "     ${CYAN}jq . $CONFIG_FILE${NC}"
        echo ""
        echo "  3. 重新初始化（會覆蓋現有配置）："
        echo "     ${CYAN}rm $CONFIG_FILE && speckit-sync init${NC}"
        echo ""
        echo "  4. 從備份恢復（如果有）："
        echo "     ${CYAN}cp $CONFIG_FILE.backup $CONFIG_FILE${NC}"
        return 1
    fi

    local config=$(cat "$CONFIG_FILE")

    # 驗證必要欄位
    local version=$(echo "$config" | jq -r '.version // empty')
    if [[ -z "$version" ]]; then
        log_warning "配置缺少版本號，可能需要升級"
        log_info "執行 ${CYAN}upgrade${NC} 命令來升級配置"
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

    log_info "當前配置版本: $current_version"

    # v1.0.0 → v1.1.0：添加動態命令掃描
    if [[ "$current_version" == "1.0.0" ]]; then
        log_info "升級配置: v1.0.0 → v1.1.0"
        config=$(echo "$config" | jq '.version = "1.1.0"')
        current_version="1.1.0"
    fi

    # v1.1.0 → v2.0.0：添加多代理支援
    if [[ "$current_version" == "1.1.0" ]]; then
        log_info "升級配置: v1.1.0 → v2.0.0"

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
        log_info "升級配置: v2.0.0 → v2.1.0"

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
        log_warning "spec-kit 模版目錄不存在: $SPECKIT_TEMPLATES"
        return
    fi

    for file in "$SPECKIT_TEMPLATES"/*; do
        [[ -f "$file" ]] && templates+=("$(basename "$file")")
    done

    echo "${templates[@]}"
}

templates_list() {
    log_header "可用模版列表"

    local templates=($(get_available_templates))

    if [[ ${#templates[@]} -eq 0 ]]; then
        log_warning "未找到任何模版"
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
        log_error "未知代理: $agent"
        return 1
    fi

    log_header "同步 ${AGENT_NAMES[$agent]} 模版"

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
    dry_run_execute "建立模版目錄: $templates_dir" mkdir -p "$templates_dir" </dev/null

    echo ""

    local synced=0
    local added=0
    local skipped=0

    for tpl in "${templates_array[@]}"; do
        local src="$SPECKIT_TEMPLATES/$tpl"
        local dest="$templates_dir/$tpl"

        if [[ ! -f "$src" ]]; then
            log_warning "$tpl - 來源檔案不存在於 spec-kit"
            : $((skipped++))
            continue
        fi

        # 檢查檔案是否已存在且相同
        if [[ -f "$dest" ]] && diff -q "$src" "$dest" >/dev/null 2>&1 </dev/null; then
            log_info "$tpl - 已是最新"
            : $((skipped++))
        else
            dry_run_execute "同步模版: $tpl" cp "$src" "$dest" </dev/null
            if [[ -f "$dest" ]]; then
                log_success "$tpl - 已更新"
                : $((synced++))
            else
                log_success "$tpl - 已新增"
                : $((added++))
            fi
        fi
    done

    echo ""
    log_info "統計："
    echo "  ✅ 已同步: $synced"
    echo "  ⊕  新增: $added"
    echo "  ⊙  跳過: $skipped"
    echo "  ═══════════"
    echo "  📦 總計: $((synced + added + skipped))"

    # 更新最後同步時間
    if [[ "$DRY_RUN" == false ]]; then
        config=$(echo "$config" | jq --arg agent "$agent" \
            ".agents[\$agent].templates.last_sync = \"$(date -u +%Y-%m-%dT%H:%M:%SZ)\"")
        save_config "$config"
    fi

    log_success "模版已同步到: $templates_dir"
}

templates_select() {
    local agent="$1"

    # 防禦性檢查：確保代理存在
    if [[ ! -v AGENT_NAMES[$agent] ]] || [[ ! -v AGENTS[$agent] ]]; then
        log_error "未知代理: $agent"
        return 1
    fi

    log_header "選擇 ${AGENT_NAMES[$agent]} 的模版"

    local templates=($(get_available_templates))

    if [[ ${#templates[@]} -eq 0 ]]; then
        log_error "未找到任何模版"
        return 1
    fi

    local config=$(load_config)
    local selected=()

    echo ""
    echo "可用模版："
    echo ""

    for i in "${!templates[@]}"; do
        local tpl="${templates[$i]}"
        printf "[%2d] %s\n" "$((i+1))" "$tpl"
    done

    echo ""
    echo "選擇方式："
    echo "  • 輸入數字（空格分隔）: 1 3 5"
    echo "  • 輸入範圍: 1-3"
    echo "  • 全選: a 或 all"
    echo "  • 取消: q 或 quit"
    echo ""

    read -p "請選擇 > " -r

    if [[ "$REPLY" == "q" ]] || [[ "$REPLY" == "quit" ]]; then
        log_info "已取消"
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
        log_warning "未選擇任何模版"
        return 1
    fi

    # 去重
    selected=($(printf '%s\n' "${selected[@]}" | sort -u))

    echo ""
    log_success "已選擇 ${#selected[@]} 個模版："
    for tpl in "${selected[@]}"; do
        echo "  • $tpl"
    done

    # 更新配置
    local selected_json=$(printf '%s\n' "${selected[@]}" | jq -R . | jq -s .)
    config=$(echo "$config" | jq --arg agent "$agent" --argjson sel "$selected_json" \
        ".agents[\$agent].templates.selected = \$sel | .agents[\$agent].templates.enabled = true")
    save_config "$config"

    echo ""
    log_success "配置已更新"
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
        log_error "未知代理: $agent"
        return 1
    fi

    local commands_dir="$(resolve_agent_dir "$agent")"

    local source="$SPECKIT_COMMANDS/$command"
    local target="$PROJECT_ROOT/$commands_dir/$command"

    if [[ ! -f "$source" ]]; then
        log_error "$command - 來源檔案不存在"
        return 1
    fi

    dry_run_execute "建立目錄: $(dirname "$target")" mkdir -p "$(dirname "$target")"
    dry_run_execute "複製檔案: $source → $target" cp "$source" "$target"
    return 0
}

check_updates() {
    local agent="$1"

    # 防禦性檢查：確保代理存在
    if [[ ! -v AGENT_NAMES[$agent] ]]; then
        log_error "未知代理: $agent"
        return 1
    fi

    log_header "檢查 ${AGENT_NAMES[$agent]} 更新"

    # 自動更新 spec-kit
    with_timing "spec-kit 更新檢查" update_speckit_repo

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
                echo -e "${GREEN}✓${NC} $cmd - 已是最新"
                synced=$((synced + 1))
                ;;
            outdated)
                echo -e "${YELLOW}↻${NC} $cmd - 有更新可用"
                outdated=$((outdated + 1))
                ;;
            new)
                echo -e "${CYAN}⊕${NC} $cmd - 本地不存在（新命令）"
                new=$((new + 1))
                ;;
            missing_source)
                echo -e "${RED}✗${NC} $cmd - spec-kit 中不存在"
                missing=$((missing + 1))
                ;;
        esac
    done <<< "$commands"

    echo ""
    log_info "統計："
    echo "  ✅ 已同步: $synced"
    echo "  ⊕  缺少: $new"
    echo "  ↻  過時: $outdated"
    echo "  ✗  遺失: $missing"
    echo "  ═══════════"
    echo "  📦 總計: $((synced + new + outdated + missing))"

    if [[ $((new + outdated)) -gt 0 ]]; then
        echo ""
        log_warning "發現 $((new + outdated)) 個命令需要更新"
        log_info "執行 'update' 來更新"
    fi
}

# ==============================================================================
# 命令同步
# ==============================================================================

update_commands() {
    local agent="$1"

    # 防禦性檢查：確保代理存在
    if [[ ! -v AGENT_NAMES[$agent] ]] || [[ ! -v AGENTS[$agent] ]]; then
        log_error "未知代理: $agent"
        return 1
    fi

    log_header "同步 ${AGENT_NAMES[$agent]} 命令"

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
                log_info "$cmd - 已是最新，跳過"
                skipped=$((skipped + 1))
                ;;
            outdated)
                if sync_command "$agent" "$cmd"; then
                    log_success "$cmd - 已更新"
                    updated=$((updated + 1))
                fi
                ;;
            new)
                if sync_command "$agent" "$cmd"; then
                    log_success "$cmd - 新增"
                    added=$((added + 1))
                fi
                ;;
            missing_source)
                log_error "$cmd - spec-kit 中不存在"
                ;;
        esac
    done <<< "$commands"

    echo ""
    log_header "同步完成"
    echo "  ⊕  新增: $added 個"
    echo "  ↻  更新: $updated 個"
    echo "  ✓  跳過: $skipped 個"
}

# ==============================================================================
# 一鍵更新流程
# ==============================================================================

update_all() {
    log_header "一鍵同步"

    local output_json="$JSON_OUTPUT"
    local has_failure=0

    if [[ "$DRY_RUN" == true ]]; then
        log_info "[DRY-RUN] 略過 spec-kit 更新"
    else
        with_timing "spec-kit 更新檢查" update_speckit_repo
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
        log_warning "未找到可處理的代理，請先執行 init 或創建代理目錄"
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
            local message="${display} 已偵測到，但系統未找到 CLI (${cli_name})."
            summary_missing_cli+=("$display|$message")
            if [[ "$output_json" == true ]]; then
                json_records+=("$(jq -cn --arg project "$PROJECT_ROOT" --arg agent "$agent" --arg name "$display" --arg status "skipped" --arg reason "missing_cli" '{project:$project,agent:$agent,name:$name,status:$status,reason:$reason}')")
            fi
            log_warning "$message"
            continue
        fi

        if [[ "$configured" != true ]]; then
            local message="${display} 尚未在配置中啟用。"
            summary_skipped+=("$display|$message")
            if [[ "$output_json" == true ]]; then
                json_records+=("$(jq -cn --arg project "$PROJECT_ROOT" --arg agent "$agent" --arg name "$display" --arg status "skipped" --arg reason "not_configured" '{project:$project,agent:$agent,name:$name,status:$status,reason:$reason}')")
            fi
            log_info "$message"
            continue
        fi

        if [[ "$DRY_RUN" == true ]]; then
            local message="[DRY-RUN] ${display} 將執行命令與範本同步"
            summary_preview+=("$display|$message")
            if [[ "$output_json" == true ]]; then
                json_records+=("$(jq -cn --arg project "$PROJECT_ROOT" --arg agent "$agent" --arg name "$display" --arg status "preview" --arg reason "dry_run" '{project:$project,agent:$agent,name:$name,status:$status,reason:$reason}')")
            fi
            log_info "$message"
            continue
        fi

        log_section "處理 $display"

        local templates_enabled
        templates_enabled="$(printf '%s' "$config" | jq -r --arg agent "$agent" '(.agents // {})[$agent].templates.enabled // false' 2>/dev/null)"
        [[ "$templates_enabled" == "null" ]] && templates_enabled="false"

        local template_status="disabled"

        if update_commands "$agent"; then
            local message="${display} 命令同步完成"

            if [[ "$templates_enabled" == "true" ]]; then
                template_status="skipped"
                if update_templates "$agent"; then
                    template_status="synced"
                else
                    template_status="failed"
                    has_failure=1
                    local fail_msg="${display} 模版同步失敗"
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
            local message="${display} 命令同步失敗"
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
    log_header "一鍵更新摘要"

    if [[ ${#summary_success[@]} -eq 0 && ${#summary_preview[@]} -eq 0 && ${#summary_skipped[@]} -eq 0 && ${#summary_missing_cli[@]} -eq 0 && ${#summary_failed[@]} -eq 0 ]]; then
        log_info "沒有可顯示的結果"
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
        log_info "JSON 報告已輸出到: $JSON_REPORT_PATH"
    fi

    return "$has_failure"
}

# ==============================================================================
# ==============================================================================
# 互動式精靈
# ==============================================================================

wizard() {
    log_header "SpecKit Sync 互動式設定精靈"

    echo ""
    echo -e "${BOLD}歡迎使用 SpecKit Sync！${NC}"
    echo "這個精靈將協助您完成初始設定並開始同步命令。"
    echo ""

    # ==================== 步驟 1: 環境檢查 ====================
    log_section "步驟 1/6: 環境檢查"
    echo ""

    # 檢查依賴
    log_info "檢查必要工具..."
    if ! check_dependencies; then
        log_error "請先安裝必要工具後再執行精靈"
        return 1
    fi
    log_success "所有必要工具已安裝"

    echo ""

    # 檢查 spec-kit 路徑
    log_info "檢查 spec-kit 路徑..."
    if [[ ! -d "$SPECKIT_PATH" ]]; then
        log_error "spec-kit 路徑無效: $SPECKIT_PATH"
        echo ""
        echo "${BOLD}${ICON_ROCKET} 可選操作：${NC}"
        echo "  1. 設定 SPECKIT_PATH 環境變數指向正確路徑"
        echo "  2. 將 spec-kit 克隆到: $(dirname "$SCRIPT_DIR")/spec-kit"
        echo ""
        read -p "是否要自動克隆 spec-kit？[y/N] " -r
        if [[ $REPLY =~ ^[Yy]$ ]]; then
            local clone_path="$(dirname "$SCRIPT_DIR")/spec-kit"
            log_info "克隆 spec-kit 到 $clone_path..."
            if git clone https://github.com/github/github-models-template.git "$clone_path" 2>/dev/null; then
                SPECKIT_PATH="$clone_path"
                SPECKIT_COMMANDS="$SPECKIT_PATH/templates/commands"
                SPECKIT_TEMPLATES="$SPECKIT_PATH/templates"
                log_success "spec-kit 克隆成功"
            else
                log_error "克隆失敗，請手動設定"
                return 1
            fi
        else
            return 1
        fi
    else
        log_success "spec-kit 路徑有效: $SPECKIT_PATH"

        # 檢查是否需要更新
        if [[ -d "$SPECKIT_PATH/.git" ]]; then
            log_info "檢查 spec-kit 更新..."
            update_speckit_repo
        fi
    fi

    echo ""

    # ==================== 步驟 2: 偵測代理 ====================
    log_section "步驟 2/6: 偵測 AI 代理"
    echo ""

    log_info "掃描專案目錄..."
    local detected_agents=($(detect_agents_quiet))

    if [[ ${#detected_agents[@]} -eq 0 ]]; then
        log_warning "未偵測到任何 AI 代理目錄"
        echo ""
        echo "${BOLD}${ICON_INFO} 支援的代理及其目錄：${NC}"
        for agent in "${!AGENTS[@]}"; do
            echo "  • ${AGENT_NAMES[$agent]}: ${AGENTS[$agent]}"
        done
        echo ""
        read -p "是否要為 Claude Code 創建預設目錄？[y/N] " -r
        if [[ $REPLY =~ ^[Yy]$ ]]; then
            mkdir -p "$PROJECT_ROOT/.claude/commands"
            log_success "已創建 .claude/commands 目錄"
            detected_agents=("claude")
        else
            log_error "無可用代理，無法繼續"
            return 1
        fi
    else
        log_success "偵測到 ${#detected_agents[@]} 個代理："
        for agent in "${detected_agents[@]}"; do
            echo "  ${GREEN}${ICON_SUCCESS}${NC} ${AGENT_NAMES[$agent]} ($(resolve_agent_dir "$agent"))"
        done
    fi

    echo ""

    # ==================== 步驟 3: 選擇要啟用的代理 ====================
    log_section "步驟 3/6: 選擇要啟用的代理"
    echo ""

    local selected_agents=()

    if [[ ${#detected_agents[@]} -eq 1 ]]; then
        log_info "只有一個代理，自動選擇: ${AGENT_NAMES[${detected_agents[0]}]}"
        selected_agents=("${detected_agents[0]}")
    else
        echo "請選擇要啟用同步的代理："
        echo ""

        for i in "${!detected_agents[@]}"; do
            local agent="${detected_agents[$i]}"
            local name="${AGENT_NAMES[$agent]}"
            local dir="$(resolve_agent_dir "$agent")"

            read -p "  [$((i+1))] $name ($dir) - 啟用？[Y/n] " -r
            if [[ -z "${REPLY:-}" ]] || [[ "${REPLY:-y}" =~ ^[Yy]$ ]]; then
                selected_agents+=("$agent")
                log_success "  已選擇: $name"
            else
                log_info "  已跳過: $name"
            fi
        done
    fi

    if [[ ${#selected_agents[@]} -eq 0 ]]; then
        log_error "未選擇任何代理"
        return 1
    fi

    echo ""
    log_success "已選擇 ${#selected_agents[@]} 個代理"

    echo ""

    # ==================== 步驟 4: 選擇同步策略 ====================
    log_section "步驟 4/6: 選擇同步策略"
    echo ""

    echo "${BOLD}同步策略選項：${NC}"
    echo "  [1] 半自動模式（推薦）- 有衝突時詢問，自動備份"
    echo "  [2] 完全自動模式 - 自動覆蓋，保留備份"
    echo "  [3] 手動模式 - 每個檔案都確認"
    echo ""

    local strategy_mode="semi-auto"
    local on_conflict="ask"

    read -p "請選擇 (1-3) [預設: 1]: " -r
    case "${REPLY:-1}" in
        1)
            strategy_mode="semi-auto"
            on_conflict="ask"
            log_success "已選擇：半自動模式"
            ;;
        2)
            strategy_mode="auto"
            on_conflict="overwrite"
            log_success "已選擇：完全自動模式"
            ;;
        3)
            strategy_mode="manual"
            on_conflict="ask"
            log_success "已選擇：手動模式"
            ;;
        *)
            log_warning "無效選擇，使用預設值：半自動模式"
            ;;
    esac

    echo ""

    # ==================== 步驟 5: 選擇要同步的命令 ====================
    log_section "步驟 5/6: 選擇要同步的命令"
    echo ""

    log_info "掃描 spec-kit 中的可用命令..."
    local standard_commands=($(get_standard_commands_from_speckit))

    if [[ ${#standard_commands[@]} -eq 0 ]]; then
        log_error "未找到任何命令"
        return 1
    fi

    log_success "發現 ${#standard_commands[@]} 個標準命令"
    echo ""

    echo "${BOLD}命令選擇：${NC}"
    echo "  [1] 同步所有命令（推薦新專案）"
    echo "  [2] 只同步核心命令（specify, plan, tasks, implement）"
    echo "  [3] 自訂選擇"
    echo ""

    local selected_commands=()

    read -p "請選擇 (1-3) [預設: 1]: " -r
    case "${REPLY:-1}" in
        1)
            selected_commands=("${standard_commands[@]}")
            log_success "已選擇：所有 ${#selected_commands[@]} 個命令"
            ;;
        2)
            local core_commands=("specify.md" "plan.md" "tasks.md" "implement.md")
            for cmd in "${core_commands[@]}"; do
                if [[ " ${standard_commands[@]} " =~ " ${cmd} " ]]; then
                    selected_commands+=("$cmd")
                fi
            done
            log_success "已選擇：${#selected_commands[@]} 個核心命令"
            ;;
        3)
            echo ""
            echo "${BOLD}可用命令：${NC}"
            for i in "${!standard_commands[@]}"; do
                local cmd="${standard_commands[$i]}"
                local desc=$(get_command_description "$SPECKIT_COMMANDS/$cmd")
                printf "  [%2d] %s - %s\n" "$((i+1))" "$cmd" "$desc"
            done
            echo ""
            echo "請輸入要同步的命令編號（空格分隔，Enter 結束）："
            read -p "> " -r

            for num in $REPLY; do
                if [[ "$num" =~ ^[0-9]+$ ]] && [[ "$num" -ge 1 ]] && [[ "$num" -le "${#standard_commands[@]}" ]]; then
                    local idx=$((num - 1))
                    selected_commands+=("${standard_commands[$idx]}")
                fi
            done

            if [[ ${#selected_commands[@]} -eq 0 ]]; then
                log_warning "未選擇任何命令，使用所有命令"
                selected_commands=("${standard_commands[@]}")
            else
                log_success "已選擇：${#selected_commands[@]} 個命令"
            fi
            ;;
        *)
            log_warning "無效選擇，使用預設值：所有命令"
            selected_commands=("${standard_commands[@]}")
            ;;
    esac

    echo ""

    # ==================== 步驟 6: 創建配置並執行同步 ====================
    log_section "步驟 6/6: 創建配置並執行同步"
    echo ""

    # 檢查是否已有配置
    if [[ -f "$CONFIG_FILE" ]]; then
        log_warning "配置檔案已存在"
        read -p "是否要覆蓋現有配置？[y/N] " -r
        if [[ ! $REPLY =~ ^[Yy]$ ]]; then
            log_info "保留現有配置，結束精靈"
            return 0
        fi

        # 備份現有配置
        local backup_file="$CONFIG_FILE.backup.$(date +%Y%m%d_%H%M%S)"
        cp "$CONFIG_FILE" "$backup_file"
        log_success "現有配置已備份: $backup_file"
    fi

    # 建立配置
    log_info "創建配置檔案..."

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
    log_success "配置檔案已創建: $CONFIG_FILE"

    echo ""

    # 詢問是否立即執行同步
    read -p "是否要立即執行命令同步？[Y/n] " -r
    if [[ -z "${REPLY:-}" ]] || [[ "${REPLY:-y}" =~ ^[Yy]$ ]]; then
        echo ""
        log_header "開始同步命令"

        for agent in "${selected_agents[@]}"; do
            echo ""
            update_commands "$agent"
        done

        echo ""
        log_header "精靈完成"
        echo ""
        log_success "設定完成！所有命令已同步。"
    else
        echo ""
        log_header "精靈完成"
        echo ""
        log_success "設定完成！"
        echo ""
        log_info "下一步："
        echo "  1. 執行 'check' 檢查更新"
        echo "  2. 執行 'update' 同步命令"
        echo "  3. 執行 'templates select' 選擇要同步的模版"
    fi

    echo ""
}
# 初始化
# ==============================================================================

init_config() {
    log_header "初始化 SpecKit Sync 配置"

    if [[ -f "$CONFIG_FILE" ]]; then
        log_warning "配置檔案已存在: $CONFIG_FILE"
        read -p "是否要重新初始化？[y/N] " -r
        [[ ! $REPLY =~ ^[Yy]$ ]] && return
    fi

    # 檢查 spec-kit 路徑
    if [[ ! -d "$SPECKIT_PATH" ]]; then
        log_error "spec-kit 路徑無效: $SPECKIT_PATH"
        log_info "請設定正確的 SPECKIT_PATH 環境變數"
        return 1
    fi

    # 偵測並選擇代理
    local detected_agents=($(detect_agents 2>/dev/null))

    if [[ ${#detected_agents[@]} -eq 0 ]]; then
        log_error "未偵測到任何 AI 代理目錄"
        log_info "請確保專案中至少有一個代理目錄（如 .claude/commands）"
        return 1
    fi

    local selected_agents=($(select_agents_interactive))

    if [[ ${#selected_agents[@]} -eq 0 ]]; then
        log_error "未選擇任何代理"
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
            log_warning "跳過未知代理: $agent"
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

    log_success "初始化完成！"
    log_info "配置檔案: $CONFIG_FILE"
    log_info "已啟用代理: ${selected_agents[*]}"
    log_info "偵測到 ${#standard_commands[@]} 個標準命令"

    echo ""
    log_info "下一步："
    echo "  1. 執行 'check' 檢查更新"
    echo "  2. 執行 'update' 同步命令"
    echo "  3. 執行 'templates select' 選擇要同步的模版"
}

# ==============================================================================
# 主程式
# ==============================================================================

show_usage() {
    cat <<EOF
${CYAN}${BOLD}SpecKit Sync - 整合版同步工具 v${VERSION}${NC}

使用方式:
    $0 <command> [options]

命令:
    wizard                       互動式設定精靈（推薦新手使用）
    init                         初始化配置
    detect-agents                偵測可用的 AI 代理
    check [options]              檢查更新狀態
    update [options]             執行命令同步
    scan [--agent <name>]        掃描並添加新命令
    cleanup [--apply] [--all-projects] [--workspace-dir PATH]
                                 清理 Spec-Kit 注入痕跡（預設為預覽）
    update-all [options]         一鍵檢查並同步所有代理

    templates list               列出可用模版
    templates select             選擇要同步的模版
    templates sync               同步已選擇的模版

    status                       顯示當前配置狀態
    upgrade                      升級配置檔案版本

選項:
    --agent <name>               指定要操作的代理
    --project-root <path>        指定目標專案路徑（預設: 當前目錄）
    --path <path>                --project-root 縮寫
    --all-agents                 自動偵測並處理所有代理（忽略配置檔啟用狀態）
    --dry-run, -n                預覽模式（顯示將執行的操作但不實際執行）
    --quiet, -q                  安靜模式（僅顯示錯誤）
    --verbose, -v                詳細模式（顯示額外資訊）
    --debug                      除錯模式（顯示所有訊息和計時）
    --json                       在 update-all 時輸出 JSON 報告
    --apply                      與 cleanup 搭配，實際執行刪除/改寫
    --all-projects               與 cleanup 搭配，掃描 workspace 下所有 repo
    --workspace-dir <path>       與 cleanup --all-projects 搭配（推薦）
    --github-dir <path>          --workspace-dir 相容別名
    --help                       顯示此幫助訊息

環境變數:
    SPECKIT_PATH                 spec-kit 倉庫路徑 (預設: ../spec-kit)
    VERBOSITY                    輸出層級: quiet|normal|verbose|debug (預設: normal)
    WORKSPACE_DIR                cleanup 批次掃描根目錄 (預設: ~/Documents/GitHub)
    GITHUB_DIR                   WORKSPACE_DIR 的相容別名

範例:
    # 使用互動式精靈（推薦第一次使用）
    $0 wizard

    # 初始化配置（進階用戶）
    $0 init

    # 檢查配置中啟用的代理
    $0 check

    # 檢查所有偵測到的代理（不管是否啟用）
    $0 check --all-agents

    # 只檢查 claude 代理
    $0 check --agent claude

    # 更新配置中啟用的代理
    $0 update

    # 更新所有偵測到的代理
    $0 update --all-agents

    # 掃描新命令
    $0 scan

    # 預覽清理 Spec-Kit 痕跡
    $0 cleanup

    # 套用清理
    $0 cleanup --apply

    # 指定單一專案路徑（不需先 cd）
    $0 status --project-root /path/to/my-project

    # 批次預覽清理（不用 batch-sync-all.sh）
    $0 cleanup --all-projects --workspace-dir /path/to/workspace

    # 批次套用清理
    $0 cleanup --all-projects --workspace-dir /path/to/workspace --apply

    # 選擇並同步模版
    $0 templates select
    $0 templates sync

EOF
}

show_status() {
    log_header "配置狀態"

    if [[ ! -f "$CONFIG_FILE" ]]; then
        log_warning "配置檔案不存在，請先執行 'init'"
        return 1
    fi

    local config=$(load_config)
    local version=$(get_config_version "$config")

    echo ""
    log_info "配置版本: $version"
    log_info "專案名稱: $(echo "$config" | jq -r '.metadata.project_name')"
    log_info "初始化時間: $(echo "$config" | jq -r '.metadata.initialized')"

    echo ""
    log_section "已啟用代理"

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
            echo "  ✓ ${AGENT_NAMES[$agent]} ($dir) - $cmd_count 個命令"
        fi
    done <<< "$agents"

    echo ""
    log_section "模版同步狀態"

    local has_templates=false
    while IFS= read -r agent; do
        [[ -z "$agent" ]] && continue

        # 防禦性檢查：確保代理存在
        if [[ ! -v AGENT_NAMES[$agent] ]]; then
            continue
        fi

        local tpl_enabled=$(echo "$config" | jq -r ".agents.${agent}.templates.enabled")
        local tpl_count=$(echo "$config" | jq -r ".agents.${agent}.templates.selected | length")
        local tpl_sync=$(echo "$config" | jq -r ".agents.${agent}.templates.last_sync // \"從未同步\"")

        if [[ "$tpl_enabled" == "true" ]] || [[ "$tpl_count" != "0" ]]; then
            has_templates=true
            echo "  ${AGENT_NAMES[$agent]}:"
            echo "    • 狀態: $([ "$tpl_enabled" == "true" ] && echo "已啟用" || echo "未啟用")"
            echo "    • 已選擇: $tpl_count 個模版"
            echo "    • 最後同步: $tpl_sync"
        fi
    done <<< "$agents"

    if [[ "$has_templates" == false ]]; then
        echo "  未配置任何代理的模版"
        echo "  執行 'templates select --agent <name>' 開始"
    fi
}

main() {
    local command="${1:-}"
    local subcommand="${2:-}"
    local agent=""
    local all_agents=false
    local cleanup_apply=false
    local cleanup_all_projects_flag=false
    local cleanup_workspace_dir="${WORKSPACE_DIR:-${GITHUB_DIR:-$HOME/Documents/GitHub}}"
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
            log_error "專案路徑不存在: $project_root_override"
            exit 1
        fi
        PROJECT_ROOT="$(cd "$project_root_override" && pwd)"
        CONFIG_FILE="$PROJECT_ROOT/.speckit-sync.json"
        log_info "使用專案路徑: $PROJECT_ROOT"
    fi

    # cleanup 給「只拿來移除」使用者：採最小依賴，不要求 git/jq
    if [[ "$command" == "cleanup" ]]; then
        with_timing "依賴檢查" check_dependencies diff grep find awk || exit 1
    else
        with_timing "依賴檢查" check_dependencies || exit 1
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
                log_info "偵測所有代理並檢查更新..."
                local detected_agents=($(detect_agents_quiet))

                if [[ ${#detected_agents[@]} -eq 0 ]]; then
                    log_warning "未偵測到任何 AI 代理目錄"
                    return 1
                fi

                log_info "發現 ${#detected_agents[@]} 個代理"
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
                log_info "偵測所有代理並更新..."
                local detected_agents=($(detect_agents_quiet))

                if [[ ${#detected_agents[@]} -eq 0 ]]; then
                    log_warning "未偵測到任何 AI 代理目錄"
                    return 1
                fi

                log_info "發現 ${#detected_agents[@]} 個代理"
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
                log_error "請指定代理: --agent <name>"
                exit 1
            fi
            ;;
        cleanup)
            CLEANUP_APPLY="$cleanup_apply"
            if [[ "$DRY_RUN" == true ]]; then
                CLEANUP_APPLY=false
                log_info "--dry-run 已啟用，cleanup 將以預覽模式執行"
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
            log_warning "備份功能已移除。如需還原，請使用 git checkout 還原檔案。"
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
                            log_warning "未偵測到任何 AI 代理目錄"
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
                            log_error "未找到啟用的代理，請先執行 init"
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
                            log_warning "未偵測到任何 AI 代理目錄"
                            return 1
                        fi

                        log_info "發現 ${#detected_agents[@]} 個代理"
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
                    log_error "未知的模版命令: $subcommand"
                    echo "可用命令: list, select, sync"
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
            log_success "配置已升級到 v$(get_config_version "$config")"
            ;;
        --help|-h|help)
            show_usage
            ;;
        *)
            log_error "未知命令: $command"
            echo ""
            show_usage
            exit 1
            ;;
    esac
}

main "$@"
