---
name: interstitial-journaling
description: This skill should be used when the user asks about "interstitial journaling", "pause journaling", "task transition tracking", "time awareness", "distraction tracking", or mentions concepts like "context switching", "procrastination awareness", "mental reset between tasks". Provides methodology and implementation guidelines for interstitial journaling in the personal assistant system.
---

# Interstitial Journaling 方法论

## 方法论起源

**创始人**: Tony Stubblebine（Better Humans 创始人）

**核心概念**: 在任务转换点（interstice = 间隙）写简短时间戳日志，将空闲时刻转化为有意识的反思机会。

## 核心价值

### 1. 上下文切换支持
- 清空上一任务的心理残留
- 为下一任务腾出认知空间
- 减少"任务残留效应"（Attention Residue）

### 2. 拖延觉察
- 写下"又刷了 20 分钟"比默默刷更有威慑力
- 让逃避行为可见化
- 建立对分心的意识

### 3. 时间感知
- 时间戳累积形成对时间流向的真实感知
- 发现时间黑洞（哪些活动消耗了大量时间）
- 了解自己的工作节奏

### 4. 认知卸载
- 写下想法释放工作记忆
- 不担心忘记重要事项
- 减少心理负担

## 记录结构

### 标准格式

```
### {HH:MM}
- **完成**: {刚完成的内容}
- **感受**: {emoji} {感受描述}
- **下一步**: {下一步内容}
- **备注**: {可选，额外想法}
```

### 情绪标记体系

| Emoji | 状态 | 触发关键词 |
|-------|------|-----------|
| 😊 | 顺利 | 顺利、不错、搞定、完美、提前 |
| 😐 | 一般 | 一般、正常、还行 |
| 😔 | 卡住 | 卡住、困难、问题、bug、搞不定 |
| 🎯 | 专注 | 专注、心流、沉浸、高效 |
| 📱 | 分心 | 分心、刷、跑偏、浪费、又 |

### 简洁格式（Tony 原版）

```
10:04 - 准备完成文章初稿
10:46 - 又掉进 Twitter 黑洞了！回去工作
11:45 - 进展不错；准备开会了
```

## 最佳实践

### 1. 30秒原则
- 间隙记录必须快（< 30秒）
- 否则会变成负担而被放弃
- 简洁胜过完整

### 2. 真实记录
- 分心就是分心，不美化
- 卡住就是卡住，不遮掩
- 真实数据才有分析价值

### 3. 下一步要具体
- ❌ "继续工作"
- ✅ "完成报告第二段"
- 具体的下一步减少启动阻力

### 4. 自然转换点
- 任务完成后
- 被打断后
- 休息结束准备开始时
- 感觉走神时

### 5. 不追求完美覆盖
- 一天记录 3-5 次已经很好
- 不需要每次转换都记录
- 养成习惯比完美执行重要

## 与 CODE+ 方法论整合

### 在 Capture 阶段
- `/c-pause` 专门命令
- `/c-capture` 智能识别间隙模式
- 自动分发到当日日志

### 在 Organize 阶段
- `/o-timeline` 查看当日时间线
- `/o-review` 整合间隙数据进行复盘
- 识别拖延模式

### 在 Distill 阶段
- 从间隙记录中提取洞察
- 发现个人工作节奏规律
- 识别高效时段和低效时段

## 数据整合

### 与 Claude Code 活动整合

间隙记录与 `cc-activity.py` 脚本的数据可以合并展示：

```
📅 2026-01-14 时间线
═══════════════════════════════════════

09:15 💻 Claude Code 会话开始
09:18 📝 开始深度工作 - 文章写作 😊
      ↓ 深度工作 46 分钟
10:04 📝 完成初稿，比预期快30分钟 🎯
      ↓ 休息 42 分钟
10:46 📝 分心了 - Twitter 黑洞 📱
```

图例：
- 📝 = 手动间隙记录
- 💻 = 自动追踪的 Claude Code 活动

### 统计指标

从间隙记录可以计算：
- 深度工作时长（🎯 专注的时间段）
- 分心时长（📱 分心记录之间的间隔）
- 任务切换频率
- 情绪分布（一天中 😊 vs 😔 的比例）

## 模式识别

### 拖延模式
- 连续多次 📱 分心
- 深度工作被频繁打断
- 任务切换过于频繁

### 高效模式
- 长时间 🎯 专注
- 😊 顺利的任务完成
- 清晰的下一步规划

### 卡住模式
- 连续 😔 卡住
- 同一任务反复出现
- 下一步模糊

## 相关命令

| 命令 | 用途 |
|------|------|
| `/c-pause` | 专门的间隙记录命令 |
| `/c-capture` | 智能识别间隙模式 |
| `/o-timeline` | 查看当日时间线 |
| `/o-review` | 整合间隙数据进行复盘 |

## 参考资料

- Tony Stubblebine 原文: "Replace Your To-Do List With Interstitial Journaling"
- Ness Labs 解读: "Interstitial journaling: combining notes, to-do & time tracking"
- 核心理念: 将微小的转换时刻变成有意识的反思机会
