---
name: sisyphus-cleanup
description: Use when cleaning, auditing, pruning, or deleting a `.sisyphus` workspace or similar execution-artifact directory, especially when the request involves removing completed plans, evidence, state files, empty folders, or preserving only deduplicated long-term knowledge before deletion.
---

# Sisyphus Cleanup

## Overview

Clean `.sisyphus` as a **verification-first artifact reduction workflow**, not as a blind file purge. The core rule is: **inventory → verify status → deduplicate durable knowledge → delete transient artifacts → prove the cleanup**.

## Load Conditions

Load this skill when any of the following is true:

- The user asks to clean, prune, archive, reset, or remove `.sisyphus` content.
- The directory contains plans, notepads, evidence, state files, or empty folders that may be obsolete.
- The user wants to keep only useful architecture notes while deleting completed execution artifacts.
- The cleanup decision depends on whether items are completed, still active, duplicated in memory, or safe to delete.

## Minimal CSO Triggers

Primary keywords: `.sisyphus cleanup`, `clean .sisyphus`, `delete completed plans`, `remove boulder.json`, `prune evidence`, `delete empty folders`, `cleanup execution artifacts`.

Secondary keywords: `archive plans`, `remove stale notepads`, `verify before delete`, `memory dedupe before deletion`, `artifact hygiene`, `task artifact cleanup`.

## Counter-Examples (Do Not Trigger)

| Input Pattern                      | Do Not Trigger Because                                                     |
| ---------------------------------- | -------------------------------------------------------------------------- |
| "只删除一个我明确指定的文件"       | Narrow deletion, no `.sisyphus` workflow needed                            |
| "只整理 Serena memories，不碰文件" | Memory-only work belongs to `memory-restructuring`                         |
| "只解释 `.sisyphus` 是什么"        | Pure explanation, no cleanup action                                        |
| "清理普通项目目录里的临时文件"     | General filesystem cleanup is broader than this artifact-specific protocol |

## Mandatory Rules

1. Start from a full inventory. Do **not** classify from filenames alone.
2. Verify completion in code/repo reality before deleting plans or notepads.
3. Treat `boulder.json`, plan files, evidence, and notes as **state-bearing** until proven disposable.
4. Preserve durable architecture knowledge only after checking existing memories for overlap.
5. Do not mirror task logs into memory. Keep only durable `guardrails`, `reference`, `topology`, or `contract` knowledge.
6. Delete transient artifacts only after their unique value is either disproven or preserved elsewhere.
7. Remove empty directories only after confirming they are truly empty.
8. End with proof: show the remaining directory state, or prove the directory no longer exists.

## Failure Modes This Skill Prevents

| Failure                       | Why It Happens                                             | Correct Response                                                      |
| ----------------------------- | ---------------------------------------------------------- | --------------------------------------------------------------------- |
| Completion guesswork          | Agent assumes `completed` or old date means safe to delete | Verify against code, current behavior, and active state first         |
| Blind `boulder.json` deletion | Agent treats state files as disposable metadata            | Inspect active plan/session references before deletion                |
| Memory dumping                | Agent copies all notes into memory                         | Deduplicate against existing memories and keep only durable knowledge |
| Partial cleanup               | Agent deletes some files, stops, and leaves mixed state    | Track cleanup in todos and verify each phase                          |
| Empty-folder assumption       | Agent deletes folders without checking contents            | Read/list directory first, then remove                                |
| No final proof                | Agent claims cleanup is done without evidence              | List remaining contents or verify path absence                        |

## Classification Pass

Classify each item into one of these buckets **after verification**:

- **Active state** — current plan/session state, live checkpoint, in-use artifact → keep
- **Completed transient artifact** — finished plan, evidence output, execution log, stale tracker → delete
- **Durable knowledge** — architecture, anti-regression lesson, topology, reusable rule → preserve via existing or updated memory
- **Unknown** — cannot prove status yet → keep until verified

## Execution Order

1. **Inventory**
   - List the full `.sisyphus` tree.
   - Identify plans, notepads, evidence, state files, and empty directories.

2. **Verify status, don’t infer it**
   - For each plan/notepad set, confirm whether the work is actually complete in code or project reality.
   - Check whether state files such as `boulder.json` still point at active work.
   - If the user says "completed", still verify.

3. **Review durable knowledge before deletion**
   - Read existing memories first.
   - If durable knowledge already exists in memory, do **not** duplicate it.
   - If notes contain unique long-term value, compress them into focused memory updates before deletion.
   - Use `memory-restructuring` principles: one memory = one dominant responsibility.

4. **Delete only verified transient artifacts**
   - Delete completed plans, stale notepads, evidence outputs, and disposable state files only after steps 2-3.
   - Remove empty directories after confirming they are empty.
   - If `.sisyphus` becomes empty, remove the root directory too.

5. **Prove the result**
   - List the remaining contents of `.sisyphus`, or
   - Verify that `.sisyphus` no longer exists.
   - Report what was deleted, what was preserved, and why no durable knowledge was lost.

## Deletion Checklist

Delete an artifact only if **all** are true:

- Its status was verified, not assumed.
- It is not the current source of active execution state.
- Any unique durable knowledge inside it was either preserved or proven redundant.
- Its removal reduces noise without creating a second source of truth.
- You can verify the post-cleanup state immediately afterward.

If any item is uncertain, keep it and mark it for follow-up review.

## Memory Handling Protocol

Use this sequence before preserving any note-derived knowledge:

1. `list_memories`
2. `read_memory` for overlapping candidates
3. decide: keep existing / update existing / write new / write nothing
4. execute the chosen memory operation
5. only then delete the source artifact

**Do not store**:

- session IDs
- one-off execution logs
- temporary audit notes
- verification output text
- giant copied plan histories

## Verification Signals

- Every deleted item had an explicit verified rationale.
- Durable knowledge was deduplicated against existing memories.
- No active state file was removed without confirmation.
- Empty directories were confirmed empty before removal.
- Final output contains evidence of the remaining state or path absence.

## Report Structure

When the cleanup is complete, report in this shape:

1. What was verified before deletion
2. What was deleted
3. What durable knowledge was preserved or intentionally not preserved
4. Final proof (`remaining tree` or `path does not exist`)

## Failure Handling

- If completion cannot be verified, stop classifying that item as deletable.
- If memory overlap is unclear, preserve less and review existing memories first.
- If deletion partially succeeds, re-inventory immediately and finish from the new ground truth.
- If `.sisyphus` is already absent, report that as the verified terminal state rather than recreating anything.
