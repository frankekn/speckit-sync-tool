#!/usr/bin/env bash
#
# Spec-Kit 命令同步工具
#
# 用於同步 GitHub spec-kit 命令到你的專案
#
# 使用方式：
#   ./sync-commands.sh init      - 初始化同步配置
#   ./sync-commands.sh check     - 檢查更新
#   ./sync-commands.sh update    - 執行同步
#   ./sync-commands.sh diff CMD  - 顯示差異
#   ./sync-commands.sh status    - 顯示狀態
#

set -e

# ============================================================================
# 配置
# ============================================================================

# 預設 spec-kit 路徑
SPECKIT_PATH="${SPECKIT_PATH:-$HOME/Documents/GitHub/spec-kit}"
SPECKIT_COMMANDS="$SPECKIT_PATH/templates/commands"

# 當前專案的命令目錄
COMMANDS_DIR="${COMMANDS_DIR:-.claude/commands}"
CONFIG_FILE=".claude/.speckit-sync.json"

# 標準命令清單
STANDARD_COMMANDS=(
    "analyze.md"
    "checklist.md"
    "clarify.md"
    "constitution.md"
    "implement.md"
    "plan.md"
    "specify.md"
    "tasks.md"
)

# 顏色
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

# ============================================================================
# 輔助函數
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
    echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo -e "${CYAN}$1${NC}"
    echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
}

validate_speckit_path() {
    if [ ! -d "$SPECKIT_COMMANDS" ]; then
        log_error "spec-kit 路徑無效: $SPECKIT_PATH"
        log_info "請設定環境變數: export SPECKIT_PATH=/path/to/spec-kit"
        exit 1
    fi
}

get_speckit_version() {
    if [ -f "$SPECKIT_PATH/pyproject.toml" ]; then
        grep '^version' "$SPECKIT_PATH/pyproject.toml" | cut -d'"' -f2
    else
        echo "unknown"
    fi
}

# ============================================================================
# 主要功能
# ============================================================================

cmd_init() {
    log_header "初始化 Spec-Kit 同步配置"

    # 檢查是否已經初始化
    if [ -f "$CONFIG_FILE" ]; then
        log_warning "配置檔案已存在: $CONFIG_FILE"
        echo -n "是否覆蓋？[y/N] "
        read -r ans
        if [ "${ans:-N}" != "y" ]; then
            log_info "取消初始化"
            exit 0
        fi
    fi

    validate_speckit_path

    # 建立配置目錄
    mkdir -p "$(dirname "$CONFIG_FILE")"
    mkdir -p "$COMMANDS_DIR"

    local project_name=$(basename "$(pwd)")
    local timestamp=$(date -u +"%Y-%m-%dT%H:%M:%SZ")
    local speckit_version=$(get_speckit_version)

    # 掃描現有命令
    log_info "掃描現有命令..."

    local standard_json=""
    local custom_json=""

    for cmd in "${STANDARD_COMMANDS[@]}"; do
        local status="missing"
        if [ -f "$COMMANDS_DIR/$cmd" ]; then
            if diff -q "$COMMANDS_DIR/$cmd" "$SPECKIT_COMMANDS/$cmd" >/dev/null 2>&1; then
                status="synced"
            else
                status="customized"
            fi
        fi

        standard_json="${standard_json}    {\"name\": \"$cmd\", \"status\": \"$status\", \"version\": \"$speckit_version\", \"last_sync\": \"$timestamp\"},\n"
    done

    # 移除最後的逗號
    standard_json=$(echo -e "$standard_json" | sed '$ s/,$//')

    # 建立配置檔案
    cat > "$CONFIG_FILE" << EOF
{
  "version": "1.0.0",
  "source": {
    "type": "local",
    "path": "$SPECKIT_PATH",
    "version": "$speckit_version"
  },
  "strategy": {
    "mode": "semi-auto",
    "on_conflict": "ask",
    "auto_backup": true,
    "backup_retention": 5
  },
  "commands": {
    "standard": [
$(echo -e "$standard_json")
    ],
    "custom": [],
    "ignored": []
  },
  "metadata": {
    "project_name": "$project_name",
    "initialized": "$timestamp",
    "last_check": "$timestamp",
    "total_syncs": 0
  }
}
EOF

    log_success "配置檔案已建立: $CONFIG_FILE"
    echo ""
    log_info "下一步: 執行 '$0 check' 檢查更新"
}

cmd_check() {
    log_header "檢查 Spec-Kit 更新"
    validate_speckit_path

    echo ""
    echo "📁 Spec-Kit 路徑: $SPECKIT_PATH"
    echo "📁 命令目錄: $COMMANDS_DIR"
    echo "🔖 Spec-Kit 版本: $(get_speckit_version)"
    echo ""

    local need_update=0
    local total=${#STANDARD_COMMANDS[@]}
    local missing=0
    local outdated=0
    local synced=0

    for cmd in "${STANDARD_COMMANDS[@]}"; do
        local speckit_file="$SPECKIT_COMMANDS/$cmd"
        local local_file="$COMMANDS_DIR/$cmd"

        if [ ! -f "$local_file" ]; then
            log_warning "⊕ $cmd - 本地不存在（新命令）"
            ((need_update++))
            ((missing++))
        elif ! diff -q "$local_file" "$speckit_file" >/dev/null 2>&1; then
            log_warning "↻ $cmd - 有更新可用"
            ((need_update++))
            ((outdated++))
        else
            log_success "$cmd - 已是最新"
            ((synced++))
        fi
    done

    echo ""
    echo "📊 統計："
    echo "  ✅ 已同步: $synced"
    echo "  ⊕  缺少: $missing"
    echo "  ↻  過時: $outdated"
    echo "  ═══════════"
    echo "  📦 總計: $total"
    echo ""

    if [ $need_update -eq 0 ]; then
        log_success "所有命令都是最新版本 🎉"
    else
        log_warning "發現 $need_update 個命令需要更新"
        log_info "執行 '$0 update' 來更新"
    fi

    # 更新檢查時間
    update_config_field "last_check" "$(date -u +"%Y-%m-%dT%H:%M:%SZ")"
}

cmd_update() {
    log_header "同步 Spec-Kit 命令"
    validate_speckit_path

    # 建立備份
    local timestamp=$(date +%Y%m%d_%H%M%S)
    local backup_dir="$COMMANDS_DIR/.backup/$timestamp"
    mkdir -p "$backup_dir"

    log_info "📦 建立備份: $backup_dir"
    if ls "$COMMANDS_DIR"/*.md 1> /dev/null 2>&1; then
        cp "$COMMANDS_DIR"/*.md "$backup_dir/" 2>/dev/null || true
    fi

    echo ""

    local updated=0
    local new_files=0
    local skipped=0

    for cmd in "${STANDARD_COMMANDS[@]}"; do
        local speckit_file="$SPECKIT_COMMANDS/$cmd"
        local local_file="$COMMANDS_DIR/$cmd"

        if [ ! -f "$local_file" ]; then
            # 新檔案，直接複製
            cp "$speckit_file" "$local_file"
            log_success "⊕ $cmd - 新增"
            ((new_files++))
        elif diff -q "$local_file" "$speckit_file" >/dev/null 2>&1; then
            # 已是最新
            echo -e "  ${GREEN}✓${NC} $cmd - 已是最新，跳過"
            ((skipped++))
        else
            # 有差異，更新
            cp "$speckit_file" "$local_file"
            log_success "↻ $cmd - 已更新"
            ((updated++))
        fi
    done

    echo ""
    log_header "同步完成"
    echo "  ⊕  新增: $new_files 個"
    echo "  ↻  更新: $updated 個"
    echo "  ✓  跳過: $skipped 個"
    echo "  📦 備份: $backup_dir"

    # 更新配置檔案
    local new_syncs=$(($(get_config_field "total_syncs") + 1))
    update_config_field "last_check" "$(date -u +"%Y-%m-%dT%H:%M:%SZ")"
    update_config_field "total_syncs" "$new_syncs"
    update_config_field "version" "$(get_speckit_version)"
}

cmd_diff() {
    local command_name="${1:-}"

    if [ -z "$command_name" ]; then
        log_error "請指定要比較的命令名稱"
        echo ""
        echo "使用方式: $0 diff <command-name>"
        echo "範例: $0 diff implement.md"
        exit 1
    fi

    validate_speckit_path

    local speckit_file="$SPECKIT_COMMANDS/$command_name"
    local local_file="$COMMANDS_DIR/$command_name"

    if [ ! -f "$local_file" ]; then
        log_error "本地檔案不存在: $local_file"
        exit 1
    fi

    if [ ! -f "$speckit_file" ]; then
        log_error "spec-kit 檔案不存在: $speckit_file"
        exit 1
    fi

    log_header "比較: $command_name"
    echo "📄 本地: $local_file"
    echo "📄 spec-kit: $speckit_file"
    echo ""

    if diff -q "$local_file" "$speckit_file" >/dev/null 2>&1; then
        log_success "檔案相同，無差異 ✨"
    else
        diff -u "$local_file" "$speckit_file" | head -50 || true
        echo ""
        log_info "（顯示前 50 行差異）"
    fi
}

cmd_status() {
    log_header "同步狀態"
    echo ""
    echo "📁 Spec-Kit 路徑: $SPECKIT_PATH"
    echo "📁 命令目錄: $COMMANDS_DIR"
    echo ""

    if [ -f "$CONFIG_FILE" ]; then
        echo "⚙️  配置檔案: $CONFIG_FILE"
        echo ""
        echo "專案: $(get_config_field "project_name")"
        echo "Spec-Kit 版本: $(get_config_field "version")"
        echo "初始化時間: $(get_config_field "initialized")"
        echo "最後檢查: $(get_config_field "last_check")"
        echo "同步次數: $(get_config_field "total_syncs")"
    else
        log_warning "未找到配置檔案: $CONFIG_FILE"
        log_info "執行 '$0 init' 初始化"
    fi

    echo ""
    echo "📋 標準命令 (${#STANDARD_COMMANDS[@]} 個):"
    for cmd in "${STANDARD_COMMANDS[@]}"; do
        if [ -f "$COMMANDS_DIR/$cmd" ]; then
            log_success "$cmd"
        else
            log_error "$cmd (不存在)"
        fi
    done

    echo ""
    echo "🎨 自訂命令:"
    local has_custom=0
    for file in "$COMMANDS_DIR"/*.md 2>/dev/null; do
        [ -f "$file" ] || continue
        local basename=$(basename "$file")
        local is_standard=0

        for std in "${STANDARD_COMMANDS[@]}"; do
            if [ "$basename" = "$std" ]; then
                is_standard=1
                break
            fi
        done

        if [ $is_standard -eq 0 ]; then
            echo -e "  ${CYAN}⊙${NC} $basename"
            has_custom=1
        fi
    done

    if [ $has_custom -eq 0 ]; then
        echo "  (無)"
    fi
}

# ============================================================================
# 配置檔案輔助函數
# ============================================================================

get_config_field() {
    local field="$1"
    if [ -f "$CONFIG_FILE" ]; then
        grep "\"$field\"" "$CONFIG_FILE" | head -1 | sed 's/.*: "\?\([^",]*\)"\?,\?/\1/'
    else
        echo ""
    fi
}

update_config_field() {
    local field="$1"
    local value="$2"

    if [ -f "$CONFIG_FILE" ]; then
        if [[ "$OSTYPE" == "darwin"* ]]; then
            sed -i '' "s/\"$field\": \"[^\"]*\"/\"$field\": \"$value\"/" "$CONFIG_FILE"
        else
            sed -i "s/\"$field\": \"[^\"]*\"/\"$field\": \"$value\"/" "$CONFIG_FILE"
        fi
    fi
}

# ============================================================================
# 主程式
# ============================================================================

show_usage() {
    cat << EOF
${CYAN}Spec-Kit 命令同步工具${NC}

使用方式:
    $0 <command> [arguments]

命令:
    ${GREEN}init${NC}               初始化同步配置
    ${GREEN}check${NC}              檢查哪些命令需要更新
    ${GREEN}update${NC}             執行同步更新
    ${GREEN}diff${NC} <command>     顯示指定命令的差異
    ${GREEN}status${NC}             顯示同步狀態
    ${GREEN}help${NC}               顯示此幫助訊息

環境變數:
    SPECKIT_PATH       spec-kit 倉庫的路徑 (預設: ~/Documents/GitHub/spec-kit)
    COMMANDS_DIR       命令目錄的路徑 (預設: .claude/commands)

範例:
    # 初始化專案
    $0 init

    # 檢查更新
    $0 check

    # 執行同步
    $0 update

    # 查看特定命令的差異
    $0 diff implement.md

    # 使用自訂 spec-kit 路徑
    SPECKIT_PATH=/custom/path/spec-kit $0 check

EOF
}

main() {
    local command="${1:-help}"

    case "$command" in
        init)
            cmd_init
            ;;
        check)
            cmd_check
            ;;
        update)
            cmd_update
            ;;
        diff)
            cmd_diff "${2:-}"
            ;;
        status)
            cmd_status
            ;;
        help|--help|-h)
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
