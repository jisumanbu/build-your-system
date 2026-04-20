# Build Your System Assistant for Codex

`build-your-system` monorepo 里的 Codex 目标。

## 目标

- 保留原 assistant 的核心工作流：capture、pause、tasks、review、timeline、weekly、export
- 在同一个源仓库里维护 Claude 与 Codex 两个宿主目标
- 通过本地 Codex plugin + skills 方式接入，不依赖独立副本仓库

## 当前路径

- 仓库根目录：`build-your-system/`
- 当前目标：`targets/codex/build-your-system-assistant`
- 本地插件入口：`~/plugins/build-your-system-assistant`
- 个人 marketplace：`~/.agents/plugins/marketplace.json`
- 仓库 marketplace：`build-your-system/.agents/plugins/marketplace.json`

## 文档

- 架构图：`docs/architecture.md`
- 用户指南：`docs/user-guide.md`

## 安装 / 更新

```bash
cd targets/codex/build-your-system-assistant
./scripts/install-local-plugin.sh
```

这个脚本会：

- 把 `~/plugins/build-your-system-assistant` 链接到当前 monorepo target
- 更新 `~/.agents/plugins/marketplace.json`
- 同步到 `~/.codex/plugins/cache/local-build-your-system/build-your-system-assistant/local`

## 活动分析

```bash
python3 "$HOME/plugins/build-your-system-assistant/scripts/analyze-codex-activity.py"
python3 "$HOME/plugins/build-your-system-assistant/scripts/analyze-codex-activity.py" 2026-04-08 --json-only
```

## 验证

```bash
cd targets/codex/build-your-system-assistant
python3 -m unittest discover -s tests -p 'test_*.py' -v
```
