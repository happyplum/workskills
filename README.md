# Public AI Agent Skills

个人维护的通用公开 AI Agent Skills 仓库，主要服务于作者日常开发工作流，同时也经过整理与脱敏，方便公开分享与跨平台复用。仓库内所有 skill 均自包含，不依赖未公开的私有配置或外部内部仓库。

维护决策见 [`DECISIONS.md`](DECISIONS.md)，编写与设计规范见 [`docs/skill-design-guide.md`](docs/skill-design-guide.md)。

## 安装与使用

本仓库采用扁平目录结构，每个顶层 skill 目录均可独立使用。将需要的 skill 目录复制到你所使用的 AI 编程工具的技能路径即可（例如 `~/.config/opencode/skills/`、`.agents/skills/` 或项目级 skills 目录），重启或刷新会话后即可按需加载。

## 技能索引

### 分析与审查

| 技能 | 说明 |
|---|---|
| [deep-thinking](deep-thinking/) | 显式触发的深度分析模式（`ult` 或明确要求深度思考时激活），强调证据支撑、假设与失败路径，避免漫无边际发散与思维流水账 |
| [lzy-review-work](lzy-review-work/) | 按改动风险动态选择最少充分审查维度，低成本优先、复用已有验证证据（保留 `lzy-` 前缀以避免与其他工具内置的 `review-work` 冲突） |
| [audit-loop](audit-loop/) | 「只读审查 → 修复与验证 → 同一审查会话增量复审」的迭代闭环，直到审查者确认零未决问题 PASS，含轮数熔断与防削弱验证保护 |

### 规划与交付

| 技能 | 说明 |
|---|---|
| [external-executor-plan](external-executor-plan/) | 将讨论与核查事实整理为脱离当前聊天上下文、与具体 AI 工具解耦的完整交接实施方案，修订时输出完整替代稿 |
| [linearize-commits](linearize-commits/) | 线性化整理 git 提交历史：按「可独立 revert」划分粒度、保留原作者、严禁 `--no-verify`、校验代码零差异，并默认规范为 `type(scope): 中文描述` |
| [weekly-report-generator](weekly-report-generator/) | 从 git 历史只读取证生成中文书面周报（默认上周日到今天），按独立交付分条，规避代码注释腔、口语流水账与正文复述标题 |

### 工程规范（显式加载）

个人中后台/管理端前端工程习惯的系统整理。在团队协同或非本人主导的项目中，仅在明确要求时应用。

| 技能 | 说明 |
|---|---|
| [dev-standards](dev-standards/) | 框架中立的前端中后台工程规范，涵盖目录组织、请求与错误处理、界面优先呈现与布局稳定、表格/表单/通信约定及项目落地指南 |
| [vue-standards](vue-standards/) | 自包含的 Vue 3 + Element Plus + Pinia 中后台工程规范（目录、请求错误、表格表单弹窗图表封装、工程化配置），无需先加载 `dev-standards` |

### 环境与排障工具

| 技能 | 说明 | 适用环境 |
|---|---|---|
| [long-running-process](long-running-process/) | Windows + PowerShell 后台长运行进程安全托管：WMI 脱离管道继承、`RunId` 生命周期管理、有界就绪与端口归属校验、精确停止（含 8 个配套 `.ps1` 脚本） | Windows + PowerShell 7+ |
| [opencode-subagent-log-triage](opencode-subagent-log-triage/) | OpenCode 本地 SQLite 会话库只读排查与复盘：判断卡住状态并关联 Windows 进程/端口、统计父子会话树成本与 token（含 2 个配套只读 `.mjs` 脚本） | OpenCode（Windows） |

## 技能间关系

- `lzy-review-work` 与 `audit-loop` 互补：前者决定单轮审查启用哪些维度和验证强度，后者负责将查出的问题经「修 → 同会话增量复审」收敛至通过。
- `dev-standards` 与 `vue-standards` 相互独立：`vue-standards` 完全自包含，不依赖先加载 `dev-standards`。
- `opencode-subagent-log-triage` 排查出需清理的应用服务器时，可配合 `long-running-process` 的脚本按 `RunId` 或端口安全停止。
