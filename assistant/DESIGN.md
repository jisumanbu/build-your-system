# Personal Assistant Plugin 设计文档

> 基于 Obsidian Vault 的 AI 个人助手系统

## 这个插件适合你吗？

### 适合安装

- 使用 **Obsidian** 管理个人知识库
- 希望 AI 了解你的**完整上下文**（项目、任务、习惯、目标）
- 同时管理**多个生活领域**（工作、副业、学习、生活）
- 想要**自动化**每日复盘和任务管理
- 愿意让 AI 读取和操作你的 Vault 文件

### 不适合安装

- 不使用 Obsidian
- 只需要简单的 AI 问答
- 对隐私极度敏感，不希望 AI 读取个人文件

---

## 初衷：为什么做这个插件？

### 痛点

1. **信息孤岛** — 任务、想法、笔记散落在不同工具，AI 看不到全貌
2. **手动分类负担** — 每条信息都要人工判断该存哪里
3. **复盘困难** — 无法自动追踪时间投入和目标完成情况
4. **AI 断层** — 每次对话都是新开始，AI 不记得你是谁

### 解决方案

将 Obsidian Vault 作为**统一数据层**，让 Claude Code：

- **自动加载上下文** — 启动时读取用户画像、偏好、今日任务
- **智能分类捕获** — 一句话输入，自动识别类型和领域
- **自动化复盘** — 分析 Claude Code 使用记录，对比 MIT 完成情况
- **持久化记忆** — 洞察、模式、偏好存入 Vault，跨会话保持

---

## 方法论：CODE+ × PARA × GTD

### CODE+ 工作流

```
Capture  →  Organize  →  Distill  →  Express
  ↓           ↓           ↓           ↓
 捕获        组织         提炼         输出
```

| 阶段 | 命令前缀 | 核心命令 |
|------|----------|----------|
| **C**apture | `c-` | `/c-capture` 快速捕获，`/c-dump` 脑暴倾倒 |
| **O**rganize | `o-` | `/o-tasks` 任务概览，`/o-review` 每日回顾 |
| **D**istill | `d-` | `/d-distill` 渐进总结，`/d-mine` 选题挖矿 |
| **E**xpress | `e-` | `/e-director` 内容创作，`/e-export` 导出笔记 |

### PARA 目录结构

```
Obsidian Vault/
├── 00-Inbox/          # 统一收集箱
│   ├── capture.md     # 快速捕获入口
│   └── {日期}.md      # 每日日志
├── 10-Projects/       # 有明确目标和截止日期的项目
├── 20-Areas/          # 持续关注的领域
│   ├── media/         # 自媒体
│   ├── indie/         # 独立开发
│   └── outsourcing/   # 外包业务
├── 30-Resources/      # 参考资料
├── 40-Archives/       # 归档
├── 50-GTD/            # 任务管理
│   ├── active.md      # 活跃任务 + 今日 MIT
│   ├── waiting.md     # 等待中
│   ├── someday.md     # 可能/也许
│   └── done.md        # 已完成
└── 60-Memory/         # AI 记忆层
    ├── profile.md     # 用户画像
    ├── preferences.md # 偏好配置
    ├── patterns.md    # 洞察模式
    └── tag-mapping.md # 领域标签配置
```

### GTD 任务状态流

```
Inbox → Active (MIT) → Done
          ↓
       Waiting
          ↓
       Someday
```

---

## 实现架构

### 插件结构

```
assistant/
├── .claude-plugin/
│   └── plugin.json              # 插件元数据 (v1.0.0)
├── commands/                    # 用户命令
│   ├── c-capture.md             # 快速捕获
│   ├── c-dump.md                # 脑暴倾倒
│   ├── o-tasks.md               # 任务概览
│   ├── o-review.md              # 每日回顾 (核心)
│   ├── o-weekly.md              # 每周整合
│   ├── o-schedule.md            # 作息状态
│   ├── d-distill.md             # 渐进式总结
│   ├── d-mine.md                # 选题挖矿
│   ├── e-director.md            # 内容创作全流程
│   ├── e-export.md              # 导出对话
│   ├── a-setup.md               # 初始化设置
│   └── cc-activity.md           # 活动分析
├── skills/                      # 知识库
│   ├── capture-rules/
│   │   └── SKILL.md             # 捕获识别规则
│   └── vault-structure/
│       ├── SKILL.md             # Vault 结构说明
│       └── references/
│           └── file-templates.md
├── hooks/
│   ├── hooks.json               # Hook 配置
│   └── scripts/
│       └── load-context.sh      # SessionStart 加载上下文
└── scripts/
    └── analyze-cc-activity.py   # 分析 Claude Code 活动
```

### 关键设计决策

#### 1. SessionStart 自动上下文加载

每次启动 Claude Code，Hook 自动执行：

```bash
# 检测 Vault 是否已初始化
LINE_COUNT=$(wc -l < "60-Memory/profile.md" 2>/dev/null | tr -d ' ')
if [ "$LINE_COUNT" -gt 5 ]; then
    # 加载用户画像、偏好、今日 MIT
    head -30 "60-Memory/profile.md"
    sed -n '/## 今日重点/,/^---/p' "50-GTD/active.md"
else
    # 引导用户运行 /a-setup
    echo "【重要】请运行 /a-setup 完成初始化"
fi
```

**价值**：AI 立即了解你是谁、你在做什么，无需每次重复说明。

#### 2. 动态领域标签

领域标签不是硬编码，而是用户可配置：

```markdown
# 60-Memory/tag-mapping.md

## #media 自媒体
关键词：视频、选题、拍摄、剪辑、B站

## #indie 独立开发
关键词：产品、SaaS、上线、用户
```

**价值**：不同用户关注不同领域，标签随用户需求变化。

#### 3. `!` 强制执行关键步骤

```markdown
## 前置数据
!`python3 "${CLAUDE_PLUGIN_ROOT}/scripts/analyze-cc-activity.py" $ARGUMENTS`
```

**价值**：脚本在命令加载时自动执行，Claude 无法跳过。避免 AI 自主"优化"掉重要步骤。

#### 4. ⭐ 交互点标记

```markdown
**交互**：⭐ 暂停等用户回答
```

**价值**：明确标记必须等待用户输入的点，防止 AI 自顾自往下执行。

---

## 用户指南

### 快速开始

1. **安装插件**
   ```bash
   # 创建插件目录（如果不存在）
   mkdir -p ~/.claude/plugins
   cd ~/.claude/plugins
   git clone https://github.com/jisumanbu/build-your-system.git
   ```

2. **初始化 Vault**
   ```
   cd /path/to/your/obsidian-vault
   claude
   /a-setup
   ```

3. **开始使用**
   - `/c-capture 明天要开会` — 快速捕获
   - `/o-tasks` — 查看任务概览
   - `/o-review` — 每日回顾

### 典型工作流

#### 早晨：规划

```
/o-tasks
→ 查看今日 MIT 和 Inbox 待处理
```

#### 白天：捕获

```
/c-capture 下周要给客户演示新功能 #outsourcing
→ 自动写入 Inbox，等待晚间分发
```

#### 晚间：回顾

```
/o-review
→ Phase 1: 分发 Inbox 条目
→ Phase 2: 复盘 MIT 完成情况，记录洞察
→ Phase 3: 规划明日 MIT
```

#### 周末：整合

```
/o-weekly
→ 扫描本周内容，生成周报
```

### 命令速查

| 命令 | 用途 |
|------|------|
| `/c-capture <内容>` | 快速捕获到 Inbox |
| `/c-dump` | 自由对话，结束时提取任务和想法 |
| `/o-tasks` | 任务概览 + 智能建议 |
| `/o-review [日期]` | 每日回顾（分发+复盘+规划） |
| `/o-weekly` | 每周整合 |
| `/d-mine` | 从笔记中挖掘选题素材 |
| `/e-director` | 内容创作全流程引导 |
| `/a-setup` | 初始化 Vault 和用户画像 |

---

## 开发路线图

### 已完成 (v1.0.0)

- [x] CODE+ 命令前缀重构（Capture/Organize/Distill/Express）
- [x] PARA+GTD 目录结构
- [x] SessionStart 自动上下文加载
- [x] 动态领域标签配置
- [x] o-review 精简优化（220→80 行）
- [x] cc-activity 强制执行

### 计划中

| 功能 | 优先级 | 状态 |
|------|--------|------|
| 周报自动生成增强 | 高 | 待开发 |
| 更智能的领域识别 | 中 | 待开发 |
| 日历集成（提醒） | 中 | 待调研 |
| 多 Vault 支持 | 低 | 待调研 |
| Web UI 仪表盘 | 低 | 待调研 |

### 贡献方式

欢迎贡献！请查看 [CONTRIBUTING.md](CONTRIBUTING.md)

1. Fork 本仓库
2. 创建功能分支：`git checkout -b feature/your-feature`
3. 提交更改：`git commit -m "feat: add your feature"`
4. 推送分支：`git push origin feature/your-feature`
5. 创建 Pull Request

---

## 技术栈

- **Claude Code** — AI 执行环境
- **Obsidian** — 知识库存储
- **Markdown** — 命令和技能定义
- **Python** — 活动分析脚本
- **Bash** — Hook 脚本

---

## 许可证

MIT License
