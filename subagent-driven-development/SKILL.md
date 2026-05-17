---
name: subagent-driven-development
description: Use when multi-step coding work must run through a decomposition-first workflow where standard-tier routing is the default, premium categories require explicit justification, and escalation cannot substitute for decomposition.
---

# Subagent-Driven Development

## Overview

This skill is the shared source of truth for `subagent-driven-development`.

- Top-level `AGENTS.md` keeps the repo-wide constitution.
- This skill defines the shared execution doctrine for decomposition, routing, cost discipline, and escalation.
- Prompts and other skills should reference this skill instead of restating the same shared rules in full.

**Core principle:** decompose first, route economically, escalate only with evidence.

## Load Conditions

Load this skill whenever multi-step coding work is being planned or executed through a task-scoped workflow and the decomposition depth, routing choice, or escalation boundary could drift.

- Use during planning when execution-ready work must be split before routing.
- Use during execution when the task is no longer a clearly local, low-risk, single-surface change.
- Use whenever a route might move from the standard tier to a premium category.

## Mandatory Rules

1. **Decompose First**: Before category selection, split work into the smallest independently executable coding units. If a task can still be split without losing execution truth, it is not ready for routing. For bug-fix work, each independently verifiable bug should be its own execution unit unless multiple symptoms share one root cause and one verification surface.
2. **Standard Tier Default**: For coding work under this workflow, standard categories (`unspecified-high`, `unspecified-low`, `quick`, `writing`) are the default. Do not jump to premium routing while a standard-tier route remains credible. For bug-fix work, start with direct local execution, `quick`, or another standard-tier route before considering a premium category.
3. **Premium Restraint**: Premium categories (`deep`, `ultrabrain`, `visual-engineering`, `artistry`) are reserved for genuinely hard subproblems. Every premium-routed task must include a short `why_not_lower_cost` rationale.
4. **No Escalation Instead of Decomposition**: Do not use premium routing or runtime escalation to swallow an under-decomposed task. If work is too large for the chosen tier, split it further or return it for repair. Do not bundle multiple unrelated bugs into one premium-routed task just because they were reported together.
5. **Explicit Routing Surface**: Each execution task must declare `category` or `subagent_type`; if routing is intentionally deferred, use `executor_judgment` or `routing_by_executor` with a one-line reason.
6. **Workflow Scope**: Use this workflow for multi-step coding work, cross-file implementation, or repeated convergence loops. Do not force it onto clearly local, low-risk, single-surface work.
7. **Evidence Before Escalation**: Any routing upgrade or runtime escalation must preserve task boundary and business intent, and must carry explicit evidence for why the lower-cost tier is insufficient.

## Quick Decision Table

| Situation | Default Move | Escalate When |
|---|---|---|
| Work is clearly local, low-risk, and confined to one narrow surface | Stay on direct local execution or `quick` | Only if repeated verification or cross-surface coupling appears |
| The report contains multiple bugs or failures | Split them into one bug per execution path and route the cheapest credible bug first | Keep multiple findings together only when one root cause and one verification surface justify it |
| Work is multi-step but routine after splitting | Use `subagent-driven-development` with standard-tier routing | Only if a child task still exceeds standard-tier capability |
| A child task needs heavy reasoning, broad uncertainty, or specialized visual/creative capability | Route only that child task to the matching premium category | Keep every other child task on the standard tier unless separate evidence says otherwise |
| A task still feels too large after the first split | Split again before choosing a stronger category | Do not escalate simply because the unsplit task feels expensive |
| Routing is intentionally deferred to execution time | Use `executor_judgment` or `routing_by_executor` with a short reason | Upgrade only after fresh evidence narrows the need |
| Runtime escalation would change scope, deliverables, or business intent | Stop and request repair or rerouting | Escalation is allowed only when the task boundary still holds |

## Failure Protocol

1. If a task still looks “too big” after initial planning, stop routing and decompose again.
2. If a premium route lacks a clear `why_not_lower_cost` reason, downgrade it or add decomposition evidence before proceeding.
3. If multiple unrelated bugs are discovered, finish the current bug's fix, verification, and commit boundary before starting the next one.
4. If runtime escalation would change scope or deliverables, stop and request plan repair or rerouting.
5. If prompts or other skills drift from the shared SDD rules here, update those references rather than creating a second source of truth.

## Appendix

### Shared Rule Ownership

- `prometheus*` should reference this skill for shared decomposition, routing, and cost-discipline rules while keeping planning-specific outputs local.
- `sisyphus*` should reference this skill for multi-step coding execution instead of re-explaining the whole workflow.
- `atlas-execution-constraints` should own Atlas-specific runtime constraints while deferring shared SDD doctrine here.
- `repairing-plans` and `omo-subagent-type` may enforce or consume these rules, but should not compete with them as parallel top-level doctrine.
