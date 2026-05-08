# coding-anywhere (Codex 适配版)

本目录是 [`coding-anywhere`](../../../coding-anywhere/) 插件的 Codex 适配版本。skills 内容与主插件完全一致，仅元数据和安装路径不同。

---

## 安装

```bash
./scripts/install-local-plugin.sh
```

脚本会：

1. 在 `~/plugins/coding-anywhere` 创建指向本目录的符号链接
2. 把插件信息写入 `~/.agents/plugins/marketplace.json`（个人本地 marketplace）
3. 把目录同步到 `~/.codex/plugins/cache/local-build-your-system/coding-anywhere/local/`

---

## 使用

启动 Codex 后，用自然语言描述需求即可触发 skill：

```
帮我搭一套从 iPhone 连回家里 Mac 的远程开发环境
```

或者直接用插件提供的"一键复刻提示词"（见主 README）：

```
我想搭建一套"随时随地远程开发"的方案……
（完整提示词见 ../../../coding-anywhere/README.md）
```

skill 会引导你完成所有步骤：环境评估 → 方案选型 → 配置生成 → 验收清单。

---

## 与 Claude Code 版本的差异

| 项 | Claude Code | Codex |
|----|-------------|-------|
| skills 内容 | 同 | 同 |
| 触发方式 | skill description 自动匹配 | 自然语言或 defaultPrompt |
| 元数据格式 | `.claude-plugin/plugin.json` | `.codex-plugin/plugin.json`（含 `interface.*`） |
| 安装路径 | `~/.claude/plugins/...` | `~/.codex/plugins/cache/...` |

---

## 升级

主插件更新后，重跑 `./scripts/install-local-plugin.sh` 即可同步到 codex cache。
