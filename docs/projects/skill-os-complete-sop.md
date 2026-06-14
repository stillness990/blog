# skill-os-complete

**Claude Code 自动技能路由系统** — 零延迟、纯本地、关键字驱动的技能自动注入引擎。

在 Claude Code 中输入文字时，Hook 自动分析内容并注入对应技能指令，让 Claude 按预定义规范回答。无需切换模式、无需手动选择技能。

## 工作原理

```text
你在 Claude Code 中输入文字
  ↓
UserPromptSubmit Hook 触发
  ↓
skill-router.py 读取输入 → 对照 skill-rules.json 打分
  ↓
选中得分最高的技能 → 自动注入 SKILL.md 规范
  ↓
Claude 按规范回答（无命中则正常对话）
```

## 快速安装

```bash
# 1. 克隆项目
git clone https://github.com/stillness990/skill-os-complete.git

# 2. 进入你的项目目录
cd /path/to/your-project

# 3. 运行安装脚本
bash /path/to/skill-os-complete/install.sh
```

安装脚本自动完成：
- 复制 `.claude/` 到项目目录
- 设置执行权限
- 验证 JSON 格式
- 运行 6 项路由测试

## 内置技能（6 个）

| 技能 | 优先级 | 触发方式 | 作用 |
|------|--------|---------|------|
| `echo` | 1 | `echo xxx`、`重复`、`原样` | 原样返回输入，调试验证 |
| `summarize` | 2 | `总结`、`摘要`、`概括`、`summarize` | 提炼 3~7 条核心要点 + 一句话总结 |
| `code_assistant` | 3 | `debug`、`bug`、`修复`、`实现`、`报错` | 结构化输出：问题分析 → 代码 → 说明 |
| `sop` | 2 | `写手册`、`怎么处理`、`SOP`、`操作手册` | 生成标准操作步骤（步骤 + 预期 + 分支） |
| `debug_log` | 2 | `解决了`、`留档`、`排查记录` | 自动生成 `debug-logs/` 目录 + `.md` 文件 |
| `sanitize` | 2 | `脱敏`、`消毒`、`sanitize`、`安全发布` | 扫描替换敏感信息 + 一键发布到 GitHub |

## 使用方式

### 触发技能

输入中自然包含关键词即可，无需特殊前缀：

| 你想做的事 | 这样说 |
|-----------|--------|
| 原样输出 | `echo 这段配置内容原样输出` |
| 总结文章 | `总结一下这篇文章的核心内容` |
| 修复代码 | `帮我 debug 这段代码，一直报 KeyError` |
| 写操作手册 | `数据库连接失败怎么处理，帮我写操作手册` |
| debug 留档 | `问题解决了，帮我记录这次排查过程留档` |
| 项目脱敏 | `帮我对这个项目做脱敏处理，准备发布` |
| 正常聊天 | `今天天气怎么样`（不触发任何技能） |

### 验证系统正常

依次输入以下 6 句话，确认各自触发正确技能：

1. `echo 测试` → 原样返回
2. `总结一下今天的对话` → 要点格式
3. `帮我 debug 这段代码` → 结构化回答
4. `帮我写一份数据库备份的操作手册` → SOP 格式
5. `问题解决了，帮我记录排查过程` → 生成文件
6. `帮我对这个项目做脱敏处理` → sanitize 格式

## 添加新技能

### 第一步：创建技能定义

```bash
mkdir -p .claude/skills/<新技能名>
```

创建 `.claude/skills/<新技能名>/SKILL.md`：

```markdown
---
name: <技能名>
description: "<一句话描述>"
---

# <技能名> Skill

## 用途
…

## 行为规则
- …
- …

## 输出格式
…
```

参考模板：`.claude/skills/sop/SKILL.md`

### 第二步：注册路由规则

打开 `.claude/skill-rules.json`，在 `"skills"` 对象中添加：

```json
"<新技能名>": {
  "priority": 2,
  "keywords": ["关键词1", "关键词2"],
  "intentPatterns": [
    "(正则模式1)"
  ]
}
```

### 第三步：验证并测试

```bash
# 验证 JSON 格式
python3 -c "import json; json.load(open('.claude/skill-rules.json'))"

# 测试路由
echo '{"prompt": "你的测试输入"}' \
  | CLAUDE_PROJECT_DIR="$(pwd)" python3 .claude/hooks/skill-router.py
```

**不需要重启 Claude Code，保存文件立即生效。**

## 打分规则

| 匹配方式 | 得分 | 说明 |
|---------|------|------|
| 基础优先级 | `priority` 字段值 | 仅兜底，**不算命中** |
| 关键词命中 | 每个 +2 | `keywords` 列表匹配 |
| 正则命中 | 每个 +3 | `intentPatterns` 列表匹配 |

> 必须有关键词或正则命中（得分 > 基础分），技能才会触发。

## 故障排查

### 技能完全不触发

```bash
echo '{"prompt": "帮我 debug 这段代码"}' \
  | CLAUDE_PROJECT_DIR="$(pwd)" python3 .claude/hooks/skill-router.py
```

预期输出中包含 `"code_assistant"` 和 `"prompt_injection"`。

如果输出 `{}`，逐项检查：

| 检查项 | 命令 | 预期 |
|--------|------|------|
| skill-rules.json 存在 | `ls .claude/skill-rules.json` | 文件存在 |
| JSON 格式正确 | `python3 -c "import json; json.load(open('.claude/skill-rules.json')); print('OK')"` | `OK` |
| python3 可用 | `which python3` | 路径非空 |
| 输入包含关键词 | 检查 `skill-rules.json` 的 `keywords` | 至少命中一个 |

### 多个技能竞争选错了

```bash
echo '{"prompt": "你的原话"}' \
  | CLAUDE_PROJECT_DIR="$(pwd)" python3 .claude/hooks/skill-router.py
```

处理方法：
- A：给期望技能加独特关键词
- B：降低冲突技能的 `priority`
- C：给期望技能加精准的 `intentPatterns` 正则

### 误触发（不该触发时触发了）

找到被误触发的技能，检查 `keywords` 列表。删除过于宽泛的关键词，改用更精确的正则。

### JSON 格式损坏

```bash
python3 -c "import json; json.load(open('.claude/settings.json'))"
```

根据报错行号修正。如果完全损坏，从备份恢复：

```bash
ls .claude/backups/
cp .claude/backups/<最新备份> .claude/settings.json
```

## 常见错误速查

| 现象 | 原因 | 处理 |
|------|------|------|
| 技能不触发，输出 `{}` | 输入未匹配任何关键词 | 检查输入是否包含 `skill-rules.json` 中的关键词 |
| `settings.json` 报错 | JSON 格式损坏 | `python3 -c "import json; json.load(...)"` 定位语法错误 |
| `skill-router.py` 报 `No such file` | Hook 路径不对 | 确认 `UserPromptSubmit` 中 command 正确 |
| 新增技能不生效 | 文件名或路径不对 | 确认目录名与 `skill-rules.json` 的 key 一致 |
| QQ 通知 Hook 丢失 | 修改 settings.json 时覆盖了原有 hooks | 检查 `UserPromptSubmit` 中是否保留了 QQ 通知 hook |

## 备份与恢复

settings.json 有自动备份：

```bash
ls .claude/backups/
```

恢复：

```bash
cp .claude/backups/.claude.json.backup.<最新时间戳> .claude/settings.json
```

## 回滚/卸载

**仅禁用技能路由：** 删除 `UserPromptSubmit` 中 skill-router 对应的 hook。

**完全移除：**

```bash
rm .claude/skill-rules.json
rm .claude/hooks/skill-router.py
rm -rf .claude/skills
```

然后手动编辑 `settings.json`，移除 skill-router 对应的 hook 条目。

## 项目结构

```text
skill-os-complete/
├── CLAUDE.md                           # 项目说明
├── install.sh                          # 一键安装脚本
├── .gitignore
├── docs/
│   └── skill-os-complete-sop.md        # 完整操作手册
└── .claude/
    ├── settings.json                   # Hook 注册入口
    ├── skill-rules.json                # 路由关键词规则
    ├── hooks/
    │   └── skill-router.py             # 自动路由脚本
    └── skills/
        ├── echo/SKILL.md
        ├── summarize/SKILL.md
        ├── code_assistant/SKILL.md
        ├── sop/SKILL.md
        ├── debug_log/SKILL.md
        └── sanitize/
            ├── SKILL.md
            └── sanitize.py             # 脱敏扫描与发布脚本
```

## License

MIT
