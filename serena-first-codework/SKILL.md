---
name: serena-first-codework
description: 当 Serena 可用时必须加载。
---

# Serena 优先代码工作

## 概述

这个 skill 的目标是把 Serena 放在语义代码工作的第一层：Serena 健康且适用时，优先用它做符号级理解、影响分析、精确编辑、诊断和项目记忆；Serena 不健康、不可用或不适合时，立即降级，不阻塞任务。

## 快速决策表

| 场景 | 首选 | 回退 |
|---|---|---|
| 代码语义理解 / 符号级重构 | Serena | 原生 LSP → AST-grep → search/read |
| 引用、实现、影响面、安全删除 | Serena | 原生 LSP references/rename → AST-grep → search/read |
| 代码诊断 | Serena diagnostics | 原生 LSP diagnostics → 编译/测试/构建 |
| 结构化代码模式搜索 / 批量改写 | AST-grep | Serena pattern/content 工具 → search/read |
| 有 LSP 的配置 / 文档 / 结构化文本 | 原生 LSP | AST-grep（适用时）→ search/read |
| Serena 不可用 / 不健康 / 不支持目标 | 回退链 | LSP → AST-grep → search/read |

## 强制规则

1. 对代码语义任务，先判断 Serena 是否已暴露、健康、支持目标语言/文件并适合当前操作；满足时先用 Serena。
2. 使用 Serena 时优先按“概览 → 符号体 → 引用/声明/实现 → 精确编辑”的顺序缩小上下文，避免不必要的整文件读取。
3. 做重构、删除、签名或行为变更前，先用 Serena 或 LSP 查引用/实现/影响面；不要先改后补看。
4. Serena 失败、缺工具、不支持语言、结果不可信或任务不适合时，立即按 **原生 LSP → AST-grep → 普通 search/read** 回退。
5. 非代码、配置、文档、锁文件和结构化文本不硬套 Serena；若该文件类型有 LSP，优先使用 LSP，再按结构化搜索或普通读写兜底。
6. Serena 的 diagnostics 和 memory 是证据来源，不是完成证明；最终仍要运行适用的诊断、测试、构建、lint 或实际验证。
7. 只把已验证、可复用、会影响后续决策的长期事实写入 memory；临时日志、猜测、过程计划和一次性排障不写入 memory。

## Serena 能力使用

| 目标 | Serena 工具 | 使用要点 |
|---|---|---|
| 看文件结构 | `get_symbols_overview` | 先拿符号地图，再决定是否需要读具体 body |
| 找定义/符号体 | `find_symbol` | 只有需要理解或编辑时才 `include_body=True` |
| 查影响面 | `find_referencing_symbols` | 编辑、删除、改签名前优先使用 |
| 解歧义 | `find_declaration` | 调用点、导入或同名符号不清楚时使用 |
| 找实现 | `find_implementations` | 接口、抽象方法、协议、多态路径优先使用 |
| 查诊断 | `get_diagnostics_for_file` | 作为早期证据，不能替代测试/构建 |
| 精确插入 | `insert_before_symbol` / `insert_after_symbol` | 在已知符号附近插入函数、类、方法或导入 |
| 替换符号 | `replace_symbol_body` | 只在已读取目标 body 后使用 |
| 安全重构 | `rename_symbol` / `safe_delete_symbol` | 优先于文本 rename/delete；失败则回退 LSP |
| 模式搜索/文本改写 | `search_for_pattern` / `replace_content` / `replace_in_files` | 符号工具表达不了时使用，注意限制路径和范围 |
| 长期知识 | memory tools | 仅记录已验证且可复用的长期事实 |

## 回退策略

| 情况 | 处理 |
|---|---|
| Serena 未暴露或启动失败 | 简短记录“Serena 不可用”，直接走 LSP |
| Serena 部分工具失败 | 可用部分继续用；失败能力按回退链处理 |
| 语言/文件不支持 | 先试可用 LSP；无 LSP 再考虑 AST-grep 或 search/read |
| 任务是精确文本、日志、生成物或锁文件 | 跳过 Serena，选择更便宜准确的工具 |
| Serena 结果与测试/编译/LSP 冲突 | 以可执行验证为准，用 Serena 反查原因 |

## 反例

- ❌ 因为文件小就直接整文件读代码 → ✅ 代码语义任务先尝试符号概览或符号定位。
- ❌ 在 Markdown、JSON、YAML、TOML、锁文件上强行 Serena-first → ✅ 有 LSP 先 LSP，否则 search/read。
- ❌ Serena 找不到符号后反复重试同一调用 → ✅ 分类失败原因并回退到 LSP / AST-grep / search。
- ❌ 用文本替换做可语义 rename/delete 的重构 → ✅ 先用 Serena 或 LSP 的语义重构能力。
- ❌ 把 Serena diagnostics 当作“已验证通过” → ✅ 仍运行相关诊断、测试、构建或实际验证。
- ❌ 把临时调试结论写进 memory → ✅ 只写已验证的长期事实。

## 最小 CSO 触发词

**主要关键词：** Serena、symbol、symbols、semantic code、reference、references、implementation、call graph、LSP、AST-grep、refactor、rename、safe delete、diagnostics、memory、replace_symbol_body、insert_after_symbol、find_symbol

**次要关键词：** MCP、代码语义、跨文件、影响面、大文件、局部插入、精确编辑、调用链、定义、声明、实现、删除、项目记忆、续接、符号级编辑

## 记住一句话

**Serena 健康且适用时先 Serena；否则 LSP，其次 AST-grep，最后 search/read。**
