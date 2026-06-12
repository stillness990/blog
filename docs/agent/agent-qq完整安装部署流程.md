# agent-qq 完整安装部署流程

本文档由现有安装、Docker、NapCat、OneBot、Claude Code、FAQ、架构与接口说明合并整理而成，目标是形成一份可以直接按步骤实施的安装部署文档。

## 1. 项目概述

agent-qq 是一个通过 QQ 私聊接入 Claude Code CLI 的机器人网关。它本身不直接调用 Claude API，也不依赖 Anthropic SDK，而是通过本机或容器内的 `claude` 命令执行智能任务。

整体链路如下：

```text
QQ
→ NapCat QQ
→ OneBot v11 WebSocket
→ Python Gateway(agent-qq)
→ Claude Code CLI
→ 本机 Claude Code 配置中的模型
→ 返回结果到 QQ
```

核心设计原则：

1. Python 业务层不直接调用 Claude API。
2. 智能能力统一通过 Claude Code CLI 执行。
3. 不在 `.env` 或 Python 业务代码中保存 Anthropic API Key。
4. 不在业务层硬编码模型，模型选择由 Claude Code CLI 本机配置决定。
5. 高风险能力默认仅管理员可用。
6. OneBot WebSocket 连接具备自动重连能力。
7. 消息处理异步执行，避免阻塞 WebSocket 接收。

## 2. 部署前准备

### 2.1 基础环境

建议环境：

- Ubuntu 24.04 或其他 Linux 服务器
- Python 3.12
- Docker 与 Docker Compose
- Git
- Node.js/npm，容器内安装 Claude Code CLI 时需要
- NapCat QQ
- 已登录并配置完成的 Claude Code CLI

### 2.2 组件职责

| 组件 | 作用 |
|---|---|
| QQ | 用户通过私聊发送命令 |
| NapCat QQ | 登录机器人 QQ，并提供 OneBot v11 WebSocket 服务 |
| OneBot v11 | QQ 与 agent-qq 之间的协议层 |
| agent-qq | Python Gateway，负责连接、命令解析、权限控制、调用 Claude Code |
| Claude Code CLI | 实际执行 `/ask`、`/code` 等智能任务 |
| Docker Compose | 可选，用于容器化部署 agent-qq |

## 3. 获取项目

如果项目在 GitHub 上：

```bash
git clone https://github.com/<your-github-user>/agent-qq.git
cd agent-qq
```

如果已经是本地目录，直接进入项目根目录：

```bash
cd /path/to/agent-qq
```

后续所有命令默认都在项目根目录执行。

## 4. 配置 NapCat QQ

### 4.1 安装并登录 NapCat QQ

按 NapCat 官方文档安装 NapCat QQ，并使用机器人 QQ 账号登录。

### 4.2 启用 OneBot v11 WebSocket

在 NapCat 配置中启用 OneBot v11 WebSocket 服务。

推荐配置：

```text
Host: 0.0.0.0
Port: 3001
Access Token: 可选
```

说明：

- `Host=0.0.0.0` 便于 Docker 容器访问宿主机上的 NapCat。
- `Port=3001` 是本文档统一使用的示例端口。
- 如果配置了 `Access Token`，agent-qq 的 `.env` 中必须同步填写同一个 token。

## 5. 配置 OneBot 连接

agent-qq 通过 WebSocket 连接 NapCat 提供的 OneBot v11 服务。

### 5.1 宿主机运行 agent-qq

如果 agent-qq 直接在宿主机运行，`.env` 中使用：

```env
ONEBOT_WS_URL=ws://127.0.0.1:3001
```

### 5.2 Docker 容器运行 agent-qq

如果 agent-qq 在 Docker 容器中运行，容器访问宿主机 NapCat 通常使用：

```env
ONEBOT_WS_URL=ws://host.docker.internal:3001
```

### 5.3 Access Token

如果 NapCat OneBot 配置中设置了 access token，`.env` 中同步填写：

```env
ONEBOT_ACCESS_TOKEN=你的token
```

如果 NapCat 未设置 token，可以留空：

```env
ONEBOT_ACCESS_TOKEN=
```

### 5.4 当前支持的 OneBot 能力

当前版本处理的事件：

- `post_type=message`
- `message_type=private`

即仅处理 QQ 私聊消息。

当前版本调用的动作：

- `send_private_msg`

用于向用户发送 QQ 私聊回复。

OneBot 文本消息示例：

```json
{
  "type": "text",
  "data": {
    "text": "/ask 你好"
  }
}
```

## 6. 准备 Claude Code CLI

### 6.1 宿主机检查

在宿主机执行：

```bash
claude --version
claude -p "你好"
```

如果能正常输出版本号并返回回答，说明宿主机 Claude Code CLI 可用。

### 6.2 Claude Code 相关配置项

`.env` 中建议配置：

```env
CLAUDE_CLI_COMMAND=claude
CLAUDE_TIMEOUT_SECONDS=180
CLAUDE_WORKDIR=/workspace
CLAUDE_CONFIG_DIR=/path/to/.claude
```

字段说明：

| 配置项 | 示例 | 说明 |
|---|---|---|
| `CLAUDE_CLI_COMMAND` | `claude` | agent-qq 调用的 Claude Code CLI 命令 |
| `CLAUDE_TIMEOUT_SECONDS` | `180` | 单次 Claude 调用超时时间，单位秒 |
| `CLAUDE_WORKDIR` | `/workspace` | Claude Code 执行任务时的工作目录 |
| `CLAUDE_CONFIG_DIR` | `/home/your-user/.claude` | 宿主机 Claude Code 配置目录，Docker 部署时会挂载到容器 |

### 6.3 Docker 内使用 Claude Code CLI

Dockerfile 中需要安装 Claude Code CLI：

```dockerfile
RUN npm install -g @anthropic-ai/claude-code
```

Docker Compose 中需要挂载宿主机 Claude Code 配置：

```yaml
${CLAUDE_CONFIG_DIR:-$HOME/.claude}:/root/.claude:ro
```

该挂载建议保持只读 `:ro`，避免容器修改宿主机 Claude Code 配置。

### 6.4 安全边界

- 不在 Python 业务层保存 Claude API Key。
- 不在 `.env` 中配置 Anthropic API Key。
- 不从业务层选择或硬编码模型。
- 模型、账号、认证状态由宿主机 Claude Code CLI 配置决定。
- Docker 部署时仅挂载 Claude Code 配置目录，不额外写入密钥。

## 7. 配置 agent-qq 环境变量

复制环境变量模板：

```bash
cp .env.example .env
nano .env
```

如果项目中没有 `.env.example`，可以手动创建 `.env`，按下面内容填写。

### 7.1 Docker 部署推荐配置

```env
ONEBOT_WS_URL=ws://host.docker.internal:3001
ONEBOT_ACCESS_TOKEN=
ADMIN_QQ_IDS=你的QQ号

CLAUDE_CONFIG_DIR=/home/your-user/.claude
CLAUDE_CLI_COMMAND=claude
CLAUDE_TIMEOUT_SECONDS=180
CLAUDE_WORKDIR=/workspace

SHELL_ALLOWED_PREFIXES=pwd,ls,git status
```

### 7.2 宿主机本地运行推荐配置

```env
ONEBOT_WS_URL=ws://127.0.0.1:3001
ONEBOT_ACCESS_TOKEN=
ADMIN_QQ_IDS=你的QQ号

CLAUDE_CONFIG_DIR=/home/your-user/.claude
CLAUDE_CLI_COMMAND=claude
CLAUDE_TIMEOUT_SECONDS=180
CLAUDE_WORKDIR=/path/to/agent-qq

SHELL_ALLOWED_PREFIXES=pwd,ls,git status
```

### 7.3 关键变量说明

| 配置项 | 是否必填 | 说明 |
|---|---:|---|
| `ONEBOT_WS_URL` | 是 | NapCat OneBot v11 WebSocket 地址 |
| `ONEBOT_ACCESS_TOKEN` | 否 | NapCat 配置了 token 时必填，否则留空 |
| `ADMIN_QQ_IDS` | 建议填写 | 管理员 QQ 号，多个可按项目支持的格式填写 |
| `CLAUDE_CONFIG_DIR` | Docker 部署必填 | 宿主机 Claude Code 配置目录 |
| `CLAUDE_CLI_COMMAND` | 建议填写 | Claude Code CLI 命令，通常为 `claude` |
| `CLAUDE_TIMEOUT_SECONDS` | 建议填写 | Claude Code 调用超时时间 |
| `CLAUDE_WORKDIR` | 建议填写 | Claude Code 执行任务的工作目录 |
| `SHELL_ALLOWED_PREFIXES` | 使用 `/shell` 时需要 | `/shell` 命令允许执行的命令前缀白名单 |

## 8. 本地运行流程

适合开发调试或不希望使用 Docker 的场景。

### 8.1 创建虚拟环境并安装依赖

```bash
python3 -m venv .venv
source .venv/bin/activate
pip install -r requirements.txt
```

### 8.2 确认本地 OneBot 地址

本地运行时，`.env` 中一般配置：

```env
ONEBOT_WS_URL=ws://127.0.0.1:3001
```

### 8.3 启动服务

```bash
python bot.py
```

启动后观察控制台日志，确认已连接到 NapCat OneBot WebSocket。

### 8.4 本地运行检查点

依次确认：

1. NapCat QQ 已登录。
2. NapCat OneBot v11 WebSocket 已启动。
3. `.env` 中的 `ONEBOT_WS_URL` 端口与 NapCat 端口一致。
4. 宿主机执行 `claude -p "你好"` 正常。
5. `ADMIN_QQ_IDS` 已配置为你的 QQ 号。
6. 向机器人 QQ 私聊 `/status` 能收到回复。

## 9. Docker 部署流程

适合服务器长期运行。

### 9.1 确认 Docker Compose 配置

Docker Compose 需要包含以下关键能力：

1. 构建并运行 agent-qq 容器。
2. 挂载宿主机 Claude Code 配置目录到容器内 `/root/.claude:ro`。
3. 让容器能够访问宿主机 NapCat 的 `3001` 端口。

Claude Code 配置挂载示例：

```yaml
${CLAUDE_CONFIG_DIR:-$HOME/.claude}:/root/.claude:ro
```

### 9.2 构建镜像

```bash
docker compose build
```

### 9.3 启动服务

```bash
docker compose up -d
```

也可以一条命令构建并启动：

```bash
docker compose up -d --build
```

### 9.4 查看服务状态

```bash
docker compose ps
```

### 9.5 查看日志

```bash
docker compose logs -f agent-qq
```

也可以查看项目日志文件：

```text
logs/agent-qq.log
```

### 9.6 重启服务

```bash
docker compose restart agent-qq
```

### 9.7 停止服务

```bash
docker compose down
```

### 9.8 更新代码后重建

```bash
git pull
docker compose up -d --build
```

重建完成后查看日志：

```bash
docker compose logs -f agent-qq
```

## 10. 部署后验证

### 10.1 检查容器状态

```bash
docker compose ps
```

确认 `agent-qq` 服务处于运行状态。

### 10.2 检查日志

```bash
docker compose logs -f agent-qq
```

重点确认：

- 已读取 `.env` 配置。
- 已连接 OneBot WebSocket。
- 没有 Claude CLI 调用失败错误。
- 没有权限或配置目录挂载错误。

### 10.3 QQ 私聊测试

向机器人 QQ 私聊发送：

```text
/help
```

预期：返回可用命令帮助。

继续发送：

```text
/status
```

预期：返回运行状态，说明 QQ → NapCat → OneBot → agent-qq 链路正常。

继续发送：

```text
/ask 你好
```

预期：返回 Claude Code 生成的回答，说明 agent-qq → Claude Code CLI 链路正常。

## 11. 支持的 QQ 命令

| 命令 | 权限 | 说明 |
|---|---|---|
| `/help` | 所有人 | 查看帮助 |
| `/status` | 所有人 | 查看运行状态 |
| `/ask 文本` | 所有人 | 调用 Claude Code 回答问题 |
| `/log` | 管理员 | 查看日志位置 |
| `/shell 命令` | 管理员 | 执行白名单 Shell 命令 |
| `/code 需求` | 管理员 | 调用 Claude Code 执行代码任务 |

预留命令：

- `/search`
- `/agent`
- `/mcp`
- `/rag`
- `/workflow`

## 12. 安全与权限

### 12.1 管理员 QQ

将自己的 QQ 号配置到：

```env
ADMIN_QQ_IDS=你的QQ号
```

管理员命令包括但不限于：

- `/log`
- `/shell`
- `/code`

### 12.2 `/shell` 白名单

为了安全，`/shell` 仅允许管理员使用，并且只允许执行白名单命令前缀。

示例：

```env
SHELL_ALLOWED_PREFIXES=pwd,ls,git status
```

表示仅允许执行以 `pwd`、`ls`、`git status` 开头的命令。

生产环境建议：

- 不要将 `rm`、`curl`、`wget`、`ssh`、`scp`、`bash`、`sh` 等高风险命令加入白名单。
- 不要给普通用户开放 `/shell`。
- 管理员 QQ 号应只配置可信账号。

### 12.3 Claude Code 配置安全

Docker 部署时建议只读挂载：

```yaml
/root/.claude:ro
```

避免容器内程序修改宿主机 Claude Code 配置。

### 12.4 Git 推送安全

如果需要发布代码，可按以下流程：

```bash
git add .
git commit -m "chore: update agent-qq"
git push
```

生产环境不建议完全无确认自动推送高风险代码，至少保留测试通过后再推送的步骤。

## 13. 故障排查

### 13.1 OneBot 404 或连接失败

检查项：

1. NapCat QQ 是否已启动并登录。
2. OneBot v11 WebSocket 是否已启用。
3. NapCat 端口是否为 `3001`。
4. `.env` 中 `ONEBOT_WS_URL` 是否正确。

宿主机运行时：

```env
ONEBOT_WS_URL=ws://127.0.0.1:3001
```

Docker 运行时：

```env
ONEBOT_WS_URL=ws://host.docker.internal:3001
```

### 13.2 Docker 容器无法连接宿主机 NapCat

检查项：

1. NapCat OneBot 的 Host 是否为 `0.0.0.0`。
2. 端口是否开放。
3. `.env` 是否使用 `ws://host.docker.internal:3001`。
4. 如果当前 Linux Docker 环境不支持 `host.docker.internal`，需要在 `docker-compose.yml` 中增加对应 host 映射，或改用宿主机网关地址。

### 13.3 `/status` 没有回复

检查项：

1. 查看 agent-qq 日志。
2. 确认机器人 QQ 与发送消息的 QQ 是私聊关系。
3. 确认当前版本只处理私聊消息，不处理群聊消息。
4. 确认 OneBot 收到了 `message_type=private` 事件。

### 13.4 `/ask` 没有回复或超时

检查项：

1. 宿主机执行：

   ```bash
   claude -p "你好"
   ```

2. Docker 部署时确认容器内安装了 Claude Code CLI。
3. 确认 `.claude` 配置目录已正确挂载到容器。
4. 适当增大：

   ```env
   CLAUDE_TIMEOUT_SECONDS=180
   ```

### 13.5 Docker 里为什么也需要 Claude Code CLI

容器内运行 Python Gateway 时，agent-qq 需要能执行 `claude -p` 命令，因此 Dockerfile 需要安装 Claude Code CLI，并通过 Docker Compose 挂载宿主机 `.claude` 配置。

### 13.6 `/shell` 不能执行某些命令

这是安全限制。`/shell` 只允许管理员使用，并且命令必须匹配白名单前缀。

修改示例：

```env
SHELL_ALLOWED_PREFIXES=pwd,ls,git status
```

修改后重启服务：

```bash
docker compose restart agent-qq
```

### 13.7 如何查看日志

Docker 日志：

```bash
docker compose logs -f agent-qq
```

项目日志文件：

```text
logs/agent-qq.log
```

## 14. 模块说明

| 模块 | 说明 |
|---|---|
| `bot.py` | 主程序，负责连接、重连、事件循环和异步消息处理 |
| `config.py` | 读取 `.env` 配置 |
| `qq_client.py` | OneBot v11 WebSocket 客户端 |
| `claude_client.py` | Claude Code CLI 调用封装 |
| `command_router.py` | QQ 命令解析和路由 |
| `plugins/mcp/` | MCP 预留接口 |
| `plugins/rag/` | RAG 预留接口 |
| `agents/` | 多 Agent 预留接口 |
| `tests/` | 测试用例 |

## 15. 最小可执行部署清单

如果只需要快速部署，按以下顺序执行：

1. 安装并登录 NapCat QQ。
2. 在 NapCat 中启用 OneBot v11 WebSocket：

   ```text
   Host: 0.0.0.0
   Port: 3001
   ```

3. 确认宿主机 Claude Code CLI 可用：

   ```bash
   claude --version
   claude -p "你好"
   ```

4. 获取项目并进入目录：

   ```bash
   git clone https://github.com/<your-github-user>/agent-qq.git
   cd agent-qq
   ```

5. 创建 `.env`：

   ```bash
   cp .env.example .env
   nano .env
   ```

6. Docker 部署时填写：

   ```env
   ONEBOT_WS_URL=ws://host.docker.internal:3001
   ONEBOT_ACCESS_TOKEN=
   ADMIN_QQ_IDS=你的QQ号
   CLAUDE_CONFIG_DIR=/home/your-user/.claude
   CLAUDE_CLI_COMMAND=claude
   CLAUDE_TIMEOUT_SECONDS=180
   CLAUDE_WORKDIR=/workspace
   SHELL_ALLOWED_PREFIXES=pwd,ls,git status
   ```

7. 启动服务：

   ```bash
   docker compose up -d --build
   ```

8. 查看日志：

   ```bash
   docker compose logs -f agent-qq
   ```

9. 向机器人 QQ 私聊测试：

   ```text
   /help
   /status
   /ask 你好
   ```

如果 `/status` 和 `/ask` 都能正常返回，则部署完成。
