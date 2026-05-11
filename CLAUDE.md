# Build Your System - Monorepo Guide

基于 Obsidian Vault 的个人效率系统仓库。

## 项目结构

```text
build-your-system/
├── .claude-plugin/            # Claude marketplace 定义
├── .agents/plugins/           # Codex repo marketplace 定义
├── assistant/                 # Claude 目标：任务管理、知识管理
│   ├── .claude-plugin/
│   ├── commands/
│   ├── skills/
│   ├── hooks/
│   └── scripts/
├── media/                     # Claude 目标：短视频创作
│   ├── .claude-plugin/
│   ├── commands/
│   └── skills/
├── claude-notify/             # Claude 目标：通知插件
├── targets/
│   └── codex/
│       └── build-your-system-assistant/
│           ├── .codex-plugin/
│           ├── commands/
│           ├── skills/
│           ├── hooks/
│           ├── scripts/
│           ├── tests/
│           └── docs/
└── examples/
    └── minimal-vault/
```

## Claude 目标修改规则

### 添加或修改 Claude 命令

1. 在 `assistant/commands/` 创建或编辑 `{prefix}-{name}.md`
2. 添加 YAML frontmatter（description, argument-hint）
3. 遵循 CODE+ 命名规范
4. 自动发现，无需修改 plugin.json

### 修改 Claude Skill

1. 编辑 `assistant/skills/{skill-name}/SKILL.md`
2. 更新引用该 skill 的命令

### 修改 Claude Hook

1. 编辑 `assistant/hooks/scripts/load-context.sh`
2. 输出到 stdout 会成为 Claude 上下文
3. exit 0 成功，非 0 失败

### 修改 Claude 活动分析

1. 编辑 `assistant/scripts/analyze-cc-activity.py`
2. 影响 `/o-review`, `/cc-activity`, `/o-timeline`

## Codex 目标修改规则

如果改动的是 Codex 适配版，不要改 `assistant/`，应改：

- `targets/codex/build-your-system-assistant/commands/`
- `targets/codex/build-your-system-assistant/skills/`
- `targets/codex/build-your-system-assistant/scripts/`
- `targets/codex/build-your-system-assistant/tests/`
- `targets/codex/build-your-system-assistant/docs/`

Codex 目标使用的是：

- `.codex-plugin/plugin.json`
- Codex skills
- Codex 本地 marketplace / 缓存安装方式

不要把 Claude 的 hook / slash command 约束直接套到 Codex 目标上。

## Claude 命令规范

### 命令命名

| 前缀 | 阶段 | 示例 |
|------|------|------|
| `c-` | Capture 捕获 | c-capture, c-dump, c-pause |
| `o-` | Organize 组织 | o-tasks, o-review, o-weekly |
| `d-` | Distill 提炼 | d-distill, d-mine |
| `e-` | Express 输出 | e-director, e-export |
| `a-` | Admin 管理 | a-setup |

### 命令模板

```markdown
---
description: "[类别] 简短描述"
argument-hint: "[可选参数]"
---

# 命令名称

**参数**：说明

## 执行流程

### Phase 1: 阶段名
步骤说明...

### Phase 2: 阶段名
**交互**：⭐ 暂停等用户回答
```

### 关键语法

- `⭐` 标记必须暂停等待用户输入的点
- `!` 强制执行（如 `!`python3 script.py``），Claude 无法跳过
- `${CLAUDE_PLUGIN_ROOT}` 为 Claude 插件根目录变量

## 编辑后同步到 Cache（重要）

Claude Code 运行时从 `~/.claude/plugins/cache/build-your-system/<plugin>/<version>/` 加载插件，**不是**从这个 marketplace 源目录。直接编辑这里的文件不会立刻生效，必须先同步到 cache。

```bash
bash scripts/sync-to-cache.sh   # 同步所有已安装插件到对应的 cache 版本
```

仓库已配置 `.git/hooks/post-commit`（未跟踪），每次 commit 后自动跑这个脚本。正常 commit 流程下不需要手动 sync。新克隆仓库后需要手动安装 hook：

```bash
ln -sf ../../scripts/sync-to-cache.sh .git/hooks/post-commit
chmod +x .git/hooks/post-commit
```

`/reload-plugins` 只刷新 plugin 元数据（commands/skills/agents 索引），**不**做文件同步。

## 测试方法

### Claude 本地开发

```bash
ln -s $(pwd)/assistant ~/.claude/plugins/assistant-dev
cd /path/to/test-vault
claude
/a-setup
```

### Codex 本地开发

```bash
cd targets/codex/build-your-system-assistant
./scripts/install-local-plugin.sh
python3 -m unittest discover -s tests -p 'test_*.py' -v
```

## 关键文件

| 文件 | 作用 | 修改影响 |
|------|------|----------|
| `assistant/commands/*.md` | Claude 用户命令 | 直接影响 Claude UX |
| `assistant/skills/capture-rules/SKILL.md` | Claude 标签识别 | 影响 Claude 捕获/分发 |
| `assistant/hooks/scripts/load-context.sh` | Claude 上下文加载 | 影响 Claude 会话 |
| `assistant/scripts/analyze-cc-activity.py` | Claude 活动分析 | 影响 Claude 回顾质量 |
| `targets/codex/build-your-system-assistant/skills/*.md` | Codex 技能 | 影响 Codex 自然语言路由 |
| `targets/codex/build-your-system-assistant/scripts/*` | Codex 工具脚本 | 影响 Codex 安装和活动分析 |

## Commit 规范

```text
<type>(<scope>): <subject>
```

类型：`feat`, `fix`, `refactor`, `docs`, `chore`
