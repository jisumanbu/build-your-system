---
name: Coding Anywhere
description: This skill should be used when the user wants to set up remote development access from mobile devices (iPhone/iPad/Android) or any laptop to a home Mac/Linux box. Trigger on keywords like "mosh", "tmux remote", "ssh from iPhone", "Blink shell setup", "always-on Mac", "reverse SSH relay", "DDNS direct connection", "build my own Tailscale alternative", "remote development setup", "code from anywhere", or when the user asks "how do I keep coding when I'm not at my desk". Also trigger when the user references this plugin's GitHub README and wants to replicate the stack.
version: 1.0.0
---

# Coding Anywhere - 随时随地远程开发栈

让你的 Mac 24/7 留在家里，你在哪里都能从手机/平板/任意笔记本进入它的 shell，回到上一秒离开的 tmux 会话。

## 这套方案解决的痛点

1. **移动办公时不想背电脑** —— 手机/平板足够了，但需要"真终端"体验
2. **网络切换不掉线** —— 蜂窝 ↔ WiFi 切换、地铁过隧道、高铁，连接不能断
3. **关掉 App 后会话还在** —— 下次打开 App 直接回到上次的位置
4. **Tailscale/ZeroTier 在国内偶有抽风** —— 想要一套不依赖第三方服务可用性的自建方案

## 核心组件

| 组件 | 作用 | 不可替代性 |
|------|------|-----------|
| **mosh** | UDP 长连接，弱网+漫游不掉 | SSH 替代不了 |
| **tmux** | 会话持久化，掉线/重连后状态不丢 | mosh 也救不了关掉的 shell |
| **SSH** | 身份认证 + 端口转发底座 | 一切的根基 |
| **reverse SSH**（ECS Relay 方案专属） | 让没公网 IP 的家庭 Mac 可达 | 解决 NAT 问题 |
| **DDNS**（直连方案专属） | 域名跟着公网 IP 走 | 仅在家里有公网 IP/IPv6 时可用 |
| **Blink Shell / Termius** | 移动客户端，提供 mosh+tmux 集成体验 | iPhone 上没有更好的 |

## 两套架构方案

### 方案 A：ECS Relay（推荐默认方案）

```text
Client (iPhone/iPad/Mac)
   │
   │ ssh/mosh to public ECS
   ▼
Public ECS (e.g. 阿里云/AWS/Vultr)
   │
   │ reverse SSH tunnel (家庭 Mac 主动建立)
   ▼
Home Mac (在家，24/7 在线)
```

- **优点**：家里没公网 IP/IPv6 也能用；任何 NAT 后都能用；一台 ECS 可以同时挂多台后端 Mac
- **代价**：需要一台公网 ECS（最低配每月几十块）
- **完整模板**：`references/ecs-relay-blueprint.md`

### 方案 B：DDNS + IPv6 直连

```text
Client
   │
   │ resolve domain via DNS
   ▼
DDNS (Cloudflare 等) → 家庭 Mac 当前公网 IPv6
   │
   │ direct ssh/mosh
   ▼
Home Mac
```

- **优点**：路径最短、延迟最低、不依赖第三方 ECS
- **代价**：必须家里有稳定的公网 IPv6（或公网 IPv4 + 端口映射）；网关必须支持 IPv6 入站放行
- **完整模板**：`references/ddns-direct-blueprint.md`

## 决策树：用户该走哪条路？

按顺序问用户，根据答案决定方案：

1. **"你家宽带有公网 IPv6 或公网 IPv4 吗？"**
   - 不知道 → 让用户跑：`curl -6 ifconfig.co` 和 `curl -4 ifconfig.co`，对比是否是家庭网关同段
   - 没有 / 是大内网 → **直接走方案 A**（DDNS 不可行）
   - 有公网 IPv6 → 进入下一题

2. **"你家光猫/网关能放行 IPv6 入站到 22/tcp 和 8443/udp 吗？"**
   - 不能 / 不会配 → 走方案 A
   - 能 → 可以走方案 B（更优），方案 A 作为 fallback

3. **"你愿意维护一台公网 ECS（最低配每月 ~30 元）吗？"**
   - 不愿意 + 上面 IPv6 又通了 → 只走方案 B
   - 愿意 → 推荐**双轨**：方案 A 主用，方案 B 作为延迟更低的可选路径

## 引导式安装流程

当用户决定动手搭建时，按以下顺序收集参数（**全部用占位符落到模板里，不要泄漏自己的真实值**）：

### 共同参数

- 远程 Mac 主机名（如 `MacBook-Pro.local`）
- 客户端设备列表（iPhone / iPad / 备用 Mac / Linux）
- ssh 用户名（默认就是 macOS 的当前用户）

### ECS Relay 方案额外参数

- ECS 公网 IP
- ECS 系统（CentOS / Ubuntu / Debian）
- ECS 上为本机分配的用户名（如 `jliu` / `jliu-mini`）
- 反向隧道本地端口（默认 `10023` / `10024`，多机分配）

### DDNS 直连方案额外参数

- 持有的域名（如 `example.com`）
- 用于本机的子域名（如 `home.example.com`）
- DNS 服务商（Cloudflare 等）
- 家庭网关型号（用于查 IPv6 入站设置入口）

### 客户端参数

- 主用客户端（Blink Shell / Termius / 终端模拟器）
- 项目 tmux session 名（如 `main`）
- 项目工作目录（如 `~/Projects/myapp`）

## 安装阶段

收集完参数后，依次完成：

1. **后端 Mac 准备** — `sudo systemsetup -setremotelogin on`、安装 mosh / tmux、电源管理
2. **方案 A 路径**：在 ECS 上配置 sshd_config + ForceCommand + 安全组；本机配置 LaunchAgent 维持反向隧道（详见 `references/ecs-relay-blueprint.md`）
3. **方案 B 路径**：配置 DDNS 更新脚本 + LaunchAgent；配置家庭网关 IPv6 入站（详见 `references/ddns-direct-blueprint.md`）
4. **客户端配置** — Blink / Termius / La Terminal / 命令行 mosh 的 Host 配置（详见 `references/client-config.md`）
5. **tmux 持久会话** — 配置项目自动 attach（详见 `references/tmux-session-recipes.md`）
6. **验收清单** — 跑一遍最小验证：`ssh` 能通、`mosh` 能通、tmux 能 attach、网络切换连接不掉

## 故障速查

最常见的坑（详见 `references/troubleshooting.md`）：

- **macOS 笔记本合盖后断连** → Clamshell Sleep；首选 HDMI dummy plug 常驻
- **mosh 连不上但 ssh 能通** → UDP 端口（8443 或 60000-61000）没放行
- **白天偶发断连** → 客户端 TUN/代理把 ECS 流量截走，需要给 ECS IP 加 DIRECT 规则
- **第二个 mosh 窗口失败** → ECS 强制了单 UDP 端口；改回端口段
- **DDNS 解析对了但还是连不上** → 公网 IPv6 入站没放行，跟 DDNS 无关

## 不要做的事

- ❌ 不要给方案 A 强制固定单个 mosh UDP 端口（多窗口会失败）
- ❌ 不要把"笔记本合盖+电池模式"当成可稳定运行的远程后端
- ❌ 不要在 README/文章里贴你真实的 ECS IP 和域名（会被扫描爆破）
- ❌ 不要跳过 `ssh` 试通就直接配 `mosh`（mosh 第一步就是 ssh 启动 mosh-server）
