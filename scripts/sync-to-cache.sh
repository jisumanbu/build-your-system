#!/bin/bash
# Sync plugin sources from this marketplace repo to Claude Code's runtime cache.
#
# Why: Claude Code loads plugins from ~/.claude/plugins/cache/<marketplace>/<plugin>/<version>/,
# not from the marketplace source directory. Editing files here without syncing means
# Claude Code keeps running the old code from cache.
#
# Run this manually, or rely on the git post-commit hook to invoke it.

set -e
MARKETPLACE_DIR="$(cd "$(dirname "$0")/.." && pwd)"
MARKETPLACE_NAME="$(basename "$MARKETPLACE_DIR")"
CACHE_BASE="$HOME/.claude/plugins/cache/$MARKETPLACE_NAME"

if [ ! -d "$CACHE_BASE" ]; then
    echo "ERROR: cache base does not exist: $CACHE_BASE" >&2
    echo "Is the plugin installed via Claude Code first?" >&2
    exit 1
fi

synced=0
skipped=0
for plugin_dir in "$MARKETPLACE_DIR"/*/; do
    plugin_name="$(basename "$plugin_dir")"
    plugin_json="$plugin_dir.claude-plugin/plugin.json"
    [ -f "$plugin_json" ] || continue

    version="$(/usr/bin/python3 -c "import json; print(json.load(open('$plugin_json'))['version'])" 2>/dev/null)"
    if [ -z "$version" ]; then
        echo "[!] $plugin_name: no version in plugin.json, skipping"
        skipped=$((skipped + 1))
        continue
    fi

    cache_dir="$CACHE_BASE/$plugin_name/$version"
    if [ ! -d "$cache_dir" ]; then
        echo "[!] $plugin_name v$version: not installed (no $cache_dir), skipping"
        skipped=$((skipped + 1))
        continue
    fi

    # Preserve .in_use/<PID> markers across rsync --delete
    in_use_backup=""
    if [ -d "$cache_dir/.in_use" ]; then
        in_use_backup="$(mktemp -d)"
        cp -R "$cache_dir/.in_use/." "$in_use_backup/" 2>/dev/null || true
    fi

    rsync -a --delete "$plugin_dir" "$cache_dir/" > /dev/null

    if [ -n "$in_use_backup" ]; then
        mkdir -p "$cache_dir/.in_use"
        cp -R "$in_use_backup/." "$cache_dir/.in_use/" 2>/dev/null || true
        rm -rf "$in_use_backup"
    fi

    echo "[OK] $plugin_name v$version -> cache"
    synced=$((synced + 1))
done

echo ""
echo "Synced $synced plugin(s); skipped $skipped."
