# agent-qq 完整部署指南

**适用版本：** v2.0.1 | **最后更新：** 2026-06-14

## 一、部署方案总览

| 方案 | 适用场景 | 复杂度 |
|------|---------|--------|
| Docker Compose | 生产推荐、隔离环境 | ⭐⭐ |
| systemd user service | 单用户、本地长期运行 | ⭐ |
| systemd system service | 多用户服务器 | ⭐⭐ |
| 本地 Python 虚拟环境 | 开发调试 | ⭐ |

---

## 二、前置条件

### 2.1 基础环境

| 项目 | 要求 |
|------|------|
| 操作系统 | Ubuntu/Linux |
| Python | 3.11+（本地）/ 3.12 slim（Docker） |
| NapCat QQ | 已安装并登录机器人 QQ |
| OneBot v11 | NapCat 中启用 WebSocket Server（端口 3001） |
| Claude Code CLI | 已安装、已登录、`claude -p` 可正常执行 |
| Git | 代码管理与更新 |

### 2.2 必备信息

| 信息 | 示例 | 用途 |
|------|------|------|
| 机器人 QQ | `<bot_qq_id>` | NapCat 登录账号 |
| 管理员 QQ | `<admin_qq_id>` | ADMIN_QQ_IDS |
| OneBot 地址 | `ws://127.0.0.1:3001`（本地）/ `ws://host.docker.internal:3001`（Docker） |
| Claude 配置目录 | `~/.claude` | Docker 挂载到 `/root/.claude:ro` |

---

## 三、方案 A：Docker Compose（推荐生产）

### 3.1 准备 NapCat

1. 启动 NapCat，登录机器人 QQ
2. 启用 OneBot v11 WebSocket Server：

```
Host: 0.0.0.0
Port: 3001
Access Token: （生产建议填写随机长字符串）
```

3. 验证端口：

```bash
ss -ltn | grep 3001
```

### 3.2 配置项目

```bash
cd /opt/agent-qq
cp .env.example .env
nano .env
```

最小配置：

```env
ONEBOT_WS_URL=ws://host.docker.internal:3001
ONEBOT_ACCESS_TOKEN=<你的token，如果没设就留空>
ENABLE_PRIVATE_CHAT=true
ADMIN_QQ_IDS=<你的QQ号>
CLAUDE_CONFIG_DIR=/home/你的用户名/.claude
CLAUDE_CLI_COMMAND=claude
CLAUDE_TIMEOUT_SECONDS=180
CLAUDE_WORKDIR=/workspace
```

### 3.3 构建并启动

```bash
docker compose up -d --build
docker compose ps
docker compose logs -f agent-qq
```

预期日志输出：

```
Log rotator startup cleanup: removed 0 terminal status entries
TaskMonitor started (poll every 5s)
Connected to OneBot: ws://host.docker.internal:3001
```

### 3.4 验证 Docker 内 Claude

```bash
docker compose exec agent-qq claude --version
docker compose exec agent-qq claude -p "你好，请只回复 OK"
```

### 3.5 Docker 运维命令

```bash
docker compose restart agent-qq    # 重启
docker compose down                # 停止
docker compose up -d --build       # 重建并启动
docker compose logs --tail=200 agent-qq  # 查看最近日志
```

---

## 四、方案 B：systemd user service（推荐本地）

### 4.1 创建虚拟环境

```bash
cd /home/ww/agent-qq
python3 -m venv .venv
source .venv/bin/activate
pip install -r requirements.txt
```

### 4.2 配置 `.env`

```env
ONEBOT_WS_URL=ws://127.0.0.1:3001
CLAUDE_CLI_COMMAND=claude
CLAUDE_TIMEOUT_SECONDS=180
CLAUDE_WORKDIR=/home/ww/agent-qq/workspace
ADMIN_QQ_IDS=<你的QQ号>
ENABLE_PRIVATE_CHAT=true
```

### 4.3 安装 systemd user service

```bash
mkdir -p ~/.config/systemd/user/
```

创建 `~/.config/systemd/user/agent-qq.service`：

```ini
[Unit]
Description=agent-qq QQ AI Agent
After=network-online.target
Wants=network-online.target

[Service]
Type=simple
WorkingDirectory=/home/ww/agent-qq
Environment=PYTHONUNBUFFERED=1
ExecStart=/home/ww/agent-qq/.venv/bin/python /home/ww/agent-qq/bot.py
Restart=always
RestartSec=5
KillSignal=SIGINT
TimeoutStopSec=30

[Install]
WantedBy=default.target
```

启用并启动：

```bash
systemctl --user daemon-reload
systemctl --user enable agent-qq
systemctl --user start agent-qq
systemctl --user status agent-qq
```

### 4.4 运维命令

```bash
systemctl --user status agent-qq        # 查看状态
systemctl --user restart agent-qq       # 重启
systemctl --user stop agent-qq          # 停止
journalctl --user -u agent-qq -f        # 实时日志
```

---

## 五、方案 C：本地 Python 调试

```bash
cd /home/ww/agent-qq
source .venv/bin/activate

# 连通性预检
python scripts/check_onebot.py --url ws://127.0.0.1:3001

# 前台运行
python bot.py
```

---

## 六、v2.0.1 新增配置项

```env
# Plan 状态机
PLAN_HISTORY_MAX=50              # plan_history.json 最大条数
PLAN_DATA_DIR=data               # 数据目录
PLAN_STATUS_LOG_MAX_AGE_HOURS=24 # 终态日志保留时长

# 熔断器
CIRCUIT_BREAKER_ENABLED=true
CIRCUIT_BREAKER_MAX_RETRIES=3
CIRCUIT_BREAKER_TASK_TIMEOUT_MINUTES=30

# 后台监控
MONITOR_ENABLED=true
MONITOR_POLL_INTERVAL_SECONDS=5
```

---

## 七、部署后验证

| 检查项 | 命令/操作 | 预期结果 |
|--------|----------|---------|
| 服务运行 | `systemctl --user status agent-qq` | active (running) |
| 启动日志 | `journalctl --user -u agent-qq -n 10` | TaskMonitor started + Connected to OneBot |
| QQ 心跳 | 私聊 `/ping` | pong + 时间 + 任务数 |
| QQ 帮助 | 私聊 `/help` | 命令列表（无 /ask /code） |
| Plan 流程 | 私聊 `/plan 你好` → `/plan-status` → `/plan-cancel` | 完整生命周期 |
| 网络测试 | 私聊 `/network` | 优/良/差 |
| 未知拦截 | 私聊 `你好` | "未知指令…" |
| 通知测试 | `python scripts/claude_notify_hook.py send "测试"` | 管理员 QQ 收到 |

---

## 八、Claude Code Hook QQ 通知

### 8.1 启用通知

`.env` 确认：

```env
CLAUDE_NOTIFY_ENABLED=true
CLAUDE_NOTIFY_QQ_IDS=（留空则使用 ADMIN_QQ_IDS）
```

### 8.2 配置 Hook

在 Claude Code 的 `~/.claude/settings.json` 或 Hook 配置中添加（使用绝对路径 + 容错后缀）：

```bash
/opt/agent-qq/scripts/claude_notify_hook.py start 2>/dev/null || true
/opt/agent-qq/scripts/claude_notify_hook.py stage 2>/dev/null || true
/opt/agent-qq/scripts/claude_notify_hook.py success 2>/dev/null || true
/opt/agent-qq/scripts/claude_notify_hook.py failure 2>/dev/null || true
/opt/agent-qq/scripts/claude_notify_hook.py stop 2>/dev/null || true
```

### 8.3 手动测试

```bash
cd /home/ww/agent-qq
.venv/bin/python scripts/claude_notify_hook.py send "【Claude】部署完成测试"
```

---

## 九、故障排查速查

| 症状 | 排查方向 |
|------|---------|
| OneBot 连接失败 | NapCat 是否登录？端口 3001 是否监听？ONEBOT_WS_URL 是否正确？ |
| Docker 连不上宿主机 | NapCat Host 是否设为 `0.0.0.0`？`.env` 是否用 `host.docker.internal`？ |
| /status 无回复 | 私聊？`ENABLE_PRIVATE_CHAT=true`？ |
| 收不到通知 | OneBot 连通？`ADMIN_QQ_IDS` 配置？Hook 路径正确？ |
| 通知太多 | 调大 `CLAUDE_NOTIFY_STAGE_COOLDOWN_SECONDS`、降低 `SESSION_BUDGET` |

---

## 十、更新与回滚

```bash
# 更新代码
cd /home/ww/agent-qq
git pull
systemctl --user restart agent-qq

# 回滚
git checkout <last_good_commit>
systemctl --user restart agent-qq
```

---

## 相关文档

- [v2.0.1 升级与测试报告](v2.0.1-upgrade-and-test.md)
- [完整 SOP（源码仓库）](https://github.com/stillness990/agent-qq/blob/main/docs/agent-qq-complete-sop.md)
