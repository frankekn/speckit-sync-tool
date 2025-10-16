#!/usr/bin/env bash
#
# SpecKit Sync Tool - 模版同步工具
# 版本: 1.0.0
# 用途: 同步 spec-kit 模版檔案到專案目錄
#

set -euo pipefail

# ============================================================================
# 常數與配置
# ============================================================================

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SPECKIT_PATH="${SCRIPT_DIR}"
CONFIG_FILE=".speckit-sync.json"
DEFAULT_SYNC_DIR=".claude/templates"
VERSION="1.0.0"

# 顏色定義
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
GRAY='\033[0;90m'
BOLD='\033[1m'
NC='\033[0m' # No Color

# 模版描述對應表
declare -A TEMPLATE_DESC=(
    ["spec-template.md"]="功能規格模版"
    ["plan-template.md"]="實作計劃模版"
    ["tasks-template.md"]="任務清單模版"
    ["checklist-template.md"]="檢查清單模版"
    ["agent-file-template.md"]="AI 代理上下文"
    ["vscode-settings.json"]="VS Code 設定"
)

# ============================================================================
# 工具函數
# ============================================================================

print_header() {
    echo -e "${CYAN}${BOLD}"
    echo "╔══════════════════════════════════════════════════════════╗"
    echo "║          SpecKit Template Sync Tool v${VERSION}          ║"
    echo "╚══════════════════════════════════════════════════════════╝"
    echo -e "${NC}"
}

print_section() {
    echo -e "\n${BLUE}${BOLD}▶ $1${NC}"
}

print_success() {
    echo -e "${GREEN}✓${NC} $1"
}

print_error() {
    echo -e "${RED}✗${NC} $1" >&2
}

print_warning() {
    echo -e "${YELLOW}⚠${NC} $1"
}

print_info() {
    echo -e "${CYAN}ℹ${NC} $1"
}

print_dim() {
    echo -e "${GRAY}$1${NC}"
}

# ============================================================================
# 配置檔案管理
# ============================================================================

load_config() {
    if [[ -f "$CONFIG_FILE" ]]; then
        cat "$CONFIG_FILE"
    else
        echo '{
  "version": "1.0.0",
  "templates": {
    "enabled": false,
    "sync_dir": ".claude/templates",
    "selected": [],
    "last_sync": null
  }
}'
    fi
}

save_config() {
    local config="$1"
    echo "$config" | jq '.' > "$CONFIG_FILE"
    print_success "配置已儲存到 $CONFIG_FILE"
}

update_config_field() {
    local field="$1"
    local value="$2"
    local config
    config=$(load_config)
    config=$(echo "$config" | jq --arg f "$field" --argjson v "$value" '.templates[$f] = $v')
    save_config "$config"
}

# ============================================================================
# 模版掃描
# ============================================================================

get_templates_from_speckit() {
    local templates_dir="$SPECKIT_PATH/templates"

    if [[ ! -d "$templates_dir" ]]; then
        print_error "找不到模版目錄: $templates_dir"
        return 1
    fi

    # 列出所有模版檔案（排除 commands/ 子目錄）
    find "$templates_dir" -maxdepth 1 -type f \
        \( -name "*.md" -o -name "*.json" \) \
        -exec basename {} \; | sort
}

get_template_info() {
    local template_name="$1"
    local template_path="$SPECKIT_PATH/templates/$template_name"

    if [[ ! -f "$template_path" ]]; then
        echo "檔案不存在"
        return 1
    fi

    local size
    size=$(du -h "$template_path" | cut -f1)
    local desc="${TEMPLATE_DESC[$template_name]:-未知模版}"

    echo "$desc (${size})"
}

# ============================================================================
# 模版同步核心功能
# ============================================================================

sync_template() {
    local template_name="$1"
    local target_dir="$2"
    local dry_run="${3:-false}"
    local backup="${4:-true}"

    local source_path="$SPECKIT_PATH/templates/$template_name"
    local target_path="$target_dir/$template_name"

    if [[ ! -f "$source_path" ]]; then
        print_error "來源模版不存在: $source_path"
        return 1
    fi

    # 建立目標目錄
    if [[ "$dry_run" == "false" ]]; then
        mkdir -p "$target_dir"
    fi

    # 檢查目標檔案是否存在
    if [[ -f "$target_path" ]]; then
        # 比較檔案是否相同
        if cmp -s "$source_path" "$target_path"; then
            print_dim "  ⊙ $template_name (已是最新)"
            return 0
        fi

        # 需要更新
        if [[ "$dry_run" == "true" ]]; then
            print_warning "  ⟳ $template_name (將被更新)"
            return 0
        fi

        # 備份舊檔案
        if [[ "$backup" == "true" ]]; then
            local backup_path="${target_path}.backup.$(date +%Y%m%d_%H%M%S)"
            cp "$target_path" "$backup_path"
            print_dim "    └─ 備份: $(basename "$backup_path")"
        fi

        cp "$source_path" "$target_path"
        print_success "  ⟳ $template_name (已更新)"
    else
        # 新檔案
        if [[ "$dry_run" == "true" ]]; then
            print_info "  + $template_name (將被建立)"
            return 0
        fi

        cp "$source_path" "$target_path"
        print_success "  + $template_name (已建立)"
    fi
}

sync_templates_batch() {
    local templates=("$@")
    local target_dir dry_run backup

    # 從配置讀取設定
    local config
    config=$(load_config)
    target_dir=$(echo "$config" | jq -r '.templates.sync_dir // ".claude/templates"')

    dry_run="${DRY_RUN:-false}"
    backup="${BACKUP:-true}"

    print_section "同步模版到: $target_dir"

    if [[ "$dry_run" == "true" ]]; then
        print_warning "預覽模式（不會實際寫入檔案）"
        echo ""
    fi

    local success_count=0
    local skip_count=0
    local error_count=0

    for template in "${templates[@]}"; do
        if sync_template "$template" "$target_dir" "$dry_run" "$backup"; then
            ((success_count++)) || true
        else
            ((error_count++)) || true
        fi
    done

    echo ""
    print_section "同步完成"
    echo "  成功: $success_count"
    [[ $skip_count -gt 0 ]] && echo "  跳過: $skip_count" || true
    [[ $error_count -gt 0 ]] && echo "  失敗: $error_count" || true

    return 0
}

# ============================================================================
# 互動式選擇
# ============================================================================

interactive_select_templates() {
    local -a available_templates
    mapfile -t available_templates < <(get_templates_from_speckit)

    if [[ ${#available_templates[@]} -eq 0 ]]; then
        print_error "找不到任何模版檔案"
        return 1
    fi

    print_section "可用模版 (${#available_templates[@]} 個)"
    echo ""

    local i=1
    for template in "${available_templates[@]}"; do
        local info
        info=$(get_template_info "$template")
        printf "  ${GRAY}[ ]${NC} ${BOLD}%2d.${NC} %-30s - %s\n" "$i" "$template" "$info"
        ((i++))
    done

    echo ""
    echo -e "${YELLOW}選擇要同步的模版:${NC}"
    echo "  • 輸入數字（空格分隔）: 1 3 5"
    echo "  • 輸入範圍: 1-3"
    echo "  • 全選: a 或 all"
    echo "  • 取消: q 或 quit"
    echo ""

    read -r -p "請選擇 > " selection

    if [[ "$selection" =~ ^(q|quit)$ ]]; then
        print_info "已取消"
        return 1
    fi

    local -a selected_templates=()

    if [[ "$selection" =~ ^(a|all)$ ]]; then
        selected_templates=("${available_templates[@]}")
    else
        # 解析選擇
        for item in $selection; do
            if [[ "$item" =~ ^([0-9]+)-([0-9]+)$ ]]; then
                # 範圍選擇
                local start="${BASH_REMATCH[1]}"
                local end="${BASH_REMATCH[2]}"
                for ((idx=start; idx<=end; idx++)); do
                    if [[ $idx -ge 1 && $idx -le ${#available_templates[@]} ]]; then
                        selected_templates+=("${available_templates[$((idx-1))]}")
                    fi
                done
            elif [[ "$item" =~ ^[0-9]+$ ]]; then
                # 單一選擇
                if [[ $item -ge 1 && $item -le ${#available_templates[@]} ]]; then
                    selected_templates+=("${available_templates[$((item-1))]}")
                fi
            fi
        done
    fi

    if [[ ${#selected_templates[@]} -eq 0 ]]; then
        print_error "未選擇任何模版"
        return 1
    fi

    # 輸出選擇的模版（供後續使用）
    printf "%s\n" "${selected_templates[@]}"
}

interactive_select_directory() {
    local default_dir="${1:-.claude/templates}"

    echo ""
    echo -e "${YELLOW}同步到哪個目錄？${NC}"
    echo -e "${GRAY}[預設: $default_dir]${NC}"

    read -r -p "> " target_dir

    if [[ -z "$target_dir" ]]; then
        target_dir="$default_dir"
    fi

    echo "$target_dir"
}

# ============================================================================
# 檢查更新
# ============================================================================

check_template_updates() {
    local target_dir="${1:-.claude/templates}"

    if [[ ! -d "$target_dir" ]]; then
        print_warning "目標目錄不存在: $target_dir"
        return 0
    fi

    print_section "檢查模版更新"

    local -a available_templates
    mapfile -t available_templates < <(get_templates_from_speckit)

    local -a outdated=()
    local -a missing=()
    local -a uptodate=()

    for template in "${available_templates[@]}"; do
        local source_path="$SPECKIT_PATH/templates/$template"
        local target_path="$target_dir/$template"

        if [[ ! -f "$target_path" ]]; then
            missing+=("$template")
        elif ! cmp -s "$source_path" "$target_path"; then
            outdated+=("$template")
        else
            uptodate+=("$template")
        fi
    done

    echo ""

    if [[ ${#outdated[@]} -gt 0 ]]; then
        echo -e "${YELLOW}需要更新 (${#outdated[@]}):${NC}"
        for template in "${outdated[@]}"; do
            echo "  ⟳ $template"
        done
        echo ""
    fi

    if [[ ${#missing[@]} -gt 0 ]]; then
        echo -e "${CYAN}尚未同步 (${#missing[@]}):${NC}"
        for template in "${missing[@]}"; do
            echo "  + $template"
        done
        echo ""
    fi

    if [[ ${#uptodate[@]} -gt 0 ]]; then
        echo -e "${GREEN}已是最新 (${#uptodate[@]}):${NC}"
        for template in "${uptodate[@]}"; do
            echo "  ✓ $template"
        done
        echo ""
    fi

    # 返回是否有更新
    [[ ${#outdated[@]} -gt 0 || ${#missing[@]} -gt 0 ]]
}

# ============================================================================
# 命令實作
# ============================================================================

cmd_sync_templates() {
    local mode="interactive"
    local -a selected_templates=()
    local target_dir=""
    local dry_run=false

    # 解析參數
    while [[ $# -gt 0 ]]; do
        case "$1" in
            --all|-a)
                mode="all"
                shift
                ;;
            --select|-s)
                mode="select"
                IFS=',' read -ra selected_templates <<< "$2"
                shift 2
                ;;
            --to|-t)
                target_dir="$2"
                shift 2
                ;;
            --dry-run|-n)
                dry_run=true
                shift
                ;;
            --help|-h)
                show_sync_help
                return 0
                ;;
            *)
                print_error "未知參數: $1"
                return 1
                ;;
        esac
    done

    print_header

    # 模式處理
    case "$mode" in
        all)
            mapfile -t selected_templates < <(get_templates_from_speckit)
            ;;
        select)
            # 已從參數取得
            ;;
        interactive)
            local -a selected
            mapfile -t selected < <(interactive_select_templates) || return 1
            selected_templates=("${selected[@]}")

            # 選擇目錄
            if [[ -z "$target_dir" ]]; then
                target_dir=$(interactive_select_directory)
            fi
            ;;
    esac

    # 使用配置檔案的目錄（如果未指定）
    if [[ -z "$target_dir" ]]; then
        local config
        config=$(load_config)
        target_dir=$(echo "$config" | jq -r '.templates.sync_dir // ".claude/templates"')
    fi

    # 設定環境變數供 sync_templates_batch 使用
    export DRY_RUN="$dry_run"

    # 執行同步
    sync_templates_batch "${selected_templates[@]}"

    # 更新配置
    if [[ "$dry_run" == "false" ]]; then
        local config
        config=$(load_config)
        config=$(echo "$config" | jq \
            --arg dir "$target_dir" \
            --argjson templates "$(printf '%s\n' "${selected_templates[@]}" | jq -R . | jq -s .)" \
            --arg time "$(date -u +"%Y-%m-%dT%H:%M:%SZ")" \
            '.templates.enabled = true |
             .templates.sync_dir = $dir |
             .templates.selected = $templates |
             .templates.last_sync = $time')
        save_config "$config"
    fi
}

cmd_check() {
    local include_templates=false
    local target_dir=""

    while [[ $# -gt 0 ]]; do
        case "$1" in
            --include-templates|-t)
                include_templates=true
                shift
                ;;
            --dir|-d)
                target_dir="$2"
                shift 2
                ;;
            *)
                shift
                ;;
        esac
    done

    print_header

    if [[ "$include_templates" == "true" ]]; then
        if [[ -z "$target_dir" ]]; then
            local config
            config=$(load_config)
            target_dir=$(echo "$config" | jq -r '.templates.sync_dir // ".claude/templates"')
        fi

        if check_template_updates "$target_dir"; then
            echo ""
            echo -e "${YELLOW}執行以下命令更新:${NC}"
            echo "  $0 update --include-templates"
        else
            print_success "所有模版都是最新的！"
        fi
    fi
}

cmd_update() {
    local include_templates=false
    local -a outdated=()

    while [[ $# -gt 0 ]]; do
        case "$1" in
            --include-templates|-t)
                include_templates=true
                shift
                ;;
            *)
                shift
                ;;
        esac
    done

    print_header

    if [[ "$include_templates" == "true" ]]; then
        local config
        config=$(load_config)
        local target_dir
        target_dir=$(echo "$config" | jq -r '.templates.sync_dir // ".claude/templates"')

        # 找出需要更新的模版
        local -a available_templates
        mapfile -t available_templates < <(get_templates_from_speckit)

        for template in "${available_templates[@]}"; do
            local source_path="$SPECKIT_PATH/templates/$template"
            local target_path="$target_dir/$template"

            if [[ ! -f "$target_path" ]] || ! cmp -s "$source_path" "$target_path"; then
                outdated+=("$template")
            fi
        done

        if [[ ${#outdated[@]} -gt 0 ]]; then
            print_info "發現 ${#outdated[@]} 個模版需要更新"
            sync_templates_batch "${outdated[@]}"
        else
            print_success "所有模版都是最新的！"
        fi
    fi
}

cmd_list() {
    local show_details=false

    while [[ $# -gt 0 ]]; do
        case "$1" in
            --details|-d)
                show_details=true
                shift
                ;;
            *)
                shift
                ;;
        esac
    done

    print_header
    print_section "可用模版"

    local -a templates
    mapfile -t templates < <(get_templates_from_speckit)

    echo ""
    for template in "${templates[@]}"; do
        if [[ "$show_details" == "true" ]]; then
            local info
            info=$(get_template_info "$template")
            printf "  ${BOLD}%-30s${NC} - %s\n" "$template" "$info"
        else
            echo "  • $template"
        fi
    done
    echo ""
    echo "總計: ${#templates[@]} 個模版"
}

cmd_status() {
    print_header

    local config
    config=$(load_config)

    print_section "同步狀態"
    echo ""

    local enabled
    enabled=$(echo "$config" | jq -r '.templates.enabled')
    echo "  啟用狀態: $(if [[ "$enabled" == "true" ]]; then echo -e "${GREEN}已啟用${NC}"; else echo -e "${GRAY}未啟用${NC}"; fi)"

    local sync_dir
    sync_dir=$(echo "$config" | jq -r '.templates.sync_dir // ".claude/templates"')
    echo "  同步目錄: $sync_dir"

    local last_sync
    last_sync=$(echo "$config" | jq -r '.templates.last_sync // "從未同步"')
    echo "  上次同步: $last_sync"

    echo ""
    print_section "已選擇的模版"
    echo ""

    local -a selected
    mapfile -t selected < <(echo "$config" | jq -r '.templates.selected[]? // empty')

    if [[ ${#selected[@]} -eq 0 ]]; then
        echo "  ${GRAY}未選擇任何模版${NC}"
    else
        for template in "${selected[@]}"; do
            local target_path="$sync_dir/$template"
            if [[ -f "$target_path" ]]; then
                echo "  ${GREEN}✓${NC} $template"
            else
                echo "  ${YELLOW}?${NC} $template ${GRAY}(檔案不存在)${NC}"
            fi
        done
    fi
}

cmd_config() {
    local action="${1:-show}"

    case "$action" in
        show)
            print_header
            print_section "當前配置"
            echo ""
            load_config | jq '.'
            ;;
        edit)
            if command -v "${EDITOR:-nano}" >/dev/null 2>&1; then
                "${EDITOR:-nano}" "$CONFIG_FILE"
            else
                print_error "找不到編輯器"
                return 1
            fi
            ;;
        reset)
            rm -f "$CONFIG_FILE"
            print_success "配置已重置"
            ;;
        *)
            print_error "未知操作: $action"
            print_info "可用操作: show, edit, reset"
            return 1
            ;;
    esac
}

# ============================================================================
# 說明文件
# ============================================================================

show_sync_help() {
    cat << 'EOF'
用法: speckit-sync-tool.sh sync [選項]

同步 spec-kit 模版檔案到專案目錄

選項:
  -a, --all              同步所有模版
  -s, --select NAMES     只同步特定模版（逗號分隔）
  -t, --to DIR           指定目標目錄
  -n, --dry-run          預覽模式（不實際寫入）
  -h, --help             顯示此說明

範例:
  # 互動式選擇模版
  ./speckit-sync-tool.sh sync

  # 同步所有模版
  ./speckit-sync-tool.sh sync --all

  # 只同步特定模版
  ./speckit-sync-tool.sh sync --select spec-template.md,plan-template.md

  # 同步到自訂目錄
  ./speckit-sync-tool.sh sync --all --to .speckit/templates

  # 預覽不執行
  ./speckit-sync-tool.sh sync --all --dry-run
EOF
}

show_help() {
    cat << 'EOF'
SpecKit Template Sync Tool - 模版同步工具

用法: speckit-sync-tool.sh <命令> [選項]

命令:
  sync          同步模版檔案
  check         檢查模版更新
  update        更新過時的模版
  list          列出可用模版
  status        顯示同步狀態
  config        管理配置檔案
  help          顯示此說明

執行 'speckit-sync-tool.sh <命令> --help' 查看個別命令說明

範例:
  ./speckit-sync-tool.sh sync --all
  ./speckit-sync-tool.sh check --include-templates
  ./speckit-sync-tool.sh list --details
  ./speckit-sync-tool.sh status
EOF
}

# ============================================================================
# 主程式
# ============================================================================

main() {
    # 檢查依賴
    if ! command -v jq >/dev/null 2>&1; then
        print_error "需要 jq 工具，請先安裝: brew install jq"
        exit 1
    fi

    local command="${1:-help}"
    shift || true

    case "$command" in
        sync)
            cmd_sync_templates "$@"
            ;;
        check)
            cmd_check "$@"
            ;;
        update)
            cmd_update "$@"
            ;;
        list|ls)
            cmd_list "$@"
            ;;
        status)
            cmd_status "$@"
            ;;
        config)
            cmd_config "$@"
            ;;
        help|--help|-h)
            show_help
            ;;
        *)
            print_error "未知命令: $command"
            echo ""
            show_help
            exit 1
            ;;
    esac
}

# 執行主程式
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main "$@"
fi
