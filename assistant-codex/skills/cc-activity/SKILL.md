---
name: cc-activity
description: This skill should be used when the user request matches the former assistant workflow `cc-activity`. 活动分析 - 分析当日对话记录，生成时间线和目标统计
---

# Codex 适配说明

- 这是原 Claude assistant 命令 `cc-activity` 的 Codex skill 版本。
- 文中旧的斜杠命令现在都表示对应 skill，而不是可直接输入的 slash command。
- 如果需要用户做选择，优先使用当前环境支持的选项式提问；若不支持，就给出简短可直接选择的选项。
- 遇到 Claude 专属语法时，使用 Codex 等价方式完成，不要照搬旧工具名。
- 在 Vault 场景下默认当前工作目录就是 Vault 根目录；若不是，先确认路径。

分析指定日期的对话记录，输出：
- **活动时间线**：按时间排列的活动列表
- **目标统计**：每个目标花费的时间
- **MIT 对比**：计划 vs 实际产出
- **领域分布**：#media #indie #tasks 等

**参数**：不传则分析今天，传入 `YYYY-MM-DD` 分析指定日期

## 执行

运行：

```bash
python3 "$HOME/plugins/build-your-system-assistant/scripts/analyze-codex-activity.py" 用户提供的参数
```
