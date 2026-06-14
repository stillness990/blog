# agent-qq — QQ 私聊 AI Agent 网关

**版本：** v2.0.1 | **架构：** 纯指令驱动 | **AI 原则：** 仅 /plan 可调 AI

## 项目简介

`agent-qq` 是一个基于 NapCat QQ + OneBot v11 + Claude Code CLI 的 QQ 私聊 AI Agent 网关。用户通过 QQ 发送指令，机器人解析执行并返回结果。

**核心特性：**
- **零 Token 消耗**：除 `/plan [自然语言]` 外，所有命令均为纯脚本/子进程执行
- **Plan 状态机**：完整的 5 步生命周期（创建→查看→确认→取消→日志）
- **异常熔断**：Token 耗尽/网络异常/超时自动检测 + QQ 通知 + 状态回滚
- **后台监控**：独立于 AI 的纯脚本巡检，每 5s 轮询
- **QQ 通知**：Claude Code Hook 行内通知系统，支持阶段/心跳/完成推送

## 项目文档

| 文档 | 说明 |
|------|------|
| [部署指南](deployment-guide.md) | 完整部署流程（Docker / systemd / 本地） |
| [v2.0.1 升级与测试报告](v2.0.1-upgrade-and-test.md) | 全生命周期追踪：升级 + 测试 |

## 快速开始

```bash
# 查看状态
systemctl --user status agent-qq

# QQ 私聊发送
/ping     → 心跳检测
/help     → 命令列表
/plan 写一个脚本  → AI 生成大纲
```

## 技术栈

| 层 | 技术 |
|----|------|
| QQ 协议 | NapCat QQ |
| 消息协议 | OneBot v11 WebSocket |
| 业务逻辑 | Python 3.11+ asyncio |
| AI 引擎 | Claude Code CLI |
| 部署 | Docker Compose / systemd |
| 文档 | MkDocs Material |
