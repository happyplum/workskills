***

name: repairing-plans
description: Normative specification for validating and repairing existing execution plans, covering task-ID graph integrity, contract consistency, executable QA, routing schema validity, verification closure, and size/decomposition audits.
------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------

# Repairing Plans

## Overview

This skill defines a second-pass repair workflow for existing plans. The goal is not to re-scope the project; the goal is to repair plan structure, dependency truth, and verification alignment so execution does not guess.

**Core principle:** Repair the document before repairing the code.
**Execution standard:** A plan is Atlas-safe only when all hard gates pass.

## Mandatory Rules

1. **Repair Boundary**: Never re-scope product intent; repair structure, dependency truth, and verification truth only. When a hard gate remains unresolved, emit `REJECT`. For high-impact ambiguity, ask 1-3 targeted clarification questions first; if the answer still cannot be recovered deterministically, emit `BLOCKED_NEEDS_DECISION`; never guess.
2. **Deterministic Repair Process**: Enforce one task-ID scheme and one contract constant set before downstream edits. Run deterministic two-pass flow (normalize first, then hard-gate re-evaluation), and keep outputs auditable with explicit gate codes and fixed sections.
3. **Verification Isolation**: Keep acceptance artifacts isolated from implementation tasks. Do not place acceptance criteria, evidence capture lists, or deliverable-proof checks inside implementation task bodies. Verification and evidence-collection work must be promoted to first-class `Task N-V` nodes rather than inlined inside `Task N`.
4. **Checkpoint & Plan-Set Governance**: Require explicit checkpoints and checkpoint-level audit records for structural repair, verification closure, and release-readiness decisions. For `plan-set` decomposition, require each sub-plan to include a preflight validation stage that re-verifies upstream outputs for blockers before current-phase implementation starts.
5. **Decomposition & Routing Discipline**: Enforce smallest independently executable task granularity. Premium categories (`deep`, `ultrabrain`, `visual-engineering`, `artistry`) are reserved for work that genuinely requires their specialized capabilities. Every `Task N` / `Task N-V` should declare `category` or `subagent_type`; if routing is intentionally deferred, require `executor_judgment` or `routing_by_executor` with a one-line rationale. Keep routing economical: premium-tier tasks should include `why_not_lower_cost`, and weak executor annotation is a quality warning unless ambiguity becomes execution-blocking.
6. **User-Facing Anti-Drift Surface**: Require every plan to include a concise user-readable summary of the current development core and requirements near the top, and require every repaired plan to preserve a lightweight anti-drift top section (`## User Requirement Digest` and `## Intent Anchor`) without creating a second task-truth source.

## Failure Handling

1. If required inputs are missing, repair only deterministic format issues and stop.
2. If ambiguity is high-impact and can be resolved by a short clarification loop, ask 1-3 targeted questions first; if the answer still cannot be recovered deterministically, return `BLOCKED_NEEDS_DECISION`.
3. If repeated gate failures persist after normalization, return `REJECT` with failing gate set.
4. Do not fall back to narrative confidence claims; output only enforceable verdict artifacts.

## Prompt Slimming Contract (Source of Truth)

This skill is the canonical rule source for plan repair/validation.

- Prometheus should stay lean and delegate repair semantics here.
- If prompt text and this skill drift, this skill wins for all repair decisions.
- Do not duplicate long hard-gate rule blocks in Prometheus; keep them here.

## Second-Pass Repair Mode (MANDATORY)

For extension/review of an existing plan, run a deterministic two-pass flow:

1. **Pass 1 — Structural normalization**
   - normalize execution-skill header
   - normalize task IDs and dependency graph
   - flatten nested executable items into task nodes
   - normalize verification modeling (`Task N` / `Task N-V`)
2. **Pass 2 — Gate re-evaluation**
   - re-run all hard gates on the normalized plan
   - emit remaining failures as `REJECT` with gate codes
   - emit `PASS` only when hard-gate failures are zero

Never skip Pass 2 after any structural change.

## Checkpoint Audit Model (MANDATORY)

Every repaired plan must define checkpoint nodes and produce checkpoint-level audit outputs.

- `CP0 — Intake Baseline`: confirm input contract completeness and checkpoint map before any normalization.
- `CP1 — Post-Normalization`: after structural normalization, re-compile task graph and dependency closure.
- `CP2 — Verification Closure`: confirm `Task N` / `Task N-V` linkage, QA executability, and validation-scope isolation.
- `CP3 — Release Readiness`: final hard-gate summary and decomposition/phase handoff readiness.

Checkpoint audit loop:

1. Run CP0 -> repair deterministic issues.
2. Run CP1 and re-evaluate hard gates.
3. If any hard gate fails, repair deterministic issues and return to CP1.
4. Run CP2 after CP1 passes.
5. If CP2 fails, repair and return to CP1.
6. Run CP3 only when CP1 and CP2 pass.
7. Exit only when CP3 passes with zero hard-gate failures; otherwise output `REJECT`.

## Input Contract (MANDATORY)

Before any repair, enforce these plan-level inputs:

1. **Single task-ID scheme** (one scheme only across Waves, TODO, dependency matrix, final verification)
   - Do not mix dotted IDs and sequential aliases in the same plan (for example, `2.1` with `Task 7` as an alias)
2. **Canonical contract constants** declared once near top:
   - `interface_prefix` (for API-style plans, this may be `api_prefix`)
   - `versioning_scheme`
   - `evidence_root`
   - `primary_stack`
3. **User-facing summary present**: `## User-Facing Summary`
   - Required near the top of the plan for fast user reading
   - Must include `Development Core` and `User Requirements`
   - Must be written in the natural language used to communicate with the user for this request, or the plan's primary user-facing language when that is already fixed
   - Must describe the current development core and requirements in concise user-readable prose/bullets, not only task IDs, file paths, or routing jargon
4. **Anti-drift top section present**: `## User Requirement Digest` and `## Intent Anchor`
   - Required near the top of the repaired plan, immediately after the user-facing summary or close to it
   - `## User Requirement Digest` must preserve the user's natural-language requirements, constraints, prohibitions, and current focus without rewriting them into task jargon
   - `## Intent Anchor` must capture `Why`, `What`, `Non-Goals`, and `Must Not Drift` in concise prose/bullets
   - If any of these fields cannot be recovered deterministically from explicit user context and settled scope, ask targeted clarification questions first; emit `BLOCKED_NEEDS_DECISION` only if ambiguity remains
5. **Execution-skill header present**: `## Execution Skill Requirements`
   - Required in the primary plan and in each sub-plan file when `decomposition_decision = plan-set`
6. **Verification mode per task**: `inline` or `Task N-V`
   - Shared surfaces (contracts, infra, API aggregation, integration boundaries) MUST use `Task N-V`
7. **Routing declarations are valid enums** for category/subagent_type/skills
   - Every `Task N` / `Task N-V` SHOULD declare `category` or `subagent_type`
   - If routing is intentionally deferred, the task SHOULD declare `executor_judgment` or `routing_by_executor` with a one-line rationale
   - Premium-tier tasks SHOULD declare `why_not_lower_cost`
8. **Plan Size Audit block present** with deterministic fields:
   - `estimated_waves`
   - `integration_boundaries`
   - `size_class` (`Small` / `Medium` / `Large` / `XLarge`)
   - `decomposition_decision` (`single-file` or `plan-set`)
9. **Checkpoint map present** with fixed nodes: `CP0`, `CP1`, `CP2`, `CP3`
10. **Plan-set index tracking model present** when `decomposition_decision = plan-set`

- The index file MUST expose Markdown checkboxes for every `Wave` and every `Phase`
- The index file is the high-level progress surface only; detailed task checkbox state remains in the corresponding phase files
- A `Wave` checkbox may be checked only when every implementation task assigned to that `Wave` and every paired `Task N-V` verification node are complete
- A `Phase` checkbox may be checked only when that phase file's executable tasks and required verification nodes are complete

11. **Sub-plan preflight validation stage present** for each phase file when `decomposition_decision = plan-set`

- Stage must validate upstream outputs, unresolved blockers, and interface/contract compatibility before implementation tasks

Plan size rubric (highest matched level wins):

- `Small`: waves <= 2, integration boundaries <= 1
- `Medium`: waves = 3, or integration boundaries = 2
- `Large`: waves = 4-5, or integration boundaries = 3
- `XLarge`: waves > 5, or integration boundaries >= 4

Decomposition policy:

- `Small` may use `single-file` or `plan-set`.
- `Medium`, `Large`, `XLarge` MUST use `plan-set` (index + phase files). `single-file` is invalid.

Plan-set file structure rules:

- All sub-plan files MUST be placed directly in the **same directory** as the original plan file.
- **NEVER** create a new subfolder for the decomposed files.
- The original plan file is converted in-place to the index file and **retains its original filename** (e.g., `my-feature-plan.md` stays as `my-feature-plan.md`).
- Phase files are created alongside the index file in the same directory, named by extending the original plan name with a phase suffix (e.g., `my-feature-plan-phase-1.md`, `my-feature-plan-phase-2.md`).

Index file format requirements:

- The index file **MUST** use Markdown checkbox syntax for every Wave entry: `- [ ] Wave N: name`.
- The index file **MUST** use Markdown checkbox syntax for every Phase entry: `- [ ] Phase N: name`.
- Each Phase entry in the index **SHOULD** link to its corresponding phase file.
- The index file is a summary surface only: detailed task status and task-level checkboxes belong in the split phase files, not duplicated in the index.
- The index file MAY include a short `## Execution Intent Snapshot`, but it must stay lightweight: 1-2 sentences of user-facing intent plus brief `Why`/`What`, with an explicit note that task truth lives in the phase files.
- When a Phase completes, update its checkbox in the index immediately.
- When a Wave completes, update its checkbox in the index immediately.
- A Phase checkbox can be checked only when every executable task in that Phase and every paired `Task N-V` verification node are complete.
- A Wave checkbox can be checked only when every implementation task in that Wave and every paired `Task N-V` verification node are complete.
- If any task or paired verification node in a Phase is reopened, the Phase checkbox MUST be reset to unchecked until closure is restored.
- If any task or paired verification node in a Wave is reopened, the Wave checkbox MUST be reset to unchecked until closure is restored.

If any required input is missing, auto-repair only deterministic structure/format items. For high-impact missing business decisions, ask targeted clarification questions first; if ambiguity remains, emit `BLOCKED_NEEDS_DECISION` and stop.

## Required Checks

1. **Execution Skill Header**
   - Ensure the plan has `## Execution Skill Requirements`
   - Classify skills into `Always preload`, `Conditionally load`, `Task-local only`
   - Declare execution mode and selection rationale for conditional skills
2. **Task Executor Annotation**
   - Ensure every `Task N` / `Task N-V` declares `category` or `subagent_type`, unless routing is intentionally deferred with `executor_judgment` or `routing_by_executor`
   - Ensure deferred routing includes a one-line reason that preserves economic routing intent
   - Ensure premium-tier tasks include `why_not_lower_cost` when specialized capability is required
3. **User-Facing Summary**
   - Ensure the plan has `## User-Facing Summary` near the top
   - Ensure it includes both `Development Core` and `User Requirements`
   - Ensure the content is concise and user-readable, summarizing the current development core and requirements without collapsing into task-ID/file-path jargon
4. **Anti-Drift Top Section**
   - Ensure the repaired plan has both `## User Requirement Digest` and `## Intent Anchor` near the top
   - Ensure the digest stays close to the user's natural-language requirements, constraints, prohibitions, and current focus
   - Ensure the anchor captures `Why`, `What`, `Non-Goals`, and `Must Not Drift` without duplicating task truth
   - If these sections cannot be recovered deterministically, ask targeted clarification questions before emitting `BLOCKED_NEEDS_DECISION`
5. **Task Flattening**
   - Promote executable nested bullets/checklists into top-level tasks (`Task N`, `Task N.a`, `Task N-V`)
   - Keep notes, file lists, and explanatory bullets nested only if they are non-executable
6. **Identifier Integrity**
   - Make Waves, task list, dependency matrix, and verification tasks reference the same task IDs
   - Remove phantom dependencies and missing task references
7. **Verification Pairing**
   - When an implementation task contains acceptance criteria, evidence capture, or verification content, a paired `Task N-V` must exist as a **first-class task node** — it must appear in the TODO list, Wave assignment, and dependency matrix as an independent executable task, not as a section within `Task N`.
   - If an implementation task has no acceptance criteria or verification content, no `Task N-V` is needed.
   - Downstream dependencies on `Task N` must also depend on `Task N-V` when `Task N-V` exists.
   - **Repair action**: When `Task N` contains acceptance criteria/evidence content but `Task N-V` is missing, create `Task N-V` as a first-class task node (TODO entry, Wave assignment, dependency matrix entry, routing declaration). Strip all verification content from `Task N` body (including `### Acceptance Criteria`, `#### Acceptance Criteria`, `### Success Criteria`, `AC:`-prefixed bullets, evidence capture checklists, deliverable-proof items) and relocate to `Task N-V`.
8. **Contract Consistency**
   - Route prefixes, naming rules, storage paths, and feature scope must match across task body, QA, and final verification
   - Final verification must not claim features with no implementation task
9. **Task Graph Compilation (NEW)**
   - Compile Waves + TODO + dependency matrix + final verification references into one graph
   - Reject duplicate IDs, unknown IDs, phantom dependencies, and unreachable required nodes
   - Reject mixed-ID aliasing (same logical task expressed in two ID systems)
10. **QA Executability (NEW)**
   - Each QA block must include:
     - `Tool`
     - `Preconditions`
     - `Commands/Inputs`
     - `Expected Observable`
     - `Evidence`
   - Reject narrative-only steps (e.g., “调用/验证/等待”) without concrete executable actions
   - For `Tool: Bash`, require runnable command lines instead of prose verbs
11. **Verification Closure**
   - For shared surfaces (contracts, infra, API aggregation, integration boundaries), verification must be modeled as `Task N-V`
   - Downstream and final verification must depend on `Task N-V`, not only `Task N`
   - `inline` verification is allowed only for non-shared local tasks with no downstream dependency consumers
   - **Repair action**: When a shared-surface task lacks `Task N-V`, create one as a first-class task node and add dependency edges from downstream consumers. When downstream tasks depend on `Task N` only, add dependency on `Task N-V` as well.
12. **Stack/Routing Congruence (NEW)**
   - Validate routing declarations against actual project stack and allowed enums
   - Invalid enum = hard failure; stack-incongruent checks = warning or hard failure by impact
13. **Nested Executables Gate (NEW)**
   - Detect executable nested checklist/bullets that should be promoted to task nodes
   - Reject plans that keep executable nested work as prose after normalization pass
14. **Plan Size Audit (NEW)**
   - Ensure plan includes a `Plan Size Audit` block with required fields and deterministic size classification
   - Recompute expected size class from `estimated_waves` and `integration_boundaries`
   - Reject plans where declared class conflicts with computed class
15. **Parallelization Audit (NEW)**
   - Prefer splitting work into the smallest independently executable tasks before creating serial chains
   - For planning and plan-check tasks, require explicit `parallel-safe` / `serial-only` declaration
   - Reject plans that force serial execution for independent tasks without constraint justification
   - Reject plans when task-level parallel declaration is missing or `serial-only` lacks one-line reason
   - For `Medium`/`Large`/`XLarge`, verify decomposition into multiple plan files and phase-level handoff gates
16. **Validation Scope Isolation**
   - Implementation tasks must not contain acceptance criteria, evidence capture lists, or deliverable-proof checklists
   - Acceptance/evidence assertions must live only in dedicated verification tasks (`Task N-V`) or checkpoint audit blocks
   - **Repair action**: When `Task N` contains acceptance criteria or evidence content, strip it from `Task N` body — including `### Acceptance Criteria`, `#### Acceptance Criteria`, `### Success Criteria`, `AC:`-prefixed bullets, evidence capture checklists, and deliverable-proof items. Relocate stripped content to the corresponding `Task N-V` QA block; if no paired `Task N-V` exists, create one as a first-class task node before relocating. If `Task N` has no such content, no repair is needed.
17. **Checkpoint Coverage (NEW)**
   - Require explicit checkpoint definitions for `CP0`, `CP1`, `CP2`, `CP3`
   - Require checkpoint outputs to map to gate status, fixed sections, and unresolved blockers
18. **Index Status Synchronization (NEW)**
   - For `plan-set`, the index file must include first-class checkbox entries for every Wave and every Phase
   - The index file must treat Wave/Phase state as summary status only; task-level checkbox truth remains in the corresponding phase files
   - A Wave checkbox may be checked only after all implementation tasks assigned to that Wave and all paired `Task N-V` verification nodes are complete
   - A Phase checkbox may be checked only after that phase file's executable tasks and paired verification nodes are complete
   - **Repair action**: add missing Wave/Phase checkboxes to the index, link phases to their files, remove duplicated task-level status from the index, and normalize Wave completion criteria so `Task N` plus required `Task N-V` closure is explicit
19. **Sub-Plan Preflight Validation (NEW)**
   - For `plan-set`, each phase file must begin with a preflight validation stage before implementation tasks
   - Preflight must verify upstream phase outputs against current-phase blockers, contracts, and dependency assumptions
20. **Task Routing Tier Audit (NEW)**
   - Enforce a two-tier routing model:
   - **Premium tier** (`deep`, `ultrabrain`, `visual-engineering`, `artistry`): reserved for tasks that genuinely require their specialized capabilities.
   - `deep`: multi-system autonomous problem-solving, unfamiliar domains, end-to-end implementation with significant uncertainty.
   - `ultrabrain`: genuinely hard logic-heavy tasks — algorithm design, complex architecture decisions, non-obvious constraint satisfaction.
   - `visual-engineering`: visual/UI/UX work, styling, layout, animation, design system implementation.
   - `artistry`: unconventional or creative approaches that go beyond standard patterns.
   - **Standard tier** (`unspecified-high`, `unspecified-low`, `quick`, `writing`): the default for all implementation tasks.
   - **Decomposition completeness**: for every task node, evaluate whether it can be further split into smaller independent units. If yes, the task is under-decomposed — hard gate failure (`TASK_UNDER_DECOMPOSED`).
   - Using a premium-tier category on a task that can be handled by the standard tier is a routing overkill — **hard gate failure**.
   - Conversely, routing a genuinely complex task to `quick` or `unspecified-low` is a routing underkill — **soft warning**.
   - **Repair action**: When a premium-tier category is assigned to a routine task, downgrade to standard tier and decompose the original task into smaller units if it can be further split.
   - **Executor annotation default**: every task SHOULD declare `category` or `subagent_type`. If the task intentionally leaves the final routing choice to execution time, require `executor_judgment` or `routing_by_executor` plus a one-line rationale.
   - **Reminder**: premium-tier tasks SHOULD include a one-line rationale explaining why the specialized capability is required, preferably using `why_not_lower_cost`. If the rationale is unclear, default to standard tier.

## Repair Order

Apply fixes in this order:

1. Repair execution-skill header, task-level executor annotations, and routing enums
2. Repair user-facing summary block (`## User-Facing Summary`, `Development Core`, `User Requirements`)
   - Synthesize concise user-readable wording from explicit request context and settled plan scope; if the core/requirements cannot be inferred deterministically, ask targeted clarification questions first and emit `BLOCKED_NEEDS_DECISION` only if ambiguity remains
3. Repair anti-drift top section (`## User Requirement Digest`, `## Intent Anchor`)
   - Preserve user natural-language requirements in the digest and distill `Why`/`What`/`Non-Goals`/`Must Not Drift` into the anchor; if the content cannot be recovered deterministically, ask targeted clarification questions first and emit `BLOCKED_NEEDS_DECISION` only if ambiguity remains
4. Repair canonical contract drift (`interface_prefix`, `versioning_scheme`, `evidence_root`, scope)
   - Ensure constants are referenced verbatim across tasks, QA, and final verification
5. Build checkpoint map (`CP0`/`CP1`/`CP2`/`CP3`) and checkpoint output schema
6. Compile and repair unified task graph (IDs + dependencies)
7. Flatten executable nested work
8. Repair plan size audit and decomposition decision (`single-file` vs `plan-set`)
9. Repair verification closure (`Task N` / `Task N-V`)
   - When creating `Task N-V`, strip acceptance criteria from `Task N` body and relocate to `Task N-V` QA block
10. Repair plan-set index state model (Wave/Phase checkboxes + completion sync rules)
   - Recompute Phase/Wave checkbox eligibility after any `Task N-V` creation, verification-closure repair, or reopened node discovered during normalization
11. Repair sub-plan preflight validation stages for each phase file (`plan-set` only)
12. Repair QA executability blocks and validation-scope isolation
13. Run checkpoint loop to closure (`CP1` -> `CP2` -> `CP3`) and re-run hard-gate evaluation
14. Audit task routing tiers and decompose overkill tasks into standard-tier units

## Output Requirements

When you repair a plan, produce:

- `Verdict`: `PASS` or `REJECT`
- `Gate Summary`: count of failing hard gates by code
- `Hard Gates`: list gate code + failing sections
- `Warnings`: non-blocking quality issues
- `Fixed Sections`: exact sections changed
- `Needs Decision`: items requiring human product/contract decisions
- `Checkpoint Report`: CP0/CP1/CP2/CP3 status, loop iterations, unresolved blockers
- `User-Facing Summary`: confirmation that `Development Core` and `User Requirements` exist near the top and accurately reflect the settled scope in user-readable language
- `Requirement Digest`: confirmation that `## User Requirement Digest` preserves the user's natural-language requirements, constraints, prohibitions, and current focus without task-jargon drift
- `Intent Anchor`: confirmation that `## Intent Anchor` captures `Why`, `What`, `Non-Goals`, and `Must Not Drift` consistently with the settled scope
- `Validation Scope`: confirmation that acceptance/evidence checks are isolated to verification tasks/checkpoints
- `Plan Size`: computed class, declared class, and decomposition verdict
- `Index State`: for `plan-set`, confirmation that Wave/Phase checkboxes exist, their completion/reset criteria are explicitly defined, and their current checked state matches the underlying phase-file truth

If any `BLOCKED_NEEDS_DECISION` item remains open, verdict MUST be `REJECT`.

## Hard Gates vs Soft Warnings

### Hard Gates (must be zero to PASS)

- `ID_GRAPH_MISMATCH`
- `ROUTING_SCHEMA_INVALID`
- `CONTRACT_DRIFT`
- `QA_NOT_EXECUTABLE`
- `VERIFY_CLOSURE_MISSING`
- `STACK_MISMATCH_BLOCKING`
- `NESTED_EXECUTABLES_FOUND`
- `PLAN_SIZE_AUDIT_MISSING`
- `PLAN_SET_REQUIRED`
- `PARALLEL_DECLARATION_MISSING`
- `CHECKPOINT_MISSING`
- `VALIDATION_SCOPE_LEAK`
- `USER_SUMMARY_MISSING`
- `ANTI_DRIFT_TOP_SECTION_MISSING`
- `INDEX_STATE_SYNC_MISSING`
- `SUBPLAN_PREFLIGHT_MISSING`
- `ROUTING_OVERKILL`
- `TASK_UNDER_DECOMPOSED`

### Soft Warnings

- `ROUTING_HEURISTIC_WEAK`
- `TASK_EXECUTOR_ANNOTATION_WEAK`
- `THRESHOLD_UNJUSTIFIED`
- `NOISY_VERIFICATION`
- `ROUTING_UNDERKILL`

## Escalation Flow

1. **Auto-fix deterministic text issues** (ID remap, explicit dependency edges, header enum corrections, literal contract alignment)
2. **For high-impact ambiguous product decisions, ask targeted clarification questions first**; if the answer still cannot be recovered deterministically, emit `BLOCKED_NEEDS_DECISION`:
   - Example: choose `/api/` vs `/api/v1/`
   - Example: include or remove a feature from final verification scope
   - Example: the user's natural-language requirements and the intended `Why`/`What` anchor cannot be mapped consistently
3. Never guess business intent to “force pass”

## Gate Semantics (Deterministic)

- `ROUTING_SCHEMA_INVALID`: Fail when any routing declaration uses an unsupported value.
  - Allowed `category`: `visual-engineering`, `ultrabrain`, `deep`, `artistry`, `quick`, `unspecified-low`, `unspecified-high`, `writing`
  - Allowed `subagent_type`: `explore`, `librarian`, `oracle`, `metis`, `momus`
- `TASK_EXECUTOR_ANNOTATION_WEAK`: Warn when a task omits both explicit routing (`category` / `subagent_type`) and a justified deferred-routing marker (`executor_judgment` / `routing_by_executor`), or when a premium-tier task omits `why_not_lower_cost`.
- `STACK_MISMATCH_BLOCKING`: Fail when stack declarations contradict one or more executable tasks or QA paths (e.g., plan declares Go-only but executable QA requires Node-only runtime without declared exception).
- `ID_GRAPH_MISMATCH`: Fail on duplicate IDs, unknown IDs, phantom dependencies, or dependency references to non-existent task nodes.
- `QA_NOT_EXECUTABLE`: Fail when a QA block lacks concrete commands/inputs plus expected observable and evidence target.
  - For `Tool: Bash`, each QA step must contain at least one executable command line; prose-only imperatives are non-executable.
- `VERIFY_CLOSURE_MISSING`: Fail when downstream/final verification depends on implementation outputs but omits required verification node dependency.
  - `Task N-V` must be a first-class task node (in TODO, Wave, dependency matrix), not a section within `Task N`.
- `NESTED_EXECUTABLES_FOUND`: Fail when executable nested checklist items remain unpromoted after normalization.
- `PLAN_SIZE_AUDIT_MISSING`: Fail when `Plan Size Audit` block or required fields are missing, or declared size class does not match computed class.
- `PLAN_SET_REQUIRED`: Fail when computed `size_class` is `Medium`/`Large`/`XLarge` but decomposition decision is not `plan-set`.
- `PARALLEL_DECLARATION_MISSING`: Fail when planning/plan-check tasks omit `parallel-safe`/`serial-only` labels, or any `serial-only` task lacks a one-line constraint reason.
- `CHECKPOINT_MISSING`: Fail when required checkpoint nodes (`CP0`, `CP1`, `CP2`, `CP3`) are missing, unordered, or not mapped to audit outputs.
- `VALIDATION_SCOPE_LEAK`: Fail when acceptance criteria, evidence capture items, or deliverable-proof checks appear inside implementation task bodies instead of verification tasks/checkpoints.
  - Repair: strip acceptance criteria sections (`### Acceptance Criteria`, `#### Acceptance Criteria`, `### Success Criteria`, `AC:`-prefixed bullets, evidence capture checklists, deliverable-proof items) from implementation task `Task N` and relocate to paired `Task N-V` QA block.
- `USER_SUMMARY_MISSING`: Fail when the plan omits `## User-Facing Summary`, omits either `Development Core` or `User Requirements`, or leaves that section as executor shorthand that does not explain the current development core and requirements in concise user-facing language.
  - Repair: synthesize a concise natural-language summary from the explicit user request and settled plan scope; keep it near the top, preserve scope exactly, and if the core/requirements are not deterministically recoverable, ask targeted clarification questions first and emit `BLOCKED_NEEDS_DECISION` only if ambiguity remains.
- `ANTI_DRIFT_TOP_SECTION_MISSING`: Fail when the repaired plan omits either `## User Requirement Digest` or `## Intent Anchor`, when the digest rewrites user requirements into executor jargon, or when the anchor omits `Why`, `What`, `Non-Goals`, or `Must Not Drift`.
  - Repair: preserve the user's natural-language requirements in the digest, distill the anchor from explicit user context and settled scope, and if that content is not deterministically recoverable, ask targeted clarification questions first and emit `BLOCKED_NEEDS_DECISION` only if ambiguity remains.
- `INDEX_STATE_SYNC_MISSING`: Fail when a `plan-set` index does not provide explicit Wave/Phase checkboxes, duplicates detailed task checkbox state that belongs in phase files, or lacks deterministic completion rules for marking Wave/Phase entries complete.
  - Repair: add Wave/Phase checkbox entries to the index, keep detailed task checkbox truth in phase files, require immediate index updates after Phase/Wave closure, define Phase completion as all executable tasks plus paired verification nodes complete, define Wave completion as all implementation tasks plus paired `Task N-V` nodes complete, and reset the affected Phase/Wave checkbox if any underlying task or verification node reopens.
- `SUBPLAN_PREFLIGHT_MISSING`: Fail when any phase file in `plan-set` lacks a preflight validation stage that checks upstream blockers/contracts before implementation starts.
- `ROUTING_OVERKILL`: Fail when a premium-tier category (`deep`, `ultrabrain`, `visual-engineering`, `artistry`) is assigned to a task that does not genuinely require its specialized capability. Routine CRUD, configuration changes, simple file edits, boilerplate generation, and straightforward refactors MUST use `unspecified-high` or lower. Repair: downgrade to `unspecified-high` and decompose if scope exceeds standard-tier capacity.
- `TASK_UNDER_DECOMPOSED`: Fail when any task node can be further split into smaller independent units that fit standard-tier routing. A task that spans multiple files, multiple concerns, or multiple independent change sets is under-decomposed. Repair: split the task into smaller units and update dependency graph, wave assignments, and routing declarations accordingly.

## Integration with Atlas/Prometheus

- This skill is the canonical structural-repair landing path for authoritative plan edits.
- This skill may be used both before execution and after review-driven discovery of plan defects; completion-review findings do not bypass this repair path.
- This skill defines what a structurally valid, repair-complete plan looks like; it does not own runtime execution ordering, runtime evidence discipline, or commit timing.
- Atlas consumes this skill as the normative repair specification when plan structural consistency must be repaired before execution.
- Prometheus may provide only compact routing intent; this skill expands and enforces concrete repair gates.
- `metis` may expose omissions or plan-level gaps, and `oracle` may produce a structured revision brief; authoritative structural repair should then be landed through this skill rather than by patching the plan inline during execution.
- Plan drafting guidance and global workflow policy should remain in project-level MD documents.
- Output should be emitted inline in the current review message; no separate artifact file is required unless the plan itself requests one.

## Quick Reference

| Problem                                                     | Repair                                                                                                          |
| ----------------------------------------------------------- | --------------------------------------------------------------------------------------------------------------- |
| Nested `[ ]` under parent task                              | Promote to `Task N.a` / `Task N-V`                                                                              |
| `Task 2` depends on `Task 1` only                           | Add dependency on `Task 1-V` too                                                                                |
| Header mentions no skills                                   | Add execution-skill header and classify skills                                                                  |
| Plan has no user-readable summary of this development round | Add `## User-Facing Summary` with `Development Core` and `User Requirements` in concise natural language        |
| QA uses `/api/v1` but task says `/api`                      | Standardize the contract everywhere                                                                             |
| Final verification checks missing feature                   | Add implementation task or remove check                                                                         |
| Wave/TODO/dependency IDs drift                              | Compile unified task graph and reconcile IDs before any execution                                               |
| QA is narrative only                                        | Add runnable commands + expected observable + evidence path                                                     |
| Downstream depends on `Task N` only                         | Add dependency on `Task N-V` for shared surfaces                                                                |
| Invalid category/skill in header                            | Replace with allowed enum or mark as task-local with explicit rationale                                         |
| Task omits executor annotation                              | Add `category` / `subagent_type`, or declare `executor_judgment` / `routing_by_executor` with one-line reason |
| Business contract missing (e.g. prefix/versioning)          | Emit `BLOCKED_NEEDS_DECISION` instead of guessing                                                               |
| Size is `Medium`/`Large`/`XLarge` but plan is single-file   | Convert to `plan-set` (index + phase files) in the **same directory**, no new subfolder; add phase gates        |
| Plan lacks parallel declaration for independent tasks       | Add `parallel-safe` / `serial-only` labels and justify serial edges                                             |
| `serial-only` has no reason                                 | Add one-line constraint reason or downgrade to `parallel-safe`                                                  |
| Missing checkpoint nodes                                    | Add `CP0`/`CP1`/`CP2`/`CP3` and checkpoint outputs                                                              |
| Acceptance/Evidence appears in implementation task          | Strip from `Task N` body and relocate to `Task N-V` QA block                                                    |
| Plan-set index has no Wave/Phase checkboxes                 | Add checkbox entries for every Wave and Phase; keep fine-grained task state in phase files                      |
| Phase is checked before executable/verification closure     | Reopen the Phase checkbox until all executable tasks and required verification nodes in that Phase are complete |
| Wave is checked before paired verification closes           | Reopen the Wave checkbox until all implementation tasks and required `Task N-V` nodes are complete              |
| Reopened task leaves Phase/Wave checked                     | Reset the affected Phase/Wave checkbox until underlying closure is restored                                     |
| Sub-plan starts implementation without preflight validation | Insert phase preflight stage and validate upstream blockers/contracts first                                     |
| Premium category on routine task                            | Downgrade to `unspecified-high`; decompose if scope exceeds standard-tier capacity                              |
| Genuinely complex task routed to `quick`/`unspecified-low`  | Upgrade to `unspecified-high` or premium tier; add decomposition rationale                                      |
| Task spans multiple concerns but not split                  | Split into smaller independent units and update graph/wave/routing                                              |

## Common Mistakes

- Treating normalization as permission to keep malformed new plans
- Leaving task-local skills implicit
- Writing a plan that jumps straight into executor detail without a quick user-readable summary of the current development core and requirements
- Leaving task-level executor choice implicit when a cheap, explicit routing declaration was available
- Fixing wave prose but not dependency matrix
- Fixing task body but not QA/final verification
- Marking a plan executable before hard-gate recheck returns zero failures
- Auto-filling ambiguous business choices and pretending it is deterministic
- Creating `Task N-V` but leaving acceptance criteria in the parent `Task N` body
- Mirroring every task checkbox into the index instead of keeping Wave/Phase summary there and task truth in phase files
- Checking off a Phase before every executable task and paired verification node in that Phase has closed
- Checking off a Wave before every implementation task and paired `Task N-V` in that Wave has closed
- Leaving a Phase/Wave checked after one of its underlying tasks or verification nodes reopens
- Routing a routine implementation task to `deep` or `ultrabrain` — premium categories are scarce, not default
- Leaving large monolithic tasks undecomposed when they could be split into smaller independent units
- Assigning premium-tier categories without a clear rationale for why the specialized capability is needed
