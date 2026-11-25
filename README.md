# Public AI Agent Skills

个人维护的通用公开 AI Agent Skills 仓库，主要服务于作者日常开发工作流，同时也经过整理与脱敏，方便公开分享与跨平台复用。仓库内所有 skill 均自包含，不依赖未公开的私有配置或外部内部仓库。

维护决策见 [`DECISIONS.md`](DECISIONS.md)，编写与设计规范见 [`docs/skill-design-guide.md`](docs/skill-design-guide.md)。

## 安装与使用

本仓库采用扁平目录结构，每个顶层 skill 目录均可独立使用。将需要的 skill 目录复制到你所使用的 AI 编程工具的技能路径即可（例如 `~/.config/opencode/skills/`、`.agents/skills/` 或项目级 skills 目录），重启或刷新会话后即可按需加载。

## 技能索引

### 分析与审查

| 技能 | 说明 |
|---|---|
| [lzy-review-work](lzy-review-work/) | 按改动风险动态选择最少充分审查维度，低成本优先、复用已有验证证据（保留 `lzy-` 前缀以避免与其他工具内置的 `review-work` 冲突） |
| [audit-loop](audit-loop/) | 「只读审查 → 轻量二次确认 → 修复与验证 → 原审查会话温链复审」的迭代闭环，核心 PASS 后可由用户选择干净代理复核，含轮数熔断与防削弱验证保护 |

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

## 技能间关系

- `lzy-review-work` 与 `audit-loop` 互补：前者决定单轮审查启用哪些维度和验证强度，后者负责将二次确认的问题经「修 → 原会话温链复审」收敛至通过，并支持核心 PASS 后可选干净代理复核。
- `dev-standards` 与 `vue-standards` 相互独立：`vue-standards` 完全自包含，不依赖先加载 `dev-standards`。
