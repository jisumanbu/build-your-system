---
name: vault-structure
description: This skill should be used when the user asks about "Obsidian Vault paths", "file locations", "task format", "frontmatter templates", or needs to navigate the personal knowledge base structure.
---

# Vault 结构导航 (CODE+ / PARA + GTD)

## Vault 根路径

**当前工作目录即为 Vault 根目录。**

所有工作流默认使用相对路径，用户可以在不同的 Vault 目录运行 Codex。

## 目录结构

```
📁 Vault/
├── 00-Inbox/                    # 统一收集箱 + 日志
│   ├── capture.md               # 所有捕获内容的统一入口
│   └── {YYYY-MM-DD}.md          # 日志 + 复盘（#record 归档位置）
│
├── 10-Projects/                 # PARA: 短期项目（有截止日期）
│   ├── {项目名}.md              # 项目文件（单文件项目）
│   └── {项目名}/                # 项目目录（复杂项目）
│       └── README.md            # 项目主文件
│
├── 20-Areas/                    # PARA: 长期责任领域
│   ├── media/                   # 自媒体
│   │   ├── topics/              # #topic 选题独立文件
│   │   ├── 逐字稿/              # 逐字稿文件
│   │   └── 方法论库/            # 方法论文件
│   ├── indie/                   # 独立开发
│   │   └── ideas/               # #idea 产品想法文件
│   └── outsourcing/             # 外包
│
├── 30-Resources/                # PARA: 知识资源
│
├── 40-Archives/                 # PARA: 归档（不活跃内容）
│
├── 50-GTD/                      # GTD 任务管理
│   ├── active.md                # #task 归档位置（含 MIT）
│   ├── waiting.md               # #waiting 等待中（GTD Waiting For）
│   ├── someday.md               # 将来/也许
│   └── done.md                  # 已完成归档
│
└── 60-Memory/                   # AI 记忆层
    ├── profile.md               # 用户画像
    ├── preferences.md           # 偏好配置（含作息）
    ├── patterns.md              # #insight 归档位置
    └── weekly-summary/          # 周报
```

## 目录编号说明

| 编号 | 目录 | 说明 |
|------|------|------|
| 00 | Inbox | 统一入口 |
| 10 | Projects | 短期项目 |
| 20 | Areas | 长期领域 |
| 30 | Resources | 知识资源 |
| 40 | Archives | 归档 |
| 50 | GTD | 任务管理 |
| 60 | Memory | AI 记忆 |

## Obsidian Tasks 格式

```markdown
- [ ] 任务描述 [[项目名]] #领域 📅 YYYY-MM-DD ⏫
```

### 任务格式组成

| 部分 | 格式 | 必选 | 说明 |
|------|------|------|------|
| 复选框 | `- [ ]` / `- [x]` | ✓ | 任务状态 |
| 描述 | 文本 | ✓ | 任务内容 |
| 项目关联 | `[[项目名]]` | 可选 | 链接到 10-Projects |
| 领域标签 | `#media` / `#indie` 等 | 可选 | 分类用途 |
| 截止日期 | `📅 YYYY-MM-DD` | 可选 | Obsidian Tasks 识别 |
| 优先级 | `⏫` / `🔼` / `🔽` | 可选 | 排序用途 |

### Emoji 含义

| Emoji | 含义 |
|-------|------|
| 📅 | 截止日期 (due) |
| ⏳ | 计划日期 (scheduled) |
| 🛫 | 开始日期 (start) |
| ⏫ | 高优先级 |
| 🔼 | 中优先级 |
| 🔽 | 低优先级 |
| 🔁 | 循环任务 |
| ✅ | 完成日期 |

## 项目文件格式

**Frontmatter**：

```yaml
---
status: active | paused | completed
created: YYYY-MM-DD
target: YYYY-MM-DD  # 可选
area: indie | media | outsourcing  # 关联领域
---
```

**状态流**：`active → paused → completed → 移动到 40-Archives/`

详见 `references/file-templates.md`

## Frontmatter 模板

详见 `references/file-templates.md`
