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
