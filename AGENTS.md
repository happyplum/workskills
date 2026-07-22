# 项目知识库


## 概述

oh-my-opencode 多智能体系统的自定义 Skill 仓库。每个 skill 是独立目录，包含 SKILL.md 定义文件。纯文档项目，无构建/测试/CI。

## 结构

```
skills/
├── README.md                        # 项目总览 + 分类索引 + 依赖关系图
├── interrupted-subagent-recovery/   # Global: 子代理中断恢复
├── agent-browser-windows/            # Global: Windows 浏览器自动化治理
├── long-running-process/            # Global: Windows 长运行进程治理
├── omo-adaptive-execution/          # Core: OMO 执行与路由
├── opencode-subagent-log-triage/    # Global: OpenCode 子代理日志排查
├── serena-first-codework/            # Core: Serena 优先代码语义工作
└── omo-atlas-execution-constraints/ # Execution: OMO Atlas 治理
```

> OMO 执行规则维护在 `omo-adaptive-execution/SKILL.md`，路由策略维护在同目录 `routing.md`；其它 prompt 和治理 skill 不复制两者内容。

## 约定

> **详细设计参照见 [`docs/skill-design-guide.md`](docs/skill-design-guide.md)**（渐进式披露分层、description 写法、长度红线与拆分信号、脚本化原则、反模式清单、本仓库 skill 现状速查）。维护任何 skill 前先读。

### SKILL.md 结构（按渐进式披露分层）

详细分层与设计原则以 [`docs/skill-design-guide.md`](docs/skill-design-guide.md) 为权威参照；本节仅给出快速约束。

| 层 | 位置 | 内容 |
|---|---|---|
| **L0 触发** | frontmatter `description` | 「当……时使用」格式的触发条件 + 触发词；纯触发，**不写工作流/能力清单** |
| **L1 规范** | SKILL.md 正文 | 概述、强制规则、决策树、反例；**不写触发词或加载条件** |
| **L2 详情** | `references/*.md` | 仅域知识密集型 skill 需要，按正文显式指令加载 |
| **L3 执行** | `scripts/*`、`assets/*` | 确定性脚本/模板，执行不进 context |

**Frontmatter 约束**：仅 `name` + `description` 两个字段；`name` 仅字母/数字/连字符；Frontmatter 总长 ≤1024 字符；`description` 中文。

**正文常用章节**：`## 概述` / `## 强制规则` / `## 反例`。

> **触发词归 L0，不进正文**：触发词属于 `description`（始终全量注入），不应在正文以章节形式重复——重复既浪费 L1 加载成本，也与 L0 触发器职责冲突。

### 外部 skill 触发边界
- 特殊执行方式由外部 skill 的 description 自行触发；本地 prompt 和治理 skill 不重复枚举或强绑外部执行 skill。

### 手动触发 skill 约定
- 记忆重组、工作区清理、计划结构修复等手动治理能力已迁移至同级独立子仓库 `../commands/`；为避免 `commands/README.md` 被命令加载器误识别，命令目录说明与手动治理工作流文档维护在 `../commands/docs/README.md`
- 本仓库仅保留与这些命令配套的治理知识、边界说明与可复用参考，不承担 command catalog 的主文档职责

### 文件命名
- 目录: kebab-case
- 文件: kebab-case（SKILL.md, AGENTS.md, template.md, examples.md）

### 语言
- Skill 内容: 中文（章节标题、正文、表格内容均已中文化）
- 系统标识符: 英文（`name` 字段、代码块、命令、文件路径、技术术语）
- 触发词: 中文（如 `omo-adaptive-execution` 的「多步骤委托」）
- 用户输出: 中文

## skills 开发常见错误积累

历次维护 skill 时实际犯过的错误。新增一条要求：现象 + 为什么错 + 如何避免。

| # | 现象 | 为什么错 | 如何避免 |
|---|------|---------|---------|
| 1 | 在 SKILL.md 正文写 `## 最小 CSO 触发词` / `## 最小触发词` 章节 | 触发词属 L0 description（始终全量注入），正文重复既浪费 L1 加载成本，又与 L0 触发器职责冲突；同义变体命名（CSO 触发词 vs 触发词）还制造 grep 漏检 | 触发词只融合进 frontmatter `description`；维护时 grep 多种命名变体确认无残留 |
