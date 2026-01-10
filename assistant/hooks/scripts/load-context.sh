#!/bin/bash
# Load user context at session start
# 根据 CLAUDE.md 的"快速上下文"要求加载三个文件

# 使用 CLAUDE_PLUGIN_ROOT 环境变量（由 Claude Code 提供）
CONFIG_FILE="${CLAUDE_PLUGIN_ROOT}/.config/settings.sh"

if [ ! -f "$CONFIG_FILE" ]; then
    echo "╔══════════════════════════════════════════════════════════╗"
    echo "║  🚀 首次使用 Personal Assistant Plugin                    ║"
    echo "║                                                          ║"
    echo "║  请运行 /a-setup 完成初始化配置                           ║"
    echo "╚══════════════════════════════════════════════════════════╝"
    echo ""
    echo "设置向导将帮助你："
    echo "  1. 配置 Obsidian Vault 路径"
    echo "  2. 检查必需的目录结构"
    echo "  3. 创建示例配置文件"
    echo ""
    echo "👉 输入 /a-setup 开始"
    exit 0
fi

source "$CONFIG_FILE"
VAULT="$VAULT_PATH"

# 验证 Vault 路径是否有效
if [ ! -d "$VAULT" ]; then
    echo "❌ Vault 路径无效: $VAULT"
    echo ""
    echo "请运行 /a-setup 重新配置"
    exit 0
fi

echo "## 快速上下文加载"
echo ""

# 1. 读取用户画像
if [ -f "$VAULT/06-Memory/profile.md" ]; then
  echo "### 用户画像"
  head -30 "$VAULT/06-Memory/profile.md" | tail -n +2
  echo ""
fi

# 2. 读取偏好配置（提取关键设置）
if [ -f "$VAULT/06-Memory/preferences.md" ]; then
  echo "### 偏好配置"
  sed -n '/```yaml/,/```/p' "$VAULT/06-Memory/preferences.md" | grep -E "language" || echo "使用默认配置"
  echo ""
fi

# 3. 读取当前任务（今日重点）
if [ -f "$VAULT/02-Tasks/active.md" ]; then
  echo "### 今日重点 (MIT)"
  sed -n '/## 今日重点/,/^---/p' "$VAULT/02-Tasks/active.md" | head -10
  echo ""
fi

# 输出当前时间（GMT+8）
echo "---"
echo "当前时间: $(TZ='Asia/Shanghai' date '+%Y-%m-%d %H:%M %A')"
