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
| [omo-adaptive-execution](omo-adaptive-execution/) | OMO 统一执行入口：`SKILL.md` 维护滚动执行，`routing.md` 维护路由选择 |
| [omo-atlas-execution-constraints](omo-atlas-execution-constraints/) | OMO Atlas 中大型目标编排的角色边界、执行门控和质量要求 |

### 代码语义与外部工具

符号级代码理解与回退链路——优先 Serena，失效时降级到 LSP / AST-grep / search-read。

| 技能 | 说明 |
|------|------|
| [serena-first-codework](serena-first-codework/) | 当 Serena 可用时必须加载。 |

### 全局约束

跨项目、跨子代理生效的通用约束。

| 技能 | 说明 |
|------|------|
| [long-running-process](long-running-process/) | 当前运行环境是 Windows + PowerShell，且涉及长运行进程、端口/health endpoint 等待或可能超时的构建命令时使用。核心：禁止无界等待、框架预算表、liveness check、参数化模板 |
| [interrupted-subagent-recovery](interrupted-subagent-recovery/) | 子代理中断恢复——控制器在中断后必须先审计旧执行状态再续派。核心：步骤 0 会话发现、workspace 现实审计、[PREVIOUS-PROGRESS] + [DO-NOT-REPEAT] 上下文 |
| [opencode-subagent-log-triage](opencode-subagent-log-triage/) | OpenCode 子代理/后台任务卡住时的日志与本地 session 数据排查，先定位 session、tool part、进程树与端口归属，再给出最小安全处置建议 |
| [agent-browser-windows](agent-browser-windows/) | Windows 上 agent-browser 浏览器自动化的进程安全：串行化锁、超时 wrapper、强制 close、孤儿进程清理。范围仅 Windows PowerShell 7+ |

## 技能依赖关系

```
omo-adaptive-execution ──→ OMO 执行状态机 + routing.md 路由策略

omo-atlas-execution-constraints ──→ omo-adaptive-execution（统一规则源）

其它特殊执行方式由各 skill 的 description 自行触发，不在本地依赖图重复枚举

interrupted-subagent-recovery ──→ 按需加载（触发词驱动）；审计发现的残留进程/端口清理与原子提交边界由控制器按需路由到对应能力，不硬绑定具体 skill
```
