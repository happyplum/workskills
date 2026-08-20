---
name: review-work
description: 当用户明确要求 review work、审查已完成实现、QA 改动、验证实现或交付前复核时使用。
---

# 完成工作审查

## 概述

以风险选择最少充分的独立审查 lane，不固定代理数量，也不把 Oracle 当通用 reviewer。先复用实现阶段已有证据，只补能改变结论的检查。

## 审查输入

开始前固定：用户目标与约束、审查基线与产物 revision、变更文件、diff、已有定向测试/集成证据、运行入口和已知未决项。缺少会改变审查结论的输入时先补证据；不要把整个仓库或完整会话倾倒给每个 reviewer。

## Lane 选择

| Lane | 何时需要 | 默认路由 |
|---|---|---|
| 目标与约束 | 范围较大、需求多条或曾发生范围变化 | `unspecified-low`；局部明确改动可由父级直接核对 |
| Hands-on QA | 行为、CLI、API、UI 或构建产物发生变化 | `quick` 或 `unspecified-low`，实际运行最小充分场景 |
| 代码质量 | 非机械实现、公共调用链或跨模块改动 | `unspecified-low`，读取 diff 与相邻模式 |
| 安全 | 改动触及 auth/authz、输入边界、密钥、文件/网络或依赖 | `unspecified-low` 安全 reviewer；显式安全研究交专用 security skill |
| 上下文与历史 | 来源、owner、会话、计划、issue/PR 或历史决策存在歧义 | `explore` / `librarian` / `unspecified-low`，只查未决证据 |
| Oracle | 证据收集后仍存在架构、并发、迁移或高风险结构决策 | 前台 `oracle`，只裁决唯一未决问题 |

未命中触发条件的 lane 不启动，并记录 `SKIPPED: <reason>`；SKIPPED 不等于缺陷。普通审查不得为了“覆盖全面”固定启动五条 lane。

## 并发与路由

- 若需启动任何审查 lane，首次调用 `task()` 前先加载 `omo-adaptive-execution`；其成功返回是 category 与并发预算生效的顺序证据，不凭记忆路由。
- 先按 `omo-adaptive-execution` 确认最低足够 category；普通 reviewer 使用本地 `unspecified-low`（Luna-max）。
- 相互独立的 QA、代码质量、安全和上下文 lane 在同一轮 `run_in_background=true` 启动，受统一并发预算约束。
- 只有下一个审查决策立即依赖某 lane 时才前台等待；否则需要 `WHY_NOT_PARALLEL`。
- 使用 `unspecified-high` / `deep` / `ultrabrain` 或 Oracle 时必须说明低一档缺失的能力；测试多、diff 大或想更稳妥不构成理由。
- reviewer 是叶子任务，不再派子 reviewer；同一证据目标只有一个 owner。

## 验证强度

从最小能证伪目标行为的项目原生检查开始：局部改动跑定向测试，包内共享行为增加范围 typecheck，公共契约增加相关集成检查；仅当小检查失败、影响无法界定、发布或用户明确要求时升级 workspace 全量门禁。已有同 revision 的新鲜证据直接复用，不重复跑。

## 结论

每个已启动 lane 返回 `PASS`、`FAIL` 或 `INCONCLUSIVE`，附产物 revision、具体证据和阻断项。聚合规则：任一必需 lane FAIL → 总体 FAIL；无 FAIL 但必需 lane INCONCLUSIVE → INCONCLUSIVE；全部必需 lane PASS → PASS。报告只保留去重后的阻断问题和最高价值建议，不把低价值可选项转成用户负担。

## 反例

| 错误 | 正确 |
|---|---|
| 每次固定 3 个 Oracle + 2 个高级代理 | 按改动风险启动最少充分 lane |
| 普通代码质量或 QA 交 Oracle | Luna-max reviewer + 可执行检查 |
| 五条 lane 串行等待 | 独立 lane 同轮后台并发 |
| 每个 reviewer 都接收全量文件与完整会话 | 共享基线 + lane 专属证据胶囊 |
| 局部改动重复 full verify、build、全量浏览器矩阵 | 定向检查先行，有具体理由才升级 |
| review 为完整而发现无关问题 | 只审当前目标、约束与可达影响面 |
