# Build Your System Assistant 架构图

## 目标

这套适配的目标不是替换 Claude Code 插件，而是复制一份独立的 Codex 版本，让 Codex 能用相同的一组 Vault 助手工作流，同时不影响原来的 Claude 环境。

## 总体架构

```text
                                   原始来源（只读，不修改）
                                  build-your-system/assistant
                                                 |
                                                 | 复制一份作为 Codex 副本
                                                 v
                              build-your-system/assistant-codex
                            |
                            |-- .codex-plugin/plugin.json
                            |-- skills/
                            |    |-- assistant-router
                            |    |-- c-capture / c-pause / c-dump
                            |    |-- o-review / o-timeline / o-weekly / o-tasks
                            |    |-- e-export / e-director / d-distill / d-mine
                            |    `-- capture-rules / interstitial-journaling / vault-structure
                            |
                            |-- scripts/
                            |    |-- analyze_codex_activity.py
                            |    |-- analyze-codex-activity.py
                            |    `-- install-local-plugin.sh
                            |
                            `-- tests/
                                 `-- test_analyze_codex_activity.py
                                                 |
                                                 | 可选本地链接入口
                                                 v
                   ~/plugins/build-your-system-assistant  ->  可链接到 assistant-codex/
                                                 |
                         +-----------------------+-----------------------+
                         |                                               |
                         v                                               v
      ~/.agents/plugins/marketplace.json                 ~/.codex/config.toml
      注册本地 marketplace                                  启用插件开关与插件实例
                         |                                               |
                         +-----------------------+-----------------------+
                                                 |
                                                 v
      ~/.codex/plugins/cache/local-build-your-system/build-your-system-assistant/local
                                                 |
                                                 | Codex 运行时从缓存加载 plugin / skills
                                                 v
                                      Codex app-server / skills/list
                                                 |
                                                 v
                                        当前 Obsidian Vault
                                   |
                                   |-- AGENTS.md
                                   `-- AGENTS.override.md
                                       优先把 Vault 助手类请求路由到 assistant-router
```

## 运行时流程

```text
用户自然语言请求
  -> Vault 内的 AGENTS.md / AGENTS.override.md 提示优先使用 build-your-system-assistant
  -> assistant-router 识别请求类型
  -> 路由到具体 skill
     -> capture 类: 写入 00-Inbox 或当日日志
     -> review / timeline / weekly 类: 读取 Vault 文件 + 活动分析脚本
     -> export 类: 输出到 30-Resources/conversations
  -> Codex 返回结果
```

## 关键组件说明

### 1. 插件清单

- `.codex-plugin/plugin.json`
- 定义插件名、描述、skills 根目录和界面元数据。

### 2. 路由层

- `skills/assistant-router/SKILL.md`
- 这是 Codex 版总入口。
- 作用是把“记一下 / 今日回顾 / 导出对话 / 看时间线”这类自然语言请求分发到具体子技能。

### 3. 业务技能层

- `skills/c-*`
  - 负责捕获、倾倒、间隙记录。
- `skills/o-*`
  - 负责组织、回顾、时间线、任务视图、每周整合。
- `skills/d-*`
  - 负责提炼、挖掘。
- `skills/e-*`
  - 负责导出、导演式流程。
- 基础规则技能
  - `capture-rules`
  - `interstitial-journaling`
  - `vault-structure`

### 4. 活动分析层

- `scripts/analyze_codex_activity.py`
- 数据源来自 `~/.codex/history.jsonl`、`~/.codex/session_index.jsonl` 和 session rollout 文件。
- 这是对原 Claude `cc-activity` 依赖 `~/.claude/projects/*.jsonl` 的替换。

### 5. 安装与缓存层

- `assistant-codex/`
  - 仓库内可维护的 Codex 插件源。
- `~/plugins/build-your-system-assistant`
  - 可选的人类友好本地入口，通常通过符号链接指向 `assistant-codex/`。
- `scripts/install-local-plugin.sh`
  - 把当前副本同步到 Codex 实际使用的缓存目录。
- `~/.codex/plugins/cache/.../local`
  - Codex 真正加载 skill 的位置。

## 设计边界

- 不修改原 Claude 插件目录。
- 不要求 Claude 与 Codex 共享运行时缓存。
- Vault 场景下优先以当前 Vault 文件和当前会话上下文为真相来源。
- Claude 专属 slash command 不再作为 Codex 的调用方式，统一改为自然语言 + skill 路由。

## 为什么这样设计

- 隔离性
  - Claude 插件可继续原样使用，不会被 Codex 适配污染。
- 可维护性
  - Codex 版技能、脚本、测试都在独立目录里，便于单独迭代。
- 可验证性
  - skill frontmatter、插件安装状态、活动分析脚本都可以单独校验。
- 可迁移性
  - 如果后续要发布到正式 marketplace，这个目录已经接近标准 Codex plugin 结构。
