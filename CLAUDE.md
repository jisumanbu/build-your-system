# Build Your System - Claude Code Plugin

基于 Obsidian Vault 的个人效率系统插件。

## 项目结构

```
build-your-system/
├── assistant/                 # 主插件：任务管理、知识管理
│   ├── .claude-plugin/
│   │   └── plugin.json        # 插件元数据 (v1.0.0)
│   ├── commands/              # 用户命令 (14个)
│   │   ├── c-*.md             # Capture 捕获
│   │   ├── o-*.md             # Organize 组织
│   │   ├── d-*.md             # Distill 提炼
│   │   ├── e-*.md             # Express 输出
│   │   └── a-*.md             # Admin 管理
│   ├── skills/                # 可复用知识
│   │   ├── capture-rules/     # 标签识别规则
│   │   ├── vault-structure/   # Vault 结构说明
│   │   └── interstitial-journaling/  # 间隙日志方法
│   ├── hooks/
│   │   ├── hooks.json         # Hook 配置
│   │   └── scripts/
│   │       └── load-context.sh  # SessionStart 加载上下文
│   └── scripts/
│       └── analyze-cc-activity.py  # 活动分析脚本
├── media/                     # 媒体插件：短视频创作
│   ├── commands/              # m-* 命令
│   └── skills/                # jenny-hoyos-method 等
└── examples/
    └── minimal-vault/         # 测试用最小 Vault
```

## 开发规范

### 命令命名 (CODE+ 前缀)

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

- `⭐` — 标记必须暂停等待用户输入的点
- `!` — 强制执行（如 `!`python3 script.py``），Claude 无法跳过
- `${CLAUDE_PLUGIN_ROOT}` — 插件根目录变量

### Skill 结构

```
skills/skill-name/
├── SKILL.md           # 主文件（含 frontmatter）
└── references/        # 参考资料
```

## 修改指南

### 添加新命令

1. 在 `assistant/commands/` 创建 `{prefix}-{name}.md`
2. 添加 YAML frontmatter（description, argument-hint）
3. 遵循 CODE+ 命名规范
4. 自动发现，无需修改 plugin.json

### 修改 Skill

1. 编辑 `assistant/skills/{skill-name}/SKILL.md`
2. 更新引用该 skill 的命令

### 修改 Hook

1. 编辑 `assistant/hooks/scripts/load-context.sh`
2. 输出到 stdout 会成为 Claude 上下文
3. exit 0 成功，非 0 失败

### 修改活动分析

1. 编辑 `assistant/scripts/analyze-cc-activity.py`
2. 影响 `/o-review`, `/cc-activity`, `/o-timeline`

## 测试方法

### 本地开发

```bash
# 链接到 plugins 目录
ln -s $(pwd)/assistant ~/.claude/plugins/assistant-dev

# 在测试 Vault 中运行
cd /path/to/test-vault
claude
/a-setup  # 初始化
```

### 使用 minimal-vault

```bash
cd examples/minimal-vault
claude
/a-setup
```

### 测试命令

```bash
/c-capture 测试任务 #task    # 测试捕获
/o-tasks                      # 测试任务概览
/o-review                     # 测试每日回顾
/cc-activity 2026-01-16       # 测试活动分析
```

## 关键文件

| 文件 | 作用 | 修改影响 |
|------|------|----------|
| `commands/*.md` | 用户命令 | 直接影响 UX |
| `skills/capture-rules/SKILL.md` | 标签识别 | 影响所有捕获/分发 |
| `hooks/scripts/load-context.sh` | 上下文加载 | 影响每次会话 |
| `scripts/analyze-cc-activity.py` | 活动分析 | 影响回顾质量 |

## Vault 目录结构

```
Vault/
├── 00-Inbox/          # 统一收集箱
├── 10-Projects/       # 项目
├── 20-Areas/          # 领域
├── 30-Resources/      # 资源
├── 40-Archives/       # 归档
├── 50-GTD/            # 任务管理
│   ├── active.md      # 活跃任务 + MIT
│   ├── waiting.md     # 等待中
│   ├── someday.md     # 可能/也许
│   └── done.md        # 已完成
└── 60-Memory/         # AI 记忆层
    ├── profile.md     # 用户画像
    ├── preferences.md # 偏好配置
    └── tag-mapping.md # 领域标签
```

## Commit 规范

```
<type>(<scope>): <subject>

类型：feat, fix, refactor, docs, chore
示例：feat(o-review): add activity timeline display
```
