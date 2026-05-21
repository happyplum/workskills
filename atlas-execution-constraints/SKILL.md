---
name: atlas-execution-constraints
description: Use when Atlas needs deterministic execution governance for reliable large-task execution, including verification ordering, normalization, evidence discipline, and escalation boundaries before or during execution.
---

# Atlas Execution Constraints

## Overview

Source of truth for Atlas execution-time constraints. Atlas prompt stays lean; SDD handles decomposition/routing/escalation; `repairing-plans` is a separate manual repair skill. Core principle: execute only what is structurally valid, verifiable, and evidenced.

## Load Conditions

Load when Atlas is about to execute an existing reviewed plan, or during execution when discipline could drift. Use only after plan authoring and review are complete upstream.

## Minimal CSO Triggers

Primary: `atlas execute`, `task n-v`, `execution gate`, `evidence before complete`, `normalize nested tasks`
Secondary: `plan-set entry exit gate`, `phase handoff`, `parent completion rule`, `review rejection loop`

## Counter-Examples (Do Not Trigger)

| Input Pattern | Why not |
|---|---|
| "生成计划" / "write a plan" | Planning stage; use `writing-plans`. |
| "修复计划结构错误" | Document-repair; use `repairing-plans`. |
| "只要解释流程，不执行" | Pure explanation needs no execution governance. |
| "单文件微小文本修正" | Trivial edits need no full constraint stack. |

## Mandatory Rules

1. Enforce preload chain before execution; missing required skill means stop.
2. Execute only against an existing reviewed plan; if missing, contradictory, or not execution-ready, stop and request upstream repair.
3. May convert the approved plan into an execution-only TODO surface as the orchestration layer without reframing as plan authoring.
4. Keep `subagent-driven-development` as the execution core for coding work; do not silently switch to sequential execution.
5. Do not execute downstream tasks before paired `Task N-V` passes.
6. Normalize executable nested items before parent completion decisions.
7. Reject or return plans when structural consistency gate fails; do not guess.
8. Require concrete evidence before completion claims and review gates; keep execution state recoverable. Bounded runtime escalation allowed when task boundary and business intent stay unchanged but execution complexity rises; stop and request repair/replan if under-decomposed, misrouted beyond bounded escalation, or scope change needed.

## Failure Handling

- Header contract missing/contradictory → stop, return plan for repair.
- Verification fails ≥2 reruns or evidence contradictory → escalate.
- Phase gate evidence missing → keep state unchanged, loop fix+reverify.
- Document-level repairable → stop, request explicit `repairing-plans` pass.
- Task or verification reopens → reset affected Phase/Wave checkbox until closure restored.
- Escalation would change task boundary/intent/deliverables → deny, request repair/replan.

## Required Preload Chain

1. `omo-subagent-type` → 2. `subagent-driven-development` → 3. `atlas-execution-constraints` (this skill). Missing any → stop and load first.

## Execution Skill Header Contract

Plan must include `## Execution Skill Requirements` as source of truth for additional skills. Must require `subagent-driven-development` for Atlas coding work; if missing or contradictory with task body, stop and return plan for repair.

## Plan-Set Contract

When `*-index.md` exists: index is orchestration source of truth and Wave/Phase progress surface; detailed checkbox truth remains in phase files. Execute phases strictly in declared order; do not start phase without prior `Entry Gate` prerequisites met. After each phase, verify `Exit Gate` evidence, update Phase checkbox, recompute Wave checkboxes from phase-file truth. Reject cross-plan direct task-ID dependencies; require phase gate tokens.

## Verification & Gate Ordering

Default chain: `Task N` → `Task N-V` → `metis` (when required) → `oracle` (when required).

- Load `verification-before-completion` before any `Task N-V` or evidence-backed completion.
- Metis finds plan-level gaps → route to `oracle` for analysis, then stop and request repair/replan.
- `Task N-V` fails → reopen parent, fix, fresh evidence, rerun; after pass, atomic-commit before next task (no batching).
- Bug-fix: each `Task N`/`Task N-V` pair isolates one independently verifiable bug unless shared root cause and shared verification surface explicitly evidenced.
- Node reopens or `Task N-V` fails → recompute Phase/Wave index state; escalate after 2 failed reruns or ambiguous evidence.

## Normalization Protocol

Before execution: (1) validate header contract, (2) scan for nested executable checklist/bullets, (3) newly generated malformed → reject and return for flattening, (4) legacy/repairable → normalize into tracked subtasks, (5) re-run structural consistency gate.

Nested-item classification: checkbox → executable → normalize; action-verb (add/create/write/run/verify/update/delete/refactor/test/capture) → executable → normalize; pure notes/lists/labels with no action → keep as notes.

## Structural Consistency Gate

Before executing any task, verify all of:

- Waves/TODO/dependency/verification reference the same task set; all dependency refs point to existing tasks.
- Contract constants consistent across task body, QA, and verification.
- Every task declares `category`/`subagent_type` or carries justified deferred-routing marker (`executor_judgment`/`routing_by_executor`).
- Atlas coding branches cannot omit `subagent-driven-development`; if plan depends on another workflow, stop and request repair.
- Final verification does not claim features with no implementation task.

Any check fails → stop and return plan for repair.

## Evidence Discipline

- Do not mark task complete without concrete evidence.
- Required artifacts under declared `evidence/` path before review gates; fallback to `evidence/<plan-filename-basename>/task-n-*`.

## Bounded Runtime Escalation Protocol

Use only when: task boundary unchanged, business intent unchanged, harder due to execution complexity (not omitted deliverables), concrete evidence exists.

Allowed within same node: raise category (e.g. `unspecified-low` → `unspecified-high` → `deep`); re-route to correct domain category when surface proves different in kind; add extra evidence/checkpoint notes.

Forbidden: expanding scope or adding unplanned deliverables; swallowing under-decomposed tasks; premium-tier without evidence; silent routing without audit record.

Every escalation record: `escalation_reason`, `from -> to`, `evidence`, `why_task_boundary_still_holds`, `repair_required_afterward`. If `repair_required_afterward = true`, stop after current node evidence and request plan repair before next node.

## Parent Completion Rule

Parent cannot be marked complete while any remains incomplete: normalized executable child task, paired verification task, required checklist item.

## Review Rejection Loop

When plan defines a review gate: (1) run reviewer loop with evidence, (2) if rejected → fix per feedback, (3) re-run until explicit OKAY.
