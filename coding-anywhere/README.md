# coding-anywhere

> 让你的 Mac 24/7 留在家里。你在哪里都能从手机/平板/任意笔记本回到它的 shell，回到上一秒离开的 tmux 会话。

一个 Claude Code 插件，把"自建 mosh + tmux + SSH 中继 + DDNS 直连"这套远程开发栈做成了**一段提示词**。复制 → 粘贴 → 让 Claude 引导你完成搭建。

---

## 这套方案能做到什么

- **网络切换不掉线** — 蜂窝 ↔ WiFi、地铁过隧道、高铁，连接一直在
- **App 关掉/电脑重启 session 还在** — tmux 会话持久化
- **不依赖 Tailscale/ZeroTier 的可用性** — 全部自建，路径短、延迟低
- **覆盖任何客户端** — iPhone Blink / iPad Termius / 桌面 mosh CLI / 朋友的 Linux 笔记本
- **两套架构按需切换** — ECS Relay（稳定，需公网 ECS）或 DDNS + IPv6 直连（最快，需家里有公网 IPv6）

---

## 安装

### 方式 1：通过 Claude Code marketplace 安装

```
/plugin install coding-anywhere
```

（marketplace: `build-your-system`）

### 方式 2：手动安装

```bash
git clone https://github.com/jisumanbu/build-your-system.git ~/.claude/plugins/marketplaces/build-your-system
# Claude Code 启动时会自动加载
```

---

## 一键复刻提示词（核心用法）

安装好插件后，把下面这段**整段复制**粘贴到 Claude Code 对话框里。Claude 会读取 `coding-anywhere` skill，自动引导你完成所有配置。

```
我想搭建一套"随时随地远程开发"的方案。

我的目标：从手机/平板/任意笔记本随时连回家里的 Mac，体验要和坐在电脑前一样：
- 网络切换不掉线
- App 关掉后会话还在
- 不依赖第三方 SaaS

请按照 coding-anywhere skill 的引导：
1. 先帮我评估环境（家里有没有公网 IPv6 / 是否有 ECS / 主用什么客户端）
2. 决定走 ECS Relay 还是 DDNS 直连方案
3. 一步一步带我完成配置（生成所有需要的脚本、配置文件、客户端配置）
4. 给我一份验收清单，让我能逐项验证

我的占位偏好：所有脚本和配置请用占位符（<your-xxx>），不要让我把真实 IP/域名贴进对话。
```

---

## 这个插件的内容

```
coding-anywhere/
├── skills/coding-anywhere/
│   ├── SKILL.md                          # 主方法论 + 决策树 + 引导式提问
│   └── references/
│       ├── ecs-relay-blueprint.md        # ECS 中继方案完整模板
│       ├── ddns-direct-blueprint.md      # DDNS + IPv6 直连完整模板
│       ├── client-config.md              # Blink / Termius / La Terminal / mosh CLI
│       ├── tmux-session-recipes.md       # tmux 持久会话配置
│       └── troubleshooting.md            # 9 类常见故障的排查清单
```

---

## 适合谁

- 经常出差/移动办公，又不想背 16 寸 MacBook 的开发者
- 想把家里 Mac mini 改造成"永远在线的开发服务器"的人
- Tailscale 等方案在国内偶发不稳，想要一套自建可控方案的人
- 钓鱼/爬山/咖啡馆是你的"灵感工位"的人

---

## 安全提醒

- 这套方案会在公网暴露 SSH 入口，请务必：
  - 关闭密码登录（只用 ssh key）
  - 给每个客户端单独生成 key
  - 给 ECS 装 fail2ban
  - **不要在公开帖子里暴露你真实的 ECS IP / 域名**

---

## 支持的运行环境

- **Claude Code**（macOS / Linux / Windows）
- **Codex**（适配版本见 `targets/codex/coding-anywhere/`）

---

## License

MIT
