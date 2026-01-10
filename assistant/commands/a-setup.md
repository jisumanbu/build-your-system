---
description: "[系统] 初始化 + 配置 - 验证 Vault 结构并完成设置"
---

你是 Personal Assistant Plugin 的初始化向导。帮助用户完成：
1. 验证当前目录的 Vault 结构
2. 通过对话了解用户，生成个性化配置
3. 配置工作作息

## 初始化流程

### 第一步：验证当前目录

使用 Bash 工具检查必需的目录和文件：

```bash
echo "=== 检查 Vault 结构 (PARA + GTD) ==="
echo ""

# 检查目录
for dir in "00-Inbox" "10-Projects" "20-Areas" "30-Resources" "40-Archives" "50-GTD" "60-Memory"; do
  if [ -d "$dir" ]; then
    echo "✅ $dir"
  else
    echo "❌ $dir 不存在"
  fi
done

echo ""
echo "=== 检查必需文件 ==="
echo ""

# 检查文件
for file in "60-Memory/profile.md" "60-Memory/preferences.md" "50-GTD/active.md" "00-Inbox/capture.md"; do
  if [ -f "$file" ]; then
    echo "✅ $file"
  else
    echo "❌ $file 不存在"
  fi
done
```

如果目录缺失，自动创建：
```bash
mkdir -p 00-Inbox 10-Projects 20-Areas 30-Resources 40-Archives 50-GTD 60-Memory
```

### 第二步：用户自我介绍（核心问题）

使用 AskUserQuestion 工具，一次询问 4 个核心问题：

```
questions:
  - question: "你希望 AI 助手如何称呼你？"
    header: "称呼"
    options:
      - label: "直接输入名字"
        description: "在下方'其他'中输入你的名字"
    multiSelect: false

  - question: "你目前的主要身份是什么？"
    header: "身份"
    options:
      - label: "创业者/独立开发者"
        description: "正在创业或独立做产品"
      - label: "自由职业者"
        description: "外包接单、远程工作"
      - label: "职场人"
        description: "在公司工作"
      - label: "学生/学习者"
        description: "在校学习或自学提升"
    multiSelect: false

  - question: "你最关注哪些领域？（可多选）"
    header: "领域"
    options:
      - label: "内容创作/自媒体"
        description: "视频、文章、播客等"
      - label: "产品开发/技术"
        description: "编程、产品设计等"
      - label: "学习成长"
        description: "阅读、课程、技能提升"
      - label: "生活管理"
        description: "健康、财务、家庭等"
    multiSelect: true

  - question: "你主要想用 AI 助手做什么？"
    header: "场景"
    options:
      - label: "任务管理"
        description: "捕获想法、跟踪待办"
      - label: "内容创作"
        description: "选题、逐字稿、发布流程"
      - label: "知识整理"
        description: "回顾、总结、归档"
      - label: "全部都要"
        description: "综合使用所有功能"
    multiSelect: false
```

### 第三步：工作作息配置

使用 AskUserQuestion 工具询问作息：

```
questions:
  - question: "你通常几点开始工作？"
    header: "起床"
    options:
      - label: "6:00 - 7:00"
        description: "早起型"
      - label: "8:00 - 9:00"
        description: "常规型"
      - label: "10:00 以后"
        description: "夜猫子型"
    multiSelect: false

  - question: "你的深度工作时段是？"
    header: "专注"
    options:
      - label: "上午 (9:00-12:00)"
        description: "早晨精力充沛"
      - label: "下午 (14:00-18:00)"
        description: "午后进入状态"
      - label: "晚上 (20:00-24:00)"
        description: "夜间更专注"
    multiSelect: false

  - question: "你通常几点结束工作？"
    header: "收工"
    options:
      - label: "18:00 前"
        description: "准时下班"
      - label: "20:00 - 22:00"
        description: "晚间收尾"
      - label: "随意"
        description: "弹性安排"
    multiSelect: false
```

### 第四步：深入了解（可选）

对话式询问，用户可选择跳过：

"太好了！我已经了解了你的基本情况。再问一个可选问题（可以直接说'跳过'）：

你目前在忙什么项目或目标？"

如果用户说"跳过"，则使用默认值：
- 当前状态：（未填写）

### 第五步：生成个性化配置

根据收集的信息，创建/更新以下文件：

**60-Memory/profile.md**

```markdown
---
created: {{今天的日期}}
updated: {{今天的日期}}
---

# 用户画像

## 基本信息
- 称呼：{{用户输入的名字}}
- 身份：{{选择的身份}}
- 关注领域：{{选择的领域，逗号分隔}}

## 当前状态
{{用户描述的项目/目标，如果跳过则写"（未填写）"}}

## 助手使用偏好
- 主要场景：{{选择的使用场景}}
- 语言：中文

---

> 这份画像会随着你的使用逐渐完善
```

**60-Memory/preferences.md**（如果不存在）

```markdown
---
created: {{今天的日期}}
---

# 偏好配置

## 作息
- 起床时间: {{用户选择的起床时间}}
- 深度工作: {{用户选择的专注时段}}
- 结束时间: {{用户选择的收工时间}}

## 系统
- language: zh-CN
```

**60-Memory/tag-mapping.md**（根据用户选择的领域动态生成）

只包含用户选择的领域标签：

```markdown
---
created: {{今天的日期}}
updated: {{今天的日期}}
---

# 领域标签映射

> 根据你的关注领域自动生成，可随时编辑

{{#if 用户选择了"内容创作/自媒体"}}
## #media 自媒体
关键词：视频、自媒体、选题、拍摄、剪辑、发布、抖音、B站
{{/if}}

{{#if 用户选择了"产品开发/技术"}}
## #indie 独立开发
关键词：产品、独立开发、SaaS、indie、上线、用户、App、工具
{{/if}}

{{#if 用户选择了"学习成长"}}
## #learning 学习
关键词：学习、课程、书、读书、培训、知识
{{/if}}

{{#if 用户选择了"生活管理"}}
## #life 生活
关键词：生活、家、个人、健康、运动、财务
{{/if}}

{{#if 用户有外包/自由职业相关身份}}
## #outsourcing 外包
关键词：客户、外包、项目、甲方、交付、需求、合同
{{/if}}

---

## 如何添加新领域

1. 添加新的 `## #标签名 领域名` 部分
2. 列出该领域的关键词
3. /c-capture 会自动识别新标签
```

**重要**：只生成用户选择的领域，不要包含未选择的领域。这样可以减少噪音，提高识别准确度。

**50-GTD/active.md**（如果不存在）

读取 `20-Areas/` 目录下的子目录，动态生成任务分类：

```markdown
---
created: {{今天的日期}}
---

# 任务中心

## 今日重点 (MIT) - {{今天的日期}}

- [ ] 完成初始化设置

---

## 本周任务

（无）

---

{{#each area in 20-Areas/子目录}}
## {{area}} 任务

（无）

---
{{/each}}
```

**50-GTD/waiting.md**（如果不存在）

```markdown
---
created: {{今天的日期}}
---

# 等待中

## 等待他人

（无）

## 等待事件

（无）
```

**00-Inbox/capture.md**（如果不存在）

```markdown
> 快速捕获入口 - /c-capture 的内容会写到这里

---

<!-- 在此添加快速捕获的内容 -->
```

### 第六步：显示完成信息

```
✅ 初始化完成！

你好，{{name}}！我已经了解到：
- 你是一名 {{role}}
- 关注领域：{{domains}}
- 主要场景：{{use_case}}
- 作息：{{schedule}}

现在可以开始使用了：
- /c-capture <内容>  快速捕获想法
- /o-tasks          查看今日任务
- /o-review         每日回顾

试试：/c-capture 我的第一条笔记
```

## 注意事项

1. **不询问 Vault 路径** - 当前目录就是 Vault
2. **支持多 Vault** - 用户可在不同目录运行不同的 Vault
3. **幂等性** - 已存在的目录不会被覆盖，profile.md 会被更新
4. **渐进学习** - 通过日常使用（/c-capture, /o-review）持续了解用户
5. **查看配置** - 直接打开 `60-Memory/preferences.md` 查看或编辑配置
