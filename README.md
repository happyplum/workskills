# oh-my-opencode 技能集

oh-my-opencode 多智能体系统的自定义技能集，覆盖路由调度、计划执行、外部协作与存储维护。

## 安装

将技能目录放置于 oh-my-opencode 的技能配置路径下（如 `~/.config/opencode/skills/`），重启会话后自动加载。

与手动治理命令对应的命令目录现已迁移为独立的 `commands/` Git 子仓库；为避免 `commands/README.md` 被命令加载器误识别，命令目录说明与命令入口文档请维护在上层同级 `../commands/docs/README.md`，不要继续把 command catalog 作为本 README 的主事实来源。

## 技能列表

### 计划与执行

计划生命周期——覆盖执行阶段协调。计划结构修复能力已迁出为独立的手动治理入口；自动执行路径应通过 `oracle` 的结构化修订结果推进，而不是把命令名当成执行动作。

| 技能 | 说明 |
|------|------|
| [omo-adaptive-execution](omo-adaptive-execution/) | OMO 统一执行入口：滚动波次 + 路由 + 发现委托均在 `SKILL.md` |
| [omo-atlas-execution-constraints](omo-atlas-execution-constraints/) | OMO Atlas 中大型目标编排的角色边界、执行门控和质量要求 |
| [review-work](review-work/) | 基于风险选择最少充分审查 lane；普通 QA/代码审查走 Luna-max，Oracle 仅裁决未决结构问题 |

### 全局约束

跨项目、跨子代理生效的通用约束。

| 技能 | 说明 |
|------|------|
| [long-running-process](long-running-process/) | Windows + PowerShell 应用进程：WMI supervisor、RunId ownership、wait-ready 归属校验、stop-background；禁止无界等待与 OpenCode shell 内 Start-Process |
| [deep-thinking](deep-thinking/) | 显式触发的深度分析模式；默认仍保持简洁优先，仅在 `ult`、`ulw` 或“深度思考 / 帮我思考 / 超级思考 / 深度分析”等触发时使用 |
| [opencode-subagent-log-triage](opencode-subagent-log-triage/) | 卡住取证：session/tool/进程树 → writer 三态 ACTIVE/INACTIVE/UNKNOWN；不 `task()` 续派，应用进程清理交 long-running-process |

## 技能依赖关系

```
omo-adaptive-execution ──→ OMO 执行状态机 + 路由 + 发现委托（单文件）

omo-atlas-execution-constraints ──→ omo-adaptive-execution（统一规则源）

review-work ──→ omo-adaptive-execution（最低足够路由与并发预算）

其它特殊执行方式由各 skill 的 description 自行触发，不在本地依赖图重复枚举
```
