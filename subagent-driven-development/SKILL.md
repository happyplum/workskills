---
name: subagent-driven-development
description: Use when multi-step coding work must run through a decomposition-first workflow where standard-tier routing is the default, premium categories require explicit justification, and escalation cannot substitute for decomposition.
---

# Subagent-Driven Development

## Overview

Core principle: decompose first, route economically, escalate only with evidence.

## Load Conditions

Use during planning when work must be split before routing, or during execution when task is no longer clearly local, low-risk, single-surface change.

## Mandatory Rules

1. **Decompose First**: Split work into smallest independently executable units before routing.
2. **Standard Tier Default**: Use standard categories (`unspecified-high`, `unspecified-low`, `quick`, `writing`) by default.
3. **Premium Restraint**: Premium categories (`deep`, `ultrabrain`, `visual-engineering`, `artistry`) require `why_not_lower_cost` rationale.
4. **No Escalation Instead of Decomposition**: Do not bundle multiple unrelated bugs into one premium-routed task.
5. **Explicit Routing Surface**: Declare `category` or `subagent_type`; if deferred, use `executor_judgment` with one-line reason.
6. **Workflow Scope**: Use for multi-step coding work, cross-file implementation, or repeated convergence loops.
7. **Evidence Before Escalation**: Any routing upgrade must preserve task boundary and carry explicit evidence.

## Failure Protocol

1. If task still looks "too big" after planning, stop and decompose again.
2. If premium route lacks `why_not_lower_cost`, downgrade or add decomposition evidence.
3. If multiple unrelated bugs discovered, finish current bug before starting next.
4. If runtime escalation would change scope, stop and request plan repair.