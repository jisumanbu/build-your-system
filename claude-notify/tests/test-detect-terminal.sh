#!/bin/bash
set -e
SCRIPT_DIR="$(cd "$(dirname "$0")/../hooks/scripts" && pwd)"

# Run detect_terminal in a clean subshell with given env + optional
# overrides (e.g. stubbing _detect_tmux_host).
# Returns "type|claude_session_id"
run_detect() {
    bash -c "
        unset TMUX TMUX_PANE ITERM_SESSION_ID VSCODE_GIT_ASKPASS_NODE TERM_PROGRAM
        source '$SCRIPT_DIR/lib/detect-terminal.sh'
        $1
        detect_terminal
        echo \"\$terminal_type|\$claude_session_id\"
    "
}

assert_eq() { [ "$1" = "$2" ] || { echo "FAIL: expected '$2', got '$1'"; exit 1; }; }

# 1. iterm+tmux: $TMUX set, host detected as iterm
result=$(run_detect 'export TMUX=/tmp/x TMUX_PANE=%5; _detect_tmux_host() { echo iterm; }')
assert_eq "$result" "iterm+tmux|"
echo "PASS: tmux + iTerm host"

# 2. cursor+tmux: $TMUX set, host detected as cursor (NEW)
result=$(run_detect 'export TMUX=/tmp/x TMUX_PANE=%5; _detect_tmux_host() { echo cursor; }')
assert_eq "$result" "cursor+tmux|"
echo "PASS: tmux + Cursor host"

# 3. vscode+tmux: $TMUX set, host detected as vscode (NEW)
result=$(run_detect 'export TMUX=/tmp/x TMUX_PANE=%5; _detect_tmux_host() { echo vscode; }')
assert_eq "$result" "vscode+tmux|"
echo "PASS: tmux + VS Code host"

# 4. tmux with unknown host: fallback to iterm+tmux (preserves backward compat)
result=$(run_detect 'export TMUX=/tmp/x TMUX_PANE=%5; _detect_tmux_host() { return 1; }')
assert_eq "$result" "iterm+tmux|"
echo "PASS: tmux + unknown host falls back to iterm+tmux"

# 5. tmux wins over ITERM_SESSION_ID
result=$(run_detect 'export TMUX=/tmp/x TMUX_PANE=%5 ITERM_SESSION_ID="w0t0p0:abc-def"; _detect_tmux_host() { echo iterm; }')
assert_eq "$result" "iterm+tmux|"
echo "PASS: tmux branch wins over iterm branch"

# 6. iterm alone (no tmux)
result=$(run_detect 'export ITERM_SESSION_ID="w0t0p0:abc-def"')
assert_eq "$result" "iterm|abc-def"
echo "PASS: iterm + session_id parsing"

# 7. cursor by ASKPASS_NODE
result=$(run_detect 'export VSCODE_GIT_ASKPASS_NODE="/Applications/Cursor.app/Contents/x" TERM_PROGRAM=vscode')
assert_eq "$result" "cursor|"
echo "PASS: cursor detection"

# 8. vscode by ASKPASS_NODE
result=$(run_detect 'export VSCODE_GIT_ASKPASS_NODE="/Applications/Visual Studio Code.app/x" TERM_PROGRAM=vscode')
assert_eq "$result" "vscode|"
echo "PASS: vscode detection"

# 9. TERM_PROGRAM=vscode only → fallback cursor
result=$(run_detect 'export TERM_PROGRAM=vscode')
assert_eq "$result" "cursor|"
echo "PASS: TERM_PROGRAM-only fallback"

# 10. empty env → unknown
result=$(run_detect ':')
assert_eq "$result" "unknown|"
echo "PASS: unknown"

# 11. TMUX but no TMUX_PANE → unknown (edge case)
result=$(run_detect 'export TMUX=/tmp/socket')
assert_eq "$result" "unknown|"
echo "PASS: TMUX without TMUX_PANE → unknown"

echo "ALL TESTS PASS"
