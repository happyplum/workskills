# 项目知识库

## 概述

个人维护的通用公开 AI Agent Skills 仓库（以作者日常自用为主，同时公开分享）。每个 skill 为仓库根目录下的独立目录，包含 `SKILL.md` 及可选的 `references/`、`scripts/`、`evals/`。纯文档与轻脚本项目，无统一构建或 CI 流水线。

## 目录结构

```text
├── README.md                        # 仓库总览与技能索引
├── AGENTS.md                        # 本仓库维护知识库
├── DECISIONS.md                     # 本仓库公开设计决策记录（PUB-xxx）
├── docs/skill-design-guide.md       # Skill 设计与维护指南
├── audit-loop/                      # 审查→修复→同会话增量复审闭环
├── deep-thinking/                   # 显式触发的深度分析模式
├── dev-standards/                   # 框架中立的前端中后台工程规范（显式加载）
├── external-executor-plan/          # 脱离聊天与工具的完整外部交接方案
├── linearize-commits/               # 线性化整理 git 提交历史与提交信息规范
├── long-running-process/            # Windows + PowerShell 长运行进程托管与脚本
├── lzy-review-work/                 # 按风险动态选择维度的完成工作审查
├── opencode-subagent-log-triage/    # OpenCode 本地日志排查与会话树成本复盘
├── vue-standards/                   # 自包含 Vue 3 + Element Plus 工程规范（显式加载）
└── weekly-report-generator/         # 从 git 历史生成书面中文周报
```

## 维护约定

维护任何 skill 前，先阅读 [`docs/skill-design-guide.md`](docs/skill-design-guide.md) 与 [`DECISIONS.md`](DECISIONS.md)。

### 渐进式披露分层

| 层 | 位置 | 内容 |
|---|---|---|
| **L0 触发** | frontmatter `description` | 「当……时使用」格式的触发条件与触发词；纯触发，**不写工作流或能力清单** |
| **L1 规范** | `SKILL.md` 正文 | 概述、核心规则、工作流/决策表、反例；**不在正文重复写触发词章节**；行数控制在 `<500` 行 |
| **L2 详情** | `references/*.md` | 仅域知识密集型 skill（如 `dev-standards`、`vue-standards`）使用，须由正文显式指明阅读时机 |
| **L3 执行** | `scripts/*` | 确定性脚本，执行时不占用正文 context |

### Frontmatter 与命名

- Frontmatter 仅保留 `name` 和 `description` 两个字段；`name` 仅含小写字母、数字和连字符，与目录名保持一致；Frontmatter 总长 ≤ 1024 字符；`description` 使用中文。
- 目录和文件采用 kebab-case（除 `SKILL.md`、`README.md`、`AGENTS.md`、`DECISIONS.md`）。

### 语言与公开卫生

- **语言**：正文、标题、表格与 `description` 统一用自然流畅的中文；系统标识符、代码块、命令、文件路径和技术专有名词保留英文。
- **去 AI 味与通俗表达**：优先使用开发者通行的直白术语，避免自创黑话、空泛隐喻或为了防模型钻空子而无限叠甲。
- **公开自包含**：禁止写入本机绝对路径、未公开的私有包名/项目名/模型别名、真实私密业务案例，或指向本仓外部私有仓库/私有 skill 的硬依赖。

## 常见维护误区

| # | 现象 | 问题所在 | 如何避免 |
|---|---|---|---|
| 1 | 在 `SKILL.md` 正文单独写「触发词」章节 | 触发词属于常驻注入的 L0 `description`，正文重复既浪费加载 token，也容易前后不一致 | 触发词只放在 frontmatter `description` 中 |
| 2 | 在 `description` 里把工作流和细则写满 | Agent 容易跳过 `SKILL.md` 正文直接按描述发挥 | `description` 只写「什么时候用」，不写「怎么做」 |
| 3 | 把本机路径、私有项目实例或外部私有 skill 写进正文 | 公开分享时他人完全无法追溯或运行，且存在私密信息泄露风险 | 写完后自查路径、包名、示例与外部引用，确保完全自包含 |
| 4 | 自创大量冷僻黑话，再专门附一份名词表翻译 | 抬高阅读门槛，偏离通用工程共识 | 直接使用业界通行说法，写清原因和边界即可 |
| 5 | 代码审查固定拉满全套维度和高成本专家 | 小改动重复验证、浪费时间与算力 | 按改动风险选最少充分维度，复用同版本已有验证证据 |
