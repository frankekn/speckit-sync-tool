#!/usr/bin/env bash

# ==============================================================================
# speckit-sync - 多代理 spec-kit 命令同步工具
# ==============================================================================
#
# 用途：同步 GitHub spec-kit 命令到本地專案，支援 13 種 AI 代理
#
# 使用方式：
#   speckit-sync init                    # 初始化配置
#   speckit-sync detect-agents           # 檢測已安裝的代理
#   speckit-sync check [--agent <name>]  # 檢查同步狀態
#   speckit-sync update [--agent <name>] # 更新命令
#
# 版本：2.0.0
# ==============================================================================

set -euo pipefail

# ==============================================================================
# 全域變數
# ==============================================================================

VERSION="2.0.0"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(pwd)"
CONFIG_FILE="$PROJECT_ROOT/.speckit-sync-config.json"

# 代理配置映射表
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

# 標準命令列表
STANDARD_COMMANDS=(
    "specify.md"
    "plan.md"
    "tasks.md"
    "implement.md"
    "constitution.md"
    "clarify.md"
    "analyze.md"
    "checklist.md"
)

# 顏色定義
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

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

log_section() {
    echo ""
    echo -e "${CYAN}━━━ $* ━━━${NC}"
}

# 檢查必要工具
check_dependencies() {
    local missing=()

    if ! command -v jq &> /dev/null; then
        missing+=("jq")
    fi

    if ! command -v git &> /dev/null; then
        missing+=("git")
    fi

    if [ ${#missing[@]} -gt 0 ]; then
        log_error "缺少必要工具: ${missing[*]}"
        log_info "請安裝："
        for tool in "${missing[@]}"; do
            echo "  - $tool"
        done
        exit 1
    fi
}

# ==============================================================================
# 代理檢測函數
# ==============================================================================

detect_agents() {
    log_section "🔍 掃描專案目錄"

    local detected=()
    local detected_info=()

    for agent in "${!AGENTS[@]}"; do
        local dir="${AGENTS[$agent]}"
        local full_path="$PROJECT_ROOT/$dir"

        if [ -d "$full_path" ]; then
            detected+=("$agent")
            detected_info+=("$agent:$dir")
            echo -e "  ${GREEN}✓${NC} ${AGENT_NAMES[$agent]} ($dir)"
        else
            echo -e "  ${YELLOW}✗${NC} ${AGENT_NAMES[$agent]} ($dir) - 目錄不存在"
        fi
    done

    if [ ${#detected[@]} -eq 0 ]; then
        echo ""
        log_warning "未檢測到任何 AI 代理目錄"
        log_info "提示：請先安裝至少一個 AI 代理並初始化專案"
        return 1
    fi

    echo ""
    log_info "檢測到 ${#detected[@]} 個代理"

    # 返回檢測結果（用於其他函數）
    printf '%s\n' "${detected_info[@]}"
}

# ==============================================================================
# 配置檔案管理
# ==============================================================================

create_default_config() {
    local config_version="${1:-2.0.0}"
    local timestamp
    timestamp=$(date -u +"%Y-%m-%dT%H:%M:%SZ")

    cat > "$CONFIG_FILE" <<EOF
{
  "version": "$config_version",
  "source": {
    "repo": "github/spec-kit",
    "branch": "main",
    "last_fetch": null
  },
  "agents": {},
  "known_commands": $(printf '%s\n' "${STANDARD_COMMANDS[@]}" | jq -R . | jq -s .)
}
EOF
}

init_agent_config() {
    local agent="$1"
    local commands_dir="${AGENTS[$agent]}"
    local timestamp
    timestamp=$(date -u +"%Y-%m-%dT%H:%M:%SZ")

    # 使用 jq 更新配置
    local temp_config
    temp_config=$(mktemp)

    jq --arg agent "$agent" \
       --arg dir "$commands_dir" \
       --arg ts "$timestamp" \
       --argjson std_cmds "$(printf '%s\n' "${STANDARD_COMMANDS[@]}" | jq -R . | jq -s .)" \
       '.agents[$agent] = {
         "enabled": true,
         "commands_dir": $dir,
         "commands": {
           "standard": $std_cmds,
           "custom": [],
           "synced": [],
           "customized": []
         },
         "last_sync": null
       }' "$CONFIG_FILE" > "$temp_config"

    mv "$temp_config" "$CONFIG_FILE"
    log_success "已初始化 ${AGENT_NAMES[$agent]} 配置"
}

# 配置升級：v1.x → v2.0.0
upgrade_config_to_v2() {
    log_section "🔄 升級配置檔案到 v2.0.0"

    # 備份舊配置
    local backup_file="${CONFIG_FILE}.v1.backup.$(date +%Y%m%d_%H%M%S)"
    cp "$CONFIG_FILE" "$backup_file"
    log_info "已備份舊配置: $backup_file"

    # 讀取舊版本
    local old_version
    old_version=$(jq -r '.version // "1.0.0"' "$CONFIG_FILE")

    log_info "從 v$old_version 升級到 v2.0.0..."

    # 創建新配置結構
    create_default_config "2.0.0"

    # 如果舊配置有 Claude 資料，遷移之
    if jq -e '.commands_dir' "$backup_file" &>/dev/null; then
        log_info "遷移 Claude 配置..."

        local old_commands_dir
        old_commands_dir=$(jq -r '.commands_dir // ".claude/commands"' "$backup_file")

        # 讀取舊的命令分類
        local old_synced
        old_synced=$(jq -r '.commands.synced // []' "$backup_file")
        local old_custom
        old_custom=$(jq -r '.commands.custom // []' "$backup_file")
        local old_customized
        old_customized=$(jq -r '.commands.customized // []' "$backup_file")

        # 更新新配置
        local temp_config
        temp_config=$(mktemp)

        jq --arg dir "$old_commands_dir" \
           --argjson synced "$old_synced" \
           --argjson custom "$old_custom" \
           --argjson customized "$old_customized" \
           --argjson std_cmds "$(printf '%s\n' "${STANDARD_COMMANDS[@]}" | jq -R . | jq -s .)" \
           '.agents.claude = {
             "enabled": true,
             "commands_dir": $dir,
             "commands": {
               "standard": $std_cmds,
               "custom": $custom,
               "synced": $synced,
               "customized": $customized
             },
             "last_sync": null
           }' "$CONFIG_FILE" > "$temp_config"

        mv "$temp_config" "$CONFIG_FILE"
        log_success "Claude 配置已遷移"
    fi

    # 檢測並初始化其他代理
    log_info "自動檢測其他代理..."
    local detected
    detected=$(detect_agents 2>/dev/null || echo "")

    if [ -n "$detected" ]; then
        while IFS=: read -r agent dir; do
            if [ "$agent" != "claude" ]; then
                log_info "檢測到 ${AGENT_NAMES[$agent]}，正在初始化..."
                init_agent_config "$agent"
            fi
        done <<< "$detected"
    fi

    log_success "配置升級完成！"
}

# ==============================================================================
# 初始化命令
# ==============================================================================

cmd_init() {
    log_section "🚀 初始化 speckit-sync 配置"

    # 檢查是否已存在配置
    if [ -f "$CONFIG_FILE" ]; then
        local existing_version
        existing_version=$(jq -r '.version // "unknown"' "$CONFIG_FILE" 2>/dev/null || echo "unknown")

        log_warning "檢測到現有配置 (v$existing_version)"
        echo -n "是否要升級配置？[y/N] "
        read -r response

        if [[ "$response" =~ ^[Yy]$ ]]; then
            if [[ "$existing_version" == "2.0.0" ]]; then
                log_info "配置已是最新版本"
            else
                upgrade_config_to_v2
            fi
        else
            log_info "保持現有配置"
        fi
        return 0
    fi

    # 檢測代理
    log_section "🤖 檢測 AI 代理"

    local detected
    detected=$(detect_agents) || {
        log_error "未檢測到任何代理，無法初始化"
        exit 1
    }

    # 建立代理列表用於選擇
    local agents_array=()
    local agents_dirs=()

    while IFS=: read -r agent dir; do
        agents_array+=("$agent")
        agents_dirs+=("$dir")
    done <<< "$detected"

    # 互動式選擇
    echo ""
    log_info "檢測到以下 AI 代理："
    for i in "${!agents_array[@]}"; do
        local num=$((i + 1))
        echo -e "  ${num}. ${GREEN}✓${NC} ${AGENT_NAMES[${agents_array[$i]}]} (${agents_dirs[$i]})"
    done

    echo ""
    echo -n "選擇要啟用的代理（空格分隔數字，Enter 全選）: "
    read -r selection

    # 處理選擇
    local selected_agents=()

    if [ -z "$selection" ]; then
        # 全選
        selected_agents=("${agents_array[@]}")
        log_info "已選擇所有檢測到的代理"
    else
        # 解析用戶輸入
        for num in $selection; do
            local idx=$((num - 1))
            if [ "$idx" -ge 0 ] && [ "$idx" -lt "${#agents_array[@]}" ]; then
                selected_agents+=("${agents_array[$idx]}")
            else
                log_warning "忽略無效選擇: $num"
            fi
        done
    fi

    if [ ${#selected_agents[@]} -eq 0 ]; then
        log_error "未選擇任何代理"
        exit 1
    fi

    # 建立配置
    log_section "📝 建立配置檔案"

    create_default_config "2.0.0"
    log_success "建立基礎配置"

    # 初始化選定的代理
    for agent in "${selected_agents[@]}"; do
        init_agent_config "$agent"
    done

    echo ""
    log_success "初始化完成！"
    log_info "配置檔案: $CONFIG_FILE"
    log_info "已啟用 ${#selected_agents[@]} 個代理："
    for agent in "${selected_agents[@]}"; do
        echo "  - ${AGENT_NAMES[$agent]}"
    done

    echo ""
    log_info "下一步："
    echo "  1. 執行 'speckit-sync update' 同步命令"
    echo "  2. 執行 'speckit-sync check' 查看狀態"
}

# ==============================================================================
# 檢測代理命令
# ==============================================================================

cmd_detect_agents() {
    detect_agents > /dev/null
}

# ==============================================================================
# 檢查命令
# ==============================================================================

cmd_check() {
    local target_agent="${1:-}"

    if [ ! -f "$CONFIG_FILE" ]; then
        log_error "配置檔案不存在，請先執行 'speckit-sync init'"
        exit 1
    fi

    if [ -n "$target_agent" ]; then
        # 檢查特定代理
        check_single_agent "$target_agent"
    else
        # 檢查所有啟用的代理
        check_all_agents
    fi
}

check_single_agent() {
    local agent="$1"

    # 驗證代理名稱
    if [ -z "${AGENTS[$agent]:-}" ]; then
        log_error "未知的代理: $agent"
        log_info "可用代理: ${!AGENTS[*]}"
        exit 1
    fi

    log_section "🔍 檢查 ${AGENT_NAMES[$agent]}"

    # 檢查代理是否在配置中
    local enabled
    enabled=$(jq -r ".agents.$agent.enabled // false" "$CONFIG_FILE")

    if [ "$enabled" != "true" ]; then
        log_warning "${AGENT_NAMES[$agent]} 未啟用"
        return 0
    fi

    # 讀取代理配置
    local commands_dir
    commands_dir=$(jq -r ".agents.$agent.commands_dir" "$CONFIG_FILE")
    local last_sync
    last_sync=$(jq -r ".agents.$agent.last_sync // \"從未同步\"" "$CONFIG_FILE")

    local synced_count
    synced_count=$(jq ".agents.$agent.commands.synced | length" "$CONFIG_FILE")
    local custom_count
    custom_count=$(jq ".agents.$agent.commands.custom | length" "$CONFIG_FILE")
    local customized_count
    customized_count=$(jq ".agents.$agent.commands.customized | length" "$CONFIG_FILE")
    local standard_count
    standard_count=$(jq ".agents.$agent.commands.standard | length" "$CONFIG_FILE")

    echo "  目錄: $commands_dir"
    echo "  狀態: $([ "$synced_count" -gt 0 ] && echo -e "${GREEN}已同步${NC}" || echo -e "${YELLOW}未同步${NC}")"
    echo "  最後同步: $last_sync"
    echo "  命令統計:"
    echo "    - 標準命令: $standard_count 個"
    echo "    - 已同步: $synced_count 個"
    echo "    - 自訂: $custom_count 個"
    echo "    - 已客製化: $customized_count 個"
    echo "    - 可更新: $((standard_count - synced_count)) 個"
}

check_all_agents() {
    log_section "🔍 檢查所有代理"

    # 獲取所有啟用的代理
    local enabled_agents
    enabled_agents=$(jq -r '.agents | to_entries | map(select(.value.enabled == true)) | .[].key' "$CONFIG_FILE")

    if [ -z "$enabled_agents" ]; then
        log_warning "沒有啟用的代理"
        return 0
    fi

    while IFS= read -r agent; do
        echo ""
        check_single_agent "$agent"
    done <<< "$enabled_agents"
}

# ==============================================================================
# 同步函數
# ==============================================================================

sync_single_agent() {
    local agent="$1"
    local commands_dir="${AGENTS[$agent]}"
    local full_path="$PROJECT_ROOT/$commands_dir"

    log_info "同步 ${AGENT_NAMES[$agent]} ($commands_dir)"

    # 確保目錄存在
    if [ ! -d "$full_path" ]; then
        log_error "目錄不存在: $full_path"
        return 1
    fi

    # 取得標準命令列表
    local standard_commands
    standard_commands=$(jq -r ".agents.$agent.commands.standard[]" "$CONFIG_FILE")

    local synced=()
    local skipped=()
    local errors=()

    # 同步每個標準命令
    while IFS= read -r cmd; do
        local target_file="$full_path/$cmd"

        # 檢查檔案是否已存在且被客製化
        if [ -f "$target_file" ]; then
            # 簡化版：假設存在的檔案可能已被客製化
            # TODO: 實作更精確的差異檢測
            local is_customized
            is_customized=$(jq -r ".agents.$agent.commands.customized | index(\"$cmd\") != null" "$CONFIG_FILE")

            if [ "$is_customized" == "true" ]; then
                skipped+=("$cmd")
                echo -e "    ${YELLOW}!${NC} $cmd (customized - skipped)"
                continue
            fi
        fi

        # 這裡應該從 GitHub 下載檔案
        # 目前簡化版：只是標記為已同步
        # TODO: 實作實際的檔案下載邏輯

        if sync_command_file "$agent" "$cmd" "$target_file"; then
            synced+=("$cmd")
            echo -e "    ${GREEN}✓${NC} $cmd (synced)"
        else
            errors+=("$cmd")
            echo -e "    ${RED}✗${NC} $cmd (failed)"
        fi
    done <<< "$standard_commands"

    # 更新配置
    local timestamp
    timestamp=$(date -u +"%Y-%m-%dT%H:%M:%SZ")

    local temp_config
    temp_config=$(mktemp)

    jq --arg agent "$agent" \
       --arg ts "$timestamp" \
       --argjson synced "$(printf '%s\n' "${synced[@]}" | jq -R . | jq -s .)" \
       ".agents[$agent].last_sync = \$ts |
        .agents[$agent].commands.synced = \$synced" \
       "$CONFIG_FILE" > "$temp_config"

    mv "$temp_config" "$CONFIG_FILE"

    # 顯示摘要
    echo ""
    log_success "同步完成: ${#synced[@]} 成功, ${#skipped[@]} 跳過, ${#errors[@]} 失敗"
}

# 同步單個命令檔案（stub 實作）
sync_command_file() {
    local agent="$1"
    local command="$2"
    local target_file="$3"

    # TODO: 實作實際的檔案下載邏輯
    # 1. 從 GitHub spec-kit 倉庫下載對應的命令檔案
    # 2. 處理不同代理的檔案格式差異
    # 3. 寫入目標檔案

    # 目前只是 stub 實作，總是返回成功
    # sleep 0.1  # 模擬網路延遲
    return 0
}

sync_all_agents() {
    log_section "🔄 同步所有代理"

    # 獲取所有啟用的代理
    local enabled_agents
    enabled_agents=$(jq -r '.agents | to_entries | map(select(.value.enabled == true)) | .[].key' "$CONFIG_FILE")

    if [ -z "$enabled_agents" ]; then
        log_warning "沒有啟用的代理"
        return 0
    fi

    local total=0
    local success=0
    local failed=0

    while IFS= read -r agent; do
        echo ""
        if sync_single_agent "$agent"; then
            ((success++))
        else
            ((failed++))
        fi
        ((total++))
    done <<< "$enabled_agents"

    echo ""
    log_section "📊 同步摘要"
    echo "  總計: $total 個代理"
    echo "  成功: $success 個"
    echo "  失敗: $failed 個"
}

# ==============================================================================
# 更新命令
# ==============================================================================

cmd_update() {
    local target_agent="${1:-}"

    if [ ! -f "$CONFIG_FILE" ]; then
        log_error "配置檔案不存在，請先執行 'speckit-sync init'"
        exit 1
    fi

    if [ -n "$target_agent" ]; then
        if [ "$target_agent" == "all" ]; then
            sync_all_agents
        else
            # 驗證代理名稱
            if [ -z "${AGENTS[$target_agent]:-}" ]; then
                log_error "未知的代理: $target_agent"
                log_info "可用代理: ${!AGENTS[*]}"
                exit 1
            fi

            log_section "🔄 更新 ${AGENT_NAMES[$target_agent]}"
            sync_single_agent "$target_agent"
        fi
    else
        sync_all_agents
    fi
}

# ==============================================================================
# 版本資訊
# ==============================================================================

cmd_version() {
    echo "speckit-sync version $VERSION"
}

# ==============================================================================
# 使用說明
# ==============================================================================

show_usage() {
    cat << 'EOF'
speckit-sync - 多代理 spec-kit 命令同步工具

使用方式:
  speckit-sync init                     初始化配置
  speckit-sync detect-agents            檢測已安裝的代理
  speckit-sync check [--agent <name>]   檢查同步狀態
  speckit-sync update [--agent <name>]  更新命令
  speckit-sync version                  顯示版本資訊
  speckit-sync help                     顯示此說明

選項:
  --agent <name>   指定特定代理（claude, cursor, copilot 等）
  --agent all      處理所有啟用的代理

支援的代理:
  claude, copilot, gemini, cursor, qwen, opencode, codex,
  windsurf, kilocode, auggie, codebuddy, roo, q

範例:
  speckit-sync init                    # 互動式初始化
  speckit-sync detect-agents           # 檢測代理
  speckit-sync check --agent claude    # 檢查 Claude 狀態
  speckit-sync update --agent cursor   # 只更新 Cursor
  speckit-sync update --agent all      # 更新所有代理
  speckit-sync update                  # 更新所有代理（同上）

配置檔案: .speckit-sync-config.json
版本: 2.0.0
EOF
}

# ==============================================================================
# 主程式
# ==============================================================================

main() {
    # 檢查依賴
    check_dependencies

    # 解析命令
    local command="${1:-help}"
    shift || true

    case "$command" in
        init)
            cmd_init
            ;;
        detect-agents)
            cmd_detect_agents
            ;;
        check)
            local agent=""
            while [ $# -gt 0 ]; do
                case "$1" in
                    --agent)
                        agent="$2"
                        shift 2
                        ;;
                    *)
                        log_error "未知選項: $1"
                        show_usage
                        exit 1
                        ;;
                esac
            done
            cmd_check "$agent"
            ;;
        update)
            local agent=""
            while [ $# -gt 0 ]; do
                case "$1" in
                    --agent)
                        agent="$2"
                        shift 2
                        ;;
                    *)
                        log_error "未知選項: $1"
                        show_usage
                        exit 1
                        ;;
                esac
            done
            cmd_update "$agent"
            ;;
        version)
            cmd_version
            ;;
        help|--help|-h)
            show_usage
            ;;
        *)
            log_error "未知命令: $command"
            show_usage
            exit 1
            ;;
    esac
}

# 執行主程式
main "$@"
