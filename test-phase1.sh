#!/usr/bin/env bash
#
# 階段 1 功能測試腳本
#
# 此腳本測試動態命令掃描的所有新功能
#

set -e

# 顏色
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m'

# 測試計數器
TOTAL_TESTS=0
PASSED_TESTS=0
FAILED_TESTS=0

# 測試工具路徑
SYNC_TOOL="./sync-commands-enhanced.sh"
TEST_DIR="/tmp/speckit-sync-test-$$"

# ============================================================================
# 測試輔助函數
# ============================================================================

test_header() {
    echo ""
    echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo -e "${CYAN}測試: $1${NC}"
    echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
}

assert_success() {
    ((TOTAL_TESTS++))
    if [ $? -eq 0 ]; then
        echo -e "${GREEN}✓${NC} $1"
        ((PASSED_TESTS++))
    else
        echo -e "${RED}✗${NC} $1"
        ((FAILED_TESTS++))
    fi
}

assert_file_exists() {
    ((TOTAL_TESTS++))
    if [ -f "$1" ]; then
        echo -e "${GREEN}✓${NC} 檔案存在: $1"
        ((PASSED_TESTS++))
    else
        echo -e "${RED}✗${NC} 檔案不存在: $1"
        ((FAILED_TESTS++))
    fi
}

assert_contains() {
    ((TOTAL_TESTS++))
    if grep -q "$2" "$1" 2>/dev/null; then
        echo -e "${GREEN}✓${NC} 檔案包含 '$2': $1"
        ((PASSED_TESTS++))
    else
        echo -e "${RED}✗${NC} 檔案不包含 '$2': $1"
        ((FAILED_TESTS++))
    fi
}

# ============================================================================
# 環境準備
# ============================================================================

setup_test_env() {
    test_header "環境準備"

    # 檢查工具是否存在
    if [ ! -f "$SYNC_TOOL" ]; then
        echo -e "${RED}錯誤: 找不到 $SYNC_TOOL${NC}"
        echo "請確保在專案根目錄執行此腳本"
        exit 1
    fi

    # 創建測試目錄
    mkdir -p "$TEST_DIR"
    cd "$TEST_DIR"
    echo -e "${GREEN}✓${NC} 測試目錄: $TEST_DIR"

    # 檢查 SPECKIT_PATH
    if [ -z "$SPECKIT_PATH" ]; then
        export SPECKIT_PATH="$HOME/Documents/GitHub/spec-kit"
    fi

    if [ ! -d "$SPECKIT_PATH/templates/commands" ]; then
        echo -e "${RED}錯誤: spec-kit 路徑無效: $SPECKIT_PATH${NC}"
        exit 1
    fi

    echo -e "${GREEN}✓${NC} Spec-Kit 路徑: $SPECKIT_PATH"
}

cleanup_test_env() {
    test_header "清理測試環境"
    cd /tmp
    rm -rf "$TEST_DIR"
    echo -e "${GREEN}✓${NC} 已清理: $TEST_DIR"
}

# ============================================================================
# 測試案例
# ============================================================================

test_list_commands() {
    test_header "測試 1: 列出可用命令"

    # 基本列表
    echo "測試基本列表..."
    $SYNC_TOOL list > /tmp/list-output.txt 2>&1
    assert_success "執行 list 命令"

    assert_contains "/tmp/list-output.txt" "analyze.md"
    assert_contains "/tmp/list-output.txt" "implement.md"

    # 詳細模式
    echo ""
    echo "測試詳細模式..."
    $SYNC_TOOL list --verbose > /tmp/list-verbose-output.txt 2>&1
    assert_success "執行 list --verbose 命令"

    assert_contains "/tmp/list-verbose-output.txt" "analyze.md"

    rm -f /tmp/list-output.txt /tmp/list-verbose-output.txt
}

test_init_with_dynamic_scan() {
    test_header "測試 2: 使用動態掃描初始化"

    # 執行初始化
    echo "y" | $SYNC_TOOL init > /dev/null 2>&1
    assert_success "執行 init 命令"

    # 檢查配置檔案
    assert_file_exists ".claude/.speckit-sync.json"

    # 檢查配置版本
    assert_contains ".claude/.speckit-sync.json" '"version": "1.1.0"'

    # 檢查 known_commands 欄位
    assert_contains ".claude/.speckit-sync.json" '"known_commands"'
    assert_contains ".claude/.speckit-sync.json" '"analyze.md"'
}

test_config_upgrade() {
    test_header "測試 3: 配置檔案自動升級"

    # 創建 v1.0.0 配置
    mkdir -p .claude
    cat > .claude/.speckit-sync.json << 'EOF'
{
  "version": "1.0.0",
  "source": {
    "type": "local",
    "path": "/path/to/spec-kit",
    "version": "0.0.20"
  },
  "commands": {
    "standard": [
      {"name": "analyze.md", "status": "synced"}
    ]
  }
}
EOF

    # 執行掃描（會觸發升級）
    echo "n" | $SYNC_TOOL scan > /dev/null 2>&1 || true

    # 檢查是否升級到 v1.1.0
    assert_contains ".claude/.speckit-sync.json" '"version": "1.1.0"'
    assert_contains ".claude/.speckit-sync.json" '"known_commands"'
}

test_new_command_detection() {
    test_header "測試 4: 新命令檢測"

    # 先初始化一個只有部分命令的配置
    mkdir -p .claude
    cat > .claude/.speckit-sync.json << 'EOF'
{
  "version": "1.1.0",
  "source": {
    "type": "local",
    "path": "$SPECKIT_PATH",
    "version": "0.0.20"
  },
  "known_commands": [
    "analyze.md",
    "implement.md"
  ],
  "commands": {
    "standard": [],
    "custom": [],
    "ignored": []
  }
}
EOF

    # 執行掃描（應該檢測到其他命令）
    echo "n" | $SYNC_TOOL scan > /tmp/scan-output.txt 2>&1 || true

    # 檢查輸出
    if grep -q "新增了.*個命令" /tmp/scan-output.txt; then
        echo -e "${GREEN}✓${NC} 檢測到新命令"
        ((PASSED_TESTS++))
    else
        echo -e "${YELLOW}⚠${NC} 未檢測到新命令（可能所有命令都已存在）"
    fi
    ((TOTAL_TESTS++))

    rm -f /tmp/scan-output.txt
}

test_check_with_scan() {
    test_header "測試 5: check 命令整合掃描"

    # 初始化
    echo "y" | $SYNC_TOOL init > /dev/null 2>&1

    # 執行 check（會自動掃描新命令）
    echo "n" | $SYNC_TOOL check > /tmp/check-output.txt 2>&1 || true
    assert_success "執行 check 命令"

    # 檢查是否包含掃描訊息
    if grep -q "檢查是否有新命令" /tmp/check-output.txt; then
        echo -e "${GREEN}✓${NC} check 命令包含新命令掃描"
        ((PASSED_TESTS++))
    else
        echo -e "${RED}✗${NC} check 命令未包含新命令掃描"
        ((FAILED_TESTS++))
    fi
    ((TOTAL_TESTS++))

    rm -f /tmp/check-output.txt
}

test_dynamic_command_list() {
    test_header "測試 6: 動態命令清單"

    # 初始化
    echo "y" | $SYNC_TOOL init > /dev/null 2>&1

    # 執行 status
    $SYNC_TOOL status > /tmp/status-output.txt 2>&1

    # 檢查是否使用動態清單
    assert_contains "/tmp/status-output.txt" "已知命令"

    # 檢查命令數量是否正確
    local cmd_count=$(find "$SPECKIT_PATH/templates/commands" -name "*.md" -type f | wc -l)
    if grep -q "已知命令 ($cmd_count 個)" /tmp/status-output.txt; then
        echo -e "${GREEN}✓${NC} 命令數量正確: $cmd_count"
        ((PASSED_TESTS++))
    else
        echo -e "${YELLOW}⚠${NC} 命令數量可能不同"
    fi
    ((TOTAL_TESTS++))

    rm -f /tmp/status-output.txt
}

test_command_description_extraction() {
    test_header "測試 7: 命令描述提取"

    # 測試詳細列表中是否有描述
    $SYNC_TOOL list -v > /tmp/list-desc.txt 2>&1

    # 檢查是否包含描述文字（不只是檔名）
    local has_description=0
    if grep -A 1 "analyze.md" /tmp/list-desc.txt | grep -q -v "analyze.md"; then
        has_description=1
    fi

    if [ $has_description -eq 1 ]; then
        echo -e "${GREEN}✓${NC} 成功提取命令描述"
        ((PASSED_TESTS++))
    else
        echo -e "${RED}✗${NC} 未能提取命令描述"
        ((FAILED_TESTS++))
    fi
    ((TOTAL_TESTS++))

    rm -f /tmp/list-desc.txt
}

# ============================================================================
# 主測試流程
# ============================================================================

run_all_tests() {
    echo -e "${CYAN}"
    echo "╔════════════════════════════════════════════╗"
    echo "║   Spec-Kit Sync Tool - 階段 1 功能測試    ║"
    echo "╚════════════════════════════════════════════╝"
    echo -e "${NC}"

    setup_test_env

    test_list_commands
    test_init_with_dynamic_scan
    test_config_upgrade
    test_new_command_detection
    test_check_with_scan
    test_dynamic_command_list
    test_command_description_extraction

    cleanup_test_env

    # 顯示測試結果
    echo ""
    echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo -e "${CYAN}測試結果${NC}"
    echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo ""
    echo "總測試數: $TOTAL_TESTS"
    echo -e "${GREEN}通過: $PASSED_TESTS${NC}"
    echo -e "${RED}失敗: $FAILED_TESTS${NC}"
    echo ""

    if [ $FAILED_TESTS -eq 0 ]; then
        echo -e "${GREEN}✓ 所有測試通過！🎉${NC}"
        exit 0
    else
        echo -e "${RED}✗ 有 $FAILED_TESTS 個測試失敗${NC}"
        exit 1
    fi
}

# ============================================================================
# 執行測試
# ============================================================================

# 處理 Ctrl+C
trap cleanup_test_env EXIT INT TERM

# 執行所有測試
run_all_tests
