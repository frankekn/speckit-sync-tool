# Spec-Kit Sync Tool

自動同步 [GitHub spec-kit](https://github.com/github/spec-kit) 命令與模版到多個專案的整合工具。

> **注意**：這是一個獨立的同步工具，不隸屬於官方 spec-kit 專案。

## ✨ 核心功能

### 🚀 Phase 1: 動態命令掃描
- ✅ **自動發現新命令**：不再寫死命令列表，自動偵測 spec-kit 的新命令
- ✅ **互動式選擇**：發現新命令時可選擇是否加入同步
- ✅ **命令描述解析**：從 YAML frontmatter 自動提取命令描述

### 🤖 Phase 2: 多代理支援
- ✅ **13 種 AI 代理**：支援 Claude, Cursor, Copilot, Gemini, Windsurf 等
- ✅ **自動偵測**：掃描專案中已安裝的代理
- ✅ **獨立狀態管理**：每個代理獨立追蹤同步狀態
- ✅ **批次或單獨更新**：可一次更新所有代理或指定特定代理

### 📄 Phase 3: 模版同步
- ✅ **spec-kit 模版支援**：同步官方模版檔案
- ✅ **選擇性同步**：互動式選擇要同步的模版
- ✅ **獨立管理**：模版與命令分開管理

### 🔄 通用功能
- ✅ **自動更新 spec-kit**：每次同步前自動檢查並更新 spec-kit 倉庫
- ✅ **自動備份**：更新前自動備份，支援回滾
- ✅ **配置自動升級**：v1.0.0 → v2.1.0 自動遷移
- ✅ **批次處理**：一次處理多個專案

## 🎯 為什麼需要這個工具？

當你有多個專案使用 spec-kit 的命令時，手動更新每個專案非常麻煩。這個工具可以：

- **自動同步**：spec-kit 更新時自動偵測並同步到所有專案
- **多代理支援**：同時管理 Claude、Cursor、Copilot 等多種 AI 代理
- **安全可靠**：自動備份、差異顯示、保護自訂命令
- **批次操作**：一次處理多個專案，省時省力

## 📦 安裝

### 方式 1：Git Clone（推薦）

```bash
# Clone 此倉庫
cd ~/Documents/GitHub
git clone https://github.com/your-username/speckit-sync-tool.git

# 全局安裝（可選）
cd speckit-sync-tool
./install.sh
```

### 方式 2：直接下載

下載這個倉庫的 zip 檔案並解壓到任意位置。

## 🚀 快速開始

### 使用整合版本（推薦，包含所有功能）

```bash
# 1. 進入你的專案
cd ~/Documents/GitHub/my-project

# 2. 初始化（會自動偵測代理）
~/Documents/GitHub/speckit-sync-tool/sync-commands-integrated.sh init

# 3. 檢查更新
~/Documents/GitHub/speckit-sync-tool/sync-commands-integrated.sh check

# 4. 執行同步
~/Documents/GitHub/speckit-sync-tool/sync-commands-integrated.sh update

# 5. 選擇並同步模版（可選）
~/Documents/GitHub/speckit-sync-tool/sync-commands-integrated.sh templates select
~/Documents/GitHub/speckit-sync-tool/sync-commands-integrated.sh templates sync
```

### 使用基礎版本（僅 Claude）

```bash
# 如果只需要同步 Claude 的命令
~/Documents/GitHub/speckit-sync-tool/sync-commands.sh init
~/Documents/GitHub/speckit-sync-tool/sync-commands.sh check
~/Documents/GitHub/speckit-sync-tool/sync-commands.sh update
```

### 批次同步多個專案

```bash
# 自動掃描並同步所有專案
~/Documents/GitHub/speckit-sync-tool/batch-sync-all.sh

# 或自動模式（不詢問）
~/Documents/GitHub/speckit-sync-tool/batch-sync-all.sh --auto
```

### 使用全局命令（需先安裝）

```bash
# 任何專案目錄都可以使用
cd ~/Documents/GitHub/any-project
speckit-sync init
speckit-sync check
speckit-sync update
```

> **💡 提示**：每次執行 `check` 或 `update` 時，工具會自動檢查 spec-kit 是否有新版本，並自動執行 `git pull`。你不需要手動更新！

## 📚 完整功能指南

### 整合版命令列表

#### 基礎命令

```bash
# 初始化配置（會偵測所有代理）
./sync-commands-integrated.sh init

# 偵測可用的 AI 代理
./sync-commands-integrated.sh detect-agents

# 檢查所有代理的更新
./sync-commands-integrated.sh check

# 檢查特定代理
./sync-commands-integrated.sh check --agent claude

# 更新所有代理
./sync-commands-integrated.sh update

# 更新特定代理
./sync-commands-integrated.sh update --agent cursor

# 顯示配置狀態
./sync-commands-integrated.sh status
```

#### 動態命令掃描

```bash
# 掃描並添加新命令（需指定代理）
./sync-commands-integrated.sh scan --agent claude
```

#### 模版管理

```bash
# 列出可用模版
./sync-commands-integrated.sh templates list

# 選擇要同步的模版
./sync-commands-integrated.sh templates select

# 同步已選擇的模版
./sync-commands-integrated.sh templates sync
```

#### 配置管理

```bash
# 升級配置檔案版本
./sync-commands-integrated.sh upgrade
```

### 支援的 AI 代理

| 代理名稱 | 命令目錄 | 偵測方式 |
|---------|---------|---------|
| Claude Code | `.claude/commands` | 自動 |
| Cursor | `.cursor/commands` | 自動 |
| GitHub Copilot | `.github/prompts` | 自動 |
| Gemini CLI | `.gemini/commands` | 自動 |
| Windsurf | `.windsurf/workflows` | 自動 |
| Qwen Code | `.qwen/commands` | 自動 |
| opencode | `.opencode/commands` | 自動 |
| Codex CLI | `.codex/commands` | 自動 |
| Kilo Code | `.kilocode/commands` | 自動 |
| Auggie CLI | `.augment/commands` | 自動 |
| CodeBuddy CLI | `.codebuddy/commands` | 自動 |
| Roo Code | `.roo/commands` | 自動 |
| Amazon Q | `.amazonq/commands` | 自動 |

### 環境變數

```bash
# 設定 spec-kit 路徑
export SPECKIT_PATH=/custom/path/to/spec-kit

# 設定 GitHub 目錄（批次處理用）
export GITHUB_DIR=/custom/path/to/github
```

## 📖 詳細使用範例

### 情境 1：新專案初始化

```bash
cd my-new-project

# 初始化配置，工具會自動偵測專案中的代理
~/speckit-sync-tool/sync-commands-integrated.sh init

# 輸出：
# 偵測 AI 代理
# ✓ Claude Code (.claude/commands)
# ✓ Cursor (.cursor/commands)
#
# 選擇要啟用的代理（空格鍵選擇，Enter 確認）：
# [1] Claude Code (.claude/commands) [Y/n] y
# [2] Cursor (.cursor/commands) [Y/n] y
#
# 偵測到 8 個標準命令
# ✓ 初始化完成！
```

### 情境 2：定期更新檢查

```bash
# 檢查所有代理的更新
./sync-commands-integrated.sh check

# 輸出：
# 檢查 Claude Code 更新
# ℹ spec-kit 已是最新版本 (0.0.20)
#
# ✓ analyze.md - 已是最新
# ✓ checklist.md - 已是最新
# ↻ implement.md - 有更新可用
# ⊕ new-command.md - 本地不存在（新命令）
#
# 統計：
#   ✅ 已同步: 6
#   ⊕  缺少: 1
#   ↻  過時: 1
#
# ⚠ 發現 2 個命令需要更新
```

### 情境 3：掃描新命令

```bash
# 掃描 spec-kit 中的新命令
./sync-commands-integrated.sh scan --agent claude

# 輸出：
# 掃描新命令 (claude)
# ℹ 發現 2 個新命令：
#   ⊕ refactor.md - 程式碼重構
#   ⊕ review.md - 程式碼審查
#
# 是否要將這些新命令加入同步列表？[y/N] y
# ✓ 已添加 2 個新命令到配置
```

### 情境 4：模版同步

```bash
# 列出可用模版
./sync-commands-integrated.sh templates list

# 輸出：
# 可用模版列表
#
# [ 1]   spec-template.md
# [ 2]   plan-template.md
# [ 3]   tasks-template.md
# [ 4] ✓ checklist-template.md

# 選擇要同步的模版
./sync-commands-integrated.sh templates select

# 同步已選擇的模版
./sync-commands-integrated.sh templates sync
# ✓ spec-template.md - 已同步
# ✓ plan-template.md - 已同步
# ✓ 共同步 2 個模版到 .claude/templates
```

### 情境 5：多代理管理

```bash
# 只更新 Claude 代理
./sync-commands-integrated.sh update --agent claude

# 更新所有啟用的代理
./sync-commands-integrated.sh update

# 輸出：
# 同步 Claude Code 命令
# ... (Claude 同步結果)
#
# 同步 Cursor 命令
# ... (Cursor 同步結果)
```

## ⚙️ 配置檔案

### v2.1.0 配置結構（整合版）

```json
{
  "version": "2.1.0",
  "source": {
    "type": "local",
    "path": "/path/to/spec-kit",
    "version": "0.0.20"
  },
  "strategy": {
    "mode": "semi-auto",
    "on_conflict": "ask",
    "auto_backup": true,
    "backup_retention": 5
  },
  "agents": {
    "claude": {
      "enabled": true,
      "commands_dir": ".claude/commands",
      "commands": {
        "standard": ["specify.md", "plan.md", "tasks.md", ...],
        "custom": ["my-command.md"],
        "synced": [],
        "customized": []
      }
    },
    "cursor": {
      "enabled": true,
      "commands_dir": ".cursor/commands",
      "commands": {...}
    }
  },
  "templates": {
    "enabled": true,
    "sync_dir": ".claude/templates",
    "selected": ["spec-template.md", "plan-template.md"],
    "last_sync": "2025-10-16T12:30:00Z"
  },
  "metadata": {
    "project_name": "my-project",
    "initialized": "2025-10-16T11:36:00Z",
    "last_check": "2025-10-16T12:00:00Z",
    "total_syncs": 3
  }
}
```

### 配置版本升級路徑

工具會自動升級配置版本，無需手動操作：

```
v1.0.0 (基礎版)
  ↓
v1.1.0 (+ 動態掃描)
  ↓
v2.0.0 (+ 多代理)
  ↓
v2.1.0 (+ 模版)
```

## 💡 最佳實踐

### 1. 使用整合版本

```bash
# 推薦使用整合版本，獲得所有功能
ln -s ~/Documents/GitHub/speckit-sync-tool/sync-commands-integrated.sh ~/bin/speckit-sync
```

### 2. 定期檢查更新

```bash
# 建議每週執行一次
cd ~/Documents/GitHub
./speckit-sync-tool/batch-sync-all.sh --check-only
```

### 3. 保護自訂命令

在配置中標記你的自訂命令：

```json
{
  "agents": {
    "claude": {
      "commands": {
        "custom": [
          "my-special-command.md",
          "project-specific-task.md"
        ]
      }
    }
  }
}
```

### 4. 多代理同步策略

```bash
# 方案A：所有代理使用相同命令（推薦）
./sync-commands-integrated.sh update

# 方案B：不同代理獨立管理
./sync-commands-integrated.sh update --agent claude
./sync-commands-integrated.sh update --agent cursor
```

### 5. 模版管理

```bash
# 只同步你需要的模版
./sync-commands-integrated.sh templates select
# 選擇 spec-template.md 和 plan-template.md

# 需要時再同步
./sync-commands-integrated.sh templates sync
```

### 6. 備份與回滾

```bash
# 備份位置（每次更新自動建立）
ls .claude/commands/.backup/

# 回滾到特定版本
cp .claude/commands/.backup/20251016_120000/*.md .claude/commands/
```

## 📊 專案結構

```
speckit-sync-tool/
├── sync-commands-integrated.sh  # 整合版 v2.1.0（推薦）
├── sync-commands-enhanced.sh    # Phase 1 版本 v1.1.0
├── sync-commands-v2.sh          # Phase 2 版本 v2.0.0
├── template-sync.sh             # Phase 3 版本 v2.1.0
├── sync-commands.sh             # 基礎版本 v1.0.0
├── batch-sync-all.sh            # 批次處理工具
├── install.sh                   # 全局安裝腳本
├── test-phase1.sh               # Phase 1 測試套件
├── .speckit-sync.json.template  # 配置檔案範本
├── Makefile.template            # Makefile 範本
├── LICENSE                      # MIT 授權
├── README.md                    # 本文檔
├── DELIVERY_SUMMARY.md          # 交付檔案總覽
└── docs/
    ├── phase1/                  # Phase 1 文檔
    │   ├── QUICKSTART_v1.1.md
    │   ├── PHASE1_SUMMARY.md
    │   └── ...
    ├── phase2/                  # Phase 2 文檔
    │   ├── speckit-sync-tool-phase2-architecture.md
    │   └── ...
    └── phase3/                  # Phase 3 文檔
        ├── README.template-sync.md
        └── ...
```

## 🔧 進階使用

### 自訂 spec-kit 路徑

```bash
SPECKIT_PATH=/custom/path/to/spec-kit ./sync-commands-integrated.sh check
```

### 整合到 CI/CD

```yaml
# .github/workflows/sync-speckit.yml
name: Sync Spec-Kit Commands

on:
  schedule:
    - cron: '0 9 * * 1'  # 每週一早上 9:00
  workflow_dispatch:

jobs:
  sync:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v3

      - name: Check spec-kit updates
        run: |
          git clone https://github.com/github/spec-kit.git /tmp/spec-kit
          SPECKIT_PATH=/tmp/spec-kit ./sync-commands-integrated.sh check
```

### 使用 Makefile 整合

```bash
# 複製 Makefile 範本
cp ~/Documents/GitHub/speckit-sync-tool/Makefile.template my-project/.claude/Makefile

# 在專案中使用
make -C .claude sync-check
make -C .claude sync-update
make -C .claude sync-status
```

## 🐛 故障排除

### 問題 1：找不到 spec-kit

```
✗ spec-kit 路徑無效: /Users/termtek/Documents/GitHub/spec-kit
```

**解決方法**：

```bash
# 檢查 spec-kit 是否存在
ls ~/Documents/GitHub/spec-kit

# 設定正確的路徑
export SPECKIT_PATH=/correct/path/to/spec-kit
```

### 問題 2：未偵測到代理

```
✗ 未偵測到任何 AI 代理目錄
```

**解決方法**：

```bash
# 確保專案中有代理目錄
mkdir -p .claude/commands
# 或
mkdir -p .cursor/commands
```

### 問題 3：權限錯誤

**解決方法**：

```bash
chmod +x ~/Documents/GitHub/speckit-sync-tool/*.sh
```

### 問題 4：配置版本過舊

**解決方法**：

```bash
# 自動升級配置
./sync-commands-integrated.sh upgrade
```

### 問題 5：模版同步失敗

**解決方法**：

```bash
# 檢查 spec-kit 是否有 templates 目錄
ls $SPECKIT_PATH/templates

# 如果沒有，spec-kit 可能尚未支援模版功能
```

## ❓ FAQ

**Q: 這個工具會修改 spec-kit 本身嗎？**
A: 不會。這個工具只會讀取 spec-kit 的命令檔案，並自動更新（git pull）spec-kit 倉庫到最新版本。

**Q: 我的自訂命令會被覆蓋嗎？**
A: 不會。工具只會同步標準命令（來自 spec-kit 的命令），你的自訂命令完全安全。可以在配置中標記為 "custom" 以明確區分。

**Q: 如果我修改了標準命令怎麼辦？**
A: 工具會偵測到差異並顯示為"過時"狀態。你可以：
- 接受新版本：執行 update（會覆蓋你的修改）
- 保留修改：在配置中標記為 "customized"

**Q: 支援哪些 AI 代理？**
A: 目前支援 13 種：Claude Code, Cursor, GitHub Copilot, Gemini, Windsurf, Qwen, opencode, Codex, Kilocode, Auggie, CodeBuddy, Roo, Amazon Q。

**Q: 可以同時使用多個代理嗎？**
A: 可以！整合版本支援在同一專案中管理多個代理，每個代理獨立追蹤同步狀態。

**Q: spec-kit 新增命令後會自動偵測嗎？**
A: 會！使用 `scan` 命令可以掃描 spec-kit 中的新命令，並互動式選擇是否加入同步列表。

**Q: 模版功能是什麼？**
A: 模版功能可以同步 spec-kit 的模版檔案（如 spec-template.md），讓你在建立新文檔時有標準格式可以參考。

**Q: 可以鎖定特定版本嗎？**
A: 目前不支援版本鎖定，但你可以不執行 update 來保持當前版本。spec-kit 會自動更新到最新版本。

**Q: 支援 Windows 嗎？**
A: 支援。在 Git Bash 或 WSL 中執行即可。

**Q: 應該使用哪個版本？**
A: 建議使用 `sync-commands-integrated.sh`（整合版），它包含所有功能。如果只需要基礎功能，可以使用 `sync-commands.sh`。

## 🤝 貢獻

歡迎提交 Issue 和 Pull Request！

## 📄 授權

MIT License

## 🔗 相關連結

- [GitHub spec-kit](https://github.com/github/spec-kit) - 官方 spec-kit 專案
- [Spec-Driven Development](https://github.com/github/spec-kit/blob/main/spec-driven.md) - 方法論說明

## 📝 更新日誌

### v2.1.0 (2025-10-16) - 整合版本

- ✨ **整合所有功能**：將三個階段合併為單一工具
- ✅ 動態命令掃描（Phase 1）
- ✅ 13 種 AI 代理支援（Phase 2）
- ✅ 模版同步功能（Phase 3）
- ✅ 配置自動升級 (v1.0.0 → v2.1.0)
- ✅ 統一 CLI 介面
- ✅ 完整文檔與範例

### v2.0.0 (2025-10-16) - Phase 2

- ✨ 多代理支援
- ✅ 13 種 AI 代理偵測與管理
- ✅ 獨立代理狀態追蹤
- ✅ 互動式代理選擇

### v1.1.0 (2025-10-16) - Phase 1

- ✨ 動態命令掃描
- ✅ 自動發現新命令
- ✅ 互動式新命令選擇
- ✅ 命令描述自動解析

### v1.0.0 (2025-10-16) - 初始版本

- ✨ 基礎功能實作
- ✅ 單一專案同步（Claude）
- ✅ 批次處理多專案
- ✅ 自動備份和回滾
- ✅ 差異顯示
- ✅ 自動更新 spec-kit
- ✅ 全局安裝支援

---

Made with ❤️ for easier spec-kit management across multiple AI coding agents
