# SpecKit 模版同步工具

快速同步 spec-kit 模版到你的專案。

## 快速開始

### 1. 互動式同步（推薦）

```bash
./speckit-sync-tool.sh sync
```

這會引導你：
1. 選擇要同步的模版
2. 指定目標目錄
3. 自動同步並建立配置

### 2. 一鍵同步所有模版

```bash
./speckit-sync-tool.sh sync --all
```

### 3. 只同步特定模版

```bash
./speckit-sync-tool.sh sync --select spec-template.md,plan-template.md
```

## 常用命令

```bash
# 列出可用模版
./speckit-sync-tool.sh list --details

# 查看同步狀態
./speckit-sync-tool.sh status

# 檢查更新
./speckit-sync-tool.sh check --include-templates

# 更新過時的模版
./speckit-sync-tool.sh update --include-templates

# 預覽不執行
./speckit-sync-tool.sh sync --all --dry-run
```

## 模版說明

| 模版 | 用途 |
|------|------|
| `spec-template.md` | 功能規格定義 |
| `plan-template.md` | 實作計劃 |
| `tasks-template.md` | 任務追蹤 |
| `checklist-template.md` | 品質檢查 |
| `agent-file-template.md` | AI 代理上下文 |
| `vscode-settings.json` | VS Code 設定 |

## 配置

工具會自動建立 `.speckit-sync.json` 配置檔案：

```json
{
  "version": "1.0.0",
  "templates": {
    "enabled": true,
    "sync_dir": ".claude/templates",
    "selected": ["spec-template.md", "plan-template.md"],
    "last_sync": "2025-10-16T12:00:00Z"
  }
}
```

## 完整文檔

詳細使用說明請參考：[docs/TEMPLATE_SYNC_GUIDE.md](docs/TEMPLATE_SYNC_GUIDE.md)

## 需求

- Bash 4.0+
- jq (JSON 處理工具)

安裝 jq：

```bash
# macOS
brew install jq

# Ubuntu/Debian
sudo apt-get install jq
```

## 範例輸出

```
╔══════════════════════════════════════════════════════════╗
║          SpecKit Template Sync Tool v1.0.0          ║
╚══════════════════════════════════════════════════════════╝

▶ 同步模版到: .claude/templates

  + spec-template.md (已建立)
  + plan-template.md (已建立)
  ⟳ tasks-template.md (已更新)
    └─ 備份: tasks-template.md.backup.20251016_120000
  ⊙ checklist-template.md (已是最新)

▶ 同步完成
  成功: 4

✓ 配置已儲存到 .speckit-sync.json
```
