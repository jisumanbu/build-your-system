# 客户端配置模板

覆盖主流 mosh + tmux 客户端的具体配置。AI 在引导用户时，按用户实际客户端选用对应章节。

---

## 1. Blink Shell（iPhone / iPad，强烈推荐）

Blink 是 iOS 上唯一把 mosh + tmux 集成体验做到位的客户端。可以付费购买（一次性约 ¥150）或自编译开源版本。

### 1.1 添加 Host

在 Blink 内输入 `config`，选 `Hosts` → 加号添加：

```
Host        = <alias-name>           # 你给这个连接起的别名，如 "home-mac"
HostName    = <server-or-relay-ip>   # ECS Relay 方案：ECS 公网 IP；DDNS 方案：域名
User        = <ssh-user>             # 登录用户名
Port        = 22                     # 默认 SSH 端口
Mosh        = on                     # 关键：开启 mosh
Mosh Port   = 60000-61000            # ECS Relay 默认；DDNS 直连建议固定为 8443
```

### 1.2 启动时自动进入 tmux 项目会话（可选但推荐）

在 Host 配置最下方的 `Command` 字段填：

```
tmux new-session -A -s <session-name> -c <project-path>
```

参数解释：
- `-A` —— attach 已存在的 session，没有则自动 new（**关键**，避免每次重连建新 session）
- `-s <session-name>` —— session 名字（建议用项目名，如 `myapp`）
- `-c <project-path>` —— 启动时的工作目录

效果：
- 第一次连：自动创建 `myapp` session 并 cd 到项目目录
- 后续重连：直接进入已存在的 `myapp` session，状态完全一致
- 在 session 内输入 `exit`：退出 session 但不断开 mosh，回到登录 shell

### 1.3 添加 SSH Key

`config` → `Keys` → `+` → `Generate new key`（推荐 ED25519）

生成后将 `Public Key` 复制到服务端的 `~/.ssh/authorized_keys`。

### 1.4 多设备多账户

每台后端设备建一个 Host alias：

```
home-mac      → 家里 MacBook Pro
home-mini     → 家里 Mac mini
work-server   → 公司 Linux 开发机
```

在 Blink 内直接输入 `mosh home-mac` 即可。

---

## 2. Termius（iOS / iPad / macOS / Windows / Linux 跨平台）

Termius 也支持 mosh，但配置位置和 Blink 不同。

### 关键设置

- `Hosts` → 新建 → 填 Hostname / Username / SSH Key
- 切换到 `Mosh` tab → 开启 `Use mosh`
- `Port range` 默认 60000-61000（与 Blink 一致）
- `Startup snippet` 等价于 Blink 的 `Command`，填 tmux attach 命令

### Termius 已知差异

- Termius 的 mosh 实现略落后于 Blink，**iOS 后台保活时间更短**（Blink 大约 30 分钟，Termius 大约 5-10 分钟）
- 适合**桌面客户端**，移动端首选 Blink

---

## 3. La Terminal（iPhone / iPad，国产，免费）

La Terminal 当前对 mosh + tmux 支持的**稳定行为**：

- mosh 能正常通过 ECS Relay 建立 UDP 会话
- 但**不要假设** mosh 会自动附带 tmux 命令
- 推荐流程：
  1. 先用 mosh 连上服务器
  2. 再用 La Terminal 自带的 "Attach to TMux session" 功能附加

原因：不同客户端对 mosh 首次 SSH 启动阶段是否支持远端命令、是否保留额外控制通道，行为并不一致。

---

## 4. 通用 Mosh CLI（macOS / Linux 桌面）

如果是桌面终端直接连：

```bash
# 最简
mosh <user>@<server-ip>

# 指定 ssh 端口
mosh --ssh='ssh -p 22' <user>@<server-ip>

# DDNS 直连方案，固定 mosh-server 端口为 8443
mosh --ssh='ssh -p 22' <user>@<domain> --server='mosh-server new -p 8443'

# 连上后自动进入项目 tmux
mosh <user>@<server-ip> -- tmux new-session -A -s myapp -c /path/to/project
```

---

## 5. 客户端代理 / VPN 注意事项

如果客户端开了 Clash / Surge / 任何 TUN：

```
# 必须给 ECS IP 加 DIRECT 规则（避免 UDP 被代理截走）
IP-CIDR,<your-ecs-ip>/32,DIRECT

# 如果同时用 DDNS 方案，再加：
DOMAIN,<your-ddns-domain>,DIRECT
```

否则会出现"白天偶发连不上、过会儿又恢复"的诡异故障。

---

## 6. 验收清单

配置完一台客户端后，按顺序验：

1. SSH 能通：在客户端 shell 里输入 `ssh <alias>` 应该不报错
2. mosh 能通：`mosh <alias>` 应该看到 `MOSH CONNECT 6000x ...`
3. tmux session 自动进：进入后顶部应该看到 tmux 状态栏
4. 网络切换不掉：从 WiFi 切到蜂窝再切回，连接保持
5. App 后台 30 分钟回来不掉（Blink 测过；其他客户端时间不一）
