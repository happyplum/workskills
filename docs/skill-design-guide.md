# Skill 设计与维护指南

> **维护任何 skill 前，先读本指南。** 本指南是本仓库自定义 skill 的设计权威参照，
> 综合 Claude 官方 best practices、superpowers/writing-skills 实测结论、Microsoft agent skill
> 规范、agentskills 开放规范，以及本地 22 个成熟 skill 样本（`.agents/skills/`）的结构分析。

## 核心原则：渐进式披露（Progressive Disclosure）

skill 不应一次性倾倒所有信息，而应分层按需加载：

| 层 | 位置 | 大小 | 何时加载 | 写什么 |
|---|---|---|---|---|
| **L0 触发** | frontmatter `description` | ~50-100 tokens | 会话开始**全量注入**（所有 skill） | 「做什么 + 何时用 + 触发词」，**纯触发条件** |
| **L1 规范** | SKILL.md 正文 | **<500 行**（红线） | 触发匹配时加载 | 工作流、强制规则、决策树、反例 |
| **L2 详情** | `references/*.md`、同级 `.md` | 不限 | 正文**显式指令**「read X」才加载 | 领域变体、API 参考、子代理提示模板 |
| **L3 执行** | `scripts/*`、`assets/*` | 不限 | 执行**不进 context**，仅输出消耗 token | 确定性脚本、模板、数据 |

**加载机制关键点**：
- `description` 是唯一始终在 context 的内容（~80 tokens/skill），它是**触发器**
- references 必须由正文显式指令（「Before X, read references/Y.md」）才加载；隐式的「use the guidelines」**不触发**
- 引用**一层深**：SKILL.md → reference，不要 reference 嵌套 reference

## description 写法（superpowers 实测结论）

> **Description = When to Use, NOT What the Skill Does**
> 实测发现：description 写工作流摘要时，agent 会**跳过正文**直接按描述执行。

**正确**——只写触发条件：
- ✅ 「当在 Windows 上启动长运行进程、等待端口就绪、或排查进程导致 tool call 卡住时使用」
- ✅ 「当子代理被中断后用户说"继续"时按需加载」

**错误**——写能力清单 / 工作流摘要：
- ❌ 「提供就绪验证、核心不被绕过、证据纪律、Wave 门控」（列能力 → agent 跳过正文）
- ❌ 「第一步 X，第二步 Y，第三步 Z」（写流程 → agent 按描述执行）

规范：中文，「当……时使用」格式，≤1024 字符，含触发词。

## 长度红线与拆分信号

| SKILL.md 行数 | 状态 | 动作 |
|---|---|---|
| <200 | 健康 | 维持单文件 |
| 200–400 | 注意 | 监控，内嵌代码优先抽 `scripts/` |
| 400–500 | 临界 | 考虑拆 `references/` |
| >500 | **违规** | 必须拆分 |

拆分信号：
- 有**领域变体**（如图表类型、API 分支）→ 每变体一个 `references/` 文件
- 有**子代理提示模板**（长 prompt）→ 独立 `.md` 文件 + markdown 链接引用（SDD 模式）
- 有**条件加载路径** → 加「何时加载」路由表（figma-use 范例）

## 何时需要 references/ 层

```
该 skill 是域知识密集型吗？（大量 API 参考、领域变体、条件路径）
├─ 是 → 需要 references/（如 figma-use 13 个参考、figma-generate-diagram 按图表类型分文件）
└─ 否（规则/治理/工作流型）
    └─ SKILL.md <400 行 → 单文件足够，不需要 references/
```

本仓库 7 个 skill 全是规则/治理型，均 <200 行，**均不需要 references/**。

## 脚本化原则

> 「把可重复的工作放脚本里，不要依赖模型推理。」

**抽脚本的信号**：
- 同一段代码在 SKILL.md 占 >20 行 → 抽 `scripts/`
- 确定性操作（启动进程、清理、校验、格式化）→ 脚本
- 带参数的模板（填空式 `$VAR` 占位）→ 带 `param()` 的脚本

**保留在 SKILL.md 的代码**：
- 反例（教学性，非可执行）—— 但优先表格化
- 工作流编排（展示如何组合脚本/函数，通常 <10 行调用序列）
- 单行调用说明（`. source.ps1` / `& script.ps1 -Param`）

**脚本组织规范**：
- `scripts/xxx.ps1` 带注释头（`.SYNOPSIS` / `.DESCRIPTION` / `.PARAMETER` / `.EXAMPLE`）
- 可复用原语 → dot-source 模块（如 `ab-primitives.ps1`）
- 场景脚本 → 带参数直接运行
- 调用说明用 `<skill-dir>/scripts/xxx.ps1` 占位符（运行时替换为 skill location）

## Gotchas / 反例章节

> Gotchas 是 skill 里**信息密度最高**的部分——案例是「agent 会做看似合理但错误的事」。

本仓库 skill 的「## 反例」章节承担此角色。规范：
- 写「❌ 错误 → ✅ 正确」对
- **优先表格化**（无代码块），除非坏命令本身值得展示
- 聚焦「看似合理但错误」的陷阱，不写显而易见的常识
- **「## 红旗」**（如 doc-sync）是 anti-rationalization 短语（agent 用来跳过审计的内心独白），区别于「## 反例」的 ❌→✅ 对；两者都是高信号内容，按 skill 性质选用

## 标准目录结构

```
skill-name/
├── SKILL.md          # 主指令（<500 行，触发时加载）
├── scripts/          # 确定性脚本（L3，执行不加载到 context）
│   └── *.ps1
├── references/       # 按需详情（L2，仅域知识密集型 skill 需要）
│   └── *.md
└── assets/           # 模板/数据（如需要）
```

## 反模式清单

| 反模式 | 为什么不好 | 来源 |
|---|---|---|
| description 写工作流/能力清单 | agent 跳过正文按描述执行 | superpowers 实测 |
| >7 条强制规则 | 认知过载，保持 ≤7 条 | 本仓库 AGENTS.md |
| SKILL.md >500 行 | 触发加载成本过高，应拆 references/ | Claude 官方 |
| reference 嵌套 reference | 加载路径不明确，只允许一层深 | Claude 官方 |
| 内嵌大段可执行代码 | 应抽 scripts/，降低复制出错率 | 本次脚本化经验 |
| 隐式引用 references | 不触发加载，必须正文显式指令「read X」 | Claude 官方 |
| 在 skill 里教基础代码 | Claude 已会写代码，skill 聚焦「推出正常思维模式」的信息 | Anthropic |
| "Verify via LLM" 规则 | 不可简单验证，每条规则需可验证标准 | 本仓库 AGENTS.md |
| ASCII 流程图 | 浏览 token，LLM 按序处理文本 | 本仓库 AGENTS.md |
| 同类多例 | 稀释质量，维护负担 | 本仓库 AGENTS.md |

## 本仓库 skill 现状速查

| skill | 行数 | 结构 | 状态 |
|---|---|---|---|
| omo-gated-routing-rules | ~120 | 单文件 | 健康 |
| long-running-process | 113 | SKILL.md + 5 scripts | 健康（已脚本化） |
| agent-browser-windows | 181 | SKILL.md + 6 scripts | 健康（已脚本化） |
| atlas-execution-constraints | 108 | 单文件 | 健康 |
| interrupted-subagent-recovery | 95 | 单文件 | 健康 |
| doc-sync | 168 | 单文件 | 健康 |
| opencode-subagent-log-triage | 165 | 单文件 | 健康 |

## 参考来源

- Claude 官方 skill best practices（progressive disclosure、目录结构、<500 行）
- superpowers/writing-skills（description 实测结论、Gotchas 价值）
- Microsoft agent skill 规范
- agentskills 开放规范
- 本地样本：`.agents/skills/` 22 个 skill 结构分析（2025-07）
