# Verbosity 快速參考卡

## 快速開始

```bash
# 安靜模式（CI/CD 適用）
./sync-commands-integrated.sh check --quiet

# 詳細模式（問題排查）
./sync-commands-integrated.sh update --verbose

# 除錯模式（效能分析）
./sync-commands-integrated.sh check --debug
```

## 四種模式對照表

| 模式 | 參數 | 環境變數 | 用途 | 輸出內容 |
|------|------|----------|------|----------|
| **quiet** | `--quiet`, `-q` | `VERBOSITY=quiet` | CI/CD, 自動化 | 僅錯誤訊息 |
| **normal** | (預設) | `VERBOSITY=normal` | 日常使用 | 標準訊息 |
| **verbose** | `--verbose`, `-v` | `VERBOSITY=verbose` | 問題排查 | + debug + timing |
| **debug** | `--debug` | `VERBOSITY=debug` | 效能分析 | 所有訊息 |

## 函數行為對照

| 函數 | quiet | normal | verbose | debug |
|------|-------|--------|---------|-------|
| `log_error()` | ✓ | ✓ | ✓ | ✓ |
| `log_warning()` | ✗ | ✓ | ✓ | ✓ |
| `log_info()` | ✗ | ✓ | ✓ | ✓ |
| `log_success()` | ✗ | ✓ | ✓ | ✓ |
| `log_header()` | ✗ | ✓ | ✓ | ✓ |
| `log_section()` | ✗ | ✓ | ✓ | ✓ |
| `log_debug()` | ✗ | ✗ | ✓ | ✓ |
| `log_verbose()` | ✗ | ✗ | ✓ | ✓ |
| `with_timing()` | ✗ | ✗ | ✓ | ✓ |

## 實用範例

### 場景 1: CI/CD 管道
```bash
#!/bin/bash
# 只顯示錯誤，便於日誌分析
VERBOSITY=quiet ./sync-commands-integrated.sh update --all-agents
if [ $? -ne 0 ]; then
    echo "同步失敗，檢查錯誤訊息"
    exit 1
fi
```

### 場景 2: 批次處理多個專案
```bash
# 安靜模式批次更新，只記錄失敗的專案
./batch-sync-all.sh --auto --quiet 2>&1 | grep "✗" > failed_projects.log
```

### 場景 3: 效能分析
```bash
# 查看每個操作的耗時
./sync-commands-integrated.sh check --debug 2>&1 | grep "耗時"

# 範例輸出：
# 完成: 依賴檢查 (耗時 .003406000s)
# 完成: spec-kit 更新檢查 (耗時 1.234567000s)
```

### 場景 4: 問題排查
```bash
# 詳細模式查看執行過程
./sync-commands-integrated.sh update --agent claude --verbose

# 查看 debug 訊息
./sync-commands-integrated.sh check --debug 2>&1 | grep DEBUG
```

## 組合使用

### 與 dry-run 結合
```bash
# 預覽 + 詳細輸出
./sync-commands-integrated.sh update --dry-run --verbose

# 預覽 + 安靜模式（只看會執行什麼）
./sync-commands-integrated.sh update --dry-run --quiet
```

### 環境變數持久化
```bash
# 在 ~/.bashrc 或 ~/.zshrc 中設定
export VERBOSITY=verbose  # 全域預設為 verbose

# 臨時覆蓋
VERBOSITY=quiet ./sync-commands-integrated.sh check
```

## 輸出重定向技巧

```bash
# 只保存錯誤訊息
./sync-commands-integrated.sh check --quiet 2>errors.log

# 保存所有輸出
./sync-commands-integrated.sh check --verbose &>full.log

# 只看 timing 資訊
./sync-commands-integrated.sh check --debug 2>&1 | grep "耗時"

# 統計各類訊息數量
./sync-commands-integrated.sh check --verbose 2>&1 | grep -c "DEBUG"
```

## 效能考量

### quiet 模式
```bash
# 最快，無輸出開銷
time ./sync-commands-integrated.sh check --quiet
```

### verbose/debug 模式
```bash
# 有 timing 計算開銷（約 0.003s/次）
# 適合問題排查，不適合生產環境高頻調用
```

## 疑難排解

### 問題：輸出沒有顏色
```bash
# 檢查是否為終端環境
[ -t 1 ] && echo "是終端" || echo "非終端"

# 強制彩色輸出（未來功能）
# export FORCE_COLOR=1
```

### 問題：timing 資訊不顯示
```bash
# 確認使用 verbose 或 debug 模式
./sync-commands-integrated.sh check --verbose

# 檢查 bc 是否安裝
which bc || brew install bc
```

### 問題：環境變數不生效
```bash
# 確認優先級：命令列參數 > 環境變數
VERBOSITY=quiet ./sync-commands-integrated.sh check --verbose
# 最終使用 verbose（命令列優先）

# 檢查當前設定
echo $VERBOSITY
```

## 最佳實踐

1. **開發階段**: 使用 `--verbose` 了解執行細節
2. **生產環境**: 使用 `--quiet` 減少日誌噪音
3. **效能分析**: 使用 `--debug` 查看計時資訊
4. **自動化腳本**: 設定 `VERBOSITY=quiet` 環境變數
5. **問題排查**: 先用 `--verbose`，必要時升級到 `--debug`

## 進階用法

### 條件式 verbosity
```bash
#!/bin/bash
# 根據環境自動調整
if [ "$CI" = "true" ]; then
    VERBOSITY=quiet
else
    VERBOSITY=normal
fi

./sync-commands-integrated.sh check
```

### 日誌分級處理
```bash
# 分離不同層級的輸出
./sync-commands-integrated.sh check --verbose \
    2> >(grep "ERROR" > errors.log) \
    1> >(grep "SUCCESS" > success.log)
```

## 相關命令

```bash
# 查看完整幫助
./sync-commands-integrated.sh --help

# 查看當前配置
./sync-commands-integrated.sh status

# 測試 verbosity
./sync-commands-integrated.sh detect-agents --debug
```

---

**版本**: 2.1.0+verbosity  
**更新日期**: 2025-10-16
