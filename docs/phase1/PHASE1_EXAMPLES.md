# 階段 1 使用範例

完整的使用範例和輸出示範。

## 📋 目錄

1. [列出所有可用命令](#1-列出所有可用命令)
2. [初始化專案（動態掃描）](#2-初始化專案動態掃描)
3. [檢測新命令](#3-檢測新命令)
4. [互動式選擇命令](#4-互動式選擇命令)
5. [配置檔案自動升級](#5-配置檔案自動升級)
6. [完整工作流程](#6-完整工作流程)

---

## 1. 列出所有可用命令

### 基本列表

```bash
$ ./sync-commands.sh list
```

**輸出：**
```
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

### 詳細模式（含描述）

```bash
$ ./sync-commands.sh list --verbose
```

**輸出：**
```
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
📋 Spec-Kit 可用命令
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

📁 來源路徑: /path/to/spec-kit/templates/commands

ℹ 找到 8 個命令：

  • analyze.md [已同步]
    Code Analysis Assistant - Systematic code review and quality assessment

  • checklist.md [未安裝]
    Quality Assurance Checklist Generator - Comprehensive QA guidelines

  • clarify.md [已修改]
    Requirements Clarification Helper - Interactive requirement gathering

  • constitution.md [已同步]
    Project Constitution - Core principles and guidelines

  • implement.md [已同步]
    Implementation Assistant - Step-by-step coding guidance

  • plan.md [已同步]
    Planning Assistant - Project and task planning

  • specify.md [已同步]
    Specification Generator - Technical specification creation

  • tasks.md [已同步]
    Task Management - Todo and task tracking
```

**圖例說明：**
- ✓ = 已同步（本地與 spec-kit 相同）
- ↻ = 已修改（本地有自訂修改）
- ⊕ = 未安裝（本地不存在）

---

## 2. 初始化專案（動態掃描）

### 場景：首次在專案中設定同步工具

```bash
$ cd /path/to/my-project
$ /path/to/sync-commands.sh init
```

**輸出：**
```
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
初始化 Spec-Kit 同步配置
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

ℹ 掃描 Spec-Kit 可用命令...
✓ 找到 8 個命令

ℹ 檢查本地命令狀態...
✓ 配置檔案已建立: .claude/.speckit-sync.json (v1.1.0)

ℹ 下一步: 執行 './sync-commands.sh check' 檢查更新
```

**生成的配置檔案 `.claude/.speckit-sync.json`：**
```json
{
  "version": "1.1.0",
  "source": {
    "type": "local",
    "path": "/path/to/spec-kit",
    "version": "0.0.20"
  },
  "known_commands": [
    "analyze.md",
    "checklist.md",
    "clarify.md",
    "constitution.md",
    "implement.md",
    "plan.md",
    "specify.md",
    "tasks.md"
  ],
  "strategy": {
    "mode": "semi-auto",
    "on_conflict": "ask",
    "auto_backup": true,
    "backup_retention": 5
  },
  "commands": {
    "standard": [
      {
        "name": "analyze.md",
        "status": "missing",
        "version": "0.0.20",
        "last_sync": "2025-10-16T04:30:00Z"
      },
      ...
    ],
    "custom": [],
    "ignored": []
  },
  "metadata": {
    "project_name": "my-project",
    "initialized": "2025-10-16T04:30:00Z",
    "last_check": "2025-10-16T04:30:00Z",
    "total_syncs": 0
  }
}
```

**重點特性：**
- ✅ 自動掃描所有 spec-kit 命令（不再硬編碼）
- ✅ `known_commands` 欄位記錄已知命令
- ✅ 配置版本為 v1.1.0

---

## 3. 檢測新命令

### 場景：spec-kit 新增了命令，專案配置是舊的

```bash
$ ./sync-commands.sh scan
```

**輸出範例 1：檢測到新命令**
```
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
🔍 掃描 Spec-Kit 新命令
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

📁 Spec-Kit 路徑: /path/to/spec-kit
📁 命令目錄: /path/to/spec-kit/templates/commands

ℹ 找到 10 個 Spec-Kit 命令
ℹ 配置檔案中已知 8 個命令

🆕 Spec-Kit 新增了 2 個命令：

  ⊕ refactor.md
     Code Refactoring Assistant - Systematic code improvement

  ⊕ review.md
     Code Review Helper - Comprehensive code review guidance

是否將新命令加入同步清單？
  [a] 全部加入
  [s] 選擇性加入
  [n] 暫不加入
選擇 [a/s/n]: a

✓ 已將 2 個新命令加入配置
```

**輸出範例 2：沒有新命令**
```
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
🔍 掃描 Spec-Kit 新命令
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

📁 Spec-Kit 路徑: /path/to/spec-kit
📁 命令目錄: /path/to/spec-kit/templates/commands

ℹ 找到 8 個 Spec-Kit 命令
ℹ 配置檔案中已知 8 個命令

✓ 沒有檢測到新命令 🎉
```

---

## 4. 互動式選擇命令

### 場景：只想加入部分新命令

```bash
$ ./sync-commands.sh scan
```

**互動過程：**
```
🆕 Spec-Kit 新增了 3 個命令：

  ⊕ refactor.md
     Code Refactoring Assistant

  ⊕ review.md
     Code Review Helper

  ⊕ debug.md
     Debugging Assistant

是否將新命令加入同步清單？
  [a] 全部加入
  [s] 選擇性加入
  [n] 暫不加入
選擇 [a/s/n]: s

ℹ 請選擇要加入的命令（輸入編號，用空格分隔，或 'all' 全選）：

  [1] refactor.md - Code Refactoring Assistant
  [2] review.md - Code Review Helper
  [3] debug.md - Debugging Assistant

選擇 (例如: 1 3 5 或 all): 1 2

✓ 已將 2 個命令加入配置
```

**結果：**
- ✅ `refactor.md` 和 `review.md` 被加入 `known_commands`
- ❌ `debug.md` 未加入（稍後可再次執行 scan）

---

## 5. 配置檔案自動升級

### 場景：專案使用舊版 v1.0.0 配置

**舊配置檔案 `.claude/.speckit-sync.json`：**
```json
{
  "version": "1.0.0",
  "source": {...},
  "commands": {
    "standard": [
      {"name": "analyze.md", "status": "synced"},
      {"name": "implement.md", "status": "synced"}
    ]
  }
}
```

**執行任何命令（例如 scan）：**
```bash
$ ./sync-commands.sh scan
```

**輸出：**
```
ℹ 升級配置檔案: 1.0.0 → 1.1.0
配置檔案已升級到 v1.1.0

━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
🔍 掃描 Spec-Kit 新命令
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
...
```

**升級後的配置檔案：**
```json
{
  "version": "1.1.0",
  "source": {...},
  "known_commands": [
    "analyze.md",
    "implement.md"
  ],
  "commands": {
    "standard": [...]
  }
}
```

**升級邏輯：**
1. 檢測配置版本
2. 從 `commands.standard` 提取命令名稱
3. 建立 `known_commands` 陣列
4. 更新版本號為 1.1.0
5. 保留所有其他設定

---

## 6. 完整工作流程

### 場景：在新專案中完整使用工具

```bash
# 1. 初始化專案
$ cd ~/my-new-project
$ ~/sync-commands.sh init

━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
初始化 Spec-Kit 同步配置
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

ℹ 掃描 Spec-Kit 可用命令...
✓ 找到 8 個命令
✓ 配置檔案已建立: .claude/.speckit-sync.json (v1.1.0)

# 2. 列出可用命令
$ ~/sync-commands.sh list

ℹ 找到 8 個命令：
  ⊕ analyze.md
  ⊕ checklist.md
  ...

# 3. 檢查更新（首次會提示需要同步）
$ ~/sync-commands.sh check

ℹ 檢查 spec-kit 是否有新版本...
✓ spec-kit 已是最新版本 (0.0.20)

⚠ ⊕ analyze.md - 本地不存在（新命令）
⚠ ⊕ checklist.md - 本地不存在（新命令）
...

📊 統計：
  ✅ 已同步: 0
  ⊕  缺少: 8
  ↻  過時: 0
  ═══════════
  📦 總計: 8

⚠ 發現 8 個命令需要更新

ℹ 檢查是否有新命令...
✓ 沒有檢測到新命令 🎉

# 4. 執行同步
$ ~/sync-commands.sh update

━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
同步 Spec-Kit 命令
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

ℹ 📦 建立備份: .claude/commands/.backup/20251016_123045

✓ ⊕ analyze.md - 新增
✓ ⊕ checklist.md - 新增
✓ ⊕ clarify.md - 新增
...

━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
同步完成
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
  ⊕  新增: 8 個
  ↻  更新: 0 個
  ✓  跳過: 0 個
  📦 備份: .claude/commands/.backup/20251016_123045

# 5. 查看狀態
$ ~/sync-commands.sh status

━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
同步狀態
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

📁 Spec-Kit 路徑: /path/to/spec-kit
📁 命令目錄: .claude/commands

⚙️  配置檔案: .claude/.speckit-sync.json
📌 配置版本: 1.1.0

專案: my-new-project
Spec-Kit 版本: 0.0.20
初始化時間: 2025-10-16T04:30:00Z
最後檢查: 2025-10-16T04:30:45Z
同步次數: 1

📋 已知命令 (8 個):
✓ analyze.md
✓ checklist.md
✓ clarify.md
...

🎨 自訂命令:
  (無)

# ─────────────────────────────────────────
# 一週後，spec-kit 新增了命令...
# ─────────────────────────────────────────

# 6. 定期檢查（會自動檢測新命令）
$ ~/sync-commands.sh check

ℹ 檢查 spec-kit 是否有新版本...
ℹ 發現 spec-kit 新版本，正在更新...
✓ spec-kit 已更新: 0.0.20 → 0.0.21

✓ analyze.md - 已是最新
↻ implement.md - 有更新可用
...

📊 統計：
  ✅ 已同步: 7
  ⊕  缺少: 0
  ↻  過時: 1
  ═══════════
  📦 總計: 8

ℹ 檢查是否有新命令...

🆕 Spec-Kit 新增了 1 個命令：

  ⊕ refactor.md
     Code Refactoring Assistant

是否將新命令加入同步清單？
  [a] 全部加入
  [s] 選擇性加入
  [n] 暫不加入
選擇 [a/s/n]: a

✓ 已將 1 個新命令加入配置

# 7. 再次更新（會同步舊命令的更新 + 新命令）
$ ~/sync-commands.sh update

✓ ↻ implement.md - 已更新
✓ ⊕ refactor.md - 新增
...

━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
同步完成
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
  ⊕  新增: 1 個
  ↻  更新: 1 個
  ✓  跳過: 7 個
```

---

## 🔍 進階使用案例

### 案例 1：查看特定命令差異

```bash
$ ~/sync-commands.sh diff implement.md

━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
比較: implement.md
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
📄 本地: .claude/commands/implement.md
📄 spec-kit: /path/to/spec-kit/templates/commands/implement.md

--- .claude/commands/implement.md
+++ /path/to/spec-kit/templates/commands/implement.md
@@ -5,7 +5,7 @@

-## Old feature description
+## Updated feature description

...

ℹ （顯示前 50 行差異）
```

### 案例 2：自訂 spec-kit 路徑

```bash
$ SPECKIT_PATH=/custom/path/spec-kit ~/sync-commands.sh list

📁 來源路徑: /custom/path/spec-kit/templates/commands
...
```

### 案例 3：批次操作多個專案

```bash
#!/bin/bash
# 批次更新所有專案

PROJECTS=(
  ~/project-a
  ~/project-b
  ~/project-c
)

for proj in "${PROJECTS[@]}"; do
  echo "處理: $proj"
  cd "$proj"
  ~/sync-commands.sh check
  echo "n" | ~/sync-commands.sh scan  # 跳過新命令提示
  ~/sync-commands.sh update
  echo "─────────────────────────"
done
```

---

## 🎯 關鍵改進對照

| 功能 | v1.0.0（舊版） | v1.1.0（新版） |
|------|----------------|----------------|
| 命令清單 | 硬編碼 8 個 | 動態掃描所有 |
| 新命令 | 手動修改腳本 | 自動檢測 + 互動選擇 |
| 命令描述 | 無 | 自動提取顯示 |
| 配置升級 | 無 | 自動向後相容 |
| CLI 命令 | 5 個 | 7 個（新增 list, scan） |

---

## 📝 技巧與最佳實踐

### 定期檢查工作流程

建議將以下命令加入 cron 或開發習慣：

```bash
# 每週一次檢查更新
$ ~/sync-commands.sh check

# 執行更新
$ ~/sync-commands.sh update
```

### 查看新功能

```bash
# 隨時列出所有可用命令
$ ~/sync-commands.sh list -v
```

### Git 整合

```bash
# 在提交前檢查同步狀態
$ ~/sync-commands.sh status
$ git add .claude/
$ git commit -m "chore: update spec-kit commands"
```

---

**版本：** 1.1.0
**更新日期：** 2025-10-16
