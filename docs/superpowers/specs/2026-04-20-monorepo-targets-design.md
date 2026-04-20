# Build Your System Monorepo Targets Design

## Goal

把 `build-your-system` 收敛为唯一源仓库，在同一个仓库里同时承载 Claude Code 和 Codex 目标实现，停止继续维护独立的 `build-your-system-codex` 副本目录。

## Current Problem

- Claude 版本的正式仓库是 `build-your-system`，当前已经对外使用。
- Codex 版本存在于独立目录 `~/Projects/build-your-system-codex`，不是正式源仓库的一部分。
- Claude 与 Codex 之间存在大量重复内容，尤其是 `commands/*.md` 目前完全一致。
- Codex 迁移后新增了大量宿主专属 skills 和脚本，已经开始与 Claude 版本分叉。
- 如果继续双仓维护，后续接入 Cursor 或其他宿主时，会继续复制第三份实现。

## Design Decision

采用“单仓多目标”结构，而不是继续做两个独立仓库。

核心原则：

- `build-your-system` 作为唯一 source of truth。
- 不追求单一原生插件包跨宿主直接安装。
- 每个宿主保留自己的包装层和安装入口。
- 本次先完成仓库收敛，不在同一次改动里强行抽离所有共享核心。

## Target Structure

```text
build-your-system/
├── .claude-plugin/
│   └── marketplace.json
├── assistant/                         # Claude target, 保持现有结构
├── media/                             # Claude target, 保持现有结构
├── claude-notify/                     # Claude target, 保持现有结构
├── targets/
│   └── codex/
│       └── build-your-system-assistant/
│           ├── .codex-plugin/
│           │   └── plugin.json
│           ├── commands/
│           ├── hooks/
│           ├── scripts/
│           ├── skills/
│           ├── tests/
│           ├── README.md
│           ├── DESIGN.md
│           └── CONTRIBUTING.md
├── docs/
│   └── superpowers/
│       ├── specs/
│       └── plans/
└── README.md
```

## Scope For This Migration

本次迁移只做以下事情：

- 把独立 Codex 副本迁入 `build-your-system` 仓库。
- 更新根 README，明确这是一个支持多个宿主的 monorepo。
- 为 Codex 目标补充清晰的路径、安装方式和验证方式。
- 保留 Claude 目标现有目录与入口，不破坏当前使用方式。

本次明确不做：

- 不抽离共享 `core/` 模块。
- 不把 Claude 的 commands/hook 流程重写成 Codex skills。
- 不尝试同步支持 Cursor 目标。
- 不修改用户本机已有的独立 `build-your-system-codex` 目录内容。

## Why This Is The Right First Step

- 风险可控：先收敛仓库，不一次性改动业务工作流。
- 成本最低：Codex 目录整体迁入即可开始统一版本管理。
- 兼容当前使用：Claude 和 Codex 入口都保留。
- 为下一阶段打基础：后续可以在同一仓库里渐进抽取共享脚本、共享规则和共享文档。

## Key Trade-Offs

### Option A: 继续双仓维护

优点：

- 眼前最省事。

缺点：

- 持续复制内容。
- 文档、脚本、命令长期漂移。
- 后续再接 Cursor 时问题进一步放大。

### Option B: 单仓多目标

优点：

- 一个源仓库管理多宿主。
- 可以逐步抽共享层。
- 发布、文档、变更审查集中。

缺点：

- 根 README 和目录结构需要重新整理。
- 初期会同时存在“共享业务内容”与“宿主专属包装”的混合状态。

### Option C: 立即做共享 core + 多目标生成

优点：

- 长期最优。

缺点：

- 当前改动过大。
- 需要同时改命令、skills、脚本与安装流程。
- 风险明显高于仓库收敛。

结论：本次采用 Option B。

## Verification Strategy

- 确认 `targets/codex/build-your-system-assistant` 完整包含 Codex 目标所需文件。
- 确认根 README 已说明 Claude/Codex 目标的不同安装入口。
- 运行 Codex 目标的现有测试。
- 检查 Git 状态，确保迁移后的结构在同一仓库内自洽。

## Follow-Up Work

迁移完成后，下一阶段再处理：

- 提取共享 workflow/spec 文档。
- 提取共享 Python 工具层。
- 统一 activity analysis 能力边界。
- 评估 Cursor 目标应采用 rules/modes/MCP 哪种包装方式。
