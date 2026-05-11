#!/bin/bash
# Pure terminal-type detection from environment variables.
# Sets globals: terminal_type, claude_session_id
# Does NOT call tmux/osascript — callers gather more details after.

detect_terminal() {
    terminal_type=""
    claude_session_id=""

    if [ -n "$TMUX" ] && [ -n "$TMUX_PANE" ]; then
        terminal_type="iterm+tmux"
    elif [ -n "$ITERM_SESSION_ID" ]; then
        terminal_type="iterm"
        claude_session_id="${ITERM_SESSION_ID##*:}"
    elif [[ "$VSCODE_GIT_ASKPASS_NODE" == *"Cursor.app"* ]]; then
        terminal_type="cursor"
    elif [[ "$VSCODE_GIT_ASKPASS_NODE" == *"Visual Studio Code"* ]]; then
        terminal_type="vscode"
    elif [ "$TERM_PROGRAM" = "vscode" ]; then
        terminal_type="cursor"
    else
        terminal_type="unknown"
    fi
}
