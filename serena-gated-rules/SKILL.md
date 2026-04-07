---
name: serena-gated-rules
description: Use when project work needs Serena symbol-level navigation/editing, Serena memory operations, or post-edit memory hygiene after durable project-content or plan changes.
---

# Serena Gated Rules

## Load Conditions

Load this skill when any of the following is true:

- You need Serena symbol/navigation/edit workflow for precise modifications.
- You performed project content/code edits or plan rewrites and must run Serena memory hygiene.
- You need to persist durable project knowledge via Serena memory tools.

## Minimal CSO Triggers

Primary keywords: `serena`, `find_symbol`, `rename_symbol`, `list_memories`, `read_memory`, `edit_memory`, `memory hygiene`, `memory impact tag`.

Secondary keywords: `symbol-level edit`, `precise refactor`, `knowledge persistence`, `post-edit memory sync`.

## Counter-Examples (Do Not Trigger)

| Input Pattern | Do Not Trigger Because |
|---|---|
| "只解释一个通用概念，不读取或修改项目" | No Serena project navigation/edit/memory workflow involved |
| "仅运行一次独立系统命令（与项目状态无关）" | Pure command execution without project knowledge lifecycle |
| "只做外部资料检索总结" | Research-only step; no Serena symbol or memory operations |

## Mandatory Rules

1. Initialize Serena context before deep edits (`serena_initial_instructions` / project activation workflow).
2. Prefer Serena symbol/navigation/edit tools for precise code operations over broad text edits.
3. After project-content changes, execute memory hygiene in fixed order.
4. Persist only durable, reusable knowledge; do not store transient task chatter.

## Memory Hygiene Protocol

- Trigger after durable project-content edits or plan rewrites that change reusable project knowledge.
- Maintenance order: `list_memories` → `read_memory` → `edit_memory` → `rename_memory` → `write_memory` → `delete_memory`.
- If a written plan/todo list exists, every item must carry one memory impact tag: `[Memory: update]`, `[Memory: delete]`, `[Memory: rename]`, `[Memory: write]`, `[Memory: none]`.
- A planned item is not complete until memory impact is executed or marked `none`.

## Verification Signals

- Updated plan/tasks include explicit memory impact tags.
- Memory operations follow the declared order without skipped stages.
- New memory entries are reusable constraints/patterns, not ephemeral logs.

## Failure Handling

- If Serena tools are unavailable, skip this skill and use non-Serena fallback workflows/tools.
