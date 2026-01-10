---
description: "[助手] 系统状态检查 - 验证 MCP 连接和 Vault 结构"
---

检查 AI 助手系统状态。

## 检查项

### 1. MCP 连接测试
使用 mcp-obsidian 工具 `list_files_in_vault` 列出 Vault 根目录文件。

### 2. Vault 结构检查

参考 vault-structure skill，检查以下核心目录是否存在：
- 00-Inbox/
- 01-Daily/
- 02-Tasks/
- 03-Areas/
- 04-Projects/
- 05-Knowledge/
- 06-Memory/

### 3. 关键文件检查

检查以下文件是否存在：
- 06-Memory/profile.md
- 06-Memory/preferences.md
- 02-Tasks/inbox.md

## 输出格式

```
=== AI 助手系统状态 ===

MCP 连接: [OK/FAIL]
Vault 路径: ...

目录结构:
- 00-Inbox: [存在/缺失]
- 01-Daily: [存在/缺失]
...

关键文件:
- profile.md: [存在/缺失]
- preferences.md: [存在/缺失]
- inbox.md: [存在/缺失]

数据概览:
- Inbox 文件数: N
- 活跃任务数: N
```
