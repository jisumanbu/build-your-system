---
description: "[助手] 每日回顾 - inbox 分发 + GRAI 复盘 + 明日规划"
---

进行每日回顾，包含 inbox 分发、复盘（GRAI + 4Fs 融合）和明日规划。

## 前置检查

先加载配置获取 Vault 路径：

```bash
if [ -f ~/.claude/plugins/config/assistant/settings.sh ]; then
    source ~/.claude/plugins/config/assistant/settings.sh
    echo "Vault: $VAULT_PATH"
else
    echo "ERROR: 未配置。请先运行 /a-setup"
    exit 1
fi
```

如果未配置，停止执行并提示用户运行 `/a-setup`。

以下所有文件路径都以 `$VAULT_PATH` 为前缀。

## 文件结构

参考 vault-structure skill 获取完整目录结构。

核心文件：
- `00-Inbox/inbox.md` - 统一收集箱
- `01-Daily/{年}/周记-{年}W{周}.md` - #record 归档位置
- `02-Tasks/active.md` - #task 归档位置
- `03-Areas/media/topics/` - #topic 独立文件目录
- `03-Areas/indie/ideas/` - #idea 独立文件目录
- `06-Memory/patterns.md` - #insight 归档位置

## 执行流程

### Phase 0: 日记扫描

#### 0.1 读取当天日记

读取 `01-Daily/{YYYY-MM-DD}.md`。如果文件不存在，跳过此阶段。

#### 0.2 识别可提取项

**使用 capture-rules skill 中的统一规则。**

识别粒度：
- 按段落或列表项识别
- 跳过已有 `✓→` 标记的内容（已处理）

#### 0.3 展示识别结果

```
=== 日记扫描 ===

在今天的日记中发现以下可提取项：

📋 任务 (2条):
[1] "要给客户发报价单" → active.md
[2] "需要整理读书笔记" → active.md

🎬 选题 (1条):
[3] "可以做期提前还贷的视频" → topics/提前还贷.md

如何处理？
1. ✅ 全部分发
2. 🔍 逐条确认
3. ⏭️ 跳过日记扫描
```

#### 0.4 执行分发

**任务**：追加到 `active.md`
```markdown
- [ ] 任务内容 ← [[2025-12-27]]
```

**选题**：创建 `topics/{选题名}.md`（使用选题模板）

**洞察**：追加到 `patterns.md`

#### 0.5 标记已处理

在日记原文中添加标记：`内容 ✓→[[目标]]`

---

### Phase 1: Inbox 分发

#### 1.1 读取 inbox.md

读取 `00-Inbox/inbox.md`，解析所有条目。

#### 1.2 分组展示

按类型标签分组显示（参考 capture-rules skill 的标签定义）：

```
=== Inbox Review (N条待处理) ===

📋 任务 (#task) - X条
📹 选题 (#topic) - X条
💡 灵感 (#idea) - X条
📝 记录 (#record) - X条
💎 洞察 (#insight) - X条
```

#### 1.3 混合模式交互

```
如何处理？
1. 全部分发 - 按默认规则一键处理
2. 按类型处理 - 选择某类型批量处理
3. 逐条处理 - 指定编号单独处理
4. 跳过 - 保留在 inbox
```

#### 1.4 默认分发规则

| 类型标签 | 目标位置 | 操作方式 |
|----------|----------|----------|
| `#task` | `02-Tasks/active.md` | 追加 |
| `#topic` | `03-Areas/media/topics/{选题名}.md` | **创建文件** |
| `#idea` | `03-Areas/indie/ideas/{产品名}.md` | **创建文件** |
| `#record` | `01-Daily/{年}/周记-{年}W{周}.md` | 追加 |
| `#insight` | `06-Memory/patterns.md` | 追加 |

**追加排序规则**：新内容插入到文件已有内容**之前**（倒序）

#### 1.5 选题文件模板

参考 vault-structure skill 的 `references/file-templates.md`。

---

### Phase 2: 复盘（GRAI + 4Fs 融合）

#### 2.1 归档已完成任务

检查 active.md 中标记为 `[x]` 的任务，移动到 `archive.md`。

#### 2.2 展示今日回顾（整合视图）

执行 `/cc-activity {日期}` 获取当日活动数据，整合 MIT 状态。

```
=== 今日回顾 ===

📋 已归档: X 条任务

📊 活动时段：{开始} - {结束} (GMT+8)

🎯 MIT vs 实际：
| MIT 计划 | 状态 | 实际投入 |
|----------|------|----------|
| ... | ✅/⏸️ | ... |

**完成率**：N/M MIT
```

#### 2.3 询问感受（Feelings）⭐ 交互点

**必须暂停，等待用户回答。**

#### 2.4 引导分析（Analysis）⭐ 交互点

根据用户感受进行针对性引导。

#### 2.5 提取洞察（Insight）⭐ 交互点

**必须暂停，等待用户回答。**

写入日记文件和 patterns.md。

---

### Phase 2.5: 睡前三问

**触发条件**：当前时间 >= 22:00（GMT+8）

包含：22:30前上床、自媒体发了吗、外包进度正常。

---

### Phase 3: 明日规划

选择 1-3 个 MIT，更新到 active.md。

---

### Phase 4: 结束

```
---
回顾完成！

📥 Inbox: 已处理 X 条，剩余 Y 条
📋 任务: 已归档 X 条，活跃 Y 条
📝 日记: 已更新复盘数据

明日 MIT:
1. ...
2. ...
3. ...
```

## 注意事项

- 保持轻松的语气
- **时区规范**：统一使用 GMT+8
- **复盘必须有交互**：等用户回答
- **觉察而非评判**：接纳用户的感受
