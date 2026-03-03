# 階段 1：動態命令掃描 - 整合指南

## 📋 概述

此文檔說明如何將階段 1 的新功能整合到現有的 `sync-commands.sh` 中。

## 🎯 新功能清單

### 1. 動態命令掃描
- ✅ `get_standard_commands_from_speckit()` - 從 spec-kit 動態掃描所有 .md 命令
- ✅ `get_command_description()` - 提取命令描述（第一行內容）

### 2. 新命令檢測
- ✅ `detect_new_commands()` - 比對並檢測新增的命令
- ✅ `get_known_commands()` - 從配置檔讀取已知命令清單
- ✅ 互動式選擇介面（全部/選擇性/取消）

### 3. 配置檔案升級
- ✅ `upgrade_config_to_v1_1()` - 自動升級 v1.0.0 → v1.1.0
- ✅ `add_commands_to_config()` - 將新命令加入配置
- ✅ `interactive_add_commands()` - 互動式選擇命令

### 4. 新 CLI 命令
- ✅ `cmd_list_commands()` - 列出所有可用命令（支援 --verbose）
- ✅ `cmd_scan()` - 掃描並檢測新命令

### 5. 更新現有命令
- ✅ `cmd_init()` - 使用動態掃描初始化
- ✅ `cmd_check()` - 整合新命令檢測
- ✅ `cmd_update()` - 使用動態命令清單
- ✅ `cmd_status()` - 顯示動態命令狀態

## 🔄 整合方式

### 選項 1：直接替換（推薦）

最簡單的方式是直接使用新版本：

```bash
# 備份原檔案
cp sync-commands.sh sync-commands.sh.v1.0.0.backup

# 使用新版本
mv sync-commands-enhanced.sh sync-commands.sh
chmod +x sync-commands.sh
```

### 選項 2：手動整合

如果你有自訂修改，可以手動整合以下區塊：

#### Step 1: 更新配置版本號

```bash
# 在配置區塊更新
CONFIG_VERSION="1.1.0"
```

#### Step 2: 移除硬編碼命令清單

**刪除這段：**
```bash
# 標準命令清單
STANDARD_COMMANDS=(
    "analyze.md"
    "checklist.md"
    ...
)
```

#### Step 3: 加入新函數

從 `sync-commands-enhanced.sh` 複製以下區塊到你的檔案（在 `update_speckit_repo()` 之後）：

```bash
# ============================================================================
# 階段 1：動態命令掃描功能
# ============================================================================

get_standard_commands_from_speckit() { ... }
get_command_description() { ... }
get_known_commands() { ... }
detect_new_commands() { ... }
interactive_add_commands() { ... }
add_commands_to_config() { ... }
upgrade_config_to_v1_1() { ... }
```

#### Step 4: 更新現有命令函數

**cmd_init():**
```bash
# 將這行：
for cmd in "${STANDARD_COMMANDS[@]}"; do

# 改為：
local -a all_commands
mapfile -t all_commands < <(get_standard_commands_from_speckit)

for cmd in "${all_commands[@]}"; do
```

並在配置檔案中加入 `known_commands` 欄位。

**cmd_check():**
```bash
# 在函數結尾加入：
echo ""
log_info "檢查是否有新命令..."
detect_new_commands
```

**cmd_update():**
```bash
# 將陣列來源改為動態掃描
local -a commands
mapfile -t commands < <(get_standard_commands_from_speckit)
```

**cmd_status():**
```bash
# 改用動態取得命令清單
local -a commands
if [ -f "$CONFIG_FILE" ]; then
    mapfile -t commands < <(get_known_commands)
else
    mapfile -t commands < <(get_standard_commands_from_speckit 2>/dev/null || echo "")
fi
```

#### Step 5: 加入新 CLI 命令

在 `main()` 函數的 case 語句中加入：

```bash
list|ls)
    cmd_list_commands "${2:-}"
    ;;
scan|detect)
    cmd_scan
    ;;
```

#### Step 6: 更新 show_usage()

加入新命令的說明。

## 📝 配置檔案格式變更

### v1.0.0 格式
```json
{
  "version": "1.0.0",
  "source": {...},
  "commands": {
    "standard": [...],
    "custom": [...],
    "ignored": []
  },
  ...
}
```

### v1.1.0 格式（新增 known_commands）
```json
{
  "version": "1.1.0",
  "source": {...},
  "known_commands": [
    "analyze.md",
    "checklist.md",
    "clarify.md",
    ...
  ],
  "commands": {
    "standard": [...],
    "custom": [...],
    "ignored": []
  },
  ...
}
```

**向後相容性：**
- 自動檢測舊版配置
- 自動升級到 v1.1.0
- 從 `commands.standard` 提取 `known_commands`
- 無需手動遷移

## 🧪 測試步驟

### 1. 基本功能測試

```bash
# 測試列出命令
./sync-commands.sh list

# 測試詳細模式
./sync-commands.sh list --verbose

# 測試掃描新命令
./sync-commands.sh scan
```

### 2. 初始化測試

```bash
# 在測試專案中初始化
cd /path/to/test-project
/path/to/sync-commands.sh init

# 檢查生成的配置檔案
cat .claude/.speckit-sync.json | grep -A 5 "known_commands"
```

### 3. 升級測試

```bash
# 使用舊版配置測試升級
cp .speckit-sync.json.template .claude/.speckit-sync.json

# 執行掃描（會自動升級）
./sync-commands.sh scan

# 驗證配置版本
grep '"version"' .claude/.speckit-sync.json
```

### 4. 新命令檢測測試

**模擬新命令場景：**

```bash
# 1. 在 spec-kit 中創建測試命令
echo "# Test Command" > /path/to/spec-kit/templates/commands/test-new.md

# 2. 執行掃描
./sync-commands.sh scan

# 應該會檢測到 test-new.md
# 選擇 'a' 加入所有新命令

# 3. 驗證配置已更新
grep "test-new.md" .claude/.speckit-sync.json

# 4. 清理測試
rm /path/to/spec-kit/templates/commands/test-new.md
```

### 5. 完整流程測試

```bash
# 完整工作流程
./sync-commands.sh init          # 初始化
./sync-commands.sh list -v       # 列出所有命令
./sync-commands.sh scan          # 掃描新命令
./sync-commands.sh check         # 檢查更新
./sync-commands.sh update        # 執行同步
./sync-commands.sh status        # 查看狀態
```

## 🎨 使用範例

### 範例 1: 列出所有可用命令

```bash
$ ./sync-commands.sh list

━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
📋 Spec-Kit 可用命令
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

📁 來源路徑: /path/to/spec-kit/templates/commands

ℹ 找到 8 個命令：

  ✓ analyze.md
  ✓ checklist.md
  ✓ clarify.md
  ✓ constitution.md
  ✓ implement.md
  ✓ plan.md
  ✓ specify.md
  ✓ tasks.md

ℹ 使用 --verbose 或 -v 顯示詳細描述
```

### 範例 2: 詳細模式列出命令

```bash
$ ./sync-commands.sh list --verbose

━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
📋 Spec-Kit 可用命令
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

📁 來源路徑: /path/to/spec-kit/templates/commands

ℹ 找到 8 個命令：

  • analyze.md [已同步]
    Code Analysis Assistant

  • checklist.md [已同步]
    Quality Assurance Checklist Generator

  • clarify.md [已同步]
    Requirements Clarification Helper

  ...
```

### 範例 3: 檢測新命令

```bash
$ ./sync-commands.sh scan

━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
🔍 掃描 Spec-Kit 新命令
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

📁 Spec-Kit 路徑: /path/to/spec-kit
📁 命令目錄: /path/to/spec-kit/templates/commands

ℹ 找到 10 個 Spec-Kit 命令
ℹ 配置檔案中已知 8 個命令

🆕 Spec-Kit 新增了 2 個命令：

  ⊕ refactor.md
     Code Refactoring Assistant

  ⊕ review.md
     Code Review Helper

是否將新命令加入同步清單？
  [a] 全部加入
  [s] 選擇性加入
  [n] 暫不加入
選擇 [a/s/n]: a

✓ 已將 2 個新命令加入配置
```

### 範例 4: 選擇性加入命令

```bash
選擇 [a/s/n]: s

ℹ 請選擇要加入的命令（輸入編號，用空格分隔，或 'all' 全選）：

  [1] refactor.md - Code Refactoring Assistant
  [2] review.md - Code Review Helper

選擇 (例如: 1 3 5 或 all): 1

✓ 已將 1 個命令加入配置
```

## 🐛 錯誤處理

### 常見問題

1. **spec-kit 路徑無效**
   ```bash
   ✗ spec-kit 路徑無效: /path/to/spec-kit
   ℹ 請設定環境變數: export SPECKIT_PATH=/path/to/spec-kit
   ```

2. **配置檔案不存在**
   ```bash
   ✗ 配置檔案不存在，請先執行 'init'
   ```

3. **Python 未安裝（降級處理）**
   ```bash
   ⚠ 未安裝 python3，使用簡單文字處理（可能格式不完美）
   ```

### 依賴項

**必需：**
- Bash 4.0+
- 基本 Unix 工具（grep, sed, find）

**可選（增強功能）：**
- `python3` - 用於 JSON 處理（沒有會自動降級到 sed）
- `jq` - 用於 JSON 查詢（沒有會自動降級到 grep/sed）

## 📊 功能對照表

| 功能 | v1.0.0 | v1.1.0 |
|------|--------|--------|
| 硬編碼命令清單 | ✅ | ❌ |
| 動態掃描命令 | ❌ | ✅ |
| 新命令檢測 | ❌ | ✅ |
| 互動式選擇 | ❌ | ✅ |
| 列出可用命令 | ❌ | ✅ |
| 顯示命令描述 | ❌ | ✅ |
| 配置自動升級 | N/A | ✅ |
| 向後相容 | N/A | ✅ |

## 🚀 後續階段預告

### 階段 2：衝突處理與合併策略（規劃中）
- 智能合併自訂修改
- 三方比對工具
- 衝突解決介面

### 階段 3：版本追蹤與回滾（規劃中）
- 命令版本歷史
- 快速回滾機制
- 變更日誌生成

## 📞 支援

如有問題請查看：
- 主 README.md
- GitHub Issues
- 執行 `./sync-commands.sh help`

---

**版本：** 1.1.0
**更新日期：** 2025-10-16
**作者：** Claude Code
