---
name: atlas-execution-constraints
description: Use when Atlas needs deterministic execution governance for reliable large-task execution, including verification ordering, normalization, evidence discipline, and escalation boundaries before or during execution.
---

# Atlas Execution Constraints

## Overview

This skill is the source of truth for Atlas execution-time constraints.

- Atlas prompt stays lean and only routes into this skill.
- Execution constraints live here, not in prompt text.
- `repairing-plans` remains a separate manual repair skill.

Core principle: execute only what is structurally valid, verifiable, and evidenced.

## Load Conditions

Load this skill when Atlas is about to execute an existing plan and needs deterministic runtime constraints.

- Use only after plan authoring and plan review are complete upstream.
- Use during execution when Subagent-Driven discipline, verification ordering, normalization, or evidence discipline could drift.

## Minimal CSO Triggers

Primary triggers:

- `atlas execute`
- `task n-v`
- `execution gate`
- `evidence before complete`
- `normalize nested tasks`

Secondary triggers:

- `plan-set entry exit gate`
- `phase handoff`
- `parent completion rule`
- `review rejection loop`

## Counter-Examples (Do Not Trigger)

| Input Pattern | Why not |
|---|---|
| "生成计划" / "write a plan" | This is planning stage; use `writing-plans`. |
| "修复计划结构错误" | This is document-repair stage; use `repairing-plans`. |
| "只要解释流程，不执行" | Pure explanation does not require execution-governance loading. |
| "单文件微小文本修正" | Trivial edits do not need full execution constraint stack. |

## Mandatory Rules

1. Enforce preload chain before execution starts; missing required skill means stop.
2. Atlas executes only against an existing reviewed plan; if the plan is missing, contradictory, or not execution-ready, stop and request upstream repair.
3. Before execution starts, Atlas may convert the accepted approved plan into an execution-only TODO surface; use that TODO surface as the immediate orchestration layer without reframing it as plan authoring.
4. Keep `subagent-driven-development` as the execution core for coding work; do not silently switch to sequential execution.
5. Do not execute downstream tasks before paired `Task N-V` passes.
6. Normalize executable nested items before parent completion decisions.
7. Reject or return plans when structural consistency gate fails; do not guess.
8. Require concrete evidence before completion claims and before review gates, and keep execution state recoverable with truthful status/evidence updates. If execution complexity rises while task boundary and business intent remain unchanged, Atlas MAY use bounded runtime escalation with explicit evidence and audit logging. If the task is under-decomposed, misrouted beyond bounded escalation, or requires scope change, stop the node, record evidence, and request plan repair/replan.

## Failure Handling

1. If skill header contract is missing/contradictory, stop and return plan for repair.
2. If verification repeatedly fails (>=2 reruns) or evidence is contradictory, escalate.
3. If phase gate evidence is missing, keep phase/index state unchanged and loop fix+reverify.
4. If issue is document-level repairable, stop runtime and request explicit manual `repairing-plans` pass.
5. If any executable task or paired verification node reopens, reset the affected Phase/Wave checkbox until closure is restored from underlying phase-file truth.
6. If proposed runtime escalation would change task boundary, business intent, or planned deliverables, deny escalation and request plan repair/replan.

## Required Preload Chain

Before execution, ensure this load order:

1. `omo-subagent-type`
2. `subagent-driven-development`
3. `atlas-execution-constraints` (this skill)

If any required skill is missing, stop and load it first.

## Execution Skill Header Contract

- Plan must include `## Execution Skill Requirements`.
- Treat that section as source of truth for additional skills.
- That section must require `subagent-driven-development` for Atlas-executed coding work; if it does not, stop and return the plan for repair or rerouting.
- If missing, incomplete, or contradictory with task body, stop and return plan for repair.

## Plan-Set Contract

When `*-index.md` exists:

- Use index as orchestration source of truth.
- Treat the index as a Wave/Phase progress surface only; detailed task checkbox truth remains in the corresponding phase files.
- Execute phases strictly in declared order.
- Do not start a phase without prior phase `Entry Gate` prerequisites met.
- After each phase, verify `Exit Gate` evidence, update the Phase checkbox, and recompute any affected Wave checkbox from underlying phase-file truth.
- Reject cross-plan direct task-ID dependencies; require phase gate tokens.

## Verification & Gate Ordering

Default order:

`Task N` -> `Task N-V` -> `metis` completion-status review (when required) -> `oracle` deep review / plan-revision guidance (when required)

Rules:

- Do not start downstream tasks before paired `Task N-V` passes.
- Load `verification-before-completion` before any `Task N-V` or evidence-backed completion.
- When a completion-status review is needed, use `metis` first to detect omissions, hidden issues, and scope drift.
- If Metis finds plan-level gaps, route to `oracle` for deeper analysis and structured plan-revision guidance, then stop runtime and request explicit repair/replan through the owning planning or `repairing-plans` path rather than patching the plan in place.
- If `Task N-V` fails, reopen parent task, fix, collect fresh evidence, and rerun.
- After a `Task N-V` node passes, perform an atomic commit of the relevant implementation and verification changes before starting the next implementation task. Do not batch multiple `Task N-V` closures into one commit.
- If `Task N-V` fails or any previously closed node reopens, recompute the affected Phase/Wave index state before continuing.
- Escalate after 2 failed reruns or immediately when evidence is ambiguous/contradictory.

## Normalization Protocol

Before execution:

1. Validate header contract.
2. Scan for nested executable checklist/bullets.
3. If newly generated malformed structure: reject and return for flattening.
4. If legacy/repairable structure: normalize into explicit tracked subtasks.
5. Re-run structural consistency gate after normalization.

Nested-item classification:

- Checkbox nested item => executable => normalize.
- Action-verb nested item (add/create/write/run/verify/update/delete/refactor/test/capture) => executable => normalize.
- Pure notes/file lists/labels with no action semantics => keep as notes.

## Structural Consistency Gate

Before executing any task, verify:

- Waves/TODO/dependency/verification reference the same task set.
- All dependency references point to existing tasks.
- Contract constants remain consistent across task body, QA, and verification.
- Every task either declares `category` / `subagent_type` or carries a justified deferred-routing marker (`executor_judgment` / `routing_by_executor`).
- Atlas-executed coding branches cannot omit `subagent-driven-development`; if the supplied plan depends on another execution workflow, stop and request repair or rerouting instead of adapting the workflow silently.
- Final verification does not claim features with no implementation task.

If any check fails, stop and return plan for repair.

## Evidence Discipline

- Do not mark a task complete without concrete evidence.
- Ensure required artifacts are written under declared `evidence/` path before review gates.
- If evidence root is missing, fallback to `evidence/<plan-filename-basename>/task-n-*`.

## Bounded Runtime Escalation Protocol

Use runtime escalation only when all of the following are true:

- The task boundary remains unchanged.
- The business intent remains unchanged.
- The work is harder than expected due to execution complexity, not because the plan omitted deliverables.
- Concrete evidence exists (for example: broader-than-expected discovery surface, higher coupling, or need for stronger reasoning/domain capability).

Allowed escalation actions within the same node:

- Raise category within the same task boundary when lower-cost execution is no longer sufficient (for example `unspecified-low` -> `unspecified-high` -> `deep`).
- Re-route the current node to the correct domain category when the execution surface proves different in kind while the same task boundary still holds (for example UI/screenshot work requiring `visual-engineering`).
- Add extra evidence capture or checkpoint notes needed to preserve auditability.

Forbidden even during escalation:

- Expanding scope or adding unplanned deliverables.
- Using escalation to swallow an under-decomposed task that should be split.
- Premium-tier escalation without evidence.
- Silent routing changes without an audit record.

Every escalation record must include:

- `escalation_reason`
- `from -> to`
- `evidence`
- `why_task_boundary_still_holds`
- `repair_required_afterward`

If `repair_required_afterward = true`, Atlas must stop after the current node's evidence is captured and request explicit plan repair before executing the next node.

## Parent Completion Rule

A parent task cannot be marked complete while any of the following remains incomplete:

- normalized executable child task
- paired verification task
- required checklist item

## Review Rejection Loop

When plan defines a review gate:

1. Run the reviewer loop with evidence.
2. If rejected, do not proceed; fix according to feedback.
3. Re-run review until explicit OKAY.

## Subagent-Driven Execution Core

Atlas uses `subagent-driven-development` as the default execution model for coding work.

- The provided plan must already be decomposed and review-ready for task-scoped subagent execution.
- Atlas must keep fresh-subagent-per-task execution as the core workflow and preserve the accompanying review loop.
- If the supplied plan actually requires staged sequential execution, batch handoff, or another workflow, Atlas must stop, record evidence, and request upstream repair or rerouting; Atlas does not silently downgrade to `executing-plans`.
- Cross-session or non-Atlas execution models are upstream routing decisions, not runtime improvisations inside Atlas.

## Boundary with `repairing-plans`

This skill does not replace `repairing-plans`.

- If plan is structurally invalid but repairable at document level, stop and request explicit manual repair.
- Manual repair workflow is defined only in `repairing-plans`.
- Do not embed `repairing-plans` hard-gate details here.

## Output Requirements for Atlas Runtime

During execution updates, always keep:

- current node status
- verification status for paired `Task N-V`
- evidence pointer/path
- blocker/escalation state
- escalation audit record when runtime escalation occurs
- next executable node
- current Phase/Wave index state when executing a `plan-set`

## Common Mistakes

- Skipping `Task N-V` because implementation "looks done"
- Normalizing nested executables but not updating dependencies
- Marking parent complete while child verification remains open
- Leaving a Phase/Wave checked after one of its underlying tasks or verification nodes reopens
- Running review gate without evidence artifacts
- Batch-closing multiple `Task N-V` nodes without an atomic commit after each verified closure
- Guessing through contradictory plan sections instead of stopping
- Expanding a task scope under the label of runtime escalation, or escalating routing without the bounded escalation audit record
- Continuing to execute a premium-tier task when it clearly doesn't need premium capability
