# Spec-Kit Sync Tool

自動同步 [GitHub spec-kit](https://github.com/github/spec-kit) 命令到多個專案的工具集。

> **注意**：這是一個獨立的同步工具，不隸屬於官方 spec-kit 專案。

## 🎯 為什麼需要這個工具？

當你有多個專案使用 spec-kit 的命令時，手動更新每個專案非常麻煩。這個工具可以：

- ✅ **自動更新 spec-kit**：每次同步時自動檢查並拉取最新版本
- ✅ 自動檢測哪些命令需要更新
- ✅ 批次同步多個專案
- ✅ 保護自訂命令不被覆蓋
- ✅ 自動備份，安全回滾
- ✅ 清晰的差異顯示

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

### 單一專案同步

```bash
# 1. 進入你的專案
cd ~/Documents/GitHub/my-project

# 2. 初始化（第一次使用）
~/Documents/GitHub/speckit-sync-tool/sync-commands.sh init

# 3. 檢查更新（會自動更新 spec-kit 倉庫）
~/Documents/GitHub/speckit-sync-tool/sync-commands.sh check

# 4. 執行同步（會自動更新 spec-kit 倉庫）
~/Documents/GitHub/speckit-sync-tool/sync-commands.sh update
```

> **💡 提示**：每次執行 `check` 或 `update` 時，工具會自動檢查 spec-kit 是否有新版本，並自動執行 `git pull`。你不需要手動更新！

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

## 📚 使用方式

### 命令列表

#### `sync-commands.sh` - 主要同步工具

```bash
./sync-commands.sh init      # 初始化同步配置
./sync-commands.sh check     # 檢查哪些命令需要更新
./sync-commands.sh update    # 執行同步（自動備份）
./sync-commands.sh diff CMD  # 顯示指定命令的差異
./sync-commands.sh status    # 顯示當前同步狀態
```

#### `batch-sync-all.sh` - 批次處理工具

```bash
./batch-sync-all.sh           # 互動模式（逐個詢問）
./batch-sync-all.sh --auto    # 自動模式（不詢問）
./batch-sync-all.sh --check-only  # 僅檢查，不更新
```

### 環境變數

```bash
# 設定 spec-kit 路徑
export SPECKIT_PATH=/custom/path/to/spec-kit

# 設定 GitHub 目錄（批次處理用）
export GITHUB_DIR=/custom/path/to/github

# 設定命令目錄
export COMMANDS_DIR=.claude/commands
```

### 使用 Makefile 整合

將 Makefile 複製到專案：

```bash
cp ~/Documents/GitHub/speckit-sync-tool/Makefile.template my-project/.claude/Makefile
```

然後在專案中使用：

```bash
make -C .claude sync-check    # 檢查更新
make -C .claude sync-update   # 執行同步
make -C .claude sync-status   # 顯示狀態
make -C .claude sync-diff CMD=implement.md  # 查看差異
```

## 📖 詳細指南

### 初始化專案

第一次在專案中使用：

```bash
cd my-project
~/Documents/GitHub/speckit-sync-tool/sync-commands.sh init
```

這會：
1. 建立 `.claude/.speckit-sync.json` 配置檔案
2. 掃描現有命令
3. 記錄當前狀態

### 檢查更新

```bash
./sync-commands.sh check
```

輸出範例：
```
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
檢查 Spec-Kit 更新
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

📁 Spec-Kit 路徑: /Users/termtek/Documents/GitHub/spec-kit
📁 命令目錄: .claude/commands
🔖 Spec-Kit 版本: 0.0.20

✓ analyze.md - 已是最新
✓ checklist.md - 已是最新
⚠ implement.md - 有更新可用
⊕ tasks.md - 本地不存在（新命令）

📊 統計：
  ✅ 已同步: 6
  ⊕  缺少: 1
  ↻  過時: 1
  ═══════════
  📦 總計: 8

⚠ 發現 2 個命令需要更新
ℹ 執行 './sync-commands.sh update' 來更新
```

### 查看差異

```bash
./sync-commands.sh diff implement.md
```

會顯示本地版本與 spec-kit 版本的詳細差異。

### 執行同步

```bash
./sync-commands.sh update
```

輸出範例：
```
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
同步 Spec-Kit 命令
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

ℹ 📦 建立備份: .claude/commands/.backup/20251016_120000

✓ analyze.md - 已是最新，跳過
✓ implement.md - 已更新
⊕ tasks.md - 新增

━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
同步完成
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
  ⊕  新增: 1 個
  ↻  更新: 1 個
  ✓  跳過: 6 個
  📦 備份: .claude/commands/.backup/20251016_120000
```

### 批次處理多個專案

#### 互動模式

```bash
./batch-sync-all.sh
```

會逐個專案詢問是否更新。

#### 自動模式

```bash
./batch-sync-all.sh --auto
```

自動更新所有專案，不詢問。

#### 僅檢查模式

```bash
./batch-sync-all.sh --check-only
```

只顯示每個專案的狀態，不執行更新。

## ⚙️ 配置

### `.speckit-sync.json` 配置檔案

```json
{
  "version": "1.0.0",
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
  "commands": {
    "standard": [...],
    "custom": [...],
    "ignored": [...]
  },
  "metadata": {
    "project_name": "my-project",
    "initialized": "2025-10-16T11:36:00Z",
    "last_check": "2025-10-16T11:36:00Z",
    "total_syncs": 3
  }
}
```

### 同步模式

- **semi-auto** (推薦)：更新前檢查差異
- **manual**：完全手動控制
- **auto-update-standard**：自動更新標準命令

### 衝突處理

- **ask** (預設)：詢問使用者
- **keep-local**：保留本地版本
- **use-upstream**：使用 spec-kit 版本

## 💡 最佳實踐

### 1. 定期檢查更新

建議每週執行一次：

```bash
cd ~/Documents/GitHub
./speckit-sync-tool/batch-sync-all.sh --check-only
```

### 2. 保護自訂命令

如果你有自訂命令，在配置中標記：

```json
{
  "commands": {
    "custom": [
      "norsk-plan.md",
      "optimize-article-smart.md"
    ]
  }
}
```

### 3. 處理客製化標準命令

如果你修改了標準命令（如 `implement.md`）：

```bash
# 1. 查看你的修改與新版本的差異
./sync-commands.sh diff implement.md

# 2. 決定是否更新
#    - 接受新版本：直接 update
#    - 保留修改：在配置中標記為 customized
```

### 4. 使用備份回滾

如果更新後有問題：

```bash
# 備份位置
ls .claude/commands/.backup/

# 回滾（手動複製）
cp .claude/commands/.backup/20251016_120000/*.md .claude/commands/
```

### 5. 批次處理客製化

編輯 `batch-sync-all.sh`，指定要處理的專案：

```bash
PROJECTS=(
    "bni-system"
    "article_writing"
    "mehmo_edu"
)
```

## 🔧 進階使用

### 自訂 spec-kit 路徑

```bash
SPECKIT_PATH=/custom/path/to/spec-kit ./sync-commands.sh check
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
          SPECKIT_PATH=/tmp/spec-kit ./sync-commands.sh check
```

### 自動化腳本

建立 cron job：

```bash
# 每週一檢查更新
crontab -e

# 添加
0 9 * * 1 cd ~/Documents/GitHub && ./speckit-sync-tool/batch-sync-all.sh --check-only > /tmp/speckit-sync.log 2>&1
```

## 📊 專案結構

```
speckit-sync-tool/
├── sync-commands.sh          # 主要同步腳本
├── batch-sync-all.sh         # 批次處理腳本
├── install.sh                # 全局安裝腳本
├── Makefile.template         # Makefile 範本
├── .speckit-sync.json.template  # 配置檔案範本
└── README.md                 # 本文檔
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

### 問題 2：權限錯誤

**解決方法**：

```bash
chmod +x ~/Documents/GitHub/speckit-sync-tool/*.sh
```

### 問題 3：批次處理找不到專案

**解決方法**：

在 `batch-sync-all.sh` 中手動指定專案：

```bash
PROJECTS=(
    "project1"
    "project2"
)
```

## 🤝 貢獻

歡迎提交 Issue 和 Pull Request！

## 📄 授權

MIT License

## 🔗 相關連結

- [GitHub spec-kit](https://github.com/github/spec-kit) - 官方 spec-kit 專案
- [Spec-Driven Development](https://github.com/github/spec-kit/blob/main/spec-driven.md) - 方法論說明

## 📝 更新日誌

### v1.0.0 (2025-10-16)

- ✨ 初始版本
- ✅ 單一專案同步
- ✅ 批次處理多專案
- ✅ 自動備份和回滾
- ✅ 差異顯示
- ✅ 全局安裝支援
- ✅ Makefile 整合

## ❓ FAQ

**Q: 這個工具會修改 spec-kit 本身嗎？**
A: 不會。這個工具只會讀取 spec-kit 的命令檔案，不會修改它。

**Q: 我的自訂命令會被覆蓋嗎？**
A: 不會。工具只會同步 8 個標準命令，你的自訂命令完全安全。

**Q: 如果我修改了標準命令怎麼辦？**
A: 工具會偵測到差異，你可以選擇保留修改或接受新版本。建議在配置中標記為 "customized"。

**Q: 可以鎖定特定版本嗎？**
A: 目前不支援版本鎖定，但你可以不執行 update 來保持當前版本。

**Q: 支援 Windows 嗎？**
A: 支援。在 Git Bash 或 WSL 中執行即可。

---

Made with ❤️ for easier spec-kit management
