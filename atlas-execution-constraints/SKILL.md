---
name: atlas-execution-constraints
description: Use when Atlas needs deterministic execution governance for plan/task completion, verification ordering, normalization, evidence discipline, and escalation boundaries before or during execution.
---

# Atlas Execution Constraints

## Overview

This skill is the source of truth for Atlas execution-time constraints.

- Atlas prompt stays lean and only routes into this skill.
- Execution constraints live here, not in prompt text.
- `repairing-plans` remains a separate manual repair skill.

Core principle: execute only what is structurally valid, verifiable, and evidenced.

## Load Conditions

Load this skill when Atlas is about to execute a plan and needs deterministic runtime constraints.

- Use after plan authoring is complete and execution is about to start.
- Use during execution when verification ordering, normalization, or evidence discipline could drift.

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
2. Do not execute downstream tasks before paired `Task N-V` passes.
3. Normalize executable nested items before parent completion decisions.
4. Reject or return plans when structural consistency gate fails; do not guess.
5. Require concrete evidence before completion claims and before review gates.
6. Keep execution state recoverable with truthful status/evidence updates.
7. If a task is discovered to be under-decomposed or misrouted during execution, do NOT expand or self-upgrade routing. Stop the node, record evidence, and request plan repair/replan.

## Failure Handling

1. If skill header contract is missing/contradictory, stop and return plan for repair.
2. If verification repeatedly fails (>=2 reruns) or evidence is contradictory, escalate.
3. If phase gate evidence is missing, keep phase/index state unchanged and loop fix+reverify.
4. If issue is document-level repairable, stop runtime and request explicit manual `repairing-plans` pass.
5. If any executable task or paired verification node reopens, reset the affected Phase/Wave checkbox until closure is restored from underlying phase-file truth.

## Required Preload Chain

Before execution, ensure this load order:

1. `writing-plans`
2. `omo-subagent-type`
3. `executing-plans`
4. `atlas-execution-constraints` (this skill)

If any required skill is missing, stop and load it first.

## Execution Skill Header Contract

- Plan must include `## Execution Skill Requirements`.
- Treat that section as source of truth for additional skills.
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

`Task N` -> `Task N-V` -> milestone quality gate (when required)

Rules:

- Do not start downstream tasks before paired `Task N-V` passes.
- Load `verification-before-completion` before any `Task N-V` or evidence-backed completion.
- If `Task N-V` fails, reopen parent task, fix, collect fresh evidence, and rerun.
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
- Final verification does not claim features with no implementation task.

If any check fails, stop and return plan for repair.

## Evidence Discipline

- Do not mark a task complete without concrete evidence.
- Ensure required artifacts are written under declared `evidence/` path before review gates.
- If evidence root is missing, fallback to `evidence/<plan-filename-basename>/task-n-*`.

## Parent Completion Rule

A parent task cannot be marked complete while any of the following remains incomplete:

- normalized executable child task
- paired verification task
- required checklist item

## Review Rejection Loop

When plan defines `@metis -> @momus` quality gates:

1. Run the reviewer loop with evidence.
2. If rejected, do not proceed; fix according to feedback.
3. Re-run full quality-gate cycle until explicit OKAY.

## Routing for Mostly-Independent Work

- If execution is same-session and tasks are mostly independent, load `subagent-driven-development`.
- If task outputs are tightly coupled or share mutable state requiring negotiation, do not classify as mostly independent.
- For batch-style/staged handoff, keep `executing-plans` as primary.

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
- next executable node
- current Phase/Wave index state when executing a `plan-set`

## Common Mistakes

- Skipping `Task N-V` because implementation "looks done"
- Normalizing nested executables but not updating dependencies
- Marking parent complete while child verification remains open
- Leaving a Phase/Wave checked after one of its underlying tasks or verification nodes reopens
- Running review gate without evidence artifacts
- Guessing through contradictory plan sections instead of stopping
- Expanding a task scope or self-upgrading routing during execution instead of stopping and requesting repair
- Continuing to execute a premium-tier task when it clearly doesn't need premium capability
