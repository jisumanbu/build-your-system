# Build Your System Assistant for Codex

Codex 版 Obsidian Vault 助手副本。

## 目标

- 保留原 assistant 的核心工作流：capture、pause、tasks、review、timeline、weekly、export
- 不修改原 Claude 插件目录
- 通过本地 Codex plugin + skills 方式接入

## 仓库结构

- 仓库目录：`assistant-codex/`
- 插件清单：`.codex-plugin/plugin.json`
- 技能目录：`skills/`
- 脚本目录：`scripts/`
- 测试目录：`tests/`

## 文档

- 架构图：`docs/architecture.md`
- 用户指南：`docs/user-guide.md`

## 安装 / 更新

```bash
cd assistant-codex
./scripts/install-local-plugin.sh
```

如果你习惯把插件源链接到 `~/plugins/build-your-system-assistant`，这个脚本也兼容；默认会直接把当前目录当作插件源。

## 活动分析

```bash
python3 "$HOME/plugins/build-your-system-assistant/scripts/analyze-codex-activity.py"
python3 "$HOME/plugins/build-your-system-assistant/scripts/analyze-codex-activity.py" 2026-04-08 --json-only
```

## 验证

```bash
cd assistant-codex
python3 -m unittest discover -s tests -p 'test_*.py' -v
```
