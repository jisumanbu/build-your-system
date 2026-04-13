---
description: "活动分析 - 分析当日对话记录，生成时间线和目标统计"
argument-hint: "[YYYY-MM-DD]"
allowed-tools: Bash(python3:*)
---

分析指定日期的对话记录，输出：
- **活动时间线**：按时间排列的活动列表
- **目标统计**：每个目标花费的时间
- **MIT 对比**：计划 vs 实际产出
- **领域分布**：#media #indie #tasks 等

**参数**：不传则分析今天，传入 `YYYY-MM-DD` 分析指定日期

## 执行

!`python3 "${CLAUDE_PLUGIN_ROOT}/scripts/analyze-cc-activity.py" $ARGUMENTS`
