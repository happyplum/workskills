---
name: superpowers-gated-rules
description: Use at conversation start and before significant actions to enforce skill-first execution and prevent rationalizing away relevant skills.
---

# Superpowers Gated Rules

## Mandatory Rules

1. Before any response/action, check whether any skill may apply.
2. If a relevant skill exists, invoke it before execution.
3. Treat "simple question / gather context first / I already know" as red-flag rationalizations.
4. Process skills (brainstorming/debugging) precede implementation skills.
5. If uncertain, invoke the likely skill first; discard only with explicit mismatch reason.

## Failure Handling

If `using-superpowers` is not available, skip this skill and proceed with standard local workflow.