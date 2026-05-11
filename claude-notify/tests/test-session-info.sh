#!/bin/bash
set -e
SCRIPT_DIR="$(cd "$(dirname "$0")/../hooks/scripts" && pwd)"

TMP_INFO=$(mktemp)
trap 'rm -f "$TMP_INFO"' EXIT
export CLAUDE_SESSION_INFO_FILE="$TMP_INFO"

source "$SCRIPT_DIR/lib/session-info.sh"

assert_eq() { [ "$1" = "$2" ] || { echo "FAIL: expected '$2', got '$1'"; exit 1; }; }

# Test 1: write then read round-trip
write_session_info \
    terminal_type=iterm+tmux \
    tmux_session_id='$0' \
    tmux_session_name=work \
    tmux_window_id=@3 \
    tmux_pane_id=%5 \
    project_name=vault \
    claude_cwd=/Users/jliu/Projects/vault

# File should be readable
[ -s "$TMP_INFO" ] || { echo "FAIL: empty session info"; exit 1; }
echo "PASS: write_session_info creates non-empty file"

# Test 2: contains schema_version
grep -q "^schema_version=2$" "$TMP_INFO" || { echo "FAIL: schema_version missing"; exit 1; }
echo "PASS: schema_version=2 written"

# Test 3: read_session_info populates env
unset terminal_type tmux_session_id tmux_pane_id project_name
read_session_info
assert_eq "$terminal_type" "iterm+tmux"
assert_eq "$tmux_session_id" '$0'
assert_eq "$tmux_pane_id" "%5"
assert_eq "$project_name" "vault"
echo "PASS: read_session_info round-trip"

# Test 4: values with special chars (path with spaces)
write_session_info \
    terminal_type=iterm \
    claude_cwd='/Users/jliu/My Projects/foo' \
    project_name='foo'
unset claude_cwd project_name
read_session_info
assert_eq "$claude_cwd" "/Users/jliu/My Projects/foo"
echo "PASS: values with spaces survive round-trip"

# Test 5: missing schema_version is rejected
echo "terminal_type=iterm" > "$TMP_INFO"
unset terminal_type
if read_session_info 2>/dev/null; then
    echo "FAIL: read should return non-zero on missing schema"
    exit 1
fi
echo "PASS: rejects missing schema_version"

# Test 6: future schema_version is rejected
echo "schema_version=99" > "$TMP_INFO"
echo "terminal_type=iterm" >> "$TMP_INFO"
if read_session_info 2>/dev/null; then
    echo "FAIL: read should reject schema_version=99"
    exit 1
fi
echo "PASS: rejects future schema_version"

# Test 7: malicious value (command substitution attempt) does not execute
echo "schema_version=2" > "$TMP_INFO"
echo 'terminal_type=$(touch /tmp/pwned-claude-notify-test)' >> "$TMP_INFO"
read_session_info
[ ! -f /tmp/pwned-claude-notify-test ] || { rm /tmp/pwned-claude-notify-test; echo "FAIL: command substitution executed"; exit 1; }
echo "PASS: no command substitution on read"

echo "ALL TESTS PASS"
