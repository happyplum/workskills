---
name: superpowers-gated-rules
description: Use at conversation start and before significant actions to enforce skill-first execution and anti-rationalization discipline.
---

# Superpowers Gated Rules

## Load Conditions

Load this skill at conversation start and before significant actions, especially when you might skip skill checks due to urgency or overconfidence.

## Minimal CSO Triggers

Primary keywords: `before any action`, `check skills first`, `skill-first`, `using-superpowers`, `red flags`.

Secondary keywords: `rationalization`, `I already know this`, `simple question trap`, `process skill before implementation`.

## Counter-Examples (Do Not Trigger)

| Input Pattern | Do Not Trigger Because |
|---|---|
| "寒暄/打招呼" | No task execution context yet |
| "只问通用常识，不涉及当前项目" | No workflow/implementation risk in project context |
| "单一确定性只读查询，且已完成技能检查并确认无相关技能" | Skill-first check already happened; no additional process-routing decision remains |

## Mandatory Rules

1. Before any response/action, check whether any skill may apply.
2. If a relevant skill exists, invoke it before execution.
3. Treat “simple question / gather context first / I already know” as red-flag rationalizations.
4. Process skills (brainstorming/debugging) precede implementation skills.
5. If uncertain, invoke the likely skill first; discard later only with explicit mismatch reason.

## Verification Signals

- A relevant skill-check happened before meaningful execution steps.
- Process skill precedence is respected when both process and implementation skills apply.
- Rationalization phrases are explicitly recognized and countered.

## Failure Handling

- If `using-superpowers` is not available, skip this skill and proceed with standard local workflow.
