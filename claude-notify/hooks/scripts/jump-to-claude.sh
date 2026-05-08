#!/bin/bash
# 跳转到最近收到通知的 Claude Code Session
# 支持 iTerm2 和 Cursor (VS Code)

# DEBUG: 记录执行
echo "$(date): jump-to-claude.sh started" >> /tmp/claude-jump-debug.log

SESSION_INFO_FILE="/tmp/claude-last-session-info"

# 检查文件是否存在
if [ ! -f "$SESSION_INFO_FILE" ]; then
    osascript -e 'display notification "没有最近的 Claude Code 通知" with title "跳转失败"'
    exit 1
fi

# 读取终端信息（格式：terminal_type:session_id:project_name）
session_info=$(cat "$SESSION_INFO_FILE")

# 解析字段
terminal_type=$(echo "$session_info" | cut -d: -f1)
target_session_id=$(echo "$session_info" | cut -d: -f2)
project_name=$(echo "$session_info" | cut -d: -f3-)

if [ -z "$terminal_type" ]; then
    osascript -e 'display notification "终端信息为空" with title "跳转失败"'
    exit 1
fi

# 关闭 Claude Code 通知
terminal-notifier -remove "claude-code" 2>/dev/null

# 根据终端类型执行跳转
case "$terminal_type" in
    "iterm")
        # iTerm2: 精确到 Session 的跳转
        if [ -z "$target_session_id" ]; then
            osascript -e 'display notification "Session ID 为空" with title "跳转失败"'
            exit 1
        fi
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
        ;;
    "vscode")
        # Cursor/VS Code: 通过窗口标题精准跳转
        echo "$(date): vscode branch, project_name=$project_name" >> /tmp/claude-jump-debug.log
        if [ -z "$project_name" ]; then
            # 没有项目名，只激活应用
            echo "$(date): no project_name, activating app" >> /tmp/claude-jump-debug.log
            osascript -e 'tell application "Cursor" to activate' 2>/dev/null || \
            osascript -e 'tell application "Visual Studio Code" to activate' 2>/dev/null
        else
            echo "$(date): running AppleScript for $project_name" >> /tmp/claude-jump-debug.log
            # 使用 Cursor/VS Code 原生接口 + System Events 组合方案
            # 先激活应用确保窗口可访问，再精确匹配
            result=$(osascript << EOF 2>&1
set targetProject to "$project_name"
set appFound to false
set allWindows to ""

-- 尝试 Cursor（优先）
try
    tell application "Cursor"
        activate
        delay 0.1
    end tell
    set appFound to true
    set appName to "Cursor"
on error
    set appFound to false
end try

-- 如果 Cursor 不存在，尝试 VS Code
if not appFound then
    try
        tell application "Visual Studio Code"
            activate
            delay 0.1
        end tell
        set appFound to true
        set appName to "Code"
    on error
        return "ERROR: No Cursor or VS Code found"
    end try
end if

-- 使用 System Events 精确匹配窗口
tell application "System Events"
    if appName = "Cursor" then
        tell process "Cursor"
            repeat with w in windows
                set winName to name of w
                set allWindows to allWindows & winName & ", "
                if winName contains targetProject then
                    -- 找到目标窗口，激活它
                    set value of attribute "AXMain" of w to true
                    perform action "AXRaise" of w
                    return "SUCCESS: " & winName
                end if
            end repeat
        end tell
    else
        tell process "Code"
            repeat with w in windows
                set winName to name of w
                set allWindows to allWindows & winName & ", "
                if winName contains targetProject then
                    set value of attribute "AXMain" of w to true
                    perform action "AXRaise" of w
                    return "SUCCESS: " & winName
                end if
            end repeat
        end tell
    end if
end tell

return "NO MATCH. Windows: " & allWindows
EOF
)
            echo "$(date): AppleScript result: $result" >> /tmp/claude-jump-debug.log
        fi
        ;;
    *)
        osascript -e 'display notification "未知的终端类型: '"$terminal_type"'" with title "跳转失败"'
        exit 1
        ;;
esac
