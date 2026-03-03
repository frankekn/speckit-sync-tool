# Spec-Kit 同步工具

> **语言**: [English](README.md) | [繁體中文](README.zh-TW.md) | [简体中文](README.zh-CN.md)

自动同步 [GitHub spec-kit](https://github.com/github/spec-kit) 命令与模板到多个项目的集成工具，支持 13+ 种 AI 编程助手。

> **注意**: 这是一个独立的同步工具，不隶属于官方 spec-kit 项目。

[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](https://opensource.org/licenses/MIT)
[![Version](https://img.shields.io/badge/version-2.1.0-blue.svg)](https://github.com/frankekn/speckit-sync-tool/releases)
[![Bash](https://img.shields.io/badge/bash-5.0+-green.svg)](https://www.gnu.org/software/bash/)

## 📖 文档说明

目前简体中文文档正在完善中。您可以：

1. **阅读英文文档**: [README.md](README.md) - 完整的英文版本
2. **阅读繁体中文文档**: [README.zh-TW.md](README.zh-TW.md) - 完整的繁体中文版本
3. **贡献简体中文翻译**: 欢迎提交 Pull Request 帮助完善简体中文文档

## ✨ 核心功能

### 🚀 阶段 1: 动态命令扫描
- ✅ **自动发现新命令**: 不再写死命令列表，自动侦测 spec-kit 的新命令
- ✅ **交互式选择**: 发现新命令时可选择是否加入同步
- ✅ **命令描述解析**: 从 YAML frontmatter 自动提取命令描述

### 🤖 阶段 2: 多代理支持
- ✅ **13+ 种 AI 代理**: 支持 Claude, Cursor, Copilot, Gemini, Windsurf 等
- ✅ **自动侦测**: 扫描项目中已安装的代理
- ✅ **独立状态管理**: 每个代理独立追踪同步状态
- ✅ **批次或单独更新**: 可一次更新所有代理或指定特定代理

### 📄 阶段 3: 模板同步
- ✅ **spec-kit 模板支持**: 同步官方模板文件
- ✅ **选择性同步**: 交互式选择要同步的模板
- ✅ **独立管理**: 模板与命令分开管理

### 🔄 通用功能
- ✅ **自动更新 spec-kit**: 每次同步前自动检查并更新 spec-kit 仓库
- ✅ **自动备份**: 更新前自动备份，支持回滚
- ✅ **配置自动升级**: v1.0.0 → v2.1.0 自动迁移
- ✅ **批处理**: 一次处理多个项目

## 🎯 为什么需要这个工具？

当你有多个项目使用 spec-kit 的命令时，手动更新每个项目非常麻烦。这个工具可以：

- **自动同步**: spec-kit 更新时自动侦测并同步到所有项目
- **多代理支持**: 同时管理 Claude、Cursor、Copilot 等多种 AI 代理
- **安全可靠**: 自动备份、差异显示、保护自定义命令
- **批量操作**: 一次处理多个项目，省时省力

## 📦 安装

### 方式 1：Git Clone（推荐）

```bash
# Clone 此仓库
cd ~/Documents/GitHub
git clone https://github.com/frankekn/speckit-sync-tool.git

# 全局安装（可选）
cd speckit-sync-tool
./install.sh
```

### 方式 2：直接下载

下载这个仓库的 zip 文件并解压到任意位置。

## 🚀 快速开始

### 使用集成版本（推荐，包含所有功能）

```bash
# 1. 进入你的项目
cd ~/Documents/GitHub/my-project

# 2. 初始化（会自动侦测代理）
~/Documents/GitHub/speckit-sync-tool/sync-commands-integrated.sh init

# 3. 检查更新
~/Documents/GitHub/speckit-sync-tool/sync-commands-integrated.sh check

# 4. 执行同步
~/Documents/GitHub/speckit-sync-tool/sync-commands-integrated.sh update

# 5. 选择并同步模板（可选）
~/Documents/GitHub/speckit-sync-tool/sync-commands-integrated.sh templates select
~/Documents/GitHub/speckit-sync-tool/sync-commands-integrated.sh templates sync

# 6. 反向清理（预览 / 实际执行）
~/Documents/GitHub/speckit-sync-tool/sync-commands-integrated.sh cleanup
~/Documents/GitHub/speckit-sync-tool/sync-commands-integrated.sh cleanup --apply

# 7. 使用主脚本批量清理（无需 batch-sync-all.sh）
~/Documents/GitHub/speckit-sync-tool/sync-commands-integrated.sh cleanup --all-projects
~/Documents/GitHub/speckit-sync-tool/sync-commands-integrated.sh cleanup --all-projects --apply
```

批量清理多个仓库：

```bash
# 预览
~/Documents/GitHub/speckit-sync-tool/batch-sync-all.sh --cleanup

# 实际执行
~/Documents/GitHub/speckit-sync-tool/batch-sync-all.sh --cleanup --apply
```

## 📚 完整文档

请参阅以下文档获取详细信息：

- [English Documentation](README.md) - 英文完整文档
- [繁體中文文檔](README.zh-TW.md) - 繁体中文完整文档
- [Test Report](TEST_REPORT_FINAL.md) - 测试报告（9/10 通过）
- [Phase 1 Documentation](docs/phase1/) - 动态扫描文档
- [Phase 2 Documentation](docs/phase2/) - 多代理支持文档
- [Phase 3 Documentation](docs/phase3/) - 模板同步文档

## 支持的 AI 代理

| 代理名称 | 命令目录 | 侦测方式 |
|---------|---------|---------|
| Claude Code | `.claude/commands` | 自动 |
| Cursor | `.cursor/commands` | 自动 |
| GitHub Copilot | `.github/prompts` | 自动 |
| Gemini CLI | `.gemini/commands` | 自动 |
| Windsurf | `.windsurf/workflows` | 自动 |
| Qwen Code | `.qwen/commands` | 自动 |
| opencode | `.opencode/commands` | 自动 |
| Codex CLI | `.codex/commands` | 自动 |
| Kilo Code | `.kilocode/commands` | 自动 |
| Auggie CLI | `.augment/commands` | 自动 |
| CodeBuddy CLI | `.codebuddy/commands` | 自动 |
| Roo Code | `.roo/commands` | 自动 |
| Amazon Q | `.amazonq/commands` | 自动 |

## ❓ 常见问题

**问：这个工具会修改 spec-kit 本身吗？**
答：不会。这个工具只会读取 spec-kit 的命令文件，并自动更新（git pull）spec-kit 仓库到最新版本。

**问：我的自定义命令会被覆盖吗？**
答：不会。工具只会同步标准命令（来自 spec-kit 的命令），你的自定义命令完全安全。可以在配置中标记为 "custom" 以明确区分。

**问：支持哪些 AI 代理？**
答：目前支持 13+ 种：Claude Code, Cursor, GitHub Copilot, Gemini, Windsurf, Qwen, opencode, Codex, Kilocode, Auggie, CodeBuddy, Roo, Amazon Q。

**问：可以同时使用多个代理吗？**
答：可以！集成版本支持在同一项目中管理多个代理，每个代理独立追踪同步状态。

**问：应该使用哪个版本？**
答：建议使用 `sync-commands-integrated.sh`（集成版），它包含所有功能。如果只需要基础功能，可以使用 `sync-commands.sh`。

## 🤝 贡献

欢迎提交 Issue 和 Pull Request！

特别欢迎帮助完善简体中文文档的贡献者。

## 📄 授权

MIT License

## 🔗 相关链接

- [GitHub spec-kit](https://github.com/github/spec-kit) - 官方 spec-kit 项目
- [Spec-Driven Development](https://github.com/github/spec-kit/blob/main/spec-driven.md) - 方法论说明

## 📝 更新日志

### v2.1.0 (2025-10-16) - 集成版本

- ✨ **集成所有功能**: 将三个阶段合并为单一工具
- ✅ 动态命令扫描（阶段 1）
- ✅ 13+ 种 AI 代理支持（阶段 2）
- ✅ 模板同步功能（阶段 3）
- ✅ 配置自动升级 (v1.0.0 → v2.1.0)
- ✅ 统一 CLI 界面
- ✅ 完整文档与示例
- 🐛 修复 6 个关键 bug，包括循环退出问题

### v2.0.0 (2025-10-16) - 阶段 2

- ✨ 多代理支持
- ✅ 13 种 AI 代理侦测与管理
- ✅ 独立代理状态追踪
- ✅ 交互式代理选择

### v1.1.0 (2025-10-16) - 阶段 1

- ✨ 动态命令扫描
- ✅ 自动发现新命令
- ✅ 交互式新命令选择
- ✅ 命令描述自动解析

### v1.0.0 (2025-10-16) - 初始版本

- ✨ 基础功能实现
- ✅ 单一项目同步（Claude）
- ✅ 批处理多项目
- ✅ 自动备份和回滚
- ✅ 差异显示
- ✅ 自动更新 spec-kit
- ✅ 全局安装支持

---

Made with ❤️ for easier spec-kit management across multiple AI coding agents
