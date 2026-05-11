# tmux-aware Notification Jump — Test Results

**Branch**: `feat/tmux-aware-notify-jump`
**Date**: 2026-05-12
**Spec**: `2026-05-12-tmux-aware-notify-jump-design.md`
**Plan**: `2026-05-12-tmux-aware-notify-jump.md`

---

## 自动测试（已通过）

### 单元测试

```bash
bash claude-notify/tests/run-all.sh
```

结果：✅ 全部通过

- `test-detect-terminal.sh`: 7 个用例（iterm+tmux 优先级、iterm session_id 解析、cursor/vscode 区分、TERM_PROGRAM fallback、unknown、TMUX 无 TMUX_PANE 边界）
- `test-log.sh`: 4 个用例（INFO 写入、timestamp 格式、1MB 轮转、ERROR 级别）
- `test-session-info.sh`: 7 个用例（写入、schema_version、round-trip、含空格值、缺失 schema 拒绝、未来 schema 拒绝、命令注入防御）

合计 **18 个用例全部通过**。

### 错误路径自动测试（已通过）

| 场景 | 触发方式 | 期望/实际通知 |
|------|---------|--------------|
| 缺失 session-info 文件 | `rm /tmp/claude-last-session-info` 后点击 | ✅ "无最近通知 — 没有可跳转的通知" |
| 缺失 schema_version | 写入只含 `terminal_type=iterm` | ✅ "通知格式过旧 — 请重新触发一次通知" |
| 未来 schema_version | 写入 `schema_version=99` | ✅ "脚本版本过旧 — 请升级 claude-notify 插件" |
| 不识别的 terminal_type | 写入 `terminal_type=unknown` | ✅ "终端类型未知 — 通知发出时无法识别终端" |
| 异常 terminal_type 值 | 写入 `terminal_type=garbage` 或空字符串 | ✅ "终端类型异常 — garbage" |
| 缺失 tmux 必要字段 | `terminal_type=iterm+tmux` 但无 session/window/pane id | ✅ "缺失 tmux 信息 — session info 不完整" |

### 实环境冒烟测试（已通过）

**场景 1（iTerm+tmux 焦点抑制）**：当前 Claude Code 会话本身就在 iTerm2 + tmux 内，前台焦点对准。触发 `Stop` 事件：

```
[INFO] notify: terminal_type=iterm+tmux cwd=/Users/jliu/Projects/vault event=Stop
[INFO] notify: tmux session=$5(assistant) win=@13 pane=%26
[INFO] notify: already focused, suppressing
```

✅ 检测到 `iterm+tmux`，准确识别 tmux session/window/pane，前台焦点匹配 → 抑制通知。

**场景 5b（重新解析 tty）**：模拟 `iterm+tmux` 上下文，用真实 tmux ID + `write_session_info` 写入，然后调用 `jump-to-claude.sh`：

```
[INFO] jump: terminal_type=iterm+tmux project=test
[INFO] jump: iterm+tmux complete (tty=/dev/ttys006 pane=%26)
```

✅ tmux 状态校验通过，AppleScript 通过 tty 反查到 iTerm session，三级切换 + 边框闪烁后台异步执行成功。

---

## 手工测试（待用户验证）

以下场景需要真实 UI 交互，请按顺序执行。每个场景前先重置：

```bash
rm -f /tmp/claude-last-session-info
> /tmp/claude-notify.log
```

### 场景 2：iTerm+tmux 非焦点 → 通知 + 跳转 + 闪烁

1. 在 tmux 里跑：`echo '{"cwd":"/Users/jliu/Projects/vault","hook_event_name":"Stop","message":""}' | bash ~/.claude/plugins/marketplaces/build-your-system/claude-notify/hooks/scripts/notify-smart.sh`
2. 立即 `Cmd+Tab` 切到 Chrome（或任何非 iTerm 应用）
3. 等 1 秒 → macOS 通知应出现
4. 点击通知

期望：
- ✅ 焦点切回 iTerm2
- ✅ 切到原 tmux session/window/pane
- ✅ 目标 pane 边框闪烁黄色 3 次（每次 200ms）

### 场景 3：切到另一 tmux pane → 通知（焦点 pane 不同）

1. 在 tmux 里运行 `notify-smart.sh`（同上）
2. **立即在 tmux 内** `prefix + o` 或 `prefix + 方向键` 切到另一 pane（保持 iTerm 前台）
3. 等通知

期望：
- ✅ 通知出现（因为 active_pane != tmux_pane_id）
- ✅ 点击 → 切回原 pane + 闪烁

### 场景 4：tmux detach 后点通知 → 错误提示

1. 先正常触发通知（场景 2 的步骤 1）
2. 通知出现前/后，立即 `tmux detach`（按 `prefix + d`）
3. 点击通知

期望：
- ✅ 错误通知 "tmux 状态异常 — session 'assistant' 已 detach，请手动 attach"
- ✅ 脚本不自动 reattach

### 场景 5a：关闭原 iTerm 窗口后重 attach → 跳到新窗口

1. 触发通知（场景 2 步骤 1）
2. 关闭当前 iTerm 窗口（`Cmd+W`）
3. 打开新 iTerm 窗口
4. `tmux attach -t assistant`
5. 切到其他 app
6. 点击之前的通知

期望：
- ✅ 焦点跳到**新** iTerm 窗口（因为 client_tty 在 jump 时实时重新解析）

### 场景 6：裸 iTerm（无 tmux）

1. 开一个新 iTerm 窗口，**不进入 tmux**
2. 在该窗口运行：`echo '{"cwd":"/Users/jliu/Projects/vault","hook_event_name":"Stop","message":""}' | bash ~/.claude/plugins/marketplaces/build-your-system/claude-notify/hooks/scripts/notify-smart.sh`
3. 切走 → 点击通知

期望：
- ✅ `terminal_type=iterm`（不是 iterm+tmux）
- ✅ 跳回原 iTerm session（按 unique ID）
- ✅ **无闪烁**（裸 iTerm 没有 tmux 边框可闪）

### 场景 7：Cursor

1. 在 Cursor 里打开一个项目（让 window 标题含项目名）
2. 在 Cursor 集成终端运行 notify-smart.sh
3. 切到其他 app → 点击通知

期望：
- ✅ activate **Cursor**（即使 VS Code 也装着）
- ✅ window 标题含项目名的那个被 raise 到最前

### 场景 8：VS Code

同场景 7 但在 VS Code 里。期望：activate VS Code，**不**抢到 Cursor。

### 场景 9：Cursor 已焦点 + 同项目 window

1. Cursor 在前台，焦点 window 是目标项目
2. 触发 notify-smart.sh

期望：
- ✅ 不发通知（"already focused, suppressing"）

---

## 已知限制（设计内）

- nested tmux：内层 `$TMUX` 覆盖外层（罕见）
- 集成终端（VS Code/Cursor）跳转停在 window 级（macOS 自动化能力上限）
- 闪烁颜色/次数/间隔固定（黄色/3 次/200ms），不可配置
- 多 client attached 到同一 tmux session 时取 `list-clients | head -1`
