---
name: Vault Structure
description: This skill should be used when the user asks about "Obsidian Vault paths", "file locations", "task format", "frontmatter templates", or needs to navigate the personal knowledge base structure.
version: 2.0.0
---

# Vault 结构导航 (CODE+ / PARA + GTD)

## Vault 根路径

**当前工作目录即为 Vault 根目录。**

所有命令使用相对路径，用户可以在不同的 Vault 目录运行 Claude Code。

## 目录结构

```
📁 Vault/
├── 00-Inbox/                    # 统一收集箱 + 日志
│   ├── capture.md               # 所有捕获内容的统一入口
│   └── {YYYY-MM-DD}.md          # 日志 + 复盘（#record 归档位置）
│
├── 10-Projects/                 # PARA: 短期项目（有截止日期）
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
- [ ] 任务描述 📅 YYYY-MM-DD ⏫
```

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

## Frontmatter 模板

详见 `references/file-templates.md`
