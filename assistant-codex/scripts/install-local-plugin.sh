#!/bin/zsh

set -euo pipefail

PLUGIN_NAME="build-your-system-assistant"
MARKETPLACE_NAME="local-build-your-system"
PLUGIN_VERSION="local"
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
SOURCE_ROOT="${SOURCE_ROOT:-$(cd "${SCRIPT_DIR}/.." && pwd)}"
CACHE_ROOT="${HOME}/.codex/plugins/cache/${MARKETPLACE_NAME}/${PLUGIN_NAME}/${PLUGIN_VERSION}"

if [[ ! -d "${SOURCE_ROOT}" ]]; then
  echo "Plugin source not found: ${SOURCE_ROOT}" >&2
  exit 1
fi

mkdir -p "$(dirname "${CACHE_ROOT}")"
rm -rf "${CACHE_ROOT}"
mkdir -p "${CACHE_ROOT}"
rsync -a --delete --exclude '.git' "${SOURCE_ROOT}/" "${CACHE_ROOT}/"

echo "Installed ${PLUGIN_NAME} to ${CACHE_ROOT}"
