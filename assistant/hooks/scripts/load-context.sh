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

# 检查必需文件
REQUIRED_FILES=("60-Memory/profile.md" "60-Memory/preferences.md" "50-GTD/active.md" "00-Inbox/capture.md")
MISSING_FILES=()

for file in "${REQUIRED_FILES[@]}"; do
    if [ ! -f "$file" ]; then
        MISSING_FILES+=("$file")
    fi
done

# 如果缺失关键内容，提示运行 setup
if [ ${#MISSING_DIRS[@]} -gt 0 ] || [ ${#MISSING_FILES[@]} -gt 0 ]; then
    echo "╔══════════════════════════════════════════════════════════╗"
    echo "║  Personal Assistant Plugin (CODE+)                       ║"
    echo "╚══════════════════════════════════════════════════════════╝"
    echo ""

    if [ ${#MISSING_DIRS[@]} -gt 0 ]; then
        echo "缺失目录: ${MISSING_DIRS[*]}"
    fi
    if [ ${#MISSING_FILES[@]} -gt 0 ]; then
        echo "缺失文件: ${MISSING_FILES[*]}"
    fi
    echo ""
    echo "运行 /a-setup 初始化 Vault 结构并完成自我介绍"
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
