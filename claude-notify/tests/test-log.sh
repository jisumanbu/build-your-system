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
