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
| #pause | 间隙记录（Interstitial Journaling）|

### 优先级 2：关键词触发

当没有显式标签时，根据关键词推断：

| 关键词 | 识别为 |
|--------|--------|
| 要、需要、记得、提醒、明天、下周、别忘 | #task |
| 选题、视频、可以拍、可以做期、内容 | #topic |
| idea、产品、工具、可以做个、SaaS、App | #idea |
| 今天、刚才、发生、经历、遇到 | #record |
| 发现、原来、想明白、规律、洞察 | #insight |
| 刚完成、做完了、接下来、下一步、分心了、回去工作 | #pause |

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

## 项目归属识别（可选）

**格式**：
- `@项目名` - 文本标记，分发时转换为 wiki-link
- `[[项目名]]` - 直接使用 Obsidian wiki-link

**验证规则**：
- 检查 `10-Projects/{项目名}.md` 或 `10-Projects/{项目名}/README.md` 是否存在
- 不存在时询问用户是否创建

**示例**：
```
完成导出功能的单元测试 @物流系统
→ 分发后：- [ ] 完成导出功能的单元测试 [[物流系统]] #outsourcing 📅 2026-01-12
```

**领域自动推断**：
- 如果任务无领域标签，从项目的 `area` 字段读取
- 项目 frontmatter 示例：`area: outsourcing`

## Waiting 识别（新增）

**显式标签**：`#waiting`

**关键词触发**（当没有显式标签时）：

| 关键词 | 识别为 |
|--------|--------|
| 等待、等他、等她、等客户、等回复、等确认 | #waiting |
| 等消息、等审批、等反馈、等通知 | #waiting |
| 提交后等、发送后等 | #waiting |

**分发目标**：`50-GTD/waiting.md`

## Someday 智能建议（新增）

**显式标签**：`#someday`

**关键词触发**：

| 关键词 | 建议 someday |
|--------|-------------|
| 以后再说、将来、有空、改天 | ✓ |
| 也许、或许、可能 | ✓ |
| 想研究、想学、感兴趣 | ✓ |
| 看到别人在做、好像不错 | ✓ |

**智能判断条件**（满足全部时建议 someday）：
1. 领域不匹配主线（读取 `60-Memory/profile.md`）
2. 无项目关联
3. 无明确截止日期或 > 30 天
4. 包含上述关键词

**分发目标**：`50-GTD/someday.md`

## 分发目标

| 类型标签 | 目标位置 |
|----------|----------|
| #task | `50-GTD/active.md` |
| #task + 建议延后 | `50-GTD/someday.md` （需用户确认）|
| #waiting | `50-GTD/waiting.md` |
| #someday | `50-GTD/someday.md` |
| #topic | `20-Areas/media/topics/{选题名}.md` |
| #idea | `20-Areas/indie/ideas/{产品名}.md` |
| #record | `00-Inbox/{日期}.md` |
| #insight | `60-Memory/patterns.md` |
| #pause | `00-Inbox/{日期}.md` 的 `## 间隙日志` 区块 |

## Pause 间隙记录识别（新增）

**显式标签**：`#pause`

**关键词触发**（当没有显式标签时）：

| 关键词模式 | 识别为 |
|-----------|--------|
| 刚完成 xxx，接下来 yyy | #pause |
| 完成了 xxx，下一步 yyy | #pause |
| xxx 做完了，接下来 yyy | #pause |
| 分心了、又刷了、跑偏了 | #pause |
| 回去工作、继续干活 | #pause |
| 切换到、转去做 | #pause |
| 休息一下、暂停、歇会 | #pause |

**情绪关键词识别**：

| 关键词 | 情绪标记 |
|--------|---------|
| 顺利、不错、搞定、完美、提前 | 😊 顺利 |
| 一般、正常、还行 | 😐 一般 |
| 卡住、困难、问题、bug、搞不定 | 😔 卡住 |
| 专注、心流、沉浸、高效 | 🎯 专注 |
| 分心、刷、跑偏、浪费、又 | 📱 分心 |

**分发格式**：

```markdown
### {HH:MM}
- **完成**: {刚完成的内容}
- **感受**: {emoji} {感受描述}
- **下一步**: {下一步内容}
- **备注**: {备注内容，如果有}
```

**分发目标**：`00-Inbox/{日期}.md` 的 `## 间隙日志` 区块

## 领域标签配置

领域标签根据用户在 `/a-setup` 时选择的关注领域动态生成。

配置存储位置：`60-Memory/tag-mapping.md`

如果该文件不存在，使用默认领域标签。

## 日记 vs 周记边界（重要）

| 日记 (Daily Log) | 周记 (Weekly Review) |
|------------------|---------------------|
| 实时捕获、流水账 | 本周回顾与反思 |
| 间隙记录（#pause） | 项目进展评估 |
| 情绪和感受 | 下周规划与优先级 |
| 快速想法 | 模式识别、洞察提炼 |
| #record 类型内容 | `/o-weekly` 生成的内容 |

**关键原则**：日记是"输入"，周记是"加工"

**禁止写入周记的内容**：
- #record（日常记录）→ 必须写入 `00-Inbox/{日期}.md`
- #pause（间隙记录）→ 必须写入 `00-Inbox/{日期}.md` 的间隙日志区块
- 流水账、随手记 → 必须写入日记

**周记只包含**：
- `/o-weekly` 命令生成的周总结
- 手动添加的周级规划
- 从日记中提炼的 #insight
