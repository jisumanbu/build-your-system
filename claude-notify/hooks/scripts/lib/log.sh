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
