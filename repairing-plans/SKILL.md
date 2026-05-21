***

name: repairing-plans
description: Normative specification for validating and repairing existing execution plans, covering task-ID graph integrity, contract consistency, executable QA, routing schema validity, verification closure, and size/decomposition audits.
------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------

# Repairing Plans

## Overview

Second-pass repair workflow for existing plans. Goal: repair plan structure, dependency truth, and verification alignment — not re-scope product intent.

**Core principle:** Repair the document before repairing the code.
**Execution standard:** A plan is Atlas-safe only when all hard gates pass.

## Mandatory Rules

1. **Repair Boundary**: Never re-scope product intent. Repair structure, dependency truth, and verification truth only. Unresolved hard gate → `REJECT`. High-impact ambiguity → ask 1-3 targeted questions first; if still indeterministic → `BLOCKED_NEEDS_DECISION`; never guess.
2. **Deterministic Repair Process**: Enforce one task-ID scheme and one contract constant set before downstream edits. Run deterministic two-pass flow (normalize first, then hard-gate re-evaluation). Keep outputs auditable with explicit gate codes and fixed sections.
3. **Verification Isolation**: Acceptance artifacts must be isolated from implementation tasks. Verification and evidence-collection work must be first-class `Task N-V` nodes, not inlined inside `Task N`.
4. **Checkpoint & Plan-Set Governance**: Require explicit checkpoints and checkpoint-level audit records. For `plan-set`, each sub-plan must include a preflight validation stage re-verifying upstream outputs before current-phase implementation.
5. **Decomposition & Routing Discipline**: Enforce smallest independently executable task granularity. Premium categories (`deep`, `ultrabrain`, `visual-engineering`, `artistry`) reserved for work genuinely requiring specialized capabilities. Every task should declare `category` or `subagent_type`; deferred routing requires `executor_judgment`/`routing_by_executor` with one-line rationale. Premium tasks should include `why_not_lower_cost`.
6. **User-Facing Anti-Drift Surface**: Every plan must include a concise user-readable summary near top. Repaired plans must preserve `## User Requirement Digest` and `## Intent Anchor` without creating a second task-truth source.

## Failure Handling

1. Missing inputs → repair deterministic format issues only and stop.
2. High-impact ambiguity → ask 1-3 targeted questions; if still indeterministic → `BLOCKED_NEEDS_DECISION`.
3. Repeated gate failures after normalization → `REJECT` with failing gate set.
4. No narrative confidence claims; output only enforceable verdict artifacts.

## Prompt Slimming Contract

This skill is the canonical rule source for plan repair/validation. Prometheus delegates repair semantics here. Shared SDD decomposition/routing/escalation doctrine lives in `subagent-driven-development`; this skill enforces it during repair instead of redefining it. If prompt text and this skill drift, this skill wins for plan-repair decisions only. Do not duplicate long hard-gate rule blocks in Prometheus; keep repair-specific gates here.

## Second-Pass Repair Mode (MANDATORY)

1. **Pass 1 — Structural normalization**: normalize execution-skill header, task IDs and dependency graph, flatten nested executables, normalize verification modeling (`Task N`/`Task N-V`).
2. **Pass 2 — Gate re-evaluation**: re-run all hard gates on normalized plan; emit `REJECT` with gate codes for failures; `PASS` only when hard-gate failures = zero.

Never skip Pass 2 after any structural change.

## Checkpoint Audit Model (MANDATORY)

- `CP0 — Intake Baseline`: confirm input contract completeness and checkpoint map before normalization.
- `CP1 — Post-Normalization`: re-compile task graph and dependency closure.
- `CP2 — Verification Closure`: confirm `Task N`/`Task N-V` linkage, QA executability, validation-scope isolation.
- `CP3 — Release Readiness`: final hard-gate summary and decomposition/phase handoff readiness.

Checkpoint audit loop:

1. Run CP0 → repair deterministic issues.
2. Run CP1 and re-evaluate hard gates.
3. If any hard gate fails, repair deterministic issues and return to CP1.
4. Run CP2 after CP1 passes.
5. If CP2 fails, repair and return to CP1.
6. Run CP3 only when CP1 and CP2 pass.
7. Exit only when CP3 passes with zero hard-gate failures; otherwise output `REJECT`.

## Input Contract (MANDATORY)

1. **Single task-ID scheme** — one scheme only across Waves, TODO, dependency matrix, final verification. Do not mix dotted IDs and sequential aliases in the same plan.
2. **Canonical contract constants** declared once near top: `interface_prefix` (for API-style plans, may be `api_prefix`), `versioning_scheme`, `evidence_root`, `primary_stack`.
3. **User-facing summary**: `## User-Facing Summary` near top, written in user's natural language, with `Development Core` and `User Requirements` as concise prose/bullets — not task IDs or routing jargon.
4. **Anti-drift top section**: `## User Requirement Digest` (preserve user's natural-language requirements, constraints, prohibitions, current focus) and `## Intent Anchor` (`Why`/`What`/`Non-Goals`/`Must Not Drift`). If unrecoverable deterministically → ask targeted questions first; `BLOCKED_NEEDS_DECISION` only if ambiguity remains.
5. **Execution-skill header**: `## Execution Skill Requirements` — required in primary plan and each sub-plan file when `decomposition_decision = plan-set`.
6. **Verification mode per task**: `inline` or `Task N-V`. Shared surfaces (contracts, infra, API aggregation, integration boundaries) MUST use `Task N-V`.
7. **Routing declarations**: valid enums for `category`/`subagent_type`/`skills`. Tasks SHOULD declare `category` or `subagent_type`; deferred routing requires `executor_judgment`/`routing_by_executor` + one-line rationale. Premium tasks SHOULD declare `why_not_lower_cost`.
8. **Plan Size Audit block**: `estimated_waves`, `integration_boundaries`, `size_class` (`Small`/`Medium`/`Large`/`XLarge`), `decomposition_decision` (`single-file` or `plan-set`).
9. **Checkpoint map**: `CP0`, `CP1`, `CP2`, `CP3`.
10. **Plan-set index tracking** (when `decomposition_decision = plan-set`):
    - Index file exposes Markdown checkboxes for every Wave and every Phase.
    - Index is summary surface only; detailed task checkbox state lives in phase files.
    - Wave checkbox: checked only when all implementation tasks + paired `Task N-V` nodes complete.
    - Phase checkbox: checked only when all executable tasks + paired verification nodes complete.
11. **Sub-plan preflight validation** (when `decomposition_decision = plan-set`):
    - Each phase file must include a preflight validation stage before implementation tasks.
    - Stage validates upstream outputs, unresolved blockers, and interface/contract compatibility.

Plan size rubric (highest matched level wins): `Small` (waves ≤2, boundaries ≤1) | `Medium` (waves=3 or boundaries=2) | `Large` (waves 4-5 or boundaries=3) | `XLarge` (waves>5 or boundaries≥4).

Decomposition policy: `Small` may use `single-file` or `plan-set`. `Medium`/`Large`/`XLarge` MUST use `plan-set`; `single-file` is invalid.

Plan-set file structure: sub-plan files placed directly in the same directory as the original plan file. Never create a new subfolder. Original plan file converts in-place to the index file, retaining its original filename. Phase files are named with phase suffix (e.g., `my-feature-plan-phase-1.md`).

Index file format: `- [ ] Wave N: name` and `- [ ] Phase N: name` with links to phase files. Update Phase/Wave checkboxes immediately on completion. Reset to unchecked if any underlying task or verification node reopens.

If any required input is missing, auto-repair only deterministic structure/format items. For high-impact missing business decisions, ask targeted clarification questions first; if ambiguity remains, emit `BLOCKED_NEEDS_DECISION` and stop.

## Required Checks

1. **Execution Skill Header** — Ensure `## Execution Skill Requirements` present. Classify skills into `Always preload`, `Conditionally load`, `Task-local only`. Declare execution mode and selection rationale for conditional skills.
2. **Task Executor Annotation** — Every task declares `category`/`subagent_type` unless deferred with `executor_judgment`/`routing_by_executor` + one-line reason. Premium tasks include `why_not_lower_cost`. Gate: `TASK_EXECUTOR_ANNOTATION_WEAK` (soft warning when omitted or premium lacks rationale).
3. **User-Facing Summary** — `## User-Facing Summary` near top with `Development Core` and `User Requirements` in concise user-readable language. Gate: `USER_SUMMARY_MISSING` (fail when missing, omits either field, or is executor shorthand only). Repair: synthesize from user request + settled scope; if unrecoverable → ask questions first, then `BLOCKED_NEEDS_DECISION`.
4. **Anti-Drift Top Section** — `## User Requirement Digest` + `## Intent Anchor` near top. Digest preserves user natural-language requirements/constraints/prohibitions; anchor captures `Why`/`What`/`Non-Goals`/`Must Not Drift`. Gate: `ANTI_DRIFT_TOP_SECTION_MISSING` (fail when either missing, digest rewritten in jargon, or anchor fields omitted). Repair: preserve user natural language in digest, distill anchor from explicit context; if unrecoverable → ask questions first, then `BLOCKED_NEEDS_DECISION`.
5. **Task Flattening** — Promote executable nested bullets/checklists into `Task N`/`Task N.a`/`Task N-V`. Keep notes, file lists, and explanatory bullets nested only if non-executable. Gate: `NESTED_EXECUTABLES_FOUND` (fail when executable nested items remain after normalization).
6. **Identifier Integrity** — Waves, task list, dependency matrix, and verification reference same task IDs. Remove phantom dependencies and missing references. Gate: `ID_GRAPH_MISMATCH` (fail on duplicate IDs, unknown IDs, phantom dependencies, references to non-existent nodes, or mixed-ID aliasing).
7. **Verification Pairing** — Implementation tasks with acceptance/evidence content require paired `Task N-V` as first-class node (in TODO, Wave, dependency matrix). No `Task N-V` needed when no acceptance content. Downstream dependencies must also depend on `Task N-V` when it exists. Gate: `VERIFY_CLOSURE_MISSING` (fail when downstream/final verification depends on implementation outputs but omits required verification node; `Task N-V` must be first-class, not a section within `Task N`).
8. **Contract Consistency** — Route prefixes, naming, storage paths, feature scope match across task body, QA, and final verification. Final verification must not claim features with no implementation task. Gate: `CONTRACT_DRIFT`.
9. **Task Graph Compilation** — Compile Waves + TODO + dependency matrix + verification references into one graph. Reject duplicate IDs, unknown IDs, phantom dependencies, unreachable required nodes, and mixed-ID aliasing.
10. **QA Executability** — Each QA block must include: `Tool`, `Preconditions`, `Commands/Inputs`, `Expected Observable`, `Evidence`. Gate: `QA_NOT_EXECUTABLE` (fail when QA lacks concrete commands + expected observable + evidence target; reject narrative-only steps. For `Tool: Bash`, require runnable command lines, not prose verbs).
11. **Verification Closure** — Shared surfaces must use `Task N-V`; downstream/final verification must depend on `Task N-V`, not only `Task N`. `inline` allowed only for non-shared local tasks with no downstream consumers. Repair: create `Task N-V` as first-class node and add dependency edges from downstream consumers.
12. **Stack/Routing Congruence** — Validate routing against actual project stack and allowed enums. Gate: `ROUTING_SCHEMA_INVALID` (fail when routing uses unsupported value. Allowed `category`: `visual-engineering`, `ultrabrain`, `deep`, `artistry`, `quick`, `unspecified-low`, `unspecified-high`, `writing`. Allowed `subagent_type`: `explore`, `librarian`, `oracle`, `metis`, `momus`). Gate: `STACK_MISMATCH_BLOCKING` (fail when stack declarations contradict executable tasks/QA paths without declared exception).
13. **Nested Executables Gate** — Detect executable nested checklists/bullets that should be task nodes. Reject plans keeping executable nested work as prose after normalization.
14. **Plan Size Audit** — `Plan Size Audit` block present with required fields. Recompute from `estimated_waves`/`integration_boundaries`. Gate: `PLAN_SIZE_AUDIT_MISSING` (fail when block missing or declared ≠ computed). Gate: `PLAN_SET_REQUIRED` (fail when `Medium`/`Large`/`XLarge` but not `plan-set`).
15. **Parallelization Audit** — Prefer smallest independently executable tasks. Planning/plan-check tasks require `parallel-safe`/`serial-only` declaration. Gate: `PARALLEL_DECLARATION_MISSING` (fail when label missing or `serial-only` lacks one-line constraint reason). Reject forced serial execution for independent tasks without constraint justification. For `Medium`/`Large`/`XLarge`, verify decomposition into multiple plan files with phase-level handoff gates.
16. **Validation Scope Isolation** — Implementation tasks must not contain acceptance criteria, evidence capture lists, or deliverable-proof checklists. These must live only in `Task N-V` or checkpoint audit blocks. Gate: `VALIDATION_SCOPE_LEAK` (fail when found in implementation bodies). Repair: strip all acceptance/evidence content (including `### Acceptance Criteria`, `#### Acceptance Criteria`, `### Success Criteria`, `AC:`-prefixed bullets, evidence capture checklists, deliverable-proof items) from `Task N` body → relocate to `Task N-V` QA block; create `Task N-V` as first-class node if missing.
17. **Checkpoint Coverage** — Require explicit `CP0`/`CP1`/`CP2`/`CP3` definitions. Checkpoint outputs must map to gate status, fixed sections, and unresolved blockers. Gate: `CHECKPOINT_MISSING` (fail when nodes missing, unordered, or not mapped to audit outputs).
18. **Index Status Synchronization** — For `plan-set`, index must have Wave/Phase checkboxes as summary; task truth in phase files. Gate: `INDEX_STATE_SYNC_MISSING` (fail when no checkboxes, duplicated task state, or lacks completion rules). Repair: add checkboxes, link phases, remove duplicated task state, define Phase completion as all executable tasks + paired verification nodes complete, define Wave completion as all implementation tasks + paired `Task N-V` nodes complete, reset affected checkbox if any underlying task reopens.
19. **Sub-Plan Preflight Validation** — For `plan-set`, each phase file must begin with preflight validation checking upstream blockers/contracts before implementation. Gate: `SUBPLAN_PREFLIGHT_MISSING` (fail when absent).
20. **Task Routing Tier Audit** — Two-tier model: Premium (`deep`, `ultrabrain`, `visual-engineering`, `artistry`) for specialized capabilities only; Standard (`unspecified-high`, `unspecified-low`, `quick`, `writing`) as default. Decomposition completeness: if task can be further split into smaller independent units → `TASK_UNDER_DECOMPOSED` (hard failure). Premium on routine task → `ROUTING_OVERKILL` (hard failure). Complex task routed to `quick`/`unspecified-low` → `ROUTING_UNDERKILL` (soft warning). Repair: downgrade overkill to standard tier and decompose if scope exceeds standard capacity. Every task SHOULD declare `category`/`subagent_type`; deferred requires `executor_judgment`/`routing_by_executor` + one-line rationale. Premium tasks SHOULD include `why_not_lower_cost`.

## Repair Order

1. Execution-skill header, executor annotations, routing enums
2. User-facing summary (`## User-Facing Summary`, `Development Core`, `User Requirements`)
3. Anti-drift top section (`## User Requirement Digest`, `## Intent Anchor`)
4. Canonical contract drift (`interface_prefix`, `versioning_scheme`, `evidence_root`, scope)
5. Checkpoint map (`CP0`/`CP1`/`CP2`/`CP3`) and output schema
6. Unified task graph (IDs + dependencies)
7. Flatten executable nested work
8. Plan size audit and decomposition decision
9. Verification closure (`Task N`/`Task N-V`); strip acceptance criteria from `Task N` → relocate to `Task N-V` QA block
10. Plan-set index state model (Wave/Phase checkboxes + completion sync); recompute after any `Task N-V` creation or reopened node
11. Sub-plan preflight validation stages (plan-set only)
12. QA executability and validation-scope isolation
13. Checkpoint loop to closure (`CP1`→`CP2`→`CP3`) and hard-gate re-evaluation
14. Task routing tier audit and decomposition of overkill tasks into standard-tier units

## Output Requirements

Produce:

- `Verdict`: `PASS` or `REJECT`
- `Gate Summary`: count of failing hard gates by code
- `Hard Gates`: list gate code + failing sections
- `Warnings`: non-blocking quality issues
- `Fixed Sections`: exact sections changed
- `Needs Decision`: items requiring human product/contract decisions
- `Checkpoint Report`: CP0/CP1/CP2/CP3 status, loop iterations, unresolved blockers
- `User-Facing Summary`: confirmation that `Development Core` and `User Requirements` exist near top in user-readable language
- `Requirement Digest`: confirmation that `## User Requirement Digest` preserves user's natural-language requirements without drift
- `Intent Anchor`: confirmation that `## Intent Anchor` captures `Why`/`What`/`Non-Goals`/`Must Not Drift` consistently
- `Validation Scope`: confirmation that acceptance/evidence checks are isolated to verification tasks/checkpoints
- `Plan Size`: computed class, declared class, and decomposition verdict
- `Index State`: for `plan-set`, confirmation that Wave/Phase checkboxes exist, completion/reset criteria are defined, and checked state matches phase-file truth

Any `BLOCKED_NEEDS_DECISION` item open → verdict MUST be `REJECT`.

## Hard Gates vs Soft Warnings

### Hard Gates (must be zero to PASS)

`ID_GRAPH_MISMATCH` · `ROUTING_SCHEMA_INVALID` · `CONTRACT_DRIFT` · `QA_NOT_EXECUTABLE` · `VERIFY_CLOSURE_MISSING` · `STACK_MISMATCH_BLOCKING` · `NESTED_EXECUTABLES_FOUND` · `PLAN_SIZE_AUDIT_MISSING` · `PLAN_SET_REQUIRED` · `PARALLEL_DECLARATION_MISSING` · `CHECKPOINT_MISSING` · `VALIDATION_SCOPE_LEAK` · `USER_SUMMARY_MISSING` · `ANTI_DRIFT_TOP_SECTION_MISSING` · `INDEX_STATE_SYNC_MISSING` · `SUBPLAN_PREFLIGHT_MISSING` · `ROUTING_OVERKILL` · `TASK_UNDER_DECOMPOSED`

### Soft Warnings

`ROUTING_HEURISTIC_WEAK` · `TASK_EXECUTOR_ANNOTATION_WEAK` · `THRESHOLD_UNJUSTIFIED` · `NOISY_VERIFICATION` · `ROUTING_UNDERKILL`

## Escalation Flow

1. Auto-fix deterministic text issues (ID remap, explicit dependency edges, header enum corrections, contract alignment).
2. High-impact ambiguous product decisions → ask 1-3 targeted questions; if still indeterministic → `BLOCKED_NEEDS_DECISION`. Examples: choose `/api/` vs `/api/v1/`, include or remove a feature from verification scope, user requirements and intent anchor cannot be mapped consistently.
3. Never guess business intent to "force pass".

## Integration with Atlas/Prometheus

- Canonical structural-repair landing path for authoritative plan edits. Used before execution and after review-driven defect discovery.
- Defines what a structurally valid, repair-complete plan looks like; does not own runtime execution ordering, evidence discipline, or commit timing.
- Atlas consumes this as the normative repair spec. Prometheus provides compact routing intent; this skill expands and enforces concrete repair gates.
- `metis` may expose omissions, `oracle` may produce revision briefs; authoritative structural repair lands through this skill, not inline patching during execution.
- Output emitted inline in the current review message; no separate artifact file required.
