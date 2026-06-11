# ww的技术博客与知识库

这是一个基于 [MkDocs Material](https://squidfunk.github.io/mkdocs-material/) 构建的个人官网、技术博客、学习笔记、知识库和项目展示平台。

## 内容方向

- AI Agent
- Claude Code
- OpenAI Codex
- Python 开发
- FastAPI
- Linux
- Android 开发
- 自动化工具
- 项目实战记录

## 本地预览

如果系统缺少 Python 虚拟环境支持，请先安装：

```bash
sudo apt-get install python3-venv python3-pip
```

然后启动本地预览：

```bash
python3 -m venv .venv
source .venv/bin/activate
pip install -r requirements.txt
mkdocs serve
```

访问：

```text
http://127.0.0.1:8000
```

## 构建

```bash
mkdocs build --strict
```

## 部署

推送到 GitHub 后，GitHub Actions 会自动构建并部署到 GitHub Pages。

默认站点地址：

```text
https://stillness990.github.io/blog/
```

如果使用 Cloudflare 自定义域名，请在 `mkdocs.yml` 中把 `site_url` 改为你的正式域名。

## 本地自动同步（可选）

启用后，本地文档变更会在 1 分钟内自动提交并推送到 GitHub，触发 GitHub Actions 自动更新网站。

### 使用 systemd（推荐，开机自启）

```bash
./scripts/install-auto-sync.sh
systemctl --user start blog-auto-sync
```

### 直接运行（前台进程）

```bash
./scripts/auto-sync.sh
```

脚本支持以下环境变量：

| 变量 | 默认值 | 说明 |
|------|--------|------|
| `BLOG_SYNC_INTERVAL_SECONDS` | `60` | 检测间隔（秒） |
| `BLOG_SYNC_DEBOUNCE_SECONDS` | `10` | 变化后等待合并连续修改（秒） |
| `BLOG_SYNC_COMMIT_PREFIX` | `Update blog content` | 提交信息前缀 |
| `BLOG_SYNC_LOG_FILE` | `.auto-sync.log` | 日志文件路径 |
