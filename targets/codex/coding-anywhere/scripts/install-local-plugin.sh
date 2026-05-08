#!/bin/zsh

set -euo pipefail

PLUGIN_NAME="coding-anywhere"
MARKETPLACE_NAME="local-build-your-system"
PLUGIN_VERSION="local"
SCRIPT_DIR="$(cd -- "$(dirname -- "$0")" && pwd)"
TARGET_ROOT="$(cd -- "${SCRIPT_DIR}/.." && pwd)"
SOURCE_ROOT="${HOME}/plugins/${PLUGIN_NAME}"
MARKETPLACE_FILE="${HOME}/.agents/plugins/marketplace.json"
CACHE_ROOT="${HOME}/.codex/plugins/cache/${MARKETPLACE_NAME}/${PLUGIN_NAME}/${PLUGIN_VERSION}"

mkdir -p "${HOME}/plugins" "${HOME}/.agents/plugins"
ln -sfn "${TARGET_ROOT}" "${SOURCE_ROOT}"

MARKETPLACE_FILE="${MARKETPLACE_FILE}" python3 <<'PY'
import json
import os
from pathlib import Path

marketplace_file = Path(os.environ["MARKETPLACE_FILE"])
entry = {
    "name": "coding-anywhere",
    "source": {"source": "local", "path": "./plugins/coding-anywhere"},
    "policy": {"installation": "AVAILABLE", "authentication": "ON_INSTALL"},
    "category": "Productivity",
}

if marketplace_file.exists():
    data = json.loads(marketplace_file.read_text(encoding="utf-8"))
else:
    data = {"plugins": []}

plugins = [plugin for plugin in data.get("plugins", []) if plugin.get("name") != entry["name"]]
plugins.append(entry)
data["plugins"] = plugins

marketplace_file.write_text(
    json.dumps(data, ensure_ascii=False, indent=2) + "\n",
    encoding="utf-8",
)
PY

mkdir -p "$(dirname "${CACHE_ROOT}")"
rm -rf "${CACHE_ROOT}"
mkdir -p "${CACHE_ROOT}"
rsync -a --delete --exclude '.git' "${SOURCE_ROOT}/" "${CACHE_ROOT}/"

echo "Linked ${PLUGIN_NAME} to ${SOURCE_ROOT}"
echo "Updated personal marketplace: ${MARKETPLACE_FILE}"
echo "Installed ${PLUGIN_NAME} to ${CACHE_ROOT}"
