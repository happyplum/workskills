---
name: superpowers-gated-rules
description: 当会话开始或执行重要操作前，需要强制执行 skill 优先加载，防止以借口跳过相关 skill 时使用。
---

# Superpowers 门控规则

## 强制规则

1. 在任何响应/操作前，检查是否有适用的 skill。
2. 如果存在相关 skill，在执行前先调用。
3. 将「简单问题/先收集上下文/我已经知道」视为危险的借口信号。
4. 流程类 skill（brainstorming/debugging）优先于实现类 skill。
5. 不确定时先调用可能的 skill；仅在明确不匹配时才跳过，并给出具体原因。

## 失败处理

若 `using-superpowers` 不可用，跳过本 skill，按标准本地工作流执行。
