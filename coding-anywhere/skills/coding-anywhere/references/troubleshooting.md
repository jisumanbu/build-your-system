# 故障排查 - 常见坑与定位方法

按"症状 → 根因 → 修复"组织。AI 帮用户排障时，按用户描述的症状定位章节。

---

## 1. mosh 连不上，但 ssh 能通

**症状**：`ssh user@host` 进得去，`mosh user@host` 卡住或超时。

**最常见根因**（按概率排序）：

1. **UDP 端口没放行**
   - ECS Relay 方案：安全组要放 `udp/60000-61000`
   - DDNS 直连方案：家庭网关要放 `udp/8443`（如果固定了端口）或同样的端口段
2. **客户端开了 TUN/代理把 UDP 截走**
   - 详见下面 §3
3. **服务端没装 mosh**
   - 跑 `which mosh-server` 验证

**排查命令**：

```bash
# 在服务端验证 mosh-server 能起
ssh user@host "mosh-server new -s -l LANG=en_US.UTF-8"
# 应该看到：MOSH CONNECT 6000x <key>
```

如果上一步成功但 mosh 还是连不上，几乎可以判定 UDP 链路被阻断。

---

## 2. macOS 笔记本作为远程后端，合盖一段时间后断连

**症状**：白天用得好好的，凌晨/隔夜某个时间点突然 ECS 主入口连不上 MacBook，需要打开盖子才能恢复。

**根因**：**Clamshell Sleep**（合盖睡眠）。`pmset sleep 0` 拦不住这个。Clamshell Sleep 触发需要**同时**满足：

1. 盖子合着
2. 外接显示器已下线（EDID 丢失 / 显示器硬关电源）
3. 当前没有任何 sleep-blocking assertion

**关键理解**：前两条决定"允许睡"，第三条决定"现在就睡 vs 等会儿睡"。常见的 sleep-blocking assertion 来源：
- 活跃 TTY（mosh/ssh 会话里跑着任务）—— `pmset ttyskeepawake 1` 让 powerd 持有 `NetworkClientActive "ttyassertion"`
- `caffeinate` / `caffeinate -dimsu`
- 音频播放、iCloud 正在同步

只要任一 assertion 在，合盖+关显示器也不会立即睡。这就是"凌晨 3 点突然睡死"的真相——是 assertion 释放的瞬间才睡的。

**修复（按推荐排序）**：

| 方案 | 优点 | 缺点 |
|------|------|------|
| **HDMI/DP dummy plug 常驻** | 最稳，可以随意关显示器电源 | 需要买配件（~¥30） |
| 夜里不关显示器电源，仅让 macOS `displaysleep` 黑屏 | 零配件成本 | 显示器一直在线 |
| 常驻 sleep assertion（如带 heartbeat 的 tmux 任务） | 不用买配件 | 不稳，Apple 文档没保证 `ttyskeepawake` 长期行为 |

**Apple Silicon 注意**：Intel 时代的 `nvram boot-args=iog=0x0` 在 M 系芯片**不适用**，无法通过 `pmset` 关闭 Clamshell Sleep。

**排障命令**：

```bash
# 1. 看是不是 Clamshell Sleep
pmset -g log | grep -E "Clamshell Sleep|Entering Sleep" | tail -20

# 2. 看 Clamshell Sleep 触发前最后释放的 assertion 是谁
pmset -g log | grep -B2 "Entering Sleep state due to 'Clamshell Sleep'" | tail -30
```

---

## 3. 白天偶发断连，过一会儿自己恢复

**症状**：某个时段（往往中午）突然连不上，过 30 分钟到 2 小时自己好。relay LaunchAgent 还在跑，但日志反复出现 `Connection closed by ... port 22` 或 `No route to host`。

**根因**：本机的 Clash / Surge / 任何 TUN 在某个规则刷新瞬间，把发往服务端的流量接管了，导致 reverse SSH 断开。

**修复**：在代理客户端加直连规则：

```conf
# Clash / Surge / Loon 通用语法
IP-CIDR,<your-ecs-ip>/32,DIRECT
DOMAIN,<your-ddns-domain>,DIRECT
DOMAIN-SUFFIX,<your-root-domain>,DIRECT
```

**验证**：

```bash
route -n get <your-ecs-ip>
# 预期 interface 是 en0 / en1（家庭网卡）
# 错误：interface 是 utun（TUN 设备）
```

---

## 4. 第二个 mosh 窗口失败（NoMoshServerArgs / Timed out waiting for server）

**症状**：第一个 mosh 窗口正常，第二个窗口提示 `NoMoshServerArgs` 或 `Timed out waiting for server`。

**根因**：服务端强制把 mosh 固定到了**单个** UDP 端口（比如只放行 `udp/8443`），第二个 mosh-server 没端口可用。

**修复**：

- ECS Relay 方案：保持默认端口段 `udp/60000-61000`，**不要**强制单端口
- DDNS 直连方案：如果一定要固定端口（光猫 IPv6 入站规则受限），至少放一段（如 `udp/60000-61010`）

---

## 5. 登录后进了普通 shell，没自动进项目 tmux

**症状**：`mosh <alias>` 连上了，但只看到 `~ %`，没自动进 tmux session。

**根因**（按概率排序）：

1. 客户端的 `Command` 字段没设
2. mosh 启动阶段没把远端命令传过去（部分客户端如 La Terminal 行为不一致）
3. 服务端的 ForceCommand 配错

**修复**：

- Blink：`Hosts` → 编辑 → `Command` 字段填 `tmux new-session -A -s <session-name> -c <path>`
- La Terminal：先 mosh 连上，再用 App 自带的 "Attach to TMux session" 功能
- Termius：`Startup snippet` 字段填同上

---

## 6. DDNS 解析正确，但公网还是连不上

**症状**：`dig AAAA <your-domain> +short` 返回了 IP，但外部 ssh 连不上。

**根因**：DDNS 只负责"告诉别人你在哪"，不负责"允许别人打进来"。家庭网关/光猫的 IPv6 入站规则没放行。

**修复**：登录光猫后台，找"IPv6 防火墙" / "端口转发"页面，放行：

- `tcp/22`（SSH）
- `udp/8443` 或 `udp/60000-61000`（mosh）

不同光猫品牌操作路径差异较大，常见的入口词：
- 华为：高级 → 安全 → IPv6 防火墙
- 中兴：网络 → IPv6 → 防火墙规则
- 商用网关（OpenWrt 等）：Network → Firewall → Traffic Rules

---

## 7. reverse SSH 报 `remote port forwarding failed`

**症状**：MacBook 端 LaunchAgent 日志反复出现 `Warning: remote port forwarding failed for listen port 10023`。

**根因**：ECS 端的 reverse 隧道端口（10023 / 10024）被旧的僵尸隧道占住了。

**排查**：

```bash
ssh root@<your-ecs-ip> 'ss -lntp | egrep "10023|10024"'
```

**修复**：

如果 ECS 上配置了 `ClientAliveInterval 30` + `ClientAliveCountMax 3`（详见 ecs-relay-blueprint.md），ECS 会在 ~90 秒内检测到 dead peer 并释放端口，本地 LaunchAgent 下一次重试就成功。

如果错误持续超过 2 分钟：

```bash
ssh root@<your-ecs-ip> 'sshd -T | grep -i clientalive'
```

预期 `clientaliveinterval 30` / `clientalivecountmax 3`。如果空，说明 sshd_config 里的 `ClientAlive*` 配置漏了或被某个 `Match` 块遮蔽（必须放在所有 `Match` 之前）。

---

## 8. 进 tmux session 后输入 `exit` 整个 mosh 断开

**症状**：在 tmux 里 `exit` 想退出 session 回到登录 shell，结果 mosh 也断了。

**根因**：服务端启动 tmux 用的是 `tmux new-session -A -s ...`，session 退出后没有回退到登录 shell。

**修复**：把启动命令改成：

```bash
zsh -lc 'tmux new-session -A -s <name> -c <path>; exec /bin/zsh -l'
```

或者在 ForceCommand 脚本里固定这套包装。

---

## 9. 通用排查清单

遇到任何远程连接问题，按这个顺序快速二分：

1. **DNS 层**：`dig <your-host>` 解析对吗？
2. **网络层**：`ping <your-host>` 通吗？（注意：mosh 用 UDP，能 ping ≠ mosh 能通）
3. **TCP 层**：`nc -vz <your-host> 22` 通吗？
4. **SSH 层**：`ssh -v <user>@<host>` 看握手哪步失败
5. **应用层**：能 ssh 但不能 mosh，查 UDP 链路；能 mosh 但 tmux 不进，查 ForceCommand / Command
6. **客户端层**：换个客户端（手机切桌面、Blink 切 Termius）看是不是单一客户端问题
