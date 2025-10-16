#!/usr/bin/env bash
#
# 安裝 speckit-sync 全局工具
#
# 使用方式：
#   ./install.sh        # 安裝到 ~/bin
#   ./install.sh uninstall  # 解除安裝
#

set -e

# 顏色
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

# 安裝目錄
INSTALL_DIR="${INSTALL_DIR:-$HOME/bin}"

# 工具名稱
TOOL_NAME="speckit-sync"

# 腳本目錄
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

log_info() {
    echo -e "${BLUE}ℹ${NC} $1"
}

log_success() {
    echo -e "${GREEN}✓${NC} $1"
}

log_warning() {
    echo -e "${YELLOW}⚠${NC} $1"
}

install_tool() {
    echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo -e "${BLUE}安裝 Spec-Kit 同步工具${NC}"
    echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo ""

    # 建立安裝目錄
    if [ ! -d "$INSTALL_DIR" ]; then
        log_info "建立目錄: $INSTALL_DIR"
        mkdir -p "$INSTALL_DIR"
    fi

    # 建立符號連結
    log_info "建立符號連結..."

    ln -sf "$SCRIPT_DIR/sync-commands-integrated.sh" "$INSTALL_DIR/$TOOL_NAME"
    chmod +x "$INSTALL_DIR/$TOOL_NAME"

    log_success "已建立: $INSTALL_DIR/$TOOL_NAME -> $SCRIPT_DIR/sync-commands-integrated.sh"

    # 檢查 PATH
    echo ""
    if [[ ":$PATH:" != *":$INSTALL_DIR:"* ]]; then
        log_warning "⚠️  $INSTALL_DIR 不在你的 PATH 中"
        echo ""
        echo "請將以下行加入你的 shell 配置檔案 (~/.bashrc 或 ~/.zshrc):"
        echo ""
        echo "  export PATH=\"\$HOME/bin:\$PATH\""
        echo ""
    else
        log_success "$INSTALL_DIR 已在 PATH 中"
    fi

    echo ""
    log_success "✨ 安裝完成！"
    echo ""
    echo "現在你可以在任何地方使用以下命令："
    echo ""
    echo "  ${GREEN}$TOOL_NAME init${NC}     - 初始化專案"
    echo "  ${GREEN}$TOOL_NAME check${NC}    - 檢查更新"
    echo "  ${GREEN}$TOOL_NAME update${NC}   - 執行同步"
    echo "  ${GREEN}$TOOL_NAME status${NC}   - 顯示狀態"
    echo "  ${GREEN}$TOOL_NAME diff CMD${NC} - 顯示差異"
    echo ""
}

uninstall_tool() {
    echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo -e "${BLUE}解除安裝 Spec-Kit 同步工具${NC}"
    echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo ""

    if [ -L "$INSTALL_DIR/$TOOL_NAME" ]; then
        rm "$INSTALL_DIR/$TOOL_NAME"
        log_success "已移除: $INSTALL_DIR/$TOOL_NAME"
    else
        log_warning "工具未安裝: $INSTALL_DIR/$TOOL_NAME"
    fi

    echo ""
    log_success "解除安裝完成"
}

show_usage() {
    cat << EOF
Spec-Kit 同步工具 - 安裝程式

使用方式:
    $0                # 安裝工具
    $0 uninstall      # 解除安裝

環境變數:
    INSTALL_DIR       安裝目錄 (預設: ~/bin)

安裝後，你可以在任何專案目錄執行:
    speckit-sync init
    speckit-sync check
    speckit-sync update
    speckit-sync status

EOF
}

main() {
    local command="${1:-install}"

    case "$command" in
        install)
            install_tool
            ;;
        uninstall)
            uninstall_tool
            ;;
        help|--help|-h)
            show_usage
            ;;
        *)
            echo "未知命令: $command"
            echo ""
            show_usage
            exit 1
            ;;
    esac
}

main "$@"
