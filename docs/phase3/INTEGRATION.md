# SpecKit 模版同步工具 - 整合說明

## 專案結構

```
spec-kit/
├── speckit-sync-tool.sh              # 主要工具腳本
├── .speckit-sync.json.example        # 配置範例
├── README.template-sync.md           # 快速開始指南
├── docs/
│   └── TEMPLATE_SYNC_GUIDE.md        # 完整使用文檔
├── examples/
│   ├── quick-start.sh                # 快速開始腳本
│   ├── sync-workflow.sh              # 工作流程演示
│   └── advanced-usage.md             # 進階使用範例
├── tests/
│   └── test-sync-tool.sh             # 整合測試
└── templates/
    ├── spec-template.md              # 功能規格模版
    ├── plan-template.md              # 實作計劃模版
    ├── tasks-template.md             # 任務清單模版
    ├── checklist-template.md         # 檢查清單模版
    ├── agent-file-template.md        # AI 代理上下文
    └── vscode-settings.json          # VS Code 設定
```

## 核心功能

### 1. 模版掃描

```bash
get_templates_from_speckit()
```

- 掃描 `templates/` 目錄下的所有模版檔案
- 排除 `commands/` 子目錄
- 支援 `.md` 和 `.json` 檔案
- 回傳排序後的模版清單

### 2. 模版同步

```bash
sync_template(template_name, target_dir, dry_run, backup)
```

**功能：**
- 複製模版檔案到目標目錄
- 自動建立目標目錄
- 檔案存在時自動備份（預設啟用）
- 支援預覽模式（dry-run）
- 檢測檔案是否已是最新版本

**狀態指示：**
- `⊙` - 已是最新（無需更新）
- `⟳` - 已更新（檔案有變更）
- `+` - 新建立（首次同步）

### 3. 批次同步

```bash
sync_templates_batch(templates...)
```

- 批次處理多個模版
- 顯示同步進度和結果統計
- 自動讀取配置中的目標目錄
- 支援預覽模式

### 4. 互動式選擇

```bash
interactive_select_templates()
```

**選擇方式：**
- 數字（空格分隔）: `1 3 5`
- 範圍: `1-3`
- 全選: `a` 或 `all`
- 取消: `q` 或 `quit`

**輸出：**
返回選中的模版清單（每行一個）

### 5. 更新檢查

```bash
check_template_updates(target_dir)
```

**檢查項目：**
- 過時的模版（有更新）
- 缺少的模版（尚未同步）
- 最新的模版（無需更新）

**回傳值：**
- `0`: 所有模版都是最新
- `1`: 有模版需要更新

### 6. 配置管理

```bash
load_config()          # 載入配置
save_config(config)    # 儲存配置
update_config_field(field, value)  # 更新單一欄位
```

**配置結構：**
```json
{
  "version": "1.0.0",
  "templates": {
    "enabled": boolean,
    "sync_dir": string,
    "selected": [string],
    "last_sync": string (ISO 8601)
  }
}
```

## CLI 命令

### sync - 同步模版

```bash
speckit-sync-tool.sh sync [選項]
```

**選項：**
- `-a, --all` - 同步所有模版
- `-s, --select NAMES` - 選擇特定模版（逗號分隔）
- `-t, --to DIR` - 指定目標目錄
- `-n, --dry-run` - 預覽模式（不寫入檔案）
- `-h, --help` - 顯示說明

**流程：**
1. 解析參數
2. 選擇模版（互動式/指定/全部）
3. 確定目標目錄
4. 執行同步
5. 更新配置（非 dry-run 模式）

### check - 檢查更新

```bash
speckit-sync-tool.sh check [選項]
```

**選項：**
- `-t, --include-templates` - 檢查模版更新
- `-d, --dir DIR` - 指定檢查目錄

**輸出：**
- 需要更新的模版清單
- 尚未同步的模版清單
- 已是最新的模版清單
- 更新命令建議

### update - 更新模版

```bash
speckit-sync-tool.sh update [選項]
```

**選項：**
- `-t, --include-templates` - 更新模版

**功能：**
- 自動偵測過時和缺失的模版
- 執行批次同步
- 更新前自動備份

### list - 列出模版

```bash
speckit-sync-tool.sh list [選項]
```

**選項：**
- `-d, --details` - 顯示詳細資訊（大小、描述）

**輸出：**
- 模版名稱
- 模版描述（詳細模式）
- 檔案大小（詳細模式）
- 模版總數

### status - 顯示狀態

```bash
speckit-sync-tool.sh status
```

**顯示資訊：**
- 啟用狀態
- 同步目錄
- 上次同步時間
- 已選擇的模版清單
- 各模版的同步狀態（✓ 存在 / ? 缺失）

### config - 管理配置

```bash
speckit-sync-tool.sh config <操作>
```

**操作：**
- `show` - 顯示配置（預設）
- `edit` - 編輯配置（使用 $EDITOR）
- `reset` - 重置配置

## 整合方式

### 1. 直接使用

```bash
# 在專案目錄中
/path/to/spec-kit/speckit-sync-tool.sh sync --all
```

### 2. 建立別名

```bash
# .bashrc 或 .zshrc
alias speckit-sync='/path/to/spec-kit/speckit-sync-tool.sh'

# 使用
speckit-sync sync --all
```

### 3. 符號連結

```bash
# 加入到 PATH
ln -s /path/to/spec-kit/speckit-sync-tool.sh /usr/local/bin/speckit-sync

# 使用
speckit-sync sync --all
```

### 4. NPM Scripts

```json
{
  "scripts": {
    "templates:sync": "speckit-sync-tool.sh sync --all",
    "templates:check": "speckit-sync-tool.sh check --include-templates",
    "templates:update": "speckit-sync-tool.sh update --include-templates"
  }
}
```

### 5. Makefile

```makefile
.PHONY: templates-sync templates-check templates-update

SPECKIT_SYNC = /path/to/spec-kit/speckit-sync-tool.sh

templates-sync:
	@$(SPECKIT_SYNC) sync --all

templates-check:
	@$(SPECKIT_SYNC) check --include-templates

templates-update:
	@$(SPECKIT_SYNC) update --include-templates
```

### 6. Git Hooks

```bash
# .git/hooks/pre-commit
#!/bin/bash

if [ -f ".speckit-sync.json" ]; then
    speckit-sync-tool.sh check --include-templates
fi
```

### 7. CI/CD

```yaml
# .github/workflows/check-templates.yml
name: Check Templates
on: [push, pull_request]
jobs:
  check:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v3
      - name: Install jq
        run: sudo apt-get install -y jq
      - name: Check templates
        run: ./speckit-sync-tool.sh check --include-templates
```

## 依賴需求

### 必要依賴

- **Bash** 4.0 或更高版本
- **jq** - JSON 處理工具
- **coreutils** - 標準 Unix 工具（cp, mv, mkdir 等）

### 檢查依賴

```bash
# 檢查 Bash 版本
bash --version

# 檢查 jq
jq --version

# 安裝 jq (macOS)
brew install jq

# 安裝 jq (Ubuntu/Debian)
sudo apt-get install jq

# 安裝 jq (CentOS/RHEL)
sudo yum install jq
```

## 環境變數

| 變數 | 說明 | 預設值 |
|------|------|--------|
| `SPECKIT_PATH` | spec-kit 安裝路徑 | 腳本所在目錄 |
| `CONFIG_FILE` | 配置檔案名稱 | `.speckit-sync.json` |
| `DEFAULT_SYNC_DIR` | 預設同步目錄 | `.claude/templates` |
| `DRY_RUN` | 預覽模式標誌 | `false` |
| `BACKUP` | 備份標誌 | `true` |
| `EDITOR` | 配置編輯器 | `nano` |

## 錯誤處理

### 退出碼

- `0`: 成功
- `1`: 錯誤（找不到檔案、參數錯誤等）

### 常見錯誤

**錯誤 1: 找不到模版目錄**
```
✗ 找不到模版目錄: /path/to/templates
```
**解決**: 檢查 SPECKIT_PATH 是否正確設定

**錯誤 2: jq 未安裝**
```
✗ 需要 jq 工具，請先安裝: brew install jq
```
**解決**: 安裝 jq 工具

**錯誤 3: 權限錯誤**
```
Permission denied: .claude/templates
```
**解決**: 檢查並修正目錄權限

**錯誤 4: 配置檔案損壞**
```
parse error: Invalid JSON
```
**解決**: 執行 `config reset` 重置配置

## 備份機制

### 自動備份

- 更新模版前自動備份舊版本
- 備份檔名格式: `{template}.backup.{timestamp}`
- 範例: `spec-template.md.backup.20251016_120000`

### 手動備份

```bash
# 備份整個模版目錄
cp -r .claude/templates .claude/templates.backup

# 備份單一模版
cp .claude/templates/spec-template.md \
   .claude/templates/spec-template.md.backup
```

### 恢復備份

```bash
# 列出所有備份
ls -lt .claude/templates/*.backup.*

# 恢復特定備份
cp .claude/templates/spec-template.md.backup.20251016_120000 \
   .claude/templates/spec-template.md
```

### 清理舊備份

```bash
# 刪除 30 天前的備份
find .claude/templates -name "*.backup.*" -mtime +30 -delete
```

## 測試

### 執行整合測試

```bash
./tests/test-sync-tool.sh
```

### 測試覆蓋範圍

- ✓ 列出模版
- ✓ 查看狀態
- ✓ 同步單一模版
- ✓ 同步多個模版
- ✓ 同步所有模版
- ✓ Dry-run 模式
- ✓ 自訂目錄
- ✓ 檢查更新
- ✓ 更新模版
- ✓ 配置管理
- ✓ JSON 格式驗證

### 手動測試

```bash
# 建立測試環境
mkdir -p ~/tmp/test-sync
cd ~/tmp/test-sync

# 執行快速開始腳本
/path/to/spec-kit/examples/quick-start.sh

# 清理
rm -rf ~/tmp/test-sync
```

## 版本歷史

### v1.0.0 (2025-10-16)

**初始版本功能：**
- ✓ 模版掃描與列表
- ✓ 互動式模版選擇
- ✓ 批次模版同步
- ✓ 更新檢查與自動更新
- ✓ 配置檔案管理
- ✓ Dry-run 預覽模式
- ✓ 自動備份機制
- ✓ CLI 命令介面
- ✓ 狀態查看
- ✓ 自訂目錄支援

## 未來規劃

### v1.1.0 (計劃中)

- [ ] 模版變數替換（`{{PROJECT_NAME}}`）
- [ ] 模版預覽功能
- [ ] 模版差異顯示（diff）
- [ ] 增量更新（只更新變更部分）

### v1.2.0 (計劃中)

- [ ] 自訂模版來源
- [ ] 模版版本管理
- [ ] 多語言模版支援
- [ ] 模版依賴管理

### v2.0.0 (計劃中)

- [ ] Web UI 介面
- [ ] 雲端同步支援
- [ ] 團隊模版庫
- [ ] API 整合

## 貢獻指南

### 回報問題

1. 檢查是否已有相同問題
2. 提供詳細的錯誤訊息
3. 包含重現步驟
4. 說明預期行為

### 提交程式碼

1. Fork 專案
2. 建立功能分支
3. 撰寫測試
4. 提交 Pull Request

### 程式碼風格

- 遵循 Bash 最佳實踐
- 使用有意義的變數名稱
- 加入適當的註解
- 保持函數簡潔

## 授權

與 spec-kit 專案相同授權。

## 支援

- 文檔: `docs/TEMPLATE_SYNC_GUIDE.md`
- 範例: `examples/`
- Issues: GitHub Issues
- 測試: `tests/test-sync-tool.sh`

## 致謝

感謝所有使用和貢獻此工具的開發者。
