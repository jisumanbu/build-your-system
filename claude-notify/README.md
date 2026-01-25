# Claude Code 智能通知插件

Claude Code 智能通知系统：任务完成时发送 macOS 通知，支持点击跳转。

> 当前支持 iTerm2，后续将支持 Terminal.app 和 Cursor。

## 功能

- **智能焦点检测**：只有当你不在 Claude Code 的终端时才通知
- **点击跳转**：点击通知自动跳转到对应的终端 Panel
- **快捷键跳转**：`Cmd+Shift+J` 跳转到最近收到通知的 Session
- **通知自动关闭**：跳转后通知自动消失

## 前置条件

- macOS
- iTerm2（后续支持 Terminal.app、Cursor）
- Claude Code CLI
- Homebrew

## 安装

### 1. 安装 terminal-notifier

```bash
brew install terminal-notifier
```

### 2. 启用插件

插件已包含在 build-your-system 中，安装后自动启用。

### 3. 运行设置向导

```
/claude-notify:setup
```

### 4. 配置快捷键（可选）

如果使用 Karabiner-Elements，在 `~/.config/karabiner/karabiner.json` 的 `rules` 数组中添加：

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

## 工作原理

```
Claude Code 完成任务
      ↓
触发 Stop/Notification Hook
      ↓
检测：你在 Claude 那个终端吗？（通过 Session ID）
      ↓
    是 → 不通知
    否 → 发送 macOS 通知
              ↓
         点击 → AppleScript 跳转到对应终端
```

## 触发时机

| Hook 事件 | 触发时机 | 通知消息 |
|-----------|----------|----------|
| Stop | Claude 响应完成 | "任务完成" |
| Notification (permission_prompt) | Claude 请求权限 | "需要你的确认" |

## 终端支持状态

| 终端 | 焦点检测 | 点击跳转 | 状态 |
|------|---------|---------|------|
| iTerm2 | ✅ 精确到 Panel | ✅ 精确到 Panel | 已支持 |
| Terminal.app | 🔜 应用级别 | 🔜 Tab 级别 | 计划中 |
| Cursor | 🔜 应用级别 | 🔜 仅激活 | 计划中 |

## 常见问题

### 通知没有声音？

系统设置 → 通知 → terminal-notifier → 打开声音

### 点击通知没反应？

系统设置 → 隐私与安全性 → 自动化 → 允许 terminal-notifier 控制 iTerm2

### 快捷键不工作？

1. 确认 Karabiner-Elements 正在运行
2. 检查 Complex Modifications 中规则是否已启用

## License

MIT
