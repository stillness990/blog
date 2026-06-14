# SOP：skill-os-complete 技能路由系统

| 字段 | 内容 |
|---|---|
| 文档类型 | SOP / 操作手册 |
| 生成时间 | 2026-06-14 |
| 适用系统 | skill-os-complete |
| 安装位置 | `<项目根目录>/.claude/` |
| 核心组件 | `skill-router.py`、`skill-rules.json`、`settings.json`、5 个技能定义文件 |
| 适用场景 | 首次安装后日常使用、添加新技能、故障排查 |

---

## 1. 系统架构

### 1.1 工作原理

```text
你在 Claude Code 中输入文字
  ↓
UserPromptSubmit Hook 触发
  ↓
skill-router.py 读取输入
  ↓
对照 skill-rules.json 中的关键词和正则打分
  ↓
得分最高且有关键词命中的技能被选中
  ↓
自动注入技能指令，Claude 按该技能的 SKILL.md 规范回答
  ↓
（无命中）不注入，正常对话
```

### 1.2 打分规则

| 匹配方式 | 得分 | 说明 |
|---|---|---|
| 基础优先级 | `priority` 字段值 | 仅兜底，**不算命中** |
| 关键词命中 | 每个 +2 | `keywords` 列表匹配 |
| 正则命中 | 每个 +3 | `intentPatterns` 列表匹配 |

> 必须有关键词或正则命中（得分 > 基础分），技能才会触发。纯靠基础分不会触发。

### 1.3 关键文件

| 文件 | 用途 |
|---|---|
| `.claude/settings.json` | Hook 注册入口（UserPromptSubmit 含 skill-router） |
| `.claude/skill-rules.json` | 路由关键词规则，定义每个技能的匹配方式 |
| `.claude/hooks/skill-router.py` | 自动路由脚本，打分并注入技能指令 |
| `.claude/skills/<技能名>/SKILL.md` | 各技能的行为规范定义 |
| `CLAUDE.md` | 项目说明，列出可用技能 |

---

## 2. 可用技能一览

| 技能 | 优先级 | 触发方式（示例） | 效果 |
|---|---|---|---|
| `echo` | 1 | `echo xxx`、`重复`、`原样` | 原样返回输入，用于调试验证 |
| `summarize` | 2 | `总结`、`摘要`、`概括`、`summarize` | 长内容压缩为 3~7 条核心要点 + 一句话总结 |
| `code_assistant` | 3 | `debug`、`bug`、`修复代码`、`报错`、`实现` | 结构化输出：问题分析 → 修复代码 → 说明 |
| `sop` | 2 | `写手册`、`怎么处理`、`操作手册`、`SOP` | 生成标准操作步骤（步骤 + 预期 + 分支判断） |
| `debug_log` | 2 | `解决了`、`留档`、`排查记录`、`保存记录` | 自动生成 `debug-logs/YYYY-MM-DD_关键词.md` 文件 |

---

## 3. 日常使用

### 3.1 触发技能

在输入中自然包含关键词，技能自动匹配：

| 你想做的事 | 这样说 |
|---|---|
| 原样重复 | `echo 这段配置内容原样输出` |
| 总结文章 | `总结一下这篇文章的核心内容` |
| 修复代码 | `帮我 debug 这段代码，一直报 KeyError` |
| 写操作手册 | `数据库连接失败怎么处理，帮我写操作手册` |
| debug 留档 | `问题解决了，帮我记录这次排查过程留档` |
| 正常聊天 | `今天天气怎么样`（不触发任何技能） |

### 3.2 验证系统正常

依次输入以下 5 句话，确认各自触发正确技能：

1. `echo 测试` → 原样返回
2. `总结一下今天的对话` → 要点格式输出
3. `帮我 debug 这段代码` → 问题分析 / 修复 / 说明格式
4. `帮我写一份数据库备份的操作手册` → SOP 格式输出
5. `问题解决了，帮我记录排查过程` → 自动生成 `debug-logs/` 目录和 `.md` 文件

---

## 4. 添加新技能

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

**参考模板：** `.claude/skills/sop/SKILL.md`

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

### 第三步：验证 JSON 格式

```bash
python3 -c "import json; json.load(open('.claude/skill-rules.json'))"
```

**预期：** 命令无输出 = 格式正确。

### 第四步：测试路由

```bash
echo '{"prompt": "你的测试输入"}' \
  | CLAUDE_PROJECT_DIR="$(pwd)" python3 .claude/hooks/skill-router.py
```

**预期：** 输出 JSON 中 `prompt_injection` 包含新技能名。

**不需要重启 Claude Code，保存文件立即生效。**

---

## 5. 故障排查

### 5.1 技能完全不触发

**操作：**

```bash
echo '{"prompt": "帮我 debug 这段代码"}' \
  | CLAUDE_PROJECT_DIR="$(pwd)" python3 .claude/hooks/skill-router.py
```

**预期：** 输出中包含 `"code_assistant"` 和 `"prompt_injection"`。

**如果输出 `{}`，逐项检查：**

| 检查项 | 命令 | 预期 |
|---|---|---|
| skill-router hook 已注册 | `python3 -c "import json; s=json.load(open('.claude/settings.json')); hooks=s.get('hooks',{}).get('UserPromptSubmit',[]); print('OK' if any('skill-router' in h.get('command','') for g in hooks for h in g.get('hooks',[])) else 'MISSING')"` | `OK` |
| skill-rules.json 存在 | `ls -la .claude/skill-rules.json` | 文件存在 |
| JSON 格式正确 | `python3 -c "import json; json.load(open('.claude/skill-rules.json')); print('OK')"` | `OK` |
| python3 可用 | `which python3` | 路径非空 |

### 5.2 误触发——不该触发时触发了

打开 `.claude/skill-rules.json`，找到被误触发的技能，检查 `keywords` 列表。

**典型场景：** "这个 bug 很有意思"只是闲聊，但 `bug` 命中了 `code_assistant`。

**处理：**
- 从 `keywords` 删除过于宽泛的词
- 改用更精确的 `intentPatterns` 正则（比如要求同时出现"修复"或"debug"）

### 5.3 多个技能竞争，选错了

**手动测试看打分：**

```bash
echo '{"prompt": "你的原话"}' \
  | CLAUDE_PROJECT_DIR="$(pwd)" python3 .claude/hooks/skill-router.py
```

**处理：**
- 方法 A：给期望技能加独特关键词，输入时带上
- 方法 B：降低冲突技能的 `priority`
- 方法 C：给期望技能加精准的 `intentPatterns`

### 5.4 `settings.json` 修改后 Claude Code 报错

JSON 格式损坏（多了逗号、少了引号）。

**修复：**

```bash
python3 -c "import json; json.load(open('.claude/settings.json'))"
```

根据报错行号定位并修正。如果完全损坏，从备份恢复：

```bash
ls .claude/backups/
cp .claude/backups/<最新备份> .claude/settings.json
```

---

## 6. 常见错误

| 错误现象 | 原因 | 处理方法 |
|---|---|---|
| 技能不触发，输出 `{}` | 输入未匹配任何关键词或正则 | 检查输入是否包含 `skill-rules.json` 中定义的关键词 |
| `settings.json` 报错 | JSON 格式损坏 | `python3 -c "import json; json.load(...)"` 定位语法错误 |
| `skill-router.py` 报 `No such file` | Hook 命令路径不对 | 确认 `UserPromptSubmit` 中 command 为 `python3 $CLAUDE_PROJECT_DIR/.claude/hooks/skill-router.py` |
| `python3: command not found` | 系统未装 python3 | `which python3`，如果用的是 `python` 则修改 settings.json 中的命令 |
| 新增技能不生效 | 文件名或路径不对 | 确认 `SKILL.md` 在 `.claude/skills/<技能名>/` 下，且目录名与 `skill-rules.json` 的 key 一致 |
| `debug_log` 没生成文件 | `debug-logs/` 目录创建失败 | 手动创建：`mkdir -p debug-logs` |
| 多个 hook 冲突 | 修改 settings.json 时覆盖了原有 hooks | 修改前先 `diff` 确认变更范围，确保其他 hook 条目未被删除 |

---

## 7. 配置管理

### 7.1 settings.json Hook 最小结构

`.claude/settings.json` 中 `UserPromptSubmit` 的 skill-router hook 结构：

```json
"UserPromptSubmit": [
  {
    "hooks": [
      {
        "command": "python3 $CLAUDE_PROJECT_DIR/.claude/hooks/skill-router.py",
        "type": "command"
      }
    ]
  }
]
```

如果你有其他 hook（如通知、日志等），将 skill-router 追加到同一个 hooks 数组中，不要覆盖原有条目。

### 7.2 备份与恢复

settings.json 有自动备份：

```bash
ls .claude/backups/
```

恢复：

```bash
cp .claude/backups/.claude.json.backup.<最新时间戳> .claude/settings.json
```

### 7.3 回滚技能路由

**禁用技能路由：**

删除 `UserPromptSubmit` 中 skill-router 对应的那条 hook。

**完全移除：**

```bash
rm .claude/skill-rules.json
rm .claude/hooks/skill-router.py
rm -rf .claude/skills
```

然后手动编辑 `settings.json`，移除 skill-router 对应的 hook 条目。

---

## 8. 最后验证

全部配置完成后，依次执行：

1. 路由功能测试（5 项）：

```bash
run_test() { local d="$1" p="$2" e="$3"; R=$(echo "{\"prompt\":\"$p\"}" | CLAUDE_PROJECT_DIR="$(pwd)" python3 .claude/hooks/skill-router.py 2>&1); if echo "$R" | grep -q "$e"; then echo "  ✓ $d"; else echo "  ✗ $d -> $R"; fi; }
run_test "echo"      "echo 测试"                                    "echo"
run_test "summarize" "总结一下"                                     "summarize"
run_test "code"      "帮我 debug 这段代码"                          "code_assistant"
run_test "sop"       "数据库连接失败怎么处理"                       "sop"
run_test "debug_log" "问题解决了请帮我记录"                         "debug_log"
```

预期：5 项全部 `✓`。

2. JSON 格式验证：

```bash
python3 -c "import json; json.load(open('.claude/settings.json')); print('settings.json OK')"
python3 -c "import json; json.load(open('.claude/skill-rules.json')); print('skill-rules.json OK')"
```

预期：两行 `OK`。

---

## 9. 标签

`skill-os-complete` `技能路由` `ClaudeCode` `Hook` `SOP` `skill-router` `故障排查` `配置管理`
