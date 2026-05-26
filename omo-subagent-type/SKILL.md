---
name: omo-subagent-type
description: 当调用 task() 进行工作路由时使用。涵盖 subagent_type 选择、category 选择、run_in_background 配置和 load_skills 配置。
---

# OMO 子代理类型

在任何 `task()` 调用前使用，确保模式正确、路由合理、提示词可执行。对于 `subagent-driven-development` 内部的编码工作，由该 skill 管理「先拆分、后路由」流程；本 skill 处理 `task()` 模式和 category/subagent 选择。

## 0. 快速入门

**一条规则：** `task()` 需要且仅需要 `subagent_type` 异或 `category` 之一，加上 `run_in_background`、`load_skills`、`description` 和 `prompt`。

### 平台事实 vs 本地治理边界

- 上游 OMO 平台文档把 `task(category="...")` 解释为路由到 category-spawned executor（如 `sisyphus-junior`）。这是**平台运行时事实**。
- 本仓库的计划、prompt 与 skill 属于**本地治理 authoring surface**：作者应只写 `category`，或本 skill 标准化的 `subagent_type`（`explore` / `librarian` / `metis` / `oracle` / `momus`），而不是把 `Sisyphus-Junior` 直接写成作者侧 `subagent_type`。
- 若 imported / copied plan 带入上游 runtime 名称、额外 category 或弱路由形状，先规范化到本地治理子集，再进入执行。

### 提级阶梯

**Category 成本顺序（默认从低到高）：** 直接工具 → `quick` → `unspecified-low` → `unspecified-high` → `deep` → `ultrabrain`。领域 category（`visual-engineering`、`artistry`、`writing`）覆盖成本层级——见 Q4。仅当低成本层级明显不足时才提级。

### 决策问题（按顺序回答）

```
Q1: 文件位置已知且任务是单步的（无需发现）？
    → YES: 使用直接工具（read/grep/glob/edit）。停止。
    → NO: 继续到 Q2。

Q2: 任务主要关于本仓库/当前工作区产物（代码、文档、配置、脚本）？
    → YES: 继续到 Q3。
    → NO: 主要需求是什么？
        - 检索（文档、示例、API 参考） → subagent_type="librarian", run_in_background=true。停止。
        - 推理/澄清 → 继续到 Q3。

Q3: 任务类型是什么？
    → 搜索/发现模式 → subagent_type="explore", run_in_background=true
    → 澄清模糊请求或评审/审查 → 路由到合适的审查代理，run_in_background=false
        - 完成状态/遗漏检查 → 先用 `metis`
        - `metis` 后的深度审查/计划修订指引 → `oracle`
    → 架构/调试或显式提级 → 路由到合适的提级代理，run_in_background=false
    → 实现代码 → 继续到 Q4。

Q4（实现——领域 category 覆盖成本层级）:
    a) UI/UX/样式工作（包括重构、构建、大规模 UI） → category="visual-engineering"
    b) 非常规创意设计 → category="artistry"
    c) 文档/文案 → category="writing"
    d) 有界、模式已知（≤2 文件，无架构权衡） → category="quick"
    e) 多文件、常规实现 → category="unspecified-low"
    f) 显著范围 + 中等不确定性 → category="unspecified-high"
    g) 广泛不确定性 + 迭代发现循环 → category="deep"
    h) 硬推理（算法、形式化权衡、复杂状态机） → category="ultrabrain"
    → 兜底（无匹配）: category="unspecified-high"
```

### 最小有效调用

```typescript
task({
  subagent_type: "explore",  // 异或 category
  run_in_background: true,
  load_skills: [],
  description: "简短摘要",
  prompt: "[CONTEXT]: ...\n[GOAL]: ...\n[RETURN]: ..."
})
```

**提示词字段：** `[CONTEXT]`/`[GOAL]`/`[RETURN]` 必填。仅在需要时添加 `[SCOPE]`/`[SKIP]`/`[WHY_NOT_LOWER_COST]`/`[INPUT-ORIGINAL]`。

**延迟路由约定：** 若 author-time 还不能确定实现类路由，可使用 `executor_judgment` 或 `routing_by_executor`，但必须附一行理由，并确保执行前已规范化为本地治理认可的路由形状。

---

## 1. 核心契约（必须——7 条规则）

| # | 规则 | 验证方式 |
|---|------|----------|
| 1 | **异或：** `subagent_type` 或 `category`，不可同时提供 | 模式检查 |
| 2 | **必填：** `run_in_background`、`load_skills`、`description`、`prompt` | 模式检查 |
| 3 | **后台：** `explore`/`librarian` = true；审查/提级代理/category = false | 代理类型检查 |
| 4 | **Skills：** 仅从 `available_skills` 中选取；验证确切名称；无匹配时默认 `[]` | 交叉检查列表 |
| 5 | **提示词：** 必须包含 `[CONTEXT]`、`[GOAL]`、`[RETURN]` | 字段存在 |
| 6 | **语言：** 提示词使用英文；通过 `[INPUT-ORIGINAL]` 引用非英文原始输入 | LLM 指令 |
| 7 | **异步：** 等待系统提醒后再调用 `background_output()`；禁止轮询 | 调用序列 |

---

## 2. 代理与 Category 指南

### 子代理类型

| 代理 | 何时使用 | 产出 |
|-------|------|--------|
| `explore` | 内部代码库搜索、模式发现 | 文件路径 + 模式摘要 |
| `librarian` | 外部文档、OSS 示例、API 正确性 | URL + 引用摘录 |
| `metis` | 模糊请求、编码前需要规划、完成状态缺口检查 | 澄清后需求 + 遗漏审查 |
| `oracle` | 架构权衡、调试、`metis` 后的深度审查、计划修订指引 | 决策 + 推理 + 修订简报 |
| `momus` | 计划审查（显式请求时） | 通过/失败 + 修复 |

### 成本护栏

- 当任务主要是确定性的、模式已知时，**禁止**选择 `deep`。
- 一次只路由一个可独立验证的 bug；禁止将不相关 bug 打包进 `deep`。
- 没有明确的硬逻辑证据时，**禁止**选择 `ultrabrain`。
- 在 `quick` 和 `deep` 之间犹豫？先选 `unspecified-low`。
- 纯验证工作（断言、日志、检查）默认 `quick`。
- **必须：** 任何贵价/高成本路由（`deep`、`ultrabrain`、`visual-engineering`、`artistry`）需要在提示词中包含 `[WHY_NOT_LOWER_COST]`。*（验证：字段存在）*

### 计划执行验证例外

匹配父任务的领域 category。CLI/日志/断言工作降级到 `quick`；UI/截图验证使用 `visual-engineering`。在提示词中包含证据目标和成功门控。

---

## 3. 失败协议

1. **输入先规范化** — 若 imported / copied plan 带入上游 runtime 标签或不属于本地 authoring subset 的路由写法，先做 `normalize-before-execute` 或转入 `repairing-plans`，不要把原始输入直接当成本地合法路由。
2. **读取错误** — 模式验证？修复参数。子代理失败？用更多上下文重试。
3. **补充上下文** — 重试前扩展提示词章节。
4. **最多 2 次重试** — 然后切换策略：`explore` 失败 → `librarian`；`category` 失败 → 审查代理。
5. **提级** — 总计 3 次失败后，提级或询问用户。
6. **异步纪律** — 在系统提醒到达前，禁止规划依赖后续操作。

### 禁止行为

| ❌ 禁止 | 原因 |
|---------------|-----|
| `task(subagent_type=..., category=..., ...)` | 异或违规 |
| `task(load_skills=["magic-skill"], ...)` | 虚构 skill |
| `run_in_background=true` 后立即 `background_output()` | 轮询会永久阻塞 |
| 提示词中缺少 `[RETURN]` | 无结构化产出 |
| 无新增上下文的静默重试 | 重复相同失败 |
| 无限代理链（A→B→C→D...） | 上下文稀释 |
| 异步任务后跳过 `background_output()` | 浪费工作，无结果 |

---

## 4. 附录

### 正确示例

**Explore（内部搜索）：**
```typescript
task({
  subagent_type: "explore",
  run_in_background: true,
  load_skills: [],
  description: "Find auth middleware patterns",
  prompt: "[CONTEXT]: Adding JWT auth to REST API.\n[GOAL]: Find existing auth middleware and token flows.\n[SCOPE]: src/api/ and src/middleware/\n[SKIP]: Test files\n[RETURN]: File paths + brief pattern descriptions"
})
```

### 错误示例

```typescript
// ❌ Wrong: Use explore to read a known file
task({
  subagent_type: "explore",
  run_in_background: true,
  load_skills: [],
  description: "Read tsconfig",
  prompt: "[GOAL]: Read tsconfig.json content"
})

// ✅ Correct: Use direct tool
read({ filePath: "/absolute/path/to/tsconfig.json" })
```
