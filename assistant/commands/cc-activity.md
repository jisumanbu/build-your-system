---
description: "Claude Code 活动分析 - 分析指定日期的对话记录，生成活动时间线"
argument-hint: "[YYYY-MM-DD]"
allowed-tools: Bash(python3:*)
---

分析 Claude Code 对话记录，生成活动时间线。

**参数**：不传则分析今天，传入 `YYYY-MM-DD` 分析指定日期

## 执行

!`python3 "${CLAUDE_PLUGIN_ROOT}/scripts/analyze-cc-activity.py" $ARGUMENTS`
