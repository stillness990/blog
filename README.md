# 王伟的技术博客与知识库

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
