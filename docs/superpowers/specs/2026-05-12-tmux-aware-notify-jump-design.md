# tmux 感知的通知跳转 — 设计文档

- **状态**: Draft，待用户 review
- **作者**: jliu（与 AI 协作）
- **日期**: 2026-05-12
- **影响范围**: `claude-notify` 插件（`notify-smart.sh` + `jump-to-claude.sh`）
- **关联 issue**: 用户报告"点击通知后显示『跳转失败，未知的终端类型: unknown』"——根因是 tmux 默认剥离 `ITERM_SESSION_ID`，导致检测落入 `unknown` 分支。

---

## 1. 问题陈述

### 1.1 现状 bug

当用户在 iTerm2 内启动 tmux，并在 tmux pane 内运行 `claude` 时：

1. `notify-smart.sh` 通过 `$ITERM_SESSION_ID` 判断终端类型；tmux 默认不透传此变量，导致 `terminal_type=unknown`。
2. unknown 分支不创建跳转脚本，但仍发通知。
3. 用户点击通知后，`jump-to-claude.sh` 的 `case` 兜底分支调用 `osascript display notification "未知的终端类型: unknown"`。

### 1.2 用户期望

点击通知后，自动跳转到对应位置：

```
macOS focus → iTerm2 app
            → iTerm window / tab / session（即 tmux client 所在的 pty）
            → tmux session / window / pane（Claude 实际所在）
```

并对目标 tmux pane 的边框做闪烁视觉反馈（黄色 ↔ 默认，重复 3 次）。

### 1.3 顺手处理的 vscode 路径问题

review 中发现 cursor/vscode 路径有两处可改进点（不算 bug 但值得修）：
- `try Cursor / fallback VS Code` 的逻辑会在通知来自 VS Code 但本机也装了 Cursor 的情况下错误地 activate Cursor。
- vscode 路径完全不做焦点检测，已在前台时仍会推通知。

---

## 2. 总体架构

```
┌─────────────────────────────────────────────────────────────┐
│  Claude hook 触发                                            │
│      ↓                                                       │
│  notify-smart.sh                                             │
│   ├─ 终端层级检测（iterm+tmux / iterm / cursor / vscode）       │
│   ├─ 焦点检测（已在前台就静默）                                  │
│   ├─ 持久化上下文 → /tmp/claude-last-session-info             │
│   └─ terminal-notifier 发通知，-execute 绑定 jump 脚本         │
│                                                              │
│  ── 用户点击通知 ──                                            │
│                                                              │
│  jump-to-claude.sh                                           │
│   ├─ 读取 /tmp/claude-last-session-info                       │
│   ├─ 按 terminal_type 走对应分支                              │
│   ├─ 跳转（AppleScript + tmux 命令）                          │
│   └─ 视觉反馈：tmux 边框闪 3 下（后台异步）                       │
└─────────────────────────────────────────────────────────────┘
```

`iterm+tmux` 是新引入的独立 `terminal_type`，与 `iterm` 平级。

### 2.1 检测优先级

```
$TMUX 非空 且 $TMUX_PANE 非空     → iterm+tmux  (新)
$ITERM_SESSION_ID 非空             → iterm
$VSCODE_GIT_ASKPASS_NODE 含 Cursor.app → cursor       (拆开)
$VSCODE_GIT_ASKPASS_NODE 含 Visual Studio Code → vscode (拆开)
或 $TERM_PROGRAM=vscode (无法精确区分时归类 cursor 兜底)
其他                                → unknown
```

**设计理由**：
- 即便用户配置了 tmux 透传 `ITERM_SESSION_ID`，`$TMUX` 仍优先——因为我们需要的是"先跳 iTerm host session，再切 tmux 三层"的完整路径，而不是停在 iTerm session 级别。
- 把原本合并的 `vscode` 拆成 `cursor` + `vscode`，避免 `try/fallback` 误激活。

---

## 3. 上下文持久化格式

### 3.1 现状问题

当前文件 `/tmp/claude-last-session-info` 内容形如：

```
iterm:DEADBEEF-1234-...:vault
```

冒号分隔 + 位置式索引。加字段就要重排所有 `cut -d:` 调用；字段含冒号会破坏解析。

### 3.2 新格式（KV）

```
schema_version=2
terminal_type=iterm+tmux
claude_session_id=
tmux_session_id=$0
tmux_session_name=work
tmux_window_id=@3
tmux_pane_id=%5
project_name=vault
claude_cwd=/Users/jliu/Projects/vault
timestamp=2026-05-12T00:25:00
```

### 3.3 解析约束

- `jump-to-claude.sh` 解析时**不能直接 `source`**（避免恶意注入）；使用 `grep -E '^[a-z_][a-z_0-9]*=' | while IFS='=' read key value` 方式逐行读入。
- 检测 `schema_version`：
  - 缺失或 `< 2` → 显示 "通知格式过旧（schema v?），请触发一次新通知再点击" 并退出。
  - `> 2` → 显示 "脚本版本过旧，请升级 claude-notify 插件" 并退出。

### 3.4 演进收益

- 加字段（如 `iterm_window_id`、`vscode_workspace_path`）不需要同步改两边
- `cat /tmp/claude-last-session-info` 直接可读，debug 友好

---

## 4. 跳转逻辑

### 4.1 `iterm+tmux` 分支（主要修复路径）

```
1. tmux 状态校验
   ├─ tmux has-session -t $tmux_session_id 失败 → "tmux server/session 已退出" + 退出
   ├─ tmux list-panes -t $tmux_pane_id 找不到   → "tmux pane '$tmux_pane_id' 已关闭" + 退出
   └─ tmux list-clients -t $tmux_session_id 为空 → "tmux session '$tmux_session_name' 已 detach，请手动 attach" + 退出

2. 实时解析 iTerm host
   client_tty=$(tmux list-clients -t $tmux_session_id -F '#{client_tty}' | head -1)
   # client_tty 形如 /dev/ttys015
   AppleScript:
     - 遍历 windows → tabs → sessions，匹配 tty=$client_tty
     - select window / select tab / select session
     - activate iTerm2
   若未找到匹配的 iTerm session → "iTerm session 未找到 (tty: $client_tty)"

3. tmux 内三级切换
   tmux switch-client -t $tmux_session_id
   tmux select-window -t $tmux_window_id
   tmux select-pane   -t $tmux_pane_id

4. 边框闪烁（后台异步）
   # 注意：tmux 边框样式是 window 级选项；step 3 已确保 target 是 active pane，
   # 所以改 pane-active-border-style 就是改目标 pane 的边框。
   orig=$(tmux show-window-options -t $tmux_window_id -v pane-active-border-style 2>/dev/null)
   (
     for i in 1 2 3; do
       tmux set-window-option -t $tmux_window_id pane-active-border-style 'fg=yellow,bold'
       sleep 0.2
       if [ -n "$orig" ]; then
         tmux set-window-option -t $tmux_window_id pane-active-border-style "$orig"
       else
         tmux set-window-option -t $tmux_window_id -u pane-active-border-style
       fi
       sleep 0.2
     done
   ) & disown
```

### 4.2 关键设计决策

| 决策 | 理由 |
|------|------|
| step 2 在 jump 时实时解析 client_tty，而非 notify 时存 | 用户可能在通知发出后关闭原 iTerm 窗口、重开新窗口 reattach tmux；保存的旧 ID 会失效，实时查询永远跳到当前的 host |
| step 3 用 tmux ID（`$0` / `@3` / `%5`）而非名称/位置 | 不受 session/window 重命名或重排影响 |
| step 4 后台 + disown | 闪烁循环 ~1.2 秒；同步执行会阻塞 macOS 通知系统的 `-execute` 回调 |
| step 4 改 window 级 `pane-active-border-style` 而非 `select-pane -P` 的 cell style | tmux 没有"per-pane 边框样式"原语；边框是 window 级选项。step 3 已把 target pane 设为 active，所以改 window 选项就等价于"只闪 target pane 的边框"。闪烁循环结束后恢复原值，不污染用户 `.tmux.conf` |
| iTerm activate 必须放在 select 之前 | 否则 select 不一定能把 macOS 焦点拉过来 |

### 4.3 其他分支

| 分支 | 行为 |
|------|------|
| `iterm`（裸 iTerm，无 tmux） | 保留现状 AppleScript 三层遍历 `unique ID`；**不闪烁**（iTerm session 没有等价边框且闪整个背景太扰民，且原用户需求仅针对 tmux 场景） |
| `cursor` | 直接 `activate "Cursor"`，按 window title 含 project_name 匹配。不 fallback 到 VS Code |
| `vscode` | 直接 `activate "Visual Studio Code"`，按 window title 含 project_name 匹配。不 fallback 到 Cursor |
| `unknown` | 保留现状报错通知（新检测层后此分支基本不再被触发） |

### 4.4 cursor/vscode 焦点检测（新增）

notify 阶段：
- AppleScript 查 frontmost app；如果不是目标 IDE，必通知。
- 如果是目标 IDE，再查 main window 标题是否含 project_name；含则静默。

跟 iTerm 路径行为对齐。

### 4.5 已知能力上限

- VS Code/Cursor 的"集成终端的具体 pane"无法通过 AppleScript 定位（它们不像 iTerm 那样暴露 session 树）。跳转停在 window 级别——macOS 自动化能力的硬上限。
- Nested tmux：内层 `$TMUX` 会覆盖外层，按内层定位（罕见，不专门处理）。

---

## 5. 错误信息精细化

### 5.1 现状

所有错误统一 `display notification "跳转失败"`，无法判断原因。

### 5.2 改后

| 触发条件 | title | message |
|---------|-------|---------|
| tmux server 退出 | tmux 状态异常 | tmux server 已退出 |
| tmux session 不存在 | tmux 状态异常 | tmux session `<name>` 不存在 |
| tmux pane 不存在 | tmux 状态异常 | tmux pane `<id>` 已关闭 |
| tmux session detach | tmux 状态异常 | session `<name>` 已 detach，请手动 attach |
| iTerm session 未找到 | iTerm 未找到 | tty `<client_tty>` 不在任何 iTerm session 中 |
| Cursor 未运行 | 应用未运行 | Cursor.app 未启动 |
| VS Code 未运行 | 应用未运行 | Visual Studio Code.app 未启动 |
| schema 过旧 | 通知格式过旧 | 请重新触发一次通知 |
| 无 session info 文件 | 无最近通知 | 没有可跳转的通知 |

---

## 6. Debug 日志统一

### 6.1 现状

`/tmp/claude-jump-debug.log` 和 `/tmp/claude-notify-debug.log` 分两个文件，散落 `echo "$(date): ..." >>`，没有级别。

### 6.2 改后

- 单一文件：`/tmp/claude-notify.log`（两个脚本共用）
- 通用 `log()` 函数，带级别（INFO / WARN / ERROR）
- 启动时检查文件大小：超 1MB 时截尾保留最后 500 行
- 默认所有事件 INFO，所有报错路径 ERROR

格式：

```
2026-05-12 00:35:01 [INFO] notify: terminal_type=iterm+tmux tmux_pane=%5
2026-05-12 00:35:02 [INFO] notify: should_notify=false (already focused)
2026-05-12 00:36:11 [INFO] jump: reading session info
2026-05-12 00:36:11 [ERROR] jump: tmux list-clients empty, session=$0
```

---

## 7. 测试场景

实现完成后人工执行：

| # | 场景 | 期望行为 |
|---|------|--------|
| 1 | iTerm2 + tmux + claude，attached，前台 | 不通知 |
| 2 | iTerm2 + tmux + claude，切到其他 app | 通知，点击跳回 iTerm + tmux 三层，边框闪 3 次 |
| 3 | iTerm2 + tmux + claude，切到同一 tmux 的另一 pane | 通知（pane 不同算未聚焦），点击跳回，闪烁 |
| 4 | iTerm2 + tmux，tmux detach 后点通知 | 报错 "tmux session 'X' 已 detach" |
| 5 | iTerm2 + tmux，关掉原 iTerm 窗口后从新窗口 `tmux a`，点通知 | 跳到新 iTerm 窗口的对应 session，闪烁 |
| 6 | iTerm2 裸跑 claude（无 tmux） | 现状不变（通知 + 跳转，无闪烁） |
| 7 | Cursor 里跑 claude | 通知，点击 activate Cursor（不是 VS Code），window 定位 |
| 8 | VS Code 里跑 claude（即使装了 Cursor） | activate VS Code，不抢到 Cursor |
| 9 | Cursor + 当前已聚焦 + 同一项目 window | 不通知 |
| 10 | 旧版 notify 写的 session-info 文件（无 schema_version），点击新 jump | "通知格式过旧" + 不崩溃 |

---

## 8. 不在本次范围

- 自动 reattach detached tmux session（场景 4 的恢复路径）——故意降级为错误提示，避免脚本副作用。
- VS Code/Cursor 集成终端的 pane 级跳转——macOS API 上限。
- 跨主机 / SSH tmux 场景——超出本机自动化范围。
- 闪烁的颜色、次数、间隔做成可配置——先固定为黄色 / 3 次 / 200ms。
- 多 client attached 到同一 tmux session 时如何选择——固定取 `list-clients | head -1`，罕见场景不优化。

---

## 9. 文件改动总结

| 文件 | 改动 |
|------|------|
| `claude-notify/hooks/scripts/notify-smart.sh` | 检测层重写 + 焦点检测扩展 + KV 格式持久化 + 日志统一 |
| `claude-notify/hooks/scripts/jump-to-claude.sh` | 分支扩展（含 iterm+tmux）+ 错误细化 + 闪烁逻辑 + 日志统一 |
| `claude-notify/README.md` | 文档同步：新增 tmux 支持说明 |

无新增文件、无依赖变更。
