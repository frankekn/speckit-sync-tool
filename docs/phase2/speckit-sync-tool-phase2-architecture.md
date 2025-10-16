# speckit-sync-tool 階段 2：多代理支援架構設計

## 專案概述

speckit-sync-tool 是一個同步工具，用於將 GitHub spec-kit 專案的命令檔案同步到本地專案，支援 13 種 AI 代理。

## 代理映射表

```bash
AGENTS = {
    "claude": ".claude/commands/",
    "copilot": ".github/prompts/",
    "gemini": ".gemini/commands/",
    "cursor": ".cursor/commands/",
    "qwen": ".qwen/commands/",
    "opencode": ".opencode/commands/",
    "codex": ".codex/commands/",
    "windsurf": ".windsurf/workflows/",
    "kilocode": ".kilocode/commands/",
    "auggie": ".augment/commands/",
    "codebuddy": ".codebuddy/commands/",
    "roo": ".roo/commands/",
    "q": ".amazonq/commands/"
}
```

## 核心功能設計

### 1. 代理自動檢測 (`detect_agents()`)

**目的**：掃描專案根目錄，檢測已安裝的 AI 代理

**輸入**：專案根目錄路徑
**輸出**：檢測到的代理列表（agent_name:directory 格式）

**邏輯**：
1. 遍歷 AGENTS 字典
2. 檢查每個代理的目錄是否存在
3. 返回已存在的代理資訊

**輸出範例**：
```
claude:.claude/commands
cursor:.cursor/commands
copilot:.github/prompts
```

### 2. 多代理初始化 (`cmd_init()`)

**目的**：互動式選擇要同步的代理並建立配置

**流程**：
1. 呼叫 `detect_agents()` 檢測現有代理
2. 顯示互動式選單
3. 用戶選擇要啟用的代理
4. 為每個代理建立配置並初始化

**互動範例**：
```
🔍 掃描專案目錄...

🤖 檢測到以下 AI 代理：
  1. ✓ Claude Code (.claude/commands) - 已安裝
  2. ✓ Cursor (.cursor/commands) - 已安裝
  3. ✗ GitHub Copilot (.github/prompts) - 未安裝

選擇要同步的代理（空格分隔，或 Enter 全選已安裝）：
[1,2] > 1 2

✓ 已選擇: Claude Code, Cursor
📝 正在初始化配置...
```

### 3. 多代理同步 (`sync_all_agents()`)

**目的**：為所有啟用的代理同步命令檔案

**流程**：
1. 讀取配置檔案
2. 遍歷所有啟用的代理
3. 為每個代理執行同步邏輯
4. 更新各自的 last_sync 時間
5. 顯示同步狀態

**輸出範例**：
```
🔄 同步代理命令...

  Claude Code (.claude/commands)
    ✓ specify.md (synced)
    ✓ plan.md (synced)
    ✓ tasks.md (synced)

  Cursor (.cursor/commands)
    ✓ specify.md (synced)
    ! custom-cmd.md (customized - skipped)
    ✓ plan.md (synced)

✅ 同步完成！2 個代理已更新
```

### 4. 配置檔案 v2.0.0

**結構設計**：

```json
{
  "version": "2.0.0",
  "source": {
    "repo": "github/spec-kit",
    "branch": "main",
    "last_fetch": "2025-10-16T12:00:00Z"
  },
  "agents": {
    "claude": {
      "enabled": true,
      "commands_dir": ".claude/commands",
      "commands": {
        "standard": [
          "specify.md",
          "plan.md",
          "tasks.md",
          "implement.md"
        ],
        "custom": [],
        "synced": [
          "specify.md",
          "plan.md",
          "tasks.md"
        ],
        "customized": []
      },
      "last_sync": "2025-10-16T12:00:00Z"
    },
    "cursor": {
      "enabled": true,
      "commands_dir": ".cursor/commands",
      "commands": {
        "standard": ["specify.md", "plan.md"],
        "custom": ["custom-cmd.md"],
        "synced": ["specify.md", "plan.md"],
        "customized": []
      },
      "last_sync": "2025-10-16T11:30:00Z"
    },
    "copilot": {
      "enabled": false,
      "commands_dir": ".github/prompts",
      "commands": {
        "standard": [],
        "custom": [],
        "synced": [],
        "customized": []
      },
      "last_sync": null
    }
  },
  "known_commands": [
    "specify.md",
    "plan.md",
    "tasks.md",
    "implement.md",
    "constitution.md",
    "clarify.md",
    "analyze.md",
    "checklist.md"
  ]
}
```

### 5. 配置升級邏輯 (`upgrade_config_to_v2()`)

**目的**：從 v1.x 平滑升級到 v2.0.0

**流程**：
1. 檢測配置版本
2. 備份舊配置 (`.speckit-sync-config.v1.backup.json`)
3. 讀取舊配置資料
4. 自動檢測專案中的代理
5. 遷移資料到新格式
6. 儲存新配置

**向後相容性**：
- v1.0.0 → v2.0.0：遷移 Claude 單代理配置到多代理
- v1.1.0 → v2.0.0：遷移分類系統到多代理

### 6. CLI 命令擴充

```bash
# 代理檢測（不初始化）
speckit-sync detect-agents
# 輸出：
# 🤖 檢測到的代理：
#   ✓ claude (.claude/commands)
#   ✓ cursor (.cursor/commands)
#   ✗ copilot (.github/prompts) - 目錄不存在

# 檢查特定代理
speckit-sync check --agent claude
# 輸出：
# ✓ Claude Code
#   目錄: .claude/commands
#   狀態: 已同步
#   最後同步: 2025-10-16 12:00:00
#   命令: 8 個 (4 synced, 0 custom, 0 customized, 4 available)

# 更新特定代理
speckit-sync update --agent cursor
# 輸出：
# 🔄 更新 Cursor...
# ✓ 3 個命令已同步

# 更新所有代理
speckit-sync update --agent all
# 或
speckit-sync update
# 輸出：
# 🔄 更新所有代理...
# ✓ Claude: 4 個命令已同步
# ✓ Cursor: 3 個命令已同步
# ⚠️ Copilot: 未啟用，跳過
```

## 實作細節

### 錯誤處理策略

1. **代理獨立性**：某個代理失敗不應影響其他代理
2. **部分成功**：顯示詳細的成功/失敗報告
3. **回滾機制**：配置升級失敗時自動回滾到備份

### 並行處理考量

```bash
# 階段 2 先實作順序處理
# 階段 3 再加入並行同步（使用 GNU parallel 或 xargs -P）
sync_agent "claude"
sync_agent "cursor"
sync_agent "copilot"

# 未來並行版本（階段 3）
export -f sync_agent
printf '%s\n' "claude" "cursor" "copilot" | parallel sync_agent
```

### 資料結構設計原則

1. **扁平化**：避免過深的嵌套結構
2. **可擴展**：新增代理不需修改核心邏輯
3. **向後相容**：舊版配置可自動升級
4. **原子性**：配置更新使用臨時檔案 + mv 確保原子性

## 測試計畫

### 單元測試
- [ ] `detect_agents()` - 檢測邏輯
- [ ] `upgrade_config_to_v2()` - 配置升級
- [ ] `sync_single_agent()` - 單代理同步
- [ ] `sync_all_agents()` - 多代理同步

### 整合測試
- [ ] v1.0.0 → v2.0.0 升級
- [ ] v1.1.0 → v2.0.0 升級
- [ ] 多代理同時同步
- [ ] 部分失敗處理

### 邊界測試
- [ ] 無代理目錄的專案
- [ ] 所有代理都安裝的專案
- [ ] 配置檔案損壞
- [ ] 網路連線失敗

## 階段劃分

### 階段 2（本次實作）
- [x] 代理自動檢測
- [x] 多代理初始化
- [x] 配置檔案 v2.0.0
- [x] 配置升級邏輯
- [x] 基本 CLI 命令
- [x] 順序同步

### 階段 3（未來）
- [ ] 並行同步優化
- [ ] 差異檢測優化
- [ ] 增量同步
- [ ] 衝突解決介面
- [ ] 性能監控

## 設計決策

### 為何選擇順序同步？
- **簡單性**：階段 2 優先功能完整性而非效能
- **可靠性**：順序執行更容易除錯和錯誤處理
- **漸進式**：先建立穩固基礎，再優化效能

### 為何獨立追蹤每個代理？
- **靈活性**：不同代理可能有不同的同步策略
- **精確性**：每個代理的狀態獨立管理
- **擴展性**：未來可以為特定代理設定不同的同步頻率

### 為何使用 JSON 配置？
- **結構化**：易於解析和驗證
- **工具支援**：`jq` 提供強大的查詢能力
- **可讀性**：人類可讀，便於除錯
- **版本控制**：易於追蹤配置變更

---

**文檔版本**: 1.0.0
**最後更新**: 2025-10-16
**作者**: Claude Code
