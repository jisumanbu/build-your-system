# tmux 持久会话最佳实践

mosh 解决"网络断不掉"，tmux 解决"App 关了/电脑重启了 session 还在"。两者结合才是完整体验。

---

## 1. 核心命令：`new-session -A -s <name>`

```bash
tmux new-session -A -s <session-name> -c <working-dir>
```

参数解读：

- **`-A`**：attach if exists, else create — **这一参数是 mosh+tmux 体验的灵魂**
  - 不加 `-A`，每次 `tmux new` 都会创建新 session，旧 session 累积成 `myapp`、`myapp-1`、`myapp-2`...
  - 加 `-A`，永远只有一个 `myapp`，多次连接进入同一个状态
- **`-s <name>`**：session 名字。建议**用项目名**，便于多项目隔离
- **`-c <dir>`**：新建时的初始工作目录（仅 first-time 生效）

---

## 2. 推荐的 session 命名约定

```
myapp-backend    # 后端项目
myapp-frontend   # 前端项目
ops              # 运维杂事
scratch          # 探索性临时活
notes            # tmux 内开 vim 记笔记
```

每个 session 独立窗口、独立历史、独立环境变量。

---

## 3. Detach vs Exit 的区别

| 操作 | 快捷键 / 命令 | 效果 |
|------|--------------|------|
| **Detach** | `Ctrl-B d` | 退出 tmux 视图但 session 留在后台 |
| **Exit shell** | 输入 `exit` | 关掉当前 shell；如果是 session 的最后一个 shell，session 也消失 |

**关键陷阱**：在 mosh+tmux 链路里，如果你 `exit` 了 tmux session 的最后一个 shell，你的 mosh 连接也会一起断（因为远端没有可读的 stdin/stdout 了）。

**避免方法**：用客户端的 `Command` 字段 + 一个登录 shell wrapper：

```bash
zsh -lc 'tmux new-session -A -s myapp -c /path/to/myapp; exec /bin/zsh -l'
```

效果：在 tmux session 里 `exit` 时：
- 退出 tmux session
- 回到登录 shell（不断 mosh）
- 再 `exit` 一次才彻底断开

---

## 4. Window 与 Pane 速查

tmux 内部用 prefix（默认 `Ctrl-B`）+ 字母控制：

| 快捷键 | 作用 |
|--------|------|
| `Ctrl-B c` | 新建 window |
| `Ctrl-B 0/1/2...` | 切换到第 N 个 window |
| `Ctrl-B ,` | 给当前 window 改名 |
| `Ctrl-B %` | 垂直分割 pane |
| `Ctrl-B "` | 水平分割 pane |
| `Ctrl-B 方向键` | 在 pane 之间切换 |
| `Ctrl-B z` | 当前 pane 全屏 / 还原 |
| `Ctrl-B [` | 进入复制模式（vim 键位滚动） |
| `Ctrl-B d` | detach（**最常用**） |
| `Ctrl-B ?` | 查所有快捷键 |

iPhone / iPad 客户端（Blink 等）通常会把 prefix 改成更易触达的键（如左下方手势区域），见客户端文档。

---

## 5. 在客户端预设多 session 的方式

如果你有多个项目，可以在客户端建多个 Host alias，每个 alias 的 `Command` 字段对应不同 tmux session：

```
Host: home-mac-app      Command: tmux new-session -A -s app -c ~/Projects/app
Host: home-mac-blog     Command: tmux new-session -A -s blog -c ~/Projects/blog
Host: home-mac-shell    Command: <留空，进入登录 shell，手动选 session>
```

这样在 Blink 里输入 `mosh home-mac-app` 就直接进项目，不用每次手动 `tmux a -t app`。

---

## 6. 持久化 tmux 配置

把以下放到后端 Mac 的 `~/.tmux.conf`：

```conf
# 鼠标支持（iPad/iPhone 触屏滚动会更舒服）
set -g mouse on

# 历史 buffer 大小（默认 2000 行太小）
set -g history-limit 100000

# 状态栏显示 session 名 + 时间
set -g status-left "[#S] "
set -g status-right "%H:%M %d-%b "

# 重新加载配置
bind r source-file ~/.tmux.conf \; display "Config reloaded"

# 减少 escape 延迟（vim 用户必备）
set -sg escape-time 0
```

修改后在已有 session 里 `Ctrl-B :source-file ~/.tmux.conf`，新 session 自动生效。

---

## 7. 常见困惑

### Q: 为什么 mosh 已经断不了了，还要 tmux？
A: mosh 解决的是"客户端到服务端的网络链路不掉"。tmux 解决的是"shell 进程不掉"。如果你重启服务端、关掉 App 太久、mosh-server 自己超时退出，tmux session 还在，下次进来 attach 即可。

### Q: 一个 session 被多个客户端同时 attach，会冲突吗？
A: 不冲突，多设备共享同一个 session 是 tmux 的核心特性（叫 "shared session"）。比如 iPad 和 MacBook 同时 attach 同一个 session，看到的内容是同步的。注意：两边输入的字符会**交错**，所以日常单人用建议同时只 attach 一个。

### Q: tmux 内 vim 颜色不对？
A: 在 `~/.tmux.conf` 加 `set -g default-terminal "tmux-256color"`；如果客户端不支持，退回 `screen-256color`。
