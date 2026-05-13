---
description: "[一键] 扫描环境、安装依赖、配置权限、验证通知"
argument-hint: ""
allowed-tools: [Bash, Read, Write, Edit, AskUserQuestion]
---

# claude-notify Setup 向导

按 7 个 Phase 顺序执行：场景选择 → 扫描 → 决策 → 安装 → 权限 → 验证 → 可选快捷键 → 持久化状态。

仅支持 macOS。如果运行环境不是 macOS，立即报错退出。

**核心原则**：

- Phase -1 先问用户实际使用场景，后续 Phase 按选择剪裁——避免给 Cursor 用户看一堆 iTerm2 相关的检查项
- Phase 0 只读，不安装任何东西
- 自动安装：terminal-notifier / tmux / Karabiner-Elements
- 不自动安装：iTerm2 / Python 3（让用户自己装）
- 不自动改用户的 Karabiner 配置（Phase 5 只在用户显式确认后写）
- 每个失败都给出具体错误信息，不藏

---

## Phase -1：使用场景识别

**这一步至关重要**：不同场景对依赖的需求完全不同。Cursor 用户根本不需要 iTerm2；iTerm2 用户根本不需要 Cursor。后续 Phase 完全按这里的选择剪裁。

```bash
# 平台检查
[ "$(uname -s)" = "Darwin" ] || { echo "ERROR: claude-notify 只支持 macOS"; exit 1; }
```

调用 AskUserQuestion：

- question: "你主要怎么使用 Claude Code？（多选，按你最常用的场景选）"
- header: "Usage scenario"
- multiSelect: true
- options:
  - **"iTerm2 里跑 `claude` 命令"** —— 这是经典场景，最完整的功能（精确到 tmux pane 级跳转 + 边框闪烁）
  - **"Cursor 的内置终端里跑 `claude` 命令"** —— 跳转到 Cursor window 级
  - **"Cursor 的 Claude Code 扩展"** —— 跳转到 Cursor window 级
  - **"还不确定 / 都用"** —— setup 会按"都装"的方式做

记下用户的选择到变量 `SCENARIOS=` 里（例如 `"iterm cursor_term"` 或 `"all"`）。

后续 Phase 引用 `SCENARIOS` 时按下面这张表决定依赖必需性：

| 依赖 | iterm 场景 | cursor_term 场景 | cursor_ext 场景 | all |
|------|-----------|-----------------|----------------|-----|
| terminal-notifier | 必需 | 必需 | 必需 | 必需 |
| Python 3 | 必需 | 必需 | 必需 | 必需 |
| AppleScript 权限 | 必需 | 必需 | 必需 | 必需 |
| 通知权限 | 必需 | 必需 | 必需 | 必需 |
| **iTerm2** | **必需** | 不检查 | 不检查 | 检查并推荐 |
| **tmux** | 强烈推荐 | 强烈推荐（用户高频用） | 不需要 | 强烈推荐 |
| Karabiner | 加分项 | 加分项 | 加分项 | 加分项 |

---

## Phase 0：环境扫描（read-only）

读取 `~/.claude/plugins/claude-notify.local.md`（如果存在）的 YAML frontmatter，了解上次运行的状态以便做幂等。

然后**按 SCENARIOS 剪裁**扫描清单。**不要**调用 AskUserQuestion，**不要**安装任何东西。

```bash
# 通用依赖
HOMEBREW=$(command -v brew 2>/dev/null || echo "")
TERMINAL_NOTIFIER=$(command -v terminal-notifier 2>/dev/null || echo "")
PYTHON3=$( /usr/bin/python3 --version 2>/dev/null | head -1 )
KARABINER=$( [ -d "/Applications/Karabiner-Elements.app" ] && echo "/Applications/Karabiner-Elements.app" || echo "" )

# tmux：iterm / cursor_term / all 场景需要
TMUX=$(command -v tmux 2>/dev/null || echo "")

# iTerm2：仅 iterm / all 场景检查
case "$SCENARIOS" in
    *iterm*|*all*) ITERM2=$( [ -d /Applications/iTerm.app ] && echo "/Applications/iTerm.app" || echo "" );;
    *) ITERM2="N/A" ;;  # 不检查
esac

# AppleScript 权限
APPLESCRIPT_TEST=$(osascript -e 'tell application "System Events" to get name of first process whose frontmost is true' 2>&1)
if echo "$APPLESCRIPT_TEST" | grep -qi "not authorized\|denied"; then
    APPLESCRIPT_GRANTED="no"
else
    APPLESCRIPT_GRANTED="yes"
fi
```

输出报告（按 SCENARIOS 显示）：

```
依赖检查报告  (场景：iTerm2 + Cursor 内置终端)
─────────────────────────────────
✓ Homebrew           /opt/homebrew/bin/brew
✓ terminal-notifier  /opt/homebrew/bin/terminal-notifier
✓ Python 3           /usr/bin/python3 (3.9.6)
✗ iTerm2             未安装  ← 重要！你选了 iTerm2 场景但没装，这是必需依赖
✗ tmux               未安装（强烈推荐）
✗ Karabiner          未安装（加分项，用于全局快捷键 Cmd+Shift+J）
✓ AppleScript 权限   已授权
─────────────────────────────────
```

**关键 UX 改进**：

- 如果用户选了 iterm 场景**且** iTerm2 缺失，单独弹出醒目警告：
  ```
  ⚠️  你选了"iTerm2 里跑 claude"场景，但 iTerm2 没安装！
      没有 iTerm2，「点通知跳回去」功能完全不可用——你只能拿到通知，无法跳转。
      请先去 https://iterm2.com/downloads.html 或 `brew install --cask iterm2` 装好，再重跑 setup。
  ```
  然后 AskUserQuestion：要不要现在退出去装，还是先跳过 iTerm2 继续？

- 如果用户**没**选 iterm 场景（只选了 Cursor 相关），完全不显示 iTerm2 行——避免无关困惑。

**如果 Homebrew 缺失**：直接告诉用户去 https://brew.sh 装好再重跑，本次 setup 退出。

**如果 Python 3 缺失**：警告（macOS 通常自带，缺失可能是 PATH 问题）+ https://www.python.org/downloads/

---

## Phase 1：用户决策（AskUserQuestion）

根据 Phase 0 扫描结果 + SCENARIOS，组装可自动安装的缺失项列表。

调用 AskUserQuestion：

- question: "下列可自动安装的依赖你想装哪些？"
- header: "Install deps"
- multiSelect: true
- options（**动态构造，按 SCENARIOS 剪裁 + 场景化文案**）：

| 依赖 | 文案（场景化）| 默认勾选条件 |
|------|--------------|--------------|
| terminal-notifier | "terminal-notifier —— 没它就发不了通知" | 必需 → 默认勾选 |
| tmux | "tmux —— 在 iTerm 或 Cursor 终端里跑 tmux 时，能精准跳到具体的 tmux pane" | SCENARIOS 含 iterm/cursor_term/all 时默认勾选 |
| Karabiner-Elements | "Karabiner-Elements —— **装了它**：以后不管在浏览器、视频、文档，按 Cmd+Shift+J 一键跳回 Claude；**不装**：只能用鼠标点通知" | 加分项，不默认勾选 |

**关键 UX 改进（来自小白测试报告）**：

- Karabiner 文案场景化——把"全局快捷键"翻译成普通用户能理解的具体好处："不管你在哪里都能一键跳回"
- iTerm2 / Python 3 **不进选项列表**（这是用户分清自动 vs 手动安装的关键边界）

---

## Phase 2：自动安装

按 Phase 1 用户的选择逐项执行 brew 命令：

```bash
# 例：用户选了 terminal-notifier + tmux + Karabiner
brew install terminal-notifier tmux
brew install --cask karabiner-elements
```

每条命令实时输出。安装完每一项跑 `command -v` 验证。失败立即停下来告诉用户具体原因。

---

## Phase 3：权限引导

**Notification 权限**：

```bash
open "x-apple.systempreferences:com.apple.preference.notifications"
```

**指引按 SCENARIOS 剪裁**：

- 选了 iterm：找 terminal-notifier 和 iTerm2，确保"允许通知"是开的
- 选了 cursor_term / cursor_ext：找 terminal-notifier 和 Cursor，确保"允许通知"是开的
- 都选：terminal-notifier + iTerm2 + Cursor + VS Code 都开

**关键 UX 提示**：terminal-notifier 第一次发通知前不在列表里。如果用户列表里没找到，告诉他"等 Phase 4 触发一次测试通知后再回来这里"。

**Automation（自动化）权限**：

```bash
open "x-apple.systempreferences:com.apple.preference.security?Privacy_Automation"
```

**指引按 SCENARIOS 剪裁**，并用大白话：

- "找到你日常用的终端/IDE 应用（按场景：iTerm2 / Cursor），点开它下面的小箭头"
- "勾上里面的 'System Events'（让 Claude 能控制你的窗口焦点）"
- "如果你日常用的应用没出现在这个列表，先在那个 app 里随便跑一下我们的脚本就会触发系统提示加进来"

AskUserQuestion：

- question: "权限都配好了吗？"
- options: ["都配好了，继续验证", "晚点再说，跳过验证直接结束"]

晚点再说 → Phase 6（标记 `notification_permission: deferred`）。

---

## Phase 4：触发测试通知 + 明确反馈

**关键 UX 改进**（小白测试报告 #2）：测试通知后**必须**给用户明确的"已发出 / 失败"反馈，不能让他对着空白终端发呆。

AskUserQuestion 先提示切焦点：

- question: "马上要触发测试通知。请先 Cmd+Tab 切到 Chrome 或别的应用——焦点不在 Claude 终端时通知才会弹。准备好了点继续。"
- options: ["切好了，触发测试", "我想跳过测试"]

跳过 → Phase 6。

继续 → 用 Bash 触发：

```bash
echo '{"cwd":"'"$PWD"'","hook_event_name":"Notification","message":"setup 测试通知"}' \
    | bash "$CLAUDE_PLUGIN_ROOT/hooks/scripts/notify-smart.sh"
EXIT=$?
sleep 1

# 检查 log 看 notify-smart 怎么结束的
LAST_LOG=$(tail -3 /tmp/claude-notify.log 2>/dev/null)
echo ""
echo "─────────────────────────────────"
if echo "$LAST_LOG" | grep -q "emitted"; then
    echo "✓ 通知已发出！"
    echo "  请看右上角的通知中心，应该弹出了一条 'Claude Code · ... · setup 测试通知'。"
    echo "  没看到？可能是：通知权限没开 / Do Not Disturb 模式 / 焦点又切回了 Claude（会被静默）"
elif echo "$LAST_LOG" | grep -q "already focused"; then
    echo "⚠️  焦点检测把通知静默了——你切回 Claude 太快了。"
    echo "  请重新切到 Chrome，重新跑这个 Phase。"
else
    echo "✗ 通知没发出。最后 3 条日志："
    echo "$LAST_LOG"
fi
echo "─────────────────────────────────"
```

然后 AskUserQuestion：

- question: "看到 macOS 通知了吗？标题应该是 'Claude Code'，副标题含项目名（在 tmux 里还会带 pane title）。"
- options:
  - "看到了"
  - "没看到 / 不确定"

**"看到了"** → 标记 `notification_test: passed`，进 Phase 5。

**"没看到"** → 故障排查清单（按 Bash 输出展示）：

```bash
echo ""
echo "故障排查"
echo "─────────────────────────────────"
echo "1. 通知日志最近 10 行："
tail -10 /tmp/claude-notify.log 2>/dev/null
echo ""
echo "2. session info 文件："
[ -f /tmp/claude-last-session-info ] && cat /tmp/claude-last-session-info || echo "  不存在（说明 notify-smart 没跑到写文件那一步）"
echo ""
echo "3. 常见原因检查："
echo "   - 通知权限没开？返回 Phase 3"
echo "   - macOS 勿扰模式开了？关掉再试"
echo "   - terminal-notifier 没装？Phase 0 检查"
echo "   - 焦点又切回 Claude？看上面 log 是否有 'already focused, suppressing'"
echo "─────────────────────────────────"
```

让用户解决后重跑 `/claude-notify:setup`。

---

## Phase 5：Cmd+Shift+J 绑定（可选）

**仅当**：Karabiner-Elements 已安装（Phase 0 或 Phase 2 之后）+ 用户在 Phase 1 选过 Karabiner。

如果两个条件不满足，跳过 Phase 5。

**Step 5.1**：检查 `~/.config/karabiner/karabiner.json` 是否已有规则：

```bash
KARABINER_CONFIG="$HOME/.config/karabiner/karabiner.json"
if [ -f "$KARABINER_CONFIG" ]; then
    if grep -q "claude-notify\|jump-to-claude" "$KARABINER_CONFIG"; then
        echo "[OK] Karabiner 已含 claude-notify 规则，跳过"
        # 跳到 Phase 6
    fi
fi
```

**Step 5.2**：规则 JSON 片段：

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

- question: "Karabiner 规则怎么处理？"
- options:
  - "自动写入到 karabiner.json"（推荐，会先备份原文件）
  - "只显示 JSON，我自己粘贴"
  - "跳过"

**"自动写入"**：先 `cp karabiner.json karabiner.json.backup-$(date +%Y%m%d-%H%M%S)`，再用 `/usr/bin/python3` 解析 JSON、把规则插入 `profiles[0].complex_modifications.rules` 数组开头、原子写回（temp + mv）。然后 `osascript -e 'tell application "Karabiner-Elements" to activate'`。

**"只显示"**：把 JSON 输出让用户复制。

**"跳过"**：不写。

---

## Phase 6：状态持久化

把整个 setup 过程的结果写到 `~/.claude/plugins/claude-notify.local.md`：

```bash
mkdir -p ~/.claude/plugins

cat > ~/.claude/plugins/claude-notify.local.md <<'EOF'
---
last_setup_run: <ISO timestamp>
scenarios: <iterm,cursor_term,cursor_ext,all>
homebrew: <installed|missing>
terminal_notifier: <installed|missing>
iterm2: <installed|missing|not_applicable>
python3: <installed|missing>
tmux: <installed|missing|skipped>
karabiner: <installed|missing|skipped>
applescript_permission: <granted|deferred>
notification_test: <passed|failed|skipped>
cmd_shift_j_binding: <configured|skipped|manual|preexisting>
---

# claude-notify Setup 状态

最近一次运行：<ISO timestamp>
选择的场景：<scenarios>

## 摘要

<2-3 行人类可读的总结>

## 下次重跑

再次运行 `/claude-notify:setup` 会读这个文件，已完成的项自动跳过；
只重做有变化或失败过的步骤。
EOF
```

下次跑 setup 时：

- 先读 frontmatter（含 scenarios），可以直接跳过 Phase -1 或重新确认
- Phase 0 仍然扫描（状态可能变）
- 已 `installed` 的项自动 ✓ 不问；`skipped` / `failed` 的重新询问

---

## 最终输出

完成所有 Phase 后，给用户一份总结：

```
Setup 完成
─────────────────────────────────
场景：iTerm2 + Cursor 内置终端
已安装：terminal-notifier, tmux, Karabiner
已配置：AppleScript 权限, Notification 权限, Cmd+Shift+J 绑定
已验证：测试通知正常
状态文件：~/.claude/plugins/claude-notify.local.md
─────────────────────────────────

下一步：
- 在你常用的终端里跑 Claude Code
- 让它做点慢一点的事
- 切到其他 app
- 等通知出现 → 鼠标点 / 按 Cmd+Shift+J
```

如果某步失败或被跳过，相应调整输出，给出"重跑 `/claude-notify:setup`"的指引。
