# speckit-sync 整合說明

## 目錄結構

```
spec-kit/
├── speckit-sync                    # 主程式（可執行）
├── .speckit-sync-config.json       # 配置檔案（由工具生成）
└── claudedocs/
    ├── speckit-sync-tool-phase2-architecture.md  # 架構文檔
    ├── speckit-sync-tool-usage-examples.md       # 使用範例
    └── speckit-sync-tool-integration-guide.md    # 本文件
```

## 與現有 spec-kit 的整合

### 1. 作為 Specify CLI 的擴充功能

speckit-sync 是獨立的工具，但可以與 Specify CLI 協同工作：

```bash
# 初始化專案（使用 Specify CLI）
specify init my-project --ai claude

cd my-project

# 安裝 speckit-sync
cp /path/to/spec-kit/speckit-sync .
chmod +x speckit-sync

# 初始化同步配置
./speckit-sync init

# 同步命令檔案
./speckit-sync update
```

### 2. 與現有代理目錄結構相容

speckit-sync 使用與 `src/specify_cli/__init__.py` 中定義相同的代理映射：

| 代理 | Specify CLI | speckit-sync |
|------|-------------|--------------|
| Claude | `.claude/` | `.claude/commands` |
| Copilot | `.github/` | `.github/prompts` |
| Cursor | `.cursor/` | `.cursor/commands` |
| Gemini | `.gemini/` | `.gemini/commands` |
| 等... | ... | ... |

### 3. 命令檔案來源

speckit-sync 同步的命令檔案來自：

```
spec-kit/templates/commands/
├── specify.md
├── plan.md
├── tasks.md
├── implement.md
├── constitution.md
├── clarify.md
├── analyze.md
└── checklist.md
```

## 實作待完成項目

### 階段 2 核心功能（已實作）

- [x] 代理自動檢測 (`detect_agents()`)
- [x] 互動式初始化 (`cmd_init()`)
- [x] 配置檔案 v2.0.0 結構
- [x] 配置升級邏輯 (`upgrade_config_to_v2()`)
- [x] CLI 命令框架
  - [x] `speckit-sync init`
  - [x] `speckit-sync detect-agents`
  - [x] `speckit-sync check [--agent <name>]`
  - [x] `speckit-sync update [--agent <name>]`
  - [x] `speckit-sync version`
  - [x] `speckit-sync help`
- [x] 單代理同步框架 (`sync_single_agent()`)
- [x] 多代理同步框架 (`sync_all_agents()`)

### 階段 2 待實作功能

#### 🔴 高優先級（核心功能）

1. **實作實際的檔案同步邏輯** (`sync_command_file()`)
   ```bash
   sync_command_file() {
       local agent="$1"
       local command="$2"
       local target_file="$3"

       # TODO: 實作以下功能
       # 1. 從 GitHub spec-kit 倉庫下載命令檔案
       # 2. 處理不同代理的檔案格式（Markdown vs TOML）
       # 3. 替換佔位符（$ARGUMENTS, {SCRIPT} 等）
       # 4. 寫入目標檔案
       # 5. 錯誤處理和重試邏輯
   }
   ```

2. **差異檢測** (`detect_customization()`)
   ```bash
   detect_customization() {
       local agent="$1"
       local command="$2"
       local local_file="$3"

       # TODO: 實作以下功能
       # 1. 計算本地檔案的 checksum
       # 2. 與標準版本比較
       # 3. 標記為 customized 如果不同
   }
   ```

3. **網路錯誤處理**
   - 下載失敗重試機制
   - 網路超時處理
   - 部分成功的回滾策略

#### 🟡 中優先級（品質提升）

4. **進度顯示**
   ```bash
   # 同步多個檔案時顯示進度條
   sync_with_progress() {
       local total=$1
       local current=0

       # TODO: 實作進度條顯示
   }
   ```

5. **備份機制**
   ```bash
   backup_before_sync() {
       local target_file="$1"

       # TODO: 在覆寫前備份檔案
       # .claude/commands/specify.md.backup.20251016_120000
   }
   ```

6. **衝突解決介面**
   ```bash
   resolve_conflict() {
       local agent="$1"
       local command="$2"

       # TODO: 提供互動式衝突解決
       # 選項：
       # 1. 保留本地版本
       # 2. 使用遠端版本
       # 3. 合併（進階）
       # 4. 跳過
   }
   ```

#### 🟢 低優先級（增強功能）

7. **乾跑模式**
   ```bash
   speckit-sync update --dry-run --agent claude
   # 顯示將要執行的操作，但不實際執行
   ```

8. **詳細日誌**
   ```bash
   speckit-sync update --verbose --agent all
   # 顯示詳細的除錯資訊
   ```

9. **選擇性同步**
   ```bash
   speckit-sync update --agent claude --only specify.md,plan.md
   # 只同步特定命令
   ```

## 檔案同步實作方案

### 方案 A：直接從 GitHub 下載（推薦）

```bash
sync_command_file() {
    local agent="$1"
    local command="$2"
    local target_file="$3"

    local repo="github/spec-kit"
    local branch="main"
    local source_path="templates/commands/$command"
    local url="https://raw.githubusercontent.com/$repo/$branch/$source_path"

    # 下載檔案
    if curl -fsSL "$url" -o "$target_file"; then
        log_success "已下載 $command"
        return 0
    else
        log_error "下載失敗: $command"
        return 1
    fi
}
```

**優點**：
- 簡單直接
- 總是獲得最新版本
- 不需要本地 spec-kit 倉庫

**缺點**：
- 需要網路連線
- 可能遇到 GitHub rate limiting
- 無法離線使用

### 方案 B：從本地 spec-kit 倉庫複製

```bash
sync_command_file() {
    local agent="$1"
    local command="$2"
    local target_file="$3"

    # 假設 spec-kit 已 clone 到某處
    local spec_kit_path="${SPEC_KIT_PATH:-$HOME/spec-kit}"
    local source_file="$spec_kit_path/templates/commands/$command"

    if [ ! -f "$source_file" ]; then
        log_error "來源檔案不存在: $source_file"
        return 1
    fi

    cp "$source_file" "$target_file"
    return $?
}
```

**優點**：
- 可離線使用
- 速度快
- 可以使用特定版本/分支

**缺點**：
- 需要先 clone spec-kit 倉庫
- 需要手動更新本地倉庫
- 多一層配置複雜度

### 方案 C：混合方案（最佳實踐）

```bash
sync_command_file() {
    local agent="$1"
    local command="$2"
    local target_file="$3"

    # 優先使用本地倉庫
    if [ -n "${SPEC_KIT_PATH:-}" ] && [ -d "$SPEC_KIT_PATH" ]; then
        sync_from_local "$agent" "$command" "$target_file"
    else
        # 降級到網路下載
        sync_from_github "$agent" "$command" "$target_file"
    fi
}
```

## 代理特定處理

### 不同代理的檔案格式差異

#### 1. Markdown 格式（Claude, Cursor, Copilot）

```markdown
---
description: "Command description"
---

## User Input

\`\`\`text
$ARGUMENTS
\`\`\`

## Outline

執行 {SCRIPT} ...
```

#### 2. TOML 格式（Gemini, Qwen）

```toml
description = "Command description"

prompt = """
使用者輸入: {{args}}

執行 {SCRIPT} ...
"""
```

### 格式轉換邏輯

```bash
convert_to_agent_format() {
    local source_file="$1"
    local target_file="$2"
    local agent="$3"

    case "$agent" in
        gemini|qwen)
            # 轉換 Markdown → TOML
            convert_md_to_toml "$source_file" "$target_file"
            ;;
        *)
            # 直接複製 Markdown
            cp "$source_file" "$target_file"
            ;;
    esac
}
```

## 測試策略

### 單元測試

```bash
# tests/test_detect_agents.sh
test_detect_agents() {
    # 建立測試目錄
    mkdir -p /tmp/test-project/.claude/commands
    mkdir -p /tmp/test-project/.cursor/commands

    cd /tmp/test-project

    # 執行檢測
    result=$(./speckit-sync detect-agents)

    # 驗證結果
    assert_contains "$result" "Claude Code"
    assert_contains "$result" "Cursor"
    assert_not_contains "$result" "Copilot"
}
```

### 整合測試

```bash
# tests/integration_test.sh
test_full_workflow() {
    cd /tmp/test-project

    # 1. 初始化
    echo "1 2" | ./speckit-sync init
    assert_file_exists ".speckit-sync-config.json"

    # 2. 檢查配置
    version=$(jq -r '.version' .speckit-sync-config.json)
    assert_equals "$version" "2.0.0"

    # 3. 同步
    ./speckit-sync update --agent claude

    # 4. 驗證檔案
    assert_file_exists ".claude/commands/specify.md"
}
```

## 部署建議

### 1. 作為獨立工具

```bash
# 全域安裝
sudo cp speckit-sync /usr/local/bin/
sudo chmod +x /usr/local/bin/speckit-sync

# 在任何專案中使用
cd ~/projects/my-app
speckit-sync init
```

### 2. 包含在 Specify CLI

```python
# src/specify_cli/__init__.py

@app.command()
def sync(
    agent: str = typer.Option(None, "--agent", help="Agent to sync")
):
    """Sync spec-kit commands for AI agents."""
    script_path = Path(__file__).parent.parent.parent / "speckit-sync"

    cmd = [str(script_path), "update"]
    if agent:
        cmd.extend(["--agent", agent])

    subprocess.run(cmd, check=True)
```

使用：
```bash
specify sync --agent claude
```

### 3. 作為 Git Hook

```bash
# .git/hooks/post-merge
#!/bin/bash

# 專案更新後自動同步命令
if [ -f ".speckit-sync-config.json" ]; then
    ./speckit-sync update --quiet
fi
```

## 設定範例

### 環境變數

```bash
# ~/.bashrc 或 ~/.zshrc

# 指定本地 spec-kit 倉庫路徑（方案 B/C）
export SPEC_KIT_PATH="$HOME/github/spec-kit"

# 設定預設代理
export SPECKIT_DEFAULT_AGENT="claude"

# 啟用詳細日誌
export SPECKIT_VERBOSE=1
```

### 專案配置

```bash
# .speckit-sync-config.json

{
  "version": "2.0.0",
  "source": {
    "repo": "github/spec-kit",
    "branch": "main",
    "local_path": "/Users/user/github/spec-kit",  # 可選
    "last_fetch": "2025-10-16T12:00:00Z"
  },
  "sync_strategy": "auto",  # auto|local|remote
  "agents": { ... }
}
```

## 疑難排解

### 問題 1: jq 不可用

```bash
# macOS
brew install jq

# Ubuntu/Debian
sudo apt-get install jq

# Alpine Linux
apk add jq
```

### 問題 2: 權限錯誤

```bash
chmod +x speckit-sync
```

### 問題 3: 配置檔案損壞

```bash
# 刪除並重新初始化
rm .speckit-sync-config.json
speckit-sync init
```

### 問題 4: 網路下載失敗

```bash
# 設定本地倉庫
export SPEC_KIT_PATH="/path/to/spec-kit"
speckit-sync update
```

## 後續發展方向

### 階段 3（效能優化）

1. **並行同步**
   ```bash
   # 使用 GNU parallel 同時同步多個代理
   sync_all_agents_parallel() {
       printf '%s\n' "${enabled_agents[@]}" | \
           parallel -j 4 sync_single_agent
   }
   ```

2. **增量同步**
   - 只下載變更的檔案
   - 使用 checksum 快速比對

3. **快取機制**
   - 快取已下載的檔案
   - 減少重複下載

### 階段 4（進階功能）

1. **命令版本管理**
   - 追蹤每個命令的版本
   - 支援回滾到舊版本

2. **自訂命令範本**
   - 允許使用者建立自己的命令範本
   - 共享自訂命令到社群

3. **代理插件系統**
   - 支援第三方代理
   - 動態載入代理配置

---

**文檔版本**: 1.0.0
**最後更新**: 2025-10-16
**作者**: Claude Code
