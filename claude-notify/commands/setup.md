---
description: "[一键] 扫描环境、安装依赖、配置权限、验证通知"
argument-hint: ""
allowed-tools: [Bash, Read, Write, Edit, AskUserQuestion]
---

# claude-notify Setup 向导

按 6 个 Phase 顺序执行：扫描 → 决策 → 安装 → 权限 → 验证 → 可选快捷键 → 持久化状态。

仅支持 macOS。如果运行环境不是 macOS，立即报错退出。

**核心原则**：

- Phase 0 只读，不安装任何东西
- 自动安装：terminal-notifier / tmux（可选）/ Karabiner-Elements（可选）
- 不自动安装：iTerm2 / Python 3（让用户自己装）
- 不自动改用户的 Karabiner 配置（Phase 5 只在用户显式确认后写）
- 每个失败都给出具体错误信息，不藏

---

## Phase 0：环境扫描（read-only）

读取 `~/.claude/plugins/claude-notify.local.md`（如果存在）的 YAML frontmatter，了解上次运行的状态以便做幂等。

然后逐项检测下面 7 个依赖，组装成一个状态表。**不要**调用 AskUserQuestion，**不要**安装任何东西。

```bash
# 平台检查
[ "$(uname -s)" = "Darwin" ] || { echo "ERROR: claude-notify 只支持 macOS"; exit 1; }

# 依赖检查
HOMEBREW=$(command -v brew 2>/dev/null || echo "")
TERMINAL_NOTIFIER=$(command -v terminal-notifier 2>/dev/null || echo "")
TMUX=$(command -v tmux 2>/dev/null || echo "")
PYTHON3=$( /usr/bin/python3 --version 2>/dev/null | head -1 )
ITERM2=$( [ -d /Applications/iTerm.app ] && echo "/Applications/iTerm.app" || echo "" )
KARABINER=$( [ -d "/Applications/Karabiner-Elements.app" ] && echo "/Applications/Karabiner-Elements.app" || echo "" )

# AppleScript 权限：尝试一个无害的 osascript 看是否失败（错误信号是 "not authorized"）
APPLESCRIPT_TEST=$(osascript -e 'tell application "System Events" to get name of first process whose frontmost is true' 2>&1)
if echo "$APPLESCRIPT_TEST" | grep -qi "not authorized\|denied"; then
    APPLESCRIPT_GRANTED="no"
else
    APPLESCRIPT_GRANTED="yes"
fi

# 输出报告
echo ""
echo "依赖检查报告"
echo "─────────────────────────────────"
[ -n "$HOMEBREW" ] && echo "✓ Homebrew           $HOMEBREW" || echo "✗ Homebrew           未安装（必需，请先装：https://brew.sh）"
[ -n "$TERMINAL_NOTIFIER" ] && echo "✓ terminal-notifier  $TERMINAL_NOTIFIER" || echo "✗ terminal-notifier  未安装（必需）"
[ -n "$ITERM2" ] && echo "✓ iTerm2             $ITERM2" || echo "✗ iTerm2             未安装（推荐，请自行安装）"
[ -n "$TMUX" ] && echo "✓ tmux               $TMUX" || echo "✗ tmux               未安装（可选）"
[ -n "$PYTHON3" ] && echo "✓ Python 3           /usr/bin/python3 ($PYTHON3)" || echo "✗ Python 3           未安装（必需，macOS 通常自带）"
[ -n "$KARABINER" ] && echo "✓ Karabiner          $KARABINER" || echo "✗ Karabiner          未安装（可选，用于 Cmd+Shift+J）"
[ "$APPLESCRIPT_GRANTED" = "yes" ] && echo "✓ AppleScript 权限   已授权" || echo "✗ AppleScript 权限   未授权"
echo "─────────────────────────────────"
```

把上述变量记下来，Phase 1-2 需要它们。

**如果 Homebrew 缺失**：直接告诉用户去 https://brew.sh 装好再重跑，本次 setup 退出。Homebrew 是其他所有自动安装的前置。

**如果 iTerm2 或 Python 3 缺失**：在报告里列出但不进入后续安装选项。Setup 继续往下走，最后在 Phase 4 验证如果失败再让用户处理。

---

## Phase 1：用户决策（AskUserQuestion）

根据 Phase 0 的扫描结果，组装一个或两个 AskUserQuestion。

**情况 A：所有必需依赖都装了，没有可选项可装** → 跳过 Phase 1，直接进 Phase 3。

**情况 B：有可自动安装的缺失项** → 用 AskUserQuestion 让用户选要装哪些。**只把"可自动安装"的项放进选项**（不要把 iTerm2 / Python 3 放进来——它们只是提示）。

调用 AskUserQuestion 工具，问题示例：

- question: "下列可自动安装的依赖你想装哪些？"
- header: "Install deps"
- multiSelect: true
- options（动态构造，只列出 Phase 0 显示为 ✗ 的可自动安装项）：
  - "terminal-notifier"（必需，强烈推荐选）
  - "tmux"（可选，缺失则无 tmux 三层跳转）
  - "Karabiner-Elements"（可选，用于 Cmd+Shift+J 全局快捷键）

**如果 iTerm2 缺失**：在询问前先弹一段文字警告："检测到 iTerm2 未安装。这个插件主要为 iTerm2 设计，没有它跳转功能基本不可用。请前往 https://iterm2.com/downloads.html 或运行 `brew install --cask iterm2` 自行安装。" 让用户看完后继续。

**如果 Python 3 缺失**：同样警告 + https://www.python.org/downloads/

---

## Phase 2：自动安装

按 Phase 1 用户的选择逐项执行 brew 命令。每条命令实时输出到当前会话，失败立即停下来报告。

```bash
# 假设 Phase 1 用户选了 terminal-notifier + tmux
brew install terminal-notifier tmux

# 假设用户选了 Karabiner
brew install --cask karabiner-elements
```

安装完每一项后重新跑一遍 `command -v` 验证它在 PATH 里（避免"装上了但是 shell 没刷新 PATH"的情况）。如果有失败，告诉用户具体原因并暂停。

---

## Phase 3：权限引导

无法用脚本配置的系统权限——只能打开对应的系统设置面板，让用户自己点。

**Notification 权限**：

```bash
open "x-apple.systempreferences:com.apple.preference.notifications"
```

文字指引："系统设置已打开。请在通知列表里找到 'terminal-notifier' 和你日常使用的 IDE（iTerm2 / Cursor / VS Code），确保 '允许通知' 是开的。"

**Automation（自动化）权限**：

```bash
open "x-apple.systempreferences:com.apple.preference.security?Privacy_Automation"
```

文字指引："请确保 iTerm2 / Cursor / VS Code 这些应用都能控制 System Events 和 iTerm2。如果列表里没出现某个应用，先在该应用里跑一次会触发 osascript 的命令，系统会自动加上来。"

**AskUserQuestion**：

- question: "权限都配好了吗？"
- header: "Permissions"
- options:
  - "都配好了，继续验证"
  - "晚点再说，跳过验证直接结束"

如果"晚点再说"，跳过 Phase 4，直接进 Phase 6 持久化（标记 `notification_permission: deferred`）。

---

## Phase 4：触发测试通知

跑一次真实的 notify-smart.sh 看看是不是端到端跑通。**先切焦点到非 iTerm/IDE 的应用**（不然焦点检测会把通知静默掉，那就看不见效果了）。

调用 AskUserQuestion 提示用户先切焦点：

- question: "马上要触发测试通知。请先 Cmd+Tab 切到 Chrome 或别的应用——焦点不在 Claude 终端时通知才会弹。准备好了点继续。"
- header: "Switch focus"
- options:
  - "切好了，触发测试"
  - "我想跳过测试"

如果用户跳过 → Phase 6。

如果继续 → 用 Bash 工具触发：

```bash
echo '{"cwd":"'"$PWD"'","hook_event_name":"Notification","message":"setup 测试通知"}' \
    | bash "$CLAUDE_PLUGIN_ROOT/hooks/scripts/notify-smart.sh"
```

等 1-2 秒，然后 AskUserQuestion：

- question: "看到 macOS 通知了吗？标题应该是 'Claude Code'，副标题含项目名（和 pane title，如果在 tmux 里）。"
- header: "Notification check"
- options:
  - "看到了"
  - "没看到"
  - "看到了，但是格式不对"

**"看到了"** → 标记 `notification_test: passed`，进入 Phase 5。

**"没看到"** → 给故障排查清单：
- 检查 `/tmp/claude-notify.log` 最后 5 行（用 Bash `tail -5`）输出给用户看
- 检查 `/tmp/claude-last-session-info` 是否存在
- 提示常见原因：terminal-notifier 没装 / 通知权限未授予 / Do Not Disturb 开着
- 让用户解决后重跑 `/claude-notify:setup`

**"格式不对"** → 让用户描述具体差异，记录到日志，然后继续 Phase 5。

---

## Phase 5：Cmd+Shift+J 绑定（可选）

**仅当**：Karabiner-Elements 已安装（Phase 0 或 Phase 2 之后）+ 用户在 Phase 1 表达过想要这个快捷键。

如果两个条件不满足，跳过 Phase 5。

**Step 5.1**：检查 `~/.config/karabiner/karabiner.json` 里是否已经有 claude-notify 的规则：

```bash
KARABINER_CONFIG="$HOME/.config/karabiner/karabiner.json"
if [ -f "$KARABINER_CONFIG" ]; then
    if grep -q "claude-notify\|jump-to-claude" "$KARABINER_CONFIG"; then
        echo "[OK] Karabiner 已含 claude-notify 规则，跳过"
        # 跳过到 Phase 6
    fi
fi
```

如果已存在，跳过。

**Step 5.2**：构造规则 JSON 片段：

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

**AskUserQuestion**：

- question: "Karabiner 规则该怎么处理？"
- header: "Karabiner rule"
- options:
  - "自动写入到 karabiner.json"（推荐）
  - "只显示 JSON，我自己粘贴"
  - "跳过"

**"自动写入"** → 用 `/usr/bin/python3` 解析 JSON，把规则插入到 `profiles[0].complex_modifications.rules` 数组开头，原子写回文件（temp + mv）。**写之前先备份**：`cp karabiner.json karabiner.json.backup-YYYYMMDD-HHMMSS`。然后跑 `osascript -e 'tell application "Karabiner-Elements" to activate'` 把 Karabiner 调到前台让用户验证规则已加上。

**"只显示"** → 把 JSON 输出到屏幕让用户复制粘贴。

**"跳过"** → 不写。

---

## Phase 6：状态持久化

把整个 setup 过程的结果写到 `~/.claude/plugins/claude-notify.local.md`。这个文件用 YAML frontmatter + 人类可读的 markdown body：

```bash
mkdir -p ~/.claude/plugins

cat > ~/.claude/plugins/claude-notify.local.md <<'EOF'
---
last_setup_run: <ISO timestamp>
homebrew: <installed|missing>
terminal_notifier: <installed|missing>
iterm2: <installed|missing|user_action_required>
python3: <installed|missing|user_action_required>
tmux: <installed|missing|skipped>
karabiner: <installed|missing|skipped>
applescript_permission: <granted|deferred>
notification_test: <passed|failed|skipped>
cmd_shift_j_binding: <configured|skipped|manual>
---

# claude-notify Setup 状态

最近一次运行：<ISO timestamp>

## 摘要

<2-3 行人类可读的总结，比如 "全部装好了，测试通知正常，Cmd+Shift+J 已绑定。可以开始用了。"
或 "iTerm2 未装、AppleScript 权限未授权，请处理后重跑。">

## 下次重跑

再次运行 `/claude-notify:setup` 会读这个文件，已完成的项自动跳过；只重做有变化或失败过的步骤。
EOF
```

下次跑 setup 时：

- 读 frontmatter 里的状态
- Phase 0 仍然扫描（状态可能变）
- 如果某项之前是 `installed` 现在还是，自动 ✓ 不问
- 如果某项之前是 `skipped` 或 `failed`，重新询问

---

## 最终输出

完成所有 Phase 后，给用户一份总结：

```
Setup 完成
─────────────────────────────────
已安装：terminal-notifier, tmux, Karabiner
已配置：AppleScript 权限, Notification 权限, Cmd+Shift+J 绑定
已验证：测试通知正常
状态文件：~/.claude/plugins/claude-notify.local.md
─────────────────────────────────

下一步：
- 在 iTerm2 里跑 Claude Code
- 让它做点慢一点的事
- 切到其他 app
- 等通知出现 → 点击 / 按 Cmd+Shift+J
```

如果某步失败或被跳过，相应调整输出，并给出"重跑 `/claude-notify:setup`"的指引。
