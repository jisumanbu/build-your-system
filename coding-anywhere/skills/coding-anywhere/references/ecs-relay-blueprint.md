# 方案 A：ECS Relay 完整模板

适用：家里没公网 IP/IPv6、在 NAT 后、或想要"任意网络环境都能稳定连"。

**核心思路**：一台公网 ECS 做首跳；家庭 Mac 主动建立 reverse SSH 隧道到 ECS；外部客户端只打到 ECS；ECS 按 SSH 用户分流到不同后端 Mac；mosh-server 在 ECS 启动，tmux 命令再透传到后端 Mac。

---

## 1. 目标拓扑

```text
Client (iPhone / iPad / Mac)
   │
   │ 1. 连接 <your-ecs-ip>:22
   ▼
Public ECS (Linux)
   │
   │ 2. 按登录用户分流：
   │    - <user-1>      → 127.0.0.1:10023 → Mac #1:22
   │    - <user-2>      → 127.0.0.1:10024 → Mac #2:22
   │ 3. mosh-server 在 ECS 本机启动
   │ 4. 客户端显式 tmux 命令透传到后端 Mac
   ▼
tmux / shell on home Mac
```

---

## 2. 前置条件

- 一台公网 ECS（最低配即可，约 ¥30/月）
- 家庭 Mac 已开启 `sshd`（系统设置 → 通用 → 共享 → 远程登录）
- 家庭 Mac 已安装 `tmux`（`brew install tmux`）
- ECS 上已安装 `mosh-server`（CentOS/RHEL: `dnf install -y epel-release mosh`；Ubuntu/Debian: `apt install -y mosh`）
- ECS 安全组放行：`tcp/22` 和 `udp/60000-61000`
- 如果家庭后端是笔记本：参考 `troubleshooting.md` §2 处理 Clamshell Sleep

---

## 3. ECS 端配置

### 3.1 创建 per-user 登录账号

每台后端 Mac 对应一个 ECS 上的登录用户：

```bash
# 在 ECS 上执行
useradd -m -s /bin/bash <user-1>
useradd -m -s /bin/bash <user-2>
mkdir -p /home/<user-1>/.ssh /home/<user-2>/.ssh
chmod 700 /home/<user-1>/.ssh /home/<user-2>/.ssh
chown -R <user-1>:<user-1> /home/<user-1>/.ssh
chown -R <user-2>:<user-2> /home/<user-2>/.ssh
```

### 3.2 写入客户端公钥

把 iPhone Blink、桌面 ssh 等客户端的公钥分别写入：

```
/home/<user-1>/.ssh/authorized_keys   # 想连 Mac #1 的客户端公钥
/home/<user-2>/.ssh/authorized_keys   # 想连 Mac #2 的客户端公钥
```

权限必须是 `600`，属主必须是对应用户。

### 3.3 准备回跳到后端 Mac 的 key

ECS 上的 `<user-1>` 用户需要一对 key 用于从 ECS 反向跳到 Mac #1：

```bash
# 在 ECS 上以对应用户身份生成
sudo -u <user-1> ssh-keygen -t ed25519 -f /home/<user-1>/.ssh/mac-relay -N ''
sudo -u <user-2> ssh-keygen -t ed25519 -f /home/<user-2>/.ssh/mac-relay -N ''
```

把这两把公钥分别加入对应后端 Mac 的 `~/.ssh/authorized_keys`：

```
/home/<user-1>/.ssh/mac-relay.pub  →  Mac #1 的 ~/.ssh/authorized_keys
/home/<user-2>/.ssh/mac-relay.pub  →  Mac #2 的 ~/.ssh/authorized_keys
```

### 3.4 安装 ForceCommand 分流脚本

在 ECS 上创建 `/usr/local/bin/coding-anywhere-forwarder`：

```python
#!/usr/bin/env python3
"""ECS-side ForceCommand: 按登录用户透传到后端 Mac。"""

import os
import shlex
import subprocess
import sys

IDENTITY_FILE = os.environ.get("CA_IDENTITY_FILE", "/home/example/.ssh/mac-relay")
KNOWN_HOSTS_FILE = os.environ.get("CA_KNOWN_HOSTS_FILE", "/home/example/.ssh/known_hosts.macrelay")
BACKEND_PORT = os.environ.get("CA_BACKEND_PORT", "10023")
BACKEND_USER = os.environ.get("CA_BACKEND_USER", os.environ.get("USER", "jliu"))
LOG_FILE = os.environ.get("CA_LOG_FILE", "/tmp/coding-anywhere-forwarder.log")

original = os.environ.get("SSH_ORIGINAL_COMMAND", "").strip()

ssh_cmd = [
    "ssh",
    "-T",
    "-o", "BatchMode=yes",
    "-o", "StrictHostKeyChecking=no",
    "-o", f"UserKnownHostsFile={KNOWN_HOSTS_FILE}",
    "-i", IDENTITY_FILE,
    "-p", BACKEND_PORT,
    f"{BACKEND_USER}@127.0.0.1",
]

if original:
    # 客户端带了远端命令（如 tmux new-session），透传
    ssh_cmd.append(original)
else:
    # 没带命令：进登录 shell（兼容 Blink 的 mosh+tmux 流程）
    ssh_cmd.append("zsh -l")

with open(LOG_FILE, "a") as f:
    f.write(f"[{os.getpid()}] {' '.join(shlex.quote(x) for x in ssh_cmd)}\n")

os.execvp(ssh_cmd[0], ssh_cmd)
```

部署：

```bash
chmod +x /usr/local/bin/coding-anywhere-forwarder
chown root:root /usr/local/bin/coding-anywhere-forwarder
```

### 3.5 配置 sshd_config

把以下追加到 `/etc/ssh/sshd_config`（**`ClientAlive*` 必须在所有 `Match` 之前，否则被遮蔽不生效**）：

```conf
# === Coding Anywhere ===

# 全局 dead peer 检测：后端 Mac 睡眠/掉线时，~90s 内释放反向监听端口
ClientAliveInterval 30
ClientAliveCountMax 3

Match User <user-1>
  ForceCommand env CA_IDENTITY_FILE=/home/<user-1>/.ssh/mac-relay CA_KNOWN_HOSTS_FILE=/home/<user-1>/.ssh/known_hosts.macrelay CA_BACKEND_PORT=10023 CA_BACKEND_USER=<mac1-user> /usr/local/bin/coding-anywhere-forwarder
  AllowTcpForwarding no
  X11Forwarding no
  PermitTTY yes

Match User <user-2>
  ForceCommand env CA_IDENTITY_FILE=/home/<user-2>/.ssh/mac-relay CA_KNOWN_HOSTS_FILE=/home/<user-2>/.ssh/known_hosts.macrelay CA_BACKEND_PORT=10024 CA_BACKEND_USER=<mac2-user> /usr/local/bin/coding-anywhere-forwarder
  AllowTcpForwarding no
  X11Forwarding no
  PermitTTY yes
```

重载：

```bash
systemctl reload sshd
```

### 3.6 ECS 安全组 / 防火墙

放行：

- `tcp/22`（SSH 公网入口）
- `udp/60000-61000`（mosh 端口段；**不要**强制单端口，否则多 mosh 窗口会失败）

---

## 4. 后端 Mac 端配置

### 4.1 生成 reverse SSH 专用 key

```bash
# 在每台 Mac 上执行
ssh-keygen -t ed25519 -f ~/.ssh/coding-anywhere-relay -N ''
```

把 `~/.ssh/coding-anywhere-relay.pub` 追加到 ECS `root` 用户的 `authorized_keys`（reverse SSH 默认连 root；也可以改成专门的 relay 用户）。

### 4.2 reverse SSH 维持脚本

创建 `~/.local/bin/run-coding-anywhere-relay`：

```bash
#!/bin/zsh
# reverse SSH keep-alive: 把本机 22 反向暴露到 ECS 的 127.0.0.1:<remote-port>

set -e

IDENTITY_FILE="${CA_IDENTITY_FILE:-$HOME/.ssh/coding-anywhere-relay}"
KNOWN_HOSTS_FILE="${CA_KNOWN_HOSTS_FILE:-$HOME/.ssh/known_hosts}"
RELAY_HOST="${CA_RELAY_HOST:-<your-ecs-ip>}"
RELAY_USER="${CA_RELAY_USER:-root}"
REMOTE_BIND="${CA_REMOTE_BIND:-127.0.0.1:10023:127.0.0.1:22}"

exec ssh \
    -N \
    -i "$IDENTITY_FILE" \
    -o "UserKnownHostsFile=$KNOWN_HOSTS_FILE" \
    -o "ServerAliveInterval=30" \
    -o "ServerAliveCountMax=3" \
    -o "ExitOnForwardFailure=yes" \
    -o "StrictHostKeyChecking=accept-new" \
    -R "$REMOTE_BIND" \
    "$RELAY_USER@$RELAY_HOST"
```

```bash
chmod +x ~/.local/bin/run-coding-anywhere-relay
```

### 4.3 LaunchAgent 自动维持

创建 `~/Library/LaunchAgents/com.<your-name>.coding-anywhere-relay.plist`：

```xml
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
  <key>Label</key>
  <string>com.<your-name>.coding-anywhere-relay</string>

  <key>ProgramArguments</key>
  <array>
    <string>/Users/<your-mac-user>/.local/bin/run-coding-anywhere-relay</string>
  </array>

  <key>EnvironmentVariables</key>
  <dict>
    <key>CA_IDENTITY_FILE</key>
    <string>/Users/<your-mac-user>/.ssh/coding-anywhere-relay</string>
    <key>CA_KNOWN_HOSTS_FILE</key>
    <string>/Users/<your-mac-user>/.ssh/known_hosts</string>
    <key>CA_RELAY_HOST</key>
    <string><your-ecs-ip></string>
    <key>CA_RELAY_USER</key>
    <string>root</string>
    <key>CA_REMOTE_BIND</key>
    <string>127.0.0.1:10023:127.0.0.1:22</string>
  </dict>

  <key>RunAtLoad</key>
  <true/>

  <key>KeepAlive</key>
  <true/>

  <key>ThrottleInterval</key>
  <integer>10</integer>

  <key>StandardOutPath</key>
  <string>/Users/<your-mac-user>/Library/Logs/com.<your-name>.coding-anywhere-relay.log</string>

  <key>StandardErrorPath</key>
  <string>/Users/<your-mac-user>/Library/Logs/com.<your-name>.coding-anywhere-relay.err.log</string>
</dict>
</plist>
```

启动：

```bash
launchctl bootout gui/$(id -u) ~/Library/LaunchAgents/com.<your-name>.coding-anywhere-relay.plist 2>/dev/null || true
launchctl bootstrap gui/$(id -u) ~/Library/LaunchAgents/com.<your-name>.coding-anywhere-relay.plist
launchctl kickstart -k gui/$(id -u)/com.<your-name>.coding-anywhere-relay
```

### 4.4 第二台 Mac

把上面所有 `10023` 替换成 `10024`，文件名加后缀（`-mac2`）即可。如果只有一台 Mac，跳过这步。

---

## 5. 客户端配置

详见 `client-config.md`。最小配置：

```
Host = home-mac
HostName = <your-ecs-ip>
User = <user-1>
Mosh = on
Mosh Port = 60000-61000
Command = tmux new-session -A -s <session-name> -c <project-path>
```

---

## 6. 验收清单

按顺序跑，不要跳步：

```bash
# 1. ECS 端：reverse 隧道是否建立
ssh root@<your-ecs-ip> 'ss -lntp | egrep ":22|:10023|:10024"'
# 预期看到：0.0.0.0:22 / 127.0.0.1:10023 / 127.0.0.1:10024

# 2. ECS 到后端的回跳通不通
ssh root@<your-ecs-ip> 'sudo -u <user-1> ssh -o BatchMode=yes -i /home/<user-1>/.ssh/mac-relay -p 10023 <mac1-user>@127.0.0.1 hostname'
# 预期返回 Mac #1 的主机名

# 3. 公网入口 SSH
ssh <user-1>@<your-ecs-ip> hostname
# 预期返回 Mac #1 的主机名

# 4. mosh-server 启动测试
ssh <user-1>@<your-ecs-ip> 'mosh-server new -s -l LANG=en_US.UTF-8'
# 预期返回 MOSH CONNECT 6000x ...

# 5. 完整 mosh 端到端
mosh <user-1>@<your-ecs-ip>
# 预期进入 Mac #1 的 shell

# 6. ClientAlive 是否生效
ssh root@<your-ecs-ip> 'sshd -T | grep -i clientalive'
# 预期 clientaliveinterval 30 / clientalivecountmax 3
```

---

## 7. 安全建议

- **不要在公网帖子里暴露你的 ECS IP** — 会被自动扫描+暴力破解
- ECS 的 `sshd_config` 关闭 `PasswordAuthentication`，只用 key
- 给每台客户端单独生成 key，不共用
- 定期轮换 reverse SSH 用的 ECS 端 root 公钥（或用专门的 relay 用户代替 root）
- 考虑给 ECS 装 fail2ban
- 如果不需要某个客户端了，立即从 `authorized_keys` 移除对应公钥

---

## 8. 回滚

如果要彻底撤掉这套方案：

```bash
# 后端 Mac
launchctl bootout gui/$(id -u) ~/Library/LaunchAgents/com.<your-name>.coding-anywhere-relay.plist
rm ~/Library/LaunchAgents/com.<your-name>.coding-anywhere-relay.plist
rm ~/.local/bin/run-coding-anywhere-relay
rm ~/.ssh/coding-anywhere-relay ~/.ssh/coding-anywhere-relay.pub

# ECS
sudo rm /usr/local/bin/coding-anywhere-forwarder
# 编辑 /etc/ssh/sshd_config 删除 Match User 块
sudo systemctl reload sshd
sudo userdel -r <user-1>
sudo userdel -r <user-2>
```
