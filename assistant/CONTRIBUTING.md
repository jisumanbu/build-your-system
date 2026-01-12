# 贡献指南

感谢你对 Personal Assistant Plugin 的关注！

## 开发环境

### 前置要求

- Claude Code CLI (v2.0+)
- Obsidian (可选，用于测试)
- Python 3.8+ (用于活动分析脚本)

### 本地开发

1. Clone 仓库
   ```bash
   git clone https://github.com/jisumanbu/build-your-system.git
   cd build-your-system
   ```

2. 链接到 Claude Code plugins 目录
   ```bash
   ln -s $(pwd)/assistant ~/.claude/plugins/assistant-dev
   ```

3. 在 Obsidian Vault 中测试
   ```bash
   cd /path/to/your/vault
   claude
   /a-setup  # 初始化
   ```

## 项目结构

```
assistant/
├── commands/          # 用户命令 (*.md)
├── skills/            # 知识库
├── hooks/             # 自动触发
├── scripts/           # Python/Bash 脚本
├── DESIGN.md          # 设计文档
└── CONTRIBUTING.md    # 本文件
```

## 命令开发规范

### 文件命名

遵循 CODE+ 前缀：
- `c-*.md` — Capture 捕获
- `o-*.md` — Organize 组织
- `d-*.md` — Distill 提炼
- `e-*.md` — Express 输出
- `a-*.md` — Admin 管理

### 命令模板

```markdown
---
description: "[类别] 简短描述"
argument-hint: "[可选参数]"
---

# 命令名称

**参数**：说明

## 执行流程

### Phase 1: 第一阶段
...

### Phase 2: 第二阶段
**交互**：⭐ 暂停等用户回答
```

### 设计原则

1. **精简优先** — 命令模板控制在 100 行以内
2. **明确交互点** — 用 `⭐` 标记必须暂停的地方
3. **引用 Skill** — 详细规则放在 skills/ 中，命令中引用
4. **强制执行** — 关键步骤用 `!` 语法确保执行

## Skill 开发规范

### 文件结构

```
skills/
└── skill-name/
    ├── SKILL.md           # 主文件
    └── references/        # 参考资料
        └── *.md
```

### SKILL.md 格式

```markdown
---
name: Skill Name
description: 触发条件描述
version: 1.0.0
---

# 技能内容
...
```

## Hook 开发规范

### 支持的事件

- `SessionStart` — 会话启动时
- `PreToolUse` — 工具调用前
- `PostToolUse` — 工具调用后

### 脚本规范

- 使用 Bash 或 Python
- 输出到 stdout 会成为 Claude 的上下文
- exit 0 表示成功，非 0 表示失败

## 提交规范

### Commit Message 格式

```
<type>(<scope>): <subject>

<body>
```

### Type

- `feat` — 新功能
- `fix` — Bug 修复
- `refactor` — 重构
- `docs` — 文档
- `chore` — 杂项

### 示例

```
feat(o-review): add activity timeline display

- 整合 cc-activity 数据到回顾视图
- 添加 MIT vs 实际投入对比
```

## Pull Request 流程

1. 确保本地测试通过
2. 更新相关文档
3. 创建 PR，描述改动内容
4. 等待 Review

## 问题反馈

- 使用 GitHub Issues 报告 Bug
- 提供复现步骤和错误信息
- 标注 Claude Code 版本

---

再次感谢你的贡献！
