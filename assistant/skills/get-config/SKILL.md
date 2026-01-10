---
description: "获取 Personal Assistant 配置（Vault 路径）"
---

# 配置加载

在执行任何需要访问 Vault 的操作前，必须先获取配置。

## 配置文件位置

`~/.claude/plugins/config/assistant/settings.sh`

## 加载方法

使用 Bash 工具执行：

```bash
if [ -f ~/.claude/plugins/config/assistant/settings.sh ]; then
    source ~/.claude/plugins/config/assistant/settings.sh
    echo "VAULT_PATH=$VAULT_PATH"
else
    echo "ERROR: 未找到配置文件。请先运行 /a-setup"
fi
```

## 未配置时的处理

如果配置文件不存在：
1. 停止当前操作
2. 提示用户运行 `/a-setup`
3. 不要使用任何默认路径或相对路径

## 使用示例

在需要访问 Vault 文件的命令中：

```bash
# 先加载配置
source ~/.claude/plugins/config/assistant/settings.sh

# 使用 VAULT_PATH
cat "$VAULT_PATH/00-Inbox/inbox.md"
```
