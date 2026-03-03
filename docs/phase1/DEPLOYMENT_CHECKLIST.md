# 階段 1 部署檢查清單

使用此檢查清單確保順利部署 v1.1.0。

## 📦 交付檔案確認

### ✅ 核心檔案

- [x] **sync-commands-enhanced.sh** (27K)
  - 完整的 v1.1.0 實作
  - 852 行程式碼
  - 包含所有新功能

- [x] **sync-commands.sh** (14K) - 原版 v1.0.0
  - 保留作為參考
  - 可作為備份

### ✅ 文檔檔案

- [x] **QUICKSTART_v1.1.md** (6.9K)
  - 10 分鐘快速入門
  - 常見問題解答
  - 命令速查表

- [x] **PHASE1_EXAMPLES.md** (14K)
  - 6 個完整使用場景
  - 輸出範例展示
  - 進階使用案例

- [x] **PHASE1_INTEGRATION.md** (9.4K)
  - 兩種整合方式
  - 函數對照表
  - 測試步驟

- [x] **PHASE1_SUMMARY.md** (8.7K)
  - 功能總覽
  - 技術細節
  - 測試報告

- [x] **DEPLOYMENT_CHECKLIST.md** - 本文檔
  - 部署步驟
  - 驗證清單

### ✅ 測試工具

- [x] **test-phase1.sh** (9.4K)
  - 7 個自動化測試
  - 完整測試流程
  - 結果報告

### ✅ 現有檔案

- [x] **README.md** (10K)
  - 需要更新以包含 v1.1.0 資訊
  - 建議加入新功能說明

---

## 🚀 部署步驟

### 步驟 1: 預檢查

```bash
# 確認在正確目錄
cd /path/to/speckit-sync-tool

# 確認所有檔案存在
ls -lh sync-commands-enhanced.sh
ls -lh test-phase1.sh
ls -lh PHASE1_*.md
ls -lh QUICKSTART_v1.1.md
```

**預期輸出：** 所有檔案都應該存在且大小合理

### 步驟 2: 語法檢查

```bash
# 檢查 bash 語法
bash -n sync-commands-enhanced.sh

# 應該沒有輸出（表示無語法錯誤）
```

**預期結果：** 無錯誤訊息

### 步驟 3: 功能測試

```bash
# 測試基本命令
./sync-commands-enhanced.sh list

# 測試詳細模式
./sync-commands-enhanced.sh list --verbose

# 測試幫助
./sync-commands-enhanced.sh help
```

**預期結果：**
- ✅ 顯示 8 個命令
- ✅ 描述正確提取
- ✅ 幫助訊息包含新命令

### 步驟 4: 備份現有版本

```bash
# 備份 v1.0.0
cp sync-commands.sh sync-commands.sh.v1.0.0.backup

# 確認備份
ls -lh sync-commands.sh.v1.0.0.backup
```

**預期結果：** 備份檔案已建立

### 步驟 5: 部署新版本

#### 選項 A：直接替換（推薦）

```bash
# 替換為新版本
mv sync-commands-enhanced.sh sync-commands.sh

# 確認權限
chmod +x sync-commands.sh

# 驗證
./sync-commands.sh --help | head -1
```

**預期輸出：** `Spec-Kit 命令同步工具 v1.1.0`

#### 選項 B：保留兩個版本

```bash
# 保留 enhanced 版本
chmod +x sync-commands-enhanced.sh

# 創建符號連結
ln -sf sync-commands-enhanced.sh sync-commands-v1.1.sh
```

### 步驟 6: 執行測試套件

```bash
# 執行自動化測試
./test-phase1.sh
```

**預期結果：**
```
總測試數: X
通過: X
失敗: 0

✓ 所有測試通過！🎉
```

### 步驟 7: 實際環境測試

```bash
# 在測試專案中初始化
cd /tmp/test-project-$$
mkdir -p /tmp/test-project-$$

# 初始化
/path/to/speckit-sync-tool/sync-commands.sh init

# 檢查配置版本
grep '"version"' .claude/.speckit-sync.json

# 列出命令
/path/to/speckit-sync-tool/sync-commands.sh list

# 清理
cd /tmp
rm -rf test-project-$$
```

**預期結果：**
- ✅ 配置版本為 "1.1.0"
- ✅ 包含 `known_commands` 欄位
- ✅ list 命令正常工作

---

## ✅ 驗證清單

### 功能驗證

- [ ] `list` 命令顯示所有可用命令
- [ ] `list --verbose` 顯示命令描述
- [ ] `init` 建立 v1.1.0 配置
- [ ] `scan` 檢測新命令（如有）
- [ ] `check` 整合新命令檢測
- [ ] `update` 使用動態命令清單
- [ ] `status` 顯示配置版本
- [ ] `help` 包含新命令文檔

### 相容性驗證

- [ ] v1.0.0 配置自動升級到 v1.1.0
- [ ] 所有舊命令仍正常運作
- [ ] 配置檔案向後相容
- [ ] 環境變數（SPECKIT_PATH）正常

### 文檔驗證

- [ ] QUICKSTART 清晰易懂
- [ ] EXAMPLES 範例正確
- [ ] INTEGRATION 步驟完整
- [ ] SUMMARY 資訊準確

### 測試驗證

- [ ] test-phase1.sh 可執行
- [ ] 所有測試通過
- [ ] 無語法錯誤
- [ ] 錯誤處理正確

---

## 🔍 故障排除

### 問題 1: 語法錯誤

**症狀：**
```
sync-commands.sh: line XXX: syntax error...
```

**解決：**
```bash
# 檢查 bash 版本
bash --version

# 應該是 4.0+
# 如果版本太舊，升級 bash
```

### 問題 2: 找不到 spec-kit

**症狀：**
```
✗ spec-kit 路徑無效: /path/to/spec-kit
```

**解決：**
```bash
# 設定正確路徑
export SPECKIT_PATH=/path/to/spec-kit

# 或在腳本中修改預設值
```

### 問題 3: 描述顯示不正確

**症狀：**
```
(無描述)
```

**解決：**
```bash
# 檢查檔案格式
head -10 $SPECKIT_PATH/templates/commands/analyze.md

# 應該包含 YAML front matter:
# ---
# description: ...
# ---
```

### 問題 4: 測試失敗

**症狀：**
```
✗ 有 X 個測試失敗
```

**解決：**
```bash
# 手動執行失敗的測試
cd /tmp/speckit-sync-test-XXXXX

# 檢查具體錯誤訊息
# 修正後重新測試
```

---

## 📊 部署後檢查

### 執行環境檢查

```bash
# 檢查所有相關檔案
cd /path/to/speckit-sync-tool
ls -lh sync-commands.sh
ls -lh test-phase1.sh
ls -lh PHASE1_*.md

# 檢查權限
[ -x sync-commands.sh ] && echo "✓ 可執行" || echo "✗ 需要 chmod +x"

# 檢查 spec-kit 路徑
[ -d "$SPECKIT_PATH/templates/commands" ] && echo "✓ spec-kit 路徑正確" || echo "✗ 路徑錯誤"
```

### 功能快速測試

```bash
# 5 個關鍵命令
./sync-commands.sh list | grep "找到.*個命令"
./sync-commands.sh list -v | grep "description"
./sync-commands.sh help | grep "v1.1.0"

# 應該都有正確輸出
```

### 配置測試

```bash
# 測試初始化
mkdir -p /tmp/deployment-test
cd /tmp/deployment-test
/path/to/sync-commands.sh init < <(echo "y")

# 檢查配置
cat .claude/.speckit-sync.json | grep -A 3 '"version"'
cat .claude/.speckit-sync.json | grep -A 3 '"known_commands"'

# 清理
cd /tmp
rm -rf deployment-test
```

---

## 📝 部署記錄

### 部署資訊

- **部署日期：** _______________
- **部署者：** _______________
- **環境：** _______________
- **版本：** v1.1.0

### 檢查結果

- [ ] 所有檔案已確認
- [ ] 語法檢查通過
- [ ] 功能測試通過
- [ ] 自動化測試通過
- [ ] 實際環境測試通過
- [ ] 文檔已審查
- [ ] 備份已建立

### 遇到的問題

1. _______________
2. _______________
3. _______________

### 解決方案

1. _______________
2. _______________
3. _______________

---

## 🎯 下一步行動

### 立即行動

- [ ] 更新 README.md 包含 v1.1.0 資訊
- [ ] 通知團隊新功能
- [ ] 更新內部文檔

### 本週行動

- [ ] 在實際專案中測試
- [ ] 收集使用者回饋
- [ ] 記錄常見問題

### 未來規劃

- [ ] 規劃階段 2 功能
- [ ] 改進文檔
- [ ] 效能優化

---

## 🎉 部署完成

恭喜！階段 1 功能已成功部署。

### 關鍵成就

- ✅ 動態命令掃描
- ✅ 新命令檢測
- ✅ 互動式選擇
- ✅ 配置自動升級
- ✅ 完整文檔

### 快速參考

```bash
# 常用命令
./sync-commands.sh list          # 列出所有命令
./sync-commands.sh scan          # 掃描新命令
./sync-commands.sh check         # 檢查更新
./sync-commands.sh update        # 執行同步
```

### 學習資源

- 📖 QUICKSTART_v1.1.md - 快速開始
- 📖 PHASE1_EXAMPLES.md - 使用範例
- 📖 PHASE1_INTEGRATION.md - 技術文檔
- 📖 PHASE1_SUMMARY.md - 完整總結

---

**部署版本：** v1.1.0
**部署日期：** 2025-10-16
**狀態：** ✅ 生產就緒
