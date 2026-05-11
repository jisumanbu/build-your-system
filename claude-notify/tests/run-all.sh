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
