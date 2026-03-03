#!/usr/bin/env bash
#
# Install speckit-sync as a global tool
#
# Usage:
#   ./install.sh            # install to ~/bin
#   ./install.sh uninstall  # uninstall
#

set -e

# Colors
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

# Install directory
INSTALL_DIR="${INSTALL_DIR:-$HOME/bin}"

# Tool name
TOOL_NAME="speckit-sync"

# Script directory
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
    echo -e "${BLUE}Install Spec-Kit Sync Tool${NC}"
    echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo ""

    # Create install directory
    if [ ! -d "$INSTALL_DIR" ]; then
        log_info "Creating directory: $INSTALL_DIR"
        mkdir -p "$INSTALL_DIR"
    fi

    # Create symlink
    log_info "Creating symlink..."

    ln -sf "$SCRIPT_DIR/sync-commands-integrated.sh" "$INSTALL_DIR/$TOOL_NAME"
    chmod +x "$INSTALL_DIR/$TOOL_NAME"

    log_success "Created: $INSTALL_DIR/$TOOL_NAME -> $SCRIPT_DIR/sync-commands-integrated.sh"

    # Check PATH
    echo ""
    if [[ ":$PATH:" != *":$INSTALL_DIR:"* ]]; then
        log_warning "⚠️  $INSTALL_DIR is not in your PATH"
        echo ""
        echo "Add the following line to your shell profile (~/.bashrc or ~/.zshrc):"
        echo ""
        echo "  export PATH=\"\$HOME/bin:\$PATH\""
        echo ""
    else
        log_success "$INSTALL_DIR is already in PATH"
    fi

    echo ""
    log_success "✨ Installation complete!"
    echo ""
    echo "You can now run these commands from anywhere:"
    echo ""
    echo "  ${GREEN}$TOOL_NAME init${NC}     - initialize project"
    echo "  ${GREEN}$TOOL_NAME check${NC}    - check updates"
    echo "  ${GREEN}$TOOL_NAME update${NC}   - run sync"
    echo "  ${GREEN}$TOOL_NAME status${NC}   - show status"
    echo "  ${GREEN}$TOOL_NAME diff CMD${NC} - show differences"
    echo ""
}

uninstall_tool() {
    echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo -e "${BLUE}Uninstall Spec-Kit Sync Tool${NC}"
    echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo ""

    if [ -L "$INSTALL_DIR/$TOOL_NAME" ]; then
        rm "$INSTALL_DIR/$TOOL_NAME"
        log_success "Removed: $INSTALL_DIR/$TOOL_NAME"
    else
        log_warning "Tool is not installed: $INSTALL_DIR/$TOOL_NAME"
    fi

    echo ""
    log_success "Uninstall complete"
}

show_usage() {
    cat << EOF
Spec-Kit Sync Tool - Installer

Usage:
    $0                # install tool
    $0 uninstall      # uninstall

Environment Variables:
    INSTALL_DIR       install directory (default: ~/bin)

After installation, you can run in any project directory:
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
            echo "Unknown command: $command"
            echo ""
            show_usage
            exit 1
            ;;
    esac
}

main "$@"
