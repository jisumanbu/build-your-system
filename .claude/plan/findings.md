# Findings: Assistant Plugin 设计理念提炼

## 1. 初衷（Why）

### 问题背景
- 用户是正在创业的程序员，需要同时管理：独立开发、自媒体、外包项目、生活
- 传统任务管理工具（Notion、滴答清单等）无法与 AI 深度集成
- 碎片化的想法、任务、灵感散落各处，缺乏统一收集和智能分发

### 核心痛点
1. **信息孤岛**：任务、想法、笔记分散在不同工具
2. **手动分类负担**：需要人工判断每条信息该去哪里
3. **复盘困难**：无法自动追踪时间投入和 MIT 完成情况
4. **AI 断层**：AI 不了解用户的完整上下文

## 2. 方法论（What）

### CODE+ 工作流
| 阶段 | 命令前缀 | 含义 |
|------|----------|------|
| Capture | c- | 快速捕获，统一入口 |
| Organize | o- | 分发、回顾、规划 |
| Distill | d- | 提炼洞察、挖掘选题 |
| Express | e- | 输出创作、导出笔记 |

### PARA 目录结构
```
00-Inbox/      → 统一收集箱
10-Projects/   → 有明确目标的项目
20-Areas/      → 持续关注的领域
30-Resources/  → 参考资料
40-Archives/   → 归档
50-GTD/        → 任务管理
60-Memory/     → AI 记忆层
```

### GTD 任务管理
```
50-GTD/
├── active.md   → 活跃任务 + 今日 MIT
├── waiting.md  → 等待他人/事件
├── someday.md  → 可能/也许
└── done.md     → 已完成归档
```

## 3. 架构设计（How）

### 插件结构
```
assistant/
├── .claude-plugin/plugin.json  → 插件元数据
├── commands/                   → 用户可调用的命令
│   ├── c-capture.md           → 捕获
│   ├── c-dump.md              → 脑暴倾倒
│   ├── o-tasks.md             → 任务概览
│   ├── o-review.md            → 每日回顾
│   ├── o-weekly.md            → 每周整合
│   ├── o-schedule.md          → 作息状态
│   ├── d-distill.md           → 渐进式总结
│   ├── d-mine.md              → 选题挖矿
│   ├── e-director.md          → 内容创作全流程
│   └── e-export.md            → 导出对话
├── skills/                     → 知识库
│   ├── capture-rules/         → 捕获识别规则
│   └── vault-structure/       → Vault 结构说明
├── hooks/                      → 自动触发
│   └── scripts/load-context.sh → SessionStart 加载上下文
└── scripts/
    └── analyze-cc-activity.py  → 分析 Claude Code 活动
```

### 关键设计决策

#### 1. SessionStart Hook 自动加载上下文
- 检测 Vault 是否已初始化
- 自动加载用户画像、偏好、今日 MIT
- 未初始化时引导用户运行 /a-setup

#### 2. 动态 tag-mapping
- 领域标签不是硬编码，而是在 /a-setup 时根据用户选择生成
- 存储在 Vault 的 60-Memory/tag-mapping.md
- 用户可随时编辑添加新领域

#### 3. ! 强制执行脚本
- 关键步骤使用 `!` 语法确保执行
- 例如 o-review 前置加载 cc-activity 数据
- 避免 Claude 自主"优化"掉重要步骤

#### 4. 精简命令模板
- 从 220 行精简到 80 行
- 删除冗余格式示例
- 用 ⭐ 标记必须暂停的交互点

## 4. 实际用例

### 用例 1: 快速捕获
```
用户: /c-capture 明天要给客户发报价单
→ AI 识别: #task #outsourcing
→ 写入: 00-Inbox/capture.md
→ 等待 /o-review 分发到 50-GTD/active.md
```

### 用例 2: 每日回顾
```
/o-review 2026-01-10

Phase 1: 分发
- 扫描日志和 Inbox
- 询问用户如何处理

Phase 2: 复盘
- 自动加载 cc-activity 数据
- 展示 MIT vs 实际投入
- 询问感受，引导分析

Phase 3: 明日规划
- 选择 1-3 个 MIT
```

### 用例 3: 选题挖矿
```
/d-mine
→ 扫描 60-Memory/patterns.md
→ 扫描 20-Areas/media/topics/
→ 提取潜在选题素材
```

## 5. 适用人群

### 适合安装
- 使用 Obsidian 管理知识的用户
- 需要 AI 了解自己完整上下文的用户
- 同时管理多个领域（工作、副业、生活）的用户
- 希望自动化复盘和任务管理的用户

### 不适合安装
- 不使用 Obsidian 的用户
- 只需要简单 AI 对话的用户
- 对隐私极度敏感、不希望 AI 读取个人文件的用户

## 6. 未来路线图（待规划）

### 已完成 (v3.1.0)
- [x] CODE+ 命令前缀重构
- [x] PARA+GTD 目录迁移
- [x] SessionStart 自动上下文加载
- [x] 动态 tag-mapping
- [x] o-review 精简优化
- [x] cc-activity 强制执行

### 计划中
- [ ] 更智能的领域识别
- [ ] 周报自动生成
- [ ] 与外部工具集成（日历、提醒）
- [ ] 多 Vault 支持
