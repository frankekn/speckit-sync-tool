# Spec-Kit Sync Tool

> **Language**: [English](README.md) | [繁體中文](README.zh-TW.md) | [简体中文](README.zh-CN.md)

Automated tool to sync [GitHub spec-kit](https://github.com/github/spec-kit) commands and templates across multiple projects with support for 13+ AI coding agents.

> **Note**: This is an independent sync tool, not affiliated with the official spec-kit project.

[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](https://opensource.org/licenses/MIT)
[![Version](https://img.shields.io/badge/version-2.1.0-blue.svg)](https://github.com/frankekn/speckit-sync-tool/releases)
[![Bash](https://img.shields.io/badge/bash-5.0+-green.svg)](https://www.gnu.org/software/bash/)

## ✨ Core Features

### 🚀 Phase 1: Dynamic Command Scanning
- ✅ **Auto-discover new commands**: No hardcoded command lists, automatically detects new spec-kit commands
- ✅ **Interactive selection**: Choose which new commands to sync when discovered
- ✅ **Command description parsing**: Auto-extracts descriptions from YAML frontmatter

### 🤖 Phase 2: Multi-Agent Support
- ✅ **13+ AI agents**: Support for Claude, Cursor, Copilot, Gemini, Windsurf, and more
- ✅ **Auto-detection**: Scans projects for installed agents
- ✅ **Independent state management**: Each agent tracks sync status independently
- ✅ **Batch or individual updates**: Update all agents at once or target specific ones

### 📄 Phase 3: Template Sync
- ✅ **spec-kit template support**: Sync official template files
- ✅ **Selective sync**: Interactive selection of templates to sync
- ✅ **Independent management**: Templates and commands managed separately

### 🔄 Universal Features
- ✅ **Auto-update spec-kit**: Automatically checks and updates spec-kit repository before syncing
- ✅ **Auto-backup**: Creates backups before updates with rollback support
- ✅ **Config auto-upgrade**: Automatic migration from v1.0.0 → v2.1.0
- ✅ **Batch processing**: Process multiple projects at once

## 🎯 Why This Tool?

When you have multiple projects using spec-kit commands, manually updating each project is tedious. This tool helps you:

- **Automatic sync**: Auto-detect and sync spec-kit updates across all projects
- **Multi-agent support**: Manage Claude, Cursor, Copilot, and more in one place
- **Safe and reliable**: Auto-backup, diff display, protect custom commands
- **Batch operations**: Process multiple projects at once, save time

## 📦 Installation

### Method 1: Git Clone (Recommended)

```bash
# Clone this repository
cd ~/Documents/GitHub
git clone https://github.com/frankekn/speckit-sync-tool.git

# Global installation (optional)
cd speckit-sync-tool
./install.sh
```

### Method 2: Direct Download

Download the repository ZIP file and extract to any location.

## 🚀 Quick Start

### Using Integrated Version (Recommended, includes all features)

```bash
# 1. Navigate to your project
cd ~/Documents/GitHub/my-project

# 2. Initialize (auto-detects agents)
~/Documents/GitHub/speckit-sync-tool/sync-commands-integrated.sh init

# 3. Check for updates
~/Documents/GitHub/speckit-sync-tool/sync-commands-integrated.sh check

# 4. Execute sync
~/Documents/GitHub/speckit-sync-tool/sync-commands-integrated.sh update

# 5. Select and sync templates (optional)
~/Documents/GitHub/speckit-sync-tool/sync-commands-integrated.sh templates select
~/Documents/GitHub/speckit-sync-tool/sync-commands-integrated.sh templates sync
```

### Using Basic Version (Claude only)

```bash
# If you only need Claude command sync
~/Documents/GitHub/speckit-sync-tool/sync-commands.sh init
~/Documents/GitHub/speckit-sync-tool/sync-commands.sh check
~/Documents/GitHub/speckit-sync-tool/sync-commands.sh update
```

### Batch Sync Multiple Projects

```bash
# Auto-scan and sync all projects
~/Documents/GitHub/speckit-sync-tool/batch-sync-all.sh

# Or auto mode (no prompts)
~/Documents/GitHub/speckit-sync-tool/batch-sync-all.sh --auto
```

### Using Global Commands (requires installation)

```bash
# Available in any project directory
cd ~/Documents/GitHub/any-project
speckit-sync init
speckit-sync check
speckit-sync update
```

> **💡 Tip**: Each time you run `check` or `update`, the tool automatically checks if spec-kit has a new version and performs `git pull`. No manual updates needed!

## 📚 Complete Feature Guide

### Integrated Version Commands

#### Basic Commands

```bash
# Initialize configuration (detects all agents)
./sync-commands-integrated.sh init

# Detect available AI agents
./sync-commands-integrated.sh detect-agents

# Check updates for all agents
./sync-commands-integrated.sh check

# Check specific agent
./sync-commands-integrated.sh check --agent claude

# Update all agents
./sync-commands-integrated.sh update

# Update specific agent
./sync-commands-integrated.sh update --agent cursor

# Display configuration status
./sync-commands-integrated.sh status
```

#### Dynamic Command Scanning

```bash
# Scan and add new commands (requires agent)
./sync-commands-integrated.sh scan --agent claude
```

#### Template Management

```bash
# List available templates
./sync-commands-integrated.sh templates list

# Select templates to sync
./sync-commands-integrated.sh templates select

# Sync selected templates
./sync-commands-integrated.sh templates sync
```

#### Configuration Management

```bash
# Upgrade configuration version
./sync-commands-integrated.sh upgrade
```

### Supported AI Agents

| Agent Name | Command Directory | Detection |
|-----------|------------------|-----------|
| Claude Code | `.claude/commands` | Auto |
| Cursor | `.cursor/commands` | Auto |
| GitHub Copilot | `.github/prompts` | Auto |
| Gemini CLI | `.gemini/commands` | Auto |
| Windsurf | `.windsurf/workflows` | Auto |
| Qwen Code | `.qwen/commands` | Auto |
| opencode | `.opencode/commands` | Auto |
| Codex CLI | `.codex/commands` | Auto |
| Kilo Code | `.kilocode/commands` | Auto |
| Auggie CLI | `.augment/commands` | Auto |
| CodeBuddy CLI | `.codebuddy/commands` | Auto |
| Roo Code | `.roo/commands` | Auto |
| Amazon Q | `.amazonq/commands` | Auto |

### Environment Variables

```bash
# Set spec-kit path
export SPECKIT_PATH=/custom/path/to/spec-kit

# Set GitHub directory (for batch processing)
export GITHUB_DIR=/custom/path/to/github
```

## 📖 Detailed Usage Examples

### Scenario 1: New Project Initialization

```bash
cd my-new-project

# Initialize configuration, tool auto-detects agents in project
~/speckit-sync-tool/sync-commands-integrated.sh init

# Output:
# Detecting AI Agents
# ✓ Claude Code (.claude/commands)
# ✓ Cursor (.cursor/commands)
#
# Select agents to enable (Space to select, Enter to confirm):
# [1] Claude Code (.claude/commands) [Y/n] y
# [2] Cursor (.cursor/commands) [Y/n] y
#
# Detected 8 standard commands
# ✓ Initialization complete!
```

### Scenario 2: Regular Update Checks

```bash
# Check updates for all agents
./sync-commands-integrated.sh check

# Output:
# Checking Claude Code Updates
# ℹ spec-kit is up to date (0.0.20)
#
# ✓ analyze.md - up to date
# ✓ checklist.md - up to date
# ↻ implement.md - update available
# ⊕ new-command.md - not found locally (new command)
#
# Statistics:
#   ✅ Synced: 6
#   ⊕  Missing: 1
#   ↻  Outdated: 1
#
# ⚠ Found 2 commands requiring update
```

### Scenario 3: Scanning New Commands

```bash
# Scan spec-kit for new commands
./sync-commands-integrated.sh scan --agent claude

# Output:
# Scanning New Commands (claude)
# ℹ Found 2 new commands:
#   ⊕ refactor.md - Code refactoring
#   ⊕ review.md - Code review
#
# Add these new commands to sync list? [y/N] y
# ✓ Added 2 new commands to configuration
```

### Scenario 4: Template Sync

```bash
# List available templates
./sync-commands-integrated.sh templates list

# Output:
# Available Templates
#
# [ 1]   spec-template.md
# [ 2]   plan-template.md
# [ 3]   tasks-template.md
# [ 4] ✓ checklist-template.md

# Select templates to sync
./sync-commands-integrated.sh templates select

# Sync selected templates
./sync-commands-integrated.sh templates sync
# ✓ spec-template.md - synced
# ✓ plan-template.md - synced
# ✓ Synced 2 templates to .claude/templates
```

### Scenario 5: Multi-Agent Management

```bash
# Update only Claude agent
./sync-commands-integrated.sh update --agent claude

# Update all enabled agents
./sync-commands-integrated.sh update

# Output:
# Syncing Claude Code Commands
# ... (Claude sync results)
#
# Syncing Cursor Commands
# ... (Cursor sync results)
```

## ⚙️ Configuration File

### v2.1.0 Configuration Structure (Integrated Version)

```json
{
  "version": "2.1.0",
  "source": {
    "type": "local",
    "path": "/path/to/spec-kit",
    "version": "0.0.20"
  },
  "strategy": {
    "mode": "semi-auto",
    "on_conflict": "ask",
    "auto_backup": true,
    "backup_retention": 5
  },
  "agents": {
    "claude": {
      "enabled": true,
      "commands_dir": ".claude/commands",
      "commands": {
        "standard": ["specify.md", "plan.md", "tasks.md", ...],
        "custom": ["my-command.md"],
        "synced": [],
        "customized": []
      }
    },
    "cursor": {
      "enabled": true,
      "commands_dir": ".cursor/commands",
      "commands": {...}
    }
  },
  "templates": {
    "enabled": true,
    "sync_dir": ".claude/templates",
    "selected": ["spec-template.md", "plan-template.md"],
    "last_sync": "2025-10-16T12:30:00Z"
  },
  "metadata": {
    "project_name": "my-project",
    "initialized": "2025-10-16T11:36:00Z",
    "last_check": "2025-10-16T12:00:00Z",
    "total_syncs": 3
  }
}
```

### Configuration Version Upgrade Path

Tool automatically upgrades configuration versions, no manual operation needed:

```
v1.0.0 (Basic)
  ↓
v1.1.0 (+ Dynamic Scanning)
  ↓
v2.0.0 (+ Multi-Agent)
  ↓
v2.1.0 (+ Templates)
```

## 💡 Best Practices

### 1. Use Integrated Version

```bash
# Recommend using integrated version for all features
ln -s ~/Documents/GitHub/speckit-sync-tool/sync-commands-integrated.sh ~/bin/speckit-sync
```

### 2. Regular Update Checks

```bash
# Recommend running weekly
cd ~/Documents/GitHub
./speckit-sync-tool/batch-sync-all.sh --check-only
```

### 3. Protect Custom Commands

Mark your custom commands in configuration:

```json
{
  "agents": {
    "claude": {
      "commands": {
        "custom": [
          "my-special-command.md",
          "project-specific-task.md"
        ]
      }
    }
  }
}
```

### 4. Multi-Agent Sync Strategy

```bash
# Option A: All agents use same commands (recommended)
./sync-commands-integrated.sh update

# Option B: Different agents managed independently
./sync-commands-integrated.sh update --agent claude
./sync-commands-integrated.sh update --agent cursor
```

### 5. Template Management

```bash
# Only sync templates you need
./sync-commands-integrated.sh templates select
# Select spec-template.md and plan-template.md

# Sync when needed
./sync-commands-integrated.sh templates sync
```

### 6. Backup and Rollback

```bash
# Backup location (auto-created on each update)
ls .claude/commands/.backup/

# Rollback to specific version
cp .claude/commands/.backup/20251016_120000/*.md .claude/commands/
```

## 📊 Project Structure

```
speckit-sync-tool/
├── sync-commands-integrated.sh  # Integrated v2.1.0 (recommended)
├── sync-commands-enhanced.sh    # Phase 1 v1.1.0
├── sync-commands-v2.sh          # Phase 2 v2.0.0
├── template-sync.sh             # Phase 3 v2.1.0
├── sync-commands.sh             # Basic v1.0.0
├── batch-sync-all.sh            # Batch processing tool
├── install.sh                   # Global installation script
├── test-phase1.sh               # Phase 1 test suite
├── .speckit-sync.json.template  # Config file template
├── Makefile.template            # Makefile template
├── LICENSE                      # MIT License
├── README.md                    # This document
├── README.zh-TW.md              # Traditional Chinese
├── README.zh-CN.md              # Simplified Chinese
├── DELIVERY_SUMMARY.md          # Delivery file overview
├── TEST_REPORT_FINAL.md         # Comprehensive test report
└── docs/
    ├── phase1/                  # Phase 1 documentation
    │   ├── QUICKSTART_v1.1.md
    │   ├── PHASE1_SUMMARY.md
    │   └── ...
    ├── phase2/                  # Phase 2 documentation
    │   ├── speckit-sync-tool-phase2-architecture.md
    │   └── ...
    └── phase3/                  # Phase 3 documentation
        ├── README.template-sync.md
        └── ...
```

## 🔧 Advanced Usage

### Custom spec-kit Path

```bash
SPECKIT_PATH=/custom/path/to/spec-kit ./sync-commands-integrated.sh check
```

### CI/CD Integration

```yaml
# .github/workflows/sync-speckit.yml
name: Sync Spec-Kit Commands

on:
  schedule:
    - cron: '0 9 * * 1'  # Every Monday at 9:00 AM
  workflow_dispatch:

jobs:
  sync:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v3

      - name: Check spec-kit updates
        run: |
          git clone https://github.com/github/spec-kit.git /tmp/spec-kit
          SPECKIT_PATH=/tmp/spec-kit ./sync-commands-integrated.sh check
```

### Makefile Integration

```bash
# Copy Makefile template
cp ~/Documents/GitHub/speckit-sync-tool/Makefile.template my-project/.claude/Makefile

# Use in project
make -C .claude sync-check
make -C .claude sync-update
make -C .claude sync-status
```

## 🐛 Troubleshooting

### Issue 1: spec-kit Not Found

```
✗ Invalid spec-kit path: /Users/termtek/Documents/GitHub/spec-kit
```

**Solution**:

```bash
# Check if spec-kit exists
ls ~/Documents/GitHub/spec-kit

# Set correct path
export SPECKIT_PATH=/correct/path/to/spec-kit
```

### Issue 2: No Agents Detected

```
✗ No AI agent directories detected
```

**Solution**:

```bash
# Ensure project has agent directories
mkdir -p .claude/commands
# or
mkdir -p .cursor/commands
```

### Issue 3: Permission Error

**Solution**:

```bash
chmod +x ~/Documents/GitHub/speckit-sync-tool/*.sh
```

### Issue 4: Outdated Configuration Version

**Solution**:

```bash
# Auto-upgrade configuration
./sync-commands-integrated.sh upgrade
```

### Issue 5: Template Sync Failed

**Solution**:

```bash
# Check if spec-kit has templates directory
ls $SPECKIT_PATH/templates

# If not present, spec-kit may not support templates yet
```

## ❓ FAQ

**Q: Will this tool modify spec-kit itself?**
A: No. This tool only reads command files from spec-kit and auto-updates (git pull) the spec-kit repository to the latest version.

**Q: Will my custom commands be overwritten?**
A: No. The tool only syncs standard commands (from spec-kit), your custom commands are completely safe. You can mark them as "custom" in configuration for explicit distinction.

**Q: What if I modified a standard command?**
A: The tool will detect the difference and show it as "outdated" status. You can:
- Accept new version: Run update (will overwrite your modifications)
- Keep modifications: Mark as "customized" in configuration

**Q: Which AI agents are supported?**
A: Currently supports 13+: Claude Code, Cursor, GitHub Copilot, Gemini, Windsurf, Qwen, opencode, Codex, Kilocode, Auggie, CodeBuddy, Roo, Amazon Q.

**Q: Can I use multiple agents simultaneously?**
A: Yes! The integrated version supports managing multiple agents in the same project, each agent tracks sync status independently.

**Q: Will new commands in spec-kit be auto-detected?**
A: Yes! Use the `scan` command to scan for new commands in spec-kit and interactively choose whether to add them to the sync list.

**Q: What is the template feature?**
A: The template feature syncs spec-kit template files (like spec-template.md), giving you standard formats to reference when creating new documents.

**Q: Can I lock to a specific version?**
A: Currently doesn't support version locking, but you can avoid running update to keep the current version. spec-kit will auto-update to the latest version.

**Q: Does it support Windows?**
A: Yes. Run in Git Bash or WSL.

**Q: Which version should I use?**
A: Recommend using `sync-commands-integrated.sh` (integrated version), it includes all features. If you only need basic functionality, use `sync-commands.sh`.

## 🤝 Contributing

Issues and Pull Requests are welcome!

## 📄 License

MIT License

## 🔗 Related Links

- [GitHub spec-kit](https://github.com/github/spec-kit) - Official spec-kit project
- [Spec-Driven Development](https://github.com/github/spec-kit/blob/main/spec-driven.md) - Methodology documentation

## 📝 Changelog

### v2.1.0 (2025-10-16) - Integrated Release

- ✨ **Integrate all features**: Merged three phases into single tool
- ✅ Dynamic command scanning (Phase 1)
- ✅ 13+ AI agent support (Phase 2)
- ✅ Template sync functionality (Phase 3)
- ✅ Config auto-upgrade (v1.0.0 → v2.1.0)
- ✅ Unified CLI interface
- ✅ Complete documentation and examples
- 🐛 Fixed 6 critical bugs including loop exit issue

### v2.0.0 (2025-10-16) - Phase 2

- ✨ Multi-agent support
- ✅ 13 AI agent detection and management
- ✅ Independent agent state tracking
- ✅ Interactive agent selection

### v1.1.0 (2025-10-16) - Phase 1

- ✨ Dynamic command scanning
- ✅ Auto-discover new commands
- ✅ Interactive new command selection
- ✅ Command description auto-parsing

### v1.0.0 (2025-10-16) - Initial Release

- ✨ Basic functionality implementation
- ✅ Single project sync (Claude)
- ✅ Batch processing for multiple projects
- ✅ Auto-backup and rollback
- ✅ Diff display
- ✅ Auto-update spec-kit
- ✅ Global installation support

---

Made with ❤️ for easier spec-kit management across multiple AI coding agents
