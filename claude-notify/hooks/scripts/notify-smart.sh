#!/bin/bash
# Multi-terminal smart notifier for Claude Code hooks.
# Detects: iterm+tmux, cursor+tmux, vscode+tmux, iterm, cursor, vscode, unknown.
# Suppresses notification when target window is already focused.

# Ensure Homebrew binaries (tmux, terminal-notifier) are findable when this
# script runs from a context with a sanitized PATH (GUI shortcut handlers,
# launchd, terminal-notifier callbacks).
export PATH="/opt/homebrew/bin:/usr/local/bin:$PATH"

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
source "$SCRIPT_DIR/lib/log.sh"
source "$SCRIPT_DIR/lib/detect-terminal.sh"
source "$SCRIPT_DIR/lib/session-info.sh"

# ---- 1. Read hook JSON from stdin ----
input=$(cat)
claude_cwd=$(echo "$input" | /usr/bin/python3 -c "import sys,json; print(json.load(sys.stdin).get('cwd',''))" 2>/dev/null)
hook_event=$(echo "$input" | /usr/bin/python3 -c "import sys,json; print(json.load(sys.stdin).get('hook_event_name',''))" 2>/dev/null)
message=$(echo "$input" | /usr/bin/python3 -c "import sys,json; print(json.load(sys.stdin).get('message',''))" 2>/dev/null)
project_name=$(basename "$claude_cwd")
[ -z "$project_name" ] && project_name="Claude Code"

# ---- 2. Detect terminal type ----
detect_terminal
log INFO "notify: terminal_type=$terminal_type cwd=$claude_cwd event=$hook_event"

# ---- 3. Gather tmux details if applicable ----
tmux_session_id=""
tmux_session_name=""
tmux_window_id=""
tmux_pane_id=""
tmux_pane_title=""
case "$terminal_type" in
    iterm+tmux|cursor+tmux|vscode+tmux)
        # Anchor ALL queries to $TMUX_PANE (the pane Claude actually lives in).
        # Without -t, `tmux display-message` reports the session's currently-active
        # window/pane — if the user wandered to another window before this hook fired,
        # we'd capture the wrong window_id and the file would be internally inconsistent.
        tmux_pane_id="$TMUX_PANE"
        tmux_session_id=$(tmux display-message -t "$tmux_pane_id" -p '#{session_id}' 2>/dev/null)
        tmux_session_name=$(tmux display-message -t "$tmux_pane_id" -p '#{session_name}' 2>/dev/null)
        tmux_window_id=$(tmux display-message -t "$tmux_pane_id" -p '#{window_id}' 2>/dev/null)
        tmux_pane_title=$(tmux display-message -t "$tmux_pane_id" -p '#{pane_title}' 2>/dev/null)
        log INFO "notify: tmux session=$tmux_session_id($tmux_session_name) win=$tmux_window_id pane=$tmux_pane_id title=$tmux_pane_title"
        ;;
esac

# ---- 4. Focus detection ----
should_notify=true
case "$terminal_type" in
    "iterm")
        active_app=$(osascript -e 'tell application "System Events" to get name of first process whose frontmost is true' 2>/dev/null)
        if [ "$active_app" = "iTerm2" ] && [ -n "$claude_session_id" ]; then
            front_id=$(osascript -e 'tell application "iTerm2" to tell current session of current tab of current window to return unique ID' 2>/dev/null)
            [ "$front_id" = "$claude_session_id" ] && should_notify=false
        fi
        ;;
    "iterm+tmux")
        active_app=$(osascript -e 'tell application "System Events" to get name of first process whose frontmost is true' 2>/dev/null)
        if [ "$active_app" = "iTerm2" ]; then
            front_tty=$(osascript -e 'tell application "iTerm2" to tell current session of current tab of current window to return tty' 2>/dev/null)
            client_tty=$(tmux list-clients -t "$tmux_session_id" -F '#{client_tty}' 2>/dev/null | head -1)
            active_pane=$(tmux display-message -t "$tmux_session_id" -p '#{pane_id}' 2>/dev/null)
            if [ -n "$front_tty" ] && [ -n "$client_tty" ] && [ -n "$active_pane" ] \
               && [ "$front_tty" = "$client_tty" ] && [ "$active_pane" = "$tmux_pane_id" ]; then
                should_notify=false
            fi
        fi
        ;;
    "cursor"|"vscode"|"cursor+tmux"|"vscode+tmux")
        # IDE 不暴露 PTY 给 AppleScript，所以无论是否在 tmux 里，
        # focus 检测都退化为"目标 IDE 前台 + 当前窗口标题含项目名"。
        # tmux 内还多一层不可见 pane，但这是 macOS 自动化能力的硬上限。
        case "$terminal_type" in
            cursor|cursor+tmux) target_app="Cursor" ;;
            vscode|vscode+tmux) target_app="Code" ;;
        esac
        active_app=$(osascript -e 'tell application "System Events" to get name of first process whose frontmost is true' 2>/dev/null)
        if [ "$active_app" = "$target_app" ]; then
            title=$(osascript -e "tell application \"System Events\" to tell process \"$target_app\" to get name of front window" 2>/dev/null)
            [[ "$title" == *"$project_name"* ]] && should_notify=false
        fi
        ;;
esac

if [ "$should_notify" = false ]; then
    log INFO "notify: already focused, suppressing"
    exit 0
fi

# ---- 5. Persist session info ----
write_session_info \
    terminal_type="$terminal_type" \
    claude_session_id="$claude_session_id" \
    tmux_session_id="$tmux_session_id" \
    tmux_session_name="$tmux_session_name" \
    tmux_window_id="$tmux_window_id" \
    tmux_pane_id="$tmux_pane_id" \
    tmux_pane_title="$tmux_pane_title" \
    project_name="$project_name" \
    claude_cwd="$claude_cwd"

# ---- 6. Emit notification ----
case "$hook_event" in
    "Stop")         msg="任务完成"; sound="Glass" ;;
    "Notification") msg="${message:-需要你的确认}"; sound="Ping" ;;
    *)              msg="需要你的注意"; sound="Glass" ;;
esac

# Expose tmux pane_title in the notification subtitle so the user can tell
# which Claude session triggered the notification when running multiple panes.
subtitle="$project_name"
case "$terminal_type" in
    iterm+tmux|cursor+tmux|vscode+tmux)
        [ -n "$tmux_pane_title" ] && subtitle="$project_name · $tmux_pane_title"
        ;;
esac

jump_script="$SCRIPT_DIR/jump-to-claude.sh"
terminal-notifier \
    -title "Claude Code" \
    -subtitle "$subtitle" \
    -message "$msg" \
    -sound "$sound" \
    -group "claude-code" \
    -execute "$jump_script"

log INFO "notify: emitted ($terminal_type) subtitle=$subtitle"
exit 0
