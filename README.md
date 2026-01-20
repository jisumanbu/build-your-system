# Build Your System

基于 Obsidian Vault 的个人效率系统 - 包含两个可独立安装的 Claude Code Plugin。

## 两个 Plugin

| Plugin | 功能 | 命令数 |
|--------|------|--------|
| **assistant** | 任务管理、知识管理、每日回顾 | 10 个 |
| **media** | 短视频创作（Jenny Hoyos 方法论） | 10 个 |

## 安装

### 方式一：Marketplace（推荐）

```bash
# 在 Claude Code 中运行
/plugin

# 选择 "Add Marketplace"，输入：
jisumanbu/build-your-system

# 选择要安装的 plugin：
# - assistant: 任务管理、知识分发
# - media: 短视频创作
# - 或两个都安装
```

### 方式二：Git Clone

```bash
# 克隆仓库
git clone https://github.com/jisumanbu/build-your-system.git

# 安装 assistant
cp -r build-your-system/assistant ~/.claude/plugins/local/

# 安装 media（可选）
cp -r build-your-system/media ~/.claude/plugins/local/
```

## 首次设置（assistant plugin）

```bash
# 运行设置向导
/a-setup
```

向导会引导你：
- 配置 Obsidian Vault 路径
- 检查必需目录结构
- 创建示例配置文件

## 前置条件

- **Claude Code CLI** - 最新版本
- **Obsidian** - 用于管理 Vault

### Vault 目录结构

```
YourVault/
├── 00-Inbox/
│   └── inbox.md          # 统一收集箱
├── 01-Daily/             # 日记
├── 02-Tasks/
│   └── active.md         # 当前任务
├── 03-Areas/
│   └── media/topics/     # 视频选题（media plugin）
└── 06-Memory/
    ├── profile.md        # 用户画像
    └── preferences.md    # 偏好配置
```

---

## Assistant Plugin

个人 AI 助手 - 任务捕获、每日回顾、知识分发。

### 命令

| 命令 | 功能 |
|------|------|
| `/a-setup` | 首次使用设置 |
| `/a-capture <内容>` | 快速捕获到 inbox |
| `/a-tasks` | 任务概览和智能建议 |
| `/a-review` | 每日回顾 + inbox 分发 |
| `/a-weekly` | 每周整合 |
| `/a-dump [主题]` | 脑暴倾倒 |
| `/a-schedule` | 作息状态检查 |
| `/a-status` | 系统状态检查 |
| `/a-config` | 配置管理 |
| `/cc-activity [日期]` | 活动分析 - 时间线和目标统计 |

### Skills

| Skill | 用途 |
|-------|------|
| capture-rules | 标签识别、分发规则 |
| vault-structure | Vault 路径、模板格式 |

### 自动上下文

SessionStart hook 自动加载：
- `06-Memory/profile.md` - 用户画像
- `06-Memory/preferences.md` - 偏好配置
- `02-Tasks/active.md` - 当前任务

---

## Media Plugin

短视频创作助手 - 基于 Jenny Hoyos 方法论的完整视频创作流程。

### 命令

| 命令 | 功能 |
|------|------|
| `/m-director [选题]` | 全流程引导完成一期视频 |
| `/m-topic <选题>` | 选题评估 |
| `/m-hook <选题>` | Hook 设计 |
| `/m-structure <选题>` | 内容结构设计 |
| `/m-script [要点]` | 逐字稿生成 |
| `/m-title [描述]` | 标题封面标签 |
| `/m-publish` | 发布检查 |
| `/m-mine [范围]` | 选题挖掘 |
| `/m-hotspot [领域]` | 热点发现 |
| `/m-keywords <主题>` | 关键词匹配 |

### Skills

| Skill | 用途 |
|-------|------|
| jenny-hoyos-method | Hook/结构/节奏方法论 |
| script-writing | 口语化写作、去 AI 味 |
| transcript-cleaner | 语音转录清洗 |

---

## 快速开始

```bash
# 快速捕获一个任务
/a-capture #task 完成项目报告 📅 2026-01-15 ⏫

# 查看当前任务
/a-tasks

# 每日回顾（分发 inbox 内容）
/a-review

# 开始一个视频选题（需要 media plugin）
/m-director 如何用 AI 提高工作效率
```

## 目录结构

```
build-your-system/
├── .claude-plugin/
│   └── marketplace.json      # 列出两个 plugin
├── assistant/                # Plugin 1
│   ├── .claude-plugin/
│   │   └── plugin.json
│   ├── commands/             # 10 个 a-* 命令
│   ├── skills/               # capture-rules, vault-structure
│   ├── hooks/                # SessionStart
│   ├── scripts/              # analyze-cc-activity.py
│   └── .config/
├── media/                    # Plugin 2
│   ├── .claude-plugin/
│   │   └── plugin.json
│   ├── commands/             # 10 个 m-* 命令
│   └── skills/               # jenny-hoyos-method, script-writing, transcript-cleaner
├── examples/
│   └── minimal-vault/
├── README.md
├── LICENSE
└── CHANGELOG.md
```

## 外部依赖（可选）

以下 Plugin 可以补充本系统的能力：

1. **content-research-writer** - 长文写作（博客、案例研究）
   - 来源：ComposioHQ/awesome-claude-skills

2. **obsidian-skills** - Obsidian 格式规范（Markdown/Bases/Canvas）
   - 来源：kepano/obsidian-skills

## 版本历史

### v3.0.0 (2026-01-10)
- 拆分为两个独立 plugin：assistant 和 media
- 支持 Marketplace 安装
- 迁移 20 个命令到 plugin 格式
- 提取 5 个可复用 skills
- 实现 SessionStart hook 自动加载用户上下文
- 添加 `/a-setup` 首次使用向导
- 支持配置化 VAULT_PATH

## 许可证

MIT License - 见 [LICENSE](LICENSE)

## 贡献

欢迎提交 Issue 和 Pull Request。
