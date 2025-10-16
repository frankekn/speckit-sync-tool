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
#
# 版本：2.1.0
# ==============================================================================

set -euo pipefail

# ==============================================================================
# 全域變數
# ==============================================================================

VERSION="2.1.0"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(pwd)"
CONFIG_FILE="$PROJECT_ROOT/.speckit-sync.json"

# spec-kit 路徑（預設為同層級目錄）
SPECKIT_PATH="${SPECKIT_PATH:-$(dirname "$SCRIPT_DIR")/spec-kit}"
SPECKIT_COMMANDS="$SPECKIT_PATH/templates/commands"
SPECKIT_TEMPLATES="$SPECKIT_PATH/templates"

# AI 代理配置映射表（13 種代理）
declare -A AGENTS=(
    ["claude"]=".claude/commands"
    ["copilot"]=".github/prompts"
    ["gemini"]=".gemini/commands"
    ["cursor"]=".cursor/commands"
    ["qwen"]=".qwen/commands"
    ["opencode"]=".opencode/commands"
    ["codex"]=".codex/commands"
    ["windsurf"]=".windsurf/workflows"
    ["kilocode"]=".kilocode/commands"
    ["auggie"]=".augment/commands"
    ["codebuddy"]=".codebuddy/commands"
    ["roo"]=".roo/commands"
    ["q"]=".amazonq/commands"
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
)

# 顏色定義
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
GRAY='\033[0;90m'
BOLD='\033[1m'
NC='\033[0m'

# ==============================================================================
# 工具函數
# ==============================================================================

log_info() {
    echo -e "${BLUE}ℹ${NC} $*"
}

log_success() {
    echo -e "${GREEN}✓${NC} $*"
}

log_error() {
    echo -e "${RED}✗${NC} $*" >&2
}

log_warning() {
    echo -e "${YELLOW}⚠${NC} $*"
}

log_header() {
    echo ""
    echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo -e "${CYAN}${BOLD}$1${NC}"
    echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
}

log_section() {
    echo ""
    echo -e "${BLUE}${BOLD}▶ $1${NC}"
}

# ==============================================================================
# spec-kit 自動更新
# ==============================================================================

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

    # 獲取當前分支
    local current_branch=$(git rev-parse --abbrev-ref HEAD)

    # fetch 最新版本
    git fetch origin --quiet 2>/dev/null || {
        log_warning "無法連接到遠端倉庫，使用本地版本"
        cd - >/dev/null
        return 0
    }

    # 檢查是否有更新
    local local_commit=$(git rev-parse HEAD)
    local remote_commit=$(git rev-parse origin/$current_branch 2>/dev/null || echo "$local_commit")

    if [[ "$local_commit" != "$remote_commit" ]]; then
        log_info "發現 spec-kit 新版本，正在更新..."

        local old_version=$(grep '^version' "$SPECKIT_PATH/pyproject.toml" | cut -d'"' -f2 2>/dev/null || echo "unknown")

        if git pull origin "$current_branch" --quiet; then
            local new_version=$(grep '^version' "$SPECKIT_PATH/pyproject.toml" | cut -d'"' -f2 2>/dev/null || echo "unknown")
            log_success "spec-kit 已更新: $old_version → $new_version"
        else
            log_error "spec-kit 更新失敗"
            cd - >/dev/null
            return 1
        fi
    else
        local version=$(grep '^version' "$SPECKIT_PATH/pyproject.toml" | cut -d'"' -f2 2>/dev/null || echo "unknown")
        log_success "spec-kit 已是最新版本 ($version)"
    fi

    cd - >/dev/null
}

# ==============================================================================
# 動態命令掃描 (Phase 1)
# ==============================================================================

get_standard_commands_from_speckit() {
    local commands=()

    if [[ ! -d "$SPECKIT_COMMANDS" ]]; then
        log_error "spec-kit 命令目錄不存在: $SPECKIT_COMMANDS"
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

    local commands_dir="${AGENTS[$agent]}"

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
# 代理偵測與管理 (Phase 2)
# ==============================================================================

# 靜默版本：只返回代理名稱陣列（用於程式化調用）
detect_agents_quiet() {
    local detected=()

    for agent in "${!AGENTS[@]}"; do
        local dir="${AGENTS[$agent]}"
        if [[ -d "$PROJECT_ROOT/$dir" ]]; then
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
        local dir="${AGENTS[$agent]}"
        if [[ -d "$PROJECT_ROOT/$dir" ]]; then
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
            local dir="${AGENTS[$agent]}"

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
        echo "{}"
        return
    fi
    cat "$CONFIG_FILE"
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

templates_sync() {
    log_header "同步模版"

    local config=$(load_config)
    local sync_dir=$(echo "$config" | jq -r '.templates.sync_dir // ".claude/templates"')
    local selected=$(echo "$config" | jq -r '.templates.selected[]' 2>/dev/null)

    # 確保目標目錄存在
    mkdir -p "$sync_dir"

    local synced=0
    while IFS= read -r tpl; do
        [[ -z "$tpl" ]] && continue

        local src="$SPECKIT_TEMPLATES/$tpl"
        local dest="$sync_dir/$tpl"

        if [[ ! -f "$src" ]]; then
            log_warning "$tpl - 來源檔案不存在"
            continue
        fi

        cp "$src" "$dest"
        log_success "$tpl - 已同步"
        ((synced++))
    done <<< "$selected"

    echo ""
    log_success "共同步 $synced 個模版到 $sync_dir"

    # 更新最後同步時間
    config=$(echo "$config" | jq ".templates.last_sync = \"$(date -u +%Y-%m-%dT%H:%M:%SZ)\"")
    save_config "$config"
}

templates_select() {
    log_header "選擇要同步的模版"

    local templates=($(get_available_templates))

    if [[ ${#templates[@]} -eq 0 ]]; then
        log_error "未找到任何模版"
        return 1
    fi

    local config=$(load_config)
    local selected=()

    echo ""
    echo "請選擇要同步的模版（Enter 選擇，空白行結束）："
    echo ""

    for i in "${!templates[@]}"; do
        local tpl="${templates[$i]}"
        printf "[%2d] %s\n" "$((i+1))" "$tpl"
    done

    echo ""
    while true; do
        read -p "選擇 (1-${#templates[@]}, Enter 結束): " -r
        [[ -z "$REPLY" ]] && break

        if [[ "$REPLY" =~ ^[0-9]+$ ]] && [[ "$REPLY" -ge 1 ]] && [[ "$REPLY" -le "${#templates[@]}" ]]; then
            local idx=$((REPLY - 1))
            selected+=("${templates[$idx]}")
            log_success "已添加: ${templates[$idx]}"
        else
            log_warning "無效選擇: $REPLY"
        fi
    done

    if [[ ${#selected[@]} -eq 0 ]]; then
        log_warning "未選擇任何模版"
        return
    fi

    # 更新配置
    local selected_json=$(printf '%s\n' "${selected[@]}" | jq -R . | jq -s .)
    config=$(echo "$config" | jq --argjson sel "$selected_json" '.templates.selected = $sel | .templates.enabled = true')
    save_config "$config"

    log_success "已選擇 ${#selected[@]} 個模版"
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

    local commands_dir="${AGENTS[$agent]}"

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

    local commands_dir="${AGENTS[$agent]}"

    local source="$SPECKIT_COMMANDS/$command"
    local target="$PROJECT_ROOT/$commands_dir/$command"

    if [[ ! -f "$source" ]]; then
        log_error "$command - 來源檔案不存在"
        return 1
    fi

    mkdir -p "$(dirname "$target")"
    cp "$source" "$target"
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
    update_speckit_repo

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
    local commands_dir="${AGENTS[$agent]}"

    # 建立備份
    local backup_dir="$PROJECT_ROOT/$commands_dir/.backup/$(date +%Y%m%d_%H%M%S)"
    mkdir -p "$backup_dir"

    if [[ -d "$PROJECT_ROOT/$commands_dir" ]]; then
        cp -r "$PROJECT_ROOT/$commands_dir"/*.md "$backup_dir/" 2>/dev/null || true
        log_info "📦 建立備份: $backup_dir"
    fi

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
    echo "  📦 備份: $backup_dir"
}

# ==============================================================================
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
    "on_conflict": "ask",
    "auto_backup": true,
    "backup_retention": 5
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

        local agent_dir="${AGENTS[$agent]}"
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
    init                         初始化配置
    detect-agents                偵測可用的 AI 代理
    check [options]              檢查更新狀態
    update [options]             執行命令同步
    scan [--agent <name>]        掃描並添加新命令

    templates list               列出可用模版
    templates select             選擇要同步的模版
    templates sync               同步已選擇的模版

    status                       顯示當前配置狀態
    upgrade                      升級配置檔案版本

選項:
    --agent <name>               指定要操作的代理
    --all-agents                 自動偵測並處理所有代理（忽略配置檔啟用狀態）
    --help                       顯示此幫助訊息

環境變數:
    SPECKIT_PATH                 spec-kit 倉庫路徑 (預設: ../spec-kit)

範例:
    # 初始化配置
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
    log_section "模版同步"

    local tpl_enabled=$(echo "$config" | jq -r '.templates.enabled')
    local tpl_count=$(echo "$config" | jq -r '.templates.selected | length')
    local tpl_sync=$(echo "$config" | jq -r '.templates.last_sync // "從未同步"')

    echo "  狀態: $([ "$tpl_enabled" == "true" ] && echo "已啟用" || echo "未啟用")"
    echo "  已選擇: $tpl_count 個模版"
    echo "  最後同步: $tpl_sync"
}

main() {
    local command="${1:-}"
    local subcommand="${2:-}"
    local agent=""
    local all_agents=false

    # 解析參數
    shift || true
    while [[ $# -gt 0 ]]; do
        case "$1" in
            --agent)
                agent="$2"
                shift 2
                ;;
            --all-agents)
                all_agents=true
                shift
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

    case "$command" in
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
        templates)
            case "$subcommand" in
                list)
                    templates_list
                    ;;
                select)
                    templates_select
                    ;;
                sync)
                    templates_sync
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
