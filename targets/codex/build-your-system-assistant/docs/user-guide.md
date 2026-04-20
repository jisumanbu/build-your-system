# Build Your System Assistant 用户指南

## 这是什么

这是 `build-your-system` monorepo 里的 Codex 目标。

它让 Codex 在 Obsidian Vault 里用自然语言完成这些动作：

- 捕获想法、任务、等待项
- 记录间隙日志
- 查看任务概览
- 做每日回顾 / 周回顾
- 查看某天时间线
- 导出当前对话到 Vault
- 读取 Codex 自己的活动记录

它不会改动仓库根目录里的 Claude 目标。

## 目录与关键路径

- 仓库根目录
  - `build-your-system`
- Codex 目标
  - `build-your-system/targets/codex/build-your-system-assistant`
- 本地插件入口
  - `~/plugins/build-your-system-assistant`
- Codex 个人 marketplace 配置
  - `~/.agents/plugins/marketplace.json`
- Codex 仓库 marketplace 配置
  - `build-your-system/.agents/plugins/marketplace.json`
- Codex 启用配置
  - `~/.codex/config.toml`
- Codex 运行时缓存
  - `~/.codex/plugins/cache/local-build-your-system/build-your-system-assistant/local`
- Vault 本地覆盖提示
  - `/Users/jliu/Projects/vault/AGENTS.override.md`

## 安装 / 更新

### 1. 同步本地插件到 Codex 缓存

```bash
cd build-your-system/targets/codex/build-your-system-assistant
./scripts/install-local-plugin.sh
```

### 2. 确认插件已启用

当前配置里应存在：

- `~/.codex/config.toml` 中开启插件能力
- `build-your-system-assistant@local-build-your-system` 已启用

### 3. 确认技能已加载

可以通过 Codex app-server 查询 `plugin/list` 和 `skills/list`。

如果你已经在 Vault 目录里使用 Codex，最直接的判断方式是：

- 说“记一下……”
- 说“基于今天做一次每日回顾”
- 说“导出这次对话到 Vault”

如果能命中对应流程，说明插件已生效。

## 如何使用

### 入口原则

在 Vault 目录里，不需要输入 Claude slash command。

直接用自然语言即可，`assistant-router` 会分发到对应 skill。

### 常见用法

#### 1. 捕获内容

示例：

- `记一下：明天给客户发报价`
- `帮我放进 inbox：给视频补 B-roll`
- `加个任务：整理 Claude 养号流程`

通常会路由到：

- `c-capture`

#### 2. 记录任务切换或分心状态

示例：

- `刚完成插件适配，接下来写用户指南`
- `又刷了 20 分钟，现在回去继续写文档`

通常会路由到：

- `c-pause`

#### 3. 查看任务状态

示例：

- `看一下我当前有哪些活跃任务`
- `帮我看 waiting 和 pause`

通常会路由到：

- `o-tasks`

#### 4. 做每日回顾

示例：

- `基于今天的记录做一次每日回顾`
- `今天回顾一下 inbox 和任务推进`

通常会路由到：

- `o-review`

#### 5. 看某天时间线

示例：

- `看一下 2026-04-08 的时间线`
- `帮我汇总今天的活动轨迹`

通常会路由到：

- `o-timeline`
- 或在内部调用 `cc-activity`

#### 6. 做每周整合

示例：

- `帮我做本周周回顾`
- `把这周任务和产出整理一下`

通常会路由到：

- `o-weekly`

#### 7. 导出当前对话

示例：

- `把这次对话导出成 Obsidian 笔记`
- `导出这次讨论，放到 conversations`

通常会路由到：

- `e-export`

## 活动分析命令

### 文本输出

```bash
python3 "$HOME/plugins/build-your-system-assistant/scripts/analyze-codex-activity.py"
```

### 指定日期 JSON 输出

```bash
python3 "$HOME/plugins/build-your-system-assistant/scripts/analyze-codex-activity.py" 2026-04-08 --json-only
```

适用场景：

- 做每日回顾
- 回看某天做了什么
- 补全时间线

## 验证命令

### 跑测试

```bash
cd build-your-system/targets/codex/build-your-system-assistant
python3 -m unittest discover -s tests -p 'test_*.py' -v
```

### 校验技能 frontmatter

```bash
python3 /tmp/openai-codex/codex-rs/skills/src/assets/samples/skill-creator/scripts/quick_validate.py \
  build-your-system/targets/codex/build-your-system-assistant/skills/assistant-router
```

## 常见问题

### 1. 插件已安装，但 skill 没出现

先检查：

- 是否执行过 `./scripts/install-local-plugin.sh`
- `~/.codex/config.toml` 是否启用了插件
- `skills/list` 是否在当前 cwd 下查询

如果刚改过技能文件，通常要重新运行安装脚本同步缓存。

### 2. 为什么不直接复用原 Claude 目标目录

因为目标是：

- Codex 可用
- Claude 不受影响
- 两者又能在同一个源仓库里统一管理

所以采用“单仓多目标”，而不是继续维护独立副本仓库。

### 3. 为什么不用 slash command

Codex 的 plugin / skill 机制和 Claude Code 不一样。

在这里的策略是：

- 保留原有工作流语义
- 把 slash command 迁移为 skill
- 用自然语言 + `assistant-router` 触发

### 4. 活动分析为什么改了数据源

原 Claude 版本依赖：

- `~/.claude/projects/*.jsonl`

Codex 版改成读取：

- `~/.codex/history.jsonl`
- `~/.codex/session_index.jsonl`
- `~/.codex/sessions/...`

这样才符合 Codex 自身的数据结构。

### 5. 在 Vault 里为什么还要有 `AGENTS.override.md`

这是为了让当前工作区更稳定地优先命中 Codex 版 assistant 工作流。

它不替代主 `AGENTS.md`，只是补一层本地接入提示。

## 推荐使用顺序

如果你是第一次在 Codex 里使用这套插件，建议按下面顺序试：

1. `记一下：明天给客户发报价`
2. `帮我看当前任务概览`
3. `基于今天做一次每日回顾`
4. `把这次对话导出成 Obsidian 笔记`

这四步基本能覆盖：

- 捕获
- 组织
- 回顾
- 导出

如果这四类都能正常工作，说明这套 Codex 版 assistant 已经能稳定用了。
