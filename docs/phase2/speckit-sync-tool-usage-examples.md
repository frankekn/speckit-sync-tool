# speckit-sync 使用範例與輸出示範

## 安裝

```bash
# 1. 將 speckit-sync 加入 PATH
cp speckit-sync /usr/local/bin/
# 或建立符號連結
ln -s "$(pwd)/speckit-sync" /usr/local/bin/speckit-sync

# 2. 驗證安裝
speckit-sync version
```

## 使用流程

### 1. 初始化配置

```bash
$ speckit-sync init

━━━ 🚀 初始化 speckit-sync 配置 ━━━

━━━ 🤖 檢測 AI 代理 ━━━
━━━ 🔍 掃描專案目錄 ━━━
  ✓ Claude Code (.claude/commands)
  ✓ Cursor (.cursor/commands)
  ✗ GitHub Copilot (.github/prompts) - 目錄不存在
  ✗ Gemini CLI (.gemini/commands) - 目錄不存在
  ✗ Qwen Code (.qwen/commands) - 目錄不存在
  ✗ opencode (.opencode/commands) - 目錄不存在
  ✗ Codex CLI (.codex/commands) - 目錄不存在
  ✗ Windsurf (.windsurf/workflows) - 目錄不存在
  ✗ Kilo Code (.kilocode/commands) - 目錄不存在
  ✗ Auggie CLI (.augment/commands) - 目錄不存在
  ✗ CodeBuddy CLI (.codebuddy/commands) - 目錄不存在
  ✗ Roo Code (.roo/commands) - 目錄不存在
  ✗ Amazon Q Developer CLI (.amazonq/commands) - 目錄不存在

ℹ 檢測到 2 個代理

ℹ 檢測到以下 AI 代理：
  1. ✓ Claude Code (.claude/commands)
  2. ✓ Cursor (.cursor/commands)

選擇要啟用的代理（空格分隔數字，Enter 全選）: 1 2

ℹ 已選擇所有檢測到的代理

━━━ 📝 建立配置檔案 ━━━
✓ 建立基礎配置
✓ 已初始化 Claude Code 配置
✓ 已初始化 Cursor 配置

✓ 初始化完成！
ℹ 配置檔案: /path/to/project/.speckit-sync-config.json
ℹ 已啟用 2 個代理：
  - Claude Code
  - Cursor

ℹ 下一步：
  1. 執行 'speckit-sync update' 同步命令
  2. 執行 'speckit-sync check' 查看狀態
```

### 2. 檢測代理（不初始化）

```bash
$ speckit-sync detect-agents

━━━ 🔍 掃描專案目錄 ━━━
  ✓ Claude Code (.claude/commands)
  ✓ Cursor (.cursor/commands)
  ✗ GitHub Copilot (.github/prompts) - 目錄不存在

ℹ 檢測到 2 個代理
```

### 3. 檢查同步狀態

#### 檢查所有代理

```bash
$ speckit-sync check

━━━ 🔍 檢查所有代理 ━━━

━━━ 🔍 檢查 Claude Code ━━━
  目錄: .claude/commands
  狀態: 已同步
  最後同步: 2025-10-16T12:00:00Z
  命令統計:
    - 標準命令: 8 個
    - 已同步: 4 個
    - 自訂: 0 個
    - 已客製化: 0 個
    - 可更新: 4 個

━━━ 🔍 檢查 Cursor ━━━
  目錄: .cursor/commands
  狀態: 已同步
  最後同步: 2025-10-16T11:30:00Z
  命令統計:
    - 標準命令: 8 個
    - 已同步: 3 個
    - 自訂: 1 個
    - 已客製化: 0 個
    - 可更新: 5 個
```

#### 檢查特定代理

```bash
$ speckit-sync check --agent claude

━━━ 🔍 檢查 Claude Code ━━━
  目錄: .claude/commands
  狀態: 已同步
  最後同步: 2025-10-16T12:00:00Z
  命令統計:
    - 標準命令: 8 個
    - 已同步: 4 個
    - 自訂: 0 個
    - 已客製化: 0 個
    - 可更新: 4 個
```

### 4. 更新命令

#### 更新所有代理

```bash
$ speckit-sync update

━━━ 🔄 同步所有代理 ━━━

ℹ 同步 Claude Code (.claude/commands)
    ✓ specify.md (synced)
    ✓ plan.md (synced)
    ✓ tasks.md (synced)
    ✓ implement.md (synced)

✓ 同步完成: 4 成功, 0 跳過, 0 失敗

ℹ 同步 Cursor (.cursor/commands)
    ✓ specify.md (synced)
    ! custom-command.md (customized - skipped)
    ✓ plan.md (synced)
    ✓ tasks.md (synced)

✓ 同步完成: 3 成功, 1 跳過, 0 失敗

━━━ 📊 同步摘要 ━━━
  總計: 2 個代理
  成功: 2 個
  失敗: 0 個
```

#### 更新特定代理

```bash
$ speckit-sync update --agent cursor

━━━ 🔄 更新 Cursor ━━━
ℹ 同步 Cursor (.cursor/commands)
    ✓ specify.md (synced)
    ! custom-command.md (customized - skipped)
    ✓ plan.md (synced)
    ✓ tasks.md (synced)

✓ 同步完成: 3 成功, 1 跳過, 0 失敗
```

#### 明確更新所有代理

```bash
$ speckit-sync update --agent all

━━━ 🔄 同步所有代理 ━━━
# ... 同 speckit-sync update
```

### 5. 版本資訊

```bash
$ speckit-sync version
speckit-sync version 2.0.0
```

### 6. 說明文件

```bash
$ speckit-sync help

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
```

## 配置檔案範例

### 初始化後的配置 (.speckit-sync-config.json)

```json
{
  "version": "2.0.0",
  "source": {
    "repo": "github/spec-kit",
    "branch": "main",
    "last_fetch": null
  },
  "agents": {
    "claude": {
      "enabled": true,
      "commands_dir": ".claude/commands",
      "commands": {
        "standard": [
          "specify.md",
          "plan.md",
          "tasks.md",
          "implement.md",
          "constitution.md",
          "clarify.md",
          "analyze.md",
          "checklist.md"
        ],
        "custom": [],
        "synced": [],
        "customized": []
      },
      "last_sync": null
    },
    "cursor": {
      "enabled": true,
      "commands_dir": ".cursor/commands",
      "commands": {
        "standard": [
          "specify.md",
          "plan.md",
          "tasks.md",
          "implement.md",
          "constitution.md",
          "clarify.md",
          "analyze.md",
          "checklist.md"
        ],
        "custom": [],
        "synced": [],
        "customized": []
      },
      "last_sync": null
    }
  },
  "known_commands": [
    "specify.md",
    "plan.md",
    "tasks.md",
    "implement.md",
    "constitution.md",
    "clarify.md",
    "analyze.md",
    "checklist.md"
  ]
}
```

### 同步後的配置

```json
{
  "version": "2.0.0",
  "source": {
    "repo": "github/spec-kit",
    "branch": "main",
    "last_fetch": "2025-10-16T12:05:00Z"
  },
  "agents": {
    "claude": {
      "enabled": true,
      "commands_dir": ".claude/commands",
      "commands": {
        "standard": [
          "specify.md",
          "plan.md",
          "tasks.md",
          "implement.md",
          "constitution.md",
          "clarify.md",
          "analyze.md",
          "checklist.md"
        ],
        "custom": [],
        "synced": [
          "specify.md",
          "plan.md",
          "tasks.md",
          "implement.md"
        ],
        "customized": []
      },
      "last_sync": "2025-10-16T12:00:00Z"
    },
    "cursor": {
      "enabled": true,
      "commands_dir": ".cursor/commands",
      "commands": {
        "standard": [
          "specify.md",
          "plan.md",
          "tasks.md",
          "implement.md",
          "constitution.md",
          "clarify.md",
          "analyze.md",
          "checklist.md"
        ],
        "custom": ["custom-command.md"],
        "synced": [
          "specify.md",
          "plan.md",
          "tasks.md"
        ],
        "customized": []
      },
      "last_sync": "2025-10-16T11:30:00Z"
    }
  },
  "known_commands": [
    "specify.md",
    "plan.md",
    "tasks.md",
    "implement.md",
    "constitution.md",
    "clarify.md",
    "analyze.md",
    "checklist.md"
  ]
}
```

## 升級配置範例

### 從 v1.0.0 升級

```bash
$ speckit-sync init

━━━ 🚀 初始化 speckit-sync 配置 ━━━
⚠ 檢測到現有配置 (v1.0.0)
是否要升級配置？[y/N] y

━━━ 🔄 升級配置檔案到 v2.0.0 ━━━
ℹ 已備份舊配置: .speckit-sync-config.json.v1.backup.20251016_120000
ℹ 從 v1.0.0 升級到 v2.0.0...
ℹ 遷移 Claude 配置...
✓ Claude 配置已遷移
ℹ 自動檢測其他代理...

━━━ 🔍 掃描專案目錄 ━━━
  ✓ Claude Code (.claude/commands)
  ✓ Cursor (.cursor/commands)

ℹ 檢測到 2 個代理
ℹ 檢測到 Cursor，正在初始化...
✓ 已初始化 Cursor 配置
✓ 配置升級完成！
```

## 錯誤處理範例

### 1. 未初始化

```bash
$ speckit-sync check
✗ 配置檔案不存在，請先執行 'speckit-sync init'
```

### 2. 未知代理

```bash
$ speckit-sync check --agent unknown
✗ 未知的代理: unknown
ℹ 可用代理: claude copilot gemini cursor qwen opencode codex windsurf kilocode auggie codebuddy roo q
```

### 3. 未檢測到代理

```bash
$ speckit-sync init

━━━ 🚀 初始化 speckit-sync 配置 ━━━

━━━ 🤖 檢測 AI 代理 ━━━
━━━ 🔍 掃描專案目錄 ━━━
  ✗ Claude Code (.claude/commands) - 目錄不存在
  ✗ Cursor (.cursor/commands) - 目錄不存在
  # ... 其他代理 ...

⚠ 未檢測到任何 AI 代理目錄
ℹ 提示：請先安裝至少一個 AI 代理並初始化專案
✗ 未檢測到任何代理，無法初始化
```

### 4. 缺少依賴

```bash
$ speckit-sync init
✗ 缺少必要工具: jq
ℹ 請安裝：
  - jq
```

## 進階使用情境

### 情境 1：多專案管理

```bash
# 專案 A
cd /path/to/project-a
speckit-sync init
speckit-sync update --agent claude

# 專案 B
cd /path/to/project-b
speckit-sync init
speckit-sync update --agent cursor
```

### 情境 2：選擇性同步

```bash
# 只啟用 Claude 和 Cursor
speckit-sync init
# 選擇: 1 2

# 稍後只更新 Claude
speckit-sync update --agent claude
```

### 情境 3：定期同步

```bash
# 設定 cron job 每天同步
0 9 * * * cd /path/to/project && /usr/local/bin/speckit-sync update
```

## 最佳實踐

1. **初始化後立即同步**
   ```bash
   speckit-sync init && speckit-sync update
   ```

2. **定期檢查狀態**
   ```bash
   speckit-sync check
   ```

3. **客製化命令前備份**
   ```bash
   cp .claude/commands/specify.md .claude/commands/specify.md.backup
   # 修改 specify.md
   ```

4. **版本控制配置檔案**
   ```bash
   git add .speckit-sync-config.json
   git commit -m "chore: update speckit-sync config"
   ```

---

**文檔版本**: 1.0.0
**最後更新**: 2025-10-16
