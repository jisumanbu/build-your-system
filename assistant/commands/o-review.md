---
description: "[Organize] 每日回顾 - 分发 + 复盘 + 规划"
argument-hint: "[YYYY-MM-DD]"
---

# 每日回顾

**参数**：日期，默认今天。当前目录是 Vault。

## 前置数据

!`python3 "${CLAUDE_PLUGIN_ROOT}/scripts/analyze-cc-activity.py" $ARGUMENTS`

上面是当日 Claude Code 活动数据（时间线、时间投入、领域分布）。Phase 2 复盘时使用。

---

## Phase 1: 分发

**依次处理**：
1. 读取 `00-Inbox/{日期}.md`（日志），识别可提取项
2. 读取 `00-Inbox/capture.md`（inbox），解析条目

**识别规则**：参考 capture-rules skill

**默认分发规则**：

| 类型 | 目标 |
|------|------|
| #task | `50-GTD/active.md` 追加 |
| #waiting | `50-GTD/waiting.md` 追加 |
| #topic | `20-Areas/media/topics/{名}.md` 新建 |
| #idea | `20-Areas/indie/ideas/{名}.md` 新建 |
| #record | `00-Inbox/{日期}.md` 追加 |
| #insight | `60-Memory/patterns.md` 追加 |

**追加规则**：新内容插入到文件已有内容**之前**（倒序）

**交互**：⭐ 暂停等用户回答

展示识别结果后询问：
```
如何处理？
1. ✅ 全部分发
2. 🔍 逐条确认
3. ⏭️ 跳过
```

---

## Phase 2: 复盘（GRAI + 4Fs 融合）

1. **归档**：将 `50-GTD/active.md` 中 `[x]` 任务移到 `done.md`

2. **展示回顾**（整合前置活动数据 + MIT）：

```
=== {日期} 回顾 ===

📋 已归档: X 条任务
📊 活动时段：{开始} - {结束} (GMT+8)

🎯 MIT vs 实际：

| MIT 计划 | 状态 | 实际投入 |
|----------|------|----------|
| ... | ✅/⏸️ | 来自前置数据 |

完成率：N/M
```

3. **询问感受**：⭐ 暂停等用户回答（今天感觉怎么样？）

4. **引导分析**：根据感受针对性引导

5. **提取洞察**：⭐ 暂停等用户回答，写入 `60-Memory/patterns.md`

**晚间附加**（>=22:00）：睡前三问

---

## Phase 3: 明日规划

选 1-3 个 MIT，更新 `50-GTD/active.md` 的"今日重点"部分。

---

## 结束

简要总结：Inbox 处理数、任务归档数、明日 MIT。
