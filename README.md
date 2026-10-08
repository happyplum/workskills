# oh-my-opencode 技能集

oh-my-opencode 多智能体系统的自定义技能集，覆盖路由调度、计划执行、外部协作与存储维护。

**决策入口**：本仓 skill 行为的用户裁决与决策史（SK-xxx）记录在 [`DECISIONS.md`](DECISIONS.md)；修改任何 skill 行为前先核对其中的 `active` / `superseded` 状态，避免回退到已废弃方向。

## 安装

将技能目录放置于 oh-my-opencode 的技能配置路径下（如 `~/.config/opencode/skills/`），重启会话后自动加载。

与手动治理命令对应的命令目录现已迁移为独立的 `commands/` Git 子仓库；为避免 `commands/README.md` 被命令加载器误识别，命令目录说明与命令入口文档请维护在上层同级 `../commands/docs/README.md`，不要继续把 command catalog 作为本 README 的主事实来源。

**omo-* 治理 skills 已迁出**（2026-10-08）：`omo-adaptive-execution`、`omo-atlas-execution-constraints`、`omo-plan-structure`、`omo-plan-review` 现维护于 `~/.config/opencode/skills/`（独立 Git 仓库，即 oh-my-opencode 技能加载路径）。本仓不再维护其内容；迁移前的 SK-xxx 决策史仍见 [`DECISIONS.md`](DECISIONS.md)。

## 技能列表

### 计划与执行

计划生命周期——覆盖执行阶段协调。计划结构修复能力已迁出为独立的手动治理入口；自动执行路径应通过 `oracle` 的结构化修订结果推进，而不是把命令名当成执行动作。omo-* 治理 skills 已迁出（见上方迁移说明）。

| 技能 | 说明 |
|------|------|
| [review-work](review-work/) | 基于风险选择最少充分审查 lane；普通 QA/代码审查走 Luna-max，Oracle 仅裁决未决结构问题 |

### 全局约束

跨项目、跨子代理生效的通用约束。

| 技能 | 说明 |
|------|------|
| [long-running-process](long-running-process/) | Windows + PowerShell 应用进程：WMI supervisor、RunId ownership、wait-ready 归属校验、stop-background；禁止无界等待与 OpenCode shell 内 Start-Process |
| [deep-thinking](deep-thinking/) | 显式触发的深度分析模式；默认仍保持简洁优先，仅在 `ult`、`ulw` 或“深度思考 / 帮我思考 / 超级思考 / 深度分析”等触发时使用 |
| [opencode-subagent-log-triage](opencode-subagent-log-triage/) | 卡住取证：session/tool/进程树 → writer 三态 ACTIVE/INACTIVE/UNKNOWN；执行审计：会话树成本/token/时长总账（SQLite 权威，scripts/query-sessions.mjs、dump-session-parts.mjs）；不 `task()` 续派，应用进程清理交 long-running-process |
| [weekly-report-generator](weekly-report-generator/) | 从 git 历史生成中文周报（默认上周日至今天，不截成完整周日周，显式区间优先）；按独立交付分条，标题写做了哪件事、正文写结果，禁止注释腔、口语流水账和副作用标题，只读取证不落入 commit hash/逐项日期 |
| [audit-loop](audit-loop/) | 审查→修复→同一审查会话温链续审，直到审查子代理明确无误通过；用户点名审查者则直接用，未点名先确认，执行类子代理不能当审计者 |

### 工程规范

手动/显式加载的个人工程契约；协同或非本人主导项目仅在用户明确要求时应用。

| 技能 | 说明 |
|------|------|
| [dev-standards](dev-standards/) | 框架中立的前端开发通用规范与工程结构契约（原则 / 落位 / 代码内部）；用于按个人习惯实现、评审或落成项目 AGENTS.md |
| [vue-standards](vue-standards/) | 自包含 Vue 工程规范（结构 / 请求 / 表格表单 / 工程化）；不依赖通用版 skill |

## 技能依赖关系

```
review-work ──→ omo-adaptive-execution（启动审查 lane 前加载；最低足够路由与并发预算；该 skill 已迁至 ~/.config/opencode/skills/）

其它特殊执行方式由各 skill 的 description 自行触发，不在本地依赖图重复枚举
```
