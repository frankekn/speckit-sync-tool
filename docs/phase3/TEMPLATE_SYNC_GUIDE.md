# SpecKit Template Sync Tool 使用指南

## 概述

`speckit-sync-tool.sh` 是一個用於同步 spec-kit 模版檔案到專案目錄的工具。它提供了互動式選擇、批次同步、更新檢測等功能。

## 快速開始

### 1. 互動式同步

最簡單的使用方式，工具會引導你完成整個流程：

```bash
./speckit-sync-tool.sh sync
```

**互動流程：**

```
╔══════════════════════════════════════════════════════════╗
║          SpecKit Template Sync Tool v1.0.0          ║
╚══════════════════════════════════════════════════════════╝

▶ 可用模版 (6 個)

  [ ] 1. spec-template.md           - 功能規格模版 (3.9K)
  [ ] 2. plan-template.md           - 實作計劃模版 (3.6K)
  [ ] 3. tasks-template.md          - 任務清單模版 (9.2K)
  [ ] 4. checklist-template.md      - 檢查清單模版 (1.3K)
  [ ] 5. agent-file-template.md     - AI 代理上下文 (455B)
  [ ] 6. vscode-settings.json       - VS Code 設定 (351B)

選擇要同步的模版:
  • 輸入數字（空格分隔）: 1 3 5
  • 輸入範圍: 1-3
  • 全選: a 或 all
  • 取消: q 或 quit

請選擇 > a

同步到哪個目錄？
[預設: .claude/templates] >

▶ 同步模版到: .claude/templates

  + spec-template.md (已建立)
  + plan-template.md (已建立)
  + tasks-template.md (已建立)
  + checklist-template.md (已建立)
  + agent-file-template.md (已建立)
  + vscode-settings.json (已建立)

▶ 同步完成
  成功: 6

✓ 配置已儲存到 .speckit-sync.json
```

### 2. 同步所有模版

```bash
./speckit-sync-tool.sh sync --all
```

### 3. 同步特定模版

```bash
./speckit-sync-tool.sh sync --select spec-template.md,plan-template.md
```

### 4. 自訂目標目錄

```bash
./speckit-sync-tool.sh sync --all --to .speckit/templates
```

### 5. 預覽模式（不實際寫入）

```bash
./speckit-sync-tool.sh sync --all --dry-run
```

## 命令參考

### sync - 同步模版

```bash
./speckit-sync-tool.sh sync [選項]
```

**選項：**

| 選項 | 說明 |
|------|------|
| `-a, --all` | 同步所有模版 |
| `-s, --select NAMES` | 只同步特定模版（逗號分隔） |
| `-t, --to DIR` | 指定目標目錄 |
| `-n, --dry-run` | 預覽模式（不實際寫入） |
| `-h, --help` | 顯示說明 |

**範例：**

```bash
# 互動式選擇
./speckit-sync-tool.sh sync

# 同步所有模版到預設目錄
./speckit-sync-tool.sh sync --all

# 只同步規格和計劃模版
./speckit-sync-tool.sh sync --select spec-template.md,plan-template.md

# 同步到自訂目錄
./speckit-sync-tool.sh sync --all --to .my-templates

# 預覽不執行
./speckit-sync-tool.sh sync --all --dry-run
```

### check - 檢查更新

檢查本地模版是否有更新：

```bash
./speckit-sync-tool.sh check --include-templates
```

**輸出範例：**

```
╔══════════════════════════════════════════════════════════╗
║          SpecKit Template Sync Tool v1.0.0          ║
╚══════════════════════════════════════════════════════════╝

▶ 檢查模版更新

需要更新 (2):
  ⟳ spec-template.md
  ⟳ plan-template.md

尚未同步 (1):
  + agent-file-template.md

已是最新 (3):
  ✓ tasks-template.md
  ✓ checklist-template.md
  ✓ vscode-settings.json

執行以下命令更新:
  ./speckit-sync-tool.sh update --include-templates
```

### update - 更新模版

自動更新所有過時的模版：

```bash
./speckit-sync-tool.sh update --include-templates
```

**特性：**

- 自動偵測需要更新的模版
- 更新前自動備份舊檔案
- 備份檔名格式：`template.md.backup.20251016_120000`

### list - 列出模版

列出所有可用模版：

```bash
# 簡單列表
./speckit-sync-tool.sh list

# 詳細資訊
./speckit-sync-tool.sh list --details
```

**輸出範例：**

```
╔══════════════════════════════════════════════════════════╗
║          SpecKit Template Sync Tool v1.0.0          ║
╚══════════════════════════════════════════════════════════╝

▶ 可用模版

  spec-template.md           - 功能規格模版 (3.9K)
  plan-template.md           - 實作計劃模版 (3.6K)
  tasks-template.md          - 任務清單模版 (9.2K)
  checklist-template.md      - 檢查清單模版 (1.3K)
  agent-file-template.md     - AI 代理上下文 (455B)
  vscode-settings.json       - VS Code 設定 (351B)

總計: 6 個模版
```

### status - 顯示狀態

顯示當前同步狀態：

```bash
./speckit-sync-tool.sh status
```

**輸出範例：**

```
╔══════════════════════════════════════════════════════════╗
║          SpecKit Template Sync Tool v1.0.0          ║
╚══════════════════════════════════════════════════════════╝

▶ 同步狀態

  啟用狀態: 已啟用
  同步目錄: .claude/templates
  上次同步: 2025-10-16T12:00:00Z

▶ 已選擇的模版

  ✓ spec-template.md
  ✓ plan-template.md
  ✓ tasks-template.md
  ? checklist-template.md (檔案不存在)
```

### config - 管理配置

管理配置檔案：

```bash
# 顯示配置
./speckit-sync-tool.sh config show

# 編輯配置
./speckit-sync-tool.sh config edit

# 重置配置
./speckit-sync-tool.sh config reset
```

## 配置檔案

工具使用 `.speckit-sync.json` 儲存配置。

### 配置結構

```json
{
  "version": "1.0.0",
  "templates": {
    "enabled": true,
    "sync_dir": ".claude/templates",
    "selected": [
      "spec-template.md",
      "plan-template.md",
      "tasks-template.md"
    ],
    "last_sync": "2025-10-16T12:00:00Z"
  }
}
```

### 配置欄位

| 欄位 | 型別 | 說明 |
|------|------|------|
| `enabled` | boolean | 是否啟用模版同步 |
| `sync_dir` | string | 同步目標目錄 |
| `selected` | array | 已選擇的模版清單 |
| `last_sync` | string | 上次同步時間（ISO 8601） |

### 自訂配置

你可以手動編輯配置檔案：

```bash
# 使用預設編輯器
./speckit-sync-tool.sh config edit

# 或直接編輯
nano .speckit-sync.json
```

## 模版說明

### spec-template.md

功能規格模版，用於定義新功能的需求和使用者場景。

**內容包含：**
- 使用者場景與測試
- 功能需求
- 技術限制
- 成功標準

### plan-template.md

實作計劃模版，用於規劃功能實作的技術細節。

**內容包含：**
- 技術選型
- 架構設計
- 檔案結構
- 實作步驟

### tasks-template.md

任務清單模版，用於追蹤功能開發進度。

**內容包含：**
- 任務分解
- 進度追蹤
- 測試檢查點
- 文件更新

### checklist-template.md

檢查清單模版，用於確保功能品質。

**內容包含：**
- 程式碼品質檢查
- 測試完整性
- 文件完整性
- 安全性檢查

### agent-file-template.md

AI 代理上下文模版，用於提供專案開發指引。

**內容包含：**
- 技術棧資訊
- 專案結構
- 常用命令
- 程式碼風格

### vscode-settings.json

VS Code 專案設定，用於統一開發環境配置。

**內容包含：**
- 編輯器設定
- 格式化規則
- 延伸模組建議

## 使用場景

### 場景 1：新專案初始化

為新專案設定 spec-kit 模版：

```bash
# 在專案根目錄
cd /path/to/your/project

# 同步所有模版
/path/to/spec-kit/speckit-sync-tool.sh sync --all

# 驗證
ls -la .claude/templates/
```

### 場景 2：選擇性模版

只需要部分模版的專案：

```bash
# 只同步規格和計劃模版
./speckit-sync-tool.sh sync --select spec-template.md,plan-template.md

# 或使用互動式選擇
./speckit-sync-tool.sh sync
# 然後選擇: 1 2
```

### 場景 3：定期更新

定期檢查並更新模版：

```bash
# 每週或每月執行
./speckit-sync-tool.sh check --include-templates

# 如果有更新
./speckit-sync-tool.sh update --include-templates
```

### 場景 4：多專案管理

為多個專案同步到不同目錄：

```bash
# 專案 A
cd /path/to/project-a
./speckit-sync-tool.sh sync --all --to .claude/templates

# 專案 B（使用不同目錄）
cd /path/to/project-b
./speckit-sync-tool.sh sync --all --to .speckit/templates

# 專案 C（只需要部分模版）
cd /path/to/project-c
./speckit-sync-tool.sh sync --select spec-template.md,plan-template.md
```

### 場景 5：預覽更改

在實際同步前預覽：

```bash
# 預覽所有模版同步
./speckit-sync-tool.sh sync --all --dry-run

# 檢查輸出後再執行
./speckit-sync-tool.sh sync --all
```

## 備份與恢復

### 自動備份

工具會在更新模版前自動備份：

```
.claude/templates/
├── spec-template.md
├── spec-template.md.backup.20251016_120000  ← 自動備份
└── plan-template.md
```

### 手動恢復

如果需要恢復舊版本：

```bash
cd .claude/templates

# 列出備份
ls -lt *.backup.*

# 恢復特定備份
cp spec-template.md.backup.20251016_120000 spec-template.md
```

### 停用備份

如果不需要備份（不建議）：

```bash
# 修改腳本中的 BACKUP 變數
export BACKUP=false
./speckit-sync-tool.sh sync --all
```

## 整合到工作流程

### Git Hooks

在 pre-commit 檢查模版：

```bash
# .git/hooks/pre-commit
#!/bin/bash

if [ -f ".speckit-sync.json" ]; then
    ./speckit-sync-tool.sh check --include-templates
    if [ $? -ne 0 ]; then
        echo "Warning: Some templates are outdated"
    fi
fi
```

### CI/CD 整合

在 CI 流程中驗證模版：

```yaml
# .github/workflows/check-templates.yml
name: Check Templates
on: [push, pull_request]

jobs:
  check:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v2
      - name: Check templates
        run: |
          ./speckit-sync-tool.sh check --include-templates
```

### NPM Scripts

整合到 package.json：

```json
{
  "scripts": {
    "templates:sync": "./speckit-sync-tool.sh sync --all",
    "templates:check": "./speckit-sync-tool.sh check --include-templates",
    "templates:update": "./speckit-sync-tool.sh update --include-templates"
  }
}
```

## 進階功能

### 自訂模版目錄

如果你的專案使用不同的目錄結構：

```bash
# 同步到自訂目錄
./speckit-sync-tool.sh sync --all --to docs/templates

# 更新配置
./speckit-sync-tool.sh config edit
# 修改 sync_dir 為 "docs/templates"
```

### 批次處理多個專案

建立腳本批次處理：

```bash
#!/bin/bash
# sync-all-projects.sh

PROJECTS=(
    "/path/to/project-a"
    "/path/to/project-b"
    "/path/to/project-c"
)

for project in "${PROJECTS[@]}"; do
    echo "Syncing $project..."
    cd "$project"
    /path/to/spec-kit/speckit-sync-tool.sh sync --all
done
```

### 選擇性啟用

只在需要時啟用模版同步：

```bash
# 初次設定時不啟用
./speckit-sync-tool.sh sync --select spec-template.md

# 之後需要時再啟用其他模版
./speckit-sync-tool.sh sync --select plan-template.md,tasks-template.md
```

## 故障排除

### 問題：找不到模版

**錯誤：**
```
✗ 找不到模版目錄: /path/to/templates
```

**解決方案：**
```bash
# 檢查 SPECKIT_PATH 是否正確
echo $SPECKIT_PATH

# 或使用絕對路徑執行
/absolute/path/to/spec-kit/speckit-sync-tool.sh sync
```

### 問題：權限錯誤

**錯誤：**
```
Permission denied: .claude/templates
```

**解決方案：**
```bash
# 檢查目錄權限
ls -ld .claude/templates

# 修正權限
chmod 755 .claude/templates
```

### 問題：jq 未安裝

**錯誤：**
```
✗ 需要 jq 工具，請先安裝: brew install jq
```

**解決方案：**
```bash
# macOS
brew install jq

# Ubuntu/Debian
sudo apt-get install jq

# CentOS/RHEL
sudo yum install jq
```

### 問題：配置檔案損壞

**錯誤：**
```
parse error: Invalid JSON
```

**解決方案：**
```bash
# 重置配置
./speckit-sync-tool.sh config reset

# 重新同步
./speckit-sync-tool.sh sync
```

## 最佳實踐

### 1. 版本控制

**建議忽略配置檔案：**

```bash
# .gitignore
.speckit-sync.json
```

**但保留模版：**

```bash
# 不要忽略
.claude/templates/*.md
.claude/templates/*.json
```

### 2. 定期更新

建立定期檢查的習慣：

```bash
# 每週執行
./speckit-sync-tool.sh check --include-templates

# 如果有更新
./speckit-sync-tool.sh update --include-templates
```

### 3. 選擇性同步

不是所有專案都需要所有模版：

```bash
# 小型專案
./speckit-sync-tool.sh sync --select spec-template.md,plan-template.md

# 大型專案
./speckit-sync-tool.sh sync --all
```

### 4. 備份管理

定期清理舊備份：

```bash
# 刪除 30 天前的備份
find .claude/templates -name "*.backup.*" -mtime +30 -delete
```

### 5. 文檔化

記錄專案使用的模版：

```markdown
# 專案文檔

## 模版配置

本專案使用以下 spec-kit 模版：
- spec-template.md - 功能規格
- plan-template.md - 實作計劃
- tasks-template.md - 任務追蹤

更新方式：
\`\`\`bash
./speckit-sync-tool.sh update --include-templates
\`\`\`
```

## 未來功能

以下功能可能在未來版本加入：

- [ ] 模版變數替換（如 `{{PROJECT_NAME}}`）
- [ ] 模版預覽功能
- [ ] 模版差異顯示（diff）
- [ ] 自訂模版來源
- [ ] 模版版本管理
- [ ] 多語言模版支援

## 貢獻

如有建議或發現問題，歡迎提交 Issue 或 Pull Request。

## 授權

與 spec-kit 專案相同授權。
