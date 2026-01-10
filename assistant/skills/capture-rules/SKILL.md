---
name: Capture Rules
description: This skill should be used when the user asks to "capture content", "add to inbox", "tag an item", "dispatch inbox items", "classify content", or mentions type tags (#task, #topic, #idea, #record, #insight). Provides unified tagging and dispatch rules for the personal assistant system.
version: 1.0.0
---

# 捕获识别规则

统一规则，被 a-capture 和 a-review 共同引用。

## 类型标签识别（必选1个）

### 优先级 1：显式标签

直接使用用户标注的标签：

| 标签 | 含义 |
|------|------|
| #task | 任务 |
| #topic | 视频选题 |
| #idea | 产品灵感 |
| #record | 日常记录 |
| #insight | 洞察反思 |

### 优先级 2：关键词触发

当没有显式标签时，根据关键词推断：

| 关键词 | 识别为 |
|--------|--------|
| 要、需要、记得、提醒、明天、下周、别忘 | #task |
| 选题、视频、可以拍、可以做期、内容 | #topic |
| idea、产品、工具、可以做个、SaaS、App | #idea |
| 今天、刚才、发生、经历、遇到 | #record |
| 发现、原来、想明白、规律、洞察 | #insight |

## 领域标签识别（可选，可叠加）

| 关键词 | 标签 |
|--------|------|
| 视频、自媒体、选题、拍摄 | #media |
| 产品、独立开发、SaaS | #indie |
| 客户、外包、项目 | #outsourcing |
| 生活、家、个人 | #life |
| 学习、课程、书 | #learning |

## 状态标签识别（可选）

| 条件 | 标签 |
|------|------|
| 有视频价值 | #可做视频 |
| 需要深入研究 | #待深挖 |
| 紧急事项 | #紧急 |

## 分发目标

| 类型标签 | 目标位置 |
|----------|----------|
| #task | `02-Tasks/active.md` |
| #topic | `03-Areas/media/topics/{选题名}.md` |
| #idea | `03-Areas/indie/ideas/{产品名}.md` |
| #record | `01-Daily/{年}/周记-{年}W{周}.md` |
| #insight | `06-Memory/patterns.md` |

## 参考资料

详细的关键词映射表见 `references/tag-mapping.md`
