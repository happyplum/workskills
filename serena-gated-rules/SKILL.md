---
name: serena-gated-rules
description: Use when project work needs Serena symbol-level editing or Serena memory hygiene after durable project-content or plan changes.
---

# Serena Gated Rules

## Load Conditions

Load this skill when precise project editing should use Serena, or when durable project changes require Serena memory sync.

## Core Purpose

Use Serena for symbol-level edits and durable knowledge hygiene, not for generic search or transient task logs.

## Mandatory Rules

1. Initialize Serena context before deep project edits.
2. Prefer Serena symbol/navigation/edit tools over broad text edits when Serena can perform the change precisely.
3. After durable project-content or plan changes, run memory hygiene.
4. Persist only durable, reusable project knowledge; never store transient task chatter.
5. If a written plan or todo list exists, each item must declare memory impact: `update`, `delete`, `rename`, `write`, or `none`.

## Memory Hygiene Order

- Maintenance order: `list_memories` → `read_memory` → `edit_memory` → `rename_memory` → `write_memory` → `delete_memory`.
- A planned item is not complete until its memory impact is executed or marked `none`.

## Failure Handling

- If Serena tools are unavailable, skip this skill and use non-Serena fallback workflows/tools.
