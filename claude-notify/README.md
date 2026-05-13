# claude-notify

Claude Code 在长任务结束、需要权限或问问题时，给你一条 macOS 通知；点一下，焦点回到那个 Claude 所在的终端、标签、tmux pane。

> 主要支持 iTerm2（含 tmux）、Cursor、Visual Studio Code。

## 它做什么

你打开 Claude Code 跑一个比较重的任务，比如让它重构一个文件、过一轮测试、读完一份长文档。任务跑起来你切到浏览器看资料、写笔记，过几秒、几十秒、几分钟，任务完成了——但 Claude 不会自己叫你。

这个插件就是来叫你的。Claude Code 触发 Stop hook 的瞬间，`notify-smart.sh` 读 stdin 的 JSON，识别当前是哪种环境——iTerm2 + tmux、Cursor + tmux、VS Code + tmux、纯 iTerm2、纯 Cursor、纯 VS Code——问一遍"你现在已经盯着那个 Claude 了吗"。是的话什么都不做（你不需要被打扰），不是的话用 `terminal-notifier` 发一条 macOS 通知，同时把当前会话的完整坐标（应用、tab、tmux session/window/pane、pane title）写到 `/tmp/claude-last-session-info`。

在 tmux 里时，插件自动识别 tmux 的宿主应用：它从 tmux client 的 tty 用 `lsof + ps` 一路追到 GUI app，分清你这个 tmux 是跑在 iTerm 还是 Cursor 还是 VS Code 的集成终端里——选对应的跳转策略。

当你点击那条通知，或者按下 Cmd+Shift+J 快捷键，`jump-to-claude.sh` 读出那份坐标文件、做一轮实时校验（tmux server 还在吗？pane 还在吗？iTerm 那个 session 还能找到吗？），然后一层层把焦点拉回到原来的位置。iTerm + tmux 主路径：macOS focus → iTerm 应用 → 对应的 iTerm session（通过 tmux client tty 反查）→ 对应的 tmux session/window/pane，再在目标 pane 边框上闪 3 次红底白字。其他路径（IDE + tmux、纯 IDE）退化到 window 级，因为 macOS AppleScript 不暴露 IDE 集成终端的几何信息。

整个过程默认两秒左右。

## 安装

### 一键安装（推荐）

```
/claude-notify:setup
```

这个命令会按以下步骤走：

1. **先问你"主要怎么用 Claude Code"**——iTerm2 / Cursor 内置终端 / Cursor 扩展 / 还不确定。按你的选择剪裁后续步骤（Cursor 用户不会被问要不要装 iTerm2 这种无关事）。
2. **扫描环境**（terminal-notifier、tmux、iTerm2、Karabiner、AppleScript 权限），报告哪些装了哪些没装。
3. **问你要不要装缺的**——只列出可自动 `brew install` 的项；iTerm2 / Python 3 这种要你自己装，setup 只会提示。
4. **配置系统权限**（通知权限、自动化权限），自动打开对应的系统设置面板。
5. **触发一次测试通知**验证整套链路，并明确告诉你"已发出/失败"。
6. （可选）**绑定 Cmd+Shift+J** 全局快捷键（需要 Karabiner-Elements）。

iTerm2 和 Python 3 由你自己装（前者去 [iterm2.com](https://iterm2.com/downloads.html) 或 `brew install --cask iterm2`，后者是 macOS 自带）；其他依赖 setup 会用 `brew install` 帮你装好。

### 手动安装（如果 setup 出了问题）

最小可用配置只需要一条命令：

```bash
brew install terminal-notifier
```

然后给 terminal-notifier 通知权限、给你的 IDE 自动化权限（系统设置 → 隐私与安全性 → 自动化）就能跑了。tmux、Karabiner 可选。

绑定 Cmd+Shift+J 全局快捷键（可选，需要 Karabiner-Elements）：在 `~/.config/karabiner/karabiner.json` 的 `complex_modifications.rules` 里加：

```json
{
  "description": "Cmd+Shift+J: 跳转到最近的 Claude Code",
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

## 支持的终端

| 终端                      | 焦点检测                                    | 跳转粒度                                        |
|---------------------------|---------------------------------------------|-------------------------------------------------|
| iTerm2 + tmux             | iTerm 前台 + 当前 session 的 tty == tmux client tty + tmux 活跃 pane == Claude pane | 精确到 tmux pane，含边框闪烁视觉反馈              |
| Cursor + tmux             | Cursor 前台 + 当前窗口标题含项目名（无法看到具体集成终端 tab）| Cursor window 级 + tmux 内 select-pane（无闪烁） |
| Visual Studio Code + tmux | VS Code 前台 + 当前窗口标题含项目名          | VS Code window 级 + tmux 内 select-pane（无闪烁）|
| iTerm2（无 tmux）         | 比较 iTerm 当前 session 的 unique ID         | 精确到 iTerm session                            |
| Cursor                    | 当前 frontmost app + 前窗口标题含项目名      | window 级（含项目名的窗口）                      |
| Visual Studio Code        | 同上                                        | window 级                                       |
| 其他                      | 不支持                                      | 报错 "终端类型未知"                              |

`iTerm2 + tmux` 是这个插件的主力路径——精确到 pane 级 + 边框闪烁视觉反馈。其他 +tmux 路径只能到 IDE window 级（IDE 不像 iTerm 那样把集成终端的 PTY 树暴露给 AppleScript），但 tmux 层的 select-pane 仍会执行，所以用户打开 IDE 集成终端时看到的就是正确的 pane。

插件自动识别 tmux 的 host：notify 阶段通过 `lsof + ps` 追 tmux client 的进程链找到 host app（iTerm / Cursor / VS Code），然后选对应的跳转路径。

## 行为细节

### 焦点检测

每种 terminal_type 各自的"我现在被你盯着吗"的判断逻辑：

- **iTerm2 + tmux**：iTerm 在前台、当前 iTerm session 的 tty 等于 tmux client tty、tmux session 的活跃 pane 等于 Claude 所在 pane —— 三个条件全部成立才静默。
- **Cursor + tmux / VS Code + tmux**：对应 IDE 在前台 + 当前窗口标题含项目名。退化版——IDE 不暴露集成终端的 PTY，所以无法验证你是不是真盯着那个 Claude 所在的 tab。
- **iTerm2（无 tmux）**：iTerm 在前台、当前 iTerm session 的 unique ID 等于 Claude 启动时记录的那个。
- **Cursor / VS Code（无 tmux）**：对应 app 在前台，且前窗口标题里含项目名（`basename $CWD`）。

通过焦点检测的"已聚焦"会被静默——不会有打扰，只在日志里留一行 `already focused, suppressing`。

### tmux 跳转的四个阶段

点通知（或按快捷键）之后，`iterm+tmux` 路径走这四步：

A 阶段，**实时校验 tmux 状态**：`has-session` 看 server 还在不在、`list-panes` 看 pane 还活不活、`list-clients` 看 session 是不是 attached。三个里任一不满足，弹一个具体的错误通知（"session 已退出" / "pane 已关闭" / "session 已 detach"），然后退出——不试图救活。

B 阶段，**找到正确的 iTerm session**：从 tmux 拿到 `client_tty`（比如 `/dev/ttys006`），让 AppleScript 遍历 iTerm 的所有 window/tab/session，匹配 `tty of s == client_tty` 的那个，select 它、activate iTerm。**这里实时反查的好处**：即使你关掉了原 iTerm 窗口，从新窗口 `tmux a` 重新接上，client_tty 会指向新窗口的 tty，跳转还是能落到正确的地方。

C 阶段，**tmux 三级切换**：`switch-client -c "$client_tty" -t "$session_id"`（`-c` 必须给——不然 tmux 会拿"上次活跃 client"来动手，可能误伤另一个 iTerm pane），然后 `select-window -t "$window_id"`、`select-pane -t "$pane_id"`。

D 阶段，**视觉反馈**：在后台用 `set-window-option pane-active-border-style` 把目标 pane 的边框设成红底白字（`fg=brightwhite,bg=red,bold`）持续 400ms，然后恢复原值持续 400ms，循环 3 次，共 2.4 秒。整个 loop 用 `( ... ) & disown` 跑后台，主脚本立即返回，不阻塞 macOS 通知系统的回调。

### 多 pane 识别

如果你同时在好几个 tmux pane 跑 Claude，通知 subtitle 里会带上 tmux 的 `pane_title`，让你一眼看清楚是哪一个：

```
┌─────────────────────────┐
│ Claude Code             │
│ vault · CC-Notify       │  ← 项目名 · pane title
│ 任务完成                 │
└─────────────────────────┘
```

`pane_title` 是 tmux 自己的字段（你可以通过 `tmux select-pane -T "标题"` 或 shell 的 escape sequence 设置），插件只是读它、显示它。

### 视觉反馈

边框颜色选择红底白字（不是更常见的黄色或绿色）是有意的——很多 tmux 主题的 `pane-active-border-style` 默认就用各种暖色调（黄、橙、青），如果闪烁色跟主题色撞车，视觉上等于没闪。红底白字几乎不可能跟任何常态色重合，对比度最高。

每个 toggle 后会发 `refresh-client` 强制 tmux 立即重绘——某些环境下 tmux 会合并连续的 option 改动到一帧，导致视觉上看不见过渡，refresh 解决这个问题。

## 故障排查

主要看这两个文件：

- `/tmp/claude-notify.log`：notify 和 jump 两个脚本共用的日志，1MB 自动 rotate 保留最后 500 行
- `/tmp/claude-last-session-info`：上次发通知时写下的会话坐标（KV 格式，第一行 `schema_version=2`）

跑单元测试：

```bash
bash ~/.claude/plugins/marketplaces/build-your-system/claude-notify/tests/run-all.sh
```

### 常见错误通知

| 通知标题         | 含义                                                              |
|------------------|-------------------------------------------------------------------|
| tmux 状态异常    | tmux server 退出 / session 不存在 / pane 关闭 / session 已 detach |
| 缺失 tmux 信息   | session-info 文件里 tmux 必要字段为空（一般是 notify 时 tmux 命令失败） |
| iTerm 未找到     | tmux client tty 不再对应任何 iTerm session                        |
| Cursor 窗口未找到 | Cursor 在跑，但没有标题含项目名的窗口                              |
| VS Code 窗口未找到 | 同上                                                              |
| 应用未运行       | Cursor 或 Visual Studio Code 没启动                                |
| 通知格式过旧     | session-info 文件缺 `schema_version`（插件升级前的残留通知）       |
| 脚本版本过旧     | session-info 文件的 `schema_version` 大于本脚本支持的版本           |
| 无最近通知       | session-info 文件不存在                                            |
| 终端类型未知     | notify 时无法识别终端环境                                          |

每条错误都对应 `jump-to-claude.sh` 里一个具体的检查点，你能通过日志 grep `[ERROR]` 找到根因。

## 设计哲学

**两阶段 + 一份 handoff 文件**。通知和跳转是两个时间点上的事——通知发出时存一份"过去的快照"，跳转执行时读快照 + 实时校验。这两个脚本通过 `/tmp/claude-last-session-info` 解耦，可以独立演进。

**时态分离**。notify-smart 写下的所有 tmux 信息都通过 `-t "$TMUX_PANE"` 锚定到 Claude 所在 pane 的时态（不是"会话现在的活跃位置"），保证 `window_id` 和 `pane_id` 永远内部一致——即使用户在 hook 触发前切走了。jump-to-claude 不信任过去保存的 iTerm session ID，每次都用 tmux client tty 重新反查，所以 reattach 之类的场景能正确跟随。

**Schema 版本**。session-info 文件第一行是 `schema_version=2`。如果脚本读到没有这行的旧格式文件（升级残留），不会崩溃，而是显示"通知格式过旧"提示你重新触发；读到比当前支持的版本更新的，显示"脚本版本过旧"提示你升级插件。这两个错误信息是 graceful migration 的护栏。

**优雅降级**。每一类失败都有一条具体的错误通知，绝不藏在"未知错误"里。tmux server 没了、session detach 了、iTerm 找不到了、应用没运行——每一种你都能从弹出的通知文字直接看出原因，不需要去翻日志。

**PATH 韧性**。两个脚本顶部都 `export PATH="/opt/homebrew/bin:/usr/local/bin:$PATH"`——GUI 触发的 shell 进程（快捷键 handler、`terminal-notifier -execute` 回调）默认 PATH 是 `/usr/bin:/bin`，Homebrew 的 tmux 找不到会让脚本误判为"业务错误"。这是 macOS 自动化的隐藏陷阱。

## 已知限制

- IDE 集成终端（VS Code / Cursor）即使在 tmux 里也只能跳到 IDE window 级——它们没有 iTerm 那样可枚举的 session 树，AppleScript 无法定位具体的 terminal tab/pane。tmux 层的 `select-pane` 仍会执行，所以用户切到 IDE 集成终端就看到正确的 pane，但插件没法替用户把焦点先打到那个 tab。
- 边框闪烁仅在 `iterm+tmux` 路径下生效——其他路径无法精确控制 pane 的视觉属性。
- nested tmux（tmux 里跑 tmux）按内层的 `$TMUX` 识别。这是罕见场景，不专门处理。
- tmux session 已 detach 时，跳转脚本只报错不自动 reattach——避免脚本副作用，让用户自己决定怎么恢复。
- Cmd+Shift+J 全局快捷键依赖 Karabiner-Elements（或其他第三方），macOS 系统快捷键设置没法直接绑定到任意脚本路径。
- tmux host 自动识别依赖 `lsof + ps` 走进程链。极少数情况（自定义 shell、复杂 nested 容器）下可能识别不出 host，会 fallback 到 `iterm+tmux`——这时 Cursor/VS Code 用户会看到"iTerm 未找到"错误，需要手动确认 host 环境。

## License

MIT
