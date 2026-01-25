#!/bin/bash
# 跳转到最近收到通知的 Claude Code Session

SESSION_ID_FILE="/tmp/claude-last-session-id"

# 检查文件是否存在
if [ ! -f "$SESSION_ID_FILE" ]; then
    osascript -e 'display notification "没有最近的 Claude Code 通知" with title "跳转失败"'
    exit 1
fi

# 读取 Session ID
target_session_id=$(cat "$SESSION_ID_FILE")

if [ -z "$target_session_id" ]; then
    osascript -e 'display notification "Session ID 为空" with title "跳转失败"'
    exit 1
fi

# 关闭 Claude Code 通知
terminal-notifier -remove "claude-code" 2>/dev/null

# 执行跳转
osascript << EOF
tell application "iTerm2"
    activate
    set targetSessionId to "$target_session_id"

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
