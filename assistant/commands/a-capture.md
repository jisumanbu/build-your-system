---
description: "[助手] 快速捕获 - 统一入口，智能打标签"
argument-hint: "<内容>"
---

将内容捕获到统一 inbox，智能打标签。

**$ARGUMENTS**

## 执行流程

### 1. 分析内容，识别标签

**使用 capture-rules skill 中的统一规则进行识别。**

识别顺序：
1. 类型标签（必选1个）：优先显式标签，其次关键词触发
2. 领域标签（可选，可叠加）
3. 状态标签（可选）

### 2. 写入 `00-Inbox/inbox.md`

**排序规则**：新内容插入到文件已有内容**之前**（倒序，最新在最上面）

使用 MCP 工具将内容插入到 inbox.md 顶部（`## 待处理` 之后）：

```markdown
---
### {月}-{日} {时}:{分}
{内容}
{类型标签} {领域标签} {状态标签}
---
```

### 3. 反馈用户

```
已捕获 {类型标签} {领域标签}
```

## 重要规则

1. **所有内容统一进 inbox**，不做分发
2. Review 时再决定去向
3. 类型标签必选1个，其他可选
4. YOLO 模式下直接保存，不询问确认

## YOLO 模式

根据 `06-Memory/preferences.md` 中的 `yolo_mode` 设置：
- `yolo_mode: true` → 直接保存
- `yolo_mode: false` → 先展示分类结果，询问确认

## 示例

输入：明天要给客户发报价单
→ `#task #outsourcing`
→ 追加到 inbox.md
→ 回复：已捕获 #task #outsourcing

输入：可以做期关于被裁后创业的视频
→ `#topic #media #可做视频`
→ 追加到 inbox.md
→ 回复：已捕获 #topic #media #可做视频

输入：今天提前还清了房贷
→ `#record #life #可做视频`
→ 追加到 inbox.md
→ 回复：已捕获 #record #life #可做视频
