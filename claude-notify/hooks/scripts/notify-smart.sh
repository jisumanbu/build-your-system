#!/bin/bash
# iTerm2 智能通知：精确焦点检测 + 点击跳转

# 从 stdin 读取 JSON
input=$(cat)

# 提取信息
claude_cwd=$(echo "$input" | /usr/bin/python3 -c "import sys,json; print(json.load(sys.stdin).get('cwd',''))" 2>/dev/null)
hook_event=$(echo "$input" | /usr/bin/python3 -c "import sys,json; print(json.load(sys.stdin).get('hook_event_name',''))" 2>/dev/null)
message=$(echo "$input" | /usr/bin/python3 -c "import sys,json; print(json.load(sys.stdin).get('message',''))" 2>/dev/null)

# 从 ITERM_SESSION_ID 提取 Session UUID（格式: w0t0p1:UUID）
claude_session_id="${ITERM_SESSION_ID##*:}"

# 检测当前活动应用
active_app=$(osascript -e 'tell application "System Events" to get name of first process whose frontmost is true' 2>/dev/null)

# 判断是否需要通知
should_notify=true

if [ "$active_app" = "iTerm2" ] && [ -n "$claude_session_id" ]; then
    # 获取当前焦点 Session 的 unique ID
    iterm_session_id=$(osascript -e '
    tell application "iTerm2"
        tell current session of current tab of current window
            return unique ID
        end tell
    end tell
    ' 2>/dev/null)

    # 比较 Session ID
    if [ "$iterm_session_id" = "$claude_session_id" ]; then
        should_notify=false
    fi
fi

# 不需要通知，退出
if [ "$should_notify" = false ]; then
    exit 0
fi

# 保存最近通知的 Session ID（供快捷键跳转使用）
echo "$claude_session_id" > /tmp/claude-last-session-id

# 准备通知内容
project_name=$(basename "$claude_cwd")
[ -z "$project_name" ] && project_name="Claude Code"

case "$hook_event" in
    "Stop")
        msg="任务完成"
        sound="Glass"
        ;;
    "Notification")
        msg="${message:-需要你的确认}"
        sound="Ping"
        ;;
    *)
        msg="需要你的注意"
        sound="Glass"
        ;;
esac

# 创建跳转脚本（使用 Session ID 精确匹配）
SCRIPT_FILE="/tmp/claude-focus-$$.applescript"
cat > "$SCRIPT_FILE" << EOF
tell application "iTerm2"
    activate
    set targetSessionId to "$claude_session_id"

    repeat with w in windows
        repeat with t in tabs of w
            repeat with s in sessions of t
                try
                    tell s
                        set sessionId to unique ID
                    end tell
                    if sessionId = targetSessionId then
                        select w
                        tell w to select t
                        select s
                        return
                    end if
                end try
            end repeat
        end repeat
    end repeat
end tell
EOF

# 发送通知
terminal-notifier \
    -title "Claude Code" \
    -subtitle "$project_name" \
    -message "$msg" \
    -sound "$sound" \
    -group "claude-code" \
    -execute "osascript '$SCRIPT_FILE'"

exit 0
