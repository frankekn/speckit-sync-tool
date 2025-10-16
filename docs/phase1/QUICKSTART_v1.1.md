# 快速開始指南 - v1.1.0

10 分鐘快速上手 Spec-Kit 同步工具的新功能！

## 📦 安裝/升級

### 選項 1：全新安裝

```bash
cd /Users/termtek/Documents/GitHub/speckit-sync-tool

# 使用新版本
mv sync-commands-enhanced.sh sync-commands.sh
chmod +x sync-commands.sh

# 測試
./sync-commands.sh list
```

### 選項 2：從 v1.0.0 升級

```bash
# 備份
cp sync-commands.sh sync-commands.sh.v1.0.0.backup

# 替換
mv sync-commands-enhanced.sh sync-commands.sh

# 配置會自動升級，無需手動操作
```

---

## 🚀 5 分鐘入門

### 1. 查看所有可用命令（新功能！）

```bash
./sync-commands.sh list
```

輸出：
```
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
📋 Spec-Kit 可用命令
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

ℹ 找到 8 個命令：

  ⊕ analyze.md
  ⊕ checklist.md
  ...
```

### 2. 查看詳細描述（新功能！）

```bash
./sync-commands.sh list --verbose
```

輸出：
```
  • analyze.md [未安裝]
    Perform a non-destructive cross-artifact consistency...

  • implement.md [未安裝]
    Execute the implementation plan by processing...
```

### 3. 在專案中初始化

```bash
cd /path/to/your-project
/path/to/sync-commands.sh init
```

### 4. 檢測新命令（新功能！）

```bash
./sync-commands.sh scan
```

如果有新命令：
```
🆕 Spec-Kit 新增了 2 個命令：

  ⊕ refactor.md
     Code Refactoring Assistant

是否將新命令加入同步清單？
  [a] 全部加入
  [s] 選擇性加入
  [n] 暫不加入
選擇 [a/s/n]: a
```

### 5. 執行同步

```bash
./sync-commands.sh update
```

---

## 🎯 常見使用場景

### 場景 1：定期檢查更新

```bash
# 每週執行一次
cd /path/to/project
~/sync-commands.sh check

# 如果有更新
~/sync-commands.sh update
```

### 場景 2：spec-kit 新增了命令

```bash
# v1.1.0 會自動檢測！
~/sync-commands.sh scan

# 或在 check 時自動檢測
~/sync-commands.sh check
```

### 場景 3：查看專案狀態

```bash
~/sync-commands.sh status
```

輸出：
```
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
同步狀態
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

專案: my-project
Spec-Kit 版本: 0.0.20
最後檢查: 2025-10-16T04:30:00Z
同步次數: 3

📋 已知命令 (8 個):
✓ analyze.md
✓ implement.md
...
```

---

## 🆕 v1.1.0 新功能速覽

### 1. 動態命令掃描

**以前（v1.0.0）：**
- 硬編碼 8 個命令
- spec-kit 新增命令需要手動修改腳本

**現在（v1.1.0）：**
- ✅ 自動掃描所有命令
- ✅ 無需修改腳本
- ✅ 支援任意數量命令

### 2. 新命令檢測

**新功能：**
```bash
./sync-commands.sh scan
```

- ✅ 自動比對 spec-kit vs 本地配置
- ✅ 互動式選擇
- ✅ 自動更新配置

### 3. 列出可用命令

**新功能：**
```bash
./sync-commands.sh list          # 基本列表
./sync-commands.sh list -v       # 詳細模式（含描述）
```

### 4. 配置自動升級

**以前：** 需要手動遷移配置

**現在：**
- ✅ 自動檢測 v1.0.0 配置
- ✅ 自動升級到 v1.1.0
- ✅ 保留所有設定

---

## 📚 命令速查

| 命令 | 功能 | v1.1.0 新增 |
|------|------|-------------|
| `init` | 初始化專案配置 | 升級：動態掃描 |
| `check` | 檢查更新 | 升級：整合新命令檢測 |
| `update` | 執行同步 | 升級：動態命令清單 |
| `status` | 查看狀態 | 升級：顯示配置版本 |
| `diff <cmd>` | 比對差異 | - |
| **`list [-v]`** | **列出可用命令** | ✅ 新增 |
| **`scan`** | **掃描新命令** | ✅ 新增 |
| `help` | 顯示幫助 | 升級：新命令文檔 |

---

## 🔧 設定環境變數（可選）

### 自訂 spec-kit 路徑

```bash
export SPECKIT_PATH=/custom/path/spec-kit
```

### 自訂命令目錄

```bash
export COMMANDS_DIR=.claude/custom-commands
```

### 寫入 shell 配置

```bash
# 加入 ~/.bashrc 或 ~/.zshrc
echo 'export SPECKIT_PATH=/path/to/spec-kit' >> ~/.bashrc
echo 'alias sks="/path/to/sync-commands.sh"' >> ~/.bashrc

# 重新載入
source ~/.bashrc

# 使用別名
sks list
sks check
```

---

## 🎓 學習路徑

### 初學者（5 分鐘）

1. ✅ 執行 `list` 查看可用命令
2. ✅ 執行 `init` 初始化專案
3. ✅ 執行 `update` 同步命令

### 進階使用者（15 分鐘）

4. ✅ 執行 `scan` 檢測新命令
5. ✅ 執行 `status` 查看詳細狀態
6. ✅ 執行 `diff` 比對差異
7. ✅ 設定環境變數和別名

### 深度使用者（30 分鐘）

8. ✅ 閱讀 **PHASE1_EXAMPLES.md**
9. ✅ 閱讀 **PHASE1_INTEGRATION.md**
10. ✅ 執行 **test-phase1.sh** 測試

---

## ❓ 常見問題

### Q1: 如何知道配置是哪個版本？

```bash
./sync-commands.sh status | grep "配置版本"
```

或直接查看配置檔案：
```bash
grep '"version"' .claude/.speckit-sync.json
```

### Q2: v1.0.0 配置會自動升級嗎？

是的！執行任何命令時會自動檢測並升級。

### Q3: 如何回退到 v1.0.0？

```bash
# 如果有備份
cp sync-commands.sh.v1.0.0.backup sync-commands.sh

# 配置檔案
cp .claude/.speckit-sync.json.backup .claude/.speckit-sync.json
```

### Q4: 新命令檢測不工作？

檢查：
1. spec-kit 路徑是否正確
2. 配置檔案是否包含 `known_commands`
3. 執行 `scan` 手動觸發

### Q5: 如何只列出未安裝的命令？

```bash
./sync-commands.sh list | grep "⊕"
```

或使用 check：
```bash
./sync-commands.sh check | grep "本地不存在"
```

---

## 🚦 下一步

### 基本工作流程

```bash
# 1. 初始化（只需一次）
cd /path/to/project
~/sync-commands.sh init

# 2. 定期檢查（每週）
~/sync-commands.sh check

# 3. 發現新命令時
~/sync-commands.sh scan

# 4. 執行同步
~/sync-commands.sh update

# 5. 查看狀態
~/sync-commands.sh status
```

### 進階學習

- 📖 閱讀 **PHASE1_EXAMPLES.md** - 完整使用範例
- 📖 閱讀 **PHASE1_INTEGRATION.md** - 技術細節
- 📖 閱讀 **PHASE1_SUMMARY.md** - 功能總覽
- 🧪 執行 **test-phase1.sh** - 自動化測試

---

## 📞 獲取幫助

```bash
# 內建幫助
./sync-commands.sh help

# 查看版本資訊
./sync-commands.sh help | grep "v1.1.0"
```

---

## ✨ 快速提示

### Tip 1: 使用別名

```bash
alias sks='/path/to/sync-commands.sh'
sks list
```

### Tip 2: 查看最近變更

```bash
sks diff implement.md | head -20
```

### Tip 3: 批次操作

```bash
# 在多個專案中快速同步
for proj in ~/projects/*; do
  cd "$proj"
  sks check
  sks update
done
```

### Tip 4: Git 整合

```bash
# 提交前檢查
sks status
git add .claude/
git commit -m "chore: sync spec-kit commands"
```

---

**版本：** v1.1.0
**更新：** 2025-10-16

🎉 **享受新功能！**
