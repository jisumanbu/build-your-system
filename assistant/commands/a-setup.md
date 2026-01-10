---
description: 首次使用设置 - 配置 Vault 路径和检查环境
---

你是 Personal Assistant Plugin 的设置向导。帮助用户完成首次配置。

## 设置流程

### 第一步：确认 Vault 路径

使用 AskUserQuestion 工具询问用户的 Obsidian Vault 路径：

```
请提供你的 Obsidian Vault 路径：

示例：
- macOS iCloud: /Users/yourname/Library/Mobile Documents/iCloud~md~obsidian/Documents/Vault
- macOS local: /Users/yourname/Vaults/PersonalVault
- Linux: /home/yourname/Obsidian/Vault
```

### 第二步：验证路径

用户提供路径后，检查该路径是否存在：
- 使用 Bash 工具: `ls -la "$USER_PROVIDED_PATH"`

如果路径不存在，提示用户重新输入。

### 第三步：检查目录结构

检查必需的目录是否存在：

```bash
VAULT="用户提供的路径"
for dir in "00-Inbox" "01-Daily" "02-Tasks" "06-Memory"; do
  if [ -d "$VAULT/$dir" ]; then
    echo "✅ $dir"
  else
    echo "❌ $dir 不存在"
  fi
done
```

如果有缺失的目录，询问用户是否自动创建。

### 第四步：检查关键文件

检查以下文件：
- `06-Memory/profile.md` - 用户画像
- `06-Memory/preferences.md` - 偏好配置
- `02-Tasks/active.md` - 当前任务
- `00-Inbox/inbox.md` - 收集箱

缺失的文件提供模板创建选项。

### 第五步：生成配置文件

创建 `.config/settings.sh`：

```bash
#!/bin/bash
# Personal Assistant Plugin - User Configuration

# Obsidian Vault 路径
VAULT_PATH="用户提供的路径"
```

先创建目录（如不存在）：
```bash
mkdir -p ~/.claude/plugins/config/assistant
```

写入到: `~/.claude/plugins/config/assistant/settings.sh`

### 第六步：验证设置

运行验证：
```bash
source ~/.claude/plugins/config/assistant/settings.sh
echo "Vault 路径: $VAULT_PATH"
ls "$VAULT_PATH/00-Inbox/inbox.md" && echo "✅ 配置成功"
```

### 完成

输出：
```
✅ Personal Assistant Plugin 配置完成！

可用命令：
- /a-capture <内容>  快速捕获
- /a-review          每日回顾
- /a-tasks           任务概览
- /a-status          系统状态

自媒体命令：
- /m-director        视频制作引导
- /m-topic           选题评估
...

开始使用：/a-capture 我的第一条笔记
```

## 文件模板

### profile.md 模板
```markdown
---
created: {{date}}
---

# 用户画像

## 基本信息
- 姓名：
- 职业：
- 所在地：

## 当前状态
- 主要目标：
- 关注领域：

## 偏好
- 工作时间：
- 沟通风格：
```

### preferences.md 模板
```markdown
---
created: {{date}}
---

# 偏好配置

\`\`\`yaml
language: zh-CN
\`\`\`

## 作息安排
- 工作时间：09:00-18:00
- 午休时间：12:00-13:00
```

### active.md 模板
```markdown
---
created: {{date}}
---

# 当前任务

## 今日重点

- [ ] 示例任务 📅 {{date}} ⏫

---

## 紧急任务

（无）

---

## 本周任务

- [ ] 周任务示例 🔼
```

### inbox.md 模板
```markdown
> 统一收集箱 - 所有内容先到这里，Review 时分发

---

<!-- 在此添加快速捕获的内容 -->
```
