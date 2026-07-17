# oh-my-opencode 技能集

oh-my-opencode 多智能体系统的自定义技能集，覆盖路由调度、计划执行、外部协作与存储维护。

## 安装

将技能目录放置于 oh-my-opencode 的技能配置路径下（如 `~/.config/opencode/skills/`），重启会话后自动加载。

与手动治理命令对应的命令目录现已迁移为独立的 `commands/` Git 子仓库；为避免 `commands/README.md` 被命令加载器误识别，命令目录说明与命令入口文档请维护在上层同级 `../commands/docs/README.md`，不要继续把 command catalog 作为本 README 的主事实来源。

## 技能列表

### 路由与编排

路由调度与技能使用规范——决定「何时委托」和「如何选择」。

| 技能 | 说明 |
|------|------|
| [omo-gated-routing-rules](omo-gated-routing-rules/) | 工作路由决策——何时使用直接工具或 `task()` 委托，如何经济选择 category/subagent，包含贵价提级理由、审查与避免重复的规则 |

### 计划与执行

计划生命周期——覆盖执行阶段协调。计划结构修复能力已迁出为独立的手动治理入口；自动执行路径应通过 `oracle` 的结构化修订结果推进，而不是把命令名当成执行动作。

| 技能 | 说明 |
|------|------|
| [atlas-execution-constraints](atlas-execution-constraints/) | **执行时**确定性约束——面向大型任务可靠执行的验证排序、规范化、证据纪律与提级处理边界。Atlas 加载本 skill 后，必须在任何 `task()` 委托或执行面展开前确认外部依赖 `subagent-driven-development` 已加载 |

### 维护

完成后的文档与记忆同步审计。

| 技能 | 说明 |
|------|------|
| [doc-sync](doc-sync/) | 当重大实现、重构或计划已完成，文档、计划文件或持久化项目记忆可能不再与已验证的代码现实一致时使用。核心原则：已验证的代码现实优先于过时文档。默认仅审计；修复需显式批准 |

### 全局约束

跨项目、跨子代理生效的通用约束。

| 技能 | 说明 |
|------|------|
| [long-running-process](long-running-process/) | Windows 上长运行进程安全启动（dev server、flutter run 等）。核心：禁止无界等待、框架预算表、liveness check、参数化模板。范围仅 Windows PowerShell 7+ |
| [interrupted-subagent-recovery](interrupted-subagent-recovery/) | 子代理中断恢复——控制器在中断后必须先审计旧执行状态再续派。核心：步骤 0 会话发现、workspace 现实审计、[PREVIOUS-PROGRESS] + [DO-NOT-REPEAT] 上下文 |
| [opencode-subagent-log-triage](opencode-subagent-log-triage/) | OpenCode 子代理/后台任务卡住时的日志与本地 session 数据排查，先定位 session、tool part、进程树与端口归属，再给出最小安全处置建议 |
| [agent-browser-windows](agent-browser-windows/) | Windows 上 agent-browser 浏览器自动化的进程安全：串行化锁、超时 wrapper、强制 close、孤儿进程清理。范围仅 Windows PowerShell 7+ |

## 技能依赖关系

```
omo-gated-routing-rules ──→ 路由入口（决定是否委托、如何经济路由、何时审查）
        │
        └──→ 审查

atlas-execution-constraints ──→ subagent-driven-development（外部 skill 依赖：共享 SDD 拆分、路由与提级规则来源；当前来源为 C:\Users\lzy\.agents\skills\subagent-driven-development\SKILL.md，本仓库不维护副本）

atlas-execution-constraints
        │
        └──→ Atlas 执行门禁: 加载本 skill 后，任何 task() 委托或执行面展开前先确认 subagent-driven-development 已加载

long-running-process ──→ subagent-driven-development（SDD 工作流引用模板）

interrupted-subagent-recovery ──→ 按需加载（触发词驱动）；审计发现的残留进程/端口清理与原子提交边界由控制器按需路由到对应能力，不硬绑定具体 skill
```
