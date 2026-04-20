# Build Your System

基于 Obsidian Vault 的个人效率系统仓库。现在采用“单仓多目标”结构：Claude Code 目标保留在仓库根目录，Codex 目标放在 `targets/codex/` 下统一版本管理。

## 当前目标

| 宿主 | 目标路径 | 说明 |
|------|----------|------|
| Claude Code | `assistant/` | 任务管理、知识管理、每日回顾 |
| Claude Code | `media/` | 短视频创作工作流 |
| Claude Code | `claude-notify/` | macOS 通知与跳转辅助 |
| Codex | `targets/codex/build-your-system-assistant/` | Obsidian Vault 助手的 Codex 适配版 |

## 为什么改成单仓多目标

- `build-your-system` 作为唯一 source of truth
- 停止继续维护独立的 `build-your-system-codex` 副本
- 保留各宿主自己的包装层，不强行合并为同一原生插件格式
- 后续如果接入 Cursor 或 MCP 共享层，可以继续在同一仓库演进

## 安装方式

### Claude Code

Claude 目标仍然按原来的 marketplace 结构工作。

```bash
# 在 Claude Code 中运行
/plugin

# Add Marketplace:
jisumanbu/build-your-system
```

可安装目标：

- `assistant`
- `media`
- `claude-notify`

### Codex

Codex 目标位于：

- `targets/codex/build-your-system-assistant`

仓库内已经提供 repo marketplace：

- `.agents/plugins/marketplace.json`

如果你要在本机直接安装这个 Codex 目标，进入目标目录运行：

```bash
cd targets/codex/build-your-system-assistant
./scripts/install-local-plugin.sh
```

这个脚本会：

- 把 `~/plugins/build-your-system-assistant` 指向当前 monorepo 内的 Codex target
- 更新 `~/.agents/plugins/marketplace.json`
- 同步到 Codex 本地缓存目录

## 首次设置

### Claude Code

在 Vault 目录里运行：

```bash
/a-setup
```

### Codex

在 Vault 目录里用自然语言触发即可，或显式调用相关 skill。Codex 目标的详细说明见：

- `targets/codex/build-your-system-assistant/README.md`
- `targets/codex/build-your-system-assistant/docs/user-guide.md`

## 仓库结构

```text
build-your-system/
├── .claude-plugin/
│   └── marketplace.json          # Claude marketplace
├── .agents/
│   └── plugins/
│       └── marketplace.json      # Codex repo marketplace
├── assistant/                    # Claude target
├── media/                        # Claude target
├── claude-notify/                # Claude target
├── targets/
│   └── codex/
│       └── build-your-system-assistant/
│           ├── .codex-plugin/
│           ├── commands/
│           ├── skills/
│           ├── scripts/
│           ├── tests/
│           └── docs/
├── examples/
│   └── minimal-vault/
└── docs/
    └── superpowers/
```

## Vault 前提

推荐的 Vault 结构仍然保持不变：

```text
YourVault/
├── 00-Inbox/
├── 10-Projects/
├── 20-Areas/
├── 30-Resources/
├── 40-Archives/
├── 50-GTD/
└── 60-Memory/
```

## 开发说明

- Claude 相关改动优先落在根目录目标：`assistant/`、`media/`、`claude-notify/`
- Codex 相关改动优先落在 `targets/codex/build-your-system-assistant/`
- 本次只是仓库收敛，不代表 Claude 与 Codex 已经共享同一套内部实现
- 下一阶段再考虑抽取共享 core、共享脚本和 MCP 层

## 许可证

MIT License - 见 [LICENSE](LICENSE)
