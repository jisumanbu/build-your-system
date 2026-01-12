# 文件模板集

## 项目文件模板（新增）

位置：`10-Projects/{项目名}.md` 或 `10-Projects/{项目名}/README.md`

```yaml
---
status: active | paused | completed
created: YYYY-MM-DD
target: YYYY-MM-DD  # 可选，预期完成日期
area: indie | media | outsourcing | life | learning  # 关联领域
tags: [project]
---

# 项目名称

## 目标

一句话描述项目要达成的目标。

## 背景

项目启动的原因和背景。

## 关键成果

- [ ] 关键成果 1
- [ ] 关键成果 2
- [ ] 关键成果 3

## 任务

> 任务可在此列出，也可在 `50-GTD/active.md` 中使用 `[[项目名]]` 关联

- [ ] 任务 1 📅 YYYY-MM-DD
- [ ] 任务 2

## 进度记录

### YYYY-MM-DD

- 完成了...
- 下一步...

## 相关资源

- [[相关文档1]]
- [[相关文档2]]
```

**状态说明**：

| 状态 | 说明 |
|------|------|
| active | 正在进行中 |
| paused | 暂停（有明确原因） |
| completed | 已完成，待归档 |

**生命周期**：
```
active → paused → active → completed → (移动到 40-Archives/{项目名}/)
```

---

## 选题文件模板

位置：`20-Areas/media/topics/{选题名}.md`

```yaml
---
type: topic
title: 选题标题
status: idea | evaluating | scripted | published | dropped
category: 分类
priority: high | medium | low
created: YYYY-MM-DD
published: YYYY-MM-DD  # 发布后填写
tags: [topic, media]
---

# 选题标题

## 核心观点

一句话描述核心观点。

## Hook 想法

- [ ] Hook 版本 1
- [ ] Hook 版本 2

## 结构要点

1. ...
2. ...

## 相关选题

- [[相关选题1]]
- [[相关选题2]]

## 逐字稿

- 状态：未开始 | 进行中 | 已完成
- 文件：[[20-Areas/media/逐字稿/日期-选题名]]

## 发布记录

- 平台：
- 日期：
- 数据：
```

## 产品想法文件模板

位置：`20-Areas/indie/ideas/{产品名}.md`

```yaml
---
status: idea | researched | building | shipped | archived
created: YYYY-MM-DD
updated: YYYY-MM-DD
tags: [indie, idea]
---

# 产品名称

## 概述

一句话描述产品解决的问题。

## 痛点

用户遇到的具体问题是什么？

## 解决方案

产品如何解决这个问题？

## 竞品调研

| 产品 | 核心功能 | 定价 | 差异点 |
|------|----------|------|--------|
| ... | ... | ... | ... |

## 差异化优势

- ...

## 可行性评估

- **技术难度**：
- **MVP 预估**：

## 下一步

- [ ] ...
```

## 日志文件模板

位置：`00-Inbox/YYYY-MM-DD.md`

```yaml
---
date: YYYY-MM-DD
tags: [daily]
---

# YYYY-MM-DD 星期X

## 日志

...

## 复盘

### 感受

...

### 分析

...

### 洞察

...
```

## Inbox 条目格式

```markdown
---
### {月}-{日} {时}:{分}
{内容}
{类型标签} {领域标签} {状态标签}
---
```
