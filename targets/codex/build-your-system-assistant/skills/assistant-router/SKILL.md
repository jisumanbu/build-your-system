---
name: assistant-router
description: "Use when the user wants the personal Obsidian Vault assistant workflow in Codex for capture, inbox dispatch, daily review, weekly summary, timeline, task overview, or conversation export."
---

# Build Your System Assistant

Codex 版个人助手总入口。

## 何时使用

- 用户说“记一下 / 捕获 / 放进 inbox / 加个任务”
- 用户说“今天回顾 / 每日回顾 / 周回顾 / 周报 / 时间线”
- 用户说“帮我总结 / 提炼 / 导出这次对话”
- 用户希望 AI 在 Obsidian Vault 里按 CODE+ / PARA / GTD 协作

## 工作原则

- 优先遵守当前 Vault 的 `AGENTS.md` / `AGENTS.override.md`
- 默认当前工作目录就是 Vault 根目录；如果不是，先确认再写文件
- 优先复用本插件已有 sub-skills，不重复发明流程
- 需要用户做选择时，优先给出简短可直接选择的选项

## 子技能映射

- 捕获与收集：`c-capture`、`c-pause`、`c-dump`
- 组织与复盘：`o-tasks`、`o-review`、`o-timeline`、`o-weekly`、`o-dashboard`、`o-schedule`
- 提炼与输出：`d-distill`、`d-mine`、`e-export`、`e-director`
- 规则与结构：`capture-rules`、`interstitial-journaling`、`vault-structure`
- 活动分析：`cc-activity`

## Codex 约束

- 不依赖 Claude slash command
- 不依赖 `CLAUDE_PLUGIN_ROOT`
- 涉及活动分析时，使用：

```bash
python3 "$HOME/plugins/build-your-system-assistant/scripts/analyze-codex-activity.py" [YYYY-MM-DD] [--json-only]
```

## 默认路由

- 捕获内容或加任务：先走 `c-capture`
- 间隙记录或任务切换：先走 `c-pause`
- 查看当前任务状态：先走 `o-tasks`
- 做当日回顾：先走 `o-review`
- 看某天时间线：先走 `o-timeline`
- 做每周整合：先走 `o-weekly`
- 导出当前对话：先走 `e-export`
