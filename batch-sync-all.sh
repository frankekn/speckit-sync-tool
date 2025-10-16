#!/usr/bin/env bash
#
# 批次同步多個專案的 spec-kit 命令
#
# 使用方式：
#   ./batch-sync-all.sh                    # 互動模式
#   ./batch-sync-all.sh --auto             # 自動模式（不詢問）
#   ./batch-sync-all.sh --check-only       # 僅檢查，不更新
#

set -e

# ============================================================================
# 配置
# ============================================================================

# GitHub 目錄（根據你的環境調整）
GITHUB_DIR="${GITHUB_DIR:-$HOME/Documents/GitHub}"

# spec-kit 路徑
SPECKIT_PATH="${SPECKIT_PATH:-$GITHUB_DIR/spec-kit}"

# 同步工具路徑（此腳本所在目錄）
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SYNC_TOOL="$SCRIPT_DIR/sync-commands.sh"

# 要處理的專案列表（可以自訂）
# 如果為空，會自動掃描所有有 .claude/commands 目錄的專案
PROJECTS=()

# 顏色
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
MAGENTA='\033[0;35m'
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
# 專案掃描
# ============================================================================

scan_projects() {
    log_info "掃描 $GITHUB_DIR 中的專案..."

    local found_projects=()

    for dir in "$GITHUB_DIR"/*; do
        [ -d "$dir" ] || continue

        local project_name=$(basename "$dir")

        # 跳過 spec-kit 和同步工具本身
        if [ "$project_name" = "spec-kit" ] || [ "$project_name" = "speckit-sync-tool" ]; then
            continue
        fi

        # 檢查是否有 .claude/commands 目錄
        if [ -d "$dir/.claude/commands" ]; then
            found_projects+=("$project_name")
        fi
    done

    echo "${found_projects[@]}"
}

# ============================================================================
# 主要功能
# ============================================================================

process_project() {
    local project_name="$1"
    local mode="${2:-interactive}"
    local project_dir="$GITHUB_DIR/$project_name"

    log_section "處理專案: $project_name"

    cd "$project_dir"

    # 檢查是否已初始化
    if [ ! -f ".claude/.speckit-sync.json" ]; then
        log_warning "專案未初始化"

        if [ "$mode" = "interactive" ]; then
            echo -n "是否初始化此專案？[y/N] "
            read -r ans
            if [ "${ans:-N}" = "y" ]; then
                $SYNC_TOOL init
            else
                log_info "跳過初始化"
                return 1
            fi
        elif [ "$mode" = "auto" ]; then
            log_info "自動初始化..."
            SPECKIT_PATH="$SPECKIT_PATH" $SYNC_TOOL init
        else
            return 1
        fi
    fi

    # 執行檢查
    echo ""
    SPECKIT_PATH="$SPECKIT_PATH" $SYNC_TOOL check

    # 根據模式決定是否更新
    if [ "$mode" = "check-only" ]; then
        log_info "僅檢查模式，不執行更新"
        return 0
    fi

    echo ""

    if [ "$mode" = "interactive" ]; then
        echo -n "是否更新此專案？[y/N] "
        read -r ans
        if [ "${ans:-N}" = "y" ]; then
            SPECKIT_PATH="$SPECKIT_PATH" $SYNC_TOOL update
            return 0
        else
            log_info "跳過更新"
            return 1
        fi
    elif [ "$mode" = "auto" ]; then
        log_info "自動更新..."
        SPECKIT_PATH="$SPECKIT_PATH" $SYNC_TOOL update
        return 0
    fi
}

batch_sync() {
    local mode="${1:-interactive}"

    log_header "批次同步 Spec-Kit 命令"

    # 如果沒有指定專案，自動掃描
    if [ ${#PROJECTS[@]} -eq 0 ]; then
        PROJECTS=($(scan_projects))
    fi

    if [ ${#PROJECTS[@]} -eq 0 ]; then
        log_error "未找到任何包含 .claude/commands 的專案"
        exit 1
    fi

    log_success "發現 ${#PROJECTS[@]} 個專案"
    echo ""

    # 顯示專案列表
    echo "專案列表："
    local index=1
    for project in "${PROJECTS[@]}"; do
        echo "  $index. $project"
        ((index++))
    done

    echo ""

    # 統計
    local total=${#PROJECTS[@]}
    local success=0
    local skipped=0
    local failed=0

    # 處理每個專案
    for project in "${PROJECTS[@]}"; do
        if process_project "$project" "$mode"; then
            ((success++))
        else
            ((skipped++))
        fi
    done

    # 顯示總結
    log_header "批次同步完成"
    echo ""
    echo "📊 統計："
    echo "  ✅ 成功: $success 個專案"
    echo "  ⏭️  跳過: $skipped 個專案"
    echo "  ❌ 失敗: $failed 個專案"
    echo "  ═══════════════"
    echo "  📦 總計: $total 個專案"
}

# ============================================================================
# 特定專案列表配置範例
# ============================================================================

# 取消註釋並自訂你要同步的專案
# PROJECTS=(
#     "bni-system"
#     "article_writing"
#     "mehmo_edu"
#     "sales-inventory-report-web"
#     "ourjrney_seo"
# )

# ============================================================================
# 主程式
# ============================================================================

show_usage() {
    cat << EOF
${CYAN}批次同步 Spec-Kit 命令工具${NC}

使用方式:
    $0 [options]

選項:
    --auto              自動模式（不詢問，自動更新）
    --check-only        僅檢查，不更新
    --help              顯示此幫助訊息

環境變數:
    GITHUB_DIR          GitHub 專案目錄 (預設: ~/Documents/GitHub)
    SPECKIT_PATH        spec-kit 倉庫路徑 (預設: \$GITHUB_DIR/spec-kit)

範例:
    # 互動模式（逐個詢問）
    $0

    # 自動模式（不詢問，直接更新）
    $0 --auto

    # 僅檢查模式（顯示狀態，不更新）
    $0 --check-only

    # 自訂 GitHub 目錄
    GITHUB_DIR=/custom/path $0

自訂專案列表:
    編輯此腳本，設定 PROJECTS 變數：

    PROJECTS=(
        "project1"
        "project2"
        "project3"
    )

EOF
}

main() {
    local mode="interactive"

    # 解析參數
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
                log_error "未知選項: $1"
                echo ""
                show_usage
                exit 1
                ;;
        esac
    done

    # 檢查同步工具是否存在
    if [ ! -f "$SYNC_TOOL" ]; then
        log_error "找不到同步工具: $SYNC_TOOL"
        exit 1
    fi

    # 檢查 GitHub 目錄是否存在
    if [ ! -d "$GITHUB_DIR" ]; then
        log_error "GitHub 目錄不存在: $GITHUB_DIR"
        log_info "請設定正確的 GITHUB_DIR 環境變數"
        exit 1
    fi

    # 執行批次同步
    batch_sync "$mode"
}

main "$@"
