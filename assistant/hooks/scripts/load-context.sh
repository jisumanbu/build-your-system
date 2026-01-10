#!/bin/bash
# Load user context at session start
# 根据 CLAUDE.md 的"快速上下文"要求加载三个文件

# 使用 CLAUDE_PLUGIN_ROOT 环境变量（由 Claude Code 提供）
CONFIG_FILE="${CLAUDE_PLUGIN_ROOT}/.config/settings.sh"

if [ -f "$CONFIG_FILE" ]; then
    source "$CONFIG_FILE"
    VAULT="$VAULT_PATH"
else
    echo "⚠️ 未找到配置文件。请运行 /a-setup 进行首次设置。"
    echo ""
    echo "或手动创建配置文件："
    echo "  cp ${CLAUDE_PLUGIN_ROOT}/.config/settings.sh.example $CONFIG_FILE"
    echo "  # 编辑 settings.sh 设置你的 Vault 路径"
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
  # 提取 YAML 块中的关键设置
  sed -n '/```yaml/,/```/p' "$VAULT/06-Memory/preferences.md" | grep -E "language" || echo "使用默认配置"
  echo ""
fi

# 3. 读取当前任务（今日重点）
if [ -f "$VAULT/02-Tasks/active.md" ]; then
  echo "### 今日重点 (MIT)"
  # 提取 MIT 部分
  sed -n '/## 今日重点/,/^---/p' "$VAULT/02-Tasks/active.md" | head -10
  echo ""
fi

# 输出当前时间（GMT+8）
echo "---"
echo "当前时间: $(TZ='Asia/Shanghai' date '+%Y-%m-%d %H:%M %A')"
