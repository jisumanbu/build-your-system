#!/bin/bash
# Load user context at session start
# 检测当前目录是否是有效 Vault，加载用户上下文

# 检查必需目录 (PARA + GTD)
REQUIRED_DIRS=("00-Inbox" "50-GTD" "60-Memory")
MISSING_DIRS=()

for dir in "${REQUIRED_DIRS[@]}"; do
    if [ ! -d "$dir" ]; then
        MISSING_DIRS+=("$dir")
    fi
done

# 检查必需文件 - profile.md 是 setup 完成的标志
SETUP_COMPLETE=false
if [ -f "60-Memory/profile.md" ]; then
    # 检查 profile.md 是否有实际内容（文件超过 5 行即视为已配置）
    LINE_COUNT=$(wc -l < "60-Memory/profile.md" 2>/dev/null | tr -d ' ')
    if [ "$LINE_COUNT" -gt 5 ]; then
        SETUP_COMPLETE=true
    fi
fi

# 如果缺失目录或未完成 setup，触发引导
if [ ${#MISSING_DIRS[@]} -gt 0 ] || [ "$SETUP_COMPLETE" = false ]; then
    echo "╔══════════════════════════════════════════════════════════╗"
    echo "║  Personal Assistant Plugin (CODE+)                       ║"
    echo "╚══════════════════════════════════════════════════════════╝"
    echo ""
    echo "【系统状态：未初始化】"
    echo ""

    if [ ${#MISSING_DIRS[@]} -gt 0 ]; then
        echo "缺失目录: ${MISSING_DIRS[*]}"
    fi

    if [ "$SETUP_COMPLETE" = false ]; then
        echo "用户画像: 未配置"
    fi
    echo ""
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo "【重要】检测到首次使用，请立即运行 /a-setup 完成初始化。"
    echo "初始化后才能使用完整功能（如 /c-capture, /o-tasks 等）。"
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo ""
    echo "Claude: 你应该主动告诉用户需要先完成初始化，并询问是否现在运行 /a-setup"
    exit 0
fi

# 加载上下文
echo "## 快速上下文加载"
echo ""

# 1. 读取用户画像
if [ -f "60-Memory/profile.md" ]; then
    echo "### 用户画像"
    head -30 "60-Memory/profile.md" | tail -n +2
    echo ""
fi

# 2. 读取偏好配置（提取关键设置）
if [ -f "60-Memory/preferences.md" ]; then
    echo "### 偏好配置"
    grep -E "起床时间|深度工作|结束时间|language" "60-Memory/preferences.md" 2>/dev/null || echo "使用默认配置"
    echo ""
fi

# 3. 读取当前任务（今日重点 MIT）
if [ -f "50-GTD/active.md" ]; then
    echo "### 今日重点 (MIT)"
    sed -n '/## 今日重点/,/^---/p' "50-GTD/active.md" | head -10
    echo ""
fi

# 输出当前时间（GMT+8）
echo "---"
echo "当前时间: $(TZ='Asia/Shanghai' date '+%Y-%m-%d %H:%M %A')"
