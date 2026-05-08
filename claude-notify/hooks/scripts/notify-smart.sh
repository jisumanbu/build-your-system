#!/bin/bash
# 多终端智能通知：支持 iTerm2 和 Cursor (VS Code)
# - iTerm2: 精确焦点检测 + Panel 级别跳转
# - Cursor: 始终通知 + 应用级别跳转

# DEBUG: 记录环境变量
echo "$(date): TERM_PROGRAM=$TERM_PROGRAM, ITERM_SESSION_ID=$ITERM_SESSION_ID" >> /tmp/claude-notify-debug.log

# 从 stdin 读取 JSON
input=$(cat)

# DEBUG: 记录输入
echo "$(date): input=$input" >> /tmp/claude-notify-debug.log

# 提取信息
claude_cwd=$(echo "$input" | /usr/bin/python3 -c "import sys,json; print(json.load(sys.stdin).get('cwd',''))" 2>/dev/null)
hook_event=$(echo "$input" | /usr/bin/python3 -c "import sys,json; print(json.load(sys.stdin).get('hook_event_name',''))" 2>/dev/null)
message=$(echo "$input" | /usr/bin/python3 -c "import sys,json; print(json.load(sys.stdin).get('message',''))" 2>/dev/null)

# DEBUG: 记录解析结果
echo "$(date): cwd=$claude_cwd, event=$hook_event" >> /tmp/claude-notify-debug.log

# ============== 终端环境检测 ==============
# 检测顺序：iTerm2 > Cursor/VS Code > 未知
#
# 注意：ITERM_SESSION_ID 只在 iTerm2 中设置
# TERM_PROGRAM=vscode 在 Cursor 和 VS Code 中都设置
# VSCODE_GIT_ASKPASS_NODE 包含应用路径，可区分 Cursor 和 VS Code

# DEBUG: 记录环境变量
echo "$(date): TERM_PROGRAM=$TERM_PROGRAM, ITERM_SESSION_ID=$ITERM_SESSION_ID, VSCODE=$VSCODE_GIT_ASKPASS_NODE" >> /tmp/claude-notify-debug.log

if [ -n "$ITERM_SESSION_ID" ]; then
    terminal_type="iterm"
    claude_session_id="${ITERM_SESSION_ID##*:}"  # 提取 UUID
elif [ "$TERM_PROGRAM" = "vscode" ] || [[ "$VSCODE_GIT_ASKPASS_NODE" == *"Cursor.app"* ]] || [[ "$VSCODE_GIT_ASKPASS_NODE" == *"Visual Studio Code"* ]]; then
    terminal_type="vscode"  # Cursor 和 VS Code 都设置此值
    claude_session_id=""
else
    terminal_type="unknown"
    claude_session_id=""
fi

# DEBUG: 记录检测结果
echo "$(date): terminal_type=$terminal_type" >> /tmp/claude-notify-debug.log

# ============== 焦点检测（仅 iTerm2）==============
should_notify=true

if [ "$terminal_type" = "iterm" ]; then
    # 检测当前活动应用
    active_app=$(osascript -e 'tell application "System Events" to get name of first process whose frontmost is true' 2>/dev/null)

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
fi
# Cursor/VS Code: 始终通知（不做焦点检测）

# 不需要通知，退出
if [ "$should_notify" = false ]; then
    exit 0
fi

# ============== 准备通知内容 ==============
project_name=$(basename "$claude_cwd")
[ -z "$project_name" ] && project_name="Claude Code"

# 保存终端信息（供快捷键跳转使用）
# 格式：terminal_type:session_id:project_name
echo "$terminal_type:$claude_session_id:$project_name" > /tmp/claude-last-session-info

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

# ============== 创建跳转脚本 ==============
SCRIPT_FILE="/tmp/claude-focus-$$.applescript"

case "$terminal_type" in
    "iterm")
        # iTerm2: 精确到 Session 的跳转
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
-- 自清理
do shell script "rm -f '$SCRIPT_FILE'"
EOF
        ;;
    "vscode")
        # Cursor/VS Code: 先激活应用再精确匹配窗口
        cat > "$SCRIPT_FILE" << EOF
set targetProject to "$project_name"
set appFound to false

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
        return
    end try
end if

-- 使用 System Events 精确匹配窗口
tell application "System Events"
    if appName = "Cursor" then
        tell process "Cursor"
            repeat with w in windows
                if name of w contains targetProject then
                    set value of attribute "AXMain" of w to true
                    perform action "AXRaise" of w
                    exit repeat
                end if
            end repeat
        end tell
    else
        tell process "Code"
            repeat with w in windows
                if name of w contains targetProject then
                    set value of attribute "AXMain" of w to true
                    perform action "AXRaise" of w
                    exit repeat
                end if
            end repeat
        end tell
    end if
end tell

-- 自清理
do shell script "rm -f '$SCRIPT_FILE'"
EOF
        ;;
    *)
        # 未知终端: 不创建跳转脚本
        SCRIPT_FILE=""
        ;;
esac

# ============== 发送通知 ==============
if [ -n "$SCRIPT_FILE" ] && [ -f "$SCRIPT_FILE" ]; then
    terminal-notifier \
        -title "Claude Code" \
        -subtitle "$project_name" \
        -message "$msg" \
        -sound "$sound" \
        -group "claude-code" \
        -execute "osascript '$SCRIPT_FILE'"
else
    # 无跳转脚本，仅发送通知
    terminal-notifier \
        -title "Claude Code" \
        -subtitle "$project_name" \
        -message "$msg" \
        -sound "$sound" \
        -group "claude-code"
fi

exit 0
