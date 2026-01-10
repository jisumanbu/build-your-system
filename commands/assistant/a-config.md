---
description: "[助手] 配置管理 - 查看和修改系统配置"
argument-hint: "[可选：配置项 值]"
---

查看或修改 AI 助手系统配置。

## 用法

### 查看配置
```
/a-config
```
显示当前所有配置。

### 修改配置
```
/a-config yolo on
/a-config yolo off
```

## 执行步骤

### 无参数：显示当前配置

读取 `06-Memory/preferences.md`，格式化显示：

```
=== AI 助手配置 ===

YOLO 模式: 开启/关闭
自动整合: 开启/关闭
语言: zh-CN

任务格式: Obsidian Tasks
优先级符号: ⏫ 高 / 🔼 中 / 🔽 低

领域标签:
- #outsourcing - 外包接单
- #indie - 独立开发
- #media - 自媒体
- #life - 生活
- #learning - 学习

---
使用 /a-config <配置项> <值> 修改配置
```

### 有参数：修改配置

解析参数: **$ARGUMENTS**

支持的配置项：
- `yolo on/off` - 开关 YOLO 模式
- `auto_integrate on/off` - 开关自动整合

更新 `06-Memory/preferences.md` 中对应的值。

确认修改：
```
已将 {配置项} 修改为 {新值}
```
