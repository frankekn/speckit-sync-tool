# Spec-Kit Sync Tool - 交付檔案總覽

## 📦 專案結構

```
speckit-sync-tool/
├── sync-commands.sh              # Phase 0: 原始版本 v1.0.0
├── sync-commands-enhanced.sh     # Phase 1: v1.1.0 動態命令掃描
├── sync-commands-v2.sh           # Phase 2: v2.0.0 多代理支援
├── template-sync.sh              # Phase 3: v2.1.0 模版同步
├── batch-sync-all.sh             # 批次處理工具
├── install.sh                    # 全局安裝腳本
├── test-phase1.sh                # Phase 1 測試套件
├── .speckit-sync.json.template   # 配置範本
├── Makefile.template             # Makefile 範本
├── LICENSE                       # MIT 授權
├── README.md                     # 主要說明文檔
├── PHASE1_COMPLETE.txt           # Phase 1 完成報告
└── docs/
    ├── phase1/                   # Phase 1 文檔
    │   ├── QUICKSTART_v1.1.md
    │   ├── PHASE1_SUMMARY.md
    │   ├── PHASE1_INTEGRATION.md
    │   ├── PHASE1_EXAMPLES.md
    │   └── DEPLOYMENT_CHECKLIST.md
    ├── phase2/                   # Phase 2 文檔
    │   ├── speckit-sync-tool-phase2-architecture.md
    │   ├── speckit-sync-tool-usage-examples.md
    │   ├── speckit-sync-tool-integration-guide.md
    │   └── speckit-sync-tool-summary.md
    └── phase3/                   # Phase 3 文檔
        ├── README.template-sync.md
        ├── TEMPLATE_SYNC_GUIDE.md
        ├── TEMPLATE_SYNC_SUMMARY.md
        └── INTEGRATION.md
```

## 🎯 各階段功能

### Phase 0: 基礎版本 (v1.0.0)
**檔案**: `sync-commands.sh`

**功能**:
- ✅ 8 個標準命令同步
- ✅ 自動備份與回滾
- ✅ 差異顯示
- ✅ 自動更新 spec-kit

**限制**:
- ❌ 命令列表寫死
- ❌ 只支援 Claude (.claude/)
- ❌ 不支援模版同步

### Phase 1: 動態掃描 (v1.1.0)
**檔案**: `sync-commands-enhanced.sh`

**新增功能**:
- ✅ 動態命令掃描 (不再寫死)
- ✅ 新命令自動偵測
- ✅ 互動式選擇新命令
- ✅ 新增 `list`, `scan` 命令

**配置升級**: v1.0.0 → v1.1.0

**測試**: `test-phase1.sh` (7 個測試案例)

### Phase 2: 多代理支援 (v2.0.0)
**檔案**: `sync-commands-v2.sh`

**新增功能**:
- ✅ 13 種 AI 代理支援:
  - Claude (.claude/)
  - Cursor (.cursor/)
  - GitHub Copilot (.github/prompts/)
  - Gemini (.gemini/)
  - Windsurf (.windsurf/workflows/)
  - Qwen, opencode, Codex, Kilocode, Auggie, CodeBuddy, Roo, Amazon Q
- ✅ 自動偵測專案中的代理
- ✅ 互動式代理選擇
- ✅ 獨立的代理同步狀態

**配置升級**: v1.1.0 → v2.0.0

**配置結構**:
```json
{
  "version": "2.0.0",
  "agents": {
    "claude": {
      "enabled": true,
      "commands_dir": ".claude/commands",
      "commands": {...}
    },
    "cursor": {...}
  }
}
```

### Phase 3: 模版同步 (v2.1.0)
**檔案**: `template-sync.sh`

**新增功能**:
- ✅ spec-kit 模版同步
- ✅ 互動式模版選擇
- ✅ 獨立模版管理
- ✅ 新增 `templates` 命令

**配置升級**: v2.0.0 → v2.1.0

**配置結構**:
```json
{
  "version": "2.1.0",
  "templates": {
    "enabled": false,
    "sync_dir": ".claude/templates",
    "selected": ["spec-template.md", "plan-template.md"]
  }
}
```

## 🔧 支援工具

### batch-sync-all.sh
批次處理多個專案

**模式**:
- 互動模式: 逐個詢問
- 自動模式: `--auto`
- 檢查模式: `--check-only`

### install.sh
全局安裝工具

**功能**:
- 建立 ~/bin/speckit-sync 符號連結
- 設定執行權限
- 跨專案使用

## 📚 文檔組織

### Phase 1 文檔 (docs/phase1/)
- **QUICKSTART_v1.1.md**: 快速開始指南
- **PHASE1_SUMMARY.md**: 功能總覽
- **PHASE1_INTEGRATION.md**: 整合指南
- **PHASE1_EXAMPLES.md**: 使用範例
- **DEPLOYMENT_CHECKLIST.md**: 部署檢查清單

### Phase 2 文檔 (docs/phase2/)
- **phase2-architecture.md**: 架構設計
- **usage-examples.md**: 使用範例
- **integration-guide.md**: 整合指南
- **summary.md**: 功能總覽

### Phase 3 文檔 (docs/phase3/)
- **README.template-sync.md**: 模版同步說明
- **TEMPLATE_SYNC_GUIDE.md**: 詳細指南
- **TEMPLATE_SYNC_SUMMARY.md**: 功能總覽
- **INTEGRATION.md**: 整合建議

## 🎬 使用流程

### 單一專案 (Phase 1)
```bash
cd my-project
~/Documents/GitHub/speckit-sync-tool/sync-commands-enhanced.sh init
~/Documents/GitHub/speckit-sync-tool/sync-commands-enhanced.sh check
~/Documents/GitHub/speckit-sync-tool/sync-commands-enhanced.sh update
```

### 多代理支援 (Phase 2)
```bash
cd my-project
~/Documents/GitHub/speckit-sync-tool/sync-commands-v2.sh init
# 自動偵測 claude, cursor, copilot 等
~/Documents/GitHub/speckit-sync-tool/sync-commands-v2.sh check
~/Documents/GitHub/speckit-sync-tool/sync-commands-v2.sh update
```

### 模版同步 (Phase 3)
```bash
cd my-project
~/Documents/GitHub/speckit-sync-tool/template-sync.sh init
~/Documents/GitHub/speckit-sync-tool/template-sync.sh templates list
~/Documents/GitHub/speckit-sync-tool/template-sync.sh templates sync
```

### 批次處理
```bash
cd ~/Documents/GitHub
./speckit-sync-tool/batch-sync-all.sh --auto
```

## ⚠️ 待整合事項

目前三個階段是獨立的腳本檔案，需要整合成單一工具：

1. **統一入口**: 單一 `sync-commands.sh` 包含所有功能
2. **漸進式啟用**: 根據配置版本啟用對應功能
3. **向後相容**: 確保 v1.0.0 配置仍能使用
4. **統一測試**: 整合測試套件

## 📝 版本演進

```
v1.0.0 → sync-commands.sh
  基礎同步 + 自動更新 spec-kit

v1.1.0 → sync-commands-enhanced.sh
  + 動態命令掃描
  + 新命令偵測

v2.0.0 → sync-commands-v2.sh
  + 13 種 AI 代理支援
  + 自動代理偵測

v2.1.0 → template-sync.sh
  + 模版同步
  + 互動式模版選擇

v3.0.0 (待開發) → 整合版本
  整合所有功能到單一工具
```

## ✅ 已完成清理

所有檔案已從 `/Users/termtek/Documents/GitHub/spec-kit/` 移動到 `/Users/termtek/Documents/GitHub/speckit-sync-tool/`：

- ✅ Phase 2 主檔案: speckit-sync → sync-commands-v2.sh
- ✅ Phase 3 主檔案: speckit-sync-tool.sh → template-sync.sh
- ✅ Phase 2 文檔: claudedocs/* → docs/phase2/
- ✅ Phase 3 文檔: 各種文件 → docs/phase3/
- ✅ Phase 1 文檔: 整理到 docs/phase1/

## 🚀 下一步

1. 整合三個階段的功能到單一工具
2. 更新主要 README 文檔
3. 建立整合測試套件
4. 發布 v3.0.0 版本
