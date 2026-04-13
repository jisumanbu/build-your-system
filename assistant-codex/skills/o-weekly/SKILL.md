---
name: o-weekly
description: This skill should be used when the user request matches the former assistant workflow `o-weekly`. [Organize] 每周整合 - 扫描本周内容，生成周报
---

# Codex 适配说明

- 这是原 Claude assistant 命令 `o-weekly` 的 Codex skill 版本。
- 文中旧的斜杠命令现在都表示对应 skill，而不是可直接输入的 slash command。
- 如果需要用户做选择，优先使用当前环境支持的选项式提问；若不支持，就给出简短可直接选择的选项。
- 遇到 Claude 专属语法时，使用 Codex 等价方式完成，不要照搬旧工具名。
- 在 Vault 场景下默认当前工作目录就是 Vault 根目录；若不是，先确认路径。

进行每周整合，扫描本周的记录并生成周报。

**当前目录就是 Vault**，使用相对路径。

## 执行步骤

### 1. 读取本周数据

读取：
- `00-Inbox/{日期}.md` - 本周的日志（按日期范围扫描）
- `50-GTD/active.md` - 任务完成情况
- `50-GTD/done.md` - 本周完成的任务
- `00-Inbox/capture.md` - 本周的快速捕获

### 2. 内容分析

整理本周的：
- 完成的重要事项
- 记录的想法/灵感
- 标记为 #可做视频 的内容
- 发现的模式或洞察

### 3. 生成周报

**注意**：一周的范围是 **周一 ~ 周日**（ISO 周标准，周一是一周的第一天）

```markdown
# {年}年第{周数}周总结

> {周一日期} (周一) ~ {周日日期} (周日)

## 本周亮点
- ...

## 完成事项
- ...

## 待跟进
- ...

## 想法收集
- ...

## 下周展望
- ...
```

### 4. 保存周报

将周报保存到 `60-Memory`weekly-summary`/{年}W{周数}.md`

### 5. 模式识别

如果发现有价值的模式或洞察，追加到 `60-Memory/patterns.md`

**排序规则**：新洞察插入到文件已有内容**之前**（倒序）

### 6. 结束

```
---
周报已保存到 60-Memory`weekly-summary`/{年}W{周数}.md

本周辛苦了！
```
