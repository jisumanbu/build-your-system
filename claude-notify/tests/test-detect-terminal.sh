#!/bin/bash
set -e
SCRIPT_DIR="$(cd "$(dirname "$0")/../hooks/scripts" && pwd)"

# Run detect_terminal in a clean subshell with given env, return "type|claude_session_id"
run_detect() {
    bash -c "
        unset TMUX TMUX_PANE ITERM_SESSION_ID VSCODE_GIT_ASKPASS_NODE TERM_PROGRAM
        $1
        source '$SCRIPT_DIR/lib/detect-terminal.sh'
        detect_terminal
        echo \"\$terminal_type|\$claude_session_id\"
    "
}

assert_eq() { [ "$1" = "$2" ] || { echo "FAIL: expected '$2', got '$1'"; exit 1; }; }

# 1. iterm+tmux wins over ITERM_SESSION_ID
result=$(run_detect 'export TMUX=/tmp/tmux-501/default TMUX_PANE=%5 ITERM_SESSION_ID="w0t0p0:abc-def"')
assert_eq "$result" "iterm+tmux|"
echo "PASS: iterm+tmux wins over iterm"

# 2. iterm alone
result=$(run_detect 'export ITERM_SESSION_ID="w0t0p0:abc-def"')
assert_eq "$result" "iterm|abc-def"
echo "PASS: iterm + session_id parsing"

# 3. cursor by ASKPASS_NODE
result=$(run_detect 'export VSCODE_GIT_ASKPASS_NODE="/Applications/Cursor.app/Contents/x" TERM_PROGRAM=vscode')
assert_eq "$result" "cursor|"
echo "PASS: cursor detection"

# 4. vscode by ASKPASS_NODE
result=$(run_detect 'export VSCODE_GIT_ASKPASS_NODE="/Applications/Visual Studio Code.app/x" TERM_PROGRAM=vscode')
assert_eq "$result" "vscode|"
echo "PASS: vscode detection"

# 5. TERM_PROGRAM=vscode only → fallback cursor
result=$(run_detect 'export TERM_PROGRAM=vscode')
assert_eq "$result" "cursor|"
echo "PASS: TERM_PROGRAM-only fallback"

# 6. empty env → unknown
result=$(run_detect ':')
assert_eq "$result" "unknown|"
echo "PASS: unknown"

# 7. TMUX but no TMUX_PANE → unknown (edge case)
result=$(run_detect 'export TMUX=/tmp/socket')
assert_eq "$result" "unknown|"
echo "PASS: TMUX without TMUX_PANE → unknown"

echo "ALL TESTS PASS"
