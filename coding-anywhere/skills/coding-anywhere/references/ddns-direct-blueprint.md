# 方案 B：DDNS + IPv6 直连完整模板

适用：家里有公网 IPv6（或公网 IPv4 + 端口映射），且家庭网关支持 IPv6 入站放行。

**核心思路**：用 DDNS 把域名跟着家庭 Mac 的当前公网 IPv6 走；客户端直接 ssh/mosh 到域名；不经过任何中继。

---

## 1. 目标拓扑

```text
Client
   │
   │ 1. 查询 <your-host>.<your-domain>
   ▼
DNS provider (Cloudflare 等)
   │
   │ 2. 返回家庭 Mac 当前公网 IPv6
   ▼
Home Mac
   │
   │ 3. 22/tcp 直接 SSH
   │ 4. 8443/udp 直接 mosh
   ▼
tmux / shell
```

**优点**：路径最短、延迟最低、不依赖第三方 ECS、零月费。
**代价**：必须有公网 IPv6（或端口可映射的公网 IPv4），且**家庭网关/光猫必须能放行 IPv6 入站**。

---

## 2. 先验证可行性（重要！）

很多人以为"DDNS 可行"=="DDNS 能用"，**这两件事是不同的**。

DDNS 只解决一件事：把域名更新到当前公网地址。

它**不**解决：
- 家里这台 Mac 是否真的拿到了**稳定**的公网 IPv6
- 外部网络能否入站打到这台 Mac 的 `22/tcp`
- mosh 需要的 UDP 端口是否被家庭网关放行

**先做可行性验证**：

```bash
# 1. 这台 Mac 有稳定的全局 IPv6 吗？
ifconfig en0 | grep "inet6 " | grep -v "fe80:"
# 预期看到一行非 fe80: 开头的全局 IPv6 地址

# 2. 这个 IPv6 真的是公网可达吗？
curl -6 ifconfig.co
# 预期返回的地址跟上一步一致或同段

# 3. 找一个外部 IPv6 节点测试入站
# 在你的服务器/朋友的 Linux 机器上：
nc -6 -vz <your-mac-ipv6> 22
# 通了 → IPv6 入站 OK，可以继续；
# 不通 → 家庭网关没放行，先去配光猫，否则 DDNS 再对都没用
```

**如果第 3 步不通**，这条方案就走不通，回头看 ECS Relay 方案（`ecs-relay-blueprint.md`）。

---

## 3. DNS provider 配置（以 Cloudflare 为例）

### 3.1 准备 API token

Cloudflare 后台 → My Profile → API Tokens → Create Token：

- 选 "Edit zone DNS" 模板
- Zone Resources 选你的域名
- 复制生成的 token，存到 macOS keychain：

```bash
security add-generic-password \
    -a "$USER" \
    -s "coding-anywhere-cloudflare-token" \
    -w "<your-cloudflare-api-token>"
```

### 3.2 创建初始 AAAA 记录

在 Cloudflare DNS 控制台新建：

- Type: `AAAA`
- Name: `<your-host>` （如 `home`）
- Content: 当前 Mac 的公网 IPv6（任意填一个，DDNS 脚本会更新）
- Proxy: **关闭**（必须直连，不能走 Cloudflare CDN，因为 Cloudflare 不代理 SSH/mosh）
- TTL: Auto 或 1 minute

获取 Zone ID：DNS 页面右下角的 Overview 区域。

---

## 4. 本机 DDNS 更新脚本

创建 `~/.local/bin/update-coding-anywhere-ddns`：

```bash
#!/bin/zsh
# 把当前公网 IPv6 更新到 Cloudflare DNS

set -e

CF_TOKEN_SERVICE="${CA_CF_TOKEN_SERVICE:-coding-anywhere-cloudflare-token}"
CF_ZONE_ID="${CA_CF_ZONE_ID:-<your-cf-zone-id>}"
RECORD_NAME="${CA_RECORD_NAME:-<your-host>.<your-domain>}"
INTERFACE="${CA_INTERFACE:-en0}"

LOG_FILE="${CA_LOG_FILE:-$HOME/Library/Logs/com.<your-name>.coding-anywhere-ddns.log}"

log() { echo "[$(date '+%Y-%m-%d %H:%M:%S')] $1" >> "$LOG_FILE"; }

# 1. 获取当前 IPv6
CURRENT_IPV6=$(ifconfig "$INTERFACE" | awk '/inet6 / && !/fe80:/ && !/temporary/ {print $2; exit}')
if [ -z "$CURRENT_IPV6" ]; then
    log "ERROR: no global IPv6 on $INTERFACE"
    exit 1
fi

# 2. 取 token
CF_TOKEN=$(security find-generic-password -a "$USER" -s "$CF_TOKEN_SERVICE" -w 2>/dev/null)
if [ -z "$CF_TOKEN" ]; then
    log "ERROR: cannot read CF token from keychain ($CF_TOKEN_SERVICE)"
    exit 1
fi

# 3. 查现有 AAAA 记录
RECORD_INFO=$(curl -sS \
    -H "Authorization: Bearer $CF_TOKEN" \
    "https://api.cloudflare.com/client/v4/zones/$CF_ZONE_ID/dns_records?type=AAAA&name=$RECORD_NAME")

RECORD_ID=$(echo "$RECORD_INFO" | python3 -c "import sys,json;d=json.load(sys.stdin);print(d['result'][0]['id'] if d.get('result') else '')")
EXISTING_IPV6=$(echo "$RECORD_INFO" | python3 -c "import sys,json;d=json.load(sys.stdin);print(d['result'][0]['content'] if d.get('result') else '')")

# 4. 没变就不动
if [ "$CURRENT_IPV6" = "$EXISTING_IPV6" ]; then
    log "noop: $RECORD_NAME already $CURRENT_IPV6"
    exit 0
fi

# 5. 更新
RESULT=$(curl -sS -X PUT \
    -H "Authorization: Bearer $CF_TOKEN" \
    -H "Content-Type: application/json" \
    -d "{\"type\":\"AAAA\",\"name\":\"$RECORD_NAME\",\"content\":\"$CURRENT_IPV6\",\"ttl\":60,\"proxied\":false}" \
    "https://api.cloudflare.com/client/v4/zones/$CF_ZONE_ID/dns_records/$RECORD_ID")

if echo "$RESULT" | grep -q '"success":true'; then
    log "updated: $RECORD_NAME → $CURRENT_IPV6"
else
    log "ERROR: update failed: $RESULT"
    exit 1
fi
```

```bash
chmod +x ~/.local/bin/update-coding-anywhere-ddns
```

手动跑一次验证：

```bash
~/.local/bin/update-coding-anywhere-ddns
tail ~/Library/Logs/com.<your-name>.coding-anywhere-ddns.log
```

---

## 5. LaunchAgent 周期任务

创建 `~/Library/LaunchAgents/com.<your-name>.coding-anywhere-ddns.plist`：

```xml
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
  <key>Label</key>
  <string>com.<your-name>.coding-anywhere-ddns</string>

  <key>ProgramArguments</key>
  <array>
    <string>/Users/<your-mac-user>/.local/bin/update-coding-anywhere-ddns</string>
  </array>

  <key>EnvironmentVariables</key>
  <dict>
    <key>CA_CF_ZONE_ID</key>
    <string><your-cf-zone-id></string>
    <key>CA_RECORD_NAME</key>
    <string><your-host>.<your-domain></string>
    <key>CA_INTERFACE</key>
    <string>en0</string>
  </dict>

  <key>StartInterval</key>
  <integer>300</integer>

  <key>RunAtLoad</key>
  <true/>

  <key>StandardOutPath</key>
  <string>/Users/<your-mac-user>/Library/Logs/com.<your-name>.coding-anywhere-ddns.out.log</string>

  <key>StandardErrorPath</key>
  <string>/Users/<your-mac-user>/Library/Logs/com.<your-name>.coding-anywhere-ddns.err.log</string>
</dict>
</plist>
```

启动：

```bash
launchctl bootout gui/$(id -u) ~/Library/LaunchAgents/com.<your-name>.coding-anywhere-ddns.plist 2>/dev/null || true
launchctl bootstrap gui/$(id -u) ~/Library/LaunchAgents/com.<your-name>.coding-anywhere-ddns.plist
launchctl kickstart -k gui/$(id -u)/com.<your-name>.coding-anywhere-ddns
```

每 5 分钟检测一次 IPv6 变化并更新。

---

## 6. 家庭网关 IPv6 入站放行（**最容易卡住的一步**）

不同光猫品牌操作差异大，常见入口：

| 品牌 | 入口路径 |
|------|----------|
| 华为 | 高级设置 → 安全 → IPv6 防火墙 |
| 中兴 | 网络 → IPv6 → 防火墙规则 |
| 小米 / OpenWrt | Network → Firewall → Traffic Rules |
| 烽火 | 应用 → IPv6 防火墙 |

放行规则（**填写当前 Mac 的 IPv6 地址**）：

| 协议 | 端口 | 目标 |
|------|------|------|
| TCP | 22 | `<mac-ipv6>` |
| UDP | 8443 | `<mac-ipv6>`（推荐固定单端口） |

**为什么推荐固定 UDP 8443**：

- 家用网关单 UDP 端口规则更容易长期维护
- 比开放整段 60000-61000 更容易排障
- 8443 在 macOS 上不是特权端口，mosh-server 可直接绑定

**如果网关只能放整段**：放 `udp/60000-61000` 也行。

如果光猫 IPv6 入站根本无法手工配置（部分老款只允许 IPv4 端口映射），这条方案走不通。

---

## 7. 客户端配置

### Blink 配置示例

```
Host = home-mac-direct
HostName = <your-host>.<your-domain>
User = <your-mac-user>
Mosh = on
Mosh Server Cmd = mosh-server new -p 8443 -s -l LANG=en_US.UTF-8
Command = tmux new-session -A -s <session-name> -c <project-path>
```

### 命令行示例

```bash
mosh --ssh='ssh -p 22' <your-mac-user>@<your-host>.<your-domain> --server='mosh-server new -p 8443'
```

---

## 8. 验收清单

```bash
# 1. DNS 解析对吗
dig AAAA <your-host>.<your-domain> +short
# 预期返回当前 Mac 的公网 IPv6

# 2. DDNS 脚本本身能跑
~/.local/bin/update-coding-anywhere-ddns
tail ~/Library/Logs/com.<your-name>.coding-anywhere-ddns.log
# 预期 noop 或 updated

# 3. LaunchAgent 在跑
launchctl print gui/$(id -u)/com.<your-name>.coding-anywhere-ddns | grep "state ="
# 预期 state = waiting

# 4. 本机 sshd 在监听
nc -vz 127.0.0.1 22

# 5. 外网 SSH 入站（找一个外部 IPv6 节点测）
ssh <your-mac-user>@<your-host>.<your-domain>
# 不通 → 几乎可以判定家庭网关 IPv6 入站没放行（不是 DDNS 的问题！）

# 6. mosh 端到端
mosh --ssh='ssh -p 22' <your-mac-user>@<your-host>.<your-domain> --server='mosh-server new -p 8443'
```

**最常见的"DDNS 都对了但还是连不上"** 的根因 90% 是 §6 网关没放行。详见 `troubleshooting.md` §6。

---

## 9. 与 ECS Relay 方案的双轨快切策略

如果你两套方案都要保留：

- **日常主入口** alias = ECS Relay（稳定性更高）
- **延迟优先**入口 alias = DDNS 直连（路径更短）
- 在客户端建两套 Host alias 分别叫 `home-mac-relay` 和 `home-mac-direct`

故障切换原则：

1. **先**把新方案完整准备好（不动旧的）
2. 用单独的 alias 验证新方案
3. 验证通过后，再修改主 alias 的 HostName
4. 老方案 alias 保留，作为即时回滚入口

不要"先关旧方案再切 DNS"——切失败时手上没退路。

---

## 10. 回滚

```bash
launchctl bootout gui/$(id -u) ~/Library/LaunchAgents/com.<your-name>.coding-anywhere-ddns.plist
rm ~/Library/LaunchAgents/com.<your-name>.coding-anywhere-ddns.plist
rm ~/.local/bin/update-coding-anywhere-ddns
security delete-generic-password -a "$USER" -s "coding-anywhere-cloudflare-token"
# 在 Cloudflare 删除对应 AAAA 记录
# 撤销光猫的 IPv6 入站规则
```
