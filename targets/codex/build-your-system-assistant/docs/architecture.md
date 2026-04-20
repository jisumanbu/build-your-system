# Build Your System Assistant 架构图

## 目标

这套适配的目标不是替换 Claude Code 插件，而是在同一个 monorepo 里维护一份 Codex 目标，让 Codex 能用相同的一组 Vault 助手工作流，同时不影响原来的 Claude 目标。

## 总体架构

```text
build-your-system/
|
|-- assistant/                                       # Claude target
|-- media/                                           # Claude target
|-- claude-notify/                                   # Claude target
|-- .agents/plugins/marketplace.json                 # Codex repo marketplace
`-- targets/codex/build-your-system-assistant        # Codex target
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
                         | install-local-plugin.sh
                         v
      ~/plugins/build-your-system-assistant   ->   指向当前 monorepo target
                         |
                         v
      ~/.agents/plugins/marketplace.json      ->   个人 marketplace 入口
                         |
                         v
      ~/.codex/plugins/cache/local-build-your-system/build-your-system-assistant/local
                         |
                         v
      Codex runtime / plugin list / skills list
```

## 运行时流程

```text
用户自然语言请求
  -> Vault 内的 AGENTS.override.md 提示优先使用 build-your-system-assistant
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

- `~/plugins/build-your-system-assistant`
  - 指向 monorepo 中 Codex target 的本地入口。
- `scripts/install-local-plugin.sh`
  - 负责创建本地链接、更新个人 marketplace，并同步到 Codex 缓存目录。
- `~/.codex/plugins/cache/.../local`
  - Codex 真正加载 skill 的位置。

## 设计边界

- 不破坏根目录下现有 Claude 目标结构。
- 不要求 Claude 与 Codex 共享运行时缓存。
- Vault 场景下优先以当前 Vault 文件和当前会话上下文为真相来源。
- Claude 专属 slash command 不再作为 Codex 的调用方式，统一改为自然语言 + skill 路由。

## 为什么这样设计

- 单一来源
  - Claude 与 Codex 目标在同一仓库里统一版本管理。
- 宿主隔离
  - 各宿主保留自己的清单、脚本和安装方式，不互相污染。
- 可维护性
  - Codex 目标在 monorepo 下独立成子树，便于单独迭代和后续抽共享层。
- 可验证性
  - skill frontmatter、插件安装状态、活动分析脚本都可以单独校验。
- 可扩展性
  - 后续如果要接入 Cursor 或 MCP 层，可以继续沿着多目标结构扩展。
