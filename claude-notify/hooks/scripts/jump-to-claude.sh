#!/bin/bash
# Jump to the Claude Code session/pane that emitted the last notification.

# Ensure Homebrew binaries (tmux, terminal-notifier) are findable when this
# script runs from a context with a sanitized PATH (GUI shortcut handlers,
# launchd, terminal-notifier callbacks). Without this, tmux returns 127
# "command not found" and the script misreports it as "session gone".
export PATH="/opt/homebrew/bin:/usr/local/bin:$PATH"

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
source "$SCRIPT_DIR/lib/log.sh"
source "$SCRIPT_DIR/lib/session-info.sh"

# Initialize all expected vars so read_session_info populating subset is safe.
terminal_type="" claude_session_id=""
tmux_session_id="" tmux_session_name=""
tmux_window_id="" tmux_pane_id=""
project_name="" claude_cwd=""

notify_error() {
    local title="$1"; local body="$2"
    log ERROR "jump: $title — $body"
    osascript -e "display notification \"$body\" with title \"$title\""
}

# ---- 1. Read session info ----
read_session_info
rc=$?
case "$rc" in
    0)  ;;
    2)  notify_error "无最近通知" "没有可跳转的通知"; exit 1 ;;
    3)  notify_error "通知格式过旧" "请重新触发一次通知"; exit 1 ;;
    4)  notify_error "脚本版本过旧" "请升级 claude-notify 插件"; exit 1 ;;
    *)  notify_error "未知错误" "读取会话信息失败 (rc=$rc)"; exit 1 ;;
esac

log INFO "jump: terminal_type=$terminal_type project=$project_name"

# Dismiss the clicked notification
terminal-notifier -remove "claude-code" 2>/dev/null

case "$terminal_type" in

    "iterm+tmux")
        if [ -z "$tmux_session_id" ] || [ -z "$tmux_window_id" ] || [ -z "$tmux_pane_id" ]; then
            notify_error "缺失 tmux 信息" "session info 不完整 (session=$tmux_session_id window=$tmux_window_id pane=$tmux_pane_id)"
            exit 1
        fi
        # ---- A. tmux state checks ----
        if ! tmux has-session -t "$tmux_session_id" 2>/dev/null; then
            notify_error "tmux 状态异常" "tmux session $tmux_session_name 已退出"
            exit 1
        fi
        if ! tmux list-panes -t "$tmux_pane_id" >/dev/null 2>&1; then
            notify_error "tmux 状态异常" "tmux pane $tmux_pane_id 已关闭"
            exit 1
        fi
        client_tty=$(tmux list-clients -t "$tmux_session_id" -F '#{client_tty}' 2>/dev/null | head -1)
        if [ -z "$client_tty" ]; then
            notify_error "tmux 状态异常" "session '$tmux_session_name' 已 detach，请手动 attach"
            exit 1
        fi

        # ---- B. Resolve iTerm session by client_tty, focus it ----
        result=$(osascript <<EOF 2>&1
tell application "iTerm2"
    activate
    set targetTty to "$client_tty"
    repeat with w in windows
        repeat with t in tabs of w
            repeat with s in sessions of t
                try
                    if (tty of s) is targetTty then
                        select w
                        tell w to select t
                        tell t to select s
                        return "OK"
                    end if
                end try
            end repeat
        end repeat
    end repeat
    return "NOTFOUND"
end tell
EOF
)
        if [ "$result" != "OK" ]; then
            notify_error "iTerm 未找到" "tty $client_tty 不在任何 iTerm session 中"
            exit 1
        fi

        # ---- C. tmux 3-level switch ----
        # -c "$client_tty" pins the operation to the iTerm pane we just focused.
        # Without it, switch-client would act on tmux's "last-active" client,
        # which may be a different iTerm pane and would mistakenly re-attach it.
        tmux switch-client -c "$client_tty" -t "$tmux_session_id" 2>/dev/null
        tmux select-window -t "$tmux_window_id" 2>/dev/null
        tmux select-pane   -t "$tmux_pane_id"   2>/dev/null

        # ---- D. Border flash 3x (background, won't block notification callback) ----
        # Pick a high-contrast style: bright white on red background. User palettes
        # commonly use yellows/oranges, so fg=yellow blends in — bg=red is unmissable.
        orig=$(tmux show-window-options -t "$tmux_window_id" -v pane-active-border-style 2>/dev/null || true)
        (
            for i in 1 2 3; do
                tmux set-window-option -t "$tmux_window_id" pane-active-border-style 'fg=brightwhite,bg=red,bold' 2>/dev/null
                tmux refresh-client 2>/dev/null
                sleep 0.4
                if [ -n "$orig" ]; then
                    tmux set-window-option -t "$tmux_window_id" pane-active-border-style "$orig" 2>/dev/null
                else
                    tmux set-window-option -t "$tmux_window_id" -u pane-active-border-style 2>/dev/null
                fi
                tmux refresh-client 2>/dev/null
                sleep 0.4
            done
        ) & disown
        log INFO "jump: iterm+tmux complete (tty=$client_tty pane=$tmux_pane_id)"
        ;;

    "cursor+tmux"|"vscode+tmux")
        # tmux 跑在 IDE 集成终端里。IDE 不暴露 PTY 给 AppleScript，所以
        # 我们 (a) 验证 tmux 状态、(b) activate IDE 并 raise 项目 window、
        # (c) 在 tmux 层做 switch-client + select-window + select-pane，
        # 让用户打开 IDE 的集成终端就看到正确的 pane。
        # 不闪烁——同上一条限制：IDE 不暴露 pane 几何。
        if [ -z "$tmux_session_id" ] || [ -z "$tmux_window_id" ] || [ -z "$tmux_pane_id" ]; then
            notify_error "缺失 tmux 信息" "session info 不完整 (session=$tmux_session_id window=$tmux_window_id pane=$tmux_pane_id)"
            exit 1
        fi
        if ! tmux has-session -t "$tmux_session_id" 2>/dev/null; then
            notify_error "tmux 状态异常" "tmux session $tmux_session_name 已退出"
            exit 1
        fi
        if ! tmux list-panes -t "$tmux_pane_id" >/dev/null 2>&1; then
            notify_error "tmux 状态异常" "tmux pane $tmux_pane_id 已关闭"
            exit 1
        fi
        client_tty=$(tmux list-clients -t "$tmux_session_id" -F '#{client_tty}' 2>/dev/null | head -1)
        if [ -z "$client_tty" ]; then
            notify_error "tmux 状态异常" "session '$tmux_session_name' 已 detach，请手动 attach"
            exit 1
        fi

        # 选择 IDE
        if [ "$terminal_type" = "cursor+tmux" ]; then
            target_app="Cursor"
            app_full_name="Cursor"
        else
            target_app="Code"
            app_full_name="Visual Studio Code"
        fi

        if ! pgrep -x "$target_app" >/dev/null 2>&1; then
            notify_error "应用未运行" "$app_full_name.app 未启动"
            exit 1
        fi

        # Activate IDE + raise 含项目名的 window
        result=$(osascript <<EOF 2>&1
tell application "$app_full_name" to activate
delay 0.1
tell application "System Events"
    tell process "$target_app"
        repeat with w in windows
            if name of w contains "$project_name" then
                set value of attribute "AXMain" of w to true
                perform action "AXRaise" of w
                return "OK"
            end if
        end repeat
    end tell
end tell
return "NOTFOUND"
EOF
)
        if [ "$result" != "OK" ]; then
            notify_error "$app_full_name 窗口未找到" "找不到含 '$project_name' 的窗口"
            exit 1
        fi

        # tmux 三级切换 — 用户切到集成终端就看到正确的 pane
        tmux switch-client -c "$client_tty" -t "$tmux_session_id" 2>/dev/null
        tmux select-window -t "$tmux_window_id" 2>/dev/null
        tmux select-pane   -t "$tmux_pane_id"   2>/dev/null

        log INFO "jump: $terminal_type complete (project=$project_name pane=$tmux_pane_id)"
        ;;

    "iterm")
        if [ -z "$claude_session_id" ]; then
            notify_error "iTerm 信息缺失" "Session ID 为空"
            exit 1
        fi
        result=$(osascript <<EOF 2>&1
tell application "iTerm2"
    activate
    set targetId to "$claude_session_id"
    repeat with w in windows
        repeat with t in tabs of w
            repeat with s in sessions of t
                try
                    if (unique ID of s) is targetId then
                        select w
                        tell w to select t
                        tell t to select s
                        return "OK"
                    end if
                end try
            end repeat
        end repeat
    end repeat
    return "NOTFOUND"
end tell
EOF
)
        if [ "$result" != "OK" ]; then
            notify_error "iTerm 未找到" "session $claude_session_id 不存在"
            exit 1
        fi
        log INFO "jump: iterm complete (session=$claude_session_id)"
        ;;

    "cursor")
        if ! pgrep -x Cursor >/dev/null 2>&1; then
            notify_error "应用未运行" "Cursor.app 未启动"
            exit 1
        fi
        result=$(osascript <<EOF 2>&1
tell application "Cursor" to activate
delay 0.1
tell application "System Events"
    tell process "Cursor"
        repeat with w in windows
            if name of w contains "$project_name" then
                set value of attribute "AXMain" of w to true
                perform action "AXRaise" of w
                return "OK"
            end if
        end repeat
    end tell
end tell
return "NOTFOUND"
EOF
)
        if [ "$result" != "OK" ]; then
            notify_error "Cursor 窗口未找到" "找不到含 '$project_name' 的窗口"
            exit 1
        fi
        log INFO "jump: cursor complete (project=$project_name)"
        ;;

    "vscode")
        if ! pgrep -x "Code" >/dev/null 2>&1 && ! pgrep -x "Code Helper" >/dev/null 2>&1; then
            notify_error "应用未运行" "Visual Studio Code.app 未启动"
            exit 1
        fi
        result=$(osascript <<EOF 2>&1
tell application "Visual Studio Code" to activate
delay 0.1
tell application "System Events"
    tell process "Code"
        repeat with w in windows
            if name of w contains "$project_name" then
                set value of attribute "AXMain" of w to true
                perform action "AXRaise" of w
                return "OK"
            end if
        end repeat
    end tell
end tell
return "NOTFOUND"
EOF
)
        if [ "$result" != "OK" ]; then
            notify_error "VS Code 窗口未找到" "找不到含 '$project_name' 的窗口"
            exit 1
        fi
        log INFO "jump: vscode complete (project=$project_name)"
        ;;

    "unknown")
        notify_error "终端类型未知" "通知发出时无法识别终端"
        exit 1
        ;;

    *)
        notify_error "终端类型异常" "$terminal_type"
        exit 1
        ;;
esac

exit 0
