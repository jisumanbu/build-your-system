---
name: Vault Structure
description: This skill should be used when the user asks about "Obsidian Vault paths", "file locations", "task format", "frontmatter templates", or needs to navigate the personal knowledge base structure.
version: 1.0.0
---

# Vault 结构导航

## Vault 根路径

从 `.config/settings.sh` 配置读取 `VAULT_PATH`。

环境变量：`${VAULT_PATH}`

## 目录结构

```
📁 Vault/
├── 00-Inbox/                    # 统一收集箱
│   └── inbox.md                 # 所有捕获内容的统一入口
│
├── 01-Daily/                    # 每日笔记
│   ├── YYYY-MM-DD.md            # 日记文件
│   └── {年}/
│       └── 周记-{年}W{周数}.md  # #record 归档位置
│
├── 02-Tasks/                    # 任务中心
│   ├── active.md                # #task 归档位置
│   ├── someday.md               # 将来/也许
│   ├── waiting.md               # 等待中
│   └── archive/                 # 已完成归档
│
├── 03-Areas/                    # 领域
│   ├── media/                   # 自媒体
│   │   ├── topics/              # 选题独立文件
│   │   ├── 逐字稿/              # 逐字稿文件
│   │   └── 方法论库/            # 方法论文件
│   └── indie/                   # 独立开发
│       └── ideas/               # #idea 产品想法文件
│
├── 04-Projects/                 # 项目
│
├── 05-Knowledge/                # 知识库
│
└── 06-Memory/                   # AI 记忆层
    ├── profile.md               # 用户画像
    ├── preferences.md           # 偏好配置
    └── patterns.md              # #insight 归档位置
```

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
