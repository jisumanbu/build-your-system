# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [3.0.0] - 2026-01-10

### Added
- 升级为 Claude Code Plugin 格式
- 20 个命令（10 个助手命令 + 10 个自媒体命令）
- 5 个可复用 Skills（capture-rules, vault-structure, jenny-hoyos-method, script-writing, transcript-cleaner）
- SessionStart hook 自动加载用户上下文（profile, preferences, active tasks）
- `/a-setup` 首次使用设置向导
- 配置化 VAULT_PATH 支持
- 最小化 Vault 示例 (`examples/minimal-vault/`)

### Changed
- 从独立命令文件迁移到标准 plugin 结构
- load-context.sh 改为读取配置文件而非硬编码路径

### Removed
- 移除旧的 `~/.claude/commands/` 独立命令（已备份）

## [2.x] - Legacy

之前版本使用 `~/.claude/commands/` 独立命令格式，非 plugin 结构。
