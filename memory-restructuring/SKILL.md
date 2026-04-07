---
name: memory-restructuring
description: Use when a project's persistent memory store needs structural reorganization across multiple memories—because it is bloated, overlapping, low-precision, or hard to retrieve—while preserving valuable experience. Do not use for routine single-memory edits or one-off deletions.
---

# Memory Restructuring

## Overview

Reorganize persistent project memories for higher retrieval precision **without purging valuable experience**. The core rule is: **split, refine, rename, and reclassify first; delete only after verification**.

## Load Conditions

Load this skill when any of the following is true:

- The memory store feels too concentrated, bloated, or hard to search.
- Many memories overlap, mix multiple concerns, or use vague names.
- Historical memories contain lessons worth preserving, but their current form hurts retrieval.
- The user asks to clean up, reorganize, optimize, refactor, trim, split, merge, or audit project memories.

## Minimal CSO Triggers

Primary keywords: `memory restructuring`, `memory store cleanup`, `memory reorganization`, `memory hit rate`, `bloated memories`, `overlapping memories`, `split memories`, `memory taxonomy cleanup`.

Secondary keywords: `memory taxonomy`, `memory naming`, `knowledge preservation`, `keep valuable experience`, `memory consolidation`, `memory audit`, `persistent memory hygiene`.

## Counter-Examples (Do Not Trigger)

| Input Pattern | Do Not Trigger Because |
|---|---|
| "给现有记忆补一条小事实" | Single-memory update, not a restructuring task |
| "只解释什么是 memory / knowledge base" | Pure explanation without project reorganization |
| "只查外部资料，不改本地记忆" | Research-only task, no local memory restructuring |
| "只删除一个明确过时且已确认废弃的记忆" | Narrow deletion task; full restructuring workflow is unnecessary |
| "把这条 memory 改个名字" | Single-memory rename, not store-level restructuring |

## Mandatory Rules

1. Start from a full inventory, not from intuition. Read the current memory list before proposing structural changes.
2. Preserve valuable experience by default. Do **not** treat overlap or age as deletion proof.
3. Prefer the safety ladder: **split → trim → rename → keep → merge → rewrite → delete** when a memory is bloated, mixed, or oversized enough to hurt retrieval.
4. Giant or monolithic memories are a hit-rate problem, not just a formatting problem. When one memory mixes multiple responsibilities, query patterns, or long unrelated sections, splitting is the default corrective action.
5. Each memory should have one dominant responsibility: `contract`, `guardrails`, `reference`, `topology`, or similarly sharp scope.
6. Historical lessons should usually be compressed into current guardrails/reference memories, not dropped as "old".
7. If pre-restructure history explains why the new structure exists, preserve that path in organized anti-regression form so future maintainers do not drift back to the old shape.
8. General knowledge may be worth caching if it avoids repeated external search; trim and classify it rather than deleting reflexively.
9. Delete only when the memory is **verified** as obsolete, useless, retired, or fully superseded **and** has no residual experience value.
10. For split, merge, or rewrite operations, create or update the destination memory first, then verify that unique lessons were preserved before deleting or overwriting the source memory.
11. Do not leave dual sources of truth. If a skill/file is authoritative, memory should hold summary, guardrails, or cross-file relationships — not a stale mirror.
12. Names are retrieval infrastructure. Use concrete retrieval words like `contract`, `edit-rules`, `reference`, `topology`, `guardrails`; avoid vague names like `notes`, `misc`, `history`, `core-logic`.
13. After restructuring, persist reusable lessons from the restructuring itself only when they are durable, cross-task, and likely to improve future retrieval or editing decisions.
14. When old structure caused recurring mistakes, preserve a compact "road already traveled" record that explains what was changed and why reverting would be a regression.

## Split Triggers

MUST split a memory when ANY of the following is true:

- It mixes multiple responsibilities such as `contract` + `guardrails` + `history`.
- It serves multiple unrelated query patterns that would be better answered by separate memories.
- It has long sections that can stand alone as focused memories.
- It is bloated enough that trimming alone would still leave a broad, low-precision memory.
- A future query would likely need only one subsection rather than the whole memory.

## Execution Order

1. Inventory the current memory set before proposing structural changes.
2. Classify each memory by size, focus, redundancy, and hit-rate potential.
3. If a memory is giant, monolithic, or mixed-purpose, split it before considering keep/merge/delete.
4. Choose the least destructive operation that resolves the problem.
5. For split, merge, or rewrite, stage the new structure first.
6. Verify that valuable lessons, guardrails, authority boundaries, and relevant pre-restructure path history were preserved.
7. Delete only after the replacement structure is confirmed sufficient.

## Classification Pass

For each memory, evaluate four axes:

1. **Size** — Is it compact, or bloated enough to hurt precision?
2. **Focus** — Does it answer one question, or mix multiple concerns?
3. **Redundancy** — Does it duplicate a file/skill/other memory, or add unique value?
4. **Hit-Rate Potential** — Would a future query naturally match this name and content?

Then classify the memory by responsibility:

- **Contract** — Hard rules, schemas, required fields, must/never constraints
- **Guardrails** — Anti-regression lessons, design rationale that prevents bad edits
- **Reference** — Reusable general knowledge worth caching locally
- **Topology** — Cross-file/runtime wiring and system relationships
- **Transient / Junk** — Pure task logs, obsolete notes, valueless leftovers

## Split Methodology

When splitting a giant memory:

1. Identify the distinct responsibilities or query patterns inside it.
2. Create smaller destination memories with one dominant purpose each.
3. Give each split memory a retrieval-oriented name that matches its likely future query.
4. Copy forward the necessary context, guardrails, and pitfall history so each split remains understandable.
5. Remove duplicated filler instead of copying the giant memory verbatim into multiple places.
6. Keep cross-references only when they improve navigation; do not recreate a giant memory as scattered mirrors.

## Operation Selection

Choose the least destructive operation that solves the problem:

| Operation | Use When |
|---|---|
| Split | One memory mixes multiple responsibilities, query patterns, or oversized sections |
| Trim | Memory is focused but padded with low-value detail |
| Rename | Content is good but name hurts retrieval |
| Keep | Memory is focused, named well, and still useful |
| Merge | Two memories serve the same responsibility and same future query |
| Rewrite | Content is valuable but current form is historical, noisy, or poorly shaped |
| Delete | Memory is verified obsolete/useless/retired and no longer worth preserving |

## Deletion Checklist

Delete a memory only if **all** are true:

- Its content is provably obsolete, useless, retired, or replaced.
- Any valuable lesson inside has already been preserved elsewhere.
- No active workflow, file contract, or guardrail still depends on it.
- Its removal improves the store more than keeping a trimmed version would.
- You have verified the decision against current project context, not just similarity.

If any item is uncertain, **preserve and downscope** instead of deleting.

## Verification Signals

- Final memory set has clear namespaces and concrete names.
- Giant or monolithic memories were split into smaller focused memories when needed.
- Each memory has one dominant responsibility.
- Historical experience has been preserved in compact current-state form.
- Pre-restructure path/history was preserved when needed to prevent future backsliding.
- Only truly obsolete/useless memories were deleted.
- A restructuring-experience or anti-regression memory was added when reusable lessons emerged.

## Common Failure Modes

| Failure | Why It Happens | Correct Response |
|---|---|---|
| Over-deletion | Agent equates overlap with redundancy | Preserve first; extract unique lessons before deletion |
| Blind merging | Similar topic mistaken for same responsibility | Merge only when future query pattern is also the same |
| Timeline cleanup | Old memories treated as disposable history | Convert history into current guardrails/reference |
| Generic naming | Organization optimized for humans, not retrieval | Rename with dense retrieval words |
| Monolithic consolidation | Too many small items merged into one giant memory | Split by responsibility and query pattern |
| Giant memory preservation | Memory was classified as bloated but kept nearly intact | Split first; trimming alone is not enough for mixed-purpose memories |
| Skill mirroring | Memory duplicates authoritative skill/file content | Keep only summary, guardrails, or topology in memory |

## Failure Handling

- If you cannot verify whether a memory is truly obsolete, keep it and mark it for later review.
- If two memories overlap but serve different future questions, split/rename rather than merge.
- If a general knowledge memory is broad but still useful, trim it into a local quick-reference instead of deleting it.
- If the store is very large, restructure namespace-by-namespace instead of rewriting everything at once.
