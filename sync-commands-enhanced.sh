#!/usr/bin/env bash
#
# Spec-Kit 命令同步工具 v1.1.0
#
# 用於同步 GitHub spec-kit 命令到你的專案
#
# 使用方式：
#   ./sync-commands.sh init             - 初始化同步配置
#   ./sync-commands.sh check            - 檢查更新
#   ./sync-commands.sh update           - 執行同步
#   ./sync-commands.sh diff CMD         - 顯示差異
#   ./sync-commands.sh status           - 顯示狀態
#   ./sync-commands.sh list             - 列出所有可用命令
#   ./sync-commands.sh scan             - 掃描並檢測新命令
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

# 配置版本
CONFIG_VERSION="1.1.0"

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
    echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo -e "${CYAN}$1${NC}"
    echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
}

log_new() {
    echo -e "${MAGENTA}⊕${NC} $1"
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

update_speckit_repo() {
    # 檢查是否為 git 倉庫
    if [ ! -d "$SPECKIT_PATH/.git" ]; then
        log_warning "spec-kit 不是 git 倉庫，跳過自動更新"
        return 0
    fi

    log_info "檢查 spec-kit 是否有新版本..."

    # 切換到 spec-kit 目錄
    cd "$SPECKIT_PATH"

    # 檢查是否有未提交的變更
    if ! git diff-index --quiet HEAD -- 2>/dev/null; then
        log_warning "spec-kit 有未提交的變更，跳過自動更新"
        log_info "請先手動處理: cd $SPECKIT_PATH && git status"
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

    if [ "$local_commit" != "$remote_commit" ]; then
        log_info "發現 spec-kit 新版本，正在更新..."

        # 顯示版本變更
        local old_version=$(get_speckit_version)

        if git pull origin $current_branch --quiet; then
            local new_version=$(get_speckit_version)
            log_success "spec-kit 已更新: $old_version → $new_version"
        else
            log_error "spec-kit 更新失敗"
            cd - >/dev/null
            return 1
        fi
    else
        log_success "spec-kit 已是最新版本 ($(get_speckit_version))"
    fi

    cd - >/dev/null
}

# ============================================================================
# 階段 1：動態命令掃描功能
# ============================================================================

# 從 spec-kit 動態掃描所有可用命令
get_standard_commands_from_speckit() {
    validate_speckit_path

    # 掃描所有 .md 檔案
    local commands=()
    while IFS= read -r file; do
        commands+=("$(basename "$file")")
    done < <(find "$SPECKIT_COMMANDS" -maxdepth 1 -name "*.md" -type f | sort)

    # 返回命令清單（透過 echo，這樣可以用 array=($(...)) 接收）
    printf '%s\n' "${commands[@]}"
}

# 從命令檔案提取描述（YAML front matter 或第一個標題）
get_command_description() {
    local cmd_file="$1"

    if [ ! -f "$cmd_file" ]; then
        echo "(無描述)"
        return
    fi

    # 檢查是否有 YAML front matter
    if head -1 "$cmd_file" | grep -q "^---"; then
        # 提取 description 欄位
        local desc=$(grep "^description:" "$cmd_file" | head -1 | sed 's/^description:\s*//')
        if [ -n "$desc" ]; then
            echo "$desc"
            return
        fi
    fi

    # Fallback: 讀取第一個 Markdown 標題
    while IFS= read -r line; do
        # 跳過空行和 YAML front matter
        [ -z "$line" ] && continue
        [[ "$line" =~ ^--- ]] && continue

        # 提取 Markdown 標題
        if [[ "$line" =~ ^#+ ]]; then
            line=$(echo "$line" | sed 's/^#\+\s*//')
            if [ -n "$line" ]; then
                echo "$line"
                return
            fi
        fi
    done < "$cmd_file"

    echo "(無描述)"
}

# 從配置檔案讀取已知命令清單
get_known_commands() {
    if [ ! -f "$CONFIG_FILE" ]; then
        echo ""
        return
    fi

    # 使用 Python 或 jq 解析 JSON（如果可用）
    if command -v jq &> /dev/null; then
        jq -r '.known_commands[]? // empty' "$CONFIG_FILE" 2>/dev/null || echo ""
    else
        # 簡單的 grep/sed 解析（fallback）
        grep -A 100 '"known_commands"' "$CONFIG_FILE" 2>/dev/null | \
            grep '\.md"' | \
            sed 's/.*"\([^"]*\.md\)".*/\1/' || echo ""
    fi
}

# 檢測新命令
detect_new_commands() {
    log_header "🔍 掃描 Spec-Kit 新命令"
    validate_speckit_path

    echo ""
    echo "📁 Spec-Kit 路徑: $SPECKIT_PATH"
    echo "📁 命令目錄: $SPECKIT_COMMANDS"
    echo ""

    # 獲取 spec-kit 所有命令
    local -a speckit_commands
    mapfile -t speckit_commands < <(get_standard_commands_from_speckit)

    log_info "找到 ${#speckit_commands[@]} 個 Spec-Kit 命令"

    # 獲取已知命令
    local -a known_commands
    if [ -f "$CONFIG_FILE" ]; then
        mapfile -t known_commands < <(get_known_commands)
        log_info "配置檔案中已知 ${#known_commands[@]} 個命令"
    else
        log_warning "未找到配置檔案，所有命令都視為新命令"
    fi

    echo ""

    # 比對找出新命令
    local -a new_commands=()
    for cmd in "${speckit_commands[@]}"; do
        local is_known=0
        for known in "${known_commands[@]}"; do
            if [ "$cmd" = "$known" ]; then
                is_known=1
                break
            fi
        done

        if [ $is_known -eq 0 ]; then
            new_commands+=("$cmd")
        fi
    done

    # 顯示結果
    if [ ${#new_commands[@]} -eq 0 ]; then
        log_success "沒有檢測到新命令 🎉"
        return 0
    fi

    echo -e "${MAGENTA}🆕 Spec-Kit 新增了 ${#new_commands[@]} 個命令：${NC}"
    echo ""

    for cmd in "${new_commands[@]}"; do
        local desc=$(get_command_description "$SPECKIT_COMMANDS/$cmd")
        echo -e "  ${MAGENTA}⊕${NC} ${GREEN}$cmd${NC}"
        echo -e "     ${CYAN}$desc${NC}"
    done

    echo ""
    echo -e "${YELLOW}是否將新命令加入同步清單？${NC}"
    echo "  [a] 全部加入"
    echo "  [s] 選擇性加入"
    echo "  [n] 暫不加入"
    echo -n "選擇 [a/s/n]: "

    read -r choice
    choice=${choice:-n}

    case "$choice" in
        a|A)
            add_commands_to_config "${new_commands[@]}"
            log_success "已將 ${#new_commands[@]} 個新命令加入配置"
            ;;
        s|S)
            interactive_add_commands "${new_commands[@]}"
            ;;
        *)
            log_info "已取消，稍後可執行 'scan' 命令再次檢測"
            ;;
    esac
}

# 互動式選擇命令加入
interactive_add_commands() {
    local commands=("$@")
    local -a selected=()

    echo ""
    log_info "請選擇要加入的命令（輸入編號，用空格分隔，或 'all' 全選）："
    echo ""

    local i=1
    for cmd in "${commands[@]}"; do
        local desc=$(get_command_description "$SPECKIT_COMMANDS/$cmd")
        echo "  [$i] $cmd - $desc"
        ((i++))
    done

    echo ""
    echo -n "選擇 (例如: 1 3 5 或 all): "
    read -r selection

    if [ "$selection" = "all" ]; then
        selected=("${commands[@]}")
    else
        for num in $selection; do
            if [[ "$num" =~ ^[0-9]+$ ]] && [ "$num" -ge 1 ] && [ "$num" -le "${#commands[@]}" ]; then
                selected+=("${commands[$((num-1))]}")
            fi
        done
    fi

    if [ ${#selected[@]} -gt 0 ]; then
        add_commands_to_config "${selected[@]}"
        log_success "已將 ${#selected[@]} 個命令加入配置"
    else
        log_info "未選擇任何命令"
    fi
}

# 將命令加入配置檔案
add_commands_to_config() {
    local commands=("$@")

    if [ ! -f "$CONFIG_FILE" ]; then
        log_error "配置檔案不存在，請先執行 'init'"
        return 1
    fi

    # 備份配置檔案
    cp "$CONFIG_FILE" "$CONFIG_FILE.backup"

    # 升級到 v1.1.0 格式（如果需要）
    upgrade_config_to_v1_1

    # 使用 Python 更新 JSON（如果可用）
    if command -v python3 &> /dev/null; then
        python3 << EOF
import json
import sys

try:
    with open('$CONFIG_FILE', 'r', encoding='utf-8') as f:
        config = json.load(f)

    # 確保 known_commands 存在
    if 'known_commands' not in config:
        config['known_commands'] = []

    # 加入新命令
    new_cmds = $(printf '%s\n' "${commands[@]}" | python3 -c "import sys, json; print(json.dumps([line.strip() for line in sys.stdin if line.strip()]))")

    for cmd in new_cmds:
        if cmd not in config['known_commands']:
            config['known_commands'].append(cmd)

    # 排序
    config['known_commands'].sort()

    # 寫回檔案
    with open('$CONFIG_FILE', 'w', encoding='utf-8') as f:
        json.dump(config, f, indent=2, ensure_ascii=False)
        f.write('\n')

    print(f"已加入 {len(new_cmds)} 個命令")
except Exception as e:
    print(f"錯誤: {e}", file=sys.stderr)
    sys.exit(1)
EOF
    else
        log_warning "未安裝 python3，使用簡單文字處理（可能格式不完美）"

        # 簡單的文字插入（fallback）
        for cmd in "${commands[@]}"; do
            # 檢查是否已存在
            if ! grep -q "\"$cmd\"" "$CONFIG_FILE"; then
                # 在 known_commands 數組中插入
                if [[ "$OSTYPE" == "darwin"* ]]; then
                    sed -i '' "/\"known_commands\"/a\\
    \"$cmd\",
" "$CONFIG_FILE"
                else
                    sed -i "/\"known_commands\"/a\\    \"$cmd\"," "$CONFIG_FILE"
                fi
            fi
        done
    fi
}

# 升級配置檔案到 v1.1.0
upgrade_config_to_v1_1() {
    if [ ! -f "$CONFIG_FILE" ]; then
        return
    fi

    # 檢查版本
    local current_version=$(get_config_field "version")

    if [ "$current_version" = "1.1.0" ]; then
        return
    fi

    log_info "升級配置檔案: $current_version → 1.1.0"

    # 使用 Python 升級
    if command -v python3 &> /dev/null; then
        python3 << 'EOF'
import json
import sys

try:
    with open('.claude/.speckit-sync.json', 'r', encoding='utf-8') as f:
        config = json.load(f)

    # 升級到 v1.1.0
    if config.get('version') != '1.1.0':
        config['version'] = '1.1.0'

        # 從 standard commands 提取已知命令
        if 'known_commands' not in config:
            known = []
            for cmd in config.get('commands', {}).get('standard', []):
                if isinstance(cmd, dict) and 'name' in cmd:
                    known.append(cmd['name'])
                elif isinstance(cmd, str):
                    known.append(cmd)
            config['known_commands'] = sorted(known)

        # 寫回
        with open('.claude/.speckit-sync.json', 'w', encoding='utf-8') as f:
            json.dump(config, f, indent=2, ensure_ascii=False)
            f.write('\n')

        print("配置檔案已升級到 v1.1.0")
except Exception as e:
    print(f"升級失敗: {e}", file=sys.stderr)
    sys.exit(1)
EOF
    else
        # Fallback: 手動插入 known_commands
        if ! grep -q "\"known_commands\"" "$CONFIG_FILE"; then
            if [[ "$OSTYPE" == "darwin"* ]]; then
                sed -i '' '/"version"/a\
  "known_commands": [],
' "$CONFIG_FILE"
            else
                sed -i '/"version"/a\  "known_commands": [],' "$CONFIG_FILE"
            fi
        fi

        # 更新版本號
        update_config_field "version" "1.1.0"
    fi
}

# ============================================================================
# 主要功能（更新版）
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

    # 動態掃描 spec-kit 命令
    log_info "掃描 Spec-Kit 可用命令..."
    local -a all_commands
    mapfile -t all_commands < <(get_standard_commands_from_speckit)

    log_success "找到 ${#all_commands[@]} 個命令"
    echo ""

    # 掃描現有命令
    log_info "檢查本地命令狀態..."

    local standard_json=""

    for cmd in "${all_commands[@]}"; do
        local status="missing"
        if [ -f "$COMMANDS_DIR/$cmd" ]; then
            if diff -q "$COMMANDS_DIR/$cmd" "$SPECKIT_COMMANDS/$cmd" >/dev/null 2>&1; then
                status="synced"
            else
                status="customized"
            fi
        fi

        standard_json="${standard_json}      {\"name\": \"$cmd\", \"status\": \"$status\", \"version\": \"$speckit_version\", \"last_sync\": \"$timestamp\"},\n"
    done

    # 移除最後的逗號
    standard_json=$(echo -e "$standard_json" | sed '$ s/,$//')

    # 建立 known_commands 清單
    local known_json=$(printf '    "%s",\n' "${all_commands[@]}")
    known_json=$(echo -e "$known_json" | sed '$ s/,$//')

    # 建立配置檔案（v1.1.0 格式）
    cat > "$CONFIG_FILE" << EOF
{
  "version": "$CONFIG_VERSION",
  "source": {
    "type": "local",
    "path": "$SPECKIT_PATH",
    "version": "$speckit_version"
  },
  "known_commands": [
$(echo -e "$known_json")
  ],
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

    log_success "配置檔案已建立: $CONFIG_FILE (v$CONFIG_VERSION)"
    echo ""
    log_info "下一步: 執行 '$0 check' 檢查更新"
}

cmd_check() {
    log_header "檢查 Spec-Kit 更新"
    validate_speckit_path

    # 自動更新 spec-kit 倉庫
    update_speckit_repo
    echo ""

    echo "📁 Spec-Kit 路徑: $SPECKIT_PATH"
    echo "📁 命令目錄: $COMMANDS_DIR"
    echo "🔖 Spec-Kit 版本: $(get_speckit_version)"
    echo ""

    # 使用動態掃描
    local -a commands
    mapfile -t commands < <(get_standard_commands_from_speckit)

    local need_update=0
    local total=${#commands[@]}
    local missing=0
    local outdated=0
    local synced=0

    for cmd in "${commands[@]}"; do
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

    # 檢測新命令
    echo ""
    log_info "檢查是否有新命令..."
    detect_new_commands
}

cmd_update() {
    log_header "同步 Spec-Kit 命令"
    validate_speckit_path

    # 自動更新 spec-kit 倉庫
    update_speckit_repo
    echo ""

    # 建立備份
    local timestamp=$(date +%Y%m%d_%H%M%S)
    local backup_dir="$COMMANDS_DIR/.backup/$timestamp"
    mkdir -p "$backup_dir"

    log_info "📦 建立備份: $backup_dir"
    if ls "$COMMANDS_DIR"/*.md 1> /dev/null 2>&1; then
        cp "$COMMANDS_DIR"/*.md "$backup_dir/" 2>/dev/null || true
    fi

    echo ""

    # 使用動態掃描
    local -a commands
    mapfile -t commands < <(get_standard_commands_from_speckit)

    local updated=0
    local new_files=0
    local skipped=0

    for cmd in "${commands[@]}"; do
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
        echo "📌 配置版本: $(get_config_field "version")"
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

    # 動態取得命令清單
    local -a commands
    if [ -f "$CONFIG_FILE" ]; then
        mapfile -t commands < <(get_known_commands)
    else
        mapfile -t commands < <(get_standard_commands_from_speckit 2>/dev/null || echo "")
    fi

    echo ""
    echo "📋 已知命令 (${#commands[@]} 個):"
    for cmd in "${commands[@]}"; do
        if [ -f "$COMMANDS_DIR/$cmd" ]; then
            log_success "$cmd"
        else
            log_error "$cmd (不存在)"
        fi
    done

    echo ""
    echo "🎨 自訂命令:"
    local has_custom=0
    shopt -s nullglob
    for file in "$COMMANDS_DIR"/*.md; do
        [ -f "$file" ] || continue
        local basename=$(basename "$file")
        local is_standard=0

        for std in "${commands[@]}"; do
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

# 新命令：列出所有可用命令
cmd_list_commands() {
    local verbose=0

    # 處理參數
    if [ "$1" = "--verbose" ] || [ "$1" = "-v" ]; then
        verbose=1
    fi

    log_header "📋 Spec-Kit 可用命令"
    validate_speckit_path

    echo ""
    echo "📁 來源路徑: $SPECKIT_COMMANDS"
    echo ""

    local -a commands
    mapfile -t commands < <(get_standard_commands_from_speckit)

    if [ $verbose -eq 1 ]; then
        log_info "找到 ${#commands[@]} 個命令："
        echo ""

        for cmd in "${commands[@]}"; do
            local desc=$(get_command_description "$SPECKIT_COMMANDS/$cmd")
            local status=""

            # 檢查本地狀態
            if [ -f "$COMMANDS_DIR/$cmd" ]; then
                if diff -q "$COMMANDS_DIR/$cmd" "$SPECKIT_COMMANDS/$cmd" >/dev/null 2>&1; then
                    status="${GREEN}[已同步]${NC}"
                else
                    status="${YELLOW}[已修改]${NC}"
                fi
            else
                status="${RED}[未安裝]${NC}"
            fi

            echo -e "  ${CYAN}•${NC} ${GREEN}$cmd${NC} $status"
            echo -e "    ${desc}"
            echo ""
        done
    else
        log_info "找到 ${#commands[@]} 個命令："
        echo ""

        for cmd in "${commands[@]}"; do
            local status=""

            if [ -f "$COMMANDS_DIR/$cmd" ]; then
                if diff -q "$COMMANDS_DIR/$cmd" "$SPECKIT_COMMANDS/$cmd" >/dev/null 2>&1; then
                    status="${GREEN}✓${NC}"
                else
                    status="${YELLOW}↻${NC}"
                fi
            else
                status="${RED}⊕${NC}"
            fi

            echo -e "  $status $cmd"
        done

        echo ""
        log_info "使用 --verbose 或 -v 顯示詳細描述"
    fi
}

# 新命令：掃描並檢測新命令
cmd_scan() {
    detect_new_commands
}

# ============================================================================
# 配置檔案輔助函數
# ============================================================================

get_config_field() {
    local field="$1"
    if [ -f "$CONFIG_FILE" ]; then
        # 嘗試使用 jq
        if command -v jq &> /dev/null; then
            jq -r ".$field // .metadata.$field // .source.$field // \"\"" "$CONFIG_FILE" 2>/dev/null || echo ""
        else
            # Fallback to grep/sed
            grep "\"$field\"" "$CONFIG_FILE" | head -1 | sed 's/.*: "\?\([^",]*\)"\?,\?/\1/'
        fi
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
            sed -i '' "s/\"$field\": [0-9]*/\"$field\": $value/" "$CONFIG_FILE"
        else
            sed -i "s/\"$field\": \"[^\"]*\"/\"$field\": \"$value\"/" "$CONFIG_FILE"
            sed -i "s/\"$field\": [0-9]*/\"$field\": $value/" "$CONFIG_FILE"
        fi
    fi
}

# ============================================================================
# 主程式
# ============================================================================

show_usage() {
    cat << EOF
${CYAN}Spec-Kit 命令同步工具 v${CONFIG_VERSION}${NC}

使用方式:
    $0 <command> [arguments]

命令:
    ${GREEN}init${NC}                    初始化同步配置
    ${GREEN}check${NC}                   檢查哪些命令需要更新
    ${GREEN}update${NC}                  執行同步更新
    ${GREEN}diff${NC} <command>          顯示指定命令的差異
    ${GREEN}status${NC}                  顯示同步狀態
    ${GREEN}list${NC} [--verbose|-v]    列出所有可用命令
    ${GREEN}scan${NC}                    掃描並檢測新命令
    ${GREEN}help${NC}                    顯示此幫助訊息

環境變數:
    SPECKIT_PATH       spec-kit 倉庫的路徑 (預設: ~/Documents/GitHub/spec-kit)
    COMMANDS_DIR       命令目錄的路徑 (預設: .claude/commands)

範例:
    # 初始化專案
    $0 init

    # 檢查更新
    $0 check

    # 列出所有可用命令
    $0 list --verbose

    # 掃描新命令
    $0 scan

    # 執行同步
    $0 update

    # 查看特定命令的差異
    $0 diff implement.md

    # 使用自訂 spec-kit 路徑
    SPECKIT_PATH=/custom/path/spec-kit $0 check

更新日誌 (v1.1.0):
    • 新增動態命令掃描功能
    • 新增新命令檢測
    • 新增 list 命令（列出所有可用命令）
    • 新增 scan 命令（檢測新命令）
    • 配置檔案升級到 v1.1.0（向後相容）

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
        list|ls)
            cmd_list_commands "${2:-}"
            ;;
        scan|detect)
            cmd_scan
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
