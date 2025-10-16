# DRY_RUN 功能實作指南

## 當前狀態

### 已完成的修改:
1. ✅ **全局變數**: `DRY_RUN=false` 已添加在第34行
2. ✅ **輔助函數**: `dry_run_execute()` 已添加在第164-175行

### 待完成的修改:

## Edit #3: sync_command() 函數 (第773-796行)

**位置**: 第793-794行
**當前代碼**:
```bash
    mkdir -p "$(dirname "$target")"
    cp "$source" "$target"
```

**修改為**:
```bash
    dry_run_execute "建立目錄: $(dirname "$target")" mkdir -p "$(dirname "$target")"
    dry_run_execute "複製檔案: $source → $target" cp "$source" "$target"
```

---

## Edit #4: update_commands() 函數 - 備份創建 (第862-926行)

**位置**: 第878-884行
**當前代碼**:
```bash
    # 建立備份
    local backup_dir="$PROJECT_ROOT/$commands_dir/.backup/$(date +%Y%m%d_%H%M%S)"
    mkdir -p "$backup_dir"

    if [[ -d "$PROJECT_ROOT/$commands_dir" ]]; then
        cp -r "$PROJECT_ROOT/$commands_dir"/*.md "$backup_dir/" 2>/dev/null || true
        log_info "📦 建立備份: $backup_dir"
    fi
```

**修改為**:
```bash
    # 建立備份
    local backup_dir="$PROJECT_ROOT/$commands_dir/.backup/$(date +%Y%m%d_%H%M%S)"
    dry_run_execute "建立備份目錄: $backup_dir" mkdir -p "$backup_dir"

    if [[ -d "$PROJECT_ROOT/$commands_dir" ]]; then
        dry_run_execute "備份現有命令檔案" cp -r "$PROJECT_ROOT/$commands_dir"/*.md "$backup_dir/" 2>/dev/null || true
        log_info "💾 建立備份: $backup_dir"
    fi
```

---

## Edit #5: templates_sync() 函數 (第653-686行)

**位置 1**: 第661行
**當前代碼**:
```bash
    # 確保目標目錄存在
    mkdir -p "$sync_dir"
```

**修改為**:
```bash
    # 確保目標目錄存在
    dry_run_execute "建立模版同步目錄: $sync_dir" mkdir -p "$sync_dir"
```

**位置 2**: 第675行
**當前代碼**:
```bash
        cp "$src" "$dest"
```

**修改為**:
```bash
        dry_run_execute "同步模版: $tpl → $dest" cp "$src" "$dest"
```

---

## Edit #6: show_usage() 函數 (第1044-1104行)

**位置**: 第1067行之後
**當前代碼**:
```bash
選項:
    --agent <name>               指定要操作的代理
    --all-agents                 自動偵測並處理所有代理（忽略配置檔啟用狀態）
    --quiet, -q                  安靜模式（僅顯示錯誤）
```

**修改為**:
```bash
選項:
    --agent <name>               指定要操作的代理
    --all-agents                 自動偵測並處理所有代理（忽略配置檔啟用狀態）
    --dry-run, -n                預覽模式（顯示將執行的操作但不實際執行）
    --quiet, -q                  安靜模式（僅顯示錯誤）
```

---

## Edit #7: main() 函數參數解析 (第1155-1315行)

**位置**: 第1171行之後
**當前代碼**:
```bash
            --all-agents)
                all_agents=true
                shift
                ;;
            --quiet|-q)
                VERBOSITY="quiet"
                shift
                ;;
```

**修改為**:
```bash
            --all-agents)
                all_agents=true
                shift
                ;;
            --dry-run|-n)
                DRY_RUN=true
                shift
                ;;
            --quiet|-q)
                VERBOSITY="quiet"
                shift
                ;;
```

---

## 測試命令

修改完成後,使用以下命令測試:

```bash
# 測試 dry-run 模式
./sync-commands-integrated.sh update --dry-run

# 測試指定代理的 dry-run
./sync-commands-integrated.sh update --agent claude --dry-run

# 測試模版同步的 dry-run
./sync-commands-integrated.sh templates sync --dry-run

# 測試正常模式(確保沒有破壞原有功能)
./sync-commands-integrated.sh check
```

## 預期輸出

Dry-run 模式下應該看到:

```
[DRY-RUN] 建立備份目錄: /path/to/backup
    指令: mkdir -p /path/to/backup
[DRY-RUN] 複製檔案: /source/file.md → /target/file.md
    指令: cp /source/file.md /target/file.md
```

## 實作優先順序

1. **高優先級**: Edit #3 (sync_command) - 核心同步功能
2. **高優先級**: Edit #4 (update_commands) - 批量更新功能
3. **中優先級**: Edit #5 (templates_sync) - 模版同步功能
4. **低優先級**: Edit #6, #7 (使用說明和參數解析) - 使用者介面

## 相容性說明

- `dry_run_execute` 函數在 DRY_RUN=false 時會正常執行命令
- 所有現有功能應該保持不變
- 新增 --dry-run 選項不會影響現有的命令列參數
