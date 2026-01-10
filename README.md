# Personal Assistant Plugin

个人 AI 助手系统 v3.0 - Claude Code Plugin 版本

一个基于 Obsidian Vault 的个人任务管理、知识管理和短视频创作助手。

## 功能特性

- **任务管理**：快速捕获、每日回顾、任务概览
- **知识管理**：自动标签识别、inbox 分发、周记整合
- **短视频创作**：选题评估、Hook 设计、逐字稿生成（基于 Jenny Hoyos 方法论）
- **自动上下文**：SessionStart 自动加载用户画像和当日任务

## 安装

### 方式一：Git Clone（推荐）

```bash
git clone https://github.com/jisumanbu/personal-assistant-plugin.git \
  ~/.claude/plugins/local/personal-assistant
```

### 方式二：手动下载

1. 下载本仓库
2. 解压到 `~/.claude/plugins/local/personal-assistant/`

## 首次设置

### 1. 运行设置向导

```bash
# 启动 Claude Code
claude

# 运行设置命令
/a-setup
```

向导会引导你：
- 配置 Obsidian Vault 路径
- 检查必需目录结构
- 创建示例配置文件

### 2. 手动配置（可选）

```bash
# 复制配置模板
cd ~/.claude/plugins/local/personal-assistant
cp .config/settings.sh.example .config/settings.sh

# 编辑配置
# 将 VAULT_PATH 改为你的 Obsidian Vault 路径
```

### 3. 验证安装

```bash
/a-status
```

应该显示 Vault 状态和 MCP 连接状态。

## 前置条件

### 必需

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
│   └── media/topics/     # 视频选题（可选）
└── 06-Memory/
    ├── profile.md        # 用户画像
    └── preferences.md    # 偏好配置
```

参考 `examples/minimal-vault/` 获取最小化示例。

## 命令列表

### 助手命令 (a-*)

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
| `/cc-activity [日期]` | Claude Code 活动分析 |

### 自媒体命令 (m-*)

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
| capture-rules | 标签识别、分发规则 |
| vault-structure | Vault 路径、模板格式 |
| jenny-hoyos-method | 视频方法论 |
| script-writing | 口语化写作、去 AI 味 |
| transcript-cleaner | 语音转录清洗 |

## 快速开始

```bash
# 1. 快速捕获一个任务
/a-capture #task 完成项目报告 📅 2026-01-15 ⏫

# 2. 查看当前任务
/a-tasks

# 3. 每日回顾（分发 inbox 内容）
/a-review

# 4. 开始一个视频选题
/m-director 如何用 AI 提高工作效率
```

## 目录结构

```
~/.claude/plugins/local/personal-assistant/
├── .claude-plugin/
│   └── plugin.json           # Plugin 配置
├── .config/
│   ├── settings.sh           # 用户配置（git ignored）
│   └── settings.sh.example   # 配置模板
├── commands/
│   ├── assistant/            # 10 个助手命令
│   └── media/                # 10 个自媒体命令
├── skills/
│   ├── capture-rules/        # 标签识别规则
│   ├── vault-structure/      # Vault 导航
│   ├── jenny-hoyos-method/   # 视频方法论
│   ├── script-writing/       # 口语化写作
│   └── transcript-cleaner/   # 转录清洗
├── hooks/
│   ├── hooks.json            # Hook 配置
│   └── scripts/
│       └── load-context.sh   # SessionStart 加载脚本
├── scripts/
│   └── analyze-cc-activity.py
├── examples/
│   └── minimal-vault/        # 最小化 Vault 示例
├── LICENSE
└── README.md
```

## 外部依赖（可选）

以下 Plugin 可以补充本系统的能力：

1. **content-research-writer** - 长文写作（博客、案例研究）
   - 来源：ComposioHQ/awesome-claude-skills

2. **obsidian-skills** - Obsidian 格式规范（Markdown/Bases/Canvas）
   - 来源：kepano/obsidian-skills

## 测试

### 快速验证

```bash
# 1. 检查系统状态
/a-status

# 2. 测试捕获
/a-capture 测试内容 #task

# 3. 查看 inbox
# 检查 00-Inbox/inbox.md 是否有新内容
```

### 完整 E2E 测试

见 `examples/` 目录的测试场景。

## 版本历史

### v3.0.0 (2026-01-10)
- 升级为 Claude Code Plugin
- 迁移 20 个命令到 plugin 格式
- 提取 5 个可复用 skills
- 实现 SessionStart hook 自动加载用户上下文
- 添加 `/a-setup` 首次使用向导
- 支持配置化 VAULT_PATH

## 许可证

MIT License - 见 [LICENSE](LICENSE)

## 贡献

欢迎提交 Issue 和 Pull Request。
