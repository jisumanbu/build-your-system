---
description: "[Capture] 快速捕获 - 统一入口，智能打标签"
argument-hint: "<内容>"
---

将内容捕获到统一 inbox，智能打标签。

**$ARGUMENTS**

## 执行流程

### 0. 检查初始化状态

先检查 `60-Memory/profile.md` 是否存在。如果不存在，提示用户先运行 `/a-setup` 完成初始化，然后停止执行。

### 1. 分析内容，识别标签

**类型标签**：使用 capture-rules skill 中的统一规则。

**领域标签**：读取 `60-Memory/tag-mapping.md` 获取用户配置的领域标签和关键词。
- 如果 tag-mapping.md 不存在，使用默认领域标签（work, life, learning）

识别顺序：
1. 类型标签（必选1个）：优先显式标签，其次关键词触发
2. 领域标签（可选，可叠加）：根据 tag-mapping.md 中的关键词识别
3. 状态标签（可选）

### 2. 写入 `00-Inbox/capture.md`

**排序规则**：新内容插入到文件已有内容**之前**（倒序，最新在最上面）

使用 Write/Edit 工具将内容插入到 capture.md 顶部（`## 待处理` 之后）：

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
2. /o-review 时再决定去向
3. 类型标签必选1个，其他可选
4. 直接保存，不询问确认
5. **当前目录就是 Vault**，使用相对路径

## 示例

输入：明天要给客户发报价单
→ `#task #outsourcing`
→ 追加到 capture.md
→ 回复：已捕获 #task #outsourcing

输入：可以做期关于创业的视频
→ `#topic #media #可做视频`
→ 追加到 capture.md
→ 回复：已捕获 #topic #media #可做视频

输入：等客户回复报价确认
→ `#waiting #outsourcing`
→ 追加到 capture.md
→ 回复：已捕获 #waiting #outsourcing
