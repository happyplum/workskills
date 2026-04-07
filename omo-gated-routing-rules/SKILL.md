---
name: omo-gated-routing-rules
description: Use when deciding direct-tools vs task() delegation, or routing work by category/subagent with required quality gates.
---

# OMO Gated Routing Rules

## Load Conditions

Load this skill when you need to route work via `task()` (category/subagent), or when deciding between direct tools and delegation.

## Minimal CSO Triggers

Primary keywords: `task()`, `subagent_type`, `category`, `explore`, `librarian`, `metis`, `momus`, `routing`.

Secondary keywords: `delegate vs direct tools`, `quality gate`, `@metis -> @momus`, `fallback when subagent unavailable`.

## Counter-Examples (Do Not Trigger)

| Input Pattern | Do Not Trigger Because |
|---|---|
| "已知文件里改一行" | Direct precise edit, no routing decision needed |
| "解释这段代码" | Read-only explanation without delegation path |
| "只运行一个本地命令" | Command execution only, no task() routing required |

## Mandatory Rules

1. Evaluate task type before delegation.
2. Delegate one atomic task per `task()` call unless tasks are truly integrated.
3. Wait for delegated completion and consume results before dependent actions.
4. If `task()` supports `subagent_type` and subagents are callable, use `@explore` for repo discovery and `@librarian` for docs/OSS research.
5. If `@explore`/`@librarian` are unavailable, fall back to direct repo tools + official docs/context7/web search without fabricating capabilities.
6. Do not duplicate delegated exploration by re-running the same search manually.
7. Cancel disposable background tasks individually (never all-at-once cancellation).
8. For code-changing or decision-bearing delegated tasks, run the quality gate loop when both reviewers are available: `@metis` critique → `@momus` validation.
9. Mark completion only after explicit pass/OKAY, or record why the review gate was unavailable or not required.

## Verification Signals

- Delegation choice includes explicit rationale (direct vs task/subagent).
- No duplicate search overlap appears between delegated and manual exploration.
- Significant work closure has recorded `@metis -> @momus` pass evidence.

## Failure Handling

- If routing capability is unavailable, skip this skill and use direct tools with explicit verification.
