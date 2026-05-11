# tmux-aware Notification Jump Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Fix the "未知的终端类型: unknown" notification jump bug by introducing `iterm+tmux` as a first-class terminal type with full tmux session/window/pane awareness; tighten cursor/vscode branches; add per-pane border flash visual feedback.

**Architecture:** Refactor the two scripts (`notify-smart.sh`, `jump-to-claude.sh`) around three shared bash libs in `claude-notify/hooks/scripts/lib/` for logging, env-based terminal detection, and KV-format session info persistence. Jump phase resolves the iTerm host session at click time via `tmux list-clients` → `client_tty` → AppleScript reverse lookup, so re-attach scenarios work correctly. Border flash uses window-scope `pane-active-border-style` toggling with original-value snapshot/restore.

**Tech Stack:** bash 3.2 (macOS default), tmux ≥ 3.0, AppleScript (osascript), terminal-notifier (existing dep), Python 3 stdlib JSON parser (existing).

**Spec:** `docs/superpowers/specs/2026-05-12-tmux-aware-notify-jump-design.md`

---

## File Structure

**Created:**
- `claude-notify/hooks/scripts/lib/log.sh` — `log()` function with level + size-based rotation
- `claude-notify/hooks/scripts/lib/detect-terminal.sh` — `detect_terminal()` pure function reading env vars
- `claude-notify/hooks/scripts/lib/session-info.sh` — KV write/read with schema_version validation
- `claude-notify/tests/test-log.sh` — assertions for log helper
- `claude-notify/tests/test-detect-terminal.sh` — assertions for detection logic
- `claude-notify/tests/test-session-info.sh` — assertions for KV IO
- `claude-notify/tests/run-all.sh` — wrapper to run all unit tests

**Modified:**
- `claude-notify/hooks/scripts/notify-smart.sh` — full rewrite using libs
- `claude-notify/hooks/scripts/jump-to-claude.sh` — full rewrite with iterm+tmux branch
- `claude-notify/README.md` — document tmux support + troubleshooting

**Conventions:**
- All scripts: bash 3.2-compatible (no associative arrays, no `${var^^}`)
- Lib functions: never `exit`, always `return`; main scripts decide exit codes
- Tests: simple `[[ ... ]] || { echo FAIL; exit 1; }` assertions, sourced libs

---

## Task 1: Shared logging helper

**Why this matters:** Both scripts currently write to two separate ad-hoc debug logs without levels. A unified `log()` with rotation makes troubleshooting tractable and prevents `/tmp` from filling up across long-running sessions.

**Files:**
- Create: `claude-notify/hooks/scripts/lib/log.sh`
- Test: `claude-notify/tests/test-log.sh`

- [ ] **Step 1: Write the failing test**

Create `claude-notify/tests/test-log.sh`:

```bash
#!/bin/bash
set -e
SCRIPT_DIR="$(cd "$(dirname "$0")/../hooks/scripts" && pwd)"

# Isolated log path for test
TMP_LOG=$(mktemp)
trap 'rm -f "$TMP_LOG" "$TMP_LOG.tmp"' EXIT
export CLAUDE_NOTIFY_LOG="$TMP_LOG"

source "$SCRIPT_DIR/lib/log.sh"

# Test 1: writes INFO
log INFO "hello world"
grep -q "\[INFO\] hello world" "$TMP_LOG" || { echo "FAIL: INFO not written"; exit 1; }
echo "PASS: log writes INFO"

# Test 2: timestamp prefix
grep -qE "^[0-9]{4}-[0-9]{2}-[0-9]{2} [0-9]{2}:[0-9]{2}:[0-9]{2} \[INFO\]" "$TMP_LOG" || { echo "FAIL: timestamp format"; exit 1; }
echo "PASS: timestamp format"

# Test 3: rotation when > 1MB; keep last 500 lines + new entry
: > "$TMP_LOG"
for i in $(seq 1 60000); do echo "padding $i"; done >> "$TMP_LOG"   # ~720KB-1MB
yes "x" | head -c 400000 >> "$TMP_LOG"                              # push past 1MB
echo "tail-marker-XYZ" >> "$TMP_LOG"
log INFO "after rotation"
size=$(wc -c < "$TMP_LOG")
[ "$size" -lt 200000 ] || { echo "FAIL: not rotated (size=$size)"; exit 1; }
grep -q "tail-marker-XYZ" "$TMP_LOG" || { echo "FAIL: tail not preserved"; exit 1; }
grep -q "after rotation" "$TMP_LOG" || { echo "FAIL: new entry missing"; exit 1; }
echo "PASS: rotation works"

# Test 4: ERROR level
log ERROR "boom"
grep -q "\[ERROR\] boom" "$TMP_LOG" || { echo "FAIL: ERROR not written"; exit 1; }
echo "PASS: ERROR level"

echo "ALL TESTS PASS"
```

- [ ] **Step 2: Run the test, verify failure**

```bash
bash ~/.claude/plugins/marketplaces/build-your-system/claude-notify/tests/test-log.sh
```

Expected: error containing `lib/log.sh: No such file or directory`.

- [ ] **Step 3: Implement `lib/log.sh`**

Create `claude-notify/hooks/scripts/lib/log.sh`:

```bash
#!/bin/bash
# Shared logging helper for claude-notify scripts.
# Usage: log INFO|WARN|ERROR "message"

CLAUDE_NOTIFY_LOG="${CLAUDE_NOTIFY_LOG:-/tmp/claude-notify.log}"

log() {
    local level="$1"; shift
    local msg="$*"
    local ts
    ts=$(date '+%Y-%m-%d %H:%M:%S')

    if [ -f "$CLAUDE_NOTIFY_LOG" ] && [ "$(wc -c < "$CLAUDE_NOTIFY_LOG")" -gt 1048576 ]; then
        tail -n 500 "$CLAUDE_NOTIFY_LOG" > "$CLAUDE_NOTIFY_LOG.tmp" 2>/dev/null \
            && mv "$CLAUDE_NOTIFY_LOG.tmp" "$CLAUDE_NOTIFY_LOG"
    fi
    echo "$ts [$level] $msg" >> "$CLAUDE_NOTIFY_LOG"
}
```

- [ ] **Step 4: Run the test, verify pass**

```bash
bash ~/.claude/plugins/marketplaces/build-your-system/claude-notify/tests/test-log.sh
```

Expected: 4 `PASS:` lines + `ALL TESTS PASS`.

- [ ] **Step 5: Commit**

```bash
cd ~/.claude/plugins/marketplaces/build-your-system
git add claude-notify/hooks/scripts/lib/log.sh claude-notify/tests/test-log.sh
git commit -m "feat(claude-notify): add shared logging helper with rotation"
```

---

## Task 2: Terminal detection helper

**Why this matters:** Wrong detection IS the bug. Isolating it into a pure function (env vars in → `terminal_type` out) makes every branch testable without spawning real terminals.

**Files:**
- Create: `claude-notify/hooks/scripts/lib/detect-terminal.sh`
- Test: `claude-notify/tests/test-detect-terminal.sh`

- [ ] **Step 1: Write the failing test**

Create `claude-notify/tests/test-detect-terminal.sh`:

```bash
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
```

- [ ] **Step 2: Run the test, verify failure**

```bash
bash ~/.claude/plugins/marketplaces/build-your-system/claude-notify/tests/test-detect-terminal.sh
```

Expected: error `lib/detect-terminal.sh: No such file or directory`.

- [ ] **Step 3: Implement `lib/detect-terminal.sh`**

Create `claude-notify/hooks/scripts/lib/detect-terminal.sh`:

```bash
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
```

- [ ] **Step 4: Run the test, verify pass**

```bash
bash ~/.claude/plugins/marketplaces/build-your-system/claude-notify/tests/test-detect-terminal.sh
```

Expected: 7 `PASS:` lines + `ALL TESTS PASS`.

- [ ] **Step 5: Commit**

```bash
cd ~/.claude/plugins/marketplaces/build-your-system
git add claude-notify/hooks/scripts/lib/detect-terminal.sh claude-notify/tests/test-detect-terminal.sh
git commit -m "feat(claude-notify): add pure terminal detection helper"
```

---

## Task 3: Session info KV reader/writer

**Why this matters:** The colon-delimited format breaks on values containing colons (paths!) and is hostile to evolution. KV with schema version lets the two scripts evolve independently and gives forward-compatibility errors a chance to be meaningful.

**Files:**
- Create: `claude-notify/hooks/scripts/lib/session-info.sh`
- Test: `claude-notify/tests/test-session-info.sh`

- [ ] **Step 1: Write the failing test**

Create `claude-notify/tests/test-session-info.sh`:

```bash
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
```

- [ ] **Step 2: Run the test, verify failure**

```bash
bash ~/.claude/plugins/marketplaces/build-your-system/claude-notify/tests/test-session-info.sh
```

Expected: error `lib/session-info.sh: No such file or directory`.

- [ ] **Step 3: Implement `lib/session-info.sh`**

Create `claude-notify/hooks/scripts/lib/session-info.sh`:

```bash
#!/bin/bash
# KV-format session info persistence.
# write_session_info key1=val1 key2=val2 ...  → writes /tmp/claude-last-session-info
# read_session_info                            → sets vars in caller's scope
#
# Safety: read does NOT `source`/`eval`; values are parsed literally.

CLAUDE_SESSION_INFO_FILE="${CLAUDE_SESSION_INFO_FILE:-/tmp/claude-last-session-info}"
CLAUDE_SESSION_INFO_SCHEMA=2

write_session_info() {
    local tmp="$CLAUDE_SESSION_INFO_FILE.tmp.$$"
    {
        echo "schema_version=$CLAUDE_SESSION_INFO_SCHEMA"
        echo "timestamp=$(date '+%Y-%m-%dT%H:%M:%S')"
        local kv
        for kv in "$@"; do
            echo "$kv"
        done
    } > "$tmp" && mv "$tmp" "$CLAUDE_SESSION_INFO_FILE"
}

read_session_info() {
    if [ ! -f "$CLAUDE_SESSION_INFO_FILE" ]; then
        return 2
    fi
    local schema=""
    local line key value
    while IFS= read -r line; do
        # Allow only [a-z_][a-z0-9_]*=anything
        if [[ "$line" =~ ^([a-z_][a-z0-9_]*)=(.*)$ ]]; then
            key="${BASH_REMATCH[1]}"
            value="${BASH_REMATCH[2]}"
            if [ "$key" = "schema_version" ]; then
                schema="$value"
            fi
            # Use printf -v for safe assignment to dynamic name (no eval)
            printf -v "$key" '%s' "$value"
        fi
    done < "$CLAUDE_SESSION_INFO_FILE"

    if [ -z "$schema" ]; then
        return 3
    fi
    if [ "$schema" -gt "$CLAUDE_SESSION_INFO_SCHEMA" ] 2>/dev/null; then
        return 4
    fi
    return 0
}
```

- [ ] **Step 4: Run the test, verify pass**

```bash
bash ~/.claude/plugins/marketplaces/build-your-system/claude-notify/tests/test-session-info.sh
```

Expected: 7 `PASS:` lines + `ALL TESTS PASS`.

- [ ] **Step 5: Add a test runner**

Create `claude-notify/tests/run-all.sh`:

```bash
#!/bin/bash
# Run all unit tests for claude-notify libs.
set -e
DIR="$(cd "$(dirname "$0")" && pwd)"
fail=0
for t in "$DIR"/test-*.sh; do
    echo "=== $(basename "$t") ==="
    if ! bash "$t"; then
        fail=$((fail+1))
    fi
    echo ""
done
if [ "$fail" -gt 0 ]; then
    echo "FAILED: $fail test files failed"
    exit 1
fi
echo "ALL TEST FILES PASS"
```

Then:

```bash
chmod +x ~/.claude/plugins/marketplaces/build-your-system/claude-notify/tests/run-all.sh
bash ~/.claude/plugins/marketplaces/build-your-system/claude-notify/tests/run-all.sh
```

Expected: all 3 test files pass.

- [ ] **Step 6: Commit**

```bash
cd ~/.claude/plugins/marketplaces/build-your-system
git add claude-notify/hooks/scripts/lib/session-info.sh \
        claude-notify/tests/test-session-info.sh \
        claude-notify/tests/run-all.sh
git commit -m "feat(claude-notify): add KV session info IO with schema versioning"
```

---

## Task 4: Rewrite `notify-smart.sh`

**Why this matters:** This wires together everything from Tasks 1-3 and adds the tmux-aware focus detection. The script is now thin: detect → gather tmux details if applicable → focus check → write KV → emit notification.

**Files:**
- Modify: `claude-notify/hooks/scripts/notify-smart.sh` (full rewrite)

- [ ] **Step 1: Rewrite the script**

Replace the entire contents of `claude-notify/hooks/scripts/notify-smart.sh` with:

```bash
#!/bin/bash
# Multi-terminal smart notifier for Claude Code hooks.
# Detects: iterm+tmux (new), iterm, cursor, vscode, unknown.
# Suppresses notification when target window is already focused.

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
if [ "$terminal_type" = "iterm+tmux" ]; then
    tmux_session_id=$(tmux display-message -p '#{session_id}' 2>/dev/null)
    tmux_session_name=$(tmux display-message -p '#{session_name}' 2>/dev/null)
    tmux_window_id=$(tmux display-message -p '#{window_id}' 2>/dev/null)
    tmux_pane_id="$TMUX_PANE"
    log INFO "notify: tmux session=$tmux_session_id($tmux_session_name) win=$tmux_window_id pane=$tmux_pane_id"
fi

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
            if [ "$front_tty" = "$client_tty" ] && [ "$active_pane" = "$tmux_pane_id" ]; then
                should_notify=false
            fi
        fi
        ;;
    "cursor"|"vscode")
        target_app="Cursor"
        [ "$terminal_type" = "vscode" ] && target_app="Code"
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
    project_name="$project_name" \
    claude_cwd="$claude_cwd"

# ---- 6. Emit notification ----
case "$hook_event" in
    "Stop")         msg="任务完成"; sound="Glass" ;;
    "Notification") msg="${message:-需要你的确认}"; sound="Ping" ;;
    *)              msg="需要你的注意"; sound="Glass" ;;
esac

jump_script="$SCRIPT_DIR/jump-to-claude.sh"
terminal-notifier \
    -title "Claude Code" \
    -subtitle "$project_name" \
    -message "$msg" \
    -sound "$sound" \
    -group "claude-code" \
    -execute "$jump_script"

log INFO "notify: emitted ($terminal_type) project=$project_name"
exit 0
```

- [ ] **Step 2: Lint / dry-run syntax check**

```bash
bash -n ~/.claude/plugins/marketplaces/build-your-system/claude-notify/hooks/scripts/notify-smart.sh
```

Expected: no output (no syntax errors).

- [ ] **Step 3: Manual smoke test — write fake hook input**

```bash
echo '{"cwd":"/Users/jliu/Projects/vault","hook_event_name":"Notification","message":"test"}' \
    | bash ~/.claude/plugins/marketplaces/build-your-system/claude-notify/hooks/scripts/notify-smart.sh
```

Expected:
- macOS notification banner appears titled "Claude Code", subtitle "vault", message "test"
- `/tmp/claude-last-session-info` exists with `schema_version=2` and `terminal_type` matching your env
- `/tmp/claude-notify.log` has a fresh `[INFO] notify:` line

```bash
cat /tmp/claude-last-session-info
tail -3 /tmp/claude-notify.log
```

- [ ] **Step 4: Commit**

```bash
cd ~/.claude/plugins/marketplaces/build-your-system
git add claude-notify/hooks/scripts/notify-smart.sh
git commit -m "refactor(claude-notify): rewrite notify-smart.sh using shared libs + tmux detection"
```

---

## Task 5: Rewrite `jump-to-claude.sh` — shell + iterm+tmux branch

**Why this matters:** This is the meat of the fix. The shell dispatches by `terminal_type`, and the `iterm+tmux` branch implements the tmux-state-check → iTerm-resolve → 3-level-switch → border-flash flow. Subsequent task adds remaining branches.

**Files:**
- Modify: `claude-notify/hooks/scripts/jump-to-claude.sh` (full rewrite, but only iterm+tmux branch + dispatch shell in this task)

- [ ] **Step 1: Write the new script with iterm+tmux branch only**

Replace contents of `claude-notify/hooks/scripts/jump-to-claude.sh` with:

```bash
#!/bin/bash
# Jump to the Claude Code session/pane that emitted the last notification.
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
        tmux switch-client -t "$tmux_session_id" 2>/dev/null
        tmux select-window -t "$tmux_window_id" 2>/dev/null
        tmux select-pane   -t "$tmux_pane_id"   2>/dev/null

        # ---- D. Border flash 3x (background, won't block notification callback) ----
        orig=$(tmux show-window-options -t "$tmux_window_id" -v pane-active-border-style 2>/dev/null || true)
        (
            for i in 1 2 3; do
                tmux set-window-option -t "$tmux_window_id" pane-active-border-style 'fg=yellow,bold' 2>/dev/null
                sleep 0.2
                if [ -n "$orig" ]; then
                    tmux set-window-option -t "$tmux_window_id" pane-active-border-style "$orig" 2>/dev/null
                else
                    tmux set-window-option -t "$tmux_window_id" -u pane-active-border-style 2>/dev/null
                fi
                sleep 0.2
            done
        ) & disown
        log INFO "jump: iterm+tmux complete (tty=$client_tty pane=$tmux_pane_id)"
        ;;

    *)
        # Other branches added in Task 6
        notify_error "未实现的终端类型" "$terminal_type (Task 6 待实现)"
        exit 1
        ;;
esac

exit 0
```

- [ ] **Step 2: Syntax check**

```bash
bash -n ~/.claude/plugins/marketplaces/build-your-system/claude-notify/hooks/scripts/jump-to-claude.sh
```

Expected: no output.

- [ ] **Step 3: Manual smoke test — fake KV file pointing at current tmux pane**

If you are currently in a tmux session inside iTerm2, run from the tmux pane:

```bash
cd ~/.claude/plugins/marketplaces/build-your-system
SCRIPT_DIR="$PWD/claude-notify/hooks/scripts"
source "$SCRIPT_DIR/lib/session-info.sh"
write_session_info \
    terminal_type=iterm+tmux \
    tmux_session_id="$(tmux display-message -p '#{session_id}')" \
    tmux_session_name="$(tmux display-message -p '#{session_name}')" \
    tmux_window_id="$(tmux display-message -p '#{window_id}')" \
    tmux_pane_id="$TMUX_PANE" \
    project_name=test \
    claude_cwd="$PWD"

# Switch away from this pane (e.g., split a new pane and focus it, or focus another app),
# then run:
bash "$SCRIPT_DIR/jump-to-claude.sh"
```

Expected:
- macOS focuses iTerm2
- tmux focuses the original pane
- Pane border flashes yellow ~3 times
- `tail -5 /tmp/claude-notify.log` shows `[INFO] jump: iterm+tmux complete`

- [ ] **Step 4: Commit**

```bash
cd ~/.claude/plugins/marketplaces/build-your-system
git add claude-notify/hooks/scripts/jump-to-claude.sh
git commit -m "feat(claude-notify): rewrite jump script with iterm+tmux branch + border flash"
```

---

## Task 6: Add remaining jump branches (iterm, cursor, vscode)

**Why this matters:** Restore the non-tmux paths after Task 5's scaffold. Cursor/vscode are now first-class (no fallback between them); iterm keeps its existing behavior but reads from KV format.

**Files:**
- Modify: `claude-notify/hooks/scripts/jump-to-claude.sh` (replace the `*)` catch-all with concrete branches)

- [ ] **Step 1: Replace the `*)` catch-all with concrete branches**

In `claude-notify/hooks/scripts/jump-to-claude.sh`, replace this block:

```bash
    *)
        # Other branches added in Task 6
        notify_error "未实现的终端类型" "$terminal_type (Task 6 待实现)"
        exit 1
        ;;
```

With:

```bash
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
```

- [ ] **Step 2: Syntax check**

```bash
bash -n ~/.claude/plugins/marketplaces/build-your-system/claude-notify/hooks/scripts/jump-to-claude.sh
```

Expected: no output.

- [ ] **Step 3: Manual smoke test — iterm branch**

Open a non-tmux iTerm2 tab/window, then in that tab run:

```bash
cd ~/.claude/plugins/marketplaces/build-your-system
SCRIPT_DIR="$PWD/claude-notify/hooks/scripts"
source "$SCRIPT_DIR/lib/session-info.sh"
sid="${ITERM_SESSION_ID##*:}"
write_session_info terminal_type=iterm claude_session_id="$sid" project_name=test claude_cwd="$PWD"
# Switch to another iTerm tab/window, then:
bash "$SCRIPT_DIR/jump-to-claude.sh"
```

Expected: focus returns to the original iTerm session.

- [ ] **Step 4: Commit**

```bash
cd ~/.claude/plugins/marketplaces/build-your-system
git add claude-notify/hooks/scripts/jump-to-claude.sh
git commit -m "feat(claude-notify): implement iterm/cursor/vscode jump branches"
```

---

## Task 7: README updates

**Why this matters:** New tmux capability + new failure modes need user-facing docs so people can self-diagnose without reading scripts.

**Files:**
- Modify: `claude-notify/README.md`

- [ ] **Step 1: Read existing README**

```bash
cat ~/.claude/plugins/marketplaces/build-your-system/claude-notify/README.md
```

- [ ] **Step 2: Append tmux + troubleshooting sections**

Add the following sections to the end of `claude-notify/README.md` (verbatim — replace path/spec references if format differs from existing structure):

```markdown
## tmux 支持

当你在 tmux 内运行 Claude（iTerm2 → tmux → claude），通知点击会自动：

1. 切回 iTerm2 应用
2. 定位到 host 该 tmux client 的 iTerm session（通过 `tmux list-clients` 的 client tty 反查）
3. 在 tmux 内 `switch-client` / `select-window` / `select-pane` 三级跳转
4. 闪烁目标 pane 边框 3 次（黄色 200ms ↔ 默认 200ms）

**已知限制：**

- tmux session detach 状态下点击通知：显示错误"session 已 detach，请手动 attach"。脚本不自动 reattach。
- nested tmux 按内层 `$TMUX` 识别。
- 集成终端（VS Code / Cursor）：跳转停在 window 级，无法定位具体 terminal pane（macOS 自动化能力上限）。

## 故障排查

- 日志：`/tmp/claude-notify.log`（最大 1MB，自动 rotate 保留最后 500 行）
- 上次通知的会话信息：`cat /tmp/claude-last-session-info`
- 单元测试：`bash claude-notify/tests/run-all.sh`

**常见错误通知：**

| 标题 | 含义 |
|------|------|
| tmux 状态异常 | tmux session/pane 已关闭或 detach |
| iTerm 未找到 | tmux client tty 不再对应任何 iTerm session |
| 应用未运行 | Cursor / VS Code 未启动 |
| 通知格式过旧 | session info 文件 schema 版本不匹配（请触发新通知后再点击） |
```

- [ ] **Step 3: Commit**

```bash
cd ~/.claude/plugins/marketplaces/build-your-system
git add claude-notify/README.md
git commit -m "docs(claude-notify): document tmux support and troubleshooting"
```

---

## Task 8: Manual integration testing (spec §7 scenarios)

**Why this matters:** Unit tests cover detection + KV IO; integration tests cover the real-world flow with iTerm/tmux/AppleScript. These must be human-verified.

**Files:** None (test execution + log review only)

- [ ] **Step 1: Unit tests pass**

```bash
bash ~/.claude/plugins/marketplaces/build-your-system/claude-notify/tests/run-all.sh
```

Expected: `ALL TEST FILES PASS`.

- [ ] **Step 2: Scenario 1 — iTerm+tmux focused (suppression)**

Setup: tmux pane running Claude is currently focused in iTerm2 frontmost.

Action: trigger a notification (e.g., `echo '{"cwd":"/Users/jliu/Projects/vault","hook_event_name":"Stop","message":""}' | bash claude-notify/hooks/scripts/notify-smart.sh`)

Expected: no macOS notification appears. `tail /tmp/claude-notify.log` shows `already focused, suppressing`.

- [ ] **Step 3: Scenario 2 — iTerm+tmux unfocused (jump + flash)**

Setup: same tmux pane, but switch macOS focus to e.g. Chrome.

Action: trigger notification (same command).

Expected:
- macOS notification appears
- Click it → focus returns to iTerm2 → correct tmux pane → border flashes yellow 3×

- [ ] **Step 4: Scenario 3 — switched to other tmux pane**

Setup: switch to another pane in the same tmux window (still inside iTerm2).

Action: trigger notification.

Expected: notification appears (active pane differs from target). Click → border flashes target pane.

- [ ] **Step 5: Scenario 4 — tmux detach error path**

Setup: `tmux detach` (loses client).

Action: trigger notification by running notify-smart.sh inside the (now detached) shell or simulate via fake KV write.

Expected: clicking notification shows "tmux 状态异常 — session 'X' 已 detach，请手动 attach".

- [ ] **Step 6: Scenario 5 — reattach from new iTerm window**

Setup: close the original iTerm window; open a new one; `tmux a -t <session>`.

Action: trigger notification, click.

Expected: jump lands in the NEW iTerm window's session (client_tty re-resolution worked).

- [ ] **Step 7: Scenario 6 — bare iTerm (no tmux)**

Setup: open a fresh iTerm tab, do NOT enter tmux. Run notify-smart.sh.

Expected: notification → click → focus that tab (no border flash, which is expected).

- [ ] **Step 8: Scenario 7 — Cursor**

Setup: open a project in Cursor, focus another app. Run notify-smart.sh from Cursor's integrated terminal in that project.

Expected: notification → click → Cursor focused, correct window raised. **Critical:** verify Cursor is activated (not VS Code), even if VS Code is also installed.

- [ ] **Step 9: Scenario 8 — VS Code**

Same as Scenario 7 but in VS Code's terminal.

Expected: VS Code activated (not Cursor).

- [ ] **Step 10: Scenario 9 — Cursor already focused + same project window**

Setup: Cursor frontmost with target project window in front.

Expected: notification suppressed.

- [ ] **Step 11: Scenario 10 — old schema graceful fail**

```bash
echo "terminal_type=iterm" > /tmp/claude-last-session-info  # no schema_version
bash ~/.claude/plugins/marketplaces/build-your-system/claude-notify/hooks/scripts/jump-to-claude.sh
```

Expected: notification "通知格式过旧 — 请重新触发一次通知". No crash.

- [ ] **Step 12: Record results**

Append a short results block to the spec (or a new file at `docs/superpowers/specs/2026-05-12-tmux-aware-notify-jump-test-results.md`) noting which scenarios passed. Commit.

```bash
cd ~/.claude/plugins/marketplaces/build-your-system
# After writing results doc:
git add docs/superpowers/specs/2026-05-12-tmux-aware-notify-jump-test-results.md
git commit -m "docs(claude-notify): record manual integration test results"
```

---

## Self-Review

**Spec coverage check (versus `docs/superpowers/specs/2026-05-12-tmux-aware-notify-jump-design.md`):**

| Spec section | Tasks |
|--------------|-------|
| §1 problem (unknown bug) | Task 2 (detection), Task 4 (notify rewrite), Task 5 (jump rewrite) |
| §2 architecture / detection priority | Task 2 |
| §3 KV persistence + schema version | Task 3 |
| §4.1 iterm+tmux jump flow (4 steps) | Task 5 |
| §4.3 other branches (iterm/cursor/vscode/unknown) | Task 6 |
| §4.4 cursor/vscode focus detection | Task 4 (focus detection section) |
| §5 error messages | Task 5 + Task 6 (notify_error helper everywhere) |
| §6 unified logging | Task 1 |
| §7 test scenarios 1-10 | Task 8 |

No gaps.

**Placeholder scan:** No TBD / TODO / "implement later" in any step. All code blocks complete.

**Type/name consistency:** `terminal_type` / `claude_session_id` / `tmux_session_id` / `tmux_pane_id` / `tmux_window_id` / `tmux_session_name` / `project_name` / `claude_cwd` consistent across all tasks. `log` / `detect_terminal` / `read_session_info` / `write_session_info` function names consistent.

**Note on bash 3.2 compatibility:** All scripts use only POSIX/bash 3.2 constructs (no `declare -A`, no `${var^^}`, no `mapfile`). `printf -v` is bash 3.1+.

---

## Execution

Plan complete and saved to `docs/superpowers/plans/2026-05-12-tmux-aware-notify-jump.md`. Two execution options:

1. **Subagent-Driven** — Fresh subagent per task, review between tasks, fast iteration
2. **Inline Execution** — Execute tasks in this session using executing-plans, batch with checkpoints

Pick one.
