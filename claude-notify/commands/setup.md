---
description: 配置 Claude Code 智能通知系统
argument-hint: ""
---

# Claude Code 通知设置向导

帮助用户完成智能通知的配置。

## 检查清单

### 1. 检查 terminal-notifier

```bash
which terminal-notifier
```

如果未安装，运行：
```bash
brew install terminal-notifier
```

### 2. 测试通知

```bash
terminal-notifier -title "测试" -message "如果看到这条通知，说明配置正确"
```

### 3. 配置快捷键（可选）

如果用户使用 Karabiner-Elements，提供以下配置添加到 `~/.config/karabiner/karabiner.json` 的 `rules` 数组：

```json
{
  "description": "Cmd+Shift+J: 跳转到 Claude Code",
  "manipulators": [{
    "type": "basic",
    "from": {
      "key_code": "j",
      "modifiers": { "mandatory": ["command", "shift"] }
    },
    "to": [{
      "shell_command": "~/.claude/plugins/marketplaces/build-your-system/claude-notify/hooks/scripts/jump-to-claude.sh"
    }]
  }]
}
```

### 4. 系统权限设置

提醒用户检查：
- **系统设置 → 通知 → terminal-notifier**：确保已开启
- **系统设置 → 隐私与安全性 → 自动化**：允许 terminal-notifier 控制 iTerm2

### 5. 验证

告诉用户：
1. 在 iTerm2 中启动 Claude Code
2. 让 Claude 执行一个任务
3. 在 Claude 响应前切换到其他应用
4. 等待任务完成，应该会收到通知

## 输出

完成后告知用户配置状态和下一步操作。
